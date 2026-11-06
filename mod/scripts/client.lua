-- Copyright (C) 2026 Luiz-AVcruz. AGPL-3.0-or-later; see ADDITIONAL-PERMISSION.
if client then
    local activeSession, activeJoin, pending, revision, generation
    local targets, nextCatalog, sentPreference, observedUnavailable
    local preference, followRequested
    local seenJoins, blockedJoins
    local RETRY, LIMIT = 0.5, 8

    local function status(key, detail)
        client.ossStatus, client.ossStatusDetail = key, detail or ""
    end

    function client.ossState()
        return {current=GetPlayerCharacter(GetLocalPlayer()), saved=GetString(OSS.root .. "character"),
            status=client.ossStatus, detail=client.ossStatusDetail}
    end

    local function available(id)
        local entry = OSS.byId[id]
        return entry and entry.available
    end

    local function beginRequest(id)
        generation = generation + 1
        preference, followRequested, sentPreference = id, id == "", false
        pending = nil
        status(id == "" and "applying" or "saved")
    end

    function client.ossSelect(id)
        client.ossRefreshCatalog()
        if not available(id) then status("unavailable", type(id)=="string" and id or ""); return false end
        SetString(OSS.root .. "character", id)
        beginRequest(id)
        return true
    end

    function client.ossFollowGame()
        ClearKey(OSS.root .. "character")
        beginRequest("")
    end

    function client.init()
        activeSession, activeJoin, pending, revision, generation = nil,nil,nil,0,0
        targets, nextCatalog, sentPreference, observedUnavailable = {},0,false,false
        seenJoins, blockedJoins = {},{}
        preference, followRequested = OSS.autoRestore() and GetString(OSS.root .. "character") or "", false
        client.ossRefreshCatalog()
        status(preference == "" and "idle" or "waiting_session")
        DebugPrint("Open Skin Selector " .. OSS.version .. " loaded")
    end

    function client.ossReply(epoch, join, sequence, accepted, reason)
        if not pending or epoch ~= activeSession or join ~= activeJoin
            or sequence ~= pending.revision or pending.generation ~= generation then return end
        pending = nil
        status(accepted and "session_accepted" or "rejected", reason)
    end

    local function sendRequest(entry, now)
        revision = math.max(revision, entry.revision) + 1
        pending = {revision=revision, started=now, nextSend=now, generation=generation, id=preference}
        sentPreference = true
        status("applying")
    end

    local function sendPending(now)
        if not pending then return end
        if now - pending.started >= LIMIT then pending=nil; status("session_timeout"); return end
        if now >= pending.nextSend then
            -- Set all state before calling the boundary: a host reply may be synchronous.
            pending.nextSend = now + 1
            ServerCall("server.ossChoose",GetLocalPlayer(),activeSession,activeJoin,pending.revision,pending.id)
        end
    end

    local function applyTarget(p, target, now)
        if not IsPlayerValid(p) then return end
        local localPlayer = IsPlayerLocal(p) and target.revision>=revision
            and ((target.releasing and preference=="") or target.id==preference)
        local current = GetPlayerCharacter(p)
        if target.releasing and current~=target.previous and current~=target.id then
            -- The game/user already selected something else. Do not overwrite that selection.
            if localPlayer then status("following_game") end
            return true
        end
        local entry = OSS.byId[target.id]
        if not entry or (localPlayer and not target.releasing and not entry.available) then
            target.missing = true
            if localPlayer then status(target.releasing and "release_failed" or "unavailable",target.id) end
            return
        end
        if target.missing then target.missing=false; target.started=nil; target.failed=false end
        if GetPlayerHealth(p) <= 0 then target.dead=true; return end
        if target.dead then target.dead=false; target.started=nil; target.failed=false end
        if current == target.id then
            target.confirmed, target.started, target.failed = true,nil,false
            if localPlayer and not pending then status(target.releasing and "following_game" or "applied") end
            if target.releasing then return true end
            return
        end
        if target.confirmed then target.confirmed=false; target.started=nil; target.failed=false end
        if target.failed then return end
        if not target.started then target.started=now; target.nextTry=now end
        if now-target.started >= LIMIT then
            target.failed=true
            if localPlayer then status(target.releasing and "release_failed" or "apply_failed",target.id) end
            return
        end
        if now >= target.nextTry then
            target.nextTry=now+RETRY
            local ok = pcall(SetPlayerCharacter,target.id,p)
            if not ok and localPlayer then status(target.releasing and "release_failed" or "apply_failed",target.id) end
        end
    end

    local function syncTargets(snapshot, now)
        local present = {}
        for p, entry in pairs(snapshot.players) do
            local blocked=blockedJoins[p]==entry.join
            present[p]=not blocked
            local old = targets[p]
            -- Ignore this client's outdated snapshot while its newer selection is pending.
            local stale = IsPlayerLocal(p) and entry.revision < revision and sentPreference
            if not blocked and not stale and IsPlayerValid(p) then
                blockedJoins[p]=nil
                seenJoins[p]=entry.join
                if entry.character ~= "" then
                    if not old or old.join ~= entry.join or old.revision ~= entry.revision then
                        local baseline=old and old.join==entry.join and old.baseline or GetPlayerCharacter(p)
                        -- The native body script uses Sven for an empty/unknown character ID.
                        if not OSS.byId[baseline] then baseline="sven_lagom" end
                        targets[p]={id=entry.character, join=entry.join, revision=entry.revision,
                            baseline=baseline}
                    end
                elseif old then
                    if old.join ~= entry.join then targets[p]=nil
                    elseif old.releasing then
                        if old.revision~=entry.revision then
                            old.revision,old.started,old.failed=entry.revision,nil,false
                        end
                    elseif IsPlayerValid(p) and GetPlayerCharacter(p)==old.id then
                        targets[p]={id=old.baseline,previous=old.id,baseline=old.baseline,
                            join=entry.join,revision=entry.revision,releasing=true}
                    else
                        targets[p]=nil
                    end
                end
            end
        end
        for p in pairs(targets) do if not present[p] then targets[p]=nil end end
        for p, target in pairs(targets) do if applyTarget(p,target,now) then targets[p]=nil end end
    end

    function client.tick(dt)
        local now = GetTime()
        if now >= nextCatalog then client.ossRefreshCatalog(); nextCatalog=now+1 end
        local snapshot = shared.oss
        if snapshot and snapshot.session~=activeSession then
            seenJoins,blockedJoins={},{}
        end
        -- A client's roster can advance before shared state. Never apply an old join's
        -- appearance to a new occupant of that ID while waiting for the new snapshot.
        for _,p in ipairs(GetRemovedPlayers()) do
            blockedJoins[p]=seenJoins[p] or (snapshot and snapshot.players[p] and snapshot.players[p].join)
            targets[p]=nil
        end
        local me = snapshot and snapshot.players[GetLocalPlayer()]
        if me and blockedJoins[GetLocalPlayer()]==me.join then me=nil end
        if snapshot and me then
            if snapshot.session ~= activeSession or me.join ~= activeJoin then
                activeSession, activeJoin = snapshot.session,me.join
                revision,pending,sentPreference,targets = 0,nil,false,{}
                generation=generation+1
            end
            if preference ~= "" and not available(preference) then
                observedUnavailable=true
                status(#OSS.catalog==0 and "waiting_catalog" or "unavailable",preference)
            else
                if observedUnavailable then sentPreference=false; pending=nil; observedUnavailable=false end
                if not sentPreference and (preference ~= "" or followRequested) then sendRequest(me,now) end
                sendPending(now)
            end
            -- The synchronized state is also an acknowledgement if the RPC reply was lost.
            if pending and me.revision==pending.revision and me.character==pending.id then
                pending=nil
                status("session_accepted")
            end
            syncTargets(snapshot,now)
            if followRequested and not pending and me.character=="" and me.revision>=revision
                and not targets[GetLocalPlayer()] then status("following_game") end
        elseif preference ~= "" then status("waiting_session") end
        client.ossMenuTick(dt)
    end

    function client.draw()
        client.ossMenuDraw()
    end
end

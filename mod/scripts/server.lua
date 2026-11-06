-- Copyright (C) 2026 Luiz-AVcruz. AGPL-3.0-or-later; see ADDITIONAL-PERMISSION.
if server then
    local session, joins, members

    local function publish()
        local snapshot = {session=session, players={}}
        for p, entry in pairs(members) do
            snapshot.players[p] = {join=entry.join, revision=entry.revision, character=entry.character}
        end
        shared.oss = snapshot
    end

    local function reconcile()
        local changed = false
        -- Removal first prevents recycled IDs from inheriting a previous entry's choice.
        for _,p in ipairs(GetRemovedPlayers()) do if members[p] then members[p]=nil; changed=true end end
        local live = {}
        for _,p in ipairs(GetAllPlayers()) do
            live[p] = true
            if not members[p] then
                joins = joins + 1
                members[p] = {join=session .. ":" .. joins, revision=0, character=""}
                changed = true
            end
        end
        for p in pairs(members) do if not live[p] then members[p]=nil; changed=true end end
        return changed
    end

    function server.init()
        local epoch = GetInt(OSS.root .. "epoch") + 1
        if epoch >= 2147483647 then epoch = 1 end
        SetInt(OSS.root .. "epoch", epoch)
        -- Different hosts must not accidentally share an epoch/join token.
        session = tostring(epoch)
        for _=1,4 do session = session .. string.format("%08x", GetRandomInt(0,2147483646)) end
        joins, members = 0, {}
        reconcile()
        publish()
    end

    function server.tick()
        if reconcile() then publish() end
    end

    function server.ossChoose(player, epoch, join, revision, id)
        if not OSS.integer(player,1) or not IsPlayerValid(player) or epoch ~= session then return end
        -- RPC may arrive before the roster tick observes a removal/recycled ID.
        for _,removed in ipairs(GetRemovedPlayers()) do if removed==player then return end end
        local entry = members[player]
        if not entry or join ~= entry.join or not OSS.integer(revision,1) then return end
        -- A retry can acknowledge the identical accepted state, never overwrite a newer choice.
        if revision <= entry.revision then
            if revision == entry.revision and id == entry.character then
                ClientCall(player,"client.ossReply",session,join,revision,true,"")
            end
            return
        end
        local character = id ~= "" and OSS.lookup(id) or nil
        -- Unlocks belong to the selecting client, not the host's campaign save.
        if type(id) ~= "string" or (id ~= "" and not character) then
            ClientCall(player,"client.ossReply",session,join,revision,false,"unavailable")
            return
        end
        entry.revision, entry.character = revision, id
        publish()
        ClientCall(player,"client.ossReply",session,join,revision,true,"")
    end
end

-- Multi-context contract tests. These simulate registries/RPC, not Teardown rendering.
local count=0
local function check(value, message) count=count+1; assert(value,message) end
local function copy(v)
    if type(v)~="table" then return v end
    local result={}; for k,x in pairs(v) do result[k]=copy(x) end; return result
end
local function catalog()
    local result={}
    local function entry(id,available,builtin)
        result["characters."..id]="player/"..id..".xml"
        result["characters."..id..".name"]=id
        result["characters."..id..".availability"]=available
        result["characters."..id..".builtin"]=builtin
    end
    entry("sven_lagom",false,true); entry("lisa_lagom",false,true)
    entry("freya",false,true); entry("steam-42.Chell",true,false)
    entry("steam-77.Miku",true,false)
    result["characters.steam-77.Miku.tool_offset"]="(-1, 0, 2)"
    return result
end

local world={now=0,players={[1]=true,[2]=true},removed={},queue={},saves={},natives={},contexts={},catalog=catalog()}
local function environment(role,player,save)
    local env=setmetatable({},{__index=_G}); env._G=env
    env.server=role=="server" and {} or nil; env.client=role=="client" and {} or nil; env.shared={}
    local db=world.catalog
    save=save or {}; local writes={}; local native=world.natives[player] or {[1]="sven_lagom",[2]="sven_lagom"}
    if player then world.natives[player]=native end
    env.calls=0; env.writes=writes; env.save=save; env.native=native
    function env.GetString(k) local v=save[k];if v==nil then v=db[k] end;return v==nil and "" or tostring(v) end
    function env.GetInt(k) return tonumber(save[k] or db[k]) or 0 end
    function env.GetBool(k) local v=save[k];if v==nil then v=db[k] end;return v==true or v==1 end
    function env.HasKey(k) return save[k]~=nil or db[k]~=nil end
    function env.ListKeys(root)
        local keys={}
        for _,source in ipairs({db,save}) do
            for k in pairs(source) do
                if k:sub(1,#root+1)==root.."." then keys[k:sub(#root+2):match("^[^.]+")]=true end
            end
        end
        local list={};for k in pairs(keys) do list[#list+1]=k end;table.sort(list);return list
    end
    -- Exact prefix below: all persistent writes must belong to this mod.
    function env.SetString(k,v) assert(k:sub(1,30)=="savegame.mod.openskinselector."); save[k]=v; writes[#writes+1]={k,v} end
    env.SetInt=env.SetString
    function env.ClearKey(k)
        assert(k:sub(1,30)=="savegame.mod.openskinselector.")
        for key in pairs(save) do if key==k or key:sub(1,#k+1)==k.."." then save[key]=nil end end
        writes[#writes+1]={k}
    end
    function env.GetRandomInt(a,b) world.random=(world.random or 0)+137;return world.random end
    function env.GetTranslatedStringByKey(k,fallback) return fallback end
    function env.GetLocalPlayer() return player end
    function env.IsPlayerLocal(p) return p==player end
    function env.IsPlayerValid(p) return world.players[p]==true end
    local function playerList(list)
        local values={};for p,v in pairs(list) do if v then values[#values+1]=p end end;table.sort(values)
        return values
    end
    function env.GetAllPlayers() return playerList(world.players) end
    function env.GetRemovedPlayers() return playerList(world.removed) end
    function env.GetTime() return world.now end
    function env.GetPlayerCharacter(p) return native[p] or "sven_lagom" end
    function env.GetPlayerHealth(p) return (world.dead and world.dead[p]) and 0 or 1 end
    function env.SetPlayerCharacter(id,p)
        env.calls=env.calls+1
        if env.throwSet then error("native setter failure") end
        if not env.ignoreSet then native[p]=id end
    end
    function env.DebugPrint() end
    function env.ClientCall(p,fn,...)
        local args={...}
        if world.dropReplies then return end
        for id,context in pairs(world.contexts) do
            if id==p or p==0 then context.client[fn:match("[^.]+$")](unpack(args)) end
        end
    end
    function env.ServerCall(fn,...)
        local args={...}
        if world.delayRequests then world.queue[#world.queue+1]={fn=fn,args=args}
        else world.server.server[fn:match("[^.]+$")](unpack(args)) end
    end
    for _,name in ipairs({"common","catalog",role=="server" and "server" or "client"}) do
        local chunk=assert(loadfile("mod/scripts/"..name..".lua")); setfenv(chunk,env);chunk()
    end
    if env.client then env.client.ossMenuTick=function() end;env.client.ossMenuDraw=function() end end
    return env
end

local function server(save)
    world.server=environment("server",nil,save);world.server.server.init();return world.server
end
local function client(p,save)
    local context=environment("client",p,save);world.contexts[p]=context
    context.client.init();return context
end
local function tick(dt)
    world.now=world.now+(dt or .1)
    world.server.server.tick()
    for _,c in pairs(world.contexts) do c.shared.oss=copy(world.server.shared.oss); c.client.tick(dt or .1) end
    world.removed={}
end
local function drain()
    local queue=world.queue; world.queue={}
    for _,q in ipairs(queue) do world.server.server[q.fn:match("[^.]+$")](unpack(q.args)) end
end
local root="savegame.mod.openskinselector."
local host=server();local one=client(1);local two=client(2)
tick()
check(#one.writes==0 and one.calls==0,"initial native choice must not be saved or forced")
check(one.OSS.byId.sven_lagom.available,"family is available without save unlock")
check(not one.OSS.byId.freya.available,"locked game character")
check(one.OSS.byId["steam-42.Chell"].origin=="mod","nested mod catalog")
check(one.OSS.byId.sven_lagom.origin=="game","builtin catalog")
check(not one.client.ossSelect("freya"),"locked selection rejected")
check(not one.client.ossSelect("../player/evil"),"paths rejected")
check(one.client.ossSelect("steam-42.Chell"),"choose registered mod")
check(two.client.ossSelect("lisa_lagom"),"choose another skin")
for _=1,4 do tick() end
check(one.native[1]=="steam-42.Chell" and two.native[1]=="steam-42.Chell","all clients see player one")
check(one.native[2]=="lisa_lagom" and two.native[2]=="lisa_lagom","all clients see player two")
check(one.client.ossStatus=="applied" and two.client.ossStatus=="applied","synchronous ACK handled")
local calls=one.calls;for _=1,20 do tick() end
check(one.calls==calls,"no continuous setter after matching readback")
one.native[1]="sven_lagom";tick();tick()
check(one.native[1]=="steam-42.Chell","recover native reset")

-- Missing local asset must preserve the saved preference and not crash/spawn anything.
world.catalog["characters.steam-42.Chell"]=nil
tick(1.1)
check(one.client.ossState().saved=="steam-42.Chell","missing skin preference retained")
check(one.client.ossStatus=="unavailable","missing skin reported")
world.catalog["characters.steam-42.Chell"]="player/chell.xml"
tick(1.1);tick();tick()
check(one.client.ossStatus=="applied","returning skin restored")

-- Death delays a pending application; respawn reactivates it.
world.dead={[1]=true};one.client.ossSelect("lisa_lagom");tick();tick()
check(one.native[1]=="steam-42.Chell","do not change a dead body")
world.dead={};tick();tick()
check(one.native[1]=="lisa_lagom","respawn applies preference")

-- A fresh Lua VM/new server keeps only the client's storage, not recyclable IDs/names.
local savedOne,savedTwo=one.save,two.save
world.contexts={};world.natives={};host=server(host.save)
one=client(1,savedOne);two=client(2,savedTwo)
for _=1,4 do tick() end
check(one.native[1]=="lisa_lagom" and two.native[2]=="lisa_lagom","new mission restores saved skin")
one.client.ossSelect("steam-42.Chell");tick();tick();tick()
world.contexts={};world.natives={};host=server({}) -- a different host has no personal profiles
world.players={[7]=true,[8]=true}
one=client(7,savedOne);two=client(8,savedTwo)
for _=1,4 do tick() end
check(two.native[7]=="steam-42.Chell" and one.native[8]=="lisa_lagom","different host and IDs preserve personal choices")

-- A late joiner receives the existing snapshot. An ID reused by a fresh client gets no skin.
world.players[9]=true;local late=client(9)
for _=1,3 do tick() end
check(late.native[7]=="steam-42.Chell" and late.native[8]=="lisa_lagom","late join state")
local oldEntry=copy(host.shared.oss.players[7]);local oldSession=host.shared.oss.session
world.players[7]=nil;world.contexts[7]=nil;world.removed={[7]=true};tick()
world.players[7]=true;world.natives[7]=nil;local fresh=client(7);tick()
check(host.shared.oss.players[7].character=="","reused ID starts clean")
host.server.ossChoose(7,oldSession,oldEntry.join,99,"steam-42.Chell")
check(host.shared.oss.players[7].character=="","old entry request rejected")

-- Stale revision may not overwrite a more recent selection, including delayed RPC replies.
world.delayRequests=true
two.client.ossSelect("steam-42.Chell");tick()
two.client.ossSelect("steam-77.Miku");tick()
local first,second=world.queue[1],world.queue[2];world.queue={}
world.delayRequests=false
host.server.ossChoose(unpack(second.args));host.server.ossChoose(unpack(first.args))
tick();tick()
check(host.shared.oss.players[8].character=="steam-77.Miku","out-of-order requests cannot undo newer choice")
check(two.native[8]=="steam-77.Miku","newer choice rendered by API")
local entry=host.shared.oss.players[8]
host.server.ossChoose(8,host.shared.oss.session,entry.join,entry.revision+1,"unregistered")
check(host.shared.oss.players[8].character=="steam-77.Miku","invalid ID rejected by server")
host.server.ossChoose(8,host.shared.oss.session,entry.join,0/0,"sven_lagom")
check(host.shared.oss.players[8].character=="steam-77.Miku","nonfinite revision rejected")

-- Snapshot confirms acceptance even if the explicit reply is dropped.
world.dropReplies=true;two.client.ossSelect("lisa_lagom");for _=1,4 do tick() end
check(two.client.ossStatus=="applied","shared acceptance survives missing ACK")
world.dropReplies=false

-- A new map must reject queued requests from the old session.
local previous=host.shared.oss.session
host.server.init();local e=host.shared.oss.players[8]
host.server.ossChoose(8,previous,e.join,100,"steam-77.Miku")
check(host.shared.oss.players[8].character=="","old session rejected")
for _=1,3 do tick() end

-- Follow the game: delete only this preference and release both local and remote overrides.
two.client.ossFollowGame();for _=1,4 do tick() end
check(two.save[root.."character"]==nil,"follow removes preference")
check(host.shared.oss.players[8].character=="","follow releases shared override")
check(two.client.ossStatus=="following_game","follow state visible")
two.native[8]="steam-77.Miku";tick()
check(two.native[8]=="steam-77.Miku","following no longer forces saved skin")

-- A silently ignored API setter must stop retrying and must never claim successful application.
fresh.ignoreSet=true;fresh.client.ossSelect("steam-42.Chell")
for _=1,25 do tick(.5) end
check(fresh.client.ossStatus=="apply_failed","bounded native failure")
local failedCalls=fresh.calls
for _=1,10 do tick(1) end
check(fresh.calls==failedCalls,"failed setter does not retry forever")
fresh.ignoreSet=false;world.dead={[7]=true};tick();world.dead={};tick();tick()
check(fresh.native[7]=="steam-42.Chell","respawn permits recovery after failure")

-- Transport timeout retains preference; a new explicit selection cancels the old pending request.
world.delayRequests=true;fresh.client.ossSelect("steam-77.Miku")
for _=1,12 do tick(1) end
check(fresh.client.ossStatus=="session_timeout","transport timeout distinct from apply success")
check(fresh.save[root.."character"]=="steam-77.Miku","timeout retains preference")
fresh.client.ossSelect("lisa_lagom");tick()
world.delayRequests=false;drain();for _=1,4 do tick() end
check(fresh.native[7]=="lisa_lagom","new explicit choice wins after timeout")

-- Availability flags are read-only, including explicit locked mod unlock values.
world.catalog["characters.steam-77.Miku.availabilityKey"]="unlocked"
fresh.save["savegame.mod.steam-77.unlocked"]=false
fresh.client.ossRefreshCatalog()
check(not fresh.OSS.byId["steam-77.Miku"].available,"explicit false unlock overrides available")
check(not fresh.client.ossSelect("steam-77.Miku"),"locked mod cannot be selected")
check(world.catalog["characters.steam-77.Miku.tool_offset"]=="(-1, 0, 2)","registry metadata unchanged")

-- Unlocks are personal. Neither host admission nor spectators may impose their own save.
world.contexts={};world.natives={};world.players={[1]=true,[2]=true};world.removed={}
world.catalog=catalog();host=server({});one=client(1);two=client(2,{["savegame.characters.freya"]=true})
tick();check(two.client.ossSelect("freya"),"guest unlocked Freya independently")
for _=1,4 do tick() end
check(host.shared.oss.players[2].character=="freya","host accepts guest's personal unlock")
check(one.native[2]=="freya","spectator without unlock still displays registered character")
check(not one.OSS.byId.freya.available,"rendering another skin never unlocks it")
two.client.ossFollowGame();for _=1,4 do tick() end
check(two.native[2]=="sven_lagom" and one.native[2]=="sven_lagom","release restores local AND remote baselines")

-- Old shared state must not be applied while native roster is already ahead.
two.client.ossSelect("steam-42.Chell");for _=1,4 do tick() end
local retired=copy(host.shared.oss.players[2]);local session=host.shared.oss.session
world.contexts[2]=nil;world.removed={[2]=true};one.native[2]="sven_lagom"
-- New player already occupies ID 2, but both server and client snapshots still show old join.
one.client.tick(.1)
check(one.native[2]=="sven_lagom","client removal blocks an old snapshot before roster publication")
host.server.ossChoose(2,session,retired.join,retired.revision+1,"steam-77.Miku")
check(host.shared.oss.players[2].character=="steam-42.Chell","RPC before roster tick cannot act for recycled ID")
host.server.tick();world.removed={}
one.client.tick(.1) -- Still intentionally delayed snapshot.
check(one.native[2]=="sven_lagom","old snapshot stays blocked after removal frame ends")
one.shared.oss=copy(host.shared.oss);one.client.tick(.1)
check(one.native[2]=="sven_lagom","new empty join does not inherit retired choice")
world.natives[2]=nil;two=client(2)

-- A release has the same retry/readback contract as applying a preference.
two.client.ossSelect("steam-42.Chell");for _=1,4 do tick() end
two.ignoreSet=true;two.client.ossFollowGame()
check(two.client.ossStatus~="following_game","release is not announced before native confirmation")
tick();tick()
check(two.client.ossStatus~="following_game","server ACK alone does not prove native restoration")
for _=1,22 do tick(.5) end
check(two.native[2]=="steam-42.Chell" and two.client.ossStatus=="release_failed","ignored release must not claim success")
local releaseCalls=two.calls;for _=1,10 do tick(1) end
check(two.calls==releaseCalls,"release retry budget is bounded")
two.ignoreSet=false;two.client.ossFollowGame();for _=1,4 do tick() end
check(two.native[2]=="sven_lagom" and two.client.ossStatus=="following_game","explicit release retry restores baseline")
two.client.ossSelect("steam-42.Chell");for _=1,4 do tick() end
two.throwSet=true;two.client.ossFollowGame();tick();tick()
check(two.client.ossStatus=="release_failed","release handles native exception")
two.throwSet=false;for _=1,4 do tick(.6) end
check(two.native[2]=="sven_lagom","release recovers a transient native exception")

-- Empty native IDs are the standard native body's Sven fallback, not an unavailable skin.
two.native[2]="";one.native[2]=""
two.client.ossSelect("steam-42.Chell");for _=1,4 do tick() end
two.client.ossFollowGame();for _=1,4 do tick() end
check(two.native[2]=="sven_lagom" and one.native[2]=="sven_lagom","empty native baseline restores native fallback")

-- Never overwrite a new native choice made independently while releasing.
two.client.ossSelect("steam-42.Chell");for _=1,4 do tick() end
two.ignoreSet=true;two.client.ossFollowGame();tick();tick()
two.native[2]="lisa_lagom";two.ignoreSet=false;tick();tick()
check(two.native[2]=="lisa_lagom","release respects a new external character choice")

-- A recovery setting changed in the manager takes effect in a fresh map, without
-- deleting either the selected skin or favorites. Manual selection remains usable.
world.contexts={};world.natives={};world.players={[1]=true,[2]=true};world.removed={}
host=server({})
one=client(1,{[root.."character"]="steam-42.Chell",[root.."auto_restore"]=false,[root.."favorites.61"]=true})
two=client(2)
for _=1,4 do tick() end
check(one.calls==0 and host.shared.oss.players[1].character=="","recovery disables automatic selection in a fresh map")
check(one.save[root.."character"]=="steam-42.Chell" and one.save[root.."favorites.61"],"recovery toggle preserves personal data")
one.client.ossSelect("steam-42.Chell");for _=1,4 do tick() end
check(one.native[1]=="steam-42.Chell" and two.native[1]=="steam-42.Chell","manual selection still works with automatic restoration disabled")

-- Load the actual expanded entry point as well as the isolated modules. A pure
-- server has no client table; UI exports must not crash that context at load time.
if arg[1] then
    for _,role in ipairs({"server","client"}) do
        local env=environment(role,role=="client" and 1 or nil,{})
        function env.PauseMenuButton() return false end
        function env.InputPressed() return false end
        local bundle=assert(loadfile(arg[1]));setfenv(bundle,env);bundle()
        if role=="server" then
            env.server.init();env.server.tick()
            check(env.shared.oss and not env.client,"entry point loads on a server without client globals")
        else
            env.client.init();env.client.tick(.1);env.client.draw()
            check(env.client.ossState().saved=="" and not env.server,"entry point loads on client without server globals")
        end
    end
end
print("PASS runtime: "..count.." contract assertions across isolated server/client contexts")

-- Copyright (C) 2026 Luiz-AVcruz. AGPL-3.0-or-later; see ADDITIONAL-PERMISSION.
-- Read the game's registry, never run its menu validation (which writes native saves).
local family = {sven_lagom=true, lisa_lagom=true, keiko_lagom=true,
    maria_lagom=true, fumiaki_lagom=true, carlos_lagom=true}

function OSS.lookup(id)
    if not OSS.validId(id) then return nil end
    local key = "characters." .. id
    local path = GetString(key)
    if path == "" then return nil end
    local builtin = GetBool(key .. ".builtin") or family[id] == true
    local available = family[id] == true or GetBool(key .. ".availability")
    local unlock = "savegame.characters." .. id
    if not builtin then
        local modId = id:match("^([^.]+)%.")
        local availabilityKey = GetString(key .. ".availabilityKey")
        unlock = modId and availabilityKey ~= "" and ("savegame.mod." .. modId .. "." .. availabilityKey) or ""
    end
    if not family[id] and unlock ~= "" and HasKey(unlock) then available = GetBool(unlock) end
    return {id=id, name=OSS.clean(GetString(key .. ".name"), id),
        description=OSS.clean(GetString(key .. ".description")), preview=GetString(key .. ".preview"),
        origin=builtin and "game" or "mod", available=available,
        hidden=GetBool(key .. ".hidden"), path=path}
end

function OSS.readCatalog()
    local list, byId = {}, {}
    local function add(id)
        local entry = OSS.lookup(id)
        if entry and not byId[id] then
            byId[id] = entry
            if not entry.hidden or entry.available then list[#list+1] = entry end
        end
    end
    for _, top in ipairs(ListKeys("characters")) do
        if GetString("characters." .. top) ~= "" then add(top)
        else
            for _, child in ipairs(ListKeys("characters." .. top)) do add(top .. "." .. child) end
        end
    end
    table.sort(list, function(a,b)
        if a.origin ~= b.origin then return a.origin == "game" end
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    return list, byId
end

if client then
    function client.ossRefreshCatalog()
        OSS.catalog, OSS.byId = OSS.readCatalog()
    end
end

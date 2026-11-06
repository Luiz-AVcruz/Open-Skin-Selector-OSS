-- Copyright (C) 2026 Luiz-AVcruz. AGPL-3.0-or-later; see ADDITIONAL-PERMISSION.
OSS = {version = "1.2.0", root = "savegame.mod.openskinselector.", catalog = {}, byId = {}}

function OSS.autoRestore()
    local key=OSS.root.."auto_restore"
    return not HasKey(key) or GetBool(key)
end

function OSS.validShortcut(key)
    if type(key)~="string" then return false end
    local reserved={w=true,a=true,s=true,d=true,q=true,z=true,e=true,r=true}
    if reserved[key] then return false end
    if key:match("^[a-z0-9]$") or key=="insert" or key=="home" or key=="end" then return true end
    for i=1,12 do if key=="f"..i then return true end end
    return false
end

function OSS.integer(value, minimum)
    return type(value) == "number" and value == value and value < 2147483647
        and value >= (minimum or 0) and value == math.floor(value)
end

function OSS.validId(id)
    return type(id) == "string" and #id > 0 and #id <= 256
        and not id:find("[%z\1-\31\127/\\]")
end

function OSS.clean(value, fallback)
    if value:sub(1,4) == "loc@" then value = GetTranslatedStringByKey(value:sub(5), fallback or "") end
    value = value:gsub("<[^>]*>", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
    return value ~= "" and value or (fallback or "")
end

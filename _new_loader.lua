-- OxideUiLibary2 minimal loader
-- Loads UiLibary/Libary.lua, then the correct game script for the PlaceId.
local LIB_URL = "https://codeberg.org/xulfo/OxideUiLibary2/raw/branch/main/UiLibary/Libary.lua"
local SCRIPTS_BASE = "https://codeberg.org/xulfo/OxideUiLibary2/raw/branch/main/scripts/"

local function FetchText(url)
    local sep = string.find(url, "?", 1, true) and "&" or "?"
    url = url .. sep .. "t=" .. tostring(os.time()) .. tostring(math.random(100000, 999999))
    local ok, src = pcall(game.HttpGet, game, url)
    if ok and type(src) == "string" and #src >= 100 then
        return true, src
    end
    return false, nil
end

local function LoadLibrary()
    local ok, b64 = FetchText(LIB_URL)
    if not ok then
        error("[Loader] Failed to download UiLibary/Libary.lua", 0)
    end
    local chunk, compileErr = loadstring(b64)
    if not chunk then
        error("[Loader] UiLibary/Libary.lua compile error: " .. tostring(compileErr), 0)
    end
    local ok2, lib = pcall(chunk)
    if not ok2 then
        error("[Loader] UiLibary/Libary.lua execution error: " .. tostring(lib), 0)
    end
    if type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
        error("[Loader] UiLibary/Libary.lua loaded but has no CreateWindow.", 0)
    end
    return lib
end

local function LoadGameScript(lib, scriptName)
    local url = SCRIPTS_BASE .. scriptName
    local ok, content = FetchText(url)
    if not ok then
        error("[Loader] Failed to download game script: " .. scriptName, 0)
    end
    local fullSource = "Library = _G.OxideLib;\n" .. content
    local chunk, compileErr = loadstring(fullSource)
    if not chunk then
        error("[Loader] Game script compile error (" .. scriptName .. "): " .. tostring(compileErr), 0)
    end
    local ok2, err = pcall(chunk)
    if not ok2 then
        error("[Loader] Game script runtime error (" .. scriptName .. "): " .. tostring(err), 0)
    end
end

local GAME_MAP = {
    [83038462357724]   = "GrabenUndReinigen.lua",
    [94640181989498]   = "GrowAChickenFighter.lua",
    [107778070777162]  = "StealAnEgg.lua",
    [100068273119174]  = "LeafSimulator.lua",
    [2788229376]       = "DaHood.lua",
    [142823291]        = "Mm2.lua",
    [106484206883664]  = "DungeonLootr.lua",
    [126870639873289]  = "JumpForPets.lua",
}

local PREMIUM_ONLY = {
    [128736949265057] = "Gakuran.lua",
}

local function ResolveScript(pid)
    return GAME_MAP[pid] or "Universal.lua"
end

local placeId = game.PlaceId
local scriptName = ResolveScript(placeId)

if PREMIUM_ONLY[placeId] then
    warn("[Loader] " .. PREMIUM_ONLY[placeId] .. " is premium-only.")
    return
end

local Library = LoadLibrary()
_G.OxideLib = Library
LoadGameScript(Library, scriptName)

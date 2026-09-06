-- ══════════════════════════════════════════════════════════════════════════════
-- OXIDE HUB — PREMIUM ScriptLoader (paid access)
-- Loaded by PremiumGate.lua AFTER a valid key + HWID check succeeded.
-- Same logic as the free loader, but maps the PREMIUM games too (Gakuran is
-- premium-only — it is NOT in the free ScriptLoader).
-- ══════════════════════════════════════════════════════════════════════════════

local CFG = {
    LIB_URL  = "https://raw.githubusercontent.com/xulfo/OxideUiLibary2/main/UiLibary/Libary.lua",
    SCRIPTS_BASE = "https://raw.githubusercontent.com/xulfo/OxideUiLibary2/main/scripts",
    FALLBACK  = "Universal.lua",
}

-- Free games + premium games. Gakuran [128736949265057] = premium-only.
local GAME_MAP = {
    [83038462357724]   = "GrabenUndReinigen.lua",   -- Graben und reinigen 🧼
    [94640181989498]   = "GrowAChickenFighter.lua", -- Grow a Chicken Fighter 🐔
    [107778070777162]  = "StealAnEgg.lua",          -- Ein Ei stehlen 🥚
    [100068273119174]  = "LeafSimulator.lua",       -- Leaf Simulator
    [128736949265057]  = "Gakuran.lua",             -- Gakuran (PREMIUM)
}

local function FetchText(url)
    local sep = string.find(url, "?", 1, true) and "&" or "?"
    url = url .. sep .. "t=" .. tostring(os.time()) .. tostring(math.random(100000, 999999))

    if type(request) == "function" then
        local ok, req = pcall(request, { Url = url, Method = "GET" })
        if ok and type(req) == "table" and req.StatusCode == 200
            and type(req.Body) == "string" and #req.Body >= 100 then
            return true, req.Body
        end
    end
    local ok, src = pcall(game.HttpGet, game, url)
    if ok and type(src) == "string" and #src >= 100 then
        return true, src
    end
    return false, nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LOAD LIBRARY (download raw source → loadstring → execute)
-- Now fully open source: the library is served as plain Lua, no encryption.
-- ══════════════════════════════════════════════════════════════════════════════
local function LoadLibrary()
    local ok, source = FetchText(CFG.LIB_URL)
    if not ok then
        error("[PremiumLoader] Failed to download library source.", 0)
    end

    local chunk, compileErr = loadstring(source)
    if not chunk then
        error("[PremiumLoader] Library compile error: " .. tostring(compileErr), 0)
    end

    local ok2, lib = pcall(chunk)
    if not ok2 then
        error("[PremiumLoader] Library execution error: " .. tostring(lib), 0)
    end

    if type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
        error("[PremiumLoader] Library loaded but has no CreateWindow.", 0)
    end

    return lib
end

local function LoadGameScript(lib, scriptName)
    local url = CFG.SCRIPTS_BASE .. "/" .. scriptName
    local ok, content = FetchText(url)
    if not ok then
        error("[PremiumLoader] Failed to download game script: " .. scriptName, 0)
    end

    -- Global library binding (keeps Gakuran under Luau's 200-local register limit).
    local fullSource = "Library = _G.OxideLib;\n" .. content

    local chunk, compileErr = loadstring(fullSource)
    if not chunk then
        error("[PremiumLoader] Game script compile error (" .. scriptName .. "): " .. tostring(compileErr), 0)
    end

    local ok2, err = pcall(chunk)
    if not ok2 then
        error("[PremiumLoader] Game script runtime error (" .. scriptName .. "): " .. tostring(err), 0)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- MAIN
-- ══════════════════════════════════════════════════════════════════════════════
-- Universe (GameId) → script: supports every place under a game universe.
local GAME_MAP_BY_GAMEID = {
}

local placeId = game.PlaceId
local gameId = game.GameId
local scriptName = GAME_MAP[placeId] or GAME_MAP_BY_GAMEID[gameId]

print("[PremiumLoader] PlaceId:", placeId, " GameId:", gameId, "→", scriptName or "NOT SUPPORTED")

if not scriptName then
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    pcall(function()
        lp:Kick("OXIDE Premium: This game has no premium script yet.")
    end)
    return
end

print("[PremiumLoader] Downloading library...")

local Library = LoadLibrary()

_G.OxideLib = Library

print("[PremiumLoader] Library loaded. Downloading game script: " .. scriptName .. "...")
LoadGameScript(Library, scriptName)

print("[PremiumLoader] " .. scriptName .. " is now running.")

-- ══════════════════════════════════════════════════════════════════════════════
-- OXIDE HUB — PREMIUM ScriptLoader (paid access)
-- Loaded by PremiumGate.lua AFTER a valid key + HWID check succeeded.
-- Same logic as the free loader, but maps the PREMIUM games too (Gakuran is
-- premium-only — it is NOT in the free ScriptLoader).
-- ══════════════════════════════════════════════════════════════════════════════

local CFG = {
    LIB_URL  = "https://raw.githubusercontent.com/xulfo/OxideUiLibary2/main/lib.enc",
    LIB_KEY  = "Buffy-Lib-2026-XyZ!",
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

local function b64decode(s)
    local map, alphabet = {}, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, #alphabet do map[alphabet:sub(i, i)] = i - 1 end
    local out, n = {}, 0
    for i = 1, #s, 4 do
        local a, b = map[s:sub(i, i)], map[s:sub(i + 1, i + 1)]
        local c, d = map[s:sub(i + 2, i + 2)], map[s:sub(i + 3, i + 3)]
        if a and b then
            n = n + 1; out[n] = string.char(a * 4 + math.floor(b / 16))
            if c then
                n = n + 1; out[n] = string.char((b % 16) * 16 + math.floor(c / 4))
                if d then
                    n = n + 1; out[n] = string.char((c % 4) * 64 + d)
                end
            end
        end
    end
    return table.concat(out)
end

local function xorDecrypt(b64, key)
    local data = b64decode(b64)
    local out, kl = {}, #key
    for i = 1, #data do
        out[i] = string.char(bit32.bxor(data:byte(i), key:byte(((i - 1) % kl) + 1)))
    end
    return table.concat(out)
end

local function LoadLibrary()
    local ok, b64 = FetchText(CFG.LIB_URL)
    if not ok then
        error("[PremiumLoader] Failed to download library blob from Codeberg.", 0)
    end

    local source = xorDecrypt(b64, CFG.LIB_KEY)
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

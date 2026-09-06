-- ══════════════════════════════════════════════════════════════════════════════
-- OXIDE HUB — Universal ScriptLoader (free)
-- Checks game.PlaceId → loads library ONCE → downloads & runs the right script.
-- Fully open source: everything is plain Lua on GitHub, no encryption.
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════════════
local CFG = {
    LIB_URL      = "https://raw.githubusercontent.com/xulfo/OxideUiLibary2/main/UiLibary/Libary.lua",
    -- Base URL for stripped game scripts (github raw).
    SCRIPTS_BASE = "https://raw.githubusercontent.com/xulfo/OxideUiLibary2/main/scripts/",
    -- Fallback script when PlaceId doesn't match any known game
    FALLBACK  = "Universal.lua",
}

-- Pretty game names shown on the statistics page (fallback = script name).
local GAME_NAMES = {
    [83038462357724]   = "Graben und reinigen",
    [94640181989498]   = "Grow a Chicken Fighter",
    [107778070777162]  = "Steal an Egg",
    [100068273119174]  = "Leaf Simulator",
    [2788229376]       = "Da Hood",
    [142823291]        = "MM2",
    [106484206883664]  = "DungeonLootr.lua",
    [126870639873289]  = "JumpForPets.lua",
}

-- Always use the stable public library.

-- ══════════════════════════════════════════════════════════════════════════════
-- STATS TRACKING — fire-and-forget, never blocks or errors the load
-- ══════════════════════════════════════════════════════════════════════════════
local function urlencode(s)
    return (string.gsub(tostring(s), "[^%w%-%_%.%~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function GetUserId()
    local ok, plr = pcall(function() return game:GetService("Players").LocalPlayer end)
    if ok and plr then
        local o2, uid = pcall(function() return plr.UserId end)
        if o2 then return tostring(uid) end
    end
    return ""
end

local function GetExecutor()
    local ok, name = pcall(identifyexecutor)
    if ok and type(name) == "string" then return name end
    return ""
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PLACE-ID → SCRIPT MAPPING
-- Add new games here: [PlaceId] = "ScriptName.lua"
-- ══════════════════════════════════════════════════════════════════════════════
-- Declared BEFORE Track so Track's closure captures it as an upvalue (a local
-- declared later would resolve to the nil global instead).
local GAME_MAP = {
    [83038462357724]   = "GrabenUndReinigen.lua",   -- Graben und reinigen 🧼
    [94640181989498]   = "GrowAChickenFighter.lua", -- Grow a Chicken Fighter 🐔
    [107778070777162]  = "StealAnEgg.lua",          -- Ein Ei stehlen 🥚
    [100068273119174]  = "LeafSimulator.lua",       -- 🍂 Spiel (Leaf Simulator)
    [2788229376]       = "DaHood.lua",              -- Da Hood 🏙️
    [142823291]        = "Mm2.lua",                 -- MM2 🔪
    [106484206883664]  = "DungeonLootr.lua",        -- Dungeon-Lootr ⚔️
    [126870639873289]  = "JumpForPets.lua",
    -- [PlaceId] = "Script.lua",  ← füg neue Games hier hinzu
}

-- Universe (GameId) → script: catches EVERY place under a game, so new/other
-- places of the same universe don't fall back to Universal.lua.
local GAME_MAP_BY_GAMEID = {
    [9656201728] = "DungeonLootr.lua",              -- Dungeon-Lootr Universe ⚔️
    [10690360998] = "JumpForPets.lua",
    -- [GameId] = "Script.lua",
}

local function ResolveScript(pid, gid)
    return GAME_MAP[pid] or GAME_MAP_BY_GAMEID[gid] or CFG.FALLBACK
end

-- Track resolves placeId/scriptName itself (self-contained, correct at call
-- time even though MAIN declares its own locals later).
local function Track(kind)
    if not CFG.TRACK_URL then return end
    local pid = game.PlaceId
    local gid = game.GameId
    local sname = ResolveScript(pid, gid)
    local params = {
        kind = kind,
        game = GAME_NAMES[pid] or sname:gsub("%.lua$", ""),
        place_id = tostring(pid),
        game_id = tostring(gid),
        user_id = GetUserId(),
        executor = GetExecutor(),
    }
    local parts = {}
    for k, v in pairs(params) do
        parts[#parts + 1] = k .. "=" .. urlencode(v)
    end
    local url = CFG.TRACK_URL .. "?" .. table.concat(parts, "&")
    pcall(function()
        if type(request) == "function" then
            request({ Url = url, Method = "GET" })
        else
            game:HttpGet(url)
        end
    end)
end

-- Games that are NOT part of the free hub — they need a paid key (PremiumGate).
local PREMIUM_ONLY = {
    [128736949265057] = "Gakuran.lua", -- Gakuran 🥋 (premium-only)
}

-- ══════════════════════════════════════════════════════════════════════════════
-- FETCH: downloads a text file from a URL (tries request() then game.HttpGet)
-- ══════════════════════════════════════════════════════════════════════════════
local function FetchText(url)
    -- Cache-bust so the CDN never serves a stale script.
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
        error("[Loader] Failed to download library source.", 0)
    end

    local chunk, compileErr = loadstring(source)
    if not chunk then
        error("[Loader] Library compile error: " .. tostring(compileErr), 0)
    end

    local ok2, lib = pcall(chunk)
    if not ok2 then
        error("[Loader] Library execution error: " .. tostring(lib), 0)
    end

    if type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
        error("[Loader] Library loaded but has no CreateWindow.", 0)
    end

    return lib
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LOAD GAME SCRIPT (download → prepend Library shim → execute)
-- ══════════════════════════════════════════════════════════════════════════════
local function LoadGameScript(lib, scriptName)
    local url = CFG.SCRIPTS_BASE .. scriptName
    local ok, content = FetchText(url)
    if not ok then
        error("[Loader] Failed to download game script: " .. scriptName, 0)
    end

    -- Use a global library binding here. Some scripts are close to Luau's
    -- 200-local register limit, so adding another local in the loader can make
    -- the stripped chunk fail before its UI is created.
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

-- ══════════════════════════════════════════════════════════════════════════════
-- MAIN
-- ══════════════════════════════════════════════════════════════════════════════
local placeId = game.PlaceId
local gameId = game.GameId
local scriptName = ResolveScript(placeId, gameId)

if PREMIUM_ONLY[placeId] then
    print("[Loader] " .. PREMIUM_ONLY[placeId] .. " is premium-only — load PremiumGate.lua with a key instead.")
    return
end

print("[Loader] PlaceId:", placeId, " GameId:", gameId, "→", scriptName)
print("[Loader] Downloading library...")

local Library = LoadLibrary()

-- Expose globally (stripped scripts grab it via local Library = _G.OxideLib)
_G.OxideLib = Library

print("[Loader] Library loaded. Downloading game script: " .. scriptName .. "...")
LoadGameScript(Library, scriptName)

-- Report the successful load, then keep a heartbeat alive for the Live tab.
Track("launch")
pcall(task.spawn, function()
    while true do
        task.wait(25)
        Track("heartbeat")
    end
end)

print("[Loader] " .. scriptName .. " is now running.")

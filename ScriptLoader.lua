-- ══════════════════════════════════════════════════════════════════════════════
-- OXIDE HUB — Universal ScriptLoader (free)
-- Checks game.PlaceId → loads library ONCE → downloads & runs the right script.
-- Fully open source: everything is plain Lua on GitHub, no encryption.
--
-- FAST + STALE-PROOF:
--  * Downloads are cached for 5 minutes per session, so re-running the script
--    is instant instead of re-downloading ~250 KB every time.
--  * GitHub's raw CDN can briefly serve an old copy right after an upload.
--    Every library download is verified against a marker ("ChatFree", present
--    only in the current build) and a stale copy is re-fetched with a fresh
--    cache-buster until the current build arrives — a stale library is NEVER
--    executed, so the old chat-era hub can never come back.
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
    [126870639873289]  = "Jump for Pets",
    [128736949265057]  = "Gakuran",
    [108628039999641]  = "Search For The Needle",
    [77108422251420]   = "Search For The Needle",
    [17625359962]      = "RIVALS",
}

-- Always use the stable public library.

-- ══════════════════════════════════════════════════════════════════════════════
-- CACHE + STALE-PROTECTION
-- ══════════════════════════════════════════════════════════════════════════════
local LIB_MARKER  = "ChatFree"   -- marker string that ONLY exists in the current (chat-free) library build
local CACHE_TTL   = 300          -- seconds a downloaded file is reused before a refresh

-- Session-wide download cache (survives re-executions of this script).
local OXIDE_CACHE = _G.OxideLoaderCache or {}
_G.OxideLoaderCache = OXIDE_CACHE

local function cacheGet(key)
    local entry = OXIDE_CACHE[key]
    if entry and os.clock() - entry.at <= CACHE_TTL then
        return entry.value
    end
    return nil
end
local function cacheSet(key, value)
    OXIDE_CACHE[key] = { at = os.clock(), value = value }
end

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
    [126870639873289]  = "JumpForPets.lua",         -- Jump for Pets 🐾
    [128736949265057]  = "Gakuran.lua",             -- Gakuran 🥋
    [108628039999641]  = "NeedleHaystack.lua",      -- Search For The Needle (Kapitel 1: Bauernhaus) 🌾
    [77108422251420]   = "NeedleHaystack.lua",      -- Search For The Needle (root place) 🌾
    [17625359962]      = "Rivals.lua",              -- RIVALS 🔫
    -- [PlaceId] = "Script.lua",  ← füg neue Games hier hinzu
}

-- Universe (GameId) → script: catches EVERY place under a game, so new/other
-- places of the same universe don't fall back to Universal.lua.
local GAME_MAP_BY_GAMEID = {
    [9656201728] = "DungeonLootr.lua",              -- Dungeon-Lootr Universe ⚔️
    [10690360998] = "JumpForPets.lua",
    [10756011174] = "NeedleHaystack.lua",           -- Search For The Needle Universe 🌾 (catches every chapter place)
    [6035872082]  = "Rivals.lua",                    -- RIVALS Universe 🔫
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

-- ══════════════════════════════════════════════════════════════════════════════
-- FETCH: downloads a text file from a URL (tries request() then game.HttpGet)
-- ══════════════════════════════════════════════════════════════════════════════
local function FetchRaw(url)
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

local function CacheBust(url)
    local sep = string.find(url, "?", 1, true) and "&" or "?"
    return url .. sep .. "cb=" .. tostring(os.time()) .. tostring(math.random(100000, 999999))
end

-- GitHub's raw CDN can keep serving a stale copy for a while after an upload,
-- and it ignores cache-busters and client Cache-Control headers. The GitHub
-- contents API (api.github.com) is never CDN-cached, so it always returns the
-- newest commit — it is used as the final, guaranteed-fresh fallback.
local function FetchApiRaw(apiPath)
    if type(request) ~= "function" then return false, nil end
    local ok, req = pcall(request, {
        Url = "https://api.github.com/repos/xulfo/OxideUiLibary2/contents/" .. apiPath,
        Method = "GET",
        Headers = {
            ["Accept"]     = "application/vnd.github.raw+json",
            ["User-Agent"] = "oxide-hub",
        },
    })
    if ok and type(req) == "table" and req.StatusCode == 200
        and type(req.Body) == "string" and #req.Body >= 100 then
        return true, req.Body
    end
    return false, nil
end

-- Fetch a file, refusing anything that lacks `marker` (i.e. a stale CDN copy).
-- Attempt 1 uses the plain URL (fast edge-cache hit), attempts 2-3 retry with
-- a cache-buster while the CDN refreshes, and the last resort is the fresh
-- contents-API fallback. A stale body is NEVER returned.
-- Returns: ok, body, attempt (4 = came from the API fallback)
local function FetchFresh(url, marker, minBytes, apiPath)
    minBytes = minBytes or 100
    for attempt = 1, 3 do
        local target = attempt == 1 and url or CacheBust(url)
        local ok, body = FetchRaw(target)
        if ok and #body >= minBytes and (marker == nil or string.find(body, marker, 1, true)) then
            return true, body, attempt
        end
        if attempt < 3 then task.wait(1) end
    end
    if apiPath then
        local ok, body = FetchApiRaw(apiPath)
        if ok and #body >= minBytes and (marker == nil or string.find(body, marker, 1, true)) then
            return true, body, 4
        end
    end
    return false, nil, 4
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LOAD LIBRARY (download raw source → loadstring → execute)
-- Now fully open source: the library is served as plain Lua, no encryption.
-- ══════════════════════════════════════════════════════════════════════════════
local function LibraryUsable(lib)
    return type(lib) == "table"
        and type(lib.CreateWindow) == "function"
        and lib.ChatFree == true      -- only the current chat-free build is accepted
end

local function LoadLibrary()
    -- Fast path: reuse a chat-free library already fetched this session, so
    -- re-running the hub costs zero downloads.
    local cached = cacheGet("lib")
    if LibraryUsable(cached) then
        print("[Loader] Library reused from cache (v" .. tostring(cached.Version or "?") .. ") — no download needed.")
        return cached
    end

    local ok, source, attempt = FetchFresh(CFG.LIB_URL, LIB_MARKER, 50000, "UiLibary/Libary.lua")
    if not ok then
        error("[Loader] Could not fetch the CURRENT UI library — GitHub's CDN is still serving the old build. Re-run the script in a few seconds.", 0)
    end

    local chunk, compileErr = loadstring(source)
    if not chunk then
        error("[Loader] Library compile error: " .. tostring(compileErr), 0)
    end
    local ok2, lib = pcall(chunk)
    if not ok2 then
        error("[Loader] Library execution error: " .. tostring(lib), 0)
    end
    if not LibraryUsable(lib) then
        error("[Loader] Library loaded but it is NOT the current chat-free build (stale copy). Refusing to run it — re-run the script.", 0)
    end

    cacheSet("lib", lib)
    if attempt >= 4 then
        print("[Loader] CDN served a stale copy — fetched the current library from the fresh API fallback.")
    elseif attempt > 1 then
        print("[Loader] CDN served a stale copy — refetched the current library (attempt " .. attempt .. ").")
    end
    print("[Loader] Library v" .. tostring(lib.Version or "?") .. " ready.")
    return lib
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LOAD GAME SCRIPT (download → prepend Library shim → execute)
-- ══════════════════════════════════════════════════════════════════════════════
local function LoadGameScript(lib, scriptName)
    local content = cacheGet("script:" .. scriptName)
    local fromCache = content ~= nil
    if not fromCache then
        local url = CFG.SCRIPTS_BASE .. scriptName
        local ok, body = FetchFresh(url, nil, 2000, "scripts/" .. scriptName)
        if not ok then
            error("[Loader] Failed to download game script: " .. scriptName, 0)
        end
        content = body
        cacheSet("script:" .. scriptName, content)
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
    return fromCache
end

-- ══════════════════════════════════════════════════════════════════════════════
-- MAIN
-- ══════════════════════════════════════════════════════════════════════════════
local placeId = game.PlaceId
local gameId = game.GameId
local scriptName = ResolveScript(placeId, gameId)

print("[Loader] PlaceId:", placeId, " GameId:", gameId, "→", scriptName)

local t0 = os.clock()
local Library = LoadLibrary()

-- Expose globally (stripped scripts grab it via local Library = _G.OxideLib)
_G.OxideLib = Library

local scriptCached = LoadGameScript(Library, scriptName)
print(string.format("[Loader] %s is now running (script %s, total %.2fs).",
    scriptName, scriptCached and "from cache" or "downloaded", os.clock() - t0))

-- Report the successful load, then keep a heartbeat alive for the Live tab.
Track("launch")
pcall(task.spawn, function()
    while true do
        task.wait(25)
        Track("heartbeat")
    end
end)

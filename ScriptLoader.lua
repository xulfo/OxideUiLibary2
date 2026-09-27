-- ══════════════════════════════════════════════════════════════════════════════
-- ARC HUB — Universal ScriptLoader (free)
-- Checks game.PlaceId → loads library ONCE → downloads & runs the right script.
-- Fully open source: everything is plain Lua on GitHub, no encryption.
--
-- FIRST 15 SECONDS:
--  * Every run opens with the Arc Discord invite screen (invite link + a copy
--    button). The library is downloaded in the background while that screen is
--    up, so the hub script starts the moment the countdown ends.
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
    -- Community invite shown on the startup screen (the copy button copies it).
    DISCORD_INVITE = "https://discord.gg/bbYM8kcaZd",
    -- How long the invite screen stays up before the hub script loads (seconds).
    DISCORD_GATE_SECONDS = 15,
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
local ARC_CACHE = _G.ArcLoaderCache or {}
_G.ArcLoaderCache = ARC_CACHE

local function cacheGet(key)
    local entry = ARC_CACHE[key]
    if entry and os.clock() - entry.at <= CACHE_TTL then
        return entry.value
    end
    return nil
end
local function cacheSet(key, value)
    ARC_CACHE[key] = { at = os.clock(), value = value }
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
    [124216119978534]  = "RideAPet.lua",            -- Reite ein Haustier 🐣
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
            ["User-Agent"] = "arc-hub",
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
    local fullSource = "Library = _G.ArcLib;\n" .. content

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
-- DISCORD GATE — the invite screen shown before anything is loaded
-- Built with plain Instance.new calls on purpose: it runs BEFORE the library is
-- downloaded, so it cannot use the hub's UI helpers. It can never block a run
-- either — if the UI cannot be built, the gate is skipped and the hub starts.
-- ══════════════════════════════════════════════════════════════════════════════
local GATE_COLORS = {
    CardBg   = Color3.fromRGB(24, 24, 24),
    Border   = Color3.fromRGB(35, 35, 35),
    Element  = Color3.fromRGB(31, 31, 31),
    White    = Color3.fromRGB(255, 255, 255),
    Gray     = Color3.fromRGB(154, 154, 154),
    Dim      = Color3.fromRGB(139, 139, 139),
    Accent   = Color3.fromRGB(240, 240, 240),
    OnAccent = Color3.fromRGB(12, 12, 12),
    Success  = Color3.fromRGB(105, 166, 124),
    Error    = Color3.fromRGB(190, 99, 99),
}
local GATE_LOGO = "rbxassetid://131675609143159"   -- the same mark as the hub's brand card

local function CopyToClipboard(text)
    local fn = setclipboard or toclipboard or writeclipboard
    if type(fn) ~= "function" and type(syn) == "table" and type(syn.write_clipboard) == "function" then
        fn = syn.write_clipboard
    end
    if type(fn) ~= "function" then return false end
    return (pcall(fn, text))
end

local function GateParent()
    local target
    pcall(function()
        target = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if not target then
        local ok, plr = pcall(function() return game:GetService("Players").LocalPlayer end)
        if ok and plr then
            local ok2, pg = pcall(function() return plr:WaitForChild("PlayerGui", 5) end)
            if ok2 then target = pg end
        end
    end
    return target
end

-- Blocks for `seconds`, then removes itself. `state` is the background library
-- download; it only feeds the status line.
local function ShowDiscordGate(seconds, invite, state)
    seconds = tonumber(seconds) or 0
    invite  = tostring(invite or "https://discord.gg/")
    if seconds <= 0 then return end

    -- Never stack gates when the loader is executed again mid-countdown.
    local stale = _G.ArcDiscordGate
    _G.ArcDiscordGate = nil
    if stale then
        pcall(function() stale:Destroy() end)
    end

    local built = pcall(function()
        local TweenService = game:GetService("TweenService")
        local Lighting     = game:GetService("Lighting")

        local parent = GateParent()
        if not parent then error("no gui parent") end

        local function mk(class, props)
            local inst = Instance.new(class)
            for k, v in pairs(props) do
                if k ~= "Parent" then
                    inst[k] = v
                end
            end
            inst.Parent = props.Parent
            return inst
        end

        local cardClass = "Frame"
        if pcall(function() return Instance.new("CanvasGroup") end) then
            cardClass = "CanvasGroup"
        end

        local gui = mk("ScreenGui", {
            Name = "ArcDiscordGate",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            DisplayOrder = 1000,
            Parent = parent,
        })
        _G.ArcDiscordGate = gui

        local blur = Instance.new("BlurEffect")
        blur.Name = "ArcGateBlur"
        blur.Size = 0
        blur.Parent = Lighting

        local backdrop = mk("Frame", {
            Name = "Backdrop",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 1,
            ZIndex = 1,
            Parent = gui,
        })

        local card = mk(cardClass, {
            Name = "Card",
            Size = UDim2.fromOffset(404, 292),
            Position = UDim2.new(0.5, 0, 0.5, 20),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = GATE_COLORS.CardBg,
            BackgroundTransparency = 0,
            ZIndex = 2,
            Parent = gui,
        })
        if card:IsA("CanvasGroup") then
            card.GroupTransparency = 0
        end
        mk("UICorner", { CornerRadius = UDim.new(0, 14), Parent = card })
        mk("UIStroke", {
            Color = GATE_COLORS.Border,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = card,
        })

        -- Brand row
        local logoHolder = mk("Frame", {
            Position = UDim2.fromOffset(18, 18),
            Size = UDim2.fromOffset(44, 44),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            ZIndex = 3,
            Parent = card,
        })
        mk("ImageLabel", {
            Image = GATE_LOGO,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1.12, 1.12),
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 3,
            Parent = logoHolder,
        })
        mk("TextLabel", {
            Text = "ARC HUB",
            Font = Enum.Font.GothamBold,
            TextSize = 15,
            TextColor3 = GATE_COLORS.White,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(74, 22),
            Size = UDim2.new(1, -92, 0, 16),
            ZIndex = 3,
            Parent = card,
        })
        mk("TextLabel", {
            Text = "Community · Support · Updates",
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = GATE_COLORS.Dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(74, 40),
            Size = UDim2.new(1, -92, 0, 14),
            ZIndex = 3,
            Parent = card,
        })
        mk("Frame", {
            Position = UDim2.fromOffset(18, 76),
            Size = UDim2.new(1, -36, 0, 1),
            BackgroundColor3 = GATE_COLORS.Border,
            ZIndex = 3,
            Parent = card,
        })

        -- Invite copy area
        mk("TextLabel", {
            Text = "Join our Discord",
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = GATE_COLORS.White,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(18, 90),
            Size = UDim2.new(1, -36, 0, 16),
            ZIndex = 3,
            Parent = card,
        })
        mk("TextLabel", {
            Text = "Copy the invite below and open it in your browser to get support, updates and new scripts.",
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = GATE_COLORS.Dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(18, 110),
            Size = UDim2.new(1, -36, 0, 30),
            ZIndex = 3,
            Parent = card,
        })

        local inviteBox = mk("Frame", {
            Position = UDim2.fromOffset(18, 148),
            Size = UDim2.new(1, -36, 0, 38),
            BackgroundColor3 = GATE_COLORS.Element,
            ZIndex = 3,
            Parent = card,
        })
        mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = inviteBox })
        mk("UIStroke", {
            Color = GATE_COLORS.Border,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = inviteBox,
        })
        mk("TextLabel", {
            Text = invite,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextColor3 = GATE_COLORS.Gray,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 4,
            Parent = inviteBox,
        })

        local copyBtn = mk("TextButton", {
            Text = "Copy Discord Invite",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = GATE_COLORS.OnAccent,
            BackgroundColor3 = GATE_COLORS.Accent,
            AutoButtonColor = false,
            Position = UDim2.fromOffset(18, 196),
            Size = UDim2.new(1, -36, 0, 38),
            ZIndex = 3,
            Parent = card,
        })
        mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = copyBtn })

        -- Countdown
        local statusLbl = mk("TextLabel", {
            Text = "The hub loads in " .. tostring(math.floor(seconds)) .. "s",
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = GATE_COLORS.Dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(18, 244),
            Size = UDim2.new(1, -36, 0, 14),
            ZIndex = 3,
            Parent = card,
        })
        local barTrack = mk("Frame", {
            Position = UDim2.fromOffset(18, 266),
            Size = UDim2.new(1, -36, 0, 4),
            BackgroundColor3 = GATE_COLORS.Element,
            ZIndex = 3,
            Parent = card,
        })
        mk("UICorner", { CornerRadius = UDim.new(0, 2), Parent = barTrack })
        local barFill = mk("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = GATE_COLORS.Accent,
            ZIndex = 4,
            Parent = barTrack,
        })
        mk("UICorner", { CornerRadius = UDim.new(0, 2), Parent = barFill })

        local copied = false
        copyBtn.MouseEnter:Connect(function()
            if not copied then
                TweenService:Create(copyBtn, TweenInfo.new(0.15), { BackgroundTransparency = 0.12 }):Play()
            end
        end)
        copyBtn.MouseLeave:Connect(function()
            if not copied then
                TweenService:Create(copyBtn, TweenInfo.new(0.15), { BackgroundTransparency = 0 }):Play()
            end
        end)
        copyBtn.MouseButton1Click:Connect(function()
            if CopyToClipboard(invite) then
                copied = true
                copyBtn.Text = "Invite copied to your clipboard"
                copyBtn.BackgroundColor3 = GATE_COLORS.Success
                copyBtn.TextColor3 = GATE_COLORS.White
                copyBtn.BackgroundTransparency = 0
            else
                copyBtn.Text = "Clipboard blocked - copy: " .. invite
                copyBtn.TextSize = 11
                copyBtn.BackgroundColor3 = GATE_COLORS.Error
                copyBtn.TextColor3 = GATE_COLORS.White
            end
        end)

        TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
        TweenService:Create(blur, TweenInfo.new(0.25), { Size = 16 }):Play()
        TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.fromScale(0.5, 0.5),
        }):Play()

        local startedAt = os.clock()
        while true do
            local elapsed = os.clock() - startedAt
            if elapsed >= seconds then break end
            barFill.Size = UDim2.new(math.clamp(elapsed / seconds, 0, 1), 0, 1, 0)
            local ready = (state and state.done) and " - hub ready" or ""
            statusLbl.Text = string.format("The hub loads in %.1fs%s", math.max(seconds - elapsed, 0), ready)
            task.wait()
        end
        barFill.Size = UDim2.new(1, 0, 1, 0)
        if state and not state.done then
            statusLbl.Text = "Finishing the download..."
        else
            statusLbl.Text = "Starting the hub..."
        end

        local fade = TweenInfo.new(0.3, Enum.EasingStyle.Quad)
        TweenService:Create(backdrop, fade, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(blur, fade, { Size = 0 }):Play()
        if card:IsA("CanvasGroup") then
            TweenService:Create(card, fade, { GroupTransparency = 1 }):Play()
            task.wait(0.3)
        end
        if _G.ArcDiscordGate == gui then
            _G.ArcDiscordGate = nil
        end
        pcall(function() gui:Destroy() end)
        pcall(function() blur:Destroy() end)
    end)

    if not built then
        -- The screen could not be built: clean up and never block the load.
        pcall(function()
            local gui = _G.ArcDiscordGate
            _G.ArcDiscordGate = nil
            if gui then gui:Destroy() end
            local Lighting = game:GetService("Lighting")
            for _, child in ipairs(Lighting:GetChildren()) do
                if child.Name == "ArcGateBlur" then child:Destroy() end
            end
        end)
    end
end

-- Waits for the library download that was started before the gate.
local function CollectLibrary(state)
    local waited = 0
    while not state.done and waited < 30 do
        task.wait(0.1)
        waited = waited + 0.1
    end
    if not state.done then
        return LoadLibrary()
    end
    if not state.ok then
        error(state.value, 0)
    end
    return state.value
end

-- ══════════════════════════════════════════════════════════════════════════════
-- MAIN
-- ══════════════════════════════════════════════════════════════════════════════
local placeId = game.PlaceId
local gameId = game.GameId
local scriptName = ResolveScript(placeId, gameId)

print("[Loader] PlaceId:", placeId, " GameId:", gameId, "→", scriptName)

-- Download the library in the background so the invite screen doubles as the
-- loading time — the hub is ready the second the countdown ends.
local libState = { done = false, ok = false, value = nil }
pcall(task.spawn, function()
    local ok, res = pcall(LoadLibrary)
    libState.ok, libState.value, libState.done = ok, res, true
end)

ShowDiscordGate(CFG.DISCORD_GATE_SECONDS, CFG.DISCORD_INVITE, libState)

local t0 = os.clock()
local Library = CollectLibrary(libState)

-- Expose globally (stripped scripts grab it via local Library = _G.ArcLib)
_G.ArcLib = Library

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

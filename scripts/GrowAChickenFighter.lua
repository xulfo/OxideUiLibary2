-- ═══ HUB STRIP POINT — when deployed via the ScriptLoader the ScriptLoader injects
--     "local Library = _G.OxideLib" above this line instead. ═══
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- RE-EXECUTION GUARD + RESOURCE TRACKING
-- ══════════════════════════════════════════════════════════════════════════════
do
    local prev = _G.OxideChickenFighter
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, dead = false }
_G.OxideChickenFighter = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end

local Window = Library:CreateWindow({
    Name = "Oxide HUB | Chicken Fighter",
    LoadingAnimation = true,
    LoadingText = "Oxide",
    LoadingDuration = 2.5,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG / FLAG PERSISTENCE (Oxide UI v2.3+ flag system; feature-guarded)
-- ══════════════════════════════════════════════════════════════════════════════
local HAS_CONFIG  = type(Library.SaveConfig) == "function"
    and type(Library.LoadConfig) == "function"
    and type(Library.ListConfigs) == "function"
local CONFIG_NAME = "chickenfighter"

local dropdownResync = {}
local function registerResync(handle, applyFn)
    if handle and applyFn then
        table.insert(dropdownResync, function() applyFn(handle:Get()) end)
    end
end
local function ResyncAll()
    for _, fn in ipairs(dropdownResync) do pcall(fn) end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SERVICES / LOCALS
-- ══════════════════════════════════════════════════════════════════════════════
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local Workspace          = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local function Notify(title, content, kind, dur)
    pcall(function()
        Window:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = dur or 2.5 })
    end)
end

-- Wrap UI callbacks so a single error can never kill the whole script.
local function safeCallback(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            pcall(Notify, "Oxide HUB", "Error: " .. tostring(err), "Error", 4)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CHARACTER HELPERS
-- ══════════════════════════════════════════════════════════════════════════════
local function GetCharacter() return LocalPlayer.Character end
local function GetHumanoid()
    local c = GetCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function GetHRP()
    local c = GetCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SAFE MOVEMENT — the game added a server-side movement guard (GameConfig.guard):
--   teleport: flags any frame moving > 8 studs (absolute) or > 2.5 studs over
--             the expected travel distance (3 strikes = disconnect)
--   speed:    flags sustained speed above WalkSpeed 16 * 1.5 = 24 studs/s
--   fly:      flags staying airborne past tolerance for 2s
-- All old instant CFrame teleports now GLIDE at a safe speed so the position
-- delta per server sample always stays inside the guard's slack window.
-- ══════════════════════════════════════════════════════════════════════════════
local SAFE_WALK = 18   -- studs/s glide speed (well under the 24/s speed cap)

local function TeleportTo(pos)
    local hrp = GetHRP()
    local hum = GetHumanoid()
    if not hrp or not pos then return false end
    if HUB.dead then return false end

    local target = CFrame.new(pos + Vector3.new(0, 3, 0))
    -- Preserve the humanoid's own WalkSpeed; we drive the HRP ourselves below.
    local prevWS = hum and hum.WalkSpeed or SAFE_WALK
    if hum then pcall(function() hum.WalkSpeed = SAFE_WALK end) end

    local budget = 45
    while not HUB.dead and budget > 0 do
        local root = GetHRP()
        if not root then break end
        local toGo = target.Position - root.Position
        local dist = toGo.Magnitude
        if dist < 2 then
            root.CFrame = target
            break
        end
        local dt = RunService.Heartbeat:Wait()
        budget = budget - dt
        local step = math.min(SAFE_WALK * dt, dist)
        root.CFrame = CFrame.new(root.Position + toGo.Unit * step) * (root.CFrame - root.Position)
    end

    if hum then pcall(function() hum.WalkSpeed = prevWS end) end
    return true
end

-- ══════════════════════════════════════════════════════════════════════════════
-- GAME API — Remotes via direct ReplicatedStorage require (falls back to upvalue
-- extraction for restricted executors); data via DataController/DataService.
-- ══════════════════════════════════════════════════════════════════════════════
local Remotes, defs
local DataController, CoopController, DataClient
local GameConfig          -- ReplicatedStorage.Content.GameConfig (lazy)
local MissionView         -- ReplicatedStorage.Features.Missions.MissionView
local GAME_OK = false
local towerRunning = false

-- World event state (declared here so initGame's hooks can capture them)
local gooseEnabled   = true
local hotEggEnabled  = true
local lastGoosePos   = nil
local lastEggPos     = nil
local gooseQueue     = {}
local eggQueue       = {}

-- Egg tiers (verified from ReplicatedStorage.Content.Catalog.Eggs — all 17).
-- Ordered cheap → expensive; "Auto (Best)" hatches from the end of this list first.
local EGG_TIERS = {
    "barn", "feed", "charm", "diner", "storm", "circuit", "ordnance",
    "meme", "arena", "haunt", "void", "bloom", "crown", "fang", "golden",
    "hotEgg", "rival",
}
local EGG_NAMES = {
    barn = "Nest Egg",     feed = "Scratch Egg",   charm = "Charm Egg",
    diner = "Diner Egg",   storm = "Thunder Egg",  circuit = "Circuit Egg",
    ordnance = "Ordnance Egg", meme = "Cursed Egg", arena = "Arena Egg",
    haunt = "Haunt Egg",   void = "Void Egg",      bloom = "Bloom Egg",
    crown = "Royal Egg",   fang = "Fang Egg",      golden = "Fortune Egg",
    hotEgg = "Blazing Egg", rival = "Grudge Egg",
}

-- Rarity ladder (verified from the 135 Catalog chicken types).
local RARITY_ORDER = {
    common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5,
    mythic = 6, divine = 7, cosmic = 8, celestial = 9, secret = 10,
}
local RARITY_LIST = { "common", "uncommon", "rare", "epic", "legendary",
    "mythic", "divine", "cosmic", "celestial", "secret" }

-- Coop generators (verified from Catalog.generators). Slot N = tier N generator.
local GENERATORS = {
    { id = "corn_sack",    name = "Corn Sack",     tier = 1 },
    { id = "wood_feeder",  name = "Wooden Feeder", tier = 2 },
    { id = "silo",         name = "Silo",          tier = 3 },
    { id = "harvester",    name = "Harvester",     tier = 4 },
}
local COOP_MAX_SLOTS = #GENERATORS

local function isRemotesTable(v)
    return type(v) == "table" and type(v.invoke) == "function"
        and type(v.defs) == "table" and v.defs.HatchEgg ~= nil and v.defs.FuseChickens ~= nil
end

local function scanUpvalues(fn, depth, seen)
    depth = depth or 0
    if depth > 5 then return nil end
    seen = seen or {}
    if seen[fn] then return nil end
    seen[fn] = true
    for i = 1, 200 do
        local ok, v = pcall(debug.getupvalue, fn, i)
        if not ok or v == nil then break end
        if isRemotesTable(v) then return v end
        if type(v) == "function" then
            local r = scanUpvalues(v, depth + 1, seen)
            if r then return r end
        end
    end
    return nil
end

local function ExtractRemotes(mod)
    if type(mod) ~= "table" then return nil end
    for _, member in pairs(mod) do
        if type(member) == "function" then
            local r = scanUpvalues(member)
            if r then return r end
        end
    end
    return nil
end

local function HookEvent(remoteDef, cb)
    if not (Remotes and defs and remoteDef and cb) then return end
    pcall(function() Remotes.onClient(remoteDef, cb) end)
end

local function initGame()
    local LP = Players.LocalPlayer
    local ps = LP:WaitForChild("PlayerScripts")

    DataController = require(ps:WaitForChild("Core"):WaitForChild("Data"):WaitForChild("DataController"))
    CoopController = require(ps:WaitForChild("Features"):WaitForChild("Coop"):WaitForChild("CoopController"))

    pcall(function()
        DataClient = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("DataService")).client
    end)
    pcall(function()
        GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Content"):WaitForChild("GameConfig"))
    end)
    pcall(function()
        MissionView = require(game:GetService("ReplicatedStorage"):WaitForChild("Features"):WaitForChild("Missions"):WaitForChild("MissionView"))
    end)

    -- Remotes: direct require (preferred), fall back to upvalue extraction.
    local ok = pcall(function()
        Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Core"):WaitForChild("Remotes"))
    end)
    if not (ok and Remotes and type(Remotes.invoke) == "function") then
        Remotes = ExtractRemotes(CoopController) or ExtractRemotes(DataController)
    end
    if not Remotes then return end
    defs = Remotes.defs
    GAME_OK = true

    -- Track tower run state so Auto Tower only (re)starts when idle.
    HookEvent(D("TowerRunStarted"), function() towerRunning = true end)
    HookEvent(D("TowerRunEnded"),   function() towerRunning = false end)
    HookEvent(D("TowerDefeat"),     function() towerRunning = false end)

    -- ── Golden Goose ──────────────────────────────────────────────────────
    HookEvent(D("GooseEntrance"), function(d)
        if type(d) == "table" and typeof(d.at) == "Vector3" then
            lastGoosePos = d.at
            if gooseEnabled then table.insert(gooseQueue, d.at) end
        end
    end)
    HookEvent(D("GooseFinale"), function(d)
        if type(d) == "table" and typeof(d.at) == "Vector3" then
            lastGoosePos = d.at
            if d.phase ~= "windup" and gooseEnabled then
                -- Coins rain AFTER the windup; queue the home positions a bit later.
                local delay = (tonumber(d.windup) or 0) + 1.2
                task.delay(delay, function()
                    if HUB.dead or not gooseEnabled then return end
                    table.insert(gooseQueue, d.at)
                    if type(d.coops) == "table" then
                        for _, v in ipairs(d.coops) do
                            if typeof(v) == "Vector3" then table.insert(gooseQueue, v) end
                        end
                    end
                end)
            end
        end
    end)

    -- ── HotEgg Meteor ─────────────────────────────────────────────────────
    HookEvent(D("HotEggEntrance"), function(d)
        if type(d) == "table" and typeof(d.at) == "Vector3" then
            lastEggPos = d.at
            if hotEggEnabled then table.insert(eggQueue, d.at) end
        end
    end)
    HookEvent(D("HotEggMeteor"), function(d)
        if type(d) == "table" and typeof(d.at) == "Vector3" then
            lastEggPos = d.at
            if hotEggEnabled then table.insert(eggQueue, d.at) end
        end
    end)
end
-- initGame() is deferred to the very END of the script (after the UI is built)
-- so that a require()/capability error in the executor can never break the UI.

local function Invoke(def, ...)
    if not (GAME_OK and def) then return nil end
    local args = { ... }
    local ok, res = pcall(function()
        return Remotes.invoke(def, table.unpack(args, 1, #args))
    end)
    return ok and res or nil
end

-- Returns (true, result.data) on success, (false, error-string) on failure.
local function TryInvoke(def, ...)
    if not GAME_OK then return false, "Game API not connected" end
    local res = Invoke(def, ...)
    if res == nil then return false, "no response (server rejected)" end
    if res.ok then return true, res.data end
    return false, tostring(res.error or "unknown")
end

-- Safe remote-def accessor: returns nil while defs isn't loaded yet, so loops
-- and buttons can never throw "attempt to index nil" before initGame finishes.
local function D(name)
    return defs and defs[name]
end

local function GetRoster()
    if not GAME_OK then return nil end
    local ok, r = pcall(function() return DataController.roster() end)
    return ok and r or nil
end

local function GetMoney()
    if not GAME_OK then return nil end
    local ok, n = pcall(function() return DataController.money():toNumber() end)
    return ok and n or nil
end

local function GetCoop()
    if not GAME_OK then return nil end
    local ok, c = pcall(function() return CoopController.coopView() end)
    return ok and c or nil
end

local function GetMissions()
    if not GAME_OK then return nil end
    local ok, m = pcall(function() return DataController.missions() end)
    return ok and m or nil
end

local function GetActiveChicken(roster)
    if not roster then return nil end
    local activeId = roster.activeId
    local chickens = roster.chickens or {}
    for _, c in ipairs(chickens) do
        if c.id == activeId then return c end
    end
    return chickens[1]
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE STATE
-- ══════════════════════════════════════════════════════════════════════════════

-- Hatch
local hatchEnabled  = false
local hatchTiers    = {}   -- set of selected egg tiers (empty = auto best)
local hatchBatch    = false
local hatchGap      = 0.6
local equipBest     = false

-- Fuse
local fuseEnabled   = false
local fuseMaxLevel  = 10
local fuseSameType  = false
local fuseGap       = 1.0

-- Sell
local sellEnabled   = false
local sellBelow     = 5
local sellRarities  = {}   -- set of rarities to sell (in addition to level)
local protectRarities = {} -- set of rarities to never sell/fuse
local sellGap       = 1.5

-- Collect
local collectEnabled = false
local collectRadius  = 200
local collectGap     = 0.5

-- Coop
local coopEnabled   = false
local coopExpand    = true
local coopBuy       = true
local coopUpgrade   = true
local coopGap       = 4.0

-- Tower
local towerEnabled  = false
local towerGap      = 5.0

-- Pit
local pitEnabled    = false
local pitGap        = 4.0

-- Rebirth
local rebirthEnabled = false
local rebirthMinFloor = 0   -- extra tower-floor gate (0 = auto, use the game's requirement)
local rebirthGap     = 10.0

-- Rewards
local rewardDaily   = false
local rewardMissions = false
local rewardSocial  = false
local rewardPass    = false
local rewardGap     = 30.0
local redeemCode    = ""

-- Events
local eventsEnabled = false
local eventGap      = 0.3

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE FUNCTIONS
-- ══════════════════════════════════════════════════════════════════════════════
local function EggDisplayName(tier) return EGG_NAMES[tier] or tier end

local function TierFromOption(opt)
    if type(opt) ~= "string" then return nil end
    local t = opt:match("^([%w_]+)%s*%(")
    return t or opt
end

local function PickHatchTier(eggs)
    -- Selected tiers take priority (best → worst). Empty selection = hatch best.
    local selected = {}
    for i = #EGG_TIERS, 1, -1 do
        local t = EGG_TIERS[i]
        if hatchTiers[t] then table.insert(selected, t) end
    end
    if #selected > 0 then
        for _, t in ipairs(selected) do
            if (tonumber(eggs[t]) or 0) > 0 then return t end
        end
        return nil
    end
    for i = #EGG_TIERS, 1, -1 do
        local t = EGG_TIERS[i]
        if (tonumber(eggs[t]) or 0) > 0 then return t end
    end
    return nil
end

local function HatchOnce()
    local roster = GetRoster()
    local eggs = roster and roster.eggs
    if not eggs then return "no data" end
    local tier = PickHatchTier(eggs)
    if not tier then return "no eggs" end
    local count = tonumber(eggs[tier]) or 0
    local okR, err
    if hatchBatch and count >= 2 then
        okR, err = TryInvoke(D("HatchEggs"), tier, math.min(count, 10))
    else
        okR, err = TryInvoke(D("HatchEgg"), tier)
    end
    if not okR then return "hatch failed: " .. tostring(err) end
    return "hatched " .. EggDisplayName(tier)
end

local function PickFusePair(roster)
    local list = {}
    local activeId = roster.activeId
    for _, c in ipairs(roster.chickens or {}) do
        if c.id ~= activeId and not protectRarities[c.rarity] and (tonumber(c.level) or 0) < fuseMaxLevel then
            table.insert(list, c)
        end
    end
    table.sort(list, function(a, b) return (tonumber(a.level) or 0) < (tonumber(b.level) or 0) end)
    if fuseSameType and #list >= 2 then
        local byType = {}
        for _, c in ipairs(list) do
            byType[c.typeId] = byType[c.typeId] or {}
            table.insert(byType[c.typeId], c)
        end
        for _, group in pairs(byType) do
            if #group >= 2 then return group[1], group[2] end
        end
    end
    if #list >= 2 then return list[1], list[2] end
    return nil, nil
end

local function FuseOnce()
    local roster = GetRoster()
    if not roster then return "no data" end
    local a, b = PickFusePair(roster)
    if not (a and b) then return "no pair" end
    local okR, err = TryInvoke(D("FuseChickens"), a.id, b.id, nil, nil, nil)
    if not okR then return "fuse failed: " .. tostring(err) end
    return "fused"
end

local function SellableIds(roster)
    local ids = {}
    local activeId = roster.activeId
    for _, c in ipairs(roster.chickens or {}) do
        if c.id ~= activeId and not protectRarities[c.rarity] then
            local sell = false
            if sellBelow > 0 and (tonumber(c.level) or 0) < sellBelow then sell = true end
            if sellRarities[c.rarity] then sell = true end
            if sell then table.insert(ids, c.id) end
        end
    end
    return ids
end

local function SellOnce()
    local roster = GetRoster()
    if not roster then return "no data" end
    local ids = SellableIds(roster)
    if #ids == 0 then return "nothing to sell" end
    local okR, err = TryInvoke(D("SellChickens"), ids)
    if not okR then return "sell failed: " .. tostring(err) end
    return "sold " .. #ids
end

-- Score = level (primary) + rarity rank. Higher = stronger fighter.
local function PowerScore(c)
    local lvl = tonumber(c.level) or 0
    local rank = RARITY_ORDER[c.rarity] or 1
    return lvl * 10 + rank
end

local function EquipBestOnce()
    local roster = GetRoster()
    if not roster then return "no data" end
    local best, bestScore = nil, -1
    for _, c in ipairs(roster.chickens or {}) do
        local s = PowerScore(c)
        if s > bestScore then best, bestScore = c, s end
    end
    if best and best.id ~= roster.activeId then
        local okR, err = TryInvoke(D("SetActiveChicken"), best.id)
        if not okR then return "equip failed: " .. tostring(err) end
        return "equipped " .. tostring(best.nickname or best.typeId)
    end
    return "already best"
end

local function ScanCollectibles(radius)
    local hrp = GetHRP()
    if not hrp then return {} end
    local list = {}
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Parent then
            local nm = part.Name:lower()
            -- Coop chickens drop eggs that are picked up by proximity; coin/scrap
            -- covers event coins + recycler drops.
            if (nm:find("coop", 1, true) or nm:find("coin", 1, true) or nm:find("scrap", 1, true))
                and (part.Position - hrp.Position).Magnitude <= radius then
                table.insert(list, part)
            end
        end
    end
    return list
end

-- Broader scan for world-event drops (coins + the meteor egg parts).
local function ScanEventDrops(radius)
    local hrp = GetHRP()
    if not hrp then return {} end
    local list = {}
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Parent then
            local nm = part.Name:lower()
            if (nm:find("coin", 1, true) or nm:find("scrap", 1, true)
                or nm:find("egg", 1, true) or nm:find("drop", 1, true)
                or nm:find("orb", 1, true) or nm:find("gem", 1, true))
                and (part.Position - hrp.Position).Magnitude <= radius then
                table.insert(list, part)
            end
        end
    end
    return list
end

local function CollectOnce()
    local drops = ScanCollectibles(collectRadius)
    if #drops == 0 then return 0 end
    for _, part in ipairs(drops) do
        if part.Parent then
            TeleportTo(part.Position)
            task.wait(0.1)
        end
    end
    return #drops
end

-- Drain a queue of announced event positions, collecting drops at each.
local function DrainQueue(queue, radius)
    local collected = 0
    while #queue > 0 and not HUB.dead do
        local pos = table.remove(queue, 1)
        if typeof(pos) == "Vector3" then
            TeleportTo(pos)
            task.wait(0.25)
            local drops = ScanEventDrops(radius)
            for _, part in ipairs(drops) do
                if part.Parent then
                    TeleportTo(part.Position)
                    task.wait(0.12)
                    collected = collected + 1
                end
            end
        end
    end
    return collected
end

local function CoopOnce()
    local view = GetCoop()
    if not view then return "no coop data" end
    local acted = {}
    -- Expand is gated server-side via canExpand (slots < maxSlots && money)
    if coopExpand and view.canExpand then
        local okRes = Invoke(D("ExpandCoop"))
        if okRes and okRes.ok then table.insert(acted, "expand") end
    end
    -- Buy the next generator slot (coopView computes buySlot = next free slot)
    if coopBuy and view.buySlot then
        local okRes = Invoke(D("BuyGenerator"), view.buySlot)
        if okRes and okRes.ok then table.insert(acted, "buy slot " .. tostring(view.buySlot)) end
    end
    -- Upgrade the lowest-level generator that can still be upgraded
    if coopUpgrade then
        local bestSlot, bestLvl = nil, nil
        for slot, g in pairs(view.gens or {}) do
            local lvl = tonumber(g.level) or 0
            if g.canUpgrade ~= false and (bestLvl == nil or lvl < bestLvl) then
                bestSlot, bestLvl = tonumber(slot), lvl
            end
        end
        if bestSlot then
            local okRes = Invoke(D("UpgradeGenerator"), bestSlot)
            if okRes and okRes.ok then table.insert(acted, "upgrade slot " .. tostring(bestSlot)) end
        end
    end
    return #acted > 0 and table.concat(acted, ", ") or "nothing"
end

-- Claim every mission whose progress reached its target (uses the game's own
-- MissionView so the id + "ready" logic always matches the server).
local function ClaimAllMissions()
    if not (MissionView and GAME_OK) then return end
    local missions = GetMissions()
    local roster = GetRoster()
    if not missions then return end
    local snapshot = {
        roster = roster,
        towerBest = 0,
        rebirthCount = 0,
        recyclerLevel = 0,
        missions = missions,
    }
    pcall(function() snapshot.towerBest = tonumber(DataController.towerBest()) or 0 end)
    pcall(function()
        local rb = DataController.rebirth()
        if type(rb) == "table" then snapshot.rebirthCount = tonumber(rb.count) or 0 end
    end)
    pcall(function() snapshot.recyclerLevel = tonumber(DataController.recyclerLevel()) or 0 end)
    for _, scope in ipairs({ "daily", "weekly", "life" }) do
        local okAct, active = pcall(function() return MissionView.active(scope) end)
        if okAct and type(active) == "table" then
            for _, m in ipairs(active) do
                if m and m.id and m.kind == nil then
                    local okSt, st = pcall(function() return MissionView.stateOf(snapshot, m, os.time()) end)
                    if okSt and st == "ready" then
                        Invoke(D("MissionClaim"), m.id)
                    end
                end
            end
        end
    end
end

-- Claim the daily "day" reward + every ready session-time reward (s1..s4).
local function ClaimDaily()
    if not GAME_OK then return end
    local ok, daily = pcall(function() return DataController.daily() end)
    if not (ok and type(daily) == "table") then return end
    local claimed = daily.claimed or {}
    local played = tonumber(daily.played) or 0
    -- Day reward (streak day) — key "d"
    if (tonumber(daily.streak) or 0) >= 1 and not claimed["d"] then
        local res = Invoke(D("DailyClaim"), "day", nil)
        if res and res.ok then pcall(Notify, "Rewards", "Daily day " .. tostring(daily.streak) .. " claimed", "Success") end
    end
    -- Session-time rewards — keys "s1".."sN", ready once played >= at
    local session = GameConfig and GameConfig.daily and GameConfig.daily.session
    local nSession = session and #session or 0
    for i = 1, nSession do
        if not claimed["s" .. i] then
            local at = session[i] and tonumber(session[i].at) or 0
            if played >= at then
                local res = Invoke(D("DailyClaim"), "session", i)
                if res and res.ok then
                    pcall(Notify, "Rewards", "Daily session tier " .. i .. " claimed", "Success")
                end
            end
        end
    end
end

-- Claim battle-pass FREE tier levels that are reached. claimed uses "<lvl>:free"
-- string keys and PassClaim takes a STRING track ("free"/"premium").
local function ClaimPassLevels()
    if not (DataClient and GameConfig) then return end
    local ok, pass = pcall(function() return DataClient:get({ "pass" }) end)
    if not (ok and type(pass) == "table") then return end
    local passCfg = GameConfig.premium and GameConfig.premium.pass
    if not passCfg or not passCfg.levels then return end
    local points = tonumber(pass.points) or 0
    local claimed = pass.claimed or {}
    local maxLevel = math.min(math.floor(points / (tonumber(passCfg.xpPerLevel) or 60)), #passCfg.levels)
    local premium = pass.premium == true
    for lvl = 1, maxLevel do
        local track = passCfg.levels[lvl].premium and "premium" or "free"
        if track == "free" or (premium and not claimed[lvl .. ":premium"]) then
            if not claimed[lvl .. ":" .. track] then
                local res = Invoke(D("PassClaim"), lvl, track)
                if res and res.ok then
                    pcall(Notify, "Rewards", "Battle pass level " .. lvl .. " (" .. track .. ") claimed", "Success")
                end
            end
        end
    end
end

local function FindPitPosition()
    local pit = Workspace:FindFirstChild("Pit")
    if pit and pit:IsA("Model") then
        local pp = pit.PrimaryPart or pit:FindFirstChildWhichIsA("BasePart", true)
        if pp then return pp.Position end
        return pit:GetPivot().Position
    end
    local hrp = GetHRP()
    if not hrp then return nil end
    -- fallback: nearest arena
    local arenas = Workspace:FindFirstChild("Arenas")
    if arenas then
        local best, bestD = nil, math.huge
        for _, a in ipairs(arenas:GetChildren()) do
            if a:IsA("Model") then
                local pp = a.PrimaryPart or a:FindFirstChildWhichIsA("BasePart", true)
                if pp then
                    local d = (pp.Position - hrp.Position).Magnitude
                    if d < bestD then best, bestD = pp.Position, d end
                end
            end
        end
        return best
    end
    return nil
end

-- ── BOOST READERS ─────────────────────────────────────────────────────────────
local function GetFriendBoost()
    local n = LocalPlayer:GetAttribute("friendsHere") or 0
    n = math.max(0, math.min(math.floor(tonumber(n) or 0), 5))
    return n, n * 10
end

local function GetGroupPerk()
    return LocalPlayer:GetAttribute("groupMember") == true
end

local function GetServerBoost()
    local kind = Workspace:GetAttribute("ServerBoostKind")
    local mult = Workspace:GetAttribute("ServerBoostMult")
    local until_ = Workspace:GetAttribute("ServerBoostUntil")
    if kind and mult and until_ then
        local remain = 0
        pcall(function()
            remain = math.max(0, (tonumber(until_) or 0) - Workspace:GetServerTimeNow())
        end)
        return kind, tonumber(mult) or 1, remain
    end
    return nil, nil, nil
end

local function GetRebirthBonus()
    if not DataClient then return 0, 0, 1, 0 end
    local ok, rb = pcall(function() return DataClient:get({ "rebirth" }) end)
    if ok and type(rb) == "table" then
        local count = tonumber(rb.count) or 0
        local points = tonumber(rb.points) or 0
        local mult = 1 + count * 0.15 + points * 0.02
        -- Next-rebirth requirement floor: 25 + 5*ln(1 + 0.4*count)
        local req = math.floor(25 + 5 * math.log(1 + 0.4 * count) + 0.5)
        return count, points, mult, req
    end
    return 0, 0, 1, 25
end

local function FormatBoostText()
    local lines = {}
    local friendCount, friendPct = GetFriendBoost()
    lines[#lines + 1] = "Friend Boost: " .. friendCount .. "/5 → +" .. friendPct .. "% money"
    if GetGroupPerk() then
        lines[#lines + 1] = "Group Perk: ACTIVE → +5% money"
    else
        lines[#lines + 1] = "Group Perk: join group 180466034 for +5%"
    end
    local kind, mult, remain = GetServerBoost()
    if kind then
        local mins = math.floor(remain / 60)
        local secs = math.floor(remain % 60)
        lines[#lines + 1] = "Server Boost: ACTIVE ×" .. mult .. " (" .. kind .. ", " .. mins .. "m " .. secs .. "s left)"
    else
        lines[#lines + 1] = "Server Boost: inactive (2+ players = ×2)"
    end
    local rc, rp, rmult, rreq = GetRebirthBonus()
    lines[#lines + 1] = "Rebirth: ×" .. string.format("%.2f", rmult) .. " (" .. rc .. " rebirths, " .. rp .. " pts) — next at tower floor " .. rreq
    return table.concat(lines, "\n")
end

-- ── REBIRTH READINESS ─────────────────────────────────────────────────────────
-- The game gates rebirth on the CURRENT-run tower best (DataController.towerBest),
-- NOT on the chicken's level. requirementFloor grows with the rebirth count.
local function GetTowerBest()
    if not GAME_OK then return 0 end
    local ok, n = pcall(function() return DataController.towerBest() end)
    return ok and (tonumber(n) or 0) or 0
end

local function GetOwnCoopPos()
    local plot = LocalPlayer:GetAttribute("Plot")
    if not plot then return nil end
    local coops = Workspace:FindFirstChild("Coops")
    local coop = coops and coops:FindFirstChild("Coop" .. tostring(plot))
    if not coop then return nil end
    local origin = coop:GetAttribute("Origin")
    if typeof(origin) == "CFrame" then
        return origin.Position + Vector3.new(0, 3, 0)
    end
    local prim = coop.PrimaryPart or coop:FindFirstChildWhichIsA("BasePart", true)
    if prim then return prim.Position end
    return coop:GetPivot().Position
end

-- State of the player's own rooster body ("corral" = at home).
local function GetOwnChickenState()
    local bodies = Workspace:FindFirstChild("ChickenBodies")
    local uid = LocalPlayer.UserId
    if not bodies then return nil end
    for _, b in ipairs(bodies:GetChildren()) do
        local ok, owner = pcall(function() return b:GetAttribute("ovOwner") end)
        if ok and owner == uid then
            local ok2, st = pcall(function() return b:GetAttribute("ovState") end)
            return ok2 and st or "corral"
        end
    end
    return nil
end

-- Returns (ready, reason). reason is nil when ready, else a human-readable message.
local function RebirthReady()
    if not GAME_OK then return false, "Game API not connected" end
    if not GetActiveChicken(GetRoster()) then return false, "no rooster" end
    if towerRunning then return false, "finish the tower run first" end
    local _, _, _, req = GetRebirthBonus()
    local best = GetTowerBest()
    if best < req then
        return false, "tower floor " .. best .. "/" .. req
    end
    return true, nil
end

-- Full rebirth action: verify ready, bring the rooster home, then fire the remote.
local function RebirthOnce()
    local ready, reason = RebirthReady()
    if not ready then return false, reason end
    if GetOwnChickenState() ~= "corral" then
        local pos = GetOwnCoopPos()
        if pos then
            TeleportTo(pos)
            task.wait(2)  -- let the server register the rooster as "home"
        end
    end
    local okR, err = TryInvoke(D("Rebirth"))
    if not okR then return false, err end
    return true, nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 1: CHICKENS
-- ══════════════════════════════════════════════════════════════════════════════
local ChickensTab = Window:AddTab({ Name = "Chickens", Subtitle = "Hatch, fuse & sell", Icon = "crown" })

-- ── HATCH ─────────────────────────────────────────────────────────────────────
local HatchSub = ChickensTab:AddSubTab("Hatch")
HatchSub:AddToggle({
    Name = "Auto Hatch", Default = false, Flag = "hatch_auto",
    Callback = safeCallback(function(v)
        hatchEnabled = v
        Notify("Auto Hatch", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
do
    local opts = {}
    for _, t in ipairs(EGG_TIERS) do table.insert(opts, t .. " (" .. EggDisplayName(t) .. ")") end
    local function setTiers(list)
        hatchTiers = {}
        for _, opt in ipairs(list or {}) do
            local t = TierFromOption(opt)
            if t then hatchTiers[t] = true end
        end
    end
    local dd = HatchSub:AddMultiDropdown({
        Name = "Egg Tiers (empty = auto best)", Options = opts, Default = {},
        MaxVisible = 8, Searchable = true, Flag = "hatch_tiers",
        Callback = setTiers,
    })
    registerResync(dd, setTiers)
end
HatchSub:AddToggle({
    Name = "Auto Equip Best Chicken", Default = false, Flag = "equip_best",
    Callback = function(v) equipBest = v end,
})
HatchSub:AddToggle({
    Name = "Batch Hatch (up to 10)", Default = false, Flag = "hatch_batch",
    Callback = function(v) hatchBatch = v end,
})
HatchSub:AddSlider({ Name = "Hatch Gap", Min = 0.1, Max = 10, Default = 0.6, Suffix = "s", Flag = "hatch_gap", Callback = function(v) hatchGap = v end })
HatchSub:AddButton({
    Name = "Hatch Once", Primary = true,
    Callback = safeCallback(function()
        local res = HatchOnce()
        Notify("Hatch", res or "failed", res and res ~= "no eggs" and res ~= "no data" and "Success" or "Info")
    end),
})

-- ── FUSE ──────────────────────────────────────────────────────────────────────
local FuseSub = ChickensTab:AddSubTab("Fuse")
FuseSub:AddToggle({
    Name = "Auto Fuse", Default = false, Flag = "fuse_auto",
    Callback = safeCallback(function(v)
        fuseEnabled = v
        Notify("Auto Fuse", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
FuseSub:AddSlider({ Name = "Fuse Below Level", Min = 1, Max = 500, Default = 10, Suffix = "", Flag = "fuse_maxlevel", Callback = function(v) fuseMaxLevel = v end })
FuseSub:AddToggle({ Name = "Prefer Same Type", Default = false, Flag = "fuse_sametype", Callback = function(v) fuseSameType = v end })
FuseSub:AddSlider({ Name = "Fuse Gap", Min = 0.1, Max = 30, Default = 1, Suffix = "s", Flag = "fuse_gap", Callback = function(v) fuseGap = v end })
FuseSub:AddButton({
    Name = "Fuse Once", Primary = true,
    Callback = safeCallback(function()
        local res = FuseOnce()
        Notify("Fuse", res or "failed", res and res ~= "no pair" and res ~= "no data" and "Success" or "Info")
    end),
})

-- ── SELL ──────────────────────────────────────────────────────────────────────
local SellSub = ChickensTab:AddSubTab("Sell")
SellSub:AddToggle({
    Name = "Auto Sell", Default = false, Flag = "sell_auto",
    Callback = safeCallback(function(v)
        sellEnabled = v
        Notify("Auto Sell", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
SellSub:AddSlider({ Name = "Sell Below Level", Min = 0, Max = 1000, Default = 5, Suffix = " (0 = off)", Flag = "sell_below", Callback = function(v) sellBelow = v end })
do
    local function setSellRarities(list)
        sellRarities = {}
        for _, r in ipairs(list or {}) do sellRarities[r] = true end
    end
    local dd = SellSub:AddMultiDropdown({
        Name = "Sell Rarities (always)", Options = RARITY_LIST, Default = {},
        MaxVisible = 8, Searchable = true, Flag = "sell_rarities",
        Callback = setSellRarities,
    })
    registerResync(dd, setSellRarities)
end
do
    local function setProtect(list)
        protectRarities = {}
        for _, r in ipairs(list or {}) do protectRarities[r] = true end
    end
    local dd = SellSub:AddMultiDropdown({
        Name = "Protect Rarities (never sell/fuse)", Options = RARITY_LIST, Default = {},
        MaxVisible = 8, Searchable = true, Flag = "protect_rarities",
        Callback = setProtect,
    })
    registerResync(dd, setProtect)
end
SellSub:AddSlider({ Name = "Sell Gap", Min = 0.1, Max = 30, Default = 1.5, Suffix = "s", Flag = "sell_gap", Callback = function(v) sellGap = v end })
SellSub:AddButton({
    Name = "Sell Now", Primary = true,
    Callback = safeCallback(function()
        local res = SellOnce()
        Notify("Sell", res or "failed", res and res ~= "nothing to sell" and res ~= "no data" and "Success" or "Info")
    end),
})

-- ── REBIRTH ───────────────────────────────────────────────────────────────────
local RebirthSub = ChickensTab:AddSubTab("Rebirth")
RebirthSub:AddToggle({
    Name = "Auto Rebirth", Default = false, Flag = "rebirth_auto",
    Callback = safeCallback(function(v)
        rebirthEnabled = v
        Notify("Auto Rebirth", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
RebirthSub:AddSlider({ Name = "Min Tower Floor (0 = auto)", Min = 0, Max = 1000, Default = 0, Suffix = "", Flag = "rebirth_floor", Callback = function(v) rebirthMinFloor = v end })
RebirthSub:AddSlider({ Name = "Check Gap", Min = 1, Max = 60, Default = 10, Suffix = "s", Flag = "rebirth_gap", Callback = function(v) rebirthGap = v end })
RebirthSub:AddButton({
    Name = "Rebirth Now", Primary = true,
    Callback = safeCallback(function()
        local okR, err = RebirthOnce()
        if okR then Notify("Rebirth", "Rebirth successful!", "Success")
        else Notify("Rebirth", "Failed: " .. tostring(err), "Error") end
    end),
})
-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 2: WORLD (tower / pit / events)
-- ══════════════════════════════════════════════════════════════════════════════
local WorldTab = Window:AddTab({ Name = "World", Subtitle = "Tower, pit & events", Icon = "swords" })

-- ── TOWER ─────────────────────────────────────────────────────────────────────
local TowerSub = WorldTab:AddSubTab("Tower")
TowerSub:AddToggle({
    Name = "Auto Tower", Default = false, Flag = "tower_auto",
    Callback = safeCallback(function(v)
        towerEnabled = v
        Notify("Auto Tower", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
TowerSub:AddSlider({ Name = "Restart Gap", Min = 1, Max = 60, Default = 5, Suffix = "s", Flag = "tower_gap", Callback = function(v) towerGap = v end })
TowerSub:AddButton({
    Name = "Start Tower Run", Primary = true,
    Callback = safeCallback(function()
        local okR, err = TryInvoke(D("TowerStart"))
        if okR then Notify("Tower", "Run started", "Success")
        else Notify("Tower", "Failed: " .. tostring(err), "Error") end
    end),
})
TowerSub:AddButton({
    Name = "Surrender Tower",
    Callback = safeCallback(function()
        local okR, err = TryInvoke(D("TowerSurrender"))
        if okR then Notify("Tower", "Run surrendered", "Success")
        else Notify("Tower", "Failed: " .. tostring(err), "Error") end
    end),
})
-- ── PIT ───────────────────────────────────────────────────────────────────────
local PitSub = WorldTab:AddSubTab("Pit")
PitSub:AddToggle({
    Name = "Auto Pit (stay in arena)", Default = false, Flag = "pit_auto",
    Callback = safeCallback(function(v)
        pitEnabled = v
        Notify("Auto Pit", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
PitSub:AddSlider({ Name = "Check Gap", Min = 1, Max = 30, Default = 4, Suffix = "s", Flag = "pit_gap", Callback = function(v) pitGap = v end })
PitSub:AddButton({
    Name = "Teleport To Pit", Primary = true,
    Callback = safeCallback(function()
        local pos = FindPitPosition()
        if pos then
            TeleportTo(pos)
            Notify("Pit", "Teleported to the pit", "Success")
        else
            Notify("Pit", "Pit not found", "Error")
        end
    end),
})

-- ── EVENTS (Golden Goose + HotEgg) ────────────────────────────────────────────
local EventsSub = WorldTab:AddSubTab("Events")
EventsSub:AddToggle({
    Name = "Auto Events", Default = false, Flag = "events_auto",
    Callback = safeCallback(function(v)
        eventsEnabled = v
        Notify("Auto Events", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
EventsSub:AddToggle({
    Name = "Golden Goose (coins)", Default = true, Flag = "events_goose",
    Callback = function(v) gooseEnabled = v end,
})
EventsSub:AddToggle({
    Name = "HotEgg Meteor (eggs)", Default = true, Flag = "events_hotegg",
    Callback = function(v) hotEggEnabled = v end,
})
EventsSub:AddSlider({ Name = "Sweep Gap", Min = 0.1, Max = 2, Default = 0.3, Suffix = "s", Flag = "events_gap", Callback = function(v) eventGap = v end })
EventsSub:AddButton({
    Name = "Teleport To Last Goose", Primary = true,
    Callback = safeCallback(function()
        if lastGoosePos then TeleportTo(lastGoosePos); Notify("Events", "At last goose", "Success")
        else Notify("Events", "No goose seen yet", "Info") end
    end),
})
EventsSub:AddButton({
    Name = "Teleport To Last Meteor",
    Callback = safeCallback(function()
        if lastEggPos then TeleportTo(lastEggPos); Notify("Events", "At last meteor", "Success")
        else Notify("Events", "No meteor seen yet", "Info") end
    end),
})
-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 3: ECONOMY
-- ══════════════════════════════════════════════════════════════════════════════
local EconomyTab = Window:AddTab({ Name = "Economy", Subtitle = "Coop, collect, rewards & boosts", Icon = "coin" })

-- ── COOP ──────────────────────────────────────────────────────────────────────
local CoopSub = EconomyTab:AddSubTab("Coop")
CoopSub:AddToggle({
    Name = "Auto Coop", Default = false, Flag = "coop_auto",
    Callback = safeCallback(function(v)
        coopEnabled = v
        Notify("Auto Coop", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
CoopSub:AddToggle({ Name = "Auto Expand", Default = true, Flag = "coop_expand", Callback = function(v) coopExpand = v end })
CoopSub:AddToggle({ Name = "Auto Buy Generator", Default = true, Flag = "coop_buy", Callback = function(v) coopBuy = v end })
CoopSub:AddToggle({ Name = "Auto Upgrade Generators", Default = true, Flag = "coop_upgrade", Callback = function(v) coopUpgrade = v end })
CoopSub:AddSlider({ Name = "Coop Gap", Min = 1, Max = 60, Default = 4, Suffix = "s", Flag = "coop_gap", Callback = function(v) coopGap = v end })
CoopSub:AddButton({
    Name = "Run Coop Once", Primary = true,
    Callback = safeCallback(function()
        local res = CoopOnce()
        Notify("Coop", res or "failed", "Info")
    end),
})
CoopSub:AddButton({
    Name = "Upgrade Recycler",
    Callback = safeCallback(function()
        local okR, err = TryInvoke(D("UpgradeRecycler"))
        if okR then Notify("Recycler", "Upgraded!", "Success")
        else Notify("Recycler", "Failed: " .. tostring(err), "Error") end
    end),
})

-- ── COLLECT (scrap / coins) ────────────────────────────────────────────────────
local CollectSub = EconomyTab:AddSubTab("Collect")
CollectSub:AddToggle({
    Name = "Auto Collect", Default = false, Flag = "collect_auto",
    Callback = safeCallback(function(v)
        collectEnabled = v
        Notify("Auto Collect", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
CollectSub:AddSlider({ Name = "Scan Radius", Min = 30, Max = 1000, Default = 200, Suffix = " studs", Flag = "collect_radius", Callback = function(v) collectRadius = v end })
CollectSub:AddSlider({ Name = "Collect Gap", Min = 0.1, Max = 5, Default = 0.5, Suffix = "s", Flag = "collect_gap", Callback = function(v) collectGap = v end })
CollectSub:AddButton({
    Name = "Collect Once", Primary = true,
    Callback = safeCallback(function()
        local n = CollectOnce()
        Notify("Collect", n > 0 and ("Collected " .. n .. " drop(s)") or "Nothing nearby", n > 0 and "Success" or "Info")
    end),
})

-- ── REWARDS ───────────────────────────────────────────────────────────────────
local RewardsSub = EconomyTab:AddSubTab("Rewards")
RewardsSub:AddToggle({ Name = "Auto Daily", Default = false, Flag = "reward_daily", Callback = function(v) rewardDaily = v end })
RewardsSub:AddToggle({ Name = "Auto Missions", Default = false, Flag = "reward_missions", Callback = function(v) rewardMissions = v end })
RewardsSub:AddToggle({ Name = "Auto Social", Default = false, Flag = "reward_social", Callback = function(v) rewardSocial = v end })
RewardsSub:AddToggle({ Name = "Auto Battle Pass", Default = false, Flag = "reward_pass", Callback = function(v) rewardPass = v end })
RewardsSub:AddSlider({ Name = "Claim Gap", Min = 5, Max = 300, Default = 30, Suffix = "s", Flag = "reward_gap", Callback = function(v) rewardGap = v end })
RewardsSub:AddButton({
    Name = "Claim All Now", Primary = true,
    Callback = safeCallback(function()
        ClaimDaily()
        Invoke(D("SocialClaim"))
        ClaimAllMissions()
        ClaimPassLevels()
        Notify("Rewards", "Daily + social + missions + pass claimed", "Success")
    end),
})
RewardsSub:AddInput({
    Name = "Redeem Code", Placeholder = "CODE", Default = "", Flag = "redeem_code",
    Callback = function(text) redeemCode = text or "" end,
})
RewardsSub:AddButton({
    Name = "Redeem",
    Callback = safeCallback(function()
        if redeemCode == "" then Notify("Rewards", "Enter a code first", "Error"); return end
        local okR, err = TryInvoke(D("RedeemCode"), redeemCode)
        if okR then Notify("Rewards", "Code accepted!", "Success")
        else Notify("Rewards", "Code rejected: " .. tostring(err), "Error") end
    end),
})

-- ── BOOSTS (friend / group / server / rebirth status) ─────────────────────────
local BoostsSub = EconomyTab:AddSubTab("Boosts")
local boostsParagraph = BoostsSub:AddParagraph({
    Title = "Live Boosts",
    Text = FormatBoostText(),
})
BoostsSub:AddButton({
    Name = "Refresh Now", Primary = true,
    Callback = safeCallback(function()
        if boostsParagraph then boostsParagraph:Set(FormatBoostText()) end
        Notify("Boosts", "Refreshed", "Success")
    end),
})
BoostsSub:AddButton({
    Name = "Dump Game Data",
    Callback = safeCallback(function()
        if not GAME_OK then Notify("Boosts", "Game API not ready", "Error"); return end
        local roster = GetRoster()
        local money = GetMoney()
        local active = GetActiveChicken(roster)
        print("[Oxide] ═══ CHICKEN FIGHTER ═══")
        print("[Oxide] Money:", tostring(money))
        print("[Oxide] Chickens:", #(roster and roster.chickens or {}), "| Active:", active and (active.id .. " lvl " .. tostring(active.level) .. " " .. tostring(active.rarity)) or "none")
        print("[Oxide] Boosts:", FormatBoostText():gsub("\n", " | "))
        Notify("Boosts", "Data dumped to console", "Success", 3)
    end),
})

-- ══════════════════════════════════════════════════════════════════════════════
-- TAB 4: PLAYER
-- ══════════════════════════════════════════════════════════════════════════════
local PlayerTab = Window:AddTab({ Name = "Player", Subtitle = "Movement & teleports", Icon = "player" })

-- ── MOVEMENT ──────────────────────────────────────────────────────────────────
local MoveSub = PlayerTab:AddSubTab("Movement")

local wsEnabled, wsValue = false, 16
local jpEnabled, jpValue = false, 60

MoveSub:AddToggle({
    Name = "WalkSpeed", Default = false, Flag = "ws_enabled",
    Callback = function(v)
        wsEnabled = v
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = v and wsValue or 16 end
    end,
})
MoveSub:AddSlider({
    Name = "WalkSpeed Value", Min = 16, Max = 24, Default = 16, Suffix = " (max 24 = safe)", Flag = "ws_value",
    Callback = function(v)
        wsValue = v
        if wsEnabled then local hum = GetHumanoid(); if hum then hum.WalkSpeed = v end end
    end,
})
MoveSub:AddToggle({
    Name = "JumpPower", Default = false, Flag = "jp_enabled",
    Callback = function(v)
        jpEnabled = v
        local hum = GetHumanoid()
        if hum then
            if v then
                hum.UseJumpPower = true
                hum.JumpPower = jpValue
            else
                -- restore the game's default jump (JumpHeight mode)
                hum.UseJumpPower = false
            end
        end
    end,
})
MoveSub:AddSlider({
    Name = "JumpPower Value", Min = 50, Max = 100, Default = 60, Suffix = " (max 100 = safe)", Flag = "jp_value",
    Callback = function(v)
        jpValue = v
        if jpEnabled then local hum = GetHumanoid(); if hum then hum.UseJumpPower = true; hum.JumpPower = v end end
    end,
})

track(LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    task.wait(0.2)
    if HUB.dead then return end
    if wsEnabled then hum.WalkSpeed = wsValue end
    if jpEnabled then hum.UseJumpPower = true; hum.JumpPower = jpValue end
end))

-- ── NOCLIP ─────────────────────────────────────────────────────────────────────
local FlySub = PlayerTab:AddSubTab("Noclip")
FlySub:AddParagraph({
    Title = "Fly removed",
    Text = "Fly was removed because the new movement guard detects sustained " ..
           "airtime and would disconnect you. All teleports now glide at a safe " ..
           "speed instead.",
})
local noclip = false
local noclipConn
FlySub:AddToggle({
    Name = "Noclip", Default = false, Flag = "noclip_enabled",
    Callback = function(v)
        noclip = v
        if v then
            if noclipConn then noclipConn:Disconnect() end
            noclipConn = RunService.Stepped:Connect(function()
                if HUB.dead or not noclip then return end
                local char = GetCharacter()
                if not char then return end
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end)
        else
            if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        end
        Notify("Noclip", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end,
})

-- ── ANTI-AFK ──────────────────────────────────────────────────────────────────
local AfkSub = PlayerTab:AddSubTab("Anti-AFK")
local antiAFK = true
AfkSub:AddToggle({
    Name = "Anti-AFK", Default = true, Flag = "anti_afk",
    Callback = function(v) antiAFK = v end,
})
if not _G.OxideChickenFighterAntiAFK then
    _G.OxideChickenFighterAntiAFK = true
    LocalPlayer.Idled:Connect(function()
        if antiAFK and not HUB.dead then
            pcall(function()
                local VU = game:GetService("VirtualUser")
                VU:Button2Down(Vector2.new(0, 0), Camera.CFrame)
                task.wait(1)
                VU:Button2Up(Vector2.new(0, 0), Camera.CFrame)
            end)
        end
    end)
end

-- ── TELEPORT ──────────────────────────────────────────────────────────────────
local TpSub = PlayerTab:AddSubTab("Teleport")

local selectedPlayer = nil
local function GetPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    table.sort(names)
    if #names == 0 then names = { "(no other players)" } end
    return names
end
local function ResolvePlayer(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name then return p end
    end
    return nil
end

local function applyPlayerSelect(v) selectedPlayer = v end
local playerDropdown = TpSub:AddDropdown({
    Name = "Player", Options = GetPlayerNames(), Default = nil,
    MaxVisible = 6, Searchable = true, Flag = "tp_player",
    Callback = applyPlayerSelect,
})
registerResync(playerDropdown, applyPlayerSelect)

TpSub:AddButton({
    Name = "Refresh Players",
    Callback = function()
        playerDropdown:SetOptions(GetPlayerNames())
        Notify("Teleport", "Player list refreshed", "Info")
    end,
})
TpSub:AddButton({
    Name = "Teleport To Player", Primary = true,
    Callback = function()
        local target = ResolvePlayer(selectedPlayer)
        local tHRP = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if tHRP then
            TeleportTo((tHRP.CFrame * CFrame.new(0, 0, 3)).Position)
            Notify("Teleport", "Teleported to " .. target.Name, "Success")
        else
            Notify("Teleport", "Target unavailable", "Error")
        end
    end,
})

local waypoints = {}
local pendingName = "Spot 1"
local selectedWaypoint = nil
local function WaypointNames()
    local names = {}
    for name in pairs(waypoints) do table.insert(names, name) end
    table.sort(names)
    if #names == 0 then names = { "(none)" } end
    return names
end
local function applyWpSelect(v) selectedWaypoint = v end
local waypointDropdown

TpSub:AddInput({
    Name = "Waypoint Name", Placeholder = "Spot 1", Default = "Spot 1", Flag = "wp_name",
    Callback = function(text) pendingName = (text ~= "" and text) or "Spot 1" end,
})
TpSub:AddButton({
    Name = "Save Current Position", Primary = true,
    Callback = function()
        local hrp = GetHRP()
        if not hrp then Notify("Waypoints", "No character", "Error"); return end
        waypoints[pendingName] = hrp.CFrame
        if waypointDropdown then waypointDropdown:SetOptions(WaypointNames()) end
        Notify("Waypoints", "Saved '" .. pendingName .. "'", "Success")
    end,
})
waypointDropdown = TpSub:AddDropdown({
    Name = "Saved Waypoints", Options = WaypointNames(), Default = nil,
    MaxVisible = 6, Searchable = true, Flag = "wp_selected",
    Callback = applyWpSelect,
})
registerResync(waypointDropdown, applyWpSelect)
TpSub:AddButton({
    Name = "Teleport To Waypoint",
    Callback = function()
        local cf = selectedWaypoint and waypoints[selectedWaypoint]
        if cf then
            TeleportTo(cf.Position)
            Notify("Waypoints", "Teleported to '" .. selectedWaypoint .. "'", "Success")
        else
            Notify("Waypoints", "Waypoint unavailable", "Error")
        end
    end,
})

TpSub:AddButton({
    Name = "Teleport To Spawn",
    Callback = function()
        local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
        if spawn then
            TeleportTo(spawn.Position)
            Notify("Teleport", "Teleported to spawn", "Success")
        else
            Notify("Teleport", "No spawn found", "Error")
        end
    end,
})
TpSub:AddButton({
    Name = "Teleport To Pit",
    Callback = safeCallback(function()
        local pos = FindPitPosition()
        if pos then
            TeleportTo(pos)
            Notify("Teleport", "Teleported to the pit", "Success")
        else
            Notify("Teleport", "Pit not found", "Error")
        end
    end),
})
TpSub:AddButton({
    Name = "Teleport To Nearest Arena",
    Callback = safeCallback(function()
        local hrp = GetHRP()
        local arenas = Workspace:FindFirstChild("Arenas")
        if not (hrp and arenas) then Notify("Teleport", "Arenas not found", "Error"); return end
        local best, bestD = nil, math.huge
        for _, a in ipairs(arenas:GetChildren()) do
            if a:IsA("Model") then
                local pp = a.PrimaryPart or a:FindFirstChildWhichIsA("BasePart", true)
                if pp then
                    local d = (pp.Position - hrp.Position).Magnitude
                    if d < bestD then best, bestD = pp.Position, d end
                end
            end
        end
        if best then TeleportTo(best); Notify("Teleport", "At arena", "Success") end
    end),
})

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG PERSISTENCE — restore saved flags, then resync engine state from the UI
-- ══════════════════════════════════════════════════════════════════════════════
if HAS_CONFIG then
    pcall(function() Library:LoadConfig(CONFIG_NAME) end)
    ResyncAll()
end

task.spawn(function()
    while not HUB.dead do
        task.wait(60)
        if HAS_CONFIG and not HUB.dead then
            pcall(function() Library:SaveConfig(CONFIG_NAME) end)
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE LOOPS
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    while not HUB.dead do
        if hatchEnabled then pcall(HatchOnce) end
        task.wait(hatchGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if equipBest then pcall(EquipBestOnce) end
        task.wait(5)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if fuseEnabled then pcall(FuseOnce) end
        task.wait(fuseGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if sellEnabled then pcall(SellOnce) end
        task.wait(sellGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if collectEnabled then pcall(CollectOnce) end
        task.wait(collectGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if coopEnabled then pcall(CoopOnce) end
        task.wait(coopGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if towerEnabled and GAME_OK and not towerRunning then
            local okR, err = TryInvoke(D("TowerStart"))
            if err and not okR then
                pcall(Notify, "Tower", "Start failed: " .. tostring(err), "Error")
            end
        end
        task.wait(towerGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if pitEnabled then
            local pos = FindPitPosition()
            local hrp = GetHRP()
            if pos and hrp and (hrp.Position - pos).Magnitude > 60 then
                TeleportTo(pos)
            end
        end
        task.wait(pitGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if rebirthEnabled then
            local ready = RebirthReady()
            if ready then
                local best = GetTowerBest()
                if rebirthMinFloor <= 0 or best >= rebirthMinFloor then
                    local okR, err = RebirthOnce()
                    if okR then
                        pcall(Notify, "Rebirth", "Rebirthed at tower floor " .. best .. "!", "Success")
                        task.wait(5)
                    elseif err then
                        pcall(Notify, "Rebirth", "Failed: " .. tostring(err), "Error")
                    end
                end
            end
        end
        task.wait(rebirthGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if rewardDaily then pcall(ClaimDaily) end
        if rewardSocial then Invoke(D("SocialClaim")) end
        if rewardMissions then pcall(ClaimAllMissions) end
        if rewardPass then pcall(ClaimPassLevels) end
        task.wait(rewardGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if eventsEnabled then
            if gooseEnabled then pcall(DrainQueue, gooseQueue, 30) end
            if hotEggEnabled then pcall(DrainQueue, eggQueue, 30) end
            local drops = ScanEventDrops(60)
            for _, part in ipairs(drops) do
                if part.Parent and not HUB.dead then
                    TeleportTo(part.Position)
                    task.wait(0.12)
                end
            end
        end
        task.wait(eventGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if boostsParagraph then
            pcall(function() boostsParagraph:Set(FormatBoostText()) end)
        end
        task.wait(5)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- GAME API INIT — runs LAST so a require/capability failure can never break the UI
-- ══════════════════════════════════════════════════════════════════════════════
for _ = 1, 8 do
    if GAME_OK then break end
    pcall(initGame)
    if GAME_OK then break end
    task.wait(1)
end
if GAME_OK then
    Notify("Oxide HUB", "Game API connected", "Success", 2)
else
    Notify("Oxide HUB", "Game API unavailable - Auto tabs disabled", "Error", 4)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CLEANUP
-- ══════════════════════════════════════════════════════════════════════════════
function HUB.Unload()
    if HUB.dead then return end
    HUB.dead = true
    for _, c in ipairs(HUB.conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(HUB.conns)
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    if HAS_CONFIG then pcall(function() Library:SaveConfig(CONFIG_NAME) end) end
    pcall(function()
        if Window and Window.Destroy then Window:Destroy() end
    end)
    _G.OxideChickenFighter = nil
end

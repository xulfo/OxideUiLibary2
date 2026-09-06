-- WINDOW
-- ══════════════════════════════════════════════════════════════════════════════
local Window = Library:CreateWindow({
    Name = "Oxide HUB",
    LoadingAnimation = true,
    LoadingText = "Oxide",
    LoadingDuration = 2.65,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG / FLAG PERSISTENCE
-- ══════════════════════════════════════════════════════════════════════════════
local HAS_CONFIG  = type(Library.SaveConfig) == "function"
    and type(Library.LoadConfig) == "function"
    and type(Library.ListConfigs) == "function"
local CONFIG_NAME = "graben"

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
-- SERVICES / ENV (safe calls only - never block the UI)
-- ══════════════════════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════════════════════
-- STATE (declared before the UI so callbacks can bind to them)
-- ══════════════════════════════════════════════════════════════════════════════
local digEnabled       = false
local digMaxPower      = true
local RARITY_OPTIONS   = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "divine", "eternal", "transcendent", "omega" }
-- Multi-select rarity filter: dig only nodes whose rarity is in this set.
-- Empty set (user unchecked everything) = dig NOTHING.
local digRarities      = {}
for _, r in ipairs(RARITY_OPTIONS) do digRarities[r] = true end

local function raritySetFromSel(sel)
    local set = {}
    for _, r in ipairs(sel or {}) do set[r] = true end
    return set
end
local cleanEnabled     = true
local cleanInstantly   = true
local sellEnabled      = false
local sellInterval     = 20
local collectEnabled   = false
local polishEnabled    = false

local digging         = false
local busy            = false
local digCount        = 0
local lastSellAt      = 0
local detectorKeeper  = nil
local digLoopRunning  = false
local buyRunning      = false

local buriedNodes   = {}
local surfacedSpots = {}
local failedNodes   = {}   -- [nodeId] = os.clock() when a dig on that node failed

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE FORWARD DECLARATIONS (implemented below the UI)
-- ══════════════════════════════════════════════════════════════════════════════
local HumanoidRoot, TeleportTo
local NearestDigZoneCenter, GetInventory
local DoDig, GoDigArea, DigLoop
local InstantClean, CleanAll, CleanLoop
local DoSell, SellLoop
local MyPlot, CollectOnce, CollectLoop
local SellNpcRef, ResolveSellNpc
local InstallDigHooks, RestoreDigHooks
local BuySelectedGear, BuyAllGear

local function Notify(title, content, kind, dur)
    pcall(Window.Notify, Window, { Title = title, Content = content, Type = kind or "Info", Duration = dur or 2.5 })
end

local function notifyOn(feature, on)
    Notify(feature, on and "ON" or "OFF", on and "Success" or "Error")
end

-- Wrap UI callbacks so a single error can never kill the whole script: the
-- failure is surfaced as a notification instead of a dead stack. Engine
-- functions are defined AFTER the UI, so a callback firing before the chunk
-- finished loading used to crash with "attempt to call a nil value".
local function safeCallback(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            pcall(Notify, "Oxide HUB", "Error: " .. tostring(err), "Error", 4)
        end
    end
end

-- Run a long engine task in a background thread so a single error can never
-- kill the script silently: it is surfaced as a notification instead.
local function safeSpawn(fn)
    task.spawn(function()
        local ok, err = pcall(fn)
        if not ok then
            pcall(Notify, "Oxide HUB", "Engine error: " .. tostring(err), "Error", 4)
        end
    end)
end


-- Buyable gear catalog - verified LIVE against the game's own config modules
-- (TS.constants.digging.Shovels / digging.Detectors / cleaning.SprayBottles).
-- The server validates price (Gold deducted), island unlock and shop proximity
-- on every purchase, so buying automates the game's own validated path.
local GEAR_CATALOG = {
    shovel = {
        { id = "plasticShovel",  name = "Plastic Shovel",         cost = 0,         island = "starterIsland" },
        { id = "woodShovel",     name = "Wood Shovel",            cost = 250,       island = "starterIsland" },
        { id = "stoneShovel",    name = "Stone Shovel",           cost = 1600,      island = "starterIsland" },
        { id = "metalShovel",    name = "Metal Shovel",           cost = 9000,      island = "starterIsland" },
        { id = "goldShovel",     name = "Gold Shovel",            cost = 45000,     island = "starterIsland" },
        { id = "amethystShovel", name = "Amethyst Shovel",        cost = 190000,    island = "starterIsland" },
        { id = "titaniumShovel", name = "Titanium Shovel",        cost = 390000,    island = "island2" },
        { id = "cobaltShovel",   name = "Cobalt Shovel",          cost = 650000,    island = "island2" },
        { id = "carbonShovel",   name = "Carbon Shovel",          cost = 1300000,   island = "island2" },
        { id = "rubyShovel",     name = "Ruby Shovel",            cost = 2900000,   island = "island2" },
        { id = "diamondShovel",  name = "Diamond Shovel",         cost = 9200000,   island = "island2" },
        { id = "sandstoneShovel",name = "Sandstone Shovel",       cost = 9000000,    island = "island3" },
        { id = "amberShovel",    name = "Amber Shovel",           cost = 15000000,   island = "island3" },
        { id = "scarabShovel",   name = "Scarab Shovel",          cost = 30000000,   island = "island3" },
        { id = "malachiteShovel",name = "Malachite Shovel",       cost = 66000000,   island = "island3" },
        { id = "aquamarineShovel",name = "Aquamarine Shovel",     cost = 210000000,  island = "island3" },
    },
    detector = {
        { id = "rusty",     name = "Rusty Detector",      cost = 0,         island = "starterIsland" },
        { id = "copper",    name = "Copper Detector",     cost = 500,       island = "starterIsland" },
        { id = "silver",    name = "Silver Detector",     cost = 5000,      island = "starterIsland" },
        { id = "gold",      name = "Gold Detector",       cost = 28000,     island = "starterIsland" },
        { id = "platinum",  name = "Platinum Detector",   cost = 140000,    island = "starterIsland" },
        { id = "onyx",      name = "Onyx Detector",       cost = 330000,    island = "island2" },
        { id = "sapphire",  name = "Sapphire Detector",   cost = 530000,    island = "island2" },
        { id = "jade",      name = "Jade Detector",       cost = 1000000,   island = "island2" },
        { id = "topaz",     name = "Topaz Detector",      cost = 2300000,   island = "island2" },
        { id = "crystal",   name = "Crystal Detector",    cost = 6400000,   island = "island2" },
        { id = "sandstone", name = "Sandstone Detector",  cost = 7500000,   island = "island3" },
        { id = "amber",     name = "Amber Detector",      cost = 12000000,  island = "island3" },
        { id = "scarab",    name = "Scarab Detector",     cost = 23000000,  island = "island3" },
        { id = "malachite", name = "Malachite Detector",  cost = 52000000,  island = "island3" },
        { id = "aquamarine",name = "Aquamarine Detector", cost = 145000000, island = "island3" },
    },
    spray = {
        { id = "basic",          name = "Basic Spray Bottle",         cost = 0,         island = "starterIsland" },
        { id = "rubber",         name = "Rubber Spray Bottle",       cost = 900,       island = "starterIsland" },
        { id = "plastic",        name = "Plastic Spray Bottle",      cost = 5500,      island = "starterIsland" },
        { id = "copper",         name = "Copper Spray Bottle",       cost = 26000,     island = "starterIsland" },
        { id = "steel",          name = "Steel Spray Bottle",        cost = 100000,    island = "starterIsland" },
        { id = "gold",           name = "Gold Spray Bottle",         cost = 220000,    island = "starterIsland" },
        { id = "turquoise",      name = "Turquoise Spray Bottle",    cost = 400000,    island = "starterIsland" },
        { id = "plasticWasher",  name = "Plastic Pressure Washer",   cost = 640000,    island = "island2" },
        { id = "metalWasher",    name = "Metal Pressure Washer",     cost = 1000000,   island = "island2" },
        { id = "obsidianWasher", name = "Obsidian Pressure Washer",  cost = 1600000,   island = "island2" },
        { id = "opalWasher",     name = "Opal Pressure Washer",      cost = 2800000,   island = "island2" },
        { id = "garnetWasher",   name = "Garnet Pressure Washer",    cost = 5200000,   island = "island2" },
        { id = "sandstoneWasher",name = "Sandstone Pressure Washer", cost = 14500000,  island = "island3" },
        { id = "amberWasher",    name = "Amber Pressure Washer",     cost = 23000000,  island = "island3" },
        { id = "scarabWasher",   name = "Scarab Pressure Washer",    cost = 36000000,  island = "island3" },
        { id = "malachiteWasher",name = "Malachite Pressure Washer", cost = 64000000,  island = "island3" },
        { id = "aquamarineWasher",name="Aquamarine Pressure Washer", cost = 118000000, island = "island3" },
    },
}

local function gearDisplay(item)
    return item.name .. " (" .. tostring(item.cost) .. " Gold)"
end

local function gearIdFromDisplay(category, display)
    for _, item in ipairs(GEAR_CATALOG[category] or {}) do
        if gearDisplay(item) == display then return item.id end
    end
    return nil
end

-- dropdown selection state: per-category SET of selected ids. Default = all
-- catalog items selected (matches the multi-dropdowns' Default = opts).
local buySel = { shovel = {}, detector = {}, spray = {} }
for cat, items in pairs(GEAR_CATALOG) do
    for _, item in ipairs(items) do
        buySel[cat][item.id] = true
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- BUY ENGINE V2 (self-contained, caches everything once, robust error handling)
-- ══════════════════════════════════════════════════════════════════════════════
local BUY_RT, BUY_SF, BUY_FW, BUY_DC = nil, nil, nil, nil

local function buyInit()
    -- Initialize all cached modules in one shot. Called lazily on first buy.
    if BUY_RT and BUY_SF and BUY_DC then return true end
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local ps = game:GetService("Players").LocalPlayer.PlayerScripts
        BUY_RT = require(rs:WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
        local sn = require(ps.TS.network.ShopNetwork)
        BUY_SF = sn and sn.ShopFunctions
        local fw = require(rs.rbxts_include:WaitForChild("node_modules"):WaitForChild("@flamework"):WaitForChild("core"):WaitForChild("out"))
        if fw and fw.Flamework then
            BUY_FW = fw.Flamework
            BUY_DC = BUY_FW.resolveDependency("client/controllers/data/DataController@DataController")
        end
    end)
    return BUY_RT ~= nil and BUY_SF ~= nil and BUY_DC ~= nil
end

local function buyGetData()
    if not BUY_DC then return nil end
    local ok, dat = pcall(function()
        if type(BUY_DC.getDataIfLoaded) == "function" then
            return BUY_DC:getDataIfLoaded()
        end
        return BUY_DC.data
    end)
    return ok and dat or nil
end

local function buyGetHRP()
    local char = game.Players.LocalPlayer.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or (char:FindFirstChildOfClass("Humanoid") and char.HumanoidRootPart))
end

local function buyFindShop(category, islandId)
    local names = { starterIsland = "Home Beach", island2 = "Shipwreck Cove", island3 = "Sphinx Sands" }
    local isl = workspace:FindFirstChild("Islands")
    isl = isl and isl:FindFirstChild(names[islandId or "starterIsland"])
    local gear = isl and isl:FindFirstChild("NPCs") and isl.NPCs:FindFirstChild("Gear")
    if not gear then return nil end
    -- island3 (Sphinx Sands) has "Sprays" instead of "BuySprays" - try both
    local pref = ({ shovel = "BuyShovels", detector = "BuyDetectors", spray = "BuySprays" })[category]
    local hit = pref and (gear:FindFirstChild(pref) or (pref == "BuySprays" and gear:FindFirstChild("Sprays")))
    if hit then return hit end
    local kw = ({ shovel = "Shovel", detector = "Detector", spray = "Spray" })[category]
    for _, c in ipairs(gear:GetChildren()) do
        if string.find(c.Name, kw, 1, true) and not string.find(c.Name, "Stand", 1, true) then
            return c
        end
    end
    return nil
end

local function buyItem(category, id)
    if not buyInit() then return "env" end
    -- find item definition
    local def
    for _, item in ipairs(GEAR_CATALOG[category] or {}) do
        if item.id == id then def = item; break end
    end
    if not def then return "config" end
    -- check player data
    local pd = buyGetData()
    if not pd then return "data" end
    local of = ({ shovel = "OwnedShovels", detector = "OwnedDetectors", spray = "OwnedSprays" })[category]
    for _, oid in ipairs(pd[of] or {}) do if oid == id then return "owned" end end
    local unlocked = false
    for _, iid in ipairs(pd.UnlockedIslands or {}) do if iid == def.island then unlocked = true; break end end
    if not unlocked then return "locked" end
    if (pd.Gold or 0) < def.cost then return "gold" end
    -- teleport to shop
    local shop = buyFindShop(category, def.island)
    if not shop then return "shop" end
    local hrp = buyGetHRP()
    if hrp then
        hrp.CFrame = CFrame.new(shop:GetPivot().Position + Vector3.new(0, 4, 0))
        task.wait(0.7)
    end
    -- invoke buy
    local ok, res = pcall(function()
        return BUY_RT.await(BUY_SF.buyGear:invoke(category, id))
    end)
    return (ok and res) and "ok" or "fail"
end

BuySelectedGear = function()
    if buyRunning then return 0, 0, { "already buying" } end
    buyRunning = true
    local bought, skipped, reasons = 0, 0, {}
    for _, cat in ipairs({ "shovel", "detector", "spray" }) do
        for id in pairs(buySel[cat] or {}) do
            local res = buyItem(cat, id)
            if res == "ok" then bought = bought + 1
            else skipped = skipped + 1; reasons[#reasons + 1] = cat .. ": " .. id .. " (" .. res .. ")" end
            task.wait(0.4)
        end
    end
    buyRunning = false
    return bought, skipped, reasons
end

BuyAllGear = function()
    if buyRunning then return 0, 0 end
    buyRunning = true
    local bought, skipped = 0, 0
    for _, cat in ipairs({ "shovel", "detector", "spray" }) do
        for _, item in ipairs(GEAR_CATALOG[cat] or {}) do
            local res = buyItem(cat, item.id)
            if res == "ok" then bought = bought + 1
            elseif res ~= "owned" then skipped = skipped + 1 end
            task.wait(0.4)
        end
    end
    buyRunning = false
    return bought, skipped
end

-- ══════════════════════════════════════════════════════════════════════════════
-- UI
-- ══════════════════════════════════════════════════════════════════════════════
local AutoTab = Window:AddTab({ Name = "Auto", Subtitle = "Automation", Icon = "lightning" })

local DigSub = AutoTab:AddSubTab("Auto Dig")
DigSub:AddToggle({
    Name = "Enable Auto Dig",
    Default = false,
    Flag = "dig_enabled",
    Callback = safeCallback(function(v)
        digEnabled = v
        notifyOn("Auto Dig", v)
        if v and type(DigLoop) == "function" then task.spawn(DigLoop) end
    end),
})
DigSub:AddToggle({
    Name = "Max Power Stop (5x Luck)",
    Default = true,
    Flag = "dig_maxpower",
    Callback = function(v) digMaxPower = v end,
})
local digRarityDropdown = DigSub:AddMultiDropdown({
    Name = "Buried Rarity Filter",
    Options = RARITY_OPTIONS,
    Default = RARITY_OPTIONS, -- all on = dig everything (old default)
    Flag = "dig_rarities",
    Callback = function(sel) digRarities = raritySetFromSel(sel) end,
})
registerResync(digRarityDropdown, function(sel) digRarities = raritySetFromSel(sel) end)
DigSub:AddButton({
    Name = "Teleport To Dig Area",
    Callback = safeCallback(function()
        if type(GoDigArea) == "function" then GoDigArea() end
    end),
})
DigSub:AddButton({
    Name = "Dig Once",
    Callback = safeCallback(function()
        task.spawn(function()
            if type(DoDig) ~= "function" then return end
            local okDig = DoDig()
            Notify("Auto Dig", okDig and "Dug an item!" or "Dig failed", okDig and "Success" or "Error")
        end)
    end),
})
local CleanSub = AutoTab:AddSubTab("Auto Clean")
CleanSub:AddToggle({
    Name = "Enable Auto Clean",
    Default = true,
    Flag = "clean_enabled",
    Callback = safeCallback(function(v)
        cleanEnabled = v
        notifyOn("Auto Clean", v)
        if v and type(CleanLoop) == "function" then task.spawn(CleanLoop) end
    end),
})
CleanSub:AddButton({
    Name = "Instant Clean",
    Callback = safeCallback(function()
        task.spawn(function()
            if type(CleanAll) ~= "function" then return end
            -- Enable all optimizations for this run
            local prevTurbo = turboClean
            local prevSkip = skipCleanPass
            turboClean = true
            skipCleanPass = true
            -- re-fire powerful spray
            pcall(function()
                local mn = require(LocalPlayer.PlayerScripts.TS.network.MiscNetwork)
                if mn and mn.MiscEvents and mn.MiscEvents.SetPowerfulSpray then
                    mn.MiscEvents.SetPowerfulSpray:Fire(true)
                end
            end)
            local n = CleanAll()
            turboClean = prevTurbo
            skipCleanPass = prevSkip
            Notify("Instant Clean", ("Cleaned %d item(s)"):format(n), n > 0 and "Success" or "Info")
        end)
    end),
})

local SellSub = AutoTab:AddSubTab("Auto Sell")
SellSub:AddToggle({
    Name = "Enable Auto Sell",
    Default = false,
    Flag = "sell_enabled",
    Callback = safeCallback(function(v)
        sellEnabled = v
        notifyOn("Auto Sell", v)
        if v and type(SellLoop) == "function" then task.spawn(SellLoop) end
    end),
})
SellSub:AddSlider({
    Name = "Sell Interval",
    Min = 5,
    Max = 120,
    Default = 20,
    Suffix = "s",
    Flag = "sell_interval",
    Callback = function(v) sellInterval = v end,
})
SellSub:AddButton({
    Name = "Sell Now",
    Callback = safeCallback(function()
        task.spawn(function()
            if type(DoSell) == "function" then DoSell() end
        end)
    end),
})

local CollectSub = AutoTab:AddSubTab("Auto Collect")
CollectSub:AddToggle({
    Name = "Collect Pedestal Items",
    Default = false,
    Flag = "collect_enabled",
    Callback = safeCallback(function(v)
        collectEnabled = v
        notifyOn("Auto Collect", v)
        if v and type(CollectLoop) == "function" then task.spawn(CollectLoop) end
    end),
})
CollectSub:AddToggle({
    Name = "Collect Polish Money",
    Default = false,
    Flag = "polish_enabled",
    Callback = function(v) polishEnabled = v end,
})
CollectSub:AddButton({
    Name = "Collect Now",
    Callback = safeCallback(function()
        task.spawn(function()
            if type(CollectOnce) ~= "function" then return end
            local n = CollectOnce()
            Notify("Collect", ("Collected %d thing(s)"):format(n), n > 0 and "Success" or "Info")
        end)
    end),
})

-- Buy Gear: pick one or more items per category in the multi-select
-- dropdowns, then buy the selection (or everything) through the game's own
-- buyGear remote. The server validates price / island unlock / proximity on
-- every purchase, so "buy" teleports to the right island shop and invokes the
-- real purchase.
local BuySub = AutoTab:AddSubTab("Buy Gear")
for _, cat in ipairs({ "shovel", "detector", "spray" }) do
    local opts = {}
    for _, item in ipairs(GEAR_CATALOG[cat]) do
        opts[#opts + 1] = gearDisplay(item)
    end
    local function setFromSel(sel)
        local set = {}
        for _, o in ipairs(sel or {}) do
            local id = gearIdFromDisplay(cat, o)
            if id then set[id] = true end
        end
        return set
    end
    local dd = BuySub:AddMultiDropdown({
        Name = ({ shovel = "Shovels", detector = "Detectors", spray = "Spray Bottles" })[cat],
        Options = opts,
        Default = opts, -- all selected: "Buy Selected" = buy everything
        Flag = "buy_" .. cat,
        Callback = function(sel) buySel[cat] = setFromSel(sel) end,
    })
    registerResync(dd, function(sel) buySel[cat] = setFromSel(sel) end)
end
BuySub:AddButton({
    Name = "Buy Selected Gear",
    Callback = safeCallback(function()
        safeSpawn(function()
            local bought, skipped, reasons = BuySelectedGear()
            Notify("Shop", ("Bought %d item(s)"):format(bought), bought > 0 and "Success" or "Info")
            if skipped > 0 then
                Notify("Shop", ("%d skipped: %s"):format(skipped, table.concat(reasons, ", ")), "Warning", 4)
            end
        end)
    end),
})
BuySub:AddButton({
    Name = "Buy All Gear",
    Callback = safeCallback(function()
        safeSpawn(function()
            local bought, skipped = BuyAllGear()
            Notify("Shop", ("Bought %d item(s)"):format(bought), bought > 0 and "Success" or "Info")
            if skipped > 0 then
                Notify("Shop", ("%d skipped (owned / locked / no gold / env)"):format(skipped), "Warning")
            end
        end)
    end),
})

local TeleTab = Window:AddTab({ Name = "Teleports", Subtitle = "Quick travel", Icon = "map" })
local TeleSub = TeleTab:AddSubTab("Teleports")
TeleSub:AddButton({
    Name = "Go To Dig Area",
    Callback = safeCallback(function()
        if type(GoDigArea) == "function" then GoDigArea() end
    end),
})
TeleSub:AddButton({
    Name = "Go To Sell NPC",
    Callback = safeCallback(function()
        local npc = type(ResolveSellNpc) == "function" and ResolveSellNpc()
        if npc then
            TeleportTo(npc.Position, 3)
            Notify("Teleport", "At Sell NPC", "Success")
        else
            Notify("Teleport", "Sell NPC not found", "Error")
        end
    end),
})
TeleSub:AddButton({
    Name = "Go To My Plot",
    Callback = safeCallback(function()
        if type(MyPlot) ~= "function" then return end
        local plot = MyPlot()
        if plot then
            local root = plot:FindFirstChild("Plot") or plot
            local okBb, bb = pcall(function() return select(2, root:GetBoundingBox()) end)
            local pos = okBb and bb
            if pos then
                TeleportTo(pos.Position, 6)
                Notify("Teleport", "At your plot", "Success")
            end
        else
            Notify("Teleport", "No plot found", "Error")
        end
    end),
})

local PatcherTab = Window:AddTab({ Name = "Patcher", Subtitle = "Game patches", Icon = "wrench" })
local PatcherSub = PatcherTab:AddSubTab("Patches")

-- Patch functions (called by toggles AND on auto-load)
-- IMPORTANT: Use PlayerScripts.TS instead of ReplicatedStorage.TS because
-- many executors block ReplicatedStorage access ("lacking capability" spam).
-- PlayerScripts is always accessible since it's local to the player.

-- Helper: patch an upvalue (cached local) in a function by scanning all
-- upvalues for a matching name. Used because controllers copy config values
-- into locals at require-time, so modifying the source module is too late.
local function getControllerClass(folder, name)
    local mod = folder and folder:FindFirstChild(name)
    if not (mod and mod:IsA("ModuleScript")) then return nil end
    local exports = require(mod)
    return exports and exports[name]
end

local function hookUpvalueBySource(cls, sourcePattern, newFn)
    if not cls then return false end
    for _, method in pairs(cls) do
        if type(method) == "function" then
            for i = 1, 50 do
                local ok, upval = pcall(debug.getupvalue, method, i)
                if not ok or upval == nil then break end
                if type(upval) == "function" then
                    local ok2, src = pcall(debug.info, upval, "s")
                    if ok2 and src and src:find(sourcePattern) then
                        hookfunction(upval, newFn)
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function hookMethod(cls, methodName, newFn)
    if not cls or type(cls[methodName]) ~= "function" then return false end
    hookfunction(cls[methodName], newFn)
    return true
end

-- Patches that use hookfunction (works at function-object level even
-- when controllers cached the function as a local)

local function applyCheapPolishing()
    -- polisherUnlockCostFor is cached as a local in PlotSectionComponent.
    -- Hook the function object directly via upvalue extraction.
    local ok = false
    pcall(function()
        local ctrl = LocalPlayer.PlayerScripts:FindFirstChild("TS")
        local world = ctrl and ctrl:FindFirstChild("components") and ctrl.components:FindFirstChild("world")
        if not world then return end
        -- PlotSectionComponent caches polisherUnlockCostFor from PlotSections module
        local cls = getControllerClass(world, "PlotSectionComponent")
        if hookUpvalueBySource(cls, "plot.PlotSections", function() return 1 end) then
            ok = true
        end
        -- Also check PolisherComponent
        local pc = getControllerClass(world, "PolisherComponent")
        if pc and hookUpvalueBySource(pc, "PlotSections", function() return 1 end) then
            ok = true
        end
    end)
    return ok
end

local function applyVIPBypass()
    -- All VIP controllers cache hasVip from ReplicatedStorage.TS.monetization.Vip
    -- as a local. We hook the function object via upvalue extraction.
    local ok = false
    local newFn = function() return true end
    pcall(function()
        local ctrl = LocalPlayer.PlayerScripts:FindFirstChild("TS")
        if not ctrl then return end
        local controllers = ctrl:FindFirstChild("controllers")
        if not controllers then return end
        local ui = controllers:FindFirstChild("ui")
        local plot = controllers:FindFirstChild("plot")
        -- BenefitsController (source: monetization/Vip)
        local bc = getControllerClass(ui, "BenefitsController")
        if hookUpvalueBySource(bc, "monetization.Vip", newFn) then ok = true end
        -- VipShopController
        local vc = getControllerClass(ui, "VipShopController")
        if hookUpvalueBySource(vc, "monetization.Vip", newFn) then ok = true end
        -- VipSignController
        local sc = getControllerClass(plot, "VipSignController")
        if hookUpvalueBySource(sc, "monetization.Vip", newFn) then ok = true end
    end)
    return ok
end

-- Controller method hooks (for constant patches where debug.setupvalue fails)

local function applyDetectorSpeed()
    -- Hook the one-shot onStart method to speed up the sweep timer once
    -- when a sweep begins, instead of every frame via onRender (laggy).
    local ok = false
    pcall(function()
        local ctrl = LocalPlayer.PlayerScripts:FindFirstChild("TS")
        local world = ctrl and ctrl.controllers:FindFirstChild("world")
        if not world then return end
        local cls = getControllerClass(world, "DetectorSweepController")
        if not cls then return end
        -- Hook onStart: set sweepStartedAt far in the past so the sweep
        -- completes in 1 frame. Called ONCE per sweep, not every frame.
        local origStart = cls.onStart
        if type(origStart) == "function" then
            local hooked = function(self, ...)
                local result = origStart(self, ...)
                if self.sweepStartedAt then
                    self.sweepStartedAt = os.clock() - 10
                end
                return result
            end
            hookfunction(origStart, hooked)
            ok = true
        end
    end)
    return ok
end

local function applyDigSpeed()
    -- InstallDigHooks already handles minigame speed (patches updateMinigame).
    -- We only hook one-shot methods here — NO per-frame hooks (those cause lag).
    local ok = false
    pcall(function()
        local ctrl = LocalPlayer.PlayerScripts:FindFirstChild("TS")
        local world = ctrl and ctrl.controllers:FindFirstChild("world")
        if not world then return end
        local cls = getControllerClass(world, "DigController")
        if not cls then return end
        -- Hook beginDig (called ONCE when digging starts) to remove surface delay
        local origBegin = cls.beginDig
        if type(origBegin) == "function" then
            local hooked = function(self, ...)
                if self.buriedRevealStartedAt then
                    self.buriedRevealStartedAt = os.clock() - 100
                end
                return origBegin(self, ...)
            end
            hookfunction(origBegin, hooked)
            ok = true
        end
    end)
    return ok
end

-- Patcher toggles
PatcherSub:AddToggle({
    Name = "Cheap Polishing (1 Gold upgrades)",
    Default = true,
    Flag = "patch_polishing",
    Callback = safeCallback(function(v)
        if v then
            local ok = applyCheapPolishing()
            notifyOn("Cheap Polishing", ok)
        end
    end),
})
PatcherSub:AddToggle({
    Name = "VIP Bypass (free VIP perks)",
    Default = true,
    Flag = "patch_vip",
    Callback = safeCallback(function(v)
        if v then
            local ok = applyVIPBypass()
            notifyOn("VIP Bypass", ok)
        end
    end),
})
PatcherSub:AddToggle({
    Name = "Detector 16x Speed",
    Default = true,
    Flag = "patch_detector",
    Callback = safeCallback(function(v)
        if v then
            local ok = applyDetectorSpeed()
            notifyOn("Detector Speed", ok)
        end
    end),
})
PatcherSub:AddToggle({
    Name = "No Dig Cooldown",
    Default = true,
    Flag = "patch_digging",
    Callback = safeCallback(function(v)
        if v then
            local ok = applyDigSpeed()
            notifyOn("Dig Cooldown", ok)
        end
    end),
})

local SettingsTab = Window:AddTab({ Name = "Settings", Subtitle = "Config & unload", Icon = "gear" })
local SettingsSub = SettingsTab:AddSubTab("Settings")
SettingsSub:AddButton({
    Name = "Save Config",
    Callback = function()
        if HAS_CONFIG then
            Library:SaveConfig(CONFIG_NAME)
            Notify("Config", "Saved!", "Success")
        end
    end,
})
SettingsSub:AddButton({
    Name = "Load Config",
    Callback = function()
        if HAS_CONFIG then
            Library:LoadConfig(CONFIG_NAME)
            task.wait(0.1)
            ResyncAll()
            Notify("Config", "Loaded!", "Success")
        end
    end,
})
pcall(function()
    SettingsSub:AddKeybind({
        Name = "Toggle Auto Dig",
        Default = "LeftAlt",
        Flag = "dig_keybind",
        Callback = safeCallback(function()
            local v = not digEnabled
            digEnabled = v
            notifyOn("Auto Dig", v)
            if v and type(DigLoop) == "function" then task.spawn(DigLoop) end
        end),
    })
end)
SettingsSub:AddButton({
    Name = "Unload",
    Callback = safeCallback(function()
        digEnabled = false
        cleanEnabled = false
        sellEnabled = false
        collectEnabled = false
        if type(RestoreDigHooks) == "function" then RestoreDigHooks() end
        Notify("Oxide HUB", "Script unloaded", "Info")
        pcall(function() Window:Destroy() end)
    end),
})

-- ══════════════════════════════════════════════════════════════════════════════
-- GAME API INIT (pcall-guarded: UI is already up, failures degrade gracefully)
-- ══════════════════════════════════════════════════════════════════════════════
local ENV_OK = false
local envWarned = false
local RuntimeLib
local ShovelEvents, ShovelFunctions, ItemsFunctions, ItemsEvents
local SellFunctions, PedestalFunctions, PolisherFunctions, DetectorEvents
local ShopFunctions
local Flamework
local DetectorController, ShovelController

local function EnvGate(feature)
    if ENV_OK then return true end
    if not envWarned then
        envWarned = true
        Notify(feature, "Game API init failed - UI only", "Error", 4)
    end
    return false
end

local function Await(promise)
    if RuntimeLib then return RuntimeLib.await(promise) end
    return nil
end

-- Auto-apply patches OUTSIDE main init pcall so they always run
-- even if ReplicatedStorage init fails.
task.spawn(function()
    for _ = 1, 5 do
        if applyCheapPolishing() then break end
        task.wait(0.8)
    end
end)
task.spawn(function()
    for _ = 1, 5 do
        if applyVIPBypass() then break end
        task.wait(0.8)
    end
end)
task.spawn(function()
    for _ = 1, 5 do
        if applyDetectorSpeed() then break end
        task.wait(0.8)
    end
end)
task.spawn(function()
    for _ = 1, 5 do
        if applyDigSpeed() then break end
        task.wait(0.8)
    end
end)

pcall(function()
    RuntimeLib = require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))

    -- Reuse the game's own client-side network wrappers (schemas pre-configured)
    local PlayerScripts = LocalPlayer.PlayerScripts
    local ShovelNet   = require(PlayerScripts.TS.network.ShovelNetwork)
    local ItemsNet    = require(PlayerScripts.TS.network.ItemsNetwork)
    local SellNet     = require(PlayerScripts.TS.network.SellNetwork)
    local PedNet      = require(PlayerScripts.TS.network.PedestalNetwork)
    local PolishNet   = require(PlayerScripts.TS.network.PolisherNetwork)
    local DetNet      = require(PlayerScripts.TS.network.DetectorNetwork)
    local ShopNet     = require(PlayerScripts.TS.network.ShopNetwork)

    ShovelEvents    = ShovelNet.ShovelEvents
    ShovelFunctions = ShovelNet.ShovelFunctions
    ItemsFunctions  = ItemsNet.ItemsFunctions
    ItemsEvents     = ItemsNet.ItemsEvents
    SellFunctions   = SellNet.SellFunctions
    PedestalFunctions = PedNet.PedestalFunctions
    PolisherFunctions = PolishNet.PolisherFunctions
    DetectorEvents  = DetNet.DetectorEvents
    ShopFunctions   = ShopNet.ShopFunctions

    -- Flamework controllers: needed to HOLD the detector (the server only
    -- streams BuriedNodes to players who really hold it) and to read inventory.
    local okFw, fw = pcall(require, ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out)
    if okFw and fw and fw.Flamework then
        Flamework = fw
        pcall(function()
            DetectorController = Flamework.Flamework.resolveDependency("client/controllers/world/DetectorController@DetectorController")
        end)
        pcall(function()
            ShovelController = Flamework.Flamework.resolveDependency("client/controllers/world/ShovelController@ShovelController")
        end)
    end

    -- World anchors (NPCs.Sell is a MODEL - the BasePart is SellerNPC.HumanoidRootPart).
    -- Resolved lazily in ResolveSellNpc() (defined below the init block).

    DetectorEvents.BuriedNodes:connect(function(added, removed)
        local now = os.clock()
        for _, node in added do
            node.at = now
            buriedNodes[node.id] = node
        end
        for _, id in removed do
            buriedNodes[id] = nil
            failedNodes[id] = nil
        end
    end)

    ShovelEvents.SurfacedItemSpawned:connect(function(spot)
        surfacedSpots[spot.id] = spot
    end)
    ShovelEvents.SurfacedItemReleased:connect(function(spot)
        surfacedSpots[spot.id] = spot
    end)
    ShovelEvents.SurfacedItemRemoved:connect(function(id)
        surfacedSpots[id] = nil
    end)

    -- make sure the shovel rig is equipped (server requires it for digs)
    pcall(function() ShovelEvents.SetShovelEquipped:fire(true) end)

    -- persistent keeper: re-hold the detector every 3s so the node stream stays
    -- on - but NEVER while a dig is in progress (unequipping mid-dig kills the
    -- session, which is why rare+ digs used to fail).
    if not detectorKeeper then
        detectorKeeper = true
        task.spawn(function()
            while true do
                if not digging and DetectorController and DetectorController.localRig then
                    pcall(function()
                        if ShovelController and ShovelController.localRig then
                            ShovelController:setEquipped(ShovelController.localRig, false)
                        end
                        DetectorController:setHeld(DetectorController.localRig, true)
                        DetectorEvents.SetDetectorHeld:fire(true)
                    end)
                end
                task.wait(3)
            end
        end)
    end

    ENV_OK = true

    -- Capture the game's own digZoneAt for authoritative zone validation
    pcall(function()
        GAME_digZoneAt = require(ReplicatedStorage.TS.utils.world.DigZoneSpawn).digZoneAt
    end)

    -- #2: Enable Turbo Clean (Powerful Spray mode)
    pcall(function()
        local mn = require(PlayerScripts.TS.network.MiscNetwork)
        if mn and mn.MiscEvents and mn.MiscEvents.SetPowerfulSpray then
            mn.MiscEvents.SetPowerfulSpray:Fire(true)
            Notify("OP Features", "Turbo Clean enabled", "Success", 2)
        end
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- UTIL
-- ══════════════════════════════════════════════════════════════════════════════
function HumanoidRoot()
    local char = LocalPlayer.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildOfClass("Humanoid") and char.HumanoidRootPart)
end

function TeleportTo(position, yOffset)
    local hrp = HumanoidRoot()
    if hrp then
        hrp.CFrame = CFrame.new(position + Vector3.new(0, (yOffset or 3), 0))
    end
end

function NearestDigZoneCenter()
    local tagged = CollectionService:GetTagged("DigZone")
    local best, bestDist = nil, math.huge
    local hrp = HumanoidRoot()
    local origin = hrp and hrp.Position or Vector3.zero
    for _, part in tagged do
        if part:IsA("BasePart") then
            local d = (part.Position - origin).Magnitude
            if d < bestDist then best, bestDist = part, d end
        end
    end
    if best then return best.Position end
    if not ENV_OK then return nil end
    local island = Workspace:FindFirstChild("Islands") and Workspace.Islands:FindFirstChild("Home Beach")
    local digArea = island and island:FindFirstChild("DigAreas") and island.DigAreas:FindFirstChild("DigArea")
    return digArea and digArea:IsA("BasePart") and digArea.Position or nil
end

local function rarityOk(r)
    if not r then return true end
    return digRarities[r] == true -- empty set (all unchecked) digs nothing
end

local NODE_MAX_AGE = 60 -- BURIED_LIFETIME_MIN; prune stale nodes before digging
local NODE_FAIL_COOLDOWN = 20 -- seconds before retrying a node that failed to dig

local function MarkNodeFailed(id)
    if id then failedNodes[id] = os.clock() end
end

local function NodeFailed(id)
    local at = failedNodes[id]
    return at ~= nil and (os.clock() - at) < NODE_FAIL_COOLDOWN
end

-- Use the game's own digZoneAt function (from DigZoneSpawn module) for
-- authoritative validation. Falls back to CollectionService bounding-box if
-- the module can't be loaded.
local GAME_digZoneAt = nil

local function IsInDigZone(pos)
    if not pos then return false end
    -- Prefer the game's own function (most accurate)
    if GAME_digZoneAt then
        return GAME_digZoneAt(pos) ~= nil
    end
    -- Fallback: bounding box check on DigZone-tagged parts
    for _, part in ipairs(CollectionService:GetTagged("DigZone")) do
        if part:IsA("BasePart") then
            local half = part.Size * 0.5
            if math.abs(pos.X - part.Position.X) <= half.X + 2
                and math.abs(pos.Z - part.Position.Z) <= half.Z + 2 then
                return true
            end
        end
    end
    return false
end

local function NearestBuriedNode()
    local hrp = HumanoidRoot()
    if not hrp then return nil end
    local now = os.clock()
    local best, bestDist = nil, math.huge
    for id, node in buriedNodes do
        if now - (node.at or 0) > NODE_MAX_AGE then
            buriedNodes[id] = nil
        elseif not NodeFailed(id) and rarityOk(node.rarity) and node.position
            and IsInDigZone(node.position) then
            local d = (node.position - hrp.Position).Magnitude
            if d < bestDist then best, bestDist = node, d end
        end
    end
    return best, bestDist
end

local function NearestSurfacedSpot()
    local hrp = HumanoidRoot()
    if not hrp then return nil end
    local best, bestDist = nil, math.huge
    for _, spot in surfacedSpots do
        if spot.position and IsInDigZone(spot.position) then
            local d = (spot.position - hrp.Position).Magnitude
            if d < bestDist then best, bestDist = spot, d end
        end
    end
    return best, bestDist
end

-- Full player data from the DataController (OwnedShovels / UnlockedIslands /
-- Gold / Inventory live on the root table). Shared by GetInventory and the
-- shop engine; never mutate the returned table (it is the game's live data).
local function GetPlayerData()
    if not Flamework or not Flamework.Flamework then
        local ok, fw = pcall(require, ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out)
        if not ok or not fw or not fw.Flamework then return nil end
        Flamework = fw
    end
    local ok, dataCtrl = pcall(function()
        return Flamework.Flamework.resolveDependency("client/controllers/data/DataController@DataController")
    end)
    if not ok or not dataCtrl then return nil end
    local okGet, data = pcall(function()
        if type(dataCtrl.getDataIfLoaded) == "function" then
            return dataCtrl:getDataIfLoaded()
        end
        return dataCtrl.data
    end)
    if not okGet or not data then return nil end
    return data
end

function GetInventory()
    local data = GetPlayerData()
    return data and data.Inventory
end

-- Buy gear from the in-world gear shops. The server validates EVERY purchase:
--   * price (Gold is deducted - verified live: metalShovel cost exactly 9,000)
--   * island unlock (island2 shovels are rejected on starterIsland) - verified
--   * proximity (must be near the island's BuyShovels container) - verified
-- So there is no free unlock; this just automates buying everything affordable.
local ISLAND_SHOP_NAMES = {
    starterIsland = "Home Beach",
    island2       = "Shipwreck Cove",
    island3       = "Sphinx Sands",
}

-- Shop container per island + category. Verified live: Home Beach has
-- BuyShovels / BuyDetectors / BuySprays, Shipwreck Cove has BuyShovels /
-- BuyDetectors / Sprays (no "Buy" prefix on the spray stand). Fall back to a
-- keyword search so a renamed container still resolves.
local function FindGearShop(category, islandId)
    local islandName = ISLAND_SHOP_NAMES[islandId or "starterIsland"]
    local islands = Workspace:FindFirstChild("Islands")
    local isl = islands and islands:FindFirstChild(islandName)
    local gear = isl and isl:FindFirstChild("NPCs") and isl.NPCs:FindFirstChild("Gear")
    if not gear then return nil end
    local preferred = ({
        shovel   = "BuyShovels",
        detector = "BuyDetectors",
        spray    = "BuySprays",
    })[category]
    local hit = preferred and gear:FindFirstChild(preferred)
    if hit then return hit end
    local kw = ({
        shovel   = "Shovel",
        detector = "Detector",
        spray    = "Spray",
    })[category]
    for _, child in ipairs(gear:GetChildren()) do
        -- skip display stands ("ShovelStand") so the fallback never resolves
        -- to a non-interactive model
        if string.find(child.Name, kw, 1, true)
            and not string.find(child.Name, "Stand", 1, true) then
            return child
        end
    end
    return nil
end

-- The game maps categories to owned fields: "shovel" -> OwnedShovels,
-- "spray" -> OwnedSprays, everything else (detectors) -> OwnedDetectors.
local GEAR_OWNED_FIELD = {
    shovel   = "OwnedShovels",
    detector = "OwnedDetectors",
    spray    = "OwnedSprays",
}




-- Sell NPC: NPCs.Sell is a MODEL; the part is SellerNPC.HumanoidRootPart.
function ResolveSellNpc()
    local function findInIsland(island)
        local npcs = island and island:FindFirstChild("NPCs")
        local sell = npcs and npcs:FindFirstChild("Sell")
        local seller = sell and sell:FindFirstChild("SellerNPC")
        local hrp = seller and seller:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:IsA("BasePart") then return hrp end
        -- fallback: any BasePart under the Sell model
        if sell then
            for _, child in sell:GetDescendants() do
                if child:IsA("BasePart") then return child end
            end
        end
        return nil
    end
    local islands = Workspace:FindFirstChild("Islands")
    if islands then
        for _, island in islands:GetChildren() do
            local hrp = findInIsland(island)
            if hrp then SellNpcRef = hrp; return hrp end
        end
    end
    return nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- DIG ENGINE
-- ══════════════════════════════════════════════════════════════════════════════
local DIG_FULL_MASK = string.rep("/", 64)

-- Server constants (DiggingConfig) - verified live against the real game:
--   * DIG_WIN_THRESHOLD = 0.985, DIG_PROGRESS_START = 0.33
--   * DIG_MAX_CLICKS_PER_SECOND = 50, DIG_MAX_CLICK_BURST = 30, effective 11/s
--   * DIG_POWER_PERIOD_SECONDS = 0.55 (peak at +0.275s), DIG_REVEAL_SECONDS 0.72
local DIG_WIN_THRESHOLD    = 0.985
local DIG_PROGRESS_START   = 0.33
local DIG_REVEAL_SECONDS   = 0.72
local DIG_EFFECTIVE_CPS    = 11
local DIG_SESSION_MAX_SEC  = 30
-- keep click streaming inside the server's 30s session cap: never stream for
-- longer than this, so resolve/fallback still have headroom.
local DIG_STREAM_BUDGET_SEC = 24

-- Exact click count that clears the dig bar for a difficulty: progress must
-- move from DIG_PROGRESS_START (0.33) to DIG_WIN_THRESHOLD (0.985) and each
-- click adds difficulty.clickPower. Rare+ items have tiny clickPower, so they
-- need HUNDREDS of clicks - a fixed cap made them unwinnable (the server only
-- credits ~30 clicks per burst), which is why instant dig failed at rare+.
local function NeededClicks(clickPower)
    return math.max(1, math.ceil(
        (DIG_WIN_THRESHOLD - DIG_PROGRESS_START) / math.max(clickPower or 0.001, 0.0001)
    ))
end

-- Click stream: +5 raw clicks every 0.1s (max 50 raw/s = the server's
-- DIG_MAX_CLICKS_PER_SECOND cap; a single event is capped at 30 = burst).
-- totalClicks is CUMULATIVE and monotonic. Streams until the exact needed
-- total is delivered (or the stream budget runs out), so common digs finish
-- in ~0.3s while rare+ digs keep streaming (a few seconds) but actually WIN
-- instead of getting clamped.
local function FireClicksTo(sessionId, target)
    local total = 0
    local t0 = os.clock()
    while total < target do
        if os.clock() - t0 >= DIG_STREAM_BUDGET_SEC then break end
        total = math.min(total + 5, target)
        ShovelEvents.DigInput:fire(sessionId, total)
        task.wait(0.1)
    end
    return total
end

-- Top-up stream: +5 raw clicks every 0.1s for `duration` seconds, continuing
-- from `from` so the cumulative total only ever increases.
local function FireClicks(sessionId, duration, from)
    local total = from or 0
    local t0 = os.clock()
    while os.clock() - t0 < duration do
        total = total + 5
        ShovelEvents.DigInput:fire(sessionId, total)
        task.wait(0.1)
    end
    return total
end

-- ══════════════════════════════════════════════════════════════════════════════
-- INSTANT DIG HOOKS (Aegis reference approach, verified live)
--  Patch the game's own DigController class so any session it drives completes
--  instantly through the game's own validated code path: auto-stop the power
--  bar at its peak (5x luck tier), skip the 0.72s reveal, and force the
--  minigame win with a plausible click count (finish() -> flushInput() ->
--  ResolveDig with the game's own retries). Restored on Unload.
-- ══════════════════════════════════════════════════════════════════════════════
local DigControllerClass
local origDigMethods = {}

function InstallDigHooks()
    if not DigControllerClass then return false end

    local function patch(name, newFn)
        if type(DigControllerClass[name]) == "function" and origDigMethods[name] == nil then
            origDigMethods[name] = DigControllerClass[name]
            DigControllerClass[name] = newFn
        end
    end

    -- stop the power charge at the first peak (power ~= 1.0 = top luck tier)
    patch("updatePowerBar", function(self, session, dt)
        local result = origDigMethods.updatePowerBar(self, session, dt)
        if digEnabled and session and session.phase == "power"
            and not session.powerStopping and session.power and session.power >= 0.97 then
            pcall(function() self:stopPower(false) end)
        end
        return result
    end)

    -- skip the 0.72s reveal animation
    patch("updateMoundReveal", function(self, session, dt)
        if digEnabled and session and session.phase == "revealing" then
            session.revealStarted = session.revealStarted or os.clock()
            session.revealStarted = os.clock() - 100
        end
        return origDigMethods.updateMoundReveal(self, session, dt)
    end)

    -- force the minigame win via the game's own finish() -> flushInput() ->
    -- requestResolve() path. Clicks are delivered incrementally across frames
    -- (respecting the server's 50/s + burst-30 caps) until the exact needed
    -- total for THIS difficulty is reached - rare+ digs need hundreds of
    -- clicks, so a one-shot total used to get clamped and the dig failed.
    patch("updateMinigame", function(self, session, dt)
        if digEnabled and session and session.phase == "minigame" and session.difficulty then
            local clickPower = session.difficulty.clickPower or 0.001
            local target = NeededClicks(clickPower)
            if not session.instantTarget then
                session.instantTarget = target
                session.instantSent = math.max(session.totalClicks or 0, 5)
            end
            -- deliver +5 cumulative clicks, paced >=0.1s apart, to stay inside
            -- the server's click caps until the target is reached. lastInputSent
            -- is written AFTER every flush so the pace check actually gates.
            local sent = session.instantSent
            if sent < session.instantTarget and (session.lastInputSent == nil
                or os.clock() - session.lastInputSent >= 0.1) then
                sent = math.min(sent + 5, session.instantTarget)
                session.totalClicks = sent
                session.instantSent = sent
                pcall(function() self:flushInput(session) end)
                session.lastInputSent = os.clock()
            end
            if sent >= session.instantTarget and not self:isResolving(session) then
                session.progress = 1
                pcall(function() self:finish(true) end)
            end
            return
        end
        return origDigMethods.updateMinigame(self, session, dt)
    end)

    return true
end

function RestoreDigHooks()
    if DigControllerClass then
        for name, orig in pairs(origDigMethods) do
            pcall(function() DigControllerClass[name] = orig end)
        end
    end
    table.clear(origDigMethods)
end

local function Resolve(sessionId, win, clicks)
    for _ = 1, 4 do
        local res = Await(ShovelFunctions.ResolveDig:invoke(sessionId, win, clicks):catch(function() return nil end))
        if res then return res end
        task.wait(0.35)
    end
    return nil
end

-- Returns true when an item was dug up (item goes into inventory dirty)
function DoDig()
    if not EnvGate("Auto Dig") then return false end
    if digging then return false end
    digging = true
    busy = true -- block clean/sell/collect loops for the whole dig (rare+ streams take seconds)
    local ok = false
    pcall(function()
        -- 1. nearest spot (buried node preferred, fallback surfaced item)
        local node, nodeDist = NearestBuriedNode()
        local spot, spotDist = NearestSurfacedSpot()
        local targetPos, targetId
        if node and (not spot or nodeDist <= (spotDist or 0) + 4) then
            targetPos, targetId = node.position, node.id
        elseif spot then
            targetPos, targetId = spot.position, nil
        end
        if not targetPos then
            return -- no spot anywhere; loop will roam
        end
        -- Only teleport if target is in a dig zone (prevents farming outside valid areas)
        if not IsInDigZone(targetPos) then
            return
        end
        TeleportTo(targetPos)

        -- 2. begin dig: buried nodes pass their id, surfaced spots use plain invoke
        task.wait(0.35)
        local begun = Await(ShovelFunctions.BeginDig:invoke(targetId or nil):catch(function() return nil end))
        if not begun or not begun.sessionId or not begun.difficulty then
            -- node dead/claimed/out of reach: blacklist it so the loop stops
            -- teleporting back and forth to the same spot every few seconds
            MarkNodeFailed(targetId)
            return
        end

        local sessionId = begun.sessionId
        local stop

        -- 3. buried node dig (response.surfaced) → straight minigame, power = 0.
        --    surfaced dig without rolled → power phase with StopPower.
        if not begun.surfaced and not begun.rolled then
            -- power phase: wait for the 0.55s cycle peak (power 1.0 = 5x luck)
            if digMaxPower then
                task.wait(math.max(0, 0.275 - (Workspace:GetServerTimeNow() - begun.powerStartedAt)) + 0.05)
                stop = Await(ShovelFunctions.StopPower:invoke(
                    sessionId,
                    begun.powerStartedAt + 0.275,
                    false
                ):catch(function() return nil end))
                if not stop or not stop.difficulty then
                    -- fallback: forced stop (power = DIG_POWER_DEFAULT)
                    stop = Await(ShovelFunctions.StopPower:invoke(
                        sessionId,
                        Workspace:GetServerTimeNow(),
                        true
                    ):catch(function() return nil end))
                end
                if not stop or not stop.difficulty then
                    Resolve(sessionId, false, 0)
                    return
                end
            else
                task.wait(math.max(0, 0.12 - (Workspace:GetServerTimeNow() - begun.powerStartedAt)) + 0.05)
                stop = Await(ShovelFunctions.StopPower:invoke(
                    sessionId,
                    Workspace:GetServerTimeNow(),
                    false
                ):catch(function() return nil end))
                if not stop or not stop.difficulty then
                    Resolve(sessionId, false, 0)
                    return
                end
            end
        end

        -- 4. INSTANT DIG (verified live): fire DigReady, then STREAM the exact
        --    click count this difficulty needs at the server's max accepted
        --    rate (+5/0.1s, burst-safe). Rare+ items have tiny clickPower and
        --    need hundreds of clicks - dumping them all in one event trips the
        --    30-per-burst clamp and the dig lost. Streaming makes common digs
        --    finish in ~0.3s and rare+ digs take a few seconds but WIN.
        local clickPower = 0.001
        if begun.difficulty and begun.difficulty.clickPower then
            clickPower = begun.difficulty.clickPower
        elseif stop and stop.difficulty and stop.difficulty.clickPower then
            clickPower = stop.difficulty.clickPower
        end
        local targetClicks = NeededClicks(clickPower)

        ShovelEvents.DigReady:fire(sessionId)
        task.wait(0.15)
        local sentClicks = FireClicksTo(sessionId, targetClicks)
        task.wait(0.4)

        -- 5. resolve (win = true) with retries
        local win = Resolve(sessionId, true, sentClicks)

        -- fallback: if the stream was rejected, top up with a sustained
        -- stream that continues from the delivered total (monotonic), then
        -- resolve with the true cumulative count the server has actually seen.
        if not win then
            Notify("Auto Dig", "Instant dig stalled - streaming more clicks", "Warning", 2)
            sentClicks = FireClicks(sessionId, 6, sentClicks)
            task.wait(0.4)
            win = Resolve(sessionId, true, sentClicks)
        end

        -- 6. abort the session if the dig could not be completed
        if not win then
            -- the node is a no-go: blacklist it so the loop moves on instead of
            -- teleporting to it again and again
            MarkNodeFailed(targetId)
            Resolve(sessionId, false, 0)
            return
        end

        if targetId then failedNodes[targetId] = nil end
        digCount = digCount + 1
        ok = true
    end)
    digging = false
    busy = false
    return ok
end

function GoDigArea()
    local pos = NearestDigZoneCenter()
    if pos then
        TeleportTo(pos, 4)
        Notify("Auto Dig", "Teleported to dig area", "Success")
    else
        Notify("Auto Dig", "No dig zone found", "Error")
    end
end

local function InventoryFull()
    local inv = GetInventory()
    return inv ~= nil and #inv >= 50 or false
end

function DigLoop()
    if digLoopRunning then return end -- never run two loops
    digLoopRunning = true
    local lastRoamPos = nil
    local lastRoamAt = 0
    while digEnabled do
        if not digging and not busy then
            -- never dig into a full backpack
            if InventoryFull() then
                Notify("Auto Dig", "Backpack full - sell first", "Error", 2)
                task.wait(3)
            else
                local hrp = HumanoidRoot()
                local inZone = false
                if hrp then
                    for _, part in CollectionService:GetTagged("DigZone") do
                        if part:IsA("BasePart") and (part.Position - hrp.Position).Magnitude < 40 then
                            inZone = true
                            break
                        end
                    end
                end

                local node, nodeDist = NearestBuriedNode()
                local spot, spotDist = NearestSurfacedSpot()
                -- Only consider targets in dig zones
                local target = (node and node.position and IsInDigZone(node.position)) and node.position
                    or (spot and spot.position and IsInDigZone(spot.position)) and spot.position or nil
                if target and ((node and nodeDist and nodeDist <= 20) or (spot and spotDist and spotDist <= 20)) then
                    -- spot is in reach: dig it (failed nodes get blacklisted
                    -- inside DoDig, so we never bounce back to the same spot)
                    local okDig = DoDig()
                    if okDig then
                        task.wait(0.3)
                    else
                        -- stay put: a failed node is blacklisted, so the loop
                        -- will pick the next node instead of re-teleporting
                        task.wait(1.2)
                    end
                elseif not inZone then
                    -- outside the dig zone: teleport to zone center
                    GoDigArea()
                    task.wait(1.5)
                elseif target and IsInDigZone(target) then
                    -- roam toward a known spot INSIDE the dig zone, but never
                    -- re-teleport to the same spot within 2.5s
                    local now = os.clock()
                    local sameSpot = lastRoamPos
                        and (target - lastRoamPos).Magnitude < 8
                        and (now - lastRoamAt) < 2.5
                    if not sameSpot then
                        TeleportTo(target, 2)
                        lastRoamPos = target
                        lastRoamAt = now
                    end
                    task.wait(1.2)
                else
                    -- no spots in zone: jitter around the zone center
                    lastRoamPos = nil
                    local center = NearestDigZoneCenter()
                    if center then
                        TeleportTo(center + Vector3.new(math.random(-30, 30), 0, math.random(-30, 30)), 4)
                    end
                    task.wait(1.2)
                end
            end
        else
            task.wait(0.5)
        end
    end
    digLoopRunning = false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CLEAN ENGINE
-- ══════════════════════════════════════════════════════════════════════════════
local turboClean = true  -- #2: Powerful Spray mode enabled by default
local skipCleanPass = false  -- #3: Bypass clean cost (requestSkipClean) - OFF by default (safety)

function InstantClean(uid)
    if not EnvGate("Clean") then return false end
    if not uid then return false end

    local begin = Await(ItemsFunctions.beginCleaning:invoke(uid):catch(function() return nil end))
    if begin == nil then return false end

    -- #3 Game Pass Bypass: skip the cleaning minigame instantly.
    -- Must be called AFTER beginCleaning (the game only processes it during
    -- an active cleaning session). The server may require the Instant Clean
    -- pass - use at your own risk (defaults OFF).
    if skipCleanPass then
        pcall(function() ItemsEvents.requestSkipClean:fire() end)
        task.wait(0.3) -- wait for server round-trip
        -- verify the item was actually cleaned
        local data = GetPlayerData()
        local inv = data and data.Inventory
        if inv then
            for _, item in inv do
                if item.uid == uid and not item.dirty then return true end
            end
        end
        -- skip not accepted: fall through to normal clean below
    end

    ItemsEvents.saveCleanProgress:fire(uid, DIG_FULL_MASK)
    -- #2 Turbo Clean: reduced wait time when powerful spray is active
    task.wait(turboClean and 0.05 or 0.15)
    ItemsEvents.finishCleaning:fire(uid)
    return true
end

function CleanAll()
    if not EnvGate("Clean") then return 0 end
    local inv = GetInventory()
    if not inv then
        Notify("Clean", "Inventory not loaded yet", "Error")
        return 0
    end
    local cleaned = 0
    for _, item in inv do
        if item and item.dirty and not item.pedestalSlot then
            if InstantClean(item.uid) then cleaned = cleaned + 1 end
            task.wait(0.2)
        end
    end
    return cleaned
end

function CleanLoop()
    while cleanEnabled do
        if not busy then
            busy = true
            local n = CleanAll()
            if n > 0 then Notify("Clean", ("Cleaned %d item(s)"):format(n), "Success") end
            busy = false
        end
        task.wait(3)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SELL ENGINE (proximity is enforced server-side: teleport to the NPC part)
-- ══════════════════════════════════════════════════════════════════════════════

-- Simple auto-sell: clean first, then sell everything at the NPC.
-- Proximity is enforced server-side, so we teleport to the seller.
function DoSell()
    if not EnvGate("Sell") then return nil end

    -- clean first: dirty items sell for less
    if cleanEnabled then pcall(CleanAll) end

    local npc = ResolveSellNpc()
    if not npc then
        Notify("Sell", "Sell NPC not found", "Error")
        return nil
    end

    local inv = GetInventory()
    if not inv then
        Notify("Sell", "Inventory not loaded yet", "Error")
        return nil
    end

    if #inv == 0 then return nil end

    TeleportTo(npc.Position, 3)
    task.wait(0.8)
    local money
    for _ = 1, 3 do
        money = Await(SellFunctions.sellInventory:invoke():catch(function() return nil end))
        if money then break end
        task.wait(0.5)
    end
    if money then
        lastSellAt = os.clock()
        Notify("Sell", ("Sold for +$%s"):format(tostring(money)), "Success", 3)
    end
    return money
end

function SellLoop()
    while sellEnabled do
        if not busy then
            busy = true
            DoSell()
            busy = false
        end
        task.wait(sellInterval)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- COLLECT ENGINE (pedestals + polish)
-- ══════════════════════════════════════════════════════════════════════════════
function MyPlot()
    for _, plot in Workspace.Plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return plot
        end
    end
    return nil
end

function CollectOnce()
    if not EnvGate("Collect") then return 0 end
    local plot = MyPlot()
    local got = 0
    if plot then
        -- pedestals: pick up displayed items so they can be sold/cleaned
        local pedestals = plot:FindFirstChild("Pedestals")
        if pedestals then
            for _, ped in pedestals:GetChildren() do
                local slot = ped:GetAttribute("Slot")
                local uid = ped:GetAttribute("ItemUid")
                if slot and uid then
                    local okPick = Await(PedestalFunctions.pickupItem:invoke(slot):catch(function() return nil end))
                    if okPick then
                        got = got + 1
                        task.wait(0.3)
                    end
                end
            end
        end
        -- polishers: collect finished polish
        if polishEnabled then
            local sections = plot:FindFirstChild("PlotComponents") and plot.PlotComponents:FindFirstChild("Sections")
            local polishing = sections and sections:FindFirstChild("Polishing")
            local polishers = polishing and polishing:FindFirstChild("Polishers")
            if polishers then
                for _, p in polishers:GetChildren() do
                    local slot = p:GetAttribute("Slot") or p:GetAttribute("PolisherSlot")
                    if slot then
                        local okCollect = Await(PolisherFunctions.collectPolish:invoke(slot):catch(function() return nil end))
                        if okCollect then
                            got = got + 1
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
    end
    return got
end

function CollectLoop()
    while collectEnabled do
        if not busy then
            busy = true
            local n = CollectOnce()
            if n > 0 then Notify("Collect", ("Collected %d thing(s)"):format(n), "Success") end
            busy = false
        end
        task.wait(5)
    end
end

-- Boot tasks (UI is already up, so these can never hide it)
if cleanEnabled then task.spawn(CleanLoop) end

-- Install the instant-dig controller hooks (optional, non-fatal): require the
-- game's own DigController module and patch its class methods so game-driven
-- dig sessions also win instantly through the game's own validated code path.
-- Restores any previous instance's hooks first (re-execution safe) and retries
-- briefly in case the controller modules are still loading.
task.spawn(function()
    RestoreDigHooks() -- undo hooks from any previous execution of this script
    for attempt = 1, 15 do
        local ok = pcall(function()
            local ps = LocalPlayer:FindFirstChild("PlayerScripts")
            local ts = ps and ps:FindFirstChild("TS")
            local controllers = ts and (ts:FindFirstChild("controllers") or ts:FindFirstChild("Controllers"))
            local world = controllers and controllers:FindFirstChild("world")
            local digMod = world and require(world:FindFirstChild("DigController"))
            if digMod and digMod.DigController then
                DigControllerClass = digMod.DigController
                return InstallDigHooks()
            end
            return false
        end)
        if ok then break end
        task.wait(1)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- END
-- ══════════════════════════════════════════════════════════════════════════════

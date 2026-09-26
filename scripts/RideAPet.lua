-- === HUB STRIP POINT - when executed through the hub ScriptLoader, which injects
--     "local Library = _G.ArcLib" above this line instead. ===
-- ==============================================================================

-- ==============================================================================
-- RE-EXECUTION GUARD + RESOURCE TRACKING
-- ==============================================================================
do
    local prev = _G.ArcRideAPet
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, drawings = {}, highlights = {}, dead = false, version = "1.0" }
_G.ArcRideAPet = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end
local function trackDrawing(d) if d then table.insert(HUB.drawings, d) end; return d end

local Window = Library:CreateWindow({
    Name = "Arc HUB | Reite ein Haustier",
    LoadingAnimation = true,
    LoadingText = "Arc",
    LoadingDuration = 2.0,
})

-- ==============================================================================
-- CONFIG / FLAG PERSISTENCE
-- ==============================================================================
local HAS_CONFIG = type(Library.SaveConfig) == "function"
    and type(Library.LoadConfig) == "function"
    and type(Library.ListConfigs) == "function"
local CONFIG_NAME = "rideapet"

-- ==============================================================================
-- SERVICES & LOCALS
-- ==============================================================================
local Players          = game:GetService("Players")
local RS               = game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local VirtualUser      = game:GetService("VirtualUser")
local TeleportService  = game:GetService("TeleportService")
local TweenService     = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local LP = Players.LocalPlayer
local function GetCamera()
    return Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
end
local function GetHRP()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function GetHumanoid()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Remotes
local Remotes = RS:WaitForChild("Remotes", 30)
local GameRemotes = Remotes and Remotes:WaitForChild("Game", 30)
local function Remote(name)
    if not GameRemotes then return nil end
    return GameRemotes:FindFirstChild(name)
end

-- GameData (read-only tables the game ships)
local function SafeRequire(inst)
    if not inst then return nil end
    local ok, res = pcall(require, inst)
    if ok and type(res) == "table" then return res end
    return nil
end
local GameData     = RS:FindFirstChild("GameData")
local GameServices = RS:FindFirstChild("GameServices")
local EggData      = SafeRequire(GameData and GameData:FindFirstChild("Eggs"))
local FoodData     = SafeRequire(GameData and GameData:FindFirstChild("Foods"))
local NestData     = SafeRequire(GameData and GameData:FindFirstChild("Nests"))
local RebirthData  = SafeRequire(GameData and GameData:FindFirstChild("Rebirths"))
local HatchLuck    = SafeRequire(GameData and GameData:FindFirstChild("HatchLuck"))
local GeneralData  = SafeRequire(GameData and GameData:FindFirstChild("General"))
local GeneralSvc   = SafeRequire(GameServices and GameServices:FindFirstChild("General"))
local DayNightSvc  = SafeRequire(GameServices and GameServices:FindFirstChild("DayNight"))

local NEST_PRICES = (NestData and NestData.Prices) or { 0, 1000, 5000, 100000, 1000000 }
local RARITY_ORDER = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5, Ethereal = 6, Divine = 7, Volcanic = 8 }

local function Notify(title, content, kind, dur)
    pcall(function()
        Window:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = dur or 2.5 })
    end)
end
local function safeCallback(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then pcall(Notify, "Arc HUB", "Error: " .. tostring(err), "Error", 4) end
    end
end

-- ==============================================================================
-- STATE
-- ==============================================================================
local S = {
    -- Egg loop
    eggLoop = false,
    eggPriority = "Best Value",     -- Fast Cycle | Best Value | Nearest
    eggRarities = {},               -- leer = alle
    eggLoopDelay = 0.35,
    autoPlace = true,
    autoHatch = true,
    hatchDelay = 1.0,
    maxEggTravel = 0,               -- 0 = unbegrenzt
    -- Pet loop
    petLoop = false,
    autoCollectPets = true,
    autoFeedPets = false,
    autoPlacePets = false,
    placeBestPets = true,
    -- Progress
    progressLoop = false,
    autoUnlockNests = false,
    autoRebirth = false,
    autoHatchUpgrades = false,
    autoClaimIndex = false,
    autoClaimOffline = false,
    autoClaimGroup = false,
    autoClaimEvent = false,
    autoRadar = false,
    autoRestock = false,
    autoBuyFood = false,
    autoBuyGear = false,
    -- ESP
    eggEsp = false,
    petEsp = false,
    playerEsp = false,
    espRarities = {},
    -- Player
    speedEnabled = false,
    speedValue = 16,
    jumpEnabled = false,
    jumpValue = 50,
    flyEnabled = false,
    flySpeed = 60,
    noclip = false,
    farmNoclip = true,          -- Noclip automatisch während des Egg-Farms
    farmNoclipActive = false,
    luckBuying = false,         -- Button "Luck kaufen"
    luckBuyDelay = 2,           -- Delay zwischen den Käufen
    luckBuyMode = "1 Upgrade",  -- "1 Upgrade" | "Max"
    upgradeReserve = 100000,    -- Cash, das für Upgrades nicht angetastet wird
    gravityEnabled = false,
    gravityValue = 196.2,
    fovEnabled = false,
    fovValue = 70,
    fullbright = false,
    fpsMode = false,
    antiAfk = true,
    antiKick = false,
    autoRejoin = false,
    -- intern
    busy = false,
    stats = { eggs = 0, hatched = 0, delivered = 0, collected = 0, rebirths = 0, nests = 0 },
}

-- Debug-Hooks (erlaubt Live-Inspektion/Steuerung von außen, z.B. via Executor)
HUB.state = S

-- ==============================================================================
-- HELPERS
-- ==============================================================================
local function EggInfo(name)
    if EggData and EggData[name] then return EggData[name] end
    return nil
end

local function RarityRank(rarity)
    return RARITY_ORDER[rarity] or 0
end

local function OwnPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, p in ipairs(plots:GetChildren()) do
        if p:GetAttribute("NestsOwnerLoaded") == LP.UserId then return p end
    end
    return nil
end
local function PlotEggs(plot) return plot and plot:FindFirstChild("Eggs") end
local function PlotNests(plot) return plot and plot:FindFirstChild("Nests") end
local function PlotPets(plot) return plot and plot:FindFirstChild("Pets") end
local function Basket() return LP:FindFirstChild("Basket") end
local function CarriedEggs() local b = Basket() return b and b:GetChildren() or {} end

local function TeleportTo(pos, yOffset)
    local hrp = GetHRP()
    if not hrp then return false end
    local target = pos + Vector3.new(0, yOffset or 3, 0)
    local ok = pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(target)
    end)
    return ok
end

local function PlayerCash()
    local sd = LP:FindFirstChild("SavedData")
    local cash = sd and sd:FindFirstChild("Cash")
    return cash and cash.Value or 0
end
local function PlayerStat(name)
    local sd = LP:FindFirstChild("SavedData")
    local v = sd and sd:FindFirstChild(name)
    return v and v.Value or 0
end

local function FirePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    local ok = pcall(fireproximityprompt, prompt)
    return ok
end

-- ==============================================================================
-- EGG SYSTEM
-- ==============================================================================
local function SpawnPads()
    local pads = {}
    local es = Workspace:FindFirstChild("EggSpawns")
    if es then
        for _, p in ipairs(es:GetChildren()) do
            if p:IsA("BasePart") then pads[#pads + 1] = p end
        end
    end
    return pads
end

-- Alle Feld-Eier (auf Spawn-Pads, mit Pickup-Prompt)
local function FieldEggs()
    local out = {}
    local pads = SpawnPads()
    local rendered = Workspace:FindFirstChild("RenderedEggs")
    if not rendered then return out end
    for _, e in ipairs(rendered:GetChildren()) do
        local prompt = e:FindFirstChild("Pickup", true)
        local pp = e.PrimaryPart or e:FindFirstChildWhichIsA("BasePart", true)
        if prompt and pp and prompt:IsA("ProximityPrompt") then
            local pad, pd = nil, 1e9
            for _, p in ipairs(pads) do
                local d = (p.Position - pp.Position).Magnitude
                if d < pd then pad, pd = p, d end
            end
            local info = EggInfo(e.Name)
            out[#out + 1] = {
                model = e,
                prompt = prompt,
                pos = pp.Position,
                pad = pad,
                padDist = pd,
                onPad = pd < 12,
                rarity = (info and info.Rarity) or "?",
                luck = (info and info.Luck) or 0,
                growth = (info and info.GrowthTime) or 0,
            }
        end
    end
    return out
end

local function RarityAllowed(rarity)
    if not S.eggRarities or next(S.eggRarities) == nil then return true end
    return S.eggRarities[rarity] == true
end

-- Priorisierung: Fast Cycle | Best Value | Nearest
local function PickTargetEgg()
    local hrp = GetHRP()
    if not hrp then return nil end
    local origin = hrp.Position
    local best, bestScore = nil, -math.huge
    for _, egg in ipairs(FieldEggs()) do
        if egg.onPad and RarityAllowed(egg.rarity) then
            local travel = ((egg.pos - origin) * Vector3.new(1, 0, 1)).Magnitude
            if S.maxEggTravel <= 0 or travel <= S.maxEggTravel then
                local score
                if S.eggPriority == "Nearest" then
                    score = -travel
                elseif S.eggPriority == "Fast Cycle" then
                    -- schnelle Runden: Wert pro (Reisezeit + Wachstumszeit)
                    local totalTime = (travel / 200) + egg.growth + 2
                    score = (RarityRank(egg.rarity) * 100 + egg.luck / 1000) / math.max(totalTime, 1)
                else -- Best Value
                    score = RarityRank(egg.rarity) * 100000 + egg.luck - travel * 0.1
                end
                if score > bestScore then bestScore, best = score, egg end
            end
        end
    end
    return best
end

-- Ei aufnehmen
local function CollectEgg(egg)
    if not egg or HUB.dead then return false end
    if #CarriedEggs() > 0 then return false, "Basket voll" end
    TeleportTo(egg.pos, 3)
    task.wait(0.18)
    FirePrompt(egg.prompt)
    task.wait(0.25)
    return #CarriedEggs() > 0
end

-- Lieferung: zur eigenen Plot-Baseplate, dann Place-Prompt am freien Nest
local function FindPlacePrompt(plot)
    local nests = PlotNests(plot)
    if not nests then return nil end
    for _, n in ipairs(nests:GetChildren()) do
        local anchor = n:FindFirstChild("PlacePromptAnchor")
        if anchor then
            local prompt = anchor:FindFirstChild("Place")
            if prompt then return prompt, anchor end
        end
    end
    return nil
end

local function DeliverAndPlace()
    local plot = OwnPlot()
    if not plot then return false, "kein Plot" end
    local base = plot:FindFirstChild("Baseplate")
    if base then
        TeleportTo(base.Position, 8)
    end
    -- Auf den Place-Prompt warten (Ei wandert vom Korb an das Nest)
    local prompt, anchor
    for _ = 1, 14 do
        task.wait(0.25)
        prompt, anchor = FindPlacePrompt(plot)
        if prompt then break end
    end
    if not prompt then return false, "kein Place-Prompt (Ei evtl. gebrochen)" end
    if anchor and anchor:IsA("BasePart") then
        TeleportTo(anchor.Position, 4)
        task.wait(0.15)
    end
    FirePrompt(prompt)
    task.wait(0.45)
    local eggs = PlotEggs(plot)
    if eggs and #eggs:GetChildren() > 0 then
        S.stats.delivered = S.stats.delivered + 1
        return true
    end
    return false
end

-- Wachstumsrestzeit eines Plot-Eis (nutzt die Spielmodule, Fallback: Serverzeit)
local function GrowthRemaining(egg)
    local data = egg:FindFirstChild("EggData")
    local placeTime = data and data:FindFirstChild("PlaceTime")
    local weight = data and data:FindFirstChild("Weight")
    local info = EggInfo(egg.Name)
    if not (placeTime and placeTime.Value > 0 and info) then return 0 end
    local growth = info.GrowthTime or 0
    if GeneralData and GeneralData.GrowthTimeFor then
        local ok, res = pcall(GeneralData.GrowthTimeFor, growth, (weight and weight.Value) or 1)
        if ok and type(res) == "number" then growth = res end
    end
    local elapsed
    if DayNightSvc and DayNightSvc.GrowthElapsed then
        local ok, res = pcall(DayNightSvc.GrowthElapsed, placeTime.Value)
        if ok and type(res) == "number" then elapsed = res end
    end
    elapsed = elapsed or (Workspace:GetServerTimeNow() - placeTime.Value)
    return math.max(growth - elapsed, 0)
end

local function HatchEgg(egg)
    local key = egg:GetAttribute("EggKey")
    if not key then return false end
    local remote = Remote("Hatch")
    if not remote then return false end
    local ok = pcall(function() remote:FireServer({ EggKey = key }) end)
    return ok
end

-- Alle reifen Eier hatchen
local function HatchReadyEggs()
    local plot = OwnPlot()
    local eggs = PlotEggs(plot)
    if not eggs then return 0 end
    local count = 0
    for _, egg in ipairs(eggs:GetChildren()) do
        local prompt = egg:FindFirstChild("Hatch", true)
        local available = prompt and prompt:GetAttribute("HatchPromptAvailable")
        local remaining = GrowthRemaining(egg)
        if available == true or remaining <= 0 then
            if HatchEgg(egg) then count = count + 1 end
            task.wait(S.hatchDelay)
        end
    end
    S.stats.hatched = S.stats.hatched + count
    return count
end

-- ==============================================================================
-- PET SYSTEM
-- ==============================================================================
local function OwnPlotPets()
    local plot = OwnPlot()
    local pets = PlotPets(plot)
    if not pets then return {} end
    local out = {}
    for _, pet in ipairs(pets:GetChildren()) do
        if pet:GetAttribute("OwnerUserId") == LP.UserId then out[#out + 1] = pet end
    end
    return out
end

local function HeldPets()
    local out = {}
    local containers = { LP:FindFirstChild("Backpack"), LP.Character }
    for _, c in ipairs(containers) do
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t:GetAttribute("PetKey") then out[#out + 1] = t end
            end
        end
    end
    return out
end

-- Pet-Earnings einsammeln
local function CollectPetEarnings()
    local remote = Remote("PetCollect")
    if not remote then return 0 end
    local n = 0
    for _, pet in ipairs(OwnPlotPets()) do
        local key = pet:GetAttribute("PetKey")
        if key then
            pcall(function() remote:FireServer(key) end)
            n = n + 1
            task.wait(0.08)
        end
    end
    S.stats.collected = S.stats.collected + n
    return n
end

-- Futter-Tool finden
local function FoodTools()
    local out = {}
    local function scan(c)
        if not c then return end
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and not t:GetAttribute("PetKey") then
                local n = tostring(t.Name)
                if FoodData and FoodData[n] then out[#out + 1] = t end
            end
        end
    end
    scan(LP:FindFirstChild("Backpack"))
    scan(LP.Character)
    return out
end

-- Pets füttern (Futter-Tool ausrüsten + Feed-Prompt)
local function FeedPets()
    local foods = FoodTools()
    if #foods == 0 then return false, "kein Futter" end
    local humanoid = GetHumanoid()
    local food = foods[1]
    if humanoid then pcall(function() humanoid:EquipTool(food) end) end
    task.wait(0.2)
    local fed = 0
    for _, pet in ipairs(OwnPlotPets()) do
        local prompt = pet:FindFirstChild("Feed", true)
        if prompt then
            FirePrompt(prompt)
            fed = fed + 1
            task.wait(0.35)
        end
    end
    return true, fed
end

-- Beste gehaltene Pets platzieren (nutzt die Spiel-eigene PlaceBest-Logik,
-- Fallback: PlacePet-Remote mit PetKey + freiem Nest-Anker)
local function PlaceBestPets()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local tracker = main and main:FindFirstChild("PetsTracker")
    local placeBest = tracker and tracker:FindFirstChild("PlaceBest")
    if placeBest then
        local ok, conns = pcall(getconnections, placeBest.Activated)
        if ok and #conns > 0 then
            for _, c in ipairs(conns) do
                if type(c.Function) == "function" then pcall(c.Function) end
            end
            return true
        end
    end
    -- Fallback: schwerste gehaltene Pets selbst setzen
    local remote = Remote("PlacePet")
    local plot = OwnPlot()
    if not (remote and plot) then return false end
    local nests = PlotNests(plot)
    if not nests then return false end
    local freeAnchor
    for _, n in ipairs(nests:GetChildren()) do
        if n:GetAttribute("Unlocked") == true then
            local anchor = n:FindFirstChild("PlacePromptAnchor")
            if anchor then freeAnchor = anchor break end
        end
    end
    if not freeAnchor then return false end
    local pets = HeldPets()
    table.sort(pets, function(a, b)
        return (a:GetAttribute("Weight") or 0) > (b:GetAttribute("Weight") or 0)
    end)
    local placed = 0
    for _, pet in ipairs(pets) do
        local key = pet:GetAttribute("PetKey")
        if key then
            local pos = freeAnchor.Position
            pcall(function() remote:FireServer(key, pos.X, pos.Y, pos.Z) end)
            placed = placed + 1
            task.wait(0.25)
            if placed >= 1 then break end
        end
    end
    return placed > 0
end

-- ==============================================================================
-- PROGRESS
-- ==============================================================================
local function UnlockNests()
    local plot = OwnPlot()
    local nests = PlotNests(plot)
    if not nests then return 0 end
    local cash = PlayerCash()
    local unlocked = 0
    for _, n in ipairs(nests:GetChildren()) do
        if n:GetAttribute("Unlocked") ~= true then
            local idx = tonumber(n.Name) or 1
            local price = NEST_PRICES[idx] or math.huge
            if cash >= price then
                local prompt = n:FindFirstChild("UnlockNest", true)
                if prompt then
                    FirePrompt(prompt)
                    unlocked = unlocked + 1
                    S.stats.nests = S.stats.nests + 1
                    task.wait(0.6)
                end
            end
        end
    end
    return unlocked
end

local function RebirthCost()
    local current = tonumber(PlayerStat("Rebirths")) or 0
    if RebirthData and RebirthData.GetCost then
        local ok, res = pcall(RebirthData.GetCost, current)
        if ok and type(res) == "number" then return res end
    end
    return 1000000 * (50 ^ current)
end

local function TryRebirth()
    local cap = (RebirthData and RebirthData.Cap) or 6
    if (tonumber(PlayerStat("Rebirths")) or 0) >= cap then return false, "Cap erreicht" end
    if PlayerCash() < RebirthCost() then return false, "zu wenig Cash" end
    local remote = Remote("Rebirth")
    if not remote then return false end
    pcall(function() remote:FireServer() end)
    S.stats.rebirths = S.stats.rebirths + 1
    return true
end

local function ClaimIndexReward()
    local remote = Remote("ClaimIndexReward")
    if not remote then return false end
    pcall(function() remote:FireServer() end)
    return true
end
local function ClaimOfflineEarnings()
    local remote = Remote("OfflineEarnings")
    if not remote then return false end
    pcall(function() remote:FireServer() end)
    return true
end
local function ClaimGroupReward()
    local remote = Remotes and Remotes:FindFirstChild("Reusable") and Remotes.Reusable:FindFirstChild("ClaimGroupReward")
    if not remote then return false end
    pcall(function() remote:FireServer() end)
    return true
end
local function ClaimEventReward()
    local remote = Remotes and Remotes:FindFirstChild("Reusable") and Remotes.Reusable:FindFirstChild("ClaimEventReward")
    if not remote then return false end
    pcall(function() remote:FireServer() end)
    return true
end
local function ActivateRadar()
    local remote = Remote("ActivateRadar")
    if not remote then return false end
    pcall(function() remote:FireServer() end)
    return true
end

-- ==============================================================================
-- HATCH-LUCK-UPGRADES (Preis/Multiplier kommen aus GameData.HatchLuck)
-- ==============================================================================
local function HatchUpgradeLevel()
    return tonumber(PlayerStat("HatchUpgrades")) or 0
end

local function HatchLuckMultiplier()
    local level = HatchUpgradeLevel()
    if HatchLuck and type(HatchLuck.GetMultiplier) == "function" then
        local ok, res = pcall(HatchLuck.GetMultiplier, level)
        if ok and type(res) == "number" then return res end
    end
    return 1 + level
end

local function NextHatchUpgradePrice()
    local level = HatchUpgradeLevel()
    if HatchLuck and type(HatchLuck.GetPrice) == "function" then
        local ok, res = pcall(HatchLuck.GetPrice, level)
        if ok and type(res) == "number" then return res end
    end
    return 5 + level * 5
end

local function MaxAffordableHatchUpgrades()
    local level, cash = HatchUpgradeLevel(), PlayerCash()
    if HatchLuck and type(HatchLuck.GetMaxAffordable) == "function" then
        local ok, count, cost = pcall(HatchLuck.GetMaxAffordable, level, cash)
        if ok and type(count) == "number" then return count, (type(cost) == "number" and cost or 0) end
    end
    return 0, 0
end

local function UpgradeRemote()
    local plotRemotes = GameRemotes and GameRemotes:FindFirstChild("Plot")
    return plotRemotes and plotRemotes:FindFirstChild("Upgrades")
end

-- Kauft Luck-Upgrades: mode = "Max" oder "1 Upgrade", solange die Reserve bleibt
local function BuyHatchUpgrades(mode, force)
    local remote = UpgradeRemote()
    if not remote then return false, "Upgrades-Remote fehlt" end
    local cash = PlayerCash()
    local price = NextHatchUpgradePrice()
    if not force and (cash - price) < (S.upgradeReserve or 0) then
        return false, "Reserve"
    end
    pcall(function()
        if (mode or S.luckBuyMode) == "Max" then
            remote:FireServer("Max")
        else
            remote:FireServer(1)
        end
    end)
    return true
end

-- ==============================================================================
-- ESP
-- ==============================================================================
local ESP_COLORS = {
    Common = Color3.fromRGB(200, 200, 200),
    Rare = Color3.fromRGB(80, 160, 255),
    Epic = Color3.fromRGB(170, 90, 255),
    Legendary = Color3.fromRGB(255, 190, 60),
    Mythic = Color3.fromRGB(255, 90, 90),
    Ethereal = Color3.fromRGB(90, 255, 210),
    Divine = Color3.fromRGB(255, 255, 140),
    Volcanic = Color3.fromRGB(255, 120, 40),
}

-- Highlights werden wiederverwendet (kein Neuaufbau pro Refresh)
local espMaps = { egg = {}, pet = {}, player = {} }

local function EspRarityOk(rarity)
    if S.espRarities == nil or next(S.espRarities) == nil then return true end
    return S.espRarities[rarity] == true
end

local function HideESP(kind)
    for inst, h in pairs(espMaps[kind]) do
        pcall(function() h:Destroy() end)
        espMaps[kind][inst] = nil
    end
    for i = #HUB.highlights, 1, -1 do
        if HUB.highlights[i].kind == kind then table.remove(HUB.highlights, i) end
    end
end
local ClearHighlights = HideESP

local function HighlightFor(kind, inst)
    if not inst or not inst.Parent then return nil end
    local map = espMaps[kind]
    local h = map[inst]
    if h and not h.Parent then h = nil map[inst] = nil end
    if not h then
        h = Instance.new("Highlight")
        h.Name = "ArcHubESP"
        h.FillTransparency = 0.6
        h.OutlineTransparency = 0
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.OutlineColor = Color3.fromRGB(255, 255, 255)
        h.Adornee = inst
        h.Parent = inst
        map[inst] = h
        table.insert(HUB.highlights, { instance = h, kind = kind, adornee = inst })
    end
    h.Enabled = true
    return h
end

local function UpdateEggESP()
    if not S.eggEsp then HideESP("egg") return end
    local seen = {}
    local own = OwnPlot()

    -- 1) Feld-Eier: weißer Rahmen = liegt auf Spawn-Pad (claimbar)
    for _, egg in ipairs(FieldEggs()) do
        if EspRarityOk(egg.rarity) then
            local h = HighlightFor("egg", egg.model)
            if h then
                h.FillColor = ESP_COLORS[egg.rarity] or Color3.new(1, 1, 1)
                h.OutlineColor = egg.onPad and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(110, 110, 110)
                h.FillTransparency = egg.onPad and 0.45 or 0.75
                seen[egg.model] = true
            end
        end
    end

    -- 2) Plot-Eier (eigene grün umrandet, fremde weiß)
    local plots = Workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local eggs = plot:FindFirstChild("Eggs")
            if eggs then
                for _, e in ipairs(eggs:GetChildren()) do
                    local info = EggInfo(e.Name)
                    local rarity = (info and info.Rarity) or "?"
                    if EspRarityOk(rarity) then
                        local h = HighlightFor("egg", e)
                        if h then
                            h.FillColor = ESP_COLORS[rarity] or Color3.new(1, 1, 1)
                            h.OutlineColor = (plot == own) and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 255, 255)
                            h.FillTransparency = 0.6
                            seen[e] = true
                        end
                    end
                end
            end
        end
    end

    -- 3) Eier im eigenen Korb
    for _, c in ipairs(CarriedEggs()) do
        local h = HighlightFor("egg", c)
        if h then
            h.FillColor = Color3.fromRGB(255, 255, 255)
            h.OutlineColor = Color3.fromRGB(255, 220, 80)
            seen[c] = true
        end
    end

    for inst, h in pairs(espMaps.egg) do
        if not seen[inst] then h.Enabled = false end
    end
end

local function UpdatePetESP()
    if not S.petEsp then HideESP("pet") return end
    local seen = {}
    local plots = Workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local pets = plot:FindFirstChild("Pets")
            if pets then
                for _, pet in ipairs(pets:GetChildren()) do
                    local own = pet:GetAttribute("OwnerUserId") == LP.UserId
                    local h = HighlightFor("pet", pet)
                    if h then
                        h.FillColor = own and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 120, 200)
                        seen[pet] = true
                    end
                end
            end
        end
    end
    -- gehaltene Pets (Backpack)
    for _, t in ipairs(HeldPets()) do
        local h = HighlightFor("pet", t)
        if h then
            h.FillColor = Color3.fromRGB(80, 200, 255)
            seen[t] = true
        end
    end
    for inst, h in pairs(espMaps.pet) do
        if not seen[inst] then h.Enabled = false end
    end
end

local function UpdatePlayerESP()
    if not S.playerEsp then HideESP("player") return end
    local seen = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local h = HighlightFor("player", plr.Character)
            if h then
                h.FillColor = Color3.fromRGB(255, 80, 80)
                seen[plr.Character] = true
            end
        end
    end
    for inst, h in pairs(espMaps.player) do
        if not seen[inst] then h.Enabled = false end
    end
end

local function RefreshESP()
    pcall(UpdateEggESP)
    pcall(UpdatePetESP)
    pcall(UpdatePlayerESP)
end

-- ==============================================================================
-- PLAYER UTILITY
-- ==============================================================================
local savedLighting = nil
local savedParticles = {}
local flyBV, flyBG, flyGyro

local function ApplySpeed()
    local h = GetHumanoid()
    if h then h.WalkSpeed = S.speedEnabled and S.speedValue or 16 end
end
local function ApplyJump()
    local h = GetHumanoid()
    if h then
        h.UseJumpPower = true
        h.JumpPower = S.jumpEnabled and S.jumpValue or 50
    end
end
local function ApplyGravity()
    Workspace.Gravity = S.gravityEnabled and S.gravityValue or 196.2
end
local function ApplyFOV()
    local cam = GetCamera()
    if cam then cam.FieldOfView = S.fovEnabled and S.fovValue or 70 end
end

local function SetFullbright(on)
    if on then
        if not savedLighting then
            savedLighting = {
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows,
                FogEnd = Lighting.FogEnd,
            }
        end
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    elseif savedLighting then
        for k, v in pairs(savedLighting) do pcall(function() Lighting[k] = v end) end
        savedLighting = nil
    end
end

local function SetFPSMode(on)
    if on then
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ParticleEmitter") and d.Enabled then
                savedParticles[#savedParticles + 1] = d
                d.Enabled = false
            end
        end
    else
        for _, d in ipairs(savedParticles) do pcall(function() d.Enabled = true end) end
        savedParticles = {}
    end
end

local function StartNoclip()
    if HUB.noclipConn then return end
    HUB.noclipConn = RunService.Stepped:Connect(function()
        if not (S.noclip or S.farmNoclipActive) then return end
        local char = LP.Character
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d.CanCollide then d.CanCollide = false end
        end
    end)
end

-- Kollisionen wiederherstellen, wenn kein Noclip mehr gebraucht wird
-- (nur echte Körperteile, Accessoires bleiben wie sie sind)
local BODY_PARTS = {
    HumanoidRootPart = true, Head = true, UpperTorso = true, LowerTorso = true, Torso = true,
    LeftUpperArm = true, RightUpperArm = true, LeftLowerArm = true, RightLowerArm = true,
    LeftHand = true, RightHand = true, LeftUpperLeg = true, RightUpperLeg = true,
    LeftLowerLeg = true, RightLowerLeg = true, LeftFoot = true, RightFoot = true,
}
local function RestoreCollisions()
    local char = LP.Character
    if not char then return end
    for _, d in ipairs(char:GetChildren()) do
        if d:IsA("BasePart") and BODY_PARTS[d.Name] and not d.CanCollide then
            pcall(function() d.CanCollide = true end)
        end
    end
end

-- Farm-Noclip: nur während des Egg-Loops aktiv
local function SetFarmNoclip(on)
    if S.farmNoclipActive == on then return end
    S.farmNoclipActive = on
    if on then
        StartNoclip()
    elseif not S.noclip then
        task.delay(0.4, RestoreCollisions)
    end
end

local function StartFly()
    if HUB.flyConn then return end
    local hrp = GetHRP()
    if not hrp then return end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = hrp
    HUB.flyConn = RunService.RenderStepped:Connect(function()
        if not S.flyEnabled then
            if flyBV then flyBV.Velocity = Vector3.zero end
            return
        end
        local cam = GetCamera()
        local h = GetHumanoid()
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
        local hrp2 = GetHRP()
        if flyBV and flyBV.Parent ~= hrp2 then flyBV.Parent = hrp2 end
        if flyBV then flyBV.Velocity = move.Magnitude > 0 and move.Unit * S.flySpeed or Vector3.zero end
        if h and move.Magnitude > 0 then h.PlatformStand = true end
    end)
end
local function StopFly()
    if HUB.flyConn then HUB.flyConn:Disconnect() HUB.flyConn = nil end
    if flyBV then flyBV:Destroy() flyBV = nil end
    local h = GetHumanoid()
    if h then h.PlatformStand = false end
end

-- Anti-AFK / Anti-Kick / Auto-Rejoin
local function StartAntiAfk()
    if HUB.afkConn then return end
    HUB.afkConn = LP.Idled:Connect(function()
        if S.antiAfk then
            pcall(function() VirtualUser:CaptureController() end)
            pcall(function() VirtualUser:ClickButton2(Vector2.new()) end)
        end
    end)
end
local function StartAntiKick()
    if HUB.kickConns then return end
    HUB.kickConns = {}
    local reusable = Remotes and Remotes:FindFirstChild("Reusable")
    local ban = reusable and reusable:FindFirstChild("Ban")
    if ban then
        local ok, conns = pcall(getconnections, ban.OnClientEvent)
        if ok then
            for _, c in ipairs(conns) do
                pcall(function() c:Disable() end)
            end
            table.insert(HUB.kickConns, ban)
        end
    end
end
local function StartAutoRejoin()
    if HUB.rejoinConn then return end
    HUB.rejoinConn = LP.OnTeleport:Connect(function(state)
        if state == Enum.TeleportState.Failed and S.autoRejoin then
            pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
        end
    end)
end

local function AntiAfkHeartbeat()
    if not S.antiAfk then return end
    pcall(function()
        local vu = VirtualUser
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end

-- ==============================================================================
-- TELEPORTS / UTILITY BUTTONS
-- ==============================================================================
local function TeleportToOwnPlot()
    local plot = OwnPlot()
    if not plot then return Notify("Arc HUB", "Kein Plot geladen", "Error") end
    local base = plot:FindFirstChild("Baseplate")
    if base then TeleportTo(base.Position, 8) end
end
local function TeleportToStall(name)
    local stalls = Workspace:FindFirstChild("Stalls")
    local stall = stalls and stalls:FindFirstChild(name)
    if not stall then return Notify("Arc HUB", "Stall nicht gefunden", "Error") end
    local pivot = stall:IsA("Model") and stall:GetPivot().Position or stall.Position
    TeleportTo(pivot, 6)
end

-- ==============================================================================
-- LOOPS
-- ==============================================================================
local function EggLoopStep()
    if S.busy then return end
    S.busy = true
    local ok, err = pcall(function()
        -- 1) Korb leeren / Ei platzieren
        if #CarriedEggs() > 0 then
            if S.autoPlace then
                DeliverAndPlace()
            end
        else
            -- 2) neues Ei holen
            local target = PickTargetEgg()
            if target then
                if CollectEgg(target) then
                    S.stats.eggs = S.stats.eggs + 1
                end
            end
        end
        -- 3) reife Eier hatchen
        if S.autoHatch then
            HatchReadyEggs()
        end
    end)
    if not ok then pcall(Notify, "Arc HUB", "Egg-Loop: " .. tostring(err), "Error", 3) end
    S.busy = false
end

local function PetLoopStep()
    if S.autoCollectPets then CollectPetEarnings() end
    if S.autoPlacePets and S.placeBestPets then PlaceBestPets() end
    if S.autoFeedPets then FeedPets() end
end

local function ProgressLoopStep()
    if S.autoUnlockNests then UnlockNests() end
    if S.autoRebirth then
        local ok, why = TryRebirth()
        if not ok and why == "zu wenig Cash" then
            -- still
        end
    end
    if S.autoClaimOffline then ClaimOfflineEarnings() end
    if S.autoClaimIndex then ClaimIndexReward() end
    if S.autoClaimGroup then ClaimGroupReward() end
    if S.autoClaimEvent then ClaimEventReward() end
    if S.autoRadar then ActivateRadar() end
end

local function StartLoops()
    if HUB.loopsRunning then return end
    HUB.loopsRunning = true
    task.spawn(function()
        while not HUB.dead do
            if S.eggLoop then
                SetFarmNoclip(S.farmNoclip)   -- durch Wände zum Ei / zurück zum Plot
                pcall(EggLoopStep)
                task.wait(S.eggLoopDelay)
            else
                SetFarmNoclip(false)          -- Farm aus -> Noclip wieder aus
                task.wait(0.25)
            end
        end
    end)
    task.spawn(function()
        while not HUB.dead do
            if S.luckBuying then
                pcall(BuyHatchUpgrades, S.luckBuyMode, false)
                task.wait(math.max(tonumber(S.luckBuyDelay) or 2, 0.2))
            else
                task.wait(0.25)
            end
        end
    end)
    task.spawn(function()
        while not HUB.dead do
            if S.petLoop then pcall(PetLoopStep) end
            task.wait(3)
        end
    end)
    task.spawn(function()
        while not HUB.dead do
            if S.progressLoop then pcall(ProgressLoopStep) end
            task.wait(5)
        end
    end)
    task.spawn(function()
        while not HUB.dead do
            if S.eggEsp or S.petEsp or S.playerEsp then pcall(RefreshESP) end
            task.wait(0.5)
        end
    end)
    task.spawn(function()
        while not HUB.dead do
            pcall(AntiAfkHeartbeat)
            task.wait(60)
        end
    end)
    task.spawn(function()
        while not HUB.dead do
            pcall(ApplySpeed)
            pcall(ApplyJump)
            task.wait(1)
        end
    end)
end

-- ==============================================================================
-- UI
-- ==============================================================================
local mainTab = Window:AddTab("Auto Farm")
local shopTab = Window:AddTab("Shops")
local espTab  = Window:AddTab("ESP")
local playerTab = Window:AddTab("Player")
local setTab  = Window:AddTab("Settings")

-- ---------------------------------------------------------------- Auto Farm
local farmSub = mainTab:AddSubTab("Smart All")
farmSub:AddParagraph({
    Text = "Alles an: Eggs farmen, Pets sammeln, Nester + Rebirth.",
})
farmSub:AddButton({
    Name = "Smart All AN", Primary = true,
    Callback = safeCallback(function()
        S.eggLoop = true; S.petLoop = true; S.progressLoop = true
        S.autoPlace = true; S.autoHatch = true
        S.autoCollectPets = true; S.placeBestPets = true; S.autoPlacePets = true
        S.autoUnlockNests = true; S.autoClaimIndex = true; S.autoClaimOffline = true
        StartLoops()
        Notify("Smart All", "alles an", "Success")
    end)
})
farmSub:AddButton({
    Name = "Alles AUS",
    Callback = safeCallback(function()
        S.eggLoop = false; S.petLoop = false; S.progressLoop = false
        S.autoPlacePets = false
        Notify("Smart All", "alles aus", "Info")
    end)
})
farmSub:AddDivider()
farmSub:AddToggle({
    Name = "Egg Loop", Default = false, Flag = "farm_eggl",
    Callback = safeCallback(function(v) S.eggLoop = v StartLoops() end)
})
farmSub:AddToggle({
    Name = "Pet Loop", Default = false, Flag = "farm_petl",
    Callback = safeCallback(function(v) S.petLoop = v StartLoops() end)
})
farmSub:AddToggle({
    Name = "Progress Loop", Default = false, Flag = "farm_progl",
    Callback = safeCallback(function(v) S.progressLoop = v StartLoops() end)
})

local statusSub = farmSub
statusSub:AddDivider()
local function StatusParagraph()
    return string.format(
        "Eggs %d | platziert %d | gehatcht %d | Collects %d | Nester %d | Rebirth %d | Luck x%.1f",
        S.stats.eggs, S.stats.delivered, S.stats.hatched, S.stats.collected, S.stats.nests, S.stats.rebirths,
        HatchLuckMultiplier())
end
local statusLabel = statusSub:AddParagraph({ Title = "Stats", Text = StatusParagraph() })
task.spawn(function()
    while not HUB.dead do
        task.wait(2)
        pcall(function() statusLabel:Set(StatusParagraph()) end)
    end
end)

-- ---------------------------------------------------------------- Eggs
local eggsLoopSub = mainTab:AddSubTab("Eggs")
eggsLoopSub:AddToggle({
    Name = "Auto Farm Eggs", Default = false, Flag = "eggs_loop",
    Callback = safeCallback(function(v) S.eggLoop = v StartLoops() end)
})
eggsLoopSub:AddDropdown({
    Name = "Egg Priorität", Options = { "Best Value", "Fast Cycle", "Nearest" }, Default = "Best Value", Flag = "eggs_prio",
    Callback = safeCallback(function(v) S.eggPriority = v end)
})
eggsLoopSub:AddMultiDropdown({
    Name = "Raritäten (leer = alle)", Options = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Ethereal", "Divine", "Volcanic" },
    Default = {}, Flag = "eggs_rarities",
    Callback = safeCallback(function(list)
        S.eggRarities = {}
        for _, r in ipairs(list) do S.eggRarities[r] = true end
    end)
})
eggsLoopSub:AddSlider({
    Name = "Loop-Delay", Min = 0.1, Max = 3, Default = 0.35, Suffix = "s", Flag = "eggs_delay",
    Callback = safeCallback(function(v) S.eggLoopDelay = tonumber(v) or 0.35 end)
})
eggsLoopSub:AddSlider({
    Name = "Max. Distanz (0 = egal)", Min = 0, Max = 5000, Default = 0, Suffix = " studs", Flag = "eggs_travel",
    Callback = safeCallback(function(v) S.maxEggTravel = tonumber(v) or 0 end)
})
eggsLoopSub:AddDivider()
eggsLoopSub:AddToggle({
    Name = "Auto Place", Default = true, Flag = "eggs_place",
    Callback = safeCallback(function(v) S.autoPlace = v end)
})
eggsLoopSub:AddToggle({
    Name = "Auto Hatch", Default = true, Flag = "eggs_hatch",
    Callback = safeCallback(function(v) S.autoHatch = v end)
})
eggsLoopSub:AddToggle({
    Name = "Noclip beim Farmen", Default = true, Flag = "eggs_farmnoclip",
    Callback = safeCallback(function(v)
        S.farmNoclip = v
        if not v then SetFarmNoclip(false) end
    end)
})
eggsLoopSub:AddSlider({
    Name = "Hatch-Delay", Min = 0.2, Max = 5, Default = 1.0, Suffix = "s", Flag = "eggs_hatchdelay",
    Callback = safeCallback(function(v) S.hatchDelay = tonumber(v) or 1 end)
})
eggsLoopSub:AddButton({
    Name = "1 Ei farmen", Primary = true,
    Callback = safeCallback(function()
        if #CarriedEggs() == 0 then
            local t = PickTargetEgg()
            if not t then return Notify("Eggs", "kein Ei gefunden", "Info") end
            if CollectEgg(t) then Notify("Eggs", t.model.Name .. " aufgenommen", "Success") else Notify("Eggs", "Aufnahme fehlgeschlagen", "Error") end
        else
            local ok, why = DeliverAndPlace()
            Notify("Eggs", ok and "Ei platziert" or ("Place fehlgeschlagen: " .. tostring(why)), ok and "Success" or "Error")
        end
    end)
})
eggsLoopSub:AddButton({
    Name = "Reife Eier hatchen",
    Callback = safeCallback(function()
        local n = HatchReadyEggs()
        Notify("Eggs", n .. " Ei(er) gehatcht", "Success")
    end)
})
eggsLoopSub:AddButton({
    Name = "Plot-Eier checken",
    Callback = safeCallback(function()
        local plot = OwnPlot()
        local eggs = PlotEggs(plot)
        if not eggs then return Notify("Eggs", "Kein Plot", "Error") end
        local lines = {}
        for _, e in ipairs(eggs:GetChildren()) do
            local remaining = GrowthRemaining(e)
            lines[#lines + 1] = string.format("%s - %ds", e.Name, math.floor(remaining))
        end
        Notify("Plot-Eier", #lines > 0 and table.concat(lines, " | ") or "leer", "Info", 5)
    end)
})

local eggsInfoSub = eggsLoopSub
eggsInfoSub:AddParagraph({
    Title = "Ablauf",
    Text = "Ei antippen -> Korb -> Plot -> Place -> Hatch. Macht der Loop alles selbst.",
})
eggsInfoSub:AddButton({
    Name = "Eier zählen",
    Callback = safeCallback(function()
        local all, onPad = 0, 0
        for _, egg in ipairs(FieldEggs()) do
            all = all + 1
            if egg.onPad then onPad = onPad + 1 end
        end
        Notify("Eier", string.format("%d Eier, %d auf Pads", all, onPad), "Info")
    end)
})

-- ---------------------------------------------------------------- Pets
local petsLoopSub = mainTab:AddSubTab("Pets")
petsLoopSub:AddToggle({
    Name = "Pet Farm", Default = false, Flag = "pets_loop",
    Callback = safeCallback(function(v) S.petLoop = v StartLoops() end)
})
petsLoopSub:AddToggle({
    Name = "Earnings sammeln", Default = true, Flag = "pets_collect",
    Callback = safeCallback(function(v) S.autoCollectPets = v end)
})
petsLoopSub:AddToggle({
    Name = "Auto Pets setzen", Default = false, Flag = "pets_place",
    Callback = safeCallback(function(v) S.autoPlacePets = v end)
})
petsLoopSub:AddToggle({
    Name = "Auto Füttern", Default = false, Flag = "pets_feed",
    Callback = safeCallback(function(v) S.autoFeedPets = v end)
})
petsLoopSub:AddButton({
    Name = "Earnings sammeln", Primary = true,
    Callback = safeCallback(function()
        local n = CollectPetEarnings()
        Notify("Pets", n .. " Pet(s) abgeholt", "Success")
    end)
})
petsLoopSub:AddButton({
    Name = "Beste Pets setzen",
    Callback = safeCallback(function()
        local ok = PlaceBestPets()
        Notify("Pets", ok and "gesetzt" or "kein freier Slot", ok and "Success" or "Info")
    end)
})
petsLoopSub:AddButton({
    Name = "Füttern",
    Callback = safeCallback(function()
        local ok, res = FeedPets()
        Notify("Pets", ok and ("Gefüttert: " .. tostring(res)) or tostring(res), ok and "Success" or "Error")
    end)
})

local petsInfoSub = petsLoopSub
petsInfoSub:AddButton({
    Name = "Gehaltene Pets",
    Callback = safeCallback(function()
        local pets = HeldPets()
        table.sort(pets, function(a, b) return (a:GetAttribute("Weight") or 0) > (b:GetAttribute("Weight") or 0) end)
        local lines = {}
        for i, p in ipairs(pets) do
            if i > 6 then break end
            lines[#lines + 1] = string.format("%s (%.0f)", tostring(p:GetAttribute("PetName") or p.Name), tonumber(p:GetAttribute("Weight")) or 0)
        end
        Notify("Pets", #lines > 0 and table.concat(lines, " | ") or "keine", "Info", 5)
    end)
})
petsInfoSub:AddButton({
    Name = "Plot-Pets",
    Callback = safeCallback(function()
        local pets = OwnPlotPets()
        local lines = {}
        for _, p in ipairs(pets) do
            lines[#lines + 1] = string.format("%s (%.0f, Age %s)", tostring(p:GetAttribute("PetName") or p.Name),
                tonumber(p:GetAttribute("Weight")) or 0, tostring(p:GetAttribute("Age")))
        end
        Notify("Plot-Pets", #lines > 0 and table.concat(lines, " | ") or "keine", "Info", 5)
    end)
})

-- ---------------------------------------------------------------- Progress
local progAutoSub = mainTab:AddSubTab("Progress")
progAutoSub:AddToggle({
    Name = "Progress Loop", Default = false, Flag = "prog_loop",
    Callback = safeCallback(function(v) S.progressLoop = v StartLoops() end)
})
progAutoSub:AddToggle({
    Name = "Nester kaufen", Default = false, Flag = "prog_nests",
    Callback = safeCallback(function(v) S.autoUnlockNests = v end)
})
progAutoSub:AddToggle({
    Name = "Auto Rebirth", Default = false, Flag = "prog_rebirth",
    Callback = safeCallback(function(v) S.autoRebirth = v end)
})
progAutoSub:AddToggle({
    Name = "Auto Index-Reward", Default = false, Flag = "prog_index",
    Callback = safeCallback(function(v) S.autoClaimIndex = v end)
})
progAutoSub:AddToggle({
    Name = "Auto Offline-Cash", Default = false, Flag = "prog_offline",
    Callback = safeCallback(function(v) S.autoClaimOffline = v end)
})
progAutoSub:AddToggle({
    Name = "Auto Gruppen-Reward", Default = false, Flag = "prog_group",
    Callback = safeCallback(function(v) S.autoClaimGroup = v end)
})
progAutoSub:AddToggle({
    Name = "Auto Event-Reward", Default = false, Flag = "prog_event",
    Callback = safeCallback(function(v) S.autoClaimEvent = v end)
})
progAutoSub:AddToggle({
    Name = "Auto Radar", Default = false, Flag = "prog_radar",
    Callback = safeCallback(function(v) S.autoRadar = v end)
})

local progManSub = progAutoSub
progManSub:AddButton({
    Name = "Luck kaufen AN/AUS", Primary = true,
    Callback = safeCallback(function()
        S.luckBuying = not S.luckBuying
        Notify("Luck",
            S.luckBuying and ("an | " .. tostring(S.luckBuyMode) .. " alle " .. tostring(S.luckBuyDelay) .. "s") or "aus",
            S.luckBuying and "Success" or "Info")
    end)
})
progManSub:AddSlider({
    Name = "Kauf-Delay", Min = 0.2, Max = 30, Default = 2, Suffix = "s", Flag = "luck_delay",
    Callback = safeCallback(function(v) S.luckBuyDelay = tonumber(v) or 2 end)
})
progManSub:AddDropdown({
    Name = "Kauf-Modus", Options = { "1 Upgrade", "Max" }, Default = "1 Upgrade", Flag = "luck_mode",
    Callback = safeCallback(function(v) S.luckBuyMode = tostring(v) end)
})
progManSub:AddSlider({
    Name = "Cash behalten", Min = 0, Max = 5000000, Default = 100000, Suffix = " $", Flag = "luck_reserve",
    Callback = safeCallback(function(v) S.upgradeReserve = tonumber(v) or 100000 end)
})

local progInfoSub = progAutoSub
local progStatusLabel = progInfoSub:AddParagraph({ Title = "Status", Text = "..." })
local function ProgressStatusText()
    local count = MaxAffordableHatchUpgrades()
    local plot = OwnPlot()
    local nests = PlotNests(plot)
    local open, total = 0, 0
    if nests then
        for _, n in ipairs(nests:GetChildren()) do
            total = total + 1
            if n:GetAttribute("Unlocked") == true then open = open + 1 end
        end
    end
    return string.format("Luck Lv%d (x%.1f) | naechster %s $ | bezahlbar %d | Nester %d/%d | Rebirths %s (%s $)",
        HatchUpgradeLevel(), HatchLuckMultiplier(), tostring(NextHatchUpgradePrice()), count,
        open, total, tostring(PlayerStat("Rebirths")), tostring(RebirthCost()))
end
task.spawn(function()
    while not HUB.dead do
        task.wait(2)
        pcall(function() progStatusLabel:Set(ProgressStatusText()) end)
    end
end)

-- ---------------------------------------------------------------- Shops
local shopSub = shopTab:AddSubTab("Shop")
shopSub:AddToggle({
    Name = "Server-Autobuy", Default = false, Flag = "shop_autobuy",
    Callback = safeCallback(function(v)
        S.autoBuyFood = v
        local remote = Remote("Autobuy")
        if remote then pcall(function() remote:FireServer(v) end) end
        Notify("Shop", v and "Autobuy an" or "Autobuy aus", "Info")
    end)
})
shopSub:AddToggle({
    Name = "Auto-Restock", Default = false, Flag = "shop_restock",
    Callback = safeCallback(function(v) S.autoRestock = v end)
})
shopSub:AddButton({
    Name = "Restock", Primary = true,
    Callback = safeCallback(function()
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        local main = pg and pg:FindFirstChild("Main")
        local oldShop = main and main:FindFirstChild("OldShop")
        local restock = oldShop and oldShop:FindFirstChild("Header") and oldShop.Header:FindFirstChild("Restock")
        if not restock then return Notify("Shop", "Restock-Button fehlt", "Error") end
        local ok, conns = pcall(getconnections, restock.Activated)
        local clicked = false
        if ok then
            for _, c in ipairs(conns) do
                if type(c.Function) == "function" then pcall(c.Function) clicked = true end
            end
        end
        Notify("Shop", clicked and "Restock ausgelöst" or "Kein Handler am Button", clicked and "Success" or "Info")
    end)
})
shopSub:AddDivider()
shopSub:AddButton({ Name = "Futter-Stand", Callback = safeCallback(function() TeleportToStall("Food") end) })
shopSub:AddButton({ Name = "Gear-Stand", Callback = safeCallback(function() TeleportToStall("Gears") end) })
shopSub:AddButton({ Name = "Verkaufs-Stand", Callback = safeCallback(function() TeleportToStall("Sell") end) })
shopSub:AddButton({ Name = "Egg-Tracker", Callback = safeCallback(function() TeleportToStall("EggTracker") end) })

-- ---------------------------------------------------------------- ESP
local espSub = espTab:AddSubTab("ESP")
espSub:AddToggle({
    Name = "Egg ESP", Default = false, Flag = "esp_egg",
    Callback = safeCallback(function(v) S.eggEsp = v RefreshESP() end)
})
espSub:AddToggle({
    Name = "Pet ESP (eigene grün)", Default = false, Flag = "esp_pet",
    Callback = safeCallback(function(v) S.petEsp = v RefreshESP() end)
})
espSub:AddToggle({
    Name = "Player ESP", Default = false, Flag = "esp_player",
    Callback = safeCallback(function(v) S.playerEsp = v RefreshESP() end)
})
espSub:AddMultiDropdown({
    Name = "Raritätsfilter", Options = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Ethereal", "Divine", "Volcanic" },
    Default = {}, Flag = "esp_rarities",
    Callback = safeCallback(function(list)
        S.espRarities = {}
        for _, r in ipairs(list) do S.espRarities[r] = true end
        RefreshESP()
    end)
})

-- ---------------------------------------------------------------- Player
local moveSub = playerTab:AddSubTab("Movement")
moveSub:AddToggle({
    Name = "Speed an", Default = false, Flag = "pl_speed_on",
    Callback = safeCallback(function(v) S.speedEnabled = v ApplySpeed() end)
})
moveSub:AddSlider({
    Name = "WalkSpeed", Min = 16, Max = 500, Default = 16, Flag = "pl_speed",
    Callback = safeCallback(function(v) S.speedValue = tonumber(v) or 16 if S.speedEnabled then ApplySpeed() end end)
})
moveSub:AddToggle({
    Name = "Jump an", Default = false, Flag = "pl_jump_on",
    Callback = safeCallback(function(v) S.jumpEnabled = v ApplyJump() end)
})
moveSub:AddSlider({
    Name = "JumpPower", Min = 50, Max = 500, Default = 50, Flag = "pl_jump",
    Callback = safeCallback(function(v) S.jumpValue = tonumber(v) or 50 if S.jumpEnabled then ApplyJump() end end)
})
moveSub:AddToggle({
    Name = "Fly (WASD)", Default = false, Flag = "pl_fly",
    Callback = safeCallback(function(v)
        S.flyEnabled = v
        if v then StartFly() else StopFly() end
    end)
})
moveSub:AddSlider({
    Name = "Fly-Speed", Min = 20, Max = 500, Default = 60, Flag = "pl_flyspeed",
    Callback = safeCallback(function(v) S.flySpeed = tonumber(v) or 60 end)
})
moveSub:AddToggle({
    Name = "Noclip", Default = false, Flag = "pl_noclip",
    Callback = safeCallback(function(v) S.noclip = v if v then StartNoclip() end end)
})
moveSub:AddToggle({
    Name = "Gravity an", Default = false, Flag = "pl_grav_on",
    Callback = safeCallback(function(v) S.gravityEnabled = v ApplyGravity() end)
})
moveSub:AddSlider({
    Name = "Gravity", Min = 0, Max = 500, Default = 196, Flag = "pl_grav",
    Callback = safeCallback(function(v) S.gravityValue = tonumber(v) or 196 if S.gravityEnabled then ApplyGravity() end end)
})
moveSub:AddToggle({
    Name = "FOV an", Default = false, Flag = "pl_fov_on",
    Callback = safeCallback(function(v) S.fovEnabled = v ApplyFOV() end)
})
moveSub:AddSlider({
    Name = "Field of View", Min = 40, Max = 160, Default = 70, Flag = "pl_fov",
    Callback = safeCallback(function(v) S.fovValue = tonumber(v) or 70 if S.fovEnabled then ApplyFOV() end end)
})

local worldSub = playerTab:AddSubTab("Welt")
worldSub:AddToggle({
    Name = "Fullbright", Default = false, Flag = "pl_fullbright",
    Callback = safeCallback(function(v) S.fullbright = v SetFullbright(v) end)
})
worldSub:AddToggle({
    Name = "FPS-Modus", Default = false, Flag = "pl_fps",
    Callback = safeCallback(function(v) S.fpsMode = v SetFPSMode(v) end)
})
worldSub:AddDivider()
worldSub:AddButton({ Name = "Eigener Plot", Primary = true, Callback = safeCallback(function() TeleportToOwnPlot() end) })
worldSub:AddButton({ Name = "Egg-Tracker", Callback = safeCallback(function() TeleportToStall("EggTracker") end) })
worldSub:AddButton({ Name = "Nächstes Ei", Callback = safeCallback(function()
    local t = PickTargetEgg()
    if t then TeleportTo(t.pos, 4) Notify("Teleport", t.model.Name, "Success") else Notify("Teleport", "kein Ei", "Info") end
end) })

local safetySub = playerTab:AddSubTab("Sicherheit")
safetySub:AddToggle({
    Name = "Anti-AFK", Default = true, Flag = "pl_antiafk",
    Callback = safeCallback(function(v) S.antiAfk = v StartAntiAfk() end)
})
safetySub:AddToggle({
    Name = "Anti-Kick", Default = false, Flag = "pl_antikick",
    Callback = safeCallback(function(v) S.antiKick = v if v then StartAntiKick() end end)
})
safetySub:AddToggle({
    Name = "Auto-Rejoin", Default = false, Flag = "pl_rejoin",
    Callback = safeCallback(function(v) S.autoRejoin = v if v then StartAutoRejoin() end end)
})

-- ---------------------------------------------------------------- Settings
local setSub = setTab:AddSubTab("Main")
setSub:AddParagraph({
    Title = "Arc HUB | Reite ein Haustier",
    Text = "PlaceId 124216119978534",
})
setSub:AddButton({
    Name = "Config speichern", Primary = true,
    Callback = safeCallback(function()
        if not HAS_CONFIG then return Notify("Config", "Library ohne Config-API", "Error") end
        Library:SaveConfig(CONFIG_NAME)
        Notify("Config", "Gespeichert", "Success")
    end)
})
setSub:AddButton({
    Name = "Config laden",
    Callback = safeCallback(function()
        if not HAS_CONFIG then return Notify("Config", "Library ohne Config-API", "Error") end
        Library:LoadConfig(CONFIG_NAME)
        Notify("Config", "Geladen", "Success")
    end)
})
setSub:AddButton({
    Name = "Unload Arc HUB", Primary = true,
    Callback = safeCallback(function()
        if HUB.Unload then HUB.Unload() end
    end)
})

-- ==============================================================================
-- UNLOAD
-- ==============================================================================
function HUB.Unload()
    HUB.dead = true
    -- Loops stoppen
    S.eggLoop, S.petLoop, S.progressLoop = false, false, false
    -- Verbindungen trennen
    for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
    HUB.conns = {}
    for _, k in ipairs({ "noclipConn", "flyConn", "afkConn", "rejoinConn", "loopsRunning" }) do
        if HUB[k] and type(HUB[k]) ~= "boolean" then pcall(function() HUB[k]:Disconnect() end) end
        HUB[k] = nil
    end
    -- Highlights + Drawings
    for _, h in ipairs(HUB.highlights) do pcall(function() h.instance:Destroy() end) end
    HUB.highlights = {}
    for _, d in ipairs(HUB.drawings) do pcall(function() d:Remove() end) end
    HUB.drawings = {}
    -- Werte zurücksetzen
    S.speedEnabled = false  pcall(ApplySpeed)
    S.jumpEnabled = false   pcall(ApplyJump)
    S.gravityEnabled = false pcall(ApplyGravity)
    S.fovEnabled = false    pcall(ApplyFOV)
    if savedLighting then pcall(SetFullbright, false) end
    if #savedParticles > 0 then pcall(SetFPSMode, false) end
    pcall(StopFly)
    pcall(function() Window:Destroy() end)
    _G.ArcRideAPet = nil
    print("[Arc HUB] Reite ein Haustier unloaded.")
end

-- ==============================================================================
-- START
-- ==============================================================================
HUB.actions = {
    PickTargetEgg = PickTargetEgg,
    CollectEgg = CollectEgg,
    DeliverAndPlace = DeliverAndPlace,
    HatchReadyEggs = HatchReadyEggs,
    CollectPetEarnings = CollectPetEarnings,
    PlaceBestPets = PlaceBestPets,
    FeedPets = FeedPets,
    UnlockNests = UnlockNests,
    TryRebirth = TryRebirth,
    OwnPlot = OwnPlot,
    FieldEggs = FieldEggs,
    GrowthRemaining = GrowthRemaining,
}
StartLoops()
Notify("Arc HUB", "Reite ein Haustier geladen", "Success", 3)

-- Character-Respawn: Werte neu anwenden
track(LP.CharacterAdded:Connect(function()
    task.wait(1)
    pcall(ApplySpeed)
    pcall(ApplyJump)
    pcall(ApplyGravity)
    pcall(ApplyFOV)
end))

return HUB

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
local HUB = { conns = {}, drawings = {}, highlights = {}, dead = false, version = "1.5" }
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
local TweenService     = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local LP = Players.LocalPlayer
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
    eggLoopDelay = 0,               -- Zusatzpause pro Zyklus (0 = sofort weiter zum naechsten Ei)
    sideInterval = 3,               -- Pflanzen/Hatchen nur alle X Sekunden (bremsen sonst den Zyklus)
    autoDeliver = true,             -- eingesammeltes Ei heim liefern (Cash)
    autoPlant = false,              -- Inventar-Eier in freie Nester pflanzen
    plantMinLuck = 0,               -- nur Eier ab diesem Luck pflanzen
    autoHatch = true,
    hatchDelay = 1.0,
    maxEggTravel = 0,               -- 0 = unbegrenzt
    pickupRetries = 8,              -- Versuche pro Ei (Server-Positions-Lag)
    deliverDelay = 0,               -- Pause nach dem Pickup, bevor es heim zur Basis geht (0 = sofort)
    useRemotes = false,             -- false = NUR echter Spiel-Weg (Prompt), keine synthetischen Remotes
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
    espEggLabels = true,        -- Name/Rarität/Distanz am Marker anzeigen
    espEggMaxDist = 0,          -- 0 = alle Eier markieren
    -- Player (nur noch Farm-Noclip - der Player-Tab ist komplett entfernt)
    noclip = false,
    farmNoclip = true,          -- Noclip automatisch während des Egg-Farms
    farmNoclipActive = false,
    -- Luck-Upgrades (Progress-Tab)
    luckBuying = false,         -- Button "Luck kaufen"
    luckBuyDelay = 2,           -- Delay zwischen den Käufen
    luckBuyMode = "1 Upgrade",  -- "1 Upgrade" | "Max"
    upgradeReserve = 100000,    -- Cash, das für Upgrades nicht angetastet wird
    -- intern
    busy = false,
    lastEggError = nil,
    stats = { eggs = 0, hatched = 0, delivered = 0, planted = 0, collected = 0, rebirths = 0, nests = 0, cash = 0 },
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
    -- Fallback wie im Referenz-Script: Plot.Data.Owner (ObjectValue)
    for _, p in ipairs(plots:GetChildren()) do
        local data = p:FindFirstChild("Data")
        local owner = data and data:FindFirstChild("Owner")
        if owner and owner:IsA("ObjectValue") and owner.Value == LP then return p end
    end
    return nil
end
local function PlotEggs(plot) return plot and plot:FindFirstChild("Eggs") end
local function PlotNests(plot) return plot and plot:FindFirstChild("Nests") end
local function PlotPets(plot) return plot and plot:FindFirstChild("Pets") end
local function Basket() return LP:FindFirstChild("Basket") end
local function CarriedEggs() local b = Basket() return b and b:GetChildren() or {} end

-- Harter TP wie im getesteten Referenz-Script: ganzen Character pivoten
local function PivotCharacter(cframe)
    if typeof(cframe) ~= "CFrame" then return false end
    local char, hrp = LP.Character, GetHRP()
    if not char or not hrp then return false end
    local ok = pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        char:PivotTo(cframe)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    if ok then
        -- merken, wo WIR den Charakter abgesetzt haben (für die Eingriff-Erkennung)
        HUB.lastPlacedPos = cframe.Position
        HUB.lastPlacedAt = os.clock()
    end
    return ok
end

-- Zielpunkte wie im Referenz-Script: 10 studs über der Oberkante
local EGG_HEIGHT_OFFSET = 10

local function EggTopCFrame(model)
    if not model or not model.Parent then return nil end
    local ok, bb, size = pcall(function() return model:GetBoundingBox() end)
    if not ok or typeof(bb) ~= "CFrame" or typeof(size) ~= "Vector3" then return nil end
    return CFrame.new(Vector3.new(bb.Position.X, bb.Position.Y + size.Y * 0.5 + EGG_HEIGHT_OFFSET, bb.Position.Z))
end

local function PartTopCFrame(part)
    if not part or not part:IsA("BasePart") or not part.Parent then return nil end
    -- genau wie getBaseplateTopCFrame im Referenz-Script: cf * (0, size.Y/2 + 10, 0)
    return part.CFrame * CFrame.new(0, part.Size.Y * 0.5 + EGG_HEIGHT_OFFSET, 0)
end

-- Reise zu einem CFrame: immer harter Pivot-TP wie im Referenz-Script (kein Tween)
local function TravelToCFrame(cframe)
    if typeof(cframe) ~= "CFrame" then return false end
    return PivotCharacter(cframe)
end

-- Reisen zum Ei / zur Basis / zum Nest (per Position)
local function TravelTo(pos, yOffset)
    if typeof(pos) ~= "Vector3" then return false end
    return TravelToCFrame(CFrame.new(pos + Vector3.new(0, yOffset or 3, 0)))
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

-- Kurze Zahl fürs UI (37,4 Mrd)
local function ShortNumber(n)
    n = tonumber(n) or 0
    if n >= 1e9 then return string.format("%.2f Mrd", n / 1e9) end
    if n >= 1e6 then return string.format("%.1f Mio", n / 1e6) end
    if n >= 1e3 then return string.format("%.0f k", n / 1e3) end
    return tostring(math.floor(n))
end

-- Letzter Prompt-Kontakt (echte Hold-Dauer / Aktions-Text) fürs UI
local lastHold = { duration = nil, method = nil, action = nil }
local PROMPT_SETTLE = 0.05   -- dem Server Zeit geben, den TP zu sehen (schnell, aber nicht 0)

-- Echter Prompt-Trigger - genau das, was ein Executor-Feature "Proximity Prompt"
-- bzw. das Referenz-Script macht: EIN fireproximityprompt auf den Prompt des Spiels.
-- Die Hold-Dauer des Prompts wertet der Executor dabei selbst aus.
--
-- WICHTIG: kein prompt:InputHoldBegin()/InputHoldEnd() mehr! Damit laesst sich der
-- Prompt-Status im Client verhaken (Hold ohne Ende, z.B. wenn das Ei waehrend des
-- Haltens verschwindet) - danach geht KEIN Prompt mehr, auch nicht in anderen
-- Scripts. Genau das war der Fehler.
local function FirePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Parent then return false end
    if prompt.Enabled == false then return false end
    lastHold.duration = tonumber(prompt.HoldDuration) or 0
    lastHold.action = tostring(prompt.ActionText or "")
    local ok = pcall(fireproximityprompt, prompt)
    lastHold.method = ok and "Proximity-Prompt" or "Prompt-Trigger fehlgeschlagen"
    return ok
end

-- ==============================================================================
-- EGG SYSTEM
--
-- Der Server prüft beim Pickup die Distanz zwischen Spieler und Spawn-Punkt des
-- Eis (Limit 90 studs) anhand SEINER Kopie der Spielerposition. Nach einem
-- Teleport ist die erst ~0,3-0,5s später aktuell, deshalb scheiterte der alte
-- ProximityPrompt-Weg ständig mit "refused: too far from its spawn point".
-- Neu: EggPickup-Remote direkt feuern und wiederholen, bis der Korb voll ist.
-- ==============================================================================
local function ServerDataFolder()
    return RS:FindFirstChild("ServerData")
end
local function ActiveEggsFolder()
    local sd = ServerDataFolder()
    return sd and sd:FindFirstChild("ActiveEggs")
end
local function EggPickupRemote() return Remote("EggPickup") end
local function EggPlacedRemote() return Remote("EggPlaced") end
local function ArrivalClaimRemote() return Remote("EggArrivalClaim") end

-- Letzte Server-Antwort auf unser Pickup (echter Grund statt Rätselraten)
local lastPickup = { mode = nil, reason = nil, name = nil }
if EggPickupRemote() then
    track(EggPickupRemote().OnClientEvent:Connect(function(mode, reason, name)
        lastPickup = { mode = tostring(mode), reason = tostring(reason), name = tostring(name) }
    end))
end

-- Alle Feld-Eier aus den Server-Records (nicht die gerenderten Attrappen)
local function EggRecords()
    local out = {}
    local folder = ActiveEggsFolder()
    if not folder then return out end
    local now = Workspace:GetServerTimeNow()
    for _, record in ipairs(folder:GetChildren()) do
        local name = record:GetAttribute("Egg")
        local pos = record:GetAttribute("Position")
        local private = record:GetAttribute("PrivateTo")
        local dropEnds = tonumber(record:GetAttribute("DropEndsAt"))
        local falling = dropEnds ~= nil and dropEnds == dropEnds and dropEnds > now
        if type(name) == "string" and typeof(pos) == "Vector3"
            and (private == nil or private == LP.UserId) and not falling then
            local info = EggInfo(name)
            out[#out + 1] = {
                record = record,
                id = record.Name,
                name = name,
                pos = pos,
                weight = tonumber(record:GetAttribute("Weight")) or 1,
                mutation = record:GetAttribute("Mutation"),
                rarity = (info and info.Rarity) or "?",
                luck = (info and info.Luck) or 0,
                sell = (info and info.SellPrice) or 0,
                growth = (info and info.GrowthTime) or 0,
            }
        end
    end
    return out
end

-- Gerenderte Feld-Eier (der Client baut die Modelle inkl. Pickup-Prompt selbst)
local function RenderedEggs()
    local out = {}
    local rendered = Workspace:FindFirstChild("RenderedEggs")
    if not rendered then return out end
    for _, model in ipairs(rendered:GetChildren()) do
        if model:IsA("Model") then
            local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
            if pp then
                local info = EggInfo(model.Name)
                local prompt = model:FindFirstChild("Pickup", true)
                if not prompt or not prompt:IsA("ProximityPrompt") then
                    prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
                end
                out[#out + 1] = {
                    model = model,
                    pos = pp.Position,
                    rarity = (info and info.Rarity) or "?",
                    prompt = (prompt and prompt:IsA("ProximityPrompt")) and prompt or nil,
                }
            end
        end
    end
    return out
end

-- Gerendertes Ei zu einer Record-Position (für den Pickup-Prompt)
local function RenderedEggNear(pos)
    if typeof(pos) ~= "Vector3" then return nil end
    local best, bestD
    for _, r in ipairs(RenderedEggs()) do
        local d = (r.pos - pos).Magnitude
        if d < 12 and (not bestD or d < bestD) then best, bestD = r, d end
    end
    return best
end

-- Referenz-TP auf ein Feld-Ei: auf das gerenderte Modell (BoundingBox + 10 studs),
-- sonst auf die Server-Position. Kein Distanzlimit, immer harter Pivot.
local function TravelToEgg(egg)
    if not egg or typeof(egg.pos) ~= "Vector3" then return false end
    local rendered = RenderedEggNear(egg.pos)
    local target = rendered and EggTopCFrame(rendered.model)
    if not target then target = CFrame.new(egg.pos + Vector3.new(0, EGG_HEIGHT_OFFSET, 0)) end
    return TravelToCFrame(target)
end

-- LoS-Eier (Tag EggPickupRequiresLineOfSight / RequiresLineOfSight) brauchen
-- Sichtkontakt - nach dem TP die Kamera auf das Ei ausrichten.
local function AimCameraAtEgg(rendered)
    local prompt = rendered and rendered.prompt
    local part = prompt and prompt.Parent
    if not part or not part:IsA("BasePart") then return false end
    local needs = prompt.RequiresLineOfSight == true
    pcall(function()
        if not needs and part:HasTag("EggPickupRequiresLineOfSight") then needs = true end
    end)
    if not needs then return false end
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    pcall(function() cam.CFrame = CFrame.lookAt(cam.CFrame.Position, part.Position) end)
    return true
end

local function RarityAllowed(rarity)
    if not S.eggRarities or next(S.eggRarities) == nil then return true end
    return S.eggRarities[rarity] == true
end

-- Priorisierung: Fast Cycle | Best Value | Nearest
-- Wie im Referenz-Script wird nur auf Eier getippt, die der Client wirklich
-- gerendert hat - nur dort sitzt der Pickup-Prompt, nur dort greift der Claim.
local function PickTargetEgg()
    local hrp = GetHRP()
    if not hrp then return nil end
    local origin = hrp.Position
    local renderedList = RenderedEggs()
    local function Claimable(egg)
        for _, r in ipairs(renderedList) do
            if (r.pos - egg.pos).Magnitude < 8 and r.prompt and r.prompt.Parent then return true end
        end
        return false
    end
    local best, bestScore, bestClaimable = nil, nil, false
    for _, egg in ipairs(EggRecords()) do
        if RarityAllowed(egg.rarity) then
            local travel = ((egg.pos - origin) * Vector3.new(1, 0, 1)).Magnitude
            if S.maxEggTravel <= 0 or travel <= S.maxEggTravel then
                local claimable = Claimable(egg)
                local value = RarityRank(egg.rarity) * 1000 + egg.luck + egg.sell * 10
                local score
                if S.eggPriority == "Nearest" then
                    score = -travel
                elseif S.eggPriority == "Fast Cycle" then
                    -- schnelle Runden: Wert pro (Reisezeit + Wachstumszeit)
                    score = value / math.max((travel / 200) + egg.growth + 2, 1)
                else -- Best Value
                    score = value - travel * 0.1
                end
                -- Eier mit Prompt (gerendert) immer bevorzugen, der Rest nur als Notnagel
                if claimable and not bestClaimable then
                    best, bestScore, bestClaimable = egg, score, true
                elseif claimable == bestClaimable and (not bestScore or score > bestScore) then
                    best, bestScore = egg, score
                end
            end
        end
    end
    return best
end

-- Ei aufnehmen - exakt die Methode des getesteten Referenz-Scripts:
--   TP auf 10 studs über der Oberkante des GERENDERTEN Eis -> fireproximityprompt.
--   Den Prompt gibt es nur am gerenderten Modell, deshalb wird das zuerst gesucht
--   (der Remote ist nur Notnagel, wenn gar kein Prompt greift).
local function CollectEgg(egg, tries)
    if not egg or HUB.dead then return false, "kein Ziel" end
    if #CarriedEggs() > 0 then return false, "Korb voll" end
    local before = #CarriedEggs()
    lastPickup = { mode = nil, reason = nil, name = egg.name, hold = nil, method = nil }
    local function WaitBasket(seconds)
        local waited = 0
        while waited < seconds and #CarriedEggs() == before do
            task.wait(0.02)
            waited = waited + 0.02
        end
        return #CarriedEggs() > before
    end
    for _ = 1, tonumber(tries) or S.pickupRetries or 8 do
        if HUB.dead then return false, "unload" end
        if #CarriedEggs() > before then return true end
        if not egg.record.Parent then return false, "Ei weg" end
        local rendered = RenderedEggNear(egg.pos)
        local prompt = rendered and rendered.prompt
        if prompt and prompt.Parent then
            -- 1.) Referenz-TP: harter Pivot 10 studs über die Ei-Oberkante
            local near = prompt.Parent
            TravelToCFrame(EggTopCFrame(rendered.model) or CFrame.new(rendered.pos + Vector3.new(0, 10, 0)))
            -- Hat der Prompt eine kleinere Aktivierungs-Distanz, noch näher ran
            local hrp = GetHRP()
            local maxDist = tonumber(prompt.MaxActivationDistance) or 10
            if near and hrp and (hrp.Position - near.Position).Magnitude > maxDist then
                TravelToCFrame(CFrame.new(near.Position + Vector3.new(0, math.max(3, maxDist - 2), 0)))
            end
            AimCameraAtEgg(rendered)      -- LoS-Eier: Sichtkontakt herstellen
            -- 2.) ECHTER Prompt sofort feuern (kein Settle - der bremste jeden Zyklus).
            -- Braucht der Server nach dem TP einen Moment, wird direkt nachgefeuert.
            if prompt.Parent then FirePrompt(prompt) end
            lastPickup.hold = lastHold.duration
            lastPickup.method = lastHold.method
            local hold = tonumber(lastHold.duration) or 0
            if WaitBasket(0.04) then return true end
            if prompt.Parent then
                task.wait(0.02)
                FirePrompt(prompt)
            end
            if WaitBasket(math.max(0.15, hold + 0.12)) then return true end
        end
        -- 3.) Nur auf Wunsch ("Direkte Remotes"): EggPickup als Notnagel feuern.
        -- Standard aus - Remotes koennen serverseitig auffallen und dann geht auch
        -- der echte Prompt-Weg nicht mehr.
        local remote = S.useRemotes and EggPickupRemote() or nil
        if remote then
            pcall(function() remote:FireServer(egg.id) end)
            if WaitBasket(0.3) then return true end
        end
        -- Korb voll -> nicht weiter hämmern
        if lastPickup.mode == "BasketFull" or (lastPickup.reason or ""):find("basket") then
            return false, "Korb voll"
        end
    end
    if #CarriedEggs() > before then return true end
    return false, tostring(lastPickup.reason or lastPickup.mode or "keine Antwort")
end

-- Liefern: in die eigene Baseplate -> der Spiel-Client claimt selbst (Cash)
local function DeliverCarried()
    if #CarriedEggs() == 0 then return false, "Korb leer" end
    local plot = OwnPlot()
    local base = plot and plot:FindFirstChild("Baseplate")
    if not base then return false, "kein Plot" end
    local cashBefore = PlayerCash()
    -- Heimreise: 10 studs über der Baseplate (genau wie im Referenz-Script)
    TravelToCFrame(PartTopCFrame(base) or CFrame.new(base.Position + Vector3.new(0, 6, 0)))
    for _ = 1, 100 do
        task.wait(0.02)
        if #CarriedEggs() == 0 then break end
    end
    if #CarriedEggs() > 0 and S.useRemotes then
        -- Nur auf Wunsch: Claim wie der Spiel-Client selbst feuern
        -- (Standard: das macht der Spiel-Client von allein - wie im Referenz-Script)
        local claim, hrp = ArrivalClaimRemote(), GetHRP()
        if claim and hrp then
            local names = {}
            for _, c in ipairs(CarriedEggs()) do names[#names + 1] = c.Name end
            pcall(function() claim:FireServer(Workspace:GetServerTimeNow(), hrp.Position, names) end)
            for _ = 1, 20 do
                task.wait(0.05)
                if #CarriedEggs() == 0 then break end
            end
        end
    end
    if #CarriedEggs() > 0 then return false, "Lieferung haengt" end
    S.stats.delivered = S.stats.delivered + 1
    -- Cash-Auswertung NICHT abwarten (sonst kostet jede Lieferung Extra-Zeit):
    -- kurz schauen, den Rest asynchron nachtragen.
    local gained = PlayerCash() - cashBefore
    if gained > 0 then S.stats.cash = S.stats.cash + gained end
    task.spawn(function()
        for _ = 1, 30 do
            if HUB.dead then break end
            task.wait(0.05)
            local now = PlayerCash() - cashBefore
            if now > gained then
                S.stats.cash = S.stats.cash + (now - gained)
                gained = now
            elseif now > 0 then
                break
            end
            if gained > 0 then break end
        end
    end)
    return true, gained
end

-- Ei-Tools im Inventar (das sind die pflanzbaren Eier)
local function EggTools()
    local out = {}
    for _, c in ipairs({ LP:FindFirstChild("Backpack"), LP.Character }) do
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t:HasTag("Egg") then
                    local info = EggInfo(t.Name)
                    out[#out + 1] = {
                        tool = t,
                        name = t.Name,
                        weight = tonumber(t:GetAttribute("Weight")) or 1,
                        mutation = t:GetAttribute("Mutation"),
                        rarity = (info and info.Rarity) or "?",
                        luck = (info and info.Luck) or 0,
                        equipped = t.Parent == LP.Character,
                    }
                end
            end
        end
    end
    return out
end

local function HeldEggTool()
    local char = LP.Character
    if not char then return nil end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") and c:HasTag("Egg") then return c end
    end
    return nil
end

local function FreeNest()
    local plot = OwnPlot()
    local nests = PlotNests(plot)
    if not nests then return nil, plot end
    for _, n in ipairs(nests:GetChildren()) do
        if n:GetAttribute("Unlocked") == true and not n:GetAttribute("Occupied") then
            return n, plot
        end
    end
    return nil, plot
end

local function NestPosition(nest, plot)
    local anchor = nest:FindFirstChild("PlacePromptAnchor")
    if anchor and anchor:IsA("BasePart") then return anchor.Position end
    local model = nest:FindFirstChild("Model")
    if model then return model:GetPivot().Position end
    local base = plot and plot:FindFirstChild("Baseplate")
    return base and base.Position or nil
end

-- Bestes Inventar-Ei in ein freies Nest pflanzen (Spiel-Methode, ohne Prompt)
local function PlantBestEgg(minLuck)
    if HUB.dead then return false, "unload" end
    local remote = EggPlacedRemote()
    if not remote then return false, "EggPlaced fehlt" end
    local nest, plot = FreeNest()
    if not nest then return false, "kein freies Nest" end
    local pick
    for _, entry in ipairs(EggTools()) do
        if entry.luck >= (tonumber(minLuck) or 0) then
            if not pick or entry.luck > pick.luck
                or (entry.luck == pick.luck and RarityRank(entry.rarity) > RarityRank(pick.rarity)) then
                pick = entry
            end
        end
    end
    if not pick then return false, "kein Ei im Inventar" end
    local humanoid = GetHumanoid()
    if not humanoid then return false, "kein Humanoid" end
    if HeldEggTool() ~= pick.tool then
        pcall(function() humanoid:UnequipTools() end)
        task.wait(0.1)
        pcall(function() humanoid:EquipTool(pick.tool) end)
        task.wait(0.35)
    end
    -- Ohne gehaltenes Ei-Tool darf NICHT gefeuert werden, sonst ist das Ei weg
    if not HeldEggTool() then return false, "Ei nicht in der Hand" end
    local eggsFolder = plot and PlotEggs(plot)
    local before = eggsFolder and #eggsFolder:GetChildren() or 0
    local pos = NestPosition(nest, plot)
    if pos then
        TravelTo(pos, 4)
        task.wait(0.25)
    end
    if nest:GetAttribute("Occupied") == true then return false, "Nest schon besetzt" end
    if LP:GetAttribute("NoNest") == true then
        -- Variante ohne Nest: irgendwo im eigenen Plot
        local base = plot and plot:FindFirstChild("Baseplate")
        local plantPos = base and base.Position or pos
        if not plantPos then return false, "keine Position" end
        pcall(function() remote:FireServer({ PlantPosition = plantPos }) end)
    else
        pcall(function() remote:FireServer({ NestId = nest.Name }) end)
    end
    local placed = false
    for _ = 1, 8 do
        task.wait(0.15)
        if nest:GetAttribute("Occupied") == true
            or (eggsFolder and #eggsFolder:GetChildren() > before) then
            placed = true
            break
        end
    end
    if placed then
        S.stats.planted = S.stats.planted + 1
        return true, pick.name
    end
    return false, "Place abgelehnt"
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
    local pp = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)
    -- Echter Weg zuerst: Hatch-Prompt des Spiels (TP 10 studs über die Oberkante)
    local prompt = egg:FindFirstChild("Hatch", true)
    if prompt and prompt:IsA("ProximityPrompt") then
        if pp then
            TravelToCFrame(PartTopCFrame(pp) or CFrame.new(pp.Position + Vector3.new(0, 10, 0)))
            task.wait(PROMPT_SETTLE)
        end
        return FirePrompt(prompt), "prompt"
    end
    -- Nur auf Wunsch: Remote direkt
    if not S.useRemotes then return false, "kein Hatch-Prompt" end
    local key = egg:GetAttribute("EggKey")
    if not key then return false, "kein EggKey" end
    local remote = Remote("Hatch")
    if not remote then return false, "Hatch fehlt" end
    if pp then
        TravelTo(pp.Position, 4)
        task.wait(0.2)
    end
    return (pcall(function() remote:FireServer({ EggKey = key }) end)), "remote"
end

-- Alle reifen Eier hatchen
-- (der Hatch läuft als Animation, das Ei verschwindet erst ein paar Sekunden später)
local function HatchReadyEggs()
    local plot = OwnPlot()
    local eggs = PlotEggs(plot)
    if not eggs then return 0 end
    local before = #eggs:GetChildren()
    local fired = 0
    for _, egg in ipairs(eggs:GetChildren()) do
        local prompt = egg:FindFirstChild("Hatch", true)
        local available = prompt and prompt:GetAttribute("HatchPromptAvailable")
        local remaining = GrowthRemaining(egg)
        if available == true or remaining <= 0 then
            if HatchEgg(egg) then fired = fired + 1 end
            task.wait(S.hatchDelay)
        end
    end
    if fired == 0 then return 0 end
    local count = 0
    for _ = 1, 40 do
        task.wait(0.25)
        local now = (eggs.Parent and #eggs:GetChildren()) or 0
        count = math.max(before - now, 0)
        if count >= fired then break end
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

-- Pet-Earnings einsammeln: zuerst der echte Prompt am Pet, erst auf Wunsch der Remote
local function PetCollectPrompt(pet)
    for _, d in ipairs(pet:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local txt = string.lower(tostring(d.ActionText or "") .. " " .. tostring(d.ObjectText or "") .. " " .. d.Name)
            if txt:find("collect") or txt:find("einsammeln") or txt:find("abholen") or txt:find("kassieren") then
                return d
            end
        end
    end
    return nil
end

local function CollectPetEarnings()
    local remote = S.useRemotes and Remote("PetCollect") or nil
    local n = 0
    for _, pet in ipairs(OwnPlotPets()) do
        local prompt = PetCollectPrompt(pet)
        if prompt then
            local hrp = GetHRP()
            local pp = prompt.Parent
            if hrp and pp and pp:IsA("BasePart") and (hrp.Position - pp.Position).Magnitude > 12 then
                TravelTo(pp.Position, 6)
                task.wait(PROMPT_SETTLE)
            end
            FirePrompt(prompt)
            n = n + 1
            task.wait(0.12)
        else
            local key = pet:GetAttribute("PetKey")
            if remote and key then
                pcall(function() remote:FireServer(key) end)
                n = n + 1
                task.wait(0.08)
            end
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
    if kind == "egg" then ClearEggMarkers() end
    for inst, h in pairs(espMaps[kind]) do
        pcall(function() h:Destroy() end)
        espMaps[kind][inst] = nil
    end
    for i = #HUB.highlights, 1, -1 do
        if HUB.highlights[i].kind == kind then table.remove(HUB.highlights, i) end
    end
end
local ClearHighlights = HideESP

-- ── Egg-Marker: zeigt ALLE ungeclaimten Feld-Eier aus ServerData.ActiveEggs,
--    auch die der Client gerade nicht zeichnet. Damit kann man zu Fuß hinlaufen
--    und selbst aufsammeln. ───────────────────────────────────────────────────
local eggMarkers = {}          -- record-Id -> { part, highlight, gui, label }
local markerFolder = nil

local function MarkerFolder()
    if markerFolder and markerFolder.Parent then return markerFolder end
    markerFolder = Instance.new("Folder")
    markerFolder.Name = "ArcHubEggMarkers"
    markerFolder.Parent = Workspace.CurrentCamera or Workspace
    return markerFolder
end

local function ForgetHighlight(instance)
    for i = #HUB.highlights, 1, -1 do
        if HUB.highlights[i].instance == instance then table.remove(HUB.highlights, i) end
    end
end

local function ClearEggMarkers()
    for id, m in pairs(eggMarkers) do
        if m.highlight then
            ForgetHighlight(m.highlight)
            pcall(function() m.highlight:Destroy() end)
        end
        if m.part then pcall(function() m.part:Destroy() end) end
        eggMarkers[id] = nil
    end
end

local function MakeEggMarker(id, egg)
    local color = ESP_COLORS[egg.rarity] or Color3.new(1, 1, 1)
    local part = Instance.new("Part")
    part.Name = "ArcEggMarker"
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(3, 3, 3)
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false       -- verfälscht keine Raycasts des Spiels
    part.CanTouch = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = 0.6
    part.CFrame = CFrame.new(egg.pos + Vector3.new(0, 1.5, 0))
    part.Parent = MarkerFolder()

    local h = Instance.new("Highlight")
    h.Name = "ArcHubESP"
    h.Adornee = part
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.FillColor = color
    h.FillTransparency = 0.7
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.OutlineTransparency = 0
    h.Parent = part
    table.insert(HUB.highlights, { instance = h, kind = "egg" })

    local gui = Instance.new("BillboardGui")
    gui.Name = "ArcEggLabel"
    gui.Size = UDim2.fromOffset(180, 30)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.MaxDistance = 6000
    gui.Parent = part
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    label.TextStrokeTransparency = 0.35
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextColor3 = color
    label.Text = ""
    label.Parent = gui

    eggMarkers[id] = { part = part, highlight = h, gui = gui, label = label }
    return eggMarkers[id]
end

local function HighlightFor(kind, inst)
    if not inst or not inst.Parent then return nil end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return nil end
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
    local seen, seenIds, known = {}, {}, {}
    local own = OwnPlot()
    local hrp = GetHRP()
    local origin = hrp and hrp.Position or nil
    local maxDist = tonumber(S.espEggMaxDist) or 0
    local labels = S.espEggLabels ~= false
    local rendered = RenderedEggs()

    -- 1a) ALLE ungeclaimten Feld-Eier (Server-Records) -> Marker + Highlight
    for _, egg in ipairs(EggRecords()) do
        if EspRarityOk(egg.rarity) then
            local dist = origin and ((egg.pos - origin) * Vector3.new(1, 0, 1)).Magnitude or 0
            if maxDist <= 0 or dist <= maxDist then
                local color = ESP_COLORS[egg.rarity] or Color3.new(1, 1, 1)
                local outline = egg.mutation and Color3.fromRGB(255, 215, 80) or Color3.fromRGB(255, 255, 255)
                -- passendes gerendertes Modell, falls der Client es zeichnet
                local model, modelDist
                for _, r in ipairs(rendered) do
                    local d = (r.pos - egg.pos).Magnitude
                    if d < 8 and (not modelDist or d < modelDist) then model, modelDist = r.model, d end
                end
                if model then
                    known[model] = true
                    local h = HighlightFor("egg", model)
                    if h then
                        h.FillColor = color
                        h.OutlineColor = outline
                        h.FillTransparency = 0.55
                        seen[model] = true
                    end
                end
                local m = eggMarkers[egg.id]
                if not m then m = MakeEggMarker(egg.id, egg) end
                if m and m.part and m.part.Parent then
                    m.part.CFrame = CFrame.new(egg.pos + Vector3.new(0, 1.5, 0))
                    m.part.Color = color
                    m.part.Transparency = model and 0.75 or 0.6
                    if m.highlight then
                        m.highlight.Enabled = true
                        m.highlight.FillColor = color
                        m.highlight.FillTransparency = model and 0.85 or 0.7
                        m.highlight.OutlineColor = outline
                    end
                    if m.gui then m.gui.Enabled = labels end
                    if m.label and labels then
                        m.label.TextColor3 = color
                        m.label.Text = string.format("%s - %s - %dm%s", egg.name, egg.rarity, math.floor(dist),
                            egg.mutation and (" - " .. tostring(egg.mutation)) or "")
                    end
                end
                seenIds[egg.id] = true
            end
        end
    end

    -- 1b) gerenderte Eier ohne Record (z.B. gerade am Runterfallen) trotzdem zeigen
    for _, r in ipairs(rendered) do
        if not known[r.model] and EspRarityOk(r.rarity) then
            local h = HighlightFor("egg", r.model)
            if h then
                h.FillColor = ESP_COLORS[r.rarity] or Color3.new(1, 1, 1)
                h.OutlineColor = Color3.fromRGB(255, 255, 255)
                h.FillTransparency = 0.55
                seen[r.model] = true
            end
        end
    end

    -- Marker aufräumen (geclaimt, weg oder rausgefiltert)
    for id, m in pairs(eggMarkers) do
        if not seenIds[id] then
            if m.highlight then
                ForgetHighlight(m.highlight)
                pcall(function() m.highlight:Destroy() end)
            end
            if m.part then pcall(function() m.part:Destroy() end) end
            eggMarkers[id] = nil
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
-- NOCLIP (nur fuer den Egg-Farm - kein manueller Toggle mehr)
-- ==============================================================================
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

-- ==============================================================================
-- TELEPORTS / UTILITY BUTTONS
-- ==============================================================================
local function TeleportToOwnPlot()
    local plot = OwnPlot()
    if not plot then return Notify("Arc HUB", "Kein Plot geladen", "Error") end
    local base = plot:FindFirstChild("Baseplate") or plot:FindFirstChild("Baseplate", true)
    if base then TravelToCFrame(PartTopCFrame(base)) end
end
local function TeleportToStall(name)
    local stalls = Workspace:FindFirstChild("Stalls")
    local stall = stalls and stalls:FindFirstChild(name)
    if not stall then return Notify("Arc HUB", "Stall nicht gefunden", "Error") end
    local pivot = stall:IsA("Model") and stall:GetPivot().Position or stall.Position
    TravelTo(pivot, 6)
end

-- ==============================================================================
-- LOOPS
-- ==============================================================================
local function EggLoopStep()
    if S.busy then return end
    -- Shift halten = Auto Farm pausiert (manuell spielen / anderes Script nutzen)
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
        return
    end
    -- Eingriff-Erkennung: hat uns jemand/etwas anderes bewegt, dann kurz still halten,
    -- sonst kämpfen wir gegen den Nutzer (oder ein zweites Script) an.
    local hrpNow = GetHRP()
    if hrpNow and HUB.lastPlacedPos and HUB.lastPlacedAt then
        local fresh = (os.clock() - HUB.lastPlacedAt) < 0.6
        if not fresh and (hrpNow.Position - HUB.lastPlacedPos).Magnitude > 40 then
            HUB.manualUntil = os.clock() + 1.5
            HUB.lastPlacedPos = hrpNow.Position
            if (os.clock() - (HUB.manualWarnAt or 0)) > 8 then
                HUB.manualWarnAt = os.clock()
                Notify("Auto Farm", "Pause - der Charakter wurde von aussen bewegt", "Info", 3)
            end
        end
    end
    if HUB.manualUntil and os.clock() < HUB.manualUntil then return end
    S.busy = true
    local did = false
    local ok, err = pcall(function()
        -- 1) TP aufs gerenderte Ei (10 studs über der Oberkante) -> Claim-Prompt
        if #CarriedEggs() == 0 then
            local target = PickTargetEgg()
            if target then
                local got, why = CollectEgg(target)
                if got then
                    S.stats.eggs = S.stats.eggs + 1
                    did = true
                else
                    S.lastEggError = tostring(why)
                end
            end
        end
        -- 1b) Pause vor Heim-TP (Standard 0 = sofort weiter)
        local delay = tonumber(S.deliverDelay) or 0
        if did and delay > 0 then
            local t0 = os.clock()
            while not HUB.dead and (os.clock() - t0) < delay do task.wait(0.02) end
        end
        -- 2) TP zurueck ueber die eigene Baseplate -> abliefern (zahlt Cash)
        if #CarriedEggs() > 0 and S.autoDeliver then
            if DeliverCarried() then did = true end
        end
        -- 3) Nebenaufgaben (Pflanzen/Hatchen) nur alle X Sekunden - die Teleports
        --    darin wuerden den schnellen Egg-Zyklus sonst ausbremsen.
        local now = os.clock()
        local every = tonumber(S.sideInterval) or 3
        if every >= 0 and (now - (HUB.lastSideAt or 0)) >= every then
            HUB.lastSideAt = now
            if S.autoPlant then PlantBestEgg(S.plantMinLuck) end
            if S.autoHatch then HatchReadyEggs() end
        end
    end)
    if not ok then pcall(Notify, "Arc HUB", "Egg-Loop: " .. tostring(err), "Error", 3) end
    S.busy = false
    return did
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
                local ok, did = pcall(EggLoopStep)
                if did then
                    -- sofort weiter zum naechsten Ei; nur die optionale Zusatzpause bremst
                    local extra = tonumber(S.eggLoopDelay) or 0
                    if extra > 0 then task.wait(extra) end
                else
                    task.wait(0.12)           -- gerade nichts zu tun -> kurz warten
                end
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
            -- immer aufrufen: schaltet ESP auch ab, wenn die Flags von außen kommen
            pcall(RefreshESP)
            task.wait(0.5)
        end
    end)
end

-- ==============================================================================
-- UI
-- ==============================================================================
local mainTab = Window:AddTab("Auto Farm")
local shopTab = Window:AddTab("Shops")
local espTab  = Window:AddTab("ESP")
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
        S.autoDeliver = true; S.autoHatch = true
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
    local hold = tonumber(lastHold.duration) or 0
    return string.format(
        "Eier %d | geliefert %d (+%s $) | gepflanzt %d | gehatcht %d | Collects %d | Nester %d | Rebirth %d | Luck x%.1f",
        S.stats.eggs, S.stats.delivered, ShortNumber(S.stats.cash), S.stats.planted, S.stats.hatched,
        S.stats.collected, S.stats.nests, S.stats.rebirths, HatchLuckMultiplier())
        .. string.format("\nPickup: %s | echter Prompt, Hold %.2fs | letzter Fehler: %s",
            tostring(lastHold.method or "-"), hold, S.lastEggError and tostring(S.lastEggError) or "-")
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
    Name = "Loop-Zusatzpause (0 = sofort)", Min = 0, Max = 3, Default = 0, Suffix = "s", Flag = "eggs_delay",
    Callback = safeCallback(function(v) S.eggLoopDelay = tonumber(v) or 0 end)
})
eggsLoopSub:AddSlider({
    Name = "Max. Distanz (0 = egal)", Min = 0, Max = 5000, Default = 0, Suffix = " studs", Flag = "eggs_travel",
    Callback = safeCallback(function(v) S.maxEggTravel = tonumber(v) or 0 end)
})
eggsLoopSub:AddDivider()
eggsLoopSub:AddToggle({
    Name = "Auto Liefern (Cash)", Default = true, Flag = "eggs_deliver",
    Callback = safeCallback(function(v) S.autoDeliver = v end)
})
eggsLoopSub:AddToggle({
    Name = "Auto Pflanzen (Inventar)", Default = false, Flag = "eggs_plant",
    Callback = safeCallback(function(v)
        S.autoPlant = v
        if v then StartLoops() end
    end)
})
eggsLoopSub:AddSlider({
    Name = "Pflanzen ab Luck", Min = 0, Max = 5000, Default = 0, Flag = "eggs_plantluck",
    Callback = safeCallback(function(v) S.plantMinLuck = tonumber(v) or 0 end)
})
eggsLoopSub:AddSlider({
    Name = "Pickup-Versuche", Min = 2, Max = 20, Default = 8, Flag = "eggs_pickuptries",
    Callback = safeCallback(function(v) S.pickupRetries = math.floor(tonumber(v) or 8) end)
})
eggsLoopSub:AddSlider({
    Name = "Pause vor Heim-TP (0 = sofort)", Min = 0, Max = 5, Default = 0, Suffix = "s", Flag = "eggs_deliverdelay",
    Callback = safeCallback(function(v) S.deliverDelay = tonumber(v) or 0 end)
})
eggsLoopSub:AddSlider({
    Name = "Pflanzen/Hatch alle", Min = 0, Max = 30, Default = 3, Suffix = "s", Flag = "eggs_sideinterval",
    Callback = safeCallback(function(v) S.sideInterval = tonumber(v) or 3 end)
})
eggsLoopSub:AddToggle({
    Name = "Direkte Remotes (Notnagel)", Default = false, Flag = "eggs_useremotes",
    Callback = safeCallback(function(v) S.useRemotes = v end)
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
eggsLoopSub:AddParagraph({
    Title = "Pickup-Methode",
    Text = "Harter TP (Character:PivotTo) auf 10 studs über die Ei-Oberkante, dann der ECHTE Pickup-Prompt des Spiels (fireproximityprompt) - genau wie das Referenz-Script. Standardmäßig werden KEINE Remotes gefeuert; 'Direkte Remotes' schaltet den alten Notnagel wieder ein. Shift halten pausiert die Farm sofort, und wenn der Charakter von aussen bewegt wird, pausiert sie 1,5s von selbst.",
})
eggsLoopSub:AddButton({
    Name = "1 Ei farmen", Primary = true,
    Callback = safeCallback(function()
        if #CarriedEggs() == 0 then
            local t = PickTargetEgg()
            if not t then return Notify("Eggs", "kein Ei gefunden", "Info") end
            local got, why = CollectEgg(t, 10)
            if got then
                Notify("Eggs", t.name .. " aufgenommen", "Success")
            else
                Notify("Eggs", "Aufnahme abgelehnt: " .. tostring(why), "Error", 4)
            end
        else
            local ok, gained = DeliverCarried()
            local txt
            if ok then
                txt = (tonumber(gained) or 0) > 0
                    and ("geliefert (+" .. ShortNumber(gained) .. " $)")
                    or "geliefert (Cash wird nachgebucht)"
            else
                txt = "Lieferung: " .. tostring(gained)
            end
            Notify("Eggs", txt, ok and "Success" or "Error")
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
eggsInfoSub:AddButton({
    Name = "Bestes Ei pflanzen",
    Callback = safeCallback(function()
        local ok, res = PlantBestEgg(S.plantMinLuck)
        Notify("Pflanzen", ok and ("gepflanzt: " .. tostring(res)) or tostring(res), ok and "Success" or "Error")
    end)
})
eggsInfoSub:AddButton({
    Name = "Eier zählen",
    Callback = safeCallback(function()
        Notify("Eier", string.format("%d Feld-Eier | %d Ei-Tools im Inventar", #EggRecords(), #EggTools()), "Info", 4)
    end)
})
eggsInfoSub:AddParagraph({
    Title = "Ablauf (getestetes Rezept)",
    Text = "Hin zum Ei (harter TP, 10 studs über der Oberkante) -> Pickup per echtem Spiel-Prompt -> zurück über die eigene Baseplate -> Abgabe gibt Cash. Ohne Prompt wird abgebrochen statt Remotes zu hämmern (siehe 'Direkte Remotes'). Inventar-Eier werden ins freie Nest gepflanzt, reife Eier gehatcht.",
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
espSub:AddToggle({
    Name = "Eier: Name + Distanz", Default = true, Flag = "esp_egglabels",
    Callback = safeCallback(function(v) S.espEggLabels = v RefreshESP() end)
})
espSub:AddSlider({
    Name = "Eier: Marker bis (0 = alle)", Min = 0, Max = 8000, Default = 0, Suffix = " studs", Flag = "esp_eggmax",
    Callback = safeCallback(function(v) S.espEggMaxDist = tonumber(v) or 0 RefreshESP() end)
})
espSub:AddParagraph({
    Title = "Egg ESP",
    Text = "Markiert ALLE ungeclaimten Feld-Eier (Server-Records), auch die der Client gerade nicht zeichnet. Farbe = Rarität, gelber Rahmen = Mutation, Label = Name/Rarität/Distanz.",
})
espSub:AddButton({
    Name = "Nächstes Ei anlaufen",
    Callback = safeCallback(function()
        local t = PickTargetEgg()
        if t then TravelToEgg(t) Notify("Egg ESP", t.name, "Success") else Notify("Egg ESP", "kein Ei", "Info") end
    end)
})

-- Player-Tab ist komplett entfernt (Speed/Jump/Fly/Gravity/FOV/Fullbright/
-- FPS-Modus/Anti-AFK/Anti-Kick/Auto-Rejoin) - das war die Fehlerquelle.

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
    for _, k in ipairs({ "noclipConn", "loopsRunning" }) do
        if HUB[k] and type(HUB[k]) ~= "boolean" then pcall(function() HUB[k]:Disconnect() end) end
        HUB[k] = nil
    end
    -- Highlights + Drawings
    for _, h in ipairs(HUB.highlights) do pcall(function() h.instance:Destroy() end) end
    HUB.highlights = {}
    pcall(ClearEggMarkers)
    for _, d in ipairs(HUB.drawings) do pcall(function() d:Remove() end) end
    HUB.drawings = {}
    -- Noclip/Kollisionen zuruecksetzen
    S.farmNoclip, S.farmNoclipActive = false, false
    pcall(RestoreCollisions)
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
    DeliverCarried = DeliverCarried,
    PlantBestEgg = PlantBestEgg,
    HatchReadyEggs = HatchReadyEggs,
    CollectPetEarnings = CollectPetEarnings,
    PlaceBestPets = PlaceBestPets,
    FeedPets = FeedPets,
    UnlockNests = UnlockNests,
    TryRebirth = TryRebirth,
    OwnPlot = OwnPlot,
    EggRecords = EggRecords,
    RenderedEggs = RenderedEggs,
    EggTools = EggTools,
    GrowthRemaining = GrowthRemaining,
}
StartLoops()
Notify("Arc HUB", "Reite ein Haustier geladen", "Success", 3)

return HUB

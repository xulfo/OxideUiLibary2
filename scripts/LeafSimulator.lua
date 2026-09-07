-- ═══ HUB STRIP POINT — when deployed via the ScriptLoader the ScriptLoader injects
--     "local Library = _G.OxideLib" above this line instead. ═══
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- RE-EXECUTION GUARD + RESOURCE TRACKING
-- ══════════════════════════════════════════════════════════════════════════════
do
    local prev = _G.OxideLeafSim
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, dead = false }
_G.OxideLeafSim = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end

local Window = Library:CreateWindow({
    Name = "Oxide HUB | 🍂 Spiel",
    LoadingAnimation = true,
    LoadingText = "Oxide",
    LoadingDuration = 2.2,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG / FLAG PERSISTENCE
-- ══════════════════════════════════════════════════════════════════════════════
local HAS_CONFIG  = type(Library.SaveConfig) == "function"
    and type(Library.LoadConfig) == "function"
    and type(Library.ListConfigs) == "function"
local CONFIG_NAME = "leafspiel"

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
-- SERVICES + HELPERS
-- ══════════════════════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local function Notify(title, content, kind, dur)
    pcall(function()
        Window:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = dur or 2.5 })
    end)
end

local function safeCallback(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            pcall(Notify, "Oxide HUB", "Error: " .. tostring(err), "Error", 4)
        end
    end
end

local function GetCharacter() return LocalPlayer.Character end
local function GetHumanoid()
    local c = GetCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function GetHRP()
    local c = GetCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function TeleportTo(pos)
    local hrp = GetHRP()
    if not hrp or not pos then return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    return true
end

-- ══════════════════════════════════════════════════════════════════════════════
-- GAME API — LeafSim module + remotes. A require/fire failure here must never
-- break the UI, so everything is lazy and pcall-guarded.
-- ══════════════════════════════════════════════════════════════════════════════
local LeafSim, LeafSimErr
local Remotes, UpgradeConfig, BagConfig
local GAME_OK = false

local function tryRequire(mod)
    local ok, m = pcall(require, mod)
    return ok, m
end

local function initGame()
    if GAME_OK then return end
    if not LeafSim then
        local ok, m = tryRequire(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("LeafSim"))
        if ok and m then LeafSim = m else LeafSimErr = tostring(m) end
    end
    if not Remotes then
        Remotes = ReplicatedStorage:FindFirstChild("Remotes")
    end
    if not UpgradeConfig then
        UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
    end
    if not BagConfig then
        BagConfig = require(ReplicatedStorage:WaitForChild("BagConfig"))
    end
    GAME_OK = LeafSim ~= nil and Remotes ~= nil
end

local function Remote(name)
    return Remotes and Remotes:FindFirstChild(name) or nil
end
local function fire(name, ...)
    local r = Remote(name)
    if not r then return false end
    local args = { ... }
    local ok = pcall(function() r:FireServer(unpack(args)) end)
    return ok
end
local function invoke(name, ...)
    local r = Remote(name)
    if not r then return nil end
    local args = { ... }
    local ok, res = pcall(function() return r:InvokeServer(unpack(args)) end)
    return ok and res or nil
end

-- Attribute shortcuts (the game mirrors its live state onto LocalPlayer attrs)
local function attr(name) return LocalPlayer:GetAttribute(name) end
local function setAttr(name, v) return pcall(function() LocalPlayer:SetAttribute(name, v) end) end

local function GetCash()     return tonumber(attr("Cash")) or 0 end
local function GetLeaves()   return tonumber(attr("Leaves")) or 0 end
local function GetCapacity() return tonumber(attr("LeafCapacity")) or 0 end
local function GetInfinite() return attr("InfiniteBag") == true end
local function GetBagSpace()
    if GetInfinite() then return 1e9 end
    local cap = GetCapacity()
    if cap <= 0 then cap = 25 end
    return math.max(0, cap - GetLeaves())
end
local function GetUpgLevel(toolKey, upgName)
    return tonumber(attr("Upg_" .. toolKey .. "_" .. upgName)) or 0
end

-- ══════════════════════════════════════════════════════════════════════════════
-- FARM — COLLECT
-- ══════════════════════════════════════════════════════════════════════════════
local function IsInRun()
    return ReplicatedStorage:GetAttribute("RunEndTime") ~= nil
end

local function CollectNearby(radius)
    if not LeafSim or not LeafSim.folder then return 0 end
    local hrp = GetHRP()
    if not hrp then return 0 end
    local space = GetBagSpace()
    if space <= 0 then return 0 end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { LeafSim.folder }
    params.MaxParts = 800
    local parts = Workspace:GetPartBoundsInRadius(hrp.Position, radius, params)
    local pick = {}
    local n = 0
    for _, p in ipairs(parts) do
        if n >= space then break end
        n = n + 1
        pick[n] = p
    end
    if n == 0 then return 0 end
    local got = LeafSim.collectMany(pick)
    return got or 0
end

-- ══════════════════════════════════════════════════════════════════════════════
-- FARM — SELL
-- ══════════════════════════════════════════════════════════════════════════════
local function GetDumpsters()
    local list = {}
    local folder = Workspace:FindFirstChild("Dumpsters")
    if not folder then return list end
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") or m:IsA("BasePart") then
            list[#list + 1] = m
        end
    end
    return list
end

local function NearestDumpsterPos()
    local hrp = GetHRP()
    local best, bestD
    for _, m in ipairs(GetDumpsters()) do
        local pos = m:GetPivot().Position
        local d = hrp and (pos - hrp.Position).Magnitude or 0
        if not bestD or d < bestD then best, bestD = pos, d end
    end
    return best
end

local function SellNow(doTeleport)
    local eb = Remote("EmptyBackpack")
    if not eb then return false, "no remote" end
    if doTeleport then
        local pos = NearestDumpsterPos()
        if pos then TeleportTo(pos) end
    end
    task.wait(0.3)
    local ok = pcall(function() eb:FireServer() end)
    return ok
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ECONOMY — UPGRADES / TOOLS / BAG / VENTS / EQUIP
-- ══════════════════════════════════════════════════════════════════════════════
local UPGRADE_ORDER = {
    { key = "Hand",       names = { "Hold", "Dexterity", "Grasp" } },
    { key = "Rake",       names = { "Radius", "Range", "Stickiness" } },
    { key = "LeafBlower", names = { "Width", "Power", "Spread" } },
}

local function BuildUpgradeOptions()
    local opts = {}
    for _, t in ipairs(UPGRADE_ORDER) do
        for _, n in ipairs(t.names) do
            opts[#opts + 1] = t.key .. " / " .. n
        end
    end
    return opts
end

local function ParseUpgradeOption(opt)
    for _, t in ipairs(UPGRADE_ORDER) do
        for _, n in ipairs(t.names) do
            if opt == (t.key .. " / " .. n) then return t.key, n end
        end
    end
    return nil, nil
end

local function UpgradePrice(toolKey, upgName)
    if not UpgradeConfig then return nil end
    local section = UpgradeConfig.tools and UpgradeConfig.tools[toolKey]
    local upg = section and section.upgrades and section.upgrades[upgName]
    if not upg then return nil end
    local lvl = GetUpgLevel(toolKey, upgName)
    if lvl >= (upg.max or 0) then return nil end
    return upg.prices[lvl + 1]
end

local function BuyUpgradeOnce(toolKey, upgName)
    local price = UpgradePrice(toolKey, upgName)
    if price == nil then return false, "maxed" end
    if GetCash() < price then return false, "poor" end
    return fire("BuyUpgrade", toolKey, upgName)
end

local function AutoUpgradeOnce(prioritySet)
    -- priority order: iterate UPGRADE_ORDER but only buy enabled upgrades
    local bought = false
    for _, t in ipairs(UPGRADE_ORDER) do
        for _, n in ipairs(t.names) do
            if (not prioritySet or prioritySet[t.key .. " / " .. n]) then
                local price = UpgradePrice(t.key, n)
                if price ~= nil and GetCash() >= price then
                    local ok = fire("BuyUpgrade", t.key, n)
                    if ok then bought = true end
                end
            end
        end
    end
    return bought
end

local function BuyBagOnce()
    if not BagConfig then return false, "no config" end
    local prices = BagConfig.prices
    local lvl = 0
    local data = invoke("GetMyData")
    if data and data.Upgrades then
        lvl = tonumber(data.Upgrades.BagCapacity) or 0
    end
    if lvl >= #prices then return false, "maxed" end
    local price = prices[lvl + 1]
    if not price then return false, "maxed" end
    if GetCash() < price then return false, "poor" end
    return fire("BuyBagUpgrade")
end

local TOOL_BUY_ORDER = { "Rake", "LeafBlower", "Molotov" }

local function OwnsTool(key)
    if key == "Rake" then return attr("OwnsRake") == true end
    if key == "LeafBlower" then return attr("OwnsLeafBlower") == true end
    if key == "Molotov" then return attr("OwnsMolotov") == true end
    return false
end

local function BuyToolOnce(key)
    if OwnsTool(key) then return false, "owned" end
    local section = UpgradeConfig and UpgradeConfig.shop and UpgradeConfig.shop[key]
    if not section then return false, "no config" end
    if section.robuxOnly then return false, "robux" end
    local price = section.cash
    if not price or GetCash() < price then return false, "poor" end
    return fire("BuyToolCash", key)
end

local function AutoBuyToolsOnce()
    local bought = false
    for _, key in ipairs(TOOL_BUY_ORDER) do
        local ok = BuyToolOnce(key)
        if ok then bought = true end
    end
    return bought
end

local function AutoBuyVentsOnce()
    local vents = Workspace:FindFirstChild("Vents")
    if not vents then return false end
    local hrp = GetHRP()
    local bought = false
    for _, v in ipairs(vents:GetChildren()) do
        if v:IsA("BasePart") and v:GetAttribute("Cost") ~= nil and not v:GetAttribute("Unlocked") then
            local cost = v:GetAttribute("Cost") or 0
            if GetCash() >= cost and hrp and (v.Position - hrp.Position).Magnitude <= 20 then
                local ok = fire("BuyVent", v)
                if ok then bought = true end
            end
        end
    end
    return bought
end

local function EquipTool(name)
    if name and name ~= "Hand" then
        setAttr("SelectedTool", name)
    else
        setAttr("SelectedTool", "Hand")
    end
    return fire("EquipTool", name ~= "Hand" and name or nil)
end

local function EquipBestOnce()
    -- best owned tool order: LeafVacuum (if owned) > LeafBlower > Rake > Hand
    if attr("OwnsLeafVacuum") == true then return EquipTool("LeafVacuum") end
    if attr("OwnsLeafBlower") == true then return EquipTool("LeafBlower") end
    if attr("OwnsRake") == true then return EquipTool("Rake") end
    return EquipTool("Hand")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- VENT FARM — feed leaves straight into a vent for bag-free cash.
-- Leaves are generated deterministically from ReplicatedStorage.LeafSeed, so we
-- cache (id, position) once and reuse it. VentEat pays directly (no 25-cap).
-- ══════════════════════════════════════════════════════════════════════════════
local leafCache, leafCacheSeed = nil, nil

local function GetLeafCache()
    local seed = ReplicatedStorage:GetAttribute("LeafSeed")
    if not seed then return nil end
    if seed == leafCacheSeed and leafCache then return leafCache end
    local ok, LG = pcall(require, ReplicatedStorage:WaitForChild("LeafGenShared"))
    if not ok or not LG then return nil end
    local cache = {}
    local okg = pcall(function()
        LG.generate(seed, function(id, cf, zone, tpl)
            cache[#cache + 1] = { id = id, pos = cf.Position }
        end)
    end)
    if not okg or #cache == 0 then return nil end
    leafCache, leafCacheSeed = cache, seed
    return cache
end

local function GetNearestVent()
    local vents = Workspace:FindFirstChild("Vents")
    if not vents then return nil end
    local hrp = GetHRP()
    local best, bestD
    for _, v in ipairs(vents:GetChildren()) do
        if v:IsA("BasePart") then
            local d = hrp and (v.Position - hrp.Position).Magnitude or 1e9
            if not bestD or d < bestD then best, bestD = v, d end
        end
    end
    return best
end

-- Buy the nearest still-locked vent when affordable (returns true if bought/unlocked).
local function EnsureVentUnlocked()
    local vents = Workspace:FindFirstChild("Vents")
    if not vents then return false end
    local hrp = GetHRP()
    for _, v in ipairs(vents:GetChildren()) do
        if v:IsA("BasePart") and v:GetAttribute("Cost") ~= nil and not v:GetAttribute("Unlocked") then
            local cost = v:GetAttribute("Cost") or 0
            if GetCash() >= cost and hrp and (v.Position - hrp.Position).Magnitude <= 20 then
                fire("BuyVent", v)
                return true
            end
        end
    end
    return false
end

local function VentFarmOnce(radius, doTeleport, doBuyVent)
    local ven = GetNearestVent()
    if not ven then return 0, "no vent" end
    if doBuyVent then pcall(EnsureVentUnlocked) end
    if doTeleport then
        TeleportTo(ven.Position)
        task.wait(0.3)
    end
    local cache = GetLeafCache()
    if not cache then return 0, "no cache" end
    local LN = require(ReplicatedStorage:WaitForChild("LeafNet"))
    local ids = {}
    local vp = ven.Position
    for _, e in ipairs(cache) do
        if (e.pos - vp).Magnitude <= radius and #ids < 200 then
            ids[#ids + 1] = e.id
        end
    end
    if #ids == 0 then return 0, "empty" end
    local ok = fire("VentEat", LN.packIds(ids, #ids))
    return ok and #ids or 0
end

-- ══════════════════════════════════════════════════════════════════════════════
-- MOVEMENT
-- ══════════════════════════════════════════════════════════════════════════════
local walkSpeed = 16
local flying = false
local flySpeed = 60
local noclip = false
local noclipConn = nil
local infiniteJump = false
local antiAFK = false

local function ApplyWalkSpeed(v)
    walkSpeed = v
    local hum = GetHumanoid()
    if hum then hum.WalkSpeed = v end
end

local function startFly()
    if flying then return end
    local hrp = GetHRP()
    local hum = GetHumanoid()
    if not (hrp and hum) then return end
    flying = true
    -- Anchoring the HRP freezes physics, which is exactly why BodyVelocity
    -- can't move it. Instead we anchor the root part and drive its CFrame
    -- directly each frame — deterministic movement, no physics fighting.
    hrp.Anchored = true
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1, 1, 1) * 1e5
    bodyGyro.P = 1e5
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp
    HUB._fly = { hrp = hrp, gyro = bodyGyro, conn = track(RunService.RenderStepped:Connect(function(dt)
        if not flying then return end
        local cam = Camera
        if not cam then return end
        local look = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector
        -- flatten horizontal axes so W/S stay level; Space/Shift handle height
        local flatLook = Vector3.new(look.X, 0, look.Z)
        flatLook = flatLook.Magnitude > 0.001 and flatLook.Unit or Vector3.new(0, 0, -1)
        local flatRight = Vector3.new(right.X, 0, right.Z)
        flatRight = flatRight.Magnitude > 0.001 and flatRight.Unit or Vector3.new(1, 0, 0)
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + dir.Unit * flySpeed * math.min(dt, 0.1)
        end
        bodyGyro.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + look)
    end)) }
end

local function stopFly()
    flying = false
    local f = HUB._fly
    if f then
        pcall(function() f.conn:Disconnect() end)
        pcall(function() f.hrp.Anchored = false end)
        pcall(function() f.gyro:Destroy() end)
        HUB._fly = nil
    end
end

local function setNoclip(v)
    noclip = v
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    if not v then
        local c = GetCharacter()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
        return
    end
    noclipConn = track(RunService.Stepped:Connect(function()
        local c = GetCharacter()
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end))
end

local function setInfiniteJump(v)
    infiniteJump = v
    local hum = GetHumanoid()
    if not hum then return end
    -- Keep the player in the Jumping state so they can hop endlessly.
    -- pcall-guarded: enum names vary across executors/game versions.
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, not v) end)
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Landed, not v) end)
    hum.JumpPower = 50
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TELEPORT
-- ══════════════════════════════════════════════════════════════════════════════
local function GetZones()
    local list = {}
    local ll = Workspace:FindFirstChild("Leave_Locations")
    if not ll then return list end
    for _, m in ipairs(ll:GetChildren()) do
        if m:IsA("Model") then list[#list + 1] = m end
    end
    return list
end

local function ZonePosition(name)
    local ll = Workspace:FindFirstChild("Leave_Locations")
    local m = ll and ll:FindFirstChild(name)
    if not m then return nil end
    -- prefer a BasePart spawn point inside, else the model pivot
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then return d.Position end
    end
    return m:GetPivot().Position
end

-- ══════════════════════════════════════════════════════════════════════════════
-- EXTRAS — ALL TOOLS / MAX UPGRADES + AUTO RAKE
-- Ported from the standalone snippet: grants every tool + max upgrade via
-- attributes, patches PlayerUpgradeConfig.levelOf / LeafSim.upgEffect, hooks
-- Instance.GetAttribute (namecall) so the game believes you own everything,
-- keeps cooldowns permanently off, and auto-rakes while holding MB1.
-- ══════════════════════════════════════════════════════════════════════════════
local allToolsEnabled = true
local autoRakeEnabled = true
local keepAliveStarted = false
local oldLevelOf, oldUpgEffect
local PlayerUpgradeConfig, PlayerUpgradeConfigErr

local itemAttributes = {
    OwnsRake = true,
    OwnsLeafBlower = true,
    OwnsLeafVacuum = true,
    OwnsMolotov = true,
    PermRake = true,
    PermLeafBlower = true,
    PermLeafVacuum = true,
    PermMolotov = true,
}

local upgradeAttributes = {
    Upg_Hand_Hold = 1,
    Upg_Hand_Dexterity = 5,
    Upg_Hand_Grasp = 5,
    Upg_Rake_Radius = 5,
    Upg_Rake_Range = 4,
    Upg_Rake_Stickiness = 4,
    Upg_LeafBlower_Width = 5,
    Upg_LeafBlower_Power = 4,
    Upg_LeafBlower_Spread = 4,
    LobbyWalkSpeed = 21,
    LobbyBagBonus = 125,
    LobbyCashMult = 1.5,
    LobbyGemsMult = 1.5,
    LobbyRakeDiscount = 1,
    LobbyBlowerDiscount = 1,
}

local cooldownAttributes = {
    HandCooldown = false,
    RakeCooldown = false,
    MolotovCooldown = false,
}

local function EnsureUpgradeConfig()
    if PlayerUpgradeConfig then return true end
    local ok, m = tryRequire(ReplicatedStorage:WaitForChild("PlayerUpgradeConfig"))
    if ok and m then
        PlayerUpgradeConfig = m
        return true
    end
    PlayerUpgradeConfigErr = tostring(m)
    return false
end

-- Set the granted attributes and patch the config modules (idempotent).
local function ApplyAllTools()
    for attr, val in pairs(itemAttributes) do setAttr(attr, val) end
    for attr, val in pairs(upgradeAttributes) do setAttr(attr, val) end
    if EnsureUpgradeConfig() and PlayerUpgradeConfig then
        if not oldLevelOf then oldLevelOf = PlayerUpgradeConfig.levelOf end
        PlayerUpgradeConfig.levelOf = function() return 5 end
    end
    if LeafSim then
        if not oldUpgEffect then oldUpgEffect = LeafSim.upgEffect end
        LeafSim.upgEffect = function(tool, upgrade)
            if tool == "Hand" then
                if upgrade == "Dexterity" then return 0
                elseif upgrade == "Hold" then return 1
                elseif upgrade == "Grasp" then return 6 end
            elseif tool == "Rake" then
                if upgrade == "Range" then return 20
                elseif upgrade == "Radius" then return 6
                elseif upgrade == "Stickiness" then return 160 end
            elseif tool == "LeafBlower" then
                if upgrade == "Width" then return 6
                elseif upgrade == "Power" then return 2.5
                elseif upgrade == "Spread" then return 0.2 end
            end
            return oldUpgEffect and oldUpgEffect(tool, upgrade)
        end
    end
end

-- Hook Instance.GetAttribute so the game sees Owns*/Perm*/Upg_* as granted and
-- cooldowns as off, even before the attributes replicate.
local namecallOld
local function SetupNamecallHook()
    if namecallOld then return end
    local hasHooks = pcall(function()
        return hookmetamethod ~= nil and getnamecallmethod ~= nil
    end)
    if not hasHooks then return end
    local wrap = newcclosure or function(f) return f end
    local ok, old = pcall(hookmetamethod, game, "__namecall", wrap(function(self, ...)
        local method = getnamecallmethod()
        if method == "GetAttribute" and self == LocalPlayer then
            local attrName = ...
            if itemAttributes[attrName] ~= nil then return true end
            if upgradeAttributes[attrName] ~= nil then return upgradeAttributes[attrName] end
            if cooldownAttributes[attrName] ~= nil then return false end
        end
        return namecallOld and namecallOld(self, ...)
    end))
    if ok and old then namecallOld = old end
end

-- Keep the granted attributes pinned and cooldowns permanently false.
local function StartKeepAlive()
    if keepAliveStarted then return end
    keepAliveStarted = true
    for attr, _ in pairs(cooldownAttributes) do
        track(LocalPlayer:GetAttributeChangedSignal(attr):Connect(function()
            if LocalPlayer:GetAttribute(attr) == true then setAttr(attr, false) end
        end))
    end
    for attr, val in pairs(itemAttributes) do
        track(LocalPlayer:GetAttributeChangedSignal(attr):Connect(function()
            if LocalPlayer:GetAttribute(attr) ~= val then setAttr(attr, val) end
        end))
    end
    for attr, val in pairs(upgradeAttributes) do
        track(LocalPlayer:GetAttributeChangedSignal(attr):Connect(function()
            if LocalPlayer:GetAttribute(attr) ~= val then setAttr(attr, val) end
        end))
    end
end

-- Auto-rake: while MB1 is held with the Rake selected, rake where the camera
-- points every 0.08s (instant, no charge-up).
local rakeHolding = false
local rakeRayParams = RaycastParams.new()
rakeRayParams.FilterType = Enum.RaycastFilterType.Exclude
rakeRayParams.IgnoreWater = true

local function RakeAimPos()
    local cam = Camera
    local hrp = GetHRP()
    if not (cam and hrp) then return nil end
    rakeRayParams.FilterDescendantsInstances = { GetCharacter() }
    local result = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 50, rakeRayParams)
    return result and result.Position or hrp.Position + cam.CFrame.LookVector * 10
end

local function InstantRake()
    if not LeafSim then return end
    local aim = RakeAimPos()
    if not aim then return end
    pcall(function()
        local okS, SC = tryRequire(ReplicatedStorage:WaitForChild("SoundController"))
        if okS and SC and SC.play then SC.play("RakeSFX") end
    end)
    pcall(function() LeafSim.rake(aim) end)
end

local function StartAutoRake()
    track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            rakeHolding = true
            task.spawn(function()
                while rakeHolding and not HUB.dead and autoRakeEnabled do
                    if (LocalPlayer:GetAttribute("SelectedTool") or "Hand") == "Rake"
                        and not LocalPlayer:GetAttribute("JournalOpen")
                        and not LocalPlayer:GetAttribute("ToolShopFocus") then
                        pcall(InstantRake)
                        task.wait(0.08)
                    else
                        break
                    end
                end
            end)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            rakeHolding = false
        end
    end))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- UI — TABS
-- ══════════════════════════════════════════════════════════════════════════════
local FarmTab = Window:AddTab({ Name = "Farm", Subtitle = "Collect & sell leaves", Icon = "backpack" })
local EconomyTab = Window:AddTab({ Name = "Economy", Subtitle = "Upgrades, tools & vents", Icon = "coin" })
local PlayerTab = Window:AddTab({ Name = "Player", Subtitle = "Movement & teleport", Icon = "move" })
local SettingsTab = Window:AddTab({ Name = "Settings", Subtitle = "Config", Icon = "settings" })

-- ── FARM / COLLECT ─────────────────────────────────────────────────────────
local CollectSub = FarmTab:AddSubTab("Collect")

local collectEnabled = false
local collectRadius = 12
local collectGap = 0.15
local collectOnlyRun = false

CollectSub:AddToggle({
    Name = "Auto Collect", Default = false, Flag = "collect_auto",
    Callback = safeCallback(function(v)
        collectEnabled = v
        Notify("Auto Collect", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
CollectSub:AddSlider({ Name = "Collect Radius", Min = 4, Max = 60, Default = 12, Suffix = " studs", Flag = "collect_radius", Callback = function(v) collectRadius = v end })
CollectSub:AddSlider({ Name = "Collect Gap", Min = 0.05, Max = 2, Default = 0.15, Suffix = "s", Flag = "collect_gap", Callback = function(v) collectGap = v end })
CollectSub:AddToggle({ Name = "Only During Run", Default = false, Flag = "collect_runonly", Callback = function(v) collectOnlyRun = v end })
CollectSub:AddButton({
    Name = "Collect Once", Primary = true,
    Callback = safeCallback(function()
        local n = CollectNearby(collectRadius)
        Notify("Collect", n > 0 and ("Collected " .. n .. " leaves") or "Nothing in range", n > 0 and "Success" or "Info")
    end),
})

-- ── FARM / SELL ────────────────────────────────────────────────────────────
local SellSub = FarmTab:AddSubTab("Sell")

local sellEnabled = false
local sellThreshold = 90
local sellGap = 2
local sellTeleport = true

SellSub:AddToggle({
    Name = "Auto Sell", Default = false, Flag = "sell_auto",
    Callback = safeCallback(function(v)
        sellEnabled = v
        Notify("Auto Sell", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
SellSub:AddSlider({ Name = "Sell When Bag Full", Min = 25, Max = 100, Default = 90, Suffix = " %", Flag = "sell_threshold", Callback = function(v) sellThreshold = v end })
SellSub:AddSlider({ Name = "Sell Gap", Min = 0.5, Max = 20, Default = 2, Suffix = "s", Flag = "sell_gap", Callback = function(v) sellGap = v end })
SellSub:AddToggle({ Name = "Teleport To Dumpster", Default = true, Flag = "sell_teleport", Callback = function(v) sellTeleport = v end })
SellSub:AddButton({
    Name = "Sell Now", Primary = true,
    Callback = safeCallback(function()
        local ok = SellNow(sellTeleport)
        Notify("Sell", ok and "Backpack emptied" or "Sell failed", ok and "Success" or "Error")
    end),
})

-- ── FARM / VENT FARM ───────────────────────────────────────────────────────
local VentSub = FarmTab:AddSubTab("Vent Farm")

local ventFarmEnabled = false
local ventFarmRadius = 8
local ventFarmGap = 1.5
local ventFarmTeleport = true
local ventFarmBuy = true

VentSub:AddToggle({
    Name = "Auto Vent Farm", Default = false, Flag = "vent_auto",
    Callback = safeCallback(function(v)
        ventFarmEnabled = v
        Notify("Vent Farm", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
VentSub:AddSlider({ Name = "Vent Radius", Min = 4, Max = 20, Default = 8, Suffix = " studs", Flag = "vent_radius", Callback = function(v) ventFarmRadius = v end })
VentSub:AddSlider({ Name = "Vent Gap", Min = 0.5, Max = 10, Default = 1.5, Suffix = "s", Flag = "vent_gap", Callback = function(v) ventFarmGap = v end })
VentSub:AddToggle({ Name = "Teleport To Vent", Default = true, Flag = "vent_teleport", Callback = function(v) ventFarmTeleport = v end })
VentSub:AddToggle({ Name = "Auto Buy Vent", Default = true, Flag = "vent_buy", Callback = function(v) ventFarmBuy = v end })
VentSub:AddButton({
    Name = "Vent Farm Once", Primary = true,
    Callback = safeCallback(function()
        local n = VentFarmOnce(ventFarmRadius, ventFarmTeleport, ventFarmBuy)
        Notify("Vent Farm", n > 0 and ("Fed " .. n .. " leaves") or "No leaves near vent", n > 0 and "Success" or "Info")
    end),
})

-- ── ECONOMY / UPGRADES ─────────────────────────────────────────────────────
local UpgradesSub = EconomyTab:AddSubTab("Upgrades")

local upgradeEnabled = false
local upgradeGap = 1.5
local upgradePriority = {}

do
    local opts = BuildUpgradeOptions()
    local function setPriority(list)
        upgradePriority = {}
        for _, opt in ipairs(list or {}) do upgradePriority[opt] = true end
    end
    local dd = UpgradesSub:AddMultiDropdown({
        Name = "Upgrade Priority (empty = all)", Options = opts, Default = {},
        MaxVisible = 8, Searchable = true, Flag = "upg_priority",
        Callback = setPriority,
    })
    registerResync(dd, setPriority)
end
UpgradesSub:AddToggle({
    Name = "Auto Upgrade", Default = false, Flag = "upg_auto",
    Callback = safeCallback(function(v)
        upgradeEnabled = v
        Notify("Auto Upgrade", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
UpgradesSub:AddSlider({ Name = "Upgrade Gap", Min = 0.2, Max = 10, Default = 1.5, Suffix = "s", Flag = "upg_gap", Callback = function(v) upgradeGap = v end })
UpgradesSub:AddButton({
    Name = "Buy All Now", Primary = true,
    Callback = safeCallback(function()
        local bought = AutoUpgradeOnce(nil)
        Notify("Upgrades", bought and "Bought upgrades" or "Nothing affordable", bought and "Success" or "Info")
    end),
})

-- ── ECONOMY / TOOLS ────────────────────────────────────────────────────────
local ToolsSub = EconomyTab:AddSubTab("Tools & Bag")

local autoBag = false
local autoTools = false
local autoVents = false
local autoEquip = false

ToolsSub:AddToggle({ Name = "Auto Buy Bag Upgrade", Default = false, Flag = "buy_bag", Callback = function(v) autoBag = v end })
ToolsSub:AddToggle({ Name = "Auto Buy Tools", Default = false, Flag = "buy_tools", Callback = function(v) autoTools = v end })
ToolsSub:AddToggle({ Name = "Auto Buy Vents", Default = false, Flag = "buy_vents", Callback = function(v) autoVents = v end })
ToolsSub:AddToggle({ Name = "Auto Equip Best Tool", Default = false, Flag = "auto_equip", Callback = function(v) autoEquip = v end })
ToolsSub:AddButton({ Name = "Buy Rake ($7.99)", Callback = safeCallback(function() local ok, why = BuyToolOnce("Rake"); Notify("Tool", ok and "Rake bought" or tostring(why), ok and "Success" or "Info") end) })
ToolsSub:AddButton({ Name = "Buy Leaf Blower ($29.99)", Callback = safeCallback(function() local ok, why = BuyToolOnce("LeafBlower"); Notify("Tool", ok and "Blower bought" or tostring(why), ok and "Success" or "Info") end) })
ToolsSub:AddButton({ Name = "Buy Molotov ($100)", Callback = safeCallback(function() local ok, why = BuyToolOnce("Molotov"); Notify("Tool", ok and "Molotov bought" or tostring(why), ok and "Success" or "Info") end) })
ToolsSub:AddButton({ Name = "Buy Bag Upgrade", Callback = safeCallback(function() local ok, why = BuyBagOnce(); Notify("Bag", ok and "Bag upgraded" or tostring(why), ok and "Success" or "Info") end) })

-- ── PLAYER / MOVEMENT ──────────────────────────────────────────────────────
local MovementSub = PlayerTab:AddSubTab("Movement")

MovementSub:AddSlider({ Name = "WalkSpeed", Min = 16, Max = 300, Default = 16, Suffix = "", Flag = "walkspeed", Callback = function(v) ApplyWalkSpeed(v) end })
MovementSub:AddToggle({
    Name = "Fly", Default = false, Flag = "fly",
    Callback = safeCallback(function(v)
        if v then startFly() else stopFly() end
        Notify("Fly", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end),
})
MovementSub:AddSlider({ Name = "Fly Speed", Min = 10, Max = 300, Default = 60, Suffix = "", Flag = "flyspeed", Callback = function(v) flySpeed = v end })
MovementSub:AddToggle({ Name = "Noclip", Default = false, Flag = "noclip", Callback = function(v) setNoclip(v) end })
MovementSub:AddToggle({ Name = "Infinite Jump", Default = false, Flag = "infjump", Callback = function(v) setInfiniteJump(v) end })
MovementSub:AddToggle({ Name = "Anti-AFK", Default = false, Flag = "antiafk", Callback = function(v) antiAFK = v end })

-- ── PLAYER / TELEPORT ──────────────────────────────────────────────────────
local TeleportSub = PlayerTab:AddSubTab("Teleport")

do
    local zoneOpts = {}
    for _, m in ipairs(GetZones()) do zoneOpts[#zoneOpts + 1] = m.Name end
    table.sort(zoneOpts)
    local selectedZone = zoneOpts[1]
    local dd = TeleportSub:AddDropdown({
        Name = "Zone", Options = zoneOpts, Default = selectedZone,
        Flag = "tp_zone", Callback = function(v) selectedZone = v end,
    })
    TeleportSub:AddButton({
        Name = "Teleport To Zone",
        Callback = safeCallback(function()
            local pos = ZonePosition(selectedZone)
            if pos then TeleportTo(pos); Notify("Teleport", "At " .. selectedZone, "Success") end
        end),
    })
end
TeleportSub:AddButton({
    Name = "Teleport To Dumpster",
    Callback = safeCallback(function()
        local pos = NearestDumpsterPos()
        if pos then TeleportTo(pos); Notify("Teleport", "At dumpster", "Success") end
    end),
})
TeleportSub:AddButton({
    Name = "Teleport To Nearest Vent",
    Callback = safeCallback(function()
        local vents = Workspace:FindFirstChild("Vents")
        local hrp = GetHRP()
        local best, bestD
        if vents and hrp then
            for _, v in ipairs(vents:GetChildren()) do
                if v:IsA("BasePart") then
                    local d = (v.Position - hrp.Position).Magnitude
                    if not bestD or d < bestD then best, bestD = v.Position, d end
                end
            end
        end
        if best then TeleportTo(best); Notify("Teleport", "At vent", "Success") end
    end),
})
TeleportSub:AddButton({
    Name = "Teleport To Player",
    Callback = safeCallback(function()
        local target
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                target = p
                break
            end
        end
        if target then
            local pos = target.Character:FindFirstChild("HumanoidRootPart").Position
            TeleportTo(pos)
            Notify("Teleport", "At " .. target.Name, "Success")
        else
            Notify("Teleport", "No other players", "Info")
        end
    end),
})

-- ── EXTRAS / ALL TOOLS ─────────────────────────────────────────────────────
local ExtrasTab = Window:AddTab({ Name = "Extras", Subtitle = "All tools, max upgrades & auto rake", Icon = "star" })
local ExtrasSub = ExtrasTab:AddSubTab("All Tools")

ExtrasSub:AddToggle({
    Name = "All Tools & Max Upgrades", Default = true, Flag = "extras_alltools",
    Callback = safeCallback(function(v)
        allToolsEnabled = v
        if v then
            pcall(ApplyAllTools)
            SetupNamecallHook()
            StartKeepAlive()
            Notify("Extras", "All tools & upgrades applied", "Success")
        else
            Notify("Extras", "Disabled", "Info")
        end
    end),
})
ExtrasSub:AddToggle({
    Name = "Auto Rake (hold MB1)", Default = true, Flag = "extras_autorage",
    Callback = function(v)
        autoRakeEnabled = v
        if not v then rakeHolding = false end
    end,
})

-- ── SETTINGS ───────────────────────────────────────────────────────────────
local ConfigSub = SettingsTab:AddSubTab("Config")

ConfigSub:AddButton({
    Name = "Save Config",
    Callback = safeCallback(function()
        if HAS_CONFIG then
            Library:SaveConfig(CONFIG_NAME)
            Notify("Config", "Saved", "Success")
        else
            Notify("Config", "Not supported", "Error")
        end
    end),
})
ConfigSub:AddButton({
    Name = "Load Config",
    Callback = safeCallback(function()
        if HAS_CONFIG then
            Library:LoadConfig(CONFIG_NAME)
            ResyncAll()
            Notify("Config", "Loaded", "Success")
        else
            Notify("Config", "Not supported", "Error")
        end
    end),
})

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG PERSISTENCE
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
        if collectEnabled and (not collectOnlyRun or IsInRun()) then
            pcall(function() CollectNearby(collectRadius) end)
        end
        task.wait(collectGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if sellEnabled then
            local cap = GetCapacity()
            if cap <= 0 then cap = 25 end
            local leaves = GetLeaves()
            if (not GetInfinite()) and cap > 0 and (leaves / cap) * 100 >= sellThreshold then
                pcall(function() SellNow(sellTeleport) end)
            end
        end
        task.wait(sellGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if ventFarmEnabled then
            pcall(function() VentFarmOnce(ventFarmRadius, ventFarmTeleport, ventFarmBuy) end)
        end
        task.wait(ventFarmGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if upgradeEnabled then
            local prio = (next(upgradePriority) ~= nil) and upgradePriority or nil
            pcall(function() AutoUpgradeOnce(prio) end)
        end
        task.wait(upgradeGap)
    end
end)

task.spawn(function()
    while not HUB.dead do
        -- Bag upgrade first: it raises the 25-cap toward 1000 and is the best
        -- cash investment, so always try it before tools/vents.
        if autoBag then pcall(function() BuyBagOnce() end) end
        if autoTools then pcall(AutoBuyToolsOnce) end
        if autoVents then pcall(AutoBuyVentsOnce) end
        task.wait(3)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if autoEquip then pcall(EquipBestOnce) end
        task.wait(5)
    end
end)

task.spawn(function()
    while not HUB.dead do
        if antiAFK then
            local vus = game:GetService("VirtualUser")
            vus:CaptureController()
            vus:ClickButton2(Vector2.new())
        end
        task.wait(60)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- GAME API INIT
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
    Notify("Oxide HUB", "Game API unavailable (" .. tostring(LeafSimErr or "?") .. ")", "Error", 4)
end

-- Extras are enabled by default: apply the buffs + hooks as soon as the game
-- API is up (LeafSim is needed for the upgEffect patch).
if allToolsEnabled then
    pcall(ApplyAllTools)
    SetupNamecallHook()
    StartKeepAlive()
end
StartAutoRake()

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
    if flying then stopFly() end
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    rakeHolding = false
    -- restore patched game modules + unhook GetAttribute
    if PlayerUpgradeConfig and oldLevelOf then
        pcall(function() PlayerUpgradeConfig.levelOf = oldLevelOf end)
    end
    if LeafSim and oldUpgEffect then
        pcall(function() LeafSim.upgEffect = oldUpgEffect end)
    end
    if namecallOld then
        pcall(function() hookmetamethod(game, "__namecall", namecallOld) end)
        namecallOld = nil
    end
    if HAS_CONFIG then pcall(function() Library:SaveConfig(CONFIG_NAME) end) end
    pcall(function()
        if Window and Window.Destroy then Window:Destroy() end
    end)
    _G.OxideLeafSim = nil
end

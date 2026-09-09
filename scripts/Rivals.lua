-- ═══ HUB STRIP POINT — when executed through the hub ScriptLoader, which injects
--     "local Library = _G.OxideLib" above this line instead. ═══
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- RE-EXECUTION GUARD + RESOURCE TRACKING
-- ══════════════════════════════════════════════════════════════════════════════
do
    local prev = _G.OxideRivals
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, drawings = {}, highlights = {}, dead = false }
_G.OxideRivals = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end
local function trackDrawing(d) if d then table.insert(HUB.drawings, d) end; return d end

local Window = Library:CreateWindow({
    Name = "Oxide HUB | RIVALS",
    LoadingAnimation = true,
    LoadingText = "Oxide",
    LoadingDuration = 2.2,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG / FLAG PERSISTENCE (guarded)
-- ══════════════════════════════════════════════════════════════════════════════
local HAS_CONFIG = type(Library.SaveConfig) == "function"
    and type(Library.LoadConfig) == "function"
    and type(Library.ListConfigs) == "function"
local CONFIG_NAME = "rivals"

local dropdownResync = {}
local function registerResync(handle, applyFn)
    if handle and applyFn then table.insert(dropdownResync, function() applyFn(handle:Get()) end) end
end
local function ResyncAll()
    for _, fn in ipairs(dropdownResync) do pcall(fn) end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SERVICES / LOCALS
-- ══════════════════════════════════════════════════════════════════════════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local hasDrawing = (typeof(Drawing) == "table") or (Drawing ~= nil and pcall(function() return Drawing.new end))

local function Notify(title, content, kind, dur)
    Window:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = dur or 2.5 })
end

-- RIVALS module handles (verified live). Everything is pcall-guarded so the
-- hub still loads if the game updates a path.
local reps = ReplicatedStorage
local U, GU, EL, GunMod
local UseItem
local enumStartShooting
do
    local ok, u = pcall(require, reps.Modules.Utility)
    if ok then U = u end
    local ok2, gu = pcall(require, reps.Modules.GameplayUtility)
    if ok2 then GU = gu end
    local ok3, el = pcall(require, reps.Modules.EnumLibrary)
    if ok3 then EL = el end
    local ok4, gun = pcall(require, LocalPlayer.PlayerScripts.Modules.ItemTypes.Gun)
    if ok4 then GunMod = gun end
    local fighter = reps.Remotes and reps.Remotes.Replication and reps.Remotes.Replication.Fighter
    if fighter then UseItem = fighter:FindFirstChild("UseItem") end
    if EL and type(EL.ToEnum) == "function" then
        local ok5, v = pcall(EL.ToEnum, EL, "StartShooting")
        if ok5 then enumStartShooting = v end
    end
end

local function newDrawing(class, props)
    if not hasDrawing then return nil end
    local ok, d = pcall(function() return Drawing.new(class) end)
    if not ok or not d then return nil end
    for k, v in pairs(props or {}) do pcall(function() d[k] = v end) end
    return trackDrawing(d)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- RAGE TAB CONFIG
-- ══════════════════════════════════════════════════════════════════════════════
local rage = {
    enabled = false,
    fireDelayMs = 1, -- fire rate slider is integer ms; 1 = 1ms
    weaponSlot = "Melee", -- Primary / Secondary / Melee
    hitPart = "Head", -- Head / Torso / Random
    maxDist = 500,
    teamCheck = true,
    deflectCheck = true,
    desync = true,
    knifeAdjust = true,
    randomOffset = true,
    priority = "Lowest HP", -- Lowest HP / Closest
    autoShoot = false, -- fire even without holding LMB
    prediction = false,
    bulletSpeed = 350,
    burst = 1,
    lowHPPrio = false,
    lowHPThreshold = 60,
    wallCheck = false,
}

-- ── No Spread ───────────────────────────────────────────────────────────
local noSpreadEnabled = false
local origIsFullyAiming
local function ApplyNoSpread(on)
    if on then
        if GunMod and type(GunMod.IsFullyAiming) == "function" then
            if not origIsFullyAiming then origIsFullyAiming = GunMod.IsFullyAiming end
            GunMod.IsFullyAiming = function() return true end
        end
    else
        if origIsFullyAiming then
            pcall(function() GunMod.IsFullyAiming = origIsFullyAiming end)
            origIsFullyAiming = nil
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- RAGE TAB (Ragebot — desync auto-fire)
-- ══════════════════════════════════════════════════════════════════════════════
local RageTab = Window:AddTab({ Name = "Rage", Subtitle = "Ragebot & combat", Icon = "bolt" })

-- No Spread (combat patch, lives on the Rage tab)
local NoSpreadSub = RageTab:AddSubTab("No Spread")
NoSpreadSub:AddSection("No Spread")
NoSpreadSub:AddToggle({
    Name = "No Spread", Default = false, Flag = "rv_nospread",
    Callback = function(v)
        noSpreadEnabled = v
        ApplyNoSpread(v)
        Notify("Rage", v and "No Spread ON" or "No Spread OFF", v and "Success" or "Error")
    end,
})
NoSpreadSub:AddParagraph({
    Title = "Note",
    Text = "Forces Gun.IsFullyAiming to always return true for perfect accuracy.",
})

-- cloneref'd services (anti-cheat safe). Fall back to plain services if the
-- executor has no cloneref.
local function CloneSvc(svc)
    if type(cloneref) == "function" then
        local ok, c = pcall(cloneref, svc)
        if ok and c then return c end
    end
    return svc
end
local repS  = CloneSvc(ReplicatedStorage)
local plrsR = CloneSvc(Players)
local runSR = CloneSvc(RunService)
local wsR   = CloneSvc(Workspace)
local uisR  = CloneSvc(UserInputService)

-- Controllers used by the ragebot (guarded so the hub still loads if a path changes)
local FighterController, SpectateController
local RageUtil, RageEnum
local UseItemR
local rageReady = false
do
    local ok1, fc = pcall(require, LocalPlayer.PlayerScripts.Controllers.FighterController)
    if ok1 then FighterController = fc end
    local ok2, sc = pcall(require, LocalPlayer.PlayerScripts.Controllers:WaitForChild("SpectateController"))
    if ok2 then SpectateController = sc end
    local ok3, u = pcall(require, repS.Modules.Utility)
    if ok3 then RageUtil = u end
    local ok4, el = pcall(require, repS.Modules.EnumLibrary)
    if ok4 then RageEnum = el end
    local fighter = repS.Remotes and repS.Remotes.Replication and repS.Remotes.Replication.Fighter
    if fighter then UseItemR = fighter:FindFirstChild("UseItem") end
    rageReady = FighterController ~= nil and SpectateController ~= nil
        and RageUtil ~= nil and RageEnum ~= nil and UseItemR ~= nil
end

local SLOT_NUM = { Primary = 1, Secondary = 2, Melee = 3 }

-- Equip keep-alive: keeps the chosen slot equipped while the ragebot is on
local equipLoopAlive = true
local equipThread = task.spawn(function()
    while equipLoopAlive do
        task.wait(1)
        if rage.enabled and FighterController then
            local lf = FighterController.LocalFighter
            if lf then
                pcall(function() lf:EquipItem(SLOT_NUM[rage.weaponSlot] or 3) end)
            end
        end
    end
end)

-- Deflection tracking (katana parry awareness)
local deflecting = {}
local playerRemoveConn = plrsR.PlayerRemoving:Connect(function(player)
    deflecting[player] = nil
end)
table.insert(HUB.conns, playerRemoveConn)

local function UpdateDeflection()
    if not FighterController or not FighterController.Objects then return end
    for _, fighterObj in FighterController.Objects do
        local player = fighterObj.Player
        if player then
            if not fighterObj.Entity or not fighterObj.Entity:IsAlive() or fighterObj:Get("IsSpectating") then
                deflecting[player] = false
            else
                local equipped = fighterObj.EquippedItem
                local isKatana = equipped and equipped.ViewModel and equipped.ViewModel.Name == "Katana"
                local isDeflecting = false
                if isKatana then
                    isDeflecting = (equipped._attack_cooldown and equipped._attack_cooldown > tick()) or false
                end
                deflecting[player] = isDeflecting
            end
        end
    end
end

local function IsEnemyR(player)
    if player == LocalPlayer then return false end
    if not rage.teamCheck then return true end
    -- Duel-based team resolution
    if SpectateController and SpectateController.CurrentDuelSubject then
        local duel = SpectateController.CurrentDuelSubject
        local localDueler = duel and duel:GetDueler(LocalPlayer)
        local localTeam = localDueler and localDueler:Get("TeamID") or nil
        if localTeam and duel and duel.Duelers then
            for _, dueler in duel.Duelers do
                if dueler.Player == player then
                    local team = dueler:Get("TeamID")
                    return team ~= localTeam
                end
            end
        end
    end
    local pTeam = player:GetAttribute("TeamID")
    local lTeam = LocalPlayer:GetAttribute("TeamID")
    if pTeam and lTeam then
        return pTeam ~= lTeam
    end
    return true
end

local function GetClosestTargetR()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil, nil, nil end
    local closestPlayer, closestRoot, closestHead
    local closestDist = rage.maxDist
    local lowHPP, lowHPRoot, lowHPHead, lowHPHp = nil, nil, nil, math.huge
    for _, player in plrsR:GetPlayers() do
        if IsEnemyR(player) then
            local pChar = player.Character
            if pChar then
                local pRoot = pChar:FindFirstChild("HumanoidRootPart")
                local pHead = pChar:FindFirstChild("Head")
                local pHum = pChar:FindFirstChildOfClass("Humanoid")
                if pRoot and pHead and pHum and pHum.Health > 0 then
                    local dist = (myRoot.Position - pRoot.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestPlayer = player
                        closestRoot = pRoot
                        closestHead = pHead
                    end
                    if rage.lowHPPrio or rage.priority == "Lowest HP" then
                        if pHum.Health < lowHPHp then
                            lowHPHp = pHum.Health
                            lowHPP = player
                            lowHPRoot = pRoot
                            lowHPHead = pHead
                        end
                    end
                end
            end
        end
    end
    if rage.priority == "Lowest HP" and lowHPP then
        if rage.lowHPPrio then
            if lowHPHp < rage.lowHPThreshold then
                return lowHPP, lowHPRoot, lowHPHead
            end
        else
            return lowHPP, lowHPRoot, lowHPHead
        end
    end
    return closestPlayer, closestRoot, closestHead
end

local function HasKnifeViewModel(targetPlayer)
    if not targetPlayer then return false end
    local viewModels = wsR:FindFirstChild("ViewModels")
    if not viewModels then return false end
    local targetName = targetPlayer.Name
    for _, model in viewModels:GetChildren() do
        if model:IsA("Model")
            and string.find(model.Name, targetName, 1, true)
            and string.find(model.Name, "Knife", 1, true) then
            return true
        end
    end
    return false
end

local lastFire = 0
local function RageFireDelay()
    return math.max(rage.fireDelayMs, 0.5) / 1000
end
local rageConn = runSR.Heartbeat:Connect(function()
    if HUB.dead then return end
    if not rage.enabled then
        -- keep deflection map fresh anyway (cheap) but skip everything else
        return
    end
    UpdateDeflection()
    local targetPlayer, targetRoot, targetHead = GetClosestTargetR()
    local desyncCF = nil

    if rage.desync and targetRoot and targetHead then
        local desyncPos
        if rage.knifeAdjust and HasKnifeViewModel(targetPlayer) then
            desyncPos = (targetRoot.CFrame * CFrame.new(0, 6, 0)).Position
        else
            desyncPos = (targetRoot.CFrame * CFrame.new(0, 1, 2)).Position
        end
        desyncCF = CFrame.lookAt(desyncPos, targetHead.Position)
    end

    if rage.desync and desyncCF and LocalPlayer.Character then
        local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            local oldCF = myRoot.CFrame
            local oldVel = myRoot.Velocity
            local oldRotVel = myRoot.RotVelocity
            myRoot.CFrame = desyncCF
            runSR:BindToRenderStep("OxideRageRestore", 101, function()
                if myRoot and myRoot.Parent then
                    myRoot.CFrame = oldCF
                    myRoot.Velocity = oldVel
                    myRoot.RotVelocity = oldRotVel
                end
                runSR:UnbindFromRenderStep("OxideRageRestore")
            end)
        end
    end

    if not targetPlayer or not targetHead or not targetRoot then return end
    if rage.deflectCheck and deflecting[targetPlayer] then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    if not FighterController or not FighterController.LocalFighter then return end
    local item = FighterController.LocalFighter.EquippedItem
    if not item then return end
    -- optional wall check: don't shoot targets behind cover
    if rage.wallCheck and targetHead then
        local myHead = LocalPlayer.Character:FindFirstChild("Head")
        if myHead then
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { LocalPlayer.Character }
            local dir = targetHead.Position - myHead.Position
            local result = workspace:Raycast(myHead.Position, dir, rayParams)
            if result and result.Instance then
                local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
                if hitChar ~= targetPlayer.Character then return end
            end
        end
    end
    -- auto-shoot: fire even without holding LMB; otherwise require the button
    if not rage.autoShoot then
        local holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        if not holding then return end
    end

    -- pick the hit part (Head / Torso / Random)
    local hitPart = targetHead
    if rage.hitPart == "Torso" then
        hitPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart") or targetPlayer.Character:FindFirstChild("Torso") or targetHead
    elseif rage.hitPart == "Random" then
        local roll = math.random(1, 3)
        if roll == 1 then
            hitPart = targetHead
        else
            hitPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart") or targetPlayer.Character:FindFirstChild("Torso") or targetHead
        end
    end

    local burstCount = math.max(1, math.floor(rage.burst or 1))
    for _ = 1, burstCount do
        if tick() - lastFire < RageFireDelay() then return end
        lastFire = tick()

        local originPos = desyncCF and desyncCF.Position or targetRoot.Position
        local targetPos = hitPart.Position
        if rage.prediction then
            local pRootVel = targetRoot.Velocity
            if pRootVel and pRootVel.Magnitude > 0.5 then
                local distToT = (originPos - targetPos).Magnitude
                local travelTime = distToT / math.max(rage.bulletSpeed, 50)
                targetPos = targetPos + pRootVel * travelTime
            end
        end
        local aimCF = CFrame.lookAt(originPos, targetPos)
        local targetCF = hitPart.CFrame
        local aimedPos = targetPos
        if rage.randomOffset then
            aimedPos = targetPos + Vector3.new(
                (math.random() - 0.5) * 0.1,
                (math.random() - 0.5) * 0.1,
                (math.random() - 0.5) * 0.1
            )
        end
        local objSpaceHeadOffset = hitPart.CFrame:ToObjectSpace(CFrame.new(aimedPos))
        local cameradata = {}
        cameradata[utf8.char(1)] = {
            [utf8.char(0)] = RageUtil:EncodeCFrame(aimCF),
            [utf8.char(1)] = RageUtil:EncodeCFrame(targetCF),
            [utf8.char(2)] = hitPart,
            [utf8.char(3)] = RageUtil:EncodeCFrame(objSpaceHeadOffset),
        }
        local okFire, errFire = pcall(function()
            UseItemR:FireServer(
                item:Get("ObjectID"),
                RageEnum:ToEnum("StartShooting"),
                cameradata,
                nil
            )
        end)
        if not okFire then return end
    end
end)
table.insert(HUB.conns, rageConn)

-- ── Rage UI ───────────────────────────────────────────────────────────────
local RageSub = RageTab:AddSubTab("Ragebot")
RageSub:AddSection("Ragebot")
RageSub:AddToggle({
    Name = "Ragebot", Default = false, Flag = "rv_rage",
    Callback = function(v)
        rage.enabled = v
        if v and not rageReady then
            Notify("Rage", "Controllers/modules not found — ragebot unavailable", "Error", 3.5)
        else
            Notify("Rage", v and "Ragebot ON" or "Ragebot OFF", v and "Success" or "Error")
        end
    end,
})
local applyWeaponSlot = function(v) rage.weaponSlot = v end
local weaponSlotDropdown = RageSub:AddDropdown({
    Name = "Weapon Slot", Options = { "Primary", "Secondary", "Melee" }, Default = "Melee",
    MaxVisible = 3, Flag = "rv_rage_slot", Callback = applyWeaponSlot,
})
registerResync(weaponSlotDropdown, applyWeaponSlot)
RageSub:AddSlider({
    Name = "Fire Rate", Min = 1, Max = 50, Default = 1, Suffix = "ms", Flag = "rv_rage_firerate",
    Callback = function(v) rage.fireDelayMs = v end,
})
RageSub:AddSlider({
    Name = "Max Distance", Min = 50, Max = 2000, Default = 500, Suffix = "", Flag = "rv_rage_dist",
    Callback = function(v) rage.maxDist = v end,
})
local applyHitPart = function(v) rage.hitPart = v end
local hitPartDropdown = RageSub:AddDropdown({
    Name = "Hit Part", Options = { "Head", "Torso", "Random" }, Default = "Head",
    MaxVisible = 3, Flag = "rv_rage_hitpart", Callback = applyHitPart,
})
registerResync(hitPartDropdown, applyHitPart)
local applyPriority = function(v) rage.priority = v end
local priorityDropdown = RageSub:AddDropdown({
    Name = "Target Priority", Options = { "Lowest HP", "Closest" }, Default = "Lowest HP",
    MaxVisible = 2, Flag = "rv_rage_priority", Callback = applyPriority,
})
registerResync(priorityDropdown, applyPriority)
RageSub:AddToggle({
    Name = "Team Check", Default = true, Flag = "rv_rage_team",
    Callback = function(v) rage.teamCheck = v end,
})
RageSub:AddToggle({
    Name = "Deflect Check", Default = true, Flag = "rv_rage_deflect",
    Callback = function(v) rage.deflectCheck = v end,
})
RageSub:AddToggle({
    Name = "Random Offset", Default = true, Flag = "rv_rage_offset",
    Callback = function(v) rage.randomOffset = v end,
})
RageSub:AddToggle({
    Name = "Auto Shoot", Default = false, Flag = "rv_rage_autoshoot",
    Callback = function(v) rage.autoShoot = v end,
})
RageSub:AddToggle({
    Name = "Wall Check", Default = false, Flag = "rv_rage_wallcheck",
    Callback = function(v) rage.wallCheck = v end,
})
RageSub:AddSlider({
    Name = "Burst Shots", Min = 1, Max = 10, Default = 1, Suffix = "", Flag = "rv_rage_burst",
    Callback = function(v) rage.burst = v end,
})
RageSub:AddToggle({
    Name = "Prediction", Default = false, Flag = "rv_rage_pred",
    Callback = function(v) rage.prediction = v end,
})
RageSub:AddSlider({
    Name = "Bullet Speed", Min = 100, Max = 1500, Default = 350, Suffix = "", Flag = "rv_rage_bulletspeed",
    Callback = function(v) rage.bulletSpeed = v end,
})
RageSub:AddToggle({
    Name = "Low HP Only (below threshold)", Default = false, Flag = "rv_rage_lowhp",
    Callback = function(v) rage.lowHPPrio = v end,
})
RageSub:AddSlider({
    Name = "Low HP Threshold", Min = 10, Max = 100, Default = 60, Suffix = "", Flag = "rv_rage_lowhpthresh",
    Callback = function(v) rage.lowHPThreshold = v end,
})

local DesyncSub = RageTab:AddSubTab("Desync")
DesyncSub:AddSection("Desync")
DesyncSub:AddToggle({
    Name = "Desync", Default = true, Flag = "rv_rage_desync",
    Callback = function(v) rage.desync = v end,
})
DesyncSub:AddToggle({
    Name = "Knife Adjust", Default = true, Flag = "rv_rage_knife",
    Callback = function(v) rage.knifeAdjust = v end,
})
DesyncSub:AddParagraph({
    Title = "Note",
    Text = "Desync repositions your character for the exact frame of the shot. If it feels too aggressive, turn it off and the ragebot will fire from your normal position instead.",
})

-- ── Rapid Hit (zero out all weapon cooldowns) ────────────────────────────
local rapidHitEnabled = false
local RapidItemLibrary
local rapidScanThread

do
    local ok, il = pcall(require, repS.Modules.ItemLibrary)
    if ok then RapidItemLibrary = il end
end

local function ScanCooldowns(tbl)
    if type(tbl) ~= "table" then return end
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            if v.ShootCooldown ~= nil then v.ShootCooldown = 0.000000000000000001 end
            if v.BurstCooldown ~= nil then v.BurstCooldown = 0.000000000000000001 end
            if v.AttackCooldown ~= nil then v.AttackCooldown = 0.000000000000000001 end
            if v.HeavyAttackCooldown ~= nil then v.HeavyAttackCooldown = 0.000000000000000001 end
            ScanCooldowns(v)
        end
    end
end

local function RapidHitLoop()
    while rapidHitEnabled do
        task.wait(1)
        if RapidItemLibrary then
            pcall(function() ScanCooldowns(RapidItemLibrary) end)
        end
    end
end

local RapidSub = RageTab:AddSubTab("Rapid Hit")
RapidSub:AddSection("Rapid Hit")
RapidSub:AddToggle({
    Name = "Rapid Hit", Default = false, Flag = "rv_rapid",
    Callback = function(v)
        rapidHitEnabled = v
        if v then
            if not RapidItemLibrary then
                Notify("Rage", "ItemLibrary not found — rapid hit unavailable", "Error", 3.5)
            else
                pcall(function() ScanCooldowns(RapidItemLibrary) end)
                rapidScanThread = task.spawn(RapidHitLoop)
                Notify("Rage", "Rapid Hit ON — all cooldowns zeroed", "Success")
            end
        else
            Notify("Rage", "Rapid Hit OFF", "Error")
        end
    end,
})
RapidSub:AddParagraph({
    Title = "Note",
    Text = "Re-scans every second so freshly-loaded items get patched too. Works together with the ragebot for maximum fire rate.",
})

-- ══════════════════════════════════════════════════════════════════════════════
-- VISUALS TAB
-- ══════════════════════════════════════════════════════════════════════════════
local VisualsTab = Window:AddTab({ Name = "Visuals", Subtitle = "ESP & world", Icon = "eye" })

local esp = {
    enabled = true,
    box = false, boxStyle = "Corner", boxThickness = 1,
    name = false, distance = false, health = false,
    hpPercent = false, weapon = false,
    skeleton = false, skeletonColor = Color3.fromRGB(120, 255, 120),
    offscreen = false,
    visibleCheck = false,
    tracer = false, tracerOrigin = "Bottom",
    teamCheck = false, rainbow = false,
    maxDistance = 1000, textSize = 13,
    color = Color3.fromRGB(255, 80, 80),
    nameColor = Color3.fromRGB(255, 255, 255),
}
local playerObjects = {}
local rayParamsESP
pcall(function()
    rayParamsESP = RaycastParams.new()
    rayParamsESP.FilterType = Enum.RaycastFilterType.Exclude
    rayParamsESP.IgnoreWater = true
end)

local function GetPlayerBox(plr)
    local o = playerObjects[plr]
    if o then return o end
    o = {}
    if hasDrawing then
        o.frame   = newDrawing("Square", { Thickness = 1, Filled = false, Visible = false })
        o.outline = newDrawing("Square", { Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0), Visible = false })
        o.fill    = newDrawing("Square", { Thickness = 1, Filled = true, Color = Color3.new(0, 0, 0), Transparency = 0.4, Visible = false })
        o.name    = newDrawing("Text", { Color = Color3.fromRGB(255, 255, 255), Size = 13, Outline = true, Centre = true, Visible = false })
        o.dist    = newDrawing("Text", { Color = Color3.fromRGB(255, 255, 255), Size = 11, Outline = true, Centre = true, Visible = false })
        o.tracer  = newDrawing("Line", { Thickness = 1.2, Visible = false })
        o.hpBack  = newDrawing("Line", { Thickness = 3, Visible = false, Color = Color3.new(0, 0, 0) })
        o.hp      = newDrawing("Line", { Thickness = 2, Visible = false })
        o.hpText  = newDrawing("Text", { Color = Color3.fromRGB(255, 255, 255), Size = 11, Outline = true, Centre = true, Visible = false })
        o.weapon  = newDrawing("Text", { Color = Color3.fromRGB(255, 220, 120), Size = 10, Outline = true, Centre = true, Visible = false })
        o.corners = {}
        for i = 1, 8 do o.corners[i] = newDrawing("Line", { Thickness = 1, Visible = false, Color = Color3.new(1, 1, 1) }) end
        o.skel = {}
        for i = 1, 14 do o.skel[i] = newDrawing("Line", { Thickness = 1.2, Visible = false }) end
        o.offscreen = newDrawing("Line", { Thickness = 1.5, Visible = false })
    end
    playerObjects[plr] = o
    return o
end

local R15_BONES = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local R6_BONES = {
    { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
    { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local function GetSkeletonPairs(char)
    if char:FindFirstChild("UpperTorso") then return R15_BONES end
    return R6_BONES
end

local function GetEquippedWeaponName(plr)
    if not FighterController or not FighterController.Objects then return nil end
    for _, fighterObj in FighterController.Objects do
        if fighterObj.Player == plr and fighterObj.EquippedItem then
            local name = fighterObj.EquippedItem.Name or fighterObj.EquippedItem:Get("Name")
            if name and name ~= "" then return name end
        end
    end
    return nil
end

local function IsPlayerVisible(char, myHeadPos, camDir)
    if not char then return false end
    if not rayParamsESP then return true end
    local targetHead = char:FindFirstChild("Head")
    local targetPart = targetHead or char:FindFirstChild("HumanoidRootPart")
    if not targetPart then return true end
    local origin = myHeadPos or Camera.CFrame.Position
    local dir = (targetPart.Position - origin)
    local dist = dir.Magnitude
    if dist < 1 then return true end
    dir = dir.Unit
    pcall(function() rayParamsESP.FilterDescendantsInstances = { LocalPlayer.Character } end)
    local result = workspace:Raycast(origin, dir * dist, rayParamsESP)
    if not result then return true end
    if result.Instance then
        local m = result.Instance:FindFirstAncestorOfClass("Model")
        if m == char then return true end
    end
    return false
end

local function GetBox2D(char)
    if not char then return nil end
    local ok, cf, size = pcall(function() return char:GetBoundingBox() end)
    if not ok or not cf then return nil end
    if size and size.Magnitude < 1 then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        cf = hrp.CFrame
        size = Vector3.new(3, 6, 2)
    end
    if not size then return nil end
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyOn = false
    for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
        local corner = (cf * CFrame.new(size.X / 2 * x, size.Y / 2 * y, size.Z / 2 * z)).Position
        local sp, on = Camera:WorldToViewportPoint(corner)
        if sp.Z > 0 then
            anyOn = anyOn or on
            minX = math.min(minX, sp.X); minY = math.min(minY, sp.Y)
            maxX = math.max(maxX, sp.X); maxY = math.max(maxY, sp.Y)
        end
    end end end
    if minX == math.huge or not anyOn then return nil end
    return minX, minY, maxX, maxY
end

local function DrawCornerBox(o, minX, minY, maxX, maxY, color, thick)
    local len = math.max(6, (maxX - minX) * 0.25)
    local pts = {
        { minX, minY, minX + len, minY }, { maxX - len, minY, maxX, minY },
        { minX, maxY, minX + len, maxY }, { maxX - len, maxY, maxX, maxY },
        { minX, minY, minX, minY + len }, { minX, maxY - len, minX, maxY },
        { maxX, minY, maxX, minY + len }, { maxX, maxY - len, maxX, maxY },
    }
    for i, p in ipairs(pts) do
        local l = o.corners[i]
        if l then
            l.Visible = true
            l.Color = color
            l.Thickness = thick
            l.From = Vector2.new(p[1], p[2])
            l.To = Vector2.new(p[3], p[4])
        end
    end
end

local espRenderConn = RunService.RenderStepped:Connect(function()
    if HUB.dead then return end
    local enabled = esp.enabled and hasDrawing
    for plr, o in pairs(playerObjects) do
        for _, d in ipairs({ o.frame, o.outline, o.fill, o.name, o.dist, o.tracer, o.hpBack, o.hp, o.hpText, o.weapon, o.offscreen }) do
            if d then d.Visible = false end
        end
        for _, l in ipairs(o.corners) do if l then l.Visible = false end end
        for _, l in ipairs(o.skel) do if l then l.Visible = false end end
    end
    if not enabled then return end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local myPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character:FindFirstChild("HumanoidRootPart").Position or Camera.CFrame.Position
    local rainbow = esp.rainbow and Color3.fromHSV((tick() % 5) / 5, 0.85, 1) or nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if not (esp.teamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team) then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if char and hum and hum.Health > 0 then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local dist = hrp and (hrp.Position - myPos).Magnitude or 0
                    if esp.maxDistance <= 0 or dist <= esp.maxDistance then
                        local o = GetPlayerBox(plr)
                        local minX, minY, maxX, maxY = GetBox2D(char)
                        if minX then
                            local color = rainbow or esp.color
                            if esp.visibleCheck then
                                local okVis, visible = pcall(function()
                                    local myChar = LocalPlayer.Character
                                    local myHead = myChar and myChar:FindFirstChild("Head")
                                    return IsPlayerVisible(char, myHead and myHead.Position or nil)
                                end)
                                if okVis and not visible then color = Color3.fromRGB(255, 60, 60) end
                            end
                            if esp.box then
                                if o.outline then o.outline.Visible = true; o.outline.Transparency = 0.6; o.outline.Color = color; o.outline.Thickness = esp.boxThickness + 2; o.outline.From = Vector2.new(minX - 1, minY - 1); o.outline.To = Vector2.new(maxX + 1, maxY + 1) end
                                if esp.boxStyle == "Corner" then
                                    DrawCornerBox(o, minX, minY, maxX, maxY, color, esp.boxThickness)
                                else
                                    if o.frame then o.frame.Visible = true; o.frame.Color = color; o.frame.Thickness = esp.boxThickness; o.frame.From = Vector2.new(minX, minY); o.frame.To = Vector2.new(maxX, maxY) end
                                end
                            end
                            if esp.health and o.hp and o.hpBack then
                                local h = hum.Health / hum.MaxHealth
                                o.hpBack.Visible = true
                                o.hpBack.From = Vector2.new(minX - 6, minY - 2)
                                o.hpBack.To = Vector2.new(minX - 6, maxY + 2)
                                o.hp.Visible = true
                                o.hp.Color = h > 0.5 and Color3.fromRGB(90, 220, 90) or (h > 0.25 and Color3.fromRGB(240, 200, 60) or Color3.fromRGB(230, 60, 60))
                                o.hp.From = Vector2.new(minX - 6, maxY + 2)
                                o.hp.To = Vector2.new(minX - 6, minY + 2 - (maxY - minY + 4) * math.clamp(h, 0, 1))
                            end
                            if esp.hpPercent and o.hpText then
                                o.hpText.Visible = true
                                o.hpText.Size = esp.textSize - 2
                                o.hpText.Text = tostring(math.floor(hum.Health)) .. "/" .. tostring(math.floor(hum.MaxHealth))
                                o.hpText.Position = Vector2.new(minX - 6, maxY + 2)
                            end
                            if esp.weapon and o.weapon then
                                local okW, wName = pcall(GetEquippedWeaponName, plr)
                                if okW and wName then
                                    o.weapon.Visible = true
                                    o.weapon.Size = esp.textSize - 3
                                    o.weapon.Color = rainbow or Color3.fromRGB(255, 220, 120)
                                    o.weapon.Text = wName
                                    o.weapon.Position = Vector2.new((minX + maxX) / 2, maxY + 14)
                                end
                            end
                            if esp.name and o.name then
                                o.name.Visible = true
                                o.name.Color = rainbow or esp.nameColor
                                o.name.Size = esp.textSize
                                o.name.Text = plr.DisplayName
                                o.name.Position = Vector2.new((minX + maxX) / 2, minY - 14)
                            end
                            if esp.distance and o.dist then
                                o.dist.Visible = true
                                o.dist.Size = esp.textSize - 2
                                o.dist.Text = tostring(math.floor(dist / 3.28)) .. "m"
                                o.dist.Position = Vector2.new((minX + maxX) / 2, maxY + 2)
                            end
                            if esp.tracer and o.tracer then
                                o.tracer.Visible = true
                                o.tracer.Color = rainbow or esp.color
                                local sp, on = Camera:WorldToViewportPoint((hrp or char):GetPivot().Position)
                                if on and sp.Z > 0 then
                                    local origin = center
                                    if esp.tracerOrigin == "Bottom" then origin = Vector2.new(center.X, Camera.ViewportSize.Y)
                                    elseif esp.tracerOrigin == "Top" then origin = Vector2.new(center.X, 0)
                                    elseif esp.tracerOrigin == "Mouse" then origin = UserInputService:GetMouseLocation() end
                                    o.tracer.From = origin
                                    o.tracer.To = Vector2.new(sp.X, sp.Y)
                                end
                            end
                            if esp.skeleton and hrp then
                                pcall(function()
                                    local pairs = GetSkeletonPairs(char)
                                    local skelColor = rainbow or esp.skeletonColor or Color3.fromRGB(120, 255, 120)
                                    for i, bonePair in ipairs(pairs) do
                                        local a = char:FindFirstChild(bonePair[1], true)
                                        local b = char:FindFirstChild(bonePair[2], true)
                                        if a and not a:IsA("BasePart") then a = nil end
                                        if b and not b:IsA("BasePart") then b = nil end
                                        if a and b then
                                            local pa, pb = a.Position, b.Position
                                            local l = o.skel[i]
                                            if l then
                                                local okA, sa, oa = pcall(function() return Camera:WorldToViewportPoint(pa) end)
                                                local okB, sb, ob = pcall(function() return Camera:WorldToViewportPoint(pb) end)
                                                if okA and okB and oa and ob and sa.Z > 0 and sb.Z > 0 then
                                                    l.Visible = true
                                                    l.Color = skelColor
                                                    l.From = Vector2.new(sa.X, sa.Y)
                                                    l.To = Vector2.new(sb.X, sb.Y)
                                                end
                                            end
                                        end
                                    end
                                end)
                            end
                            if esp.offscreen and o.offscreen and hrp then
                                pcall(function()
                                    local sp, on = Camera:WorldToViewportPoint(hrp.Position)
                                    if sp.Z > 0 and not on then
                                        local vs = Camera.ViewportSize
                                        local margin = 30
                                        local cx = math.clamp(sp.X, margin, vs.X - margin)
                                        local cy = math.clamp(sp.Y, margin, vs.Y - margin)
                                        local edge = Vector2.new(cx, cy)
                                        local dirV = (Vector2.new(sp.X, sp.Y) - edge)
                                        if dirV.Magnitude > 8 then
                                            local n = dirV.Unit * 14
                                            o.offscreen.Visible = true
                                            o.offscreen.Color = rainbow or esp.color
                                            o.offscreen.From = edge - n
                                            o.offscreen.To = edge
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end)
table.insert(HUB.conns, espRenderConn)

-- ── ESP UI ────────────────────────────────────────────────────────────────
local EspSub = VisualsTab:AddSubTab("ESP")
EspSub:AddToggle({ Name = "Master Enable", Default = true, Flag = "rv_esp", Callback = function(v) esp.enabled = v end })
EspSub:AddSection("Boxes")
EspSub:AddToggle({ Name = "2D Box", Default = false, Flag = "rv_espbox", Callback = function(v) esp.box = v end })
local applyBoxStyle = function(v) esp.boxStyle = v end
local boxStyleDropdown = EspSub:AddDropdown({
    Name = "Box Style", Options = { "Corner", "Full" }, Default = "Corner", MaxVisible = 2,
    Flag = "rv_espboxstyle", Callback = applyBoxStyle,
})
registerResync(boxStyleDropdown, applyBoxStyle)
EspSub:AddSlider({ Name = "Box Thickness", Min = 1, Max = 5, Default = 1, Suffix = "", Flag = "rv_espthick", Callback = function(v) esp.boxThickness = v end })
EspSub:AddSection("Text")
EspSub:AddToggle({ Name = "Name", Default = false, Flag = "rv_espname", Callback = function(v) esp.name = v end })
EspSub:AddToggle({ Name = "Distance", Default = false, Flag = "rv_espdist", Callback = function(v) esp.distance = v end })
EspSub:AddToggle({ Name = "Health Bar", Default = false, Flag = "rv_esphp", Callback = function(v) esp.health = v end })
EspSub:AddToggle({ Name = "HP Percent", Default = false, Flag = "rv_esphppct", Callback = function(v) esp.hpPercent = v end })
EspSub:AddToggle({ Name = "Weapon Name", Default = false, Flag = "rv_espweapon", Callback = function(v) esp.weapon = v end })
EspSub:AddSlider({ Name = "Text Size", Min = 10, Max = 20, Default = 13, Suffix = "", Flag = "rv_esptextsize", Callback = function(v) esp.textSize = v end })
EspSub:AddSection("Skeleton")
EspSub:AddToggle({ Name = "Skeleton", Default = false, Flag = "rv_espskel", Callback = function(v) esp.skeleton = v end })
EspSub:AddColorPicker({ Name = "Skeleton Color", Default = esp.skeletonColor, Flag = "rv_espskelcolor", Callback = function(c) esp.skeletonColor = c end })
EspSub:AddSection("Extras")
EspSub:AddToggle({ Name = "Tracers", Default = false, Flag = "rv_esptracer", Callback = function(v) esp.tracer = v end })
EspSub:AddToggle({ Name = "Offscreen Indicators", Default = false, Flag = "rv_espoffscreen", Callback = function(v) esp.offscreen = v end })
EspSub:AddToggle({ Name = "Visibility Check", Default = false, Flag = "rv_espvisible", Callback = function(v) esp.visibleCheck = v end })
local applyTracerOrigin = function(v) esp.tracerOrigin = v end
local tracerOriginDropdown = EspSub:AddDropdown({
    Name = "Tracer Origin", Options = { "Bottom", "Center", "Top", "Mouse" }, Default = "Bottom",
    MaxVisible = 4, Flag = "rv_esptracerorigin", Callback = applyTracerOrigin,
})
registerResync(tracerOriginDropdown, applyTracerOrigin)
EspSub:AddSection("Behavior")
EspSub:AddToggle({ Name = "Team Check", Default = false, Flag = "rv_espteam", Callback = function(v) esp.teamCheck = v end })
EspSub:AddToggle({ Name = "Rainbow", Default = false, Flag = "rv_esprb", Callback = function(v) esp.rainbow = v end })
EspSub:AddSlider({ Name = "Max Distance", Min = 0, Max = 5000, Default = 1000, Suffix = "m", Flag = "rv_espmaxdist", Callback = function(v) esp.maxDistance = v end })
EspSub:AddSection("Colors")
EspSub:AddColorPicker({ Name = "Box Color", Default = esp.color, Flag = "rv_espcolor", Callback = function(c) esp.color = c end })
EspSub:AddColorPicker({ Name = "Name Color", Default = esp.nameColor, Flag = "rv_espnamecolor", Callback = function(c) esp.nameColor = c end })

-- ── World sub-tab ─────────────────────────────────────────────────────────
local WorldSub = VisualsTab:AddSubTab("World")
local savedLighting = { GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient }
local okOutdoor, outdoorAmbient = pcall(function() return Lighting.OutdoorAmbient end)
local okExp, exposureComp = pcall(function() return Lighting.ExposureCompensation end)
if okOutdoor then savedLighting.OutdoorAmbient = outdoorAmbient end
if okExp then savedLighting.ExposureCompensation = exposureComp end

local fullbright = false
WorldSub:AddToggle({
    Name = "Fullbright", Default = false, Flag = "rv_fullbright",
    Callback = function(v)
        fullbright = v
        Lighting.GlobalShadows = not v
        Lighting.Ambient = v and Color3.new(1, 1, 1) or savedLighting.Ambient
        pcall(function() Lighting.OutdoorAmbient = v and Color3.new(1, 1, 1) or savedLighting.OutdoorAmbient end)
        pcall(function() Lighting.ExposureCompensation = v and 0.6 or savedLighting.ExposureCompensation end)
    end,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- PLAYER TAB
-- ══════════════════════════════════════════════════════════════════════════════
local PlayerTab = Window:AddTab({ Name = "Player", Subtitle = "Movement & character", Icon = "player" })

local MoveSub = PlayerTab:AddSubTab("Movement")
local wsEnabled, wsValue = false, 16
local jpEnabled, jpValue = false, 50
local infJump = false
local flyEnabled, flySpeed = false, 60
local noclipEnabled = false

MoveSub:AddSection("Speed & Jump")
MoveSub:AddToggle({
    Name = "WalkSpeed", Default = false, Flag = "rv_ws",
    Callback = function(v)
        wsEnabled = v
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v and wsValue or 16 end
    end,
})
MoveSub:AddSlider({
    Name = "WalkSpeed Value", Min = 16, Max = 200, Default = 16, Suffix = "", Flag = "rv_ws_value",
    Callback = function(v)
        wsValue = v
        if wsEnabled then local c = LocalPlayer.Character; local hum = c and c:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = v end end
    end,
})
MoveSub:AddToggle({
    Name = "JumpPower", Default = false, Flag = "rv_jp",
    Callback = function(v)
        jpEnabled = v
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = v and jpValue or 50 end
    end,
})
MoveSub:AddSlider({
    Name = "JumpPower Value", Min = 50, Max = 300, Default = 50, Suffix = "", Flag = "rv_jp_value",
    Callback = function(v)
        jpValue = v
        if jpEnabled then local c = LocalPlayer.Character; local hum = c and c:FindFirstChildOfClass("Humanoid"); if hum then hum.JumpPower = v end end
    end,
})
MoveSub:AddToggle({
    Name = "Infinite Jump", Default = false, Flag = "rv_infjump",
    Callback = function(v) infJump = v end,
})

MoveSub:AddSection("Fly & Noclip")
MoveSub:AddToggle({
    Name = "Fly", Default = false, Flag = "rv_fly",
    Callback = function(v) flyEnabled = v end,
})
MoveSub:AddSlider({
    Name = "Fly Speed", Min = 10, Max = 300, Default = 60, Suffix = "", Flag = "rv_fly_speed",
    Callback = function(v) flySpeed = v end,
})
MoveSub:AddToggle({
    Name = "Noclip", Default = false, Flag = "rv_noclip",
    Callback = function(v) noclipEnabled = v end,
})

-- Movement re-apply / fly / noclip loop
local function ReapplyStats()
    local c = LocalPlayer.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then
        if wsEnabled then hum.WalkSpeed = wsValue end
        if jpEnabled then hum.JumpPower = jpValue end
    end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        if noclipEnabled then hrp.CanCollide = false end
        if flyEnabled then
            local move = UserInputService:GetMoveVector()
            local camCf = Camera.CFrame
            local dir = (camCf.RightVector * move.X + camCf.LookVector * -move.Y) * flySpeed
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, flySpeed, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir + Vector3.new(0, -flySpeed, 0) end
            hrp.CFrame = hrp.CFrame + dir * 0.016
        end
    end
end
track(RunService.Heartbeat:Connect(function()
    if HUB.dead then return end
    if wsEnabled or jpEnabled or flyEnabled or noclipEnabled then
        pcall(ReapplyStats)
    end
end))

-- Infinite jump
track(UserInputService.JumpRequest:Connect(function()
    if infJump then
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

-- ══════════════════════════════════════════════════════════════════════════════
-- UNLOCK ALL COSMETICS (Player tab) — skins / charms / dances / emotes / wraps
-- Everything except Finishers, exactly like the user script. Consolidated into a
-- single hook set (the original defines each hook 5x; only the last one wins).
-- ══════════════════════════════════════════════════════════════════════════════
local unlockEnabled = false
local CosmeticLibrary, ItemLibrary, PlayerDataController
local equipped = {}
local favorites = {}
local constructingWeapon, viewingProfile = nil, nil
local lastUsedWeapon = nil
local origOwnsCosmetic, origDataGet, origGetWeaponData
local origNamecall
local origCreateViewModel, origClientVMNew, origGetCharm, origGetWrap, origGetVMImage, origFetch
local viewModelModule, ClientViewModel, ClientItem
local unlockFile = "unlockall/config.json"

do
    local ok1, cl = pcall(require, reps.Modules.CosmeticLibrary)
    if ok1 then CosmeticLibrary = cl end
    local ok2, il = pcall(require, reps.Modules.ItemLibrary)
    if ok2 then ItemLibrary = il end
    local ok3, pd = pcall(require, LocalPlayer.PlayerScripts.Controllers.PlayerDataController)
    if ok3 then PlayerDataController = pd end
end

local function UnlockIsUnlockable(cosmetic)
    if not cosmetic then return false end
    local t = cosmetic.Type or ""
    local n = (cosmetic.Name or ""):lower()
    if t == "Skin" or t == "Charm" or t == "Dance" or t == "Emote" or t == "Wrap" or t == "Wrapping" then
        return true
    end
    if n:find("charm") or n:find("dance") or n:find("emote") or n:find("wrap") then
        return true
    end
    return false
end

local function UnlockCloneCosmetic(name, cosmeticType, options)
    local base = CosmeticLibrary and CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[name]
    if not base then return nil end
    local data = {}
    for key, value in pairs(base) do data[key] = value end
    data.Name = name
    data.Type = data.Type or cosmeticType
    data.Seed = data.Seed or math.random(1, 1000000)
    if options then
        if options.inverted ~= nil then data.Inverted = options.inverted end
        if options.favoritesOnly ~= nil then data.OnlyUseFavorites = options.favoritesOnly end
    end
    return data
end

local function UnlockSaveConfig()
    if not writefile then return end
    pcall(function()
        local config = { equipped = {}, favorites = favorites }
        for weapon, cosmetics in pairs(equipped) do
            config.equipped[weapon] = {}
            for cosmeticType, cosmeticData in pairs(cosmetics) do
                if cosmeticData and cosmeticData.Name then
                    config.equipped[weapon][cosmeticType] = {
                        name = cosmeticData.Name,
                        seed = cosmeticData.Seed,
                        inverted = cosmeticData.Inverted,
                    }
                end
            end
        end
        makefolder("unlockall")
        writefile(unlockFile, HttpService:JSONEncode(config))
    end)
end

local function UnlockLoadConfig()
    if not readfile or not isfile or not isfile(unlockFile) then return end
    pcall(function()
        local config = HttpService:JSONDecode(readfile(unlockFile))
        if config.equipped then
            for weapon, cosmetics in pairs(config.equipped) do
                equipped[weapon] = {}
                for cosmeticType, cosmeticData in pairs(cosmetics) do
                    local cloned = UnlockCloneCosmetic(cosmeticData.name, cosmeticType, { inverted = cosmeticData.inverted })
                    if cloned then
                        cloned.Seed = cosmeticData.seed
                        equipped[weapon][cosmeticType] = cloned
                    end
                end
            end
        end
        favorites = config.favorites or {}
    end)
end

local function UnlockApplyViewmodelCosmetics(replicatedData, weaponName, weaponPlayer)
    if weaponPlayer == LocalPlayer and equipped[weaponName] then
        local ReplicatedClass = require(reps.Modules.ReplicatedClass)
        local dataKey = ReplicatedClass:ToEnum("Data")
        replicatedData[dataKey] = replicatedData[dataKey] or {}
        local cosmetics = equipped[weaponName]
        if cosmetics.Skin then replicatedData[dataKey][ReplicatedClass:ToEnum("Skin")] = cosmetics.Skin end
        if cosmetics.Charm then replicatedData[dataKey][ReplicatedClass:ToEnum("Charm")] = cosmetics.Charm end
        if cosmetics.Wrap then replicatedData[dataKey][ReplicatedClass:ToEnum("Wrap")] = cosmetics.Wrap end
    end
end

local function ApplyUnlockAll(on)
    if on then
        if not (CosmeticLibrary and ItemLibrary and PlayerDataController) then
            Notify("Unlock All", "Cosmetic modules not found", "Error", 3.5)
            return
        end

        -- OwnsCosmetic: every Skin/Charm/Dance/Emote/Wrap is owned (no Finishers)
        if not origOwnsCosmetic then
            origOwnsCosmetic = CosmeticLibrary.OwnsCosmetic
            CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
                if name:find("MISSING_") then return origOwnsCosmetic(self, inventory, name, weapon) end
                local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[name]
                if UnlockIsUnlockable(cosmetic) then return true end
                return origOwnsCosmetic(self, inventory, name, weapon)
            end
        end

        -- DataController.Get: inventory reports every unlockable cosmetic owned
        if not origDataGet then
            origDataGet = PlayerDataController.Get
            PlayerDataController.Get = function(self, key)
                local data = origDataGet(self, key)
                if key == "CosmeticInventory" then
                    local proxy = {}
                    if data then
                        for k, v in pairs(data) do
                            local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[k]
                            if UnlockIsUnlockable(cosmetic) then proxy[k] = v end
                        end
                    end
                    return setmetatable(proxy, { __index = function(t, k)
                        local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[k]
                        if UnlockIsUnlockable(cosmetic) then return true end
                        return nil
                    end })
                end
                if key == "FavoritedCosmetics" then
                    local result = data and table.clone(data) or {}
                    for weapon, favs in pairs(favorites) do
                        result[weapon] = result[weapon] or {}
                        for name, isFav in pairs(favs) do
                            local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[name]
                            if UnlockIsUnlockable(cosmetic) then result[weapon][name] = isFav end
                        end
                    end
                    return result
                end
                return data
            end
        end

        -- GetWeaponData: merge equipped Skin/Charm/Wrap into the weapon data
        if not origGetWeaponData then
            origGetWeaponData = PlayerDataController.GetWeaponData
            PlayerDataController.GetWeaponData = function(self, weaponName)
                local data = origGetWeaponData(self, weaponName)
                if not data then return nil end
                local merged = {}
                for key, value in pairs(data) do merged[key] = value end
                merged.Name = weaponName
                if equipped[weaponName] then
                    for cosmeticType, cosmeticData in pairs(equipped[weaponName]) do
                        if cosmeticType == "Skin" or cosmeticType == "Charm" or cosmeticType == "Wrap" or cosmeticType == "Wrapping" then
                            merged[cosmeticType] = cosmeticData
                        end
                    end
                end
                return merged
            end
        end

        -- EquipCosmetic / FavoriteCosmetic remotes: store equipped cosmetics locally
        if not origNamecall and hookmetamethod and getnamecallmethod then
            local remotes = reps.Remotes
            local dataRemotes = remotes and remotes:FindFirstChild("Data")
            local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
            local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
            if equipRemote then
                origNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                    if getnamecallmethod() ~= "FireServer" then return origNamecall(self, ...) end
                    local args = { ... }
                    if self == equipRemote then
                        local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                        local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[cosmeticName]
                        if not UnlockIsUnlockable(cosmetic) then return origNamecall(self, ...) end
                        if cosmeticName and cosmeticName ~= "None" and cosmeticName ~= "" then
                            local inventory = PlayerDataController:Get("CosmeticInventory")
                            if inventory and rawget(inventory, cosmeticName) then return origNamecall(self, ...) end
                        end
                        if cosmeticType == "Dance" or cosmeticType == "Emote" then
                            equipped.Dances = equipped.Dances or {}
                            if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                                equipped.Dances[cosmeticType] = nil
                            else
                                local cloned = UnlockCloneCosmetic(cosmeticName, cosmeticType, { inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites })
                                if cloned then equipped.Dances[cosmeticType] = cloned end
                            end
                            task.defer(function()
                                pcall(function() PlayerDataController.CurrentData:Replicate("CosmeticInventory") end)
                                task.wait(0.2)
                                UnlockSaveConfig()
                            end)
                        else
                            equipped[weaponName] = equipped[weaponName] or {}
                            if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                                equipped[weaponName][cosmeticType] = nil
                                if not next(equipped[weaponName]) then equipped[weaponName] = nil end
                            else
                                local cloned = UnlockCloneCosmetic(cosmeticName, cosmeticType, { inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites })
                                if cloned then equipped[weaponName][cosmeticType] = cloned end
                            end
                            task.defer(function()
                                pcall(function() PlayerDataController.CurrentData:Replicate("WeaponInventory") end)
                                task.wait(0.2)
                                UnlockSaveConfig()
                            end)
                        end
                        return
                    end
                    if self == favoriteRemote then
                        local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[args[2]]
                        if UnlockIsUnlockable(cosmetic) then
                            favorites[args[1]] = favorites[args[1]] or {}
                            favorites[args[1]][args[2]] = args[3] or nil
                            UnlockSaveConfig()
                            task.spawn(function() pcall(function() PlayerDataController.CurrentData:Replicate("FavoritedCosmetics") end) end)
                        end
                        return
                    end
                    return origNamecall(self, ...)
                end)
            end
        end

        -- ClientItem._CreateViewModel: inject the equipped cosmetic into the viewmodel ref
        pcall(function() ClientItem = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem) end)
        if ClientItem and ClientItem._CreateViewModel and not origCreateViewModel then
            origCreateViewModel = ClientItem._CreateViewModel
            ClientItem._CreateViewModel = function(self, viewmodelRef)
                local weaponName = self.Name
                local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
                constructingWeapon = (weaponPlayer == LocalPlayer) and weaponName or nil
                if weaponPlayer == LocalPlayer and equipped[weaponName] and viewmodelRef then
                    local dataKey, skinKey, nameKey = self:ToEnum("Data"), self:ToEnum("Skin"), self:ToEnum("Name")
                    if viewmodelRef[dataKey] then
                        if equipped[weaponName].Skin then
                            viewmodelRef[dataKey][skinKey] = equipped[weaponName].Skin
                            viewmodelRef[dataKey][nameKey] = equipped[weaponName].Skin.Name
                        end
                    elseif viewmodelRef.Data then
                        if equipped[weaponName].Skin then
                            viewmodelRef.Data.Skin = equipped[weaponName].Skin
                            viewmodelRef.Data.Name = equipped[weaponName].Skin.Name
                        end
                    end
                end
                local result = origCreateViewModel(self, viewmodelRef)
                constructingWeapon = nil
                return result
            end
        end

        -- ClientViewModel: new() + GetCharm/GetWrap getters apply equipped cosmetics
        viewModelModule = LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
        if viewModelModule then
            ClientViewModel = require(viewModelModule)
            if not origClientVMNew then
                origClientVMNew = ClientViewModel.new
                ClientViewModel.new = function(replicatedData, clientItem)
                    local weaponPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player
                    local weaponName = constructingWeapon or clientItem.Name
                    UnlockApplyViewmodelCosmetics(replicatedData, weaponName, weaponPlayer)
                    local result = origClientVMNew(replicatedData, clientItem)
                    if weaponPlayer == LocalPlayer and equipped[weaponName] and equipped[weaponName].Wrap and result._UpdateWrap then
                        result:_UpdateWrap()
                        task.delay(0.1, function() if not result._destroyed then result:_UpdateWrap() end end)
                    end
                    return result
                end
            end
            if not origGetCharm and ClientViewModel.GetCharm then
                origGetCharm = ClientViewModel.GetCharm
                ClientViewModel.GetCharm = function(self)
                    local weaponName = self.ClientItem and self.ClientItem.Name
                    local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player
                    if weaponName and weaponPlayer == LocalPlayer and equipped[weaponName] and equipped[weaponName].Charm then
                        return equipped[weaponName].Charm
                    end
                    return origGetCharm(self)
                end
            end
            if not origGetWrap and ClientViewModel.GetWrap then
                origGetWrap = ClientViewModel.GetWrap
                ClientViewModel.GetWrap = function(self)
                    local weaponName = self.ClientItem and self.ClientItem.Name
                    local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player
                    if weaponName and weaponPlayer == LocalPlayer and equipped[weaponName] and equipped[weaponName].Wrap then
                        return equipped[weaponName].Wrap
                    end
                    return origGetWrap(self)
                end
            end
        end

        -- ItemLibrary: show the equipped skin image (also on your profile page)
        if ItemLibrary and ItemLibrary.GetViewModelImageFromWeaponData and not origGetVMImage then
            origGetVMImage = ItemLibrary.GetViewModelImageFromWeaponData
            ItemLibrary.GetViewModelImageFromWeaponData = function(self, weaponData, highRes)
                if not weaponData then return origGetVMImage(self, weaponData, highRes) end
                local weaponName = weaponData.Name
                local shouldShowSkin = (weaponData.Skin and equipped[weaponName] and weaponData.Skin == equipped[weaponName].Skin) or (viewingProfile == LocalPlayer and equipped[weaponName] and equipped[weaponName].Skin)
                if shouldShowSkin and equipped[weaponName] and equipped[weaponName].Skin then
                    local skinInfo = self.ViewModels and self.ViewModels[equipped[weaponName].Skin.Name]
                    if skinInfo then return skinInfo[highRes and "ImageHighResolution" or "Image"] or skinInfo.Image end
                end
                return origGetVMImage(self, weaponData, highRes)
            end
        end

        -- ViewProfile: track when your profile is open so skins show there too
        pcall(function()
            local ViewProfile = require(LocalPlayer.PlayerScripts.Modules.Pages.ViewProfile)
            if ViewProfile and ViewProfile.Fetch and not origFetch then
                origFetch = ViewProfile.Fetch
                ViewProfile.Fetch = function(self, targetPlayer)
                    viewingProfile = targetPlayer
                    return origFetch(self, targetPlayer)
                end
            end
        end)

        UnlockLoadConfig()
    else
        if CosmeticLibrary and origOwnsCosmetic then pcall(function() CosmeticLibrary.OwnsCosmetic = origOwnsCosmetic end); origOwnsCosmetic = nil end
        if PlayerDataController and origDataGet then pcall(function() PlayerDataController.Get = origDataGet end); origDataGet = nil end
        if PlayerDataController and origGetWeaponData then pcall(function() PlayerDataController.GetWeaponData = origGetWeaponData end); origGetWeaponData = nil end
        if origNamecall then pcall(function() hookmetamethod(game, "__namecall", origNamecall) end); origNamecall = nil end
        if ClientItem and origCreateViewModel then pcall(function() ClientItem._CreateViewModel = origCreateViewModel end); origCreateViewModel = nil end
        if ClientViewModel and origClientVMNew then pcall(function() ClientViewModel.new = origClientVMNew end); origClientVMNew = nil end
        if ClientViewModel and origGetCharm then pcall(function() ClientViewModel.GetCharm = origGetCharm end); origGetCharm = nil end
        if ClientViewModel and origGetWrap then pcall(function() ClientViewModel.GetWrap = origGetWrap end); origGetWrap = nil end
        if ItemLibrary and origGetVMImage then pcall(function() ItemLibrary.GetViewModelImageFromWeaponData = origGetVMImage end); origGetVMImage = nil end
        if origFetch then
            pcall(function()
                local ViewProfile = require(LocalPlayer.PlayerScripts.Modules.Pages.ViewProfile)
                if ViewProfile then ViewProfile.Fetch = origFetch end
            end)
            origFetch = nil
        end
        ClientItem, ClientViewModel, viewModelModule = nil, nil, nil
    end
end

local UnlockSub = PlayerTab:AddSubTab("Unlock All")
UnlockSub:AddSection("Unlock All Cosmetics")
UnlockSub:AddToggle({
    Name = "Unlock All Cosmetics", Default = false, Flag = "rv_unlockall",
    Callback = function(v)
        unlockEnabled = v
        ApplyUnlockAll(v)
        if v and not (CosmeticLibrary and ItemLibrary and PlayerDataController) then
            Notify("Unlock All", "Cosmetic modules not found", "Error", 3.5)
        else
            Notify("Unlock All", v and "All cosmetics unlocked (no Finishers)" or "Unlock All off", v and "Success" or "Error")
        end
    end,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- SPOOF (Player tab) — name / level / winstreak
-- ══════════════════════════════════════════════════════════════════════════════
local spoofConfig = {
    nameSpoof = true,
    yourName = "Andy",
    enemyName = "Johnny",
    levelSpoof = false,
    spoofedLevel = 996,
    winstreakSpoof = false,
    spoofedWinstreak = 56,
}
local spoofConns = {}
local spoofLoopAlive = true

local function SpoofPlayer(player)
    if not spoofConfig.nameSpoof then return end
    if player == LocalPlayer then
        pcall(function()
            player.Name = spoofConfig.yourName
            player.DisplayName = spoofConfig.yourName
        end)
    else
        pcall(function()
            player.Name = spoofConfig.enemyName
            player.DisplayName = spoofConfig.enemyName
        end)
    end
end

local function SpoofLeaderstats(player)
    if player ~= LocalPlayer then return end
    local leaderstats = player:FindFirstChild("CustomLeaderstats")
    if not leaderstats then return end
    if spoofConfig.levelSpoof then
        local levelVal = leaderstats:FindFirstChild("Level")
        if levelVal and levelVal:IsA("IntValue") then levelVal.Value = spoofConfig.spoofedLevel end
        pcall(function() player:SetAttribute("Level", spoofConfig.spoofedLevel) end)
    end
    if spoofConfig.winstreakSpoof then
        local streakFolder = leaderstats:FindFirstChild("Win Streak")
        if streakFolder then
            if streakFolder:IsA("Folder") then
                local streakVal = streakFolder:FindFirstChildWhichIsA("IntValue")
                if streakVal then streakVal.Value = spoofConfig.spoofedWinstreak end
            elseif streakFolder:IsA("IntValue") then
                streakFolder.Value = spoofConfig.spoofedWinstreak
            end
        end
        pcall(function() player:SetAttribute("StatisticDuelsWinStreak", spoofConfig.spoofedWinstreak) end)
    end
end

local GUI_PATH = {
    "PlayerGui", "MainGui", "PlayerList", "Container",
    "Elements", "Container", "Middle", "List", "Container",
}

local function GetListContainer()
    local node = LocalPlayer
    for _, name in ipairs(GUI_PATH) do
        if not node then return nil end
        node = node:FindFirstChild(name)
    end
    return node
end

local function FindAllTitleLabels(instance, results)
    results = results or {}
    if not instance then return results end
    for _, child in ipairs(instance:GetChildren()) do
        if child:IsA("TextLabel") and child.Name == "Title" then table.insert(results, child) end
        FindAllTitleLabels(child, results)
    end
    return results
end

local function SpoofTitleLabels(container)
    if not container then return end
    for _, playerFrame in ipairs(container:GetChildren()) do
        if playerFrame:IsA("Frame") then
            local spoofed = false
            local innerContainer = playerFrame:FindFirstChild("Container")
            if innerContainer and innerContainer:IsA("Frame") then
                for _, child in ipairs(innerContainer:GetChildren()) do
                    if child:IsA("Frame") then
                        local titleLabel = child:FindFirstChild("Title")
                        if titleLabel and titleLabel:IsA("TextLabel") then
                            local isLocal = titleLabel.Text == LocalPlayer.Name or titleLabel.Text == LocalPlayer.DisplayName
                            titleLabel.Text = isLocal and spoofConfig.yourName or spoofConfig.enemyName
                            spoofed = true
                        end
                    end
                end
            end
            if not spoofed then
                local labels = FindAllTitleLabels(playerFrame)
                for _, titleLabel in ipairs(labels) do
                    local isLocal = titleLabel.Text == LocalPlayer.Name or titleLabel.Text == LocalPlayer.DisplayName
                    titleLabel.Text = isLocal and spoofConfig.yourName or spoofConfig.enemyName
                end
            end
        end
    end
end

local function StartSpoofLoop()
    task.spawn(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui", 30)
        if not playerGui then return end
        local monitoredContainer = nil
        while spoofLoopAlive do
            task.wait(0.5)
            if not spoofConfig.nameSpoof then
                -- name spoof off: just idle until it's enabled again
            else
                local listContainer = GetListContainer()
                if listContainer and listContainer ~= monitoredContainer then
                    monitoredContainer = listContainer
                    local conn = listContainer.ChildAdded:Connect(function(child)
                        if child:IsA("Frame") then
                            task.wait(0.1)
                            pcall(SpoofTitleLabels, listContainer)
                        end
                    end)
                    table.insert(spoofConns, conn)
                end
                if listContainer then
                    pcall(SpoofTitleLabels, listContainer)
                end
            end
        end
    end)
end

local function ApplySpoof(on)
    if on then
        for _, player in ipairs(Players:GetPlayers()) do
            SpoofPlayer(player)
            if player == LocalPlayer then
                SpoofLeaderstats(player)
            end
        end
        local addedConn = Players.PlayerAdded:Connect(function(player) SpoofPlayer(player) end)
        table.insert(spoofConns, addedConn)
        StartSpoofLoop()
    else
        for _, c in ipairs(spoofConns) do pcall(function() c:Disconnect() end) end
        table.clear(spoofConns)
    end
end

local SpoofSub = PlayerTab:AddSubTab("Spoof")
SpoofSub:AddSection("Name Spoof")
SpoofSub:AddToggle({
    Name = "Name Spoof", Default = true, Flag = "rv_spoof_name",
    Callback = function(v)
        spoofConfig.nameSpoof = v
        if v then
            ApplySpoof(true)
        else
            for _, c in ipairs(spoofConns) do pcall(function() c:Disconnect() end) end
            table.clear(spoofConns)
        end
    end,
})
SpoofSub:AddInput({
    Name = "Your Name", Default = "Andy", Flag = "rv_spoof_yname",
    Callback = function(t) spoofConfig.yourName = t end,
})
SpoofSub:AddInput({
    Name = "Enemy Name", Default = "Johnny", Flag = "rv_spoof_ename",
    Callback = function(t) spoofConfig.enemyName = t end,
})
SpoofSub:AddSection("Stats Spoof")
SpoofSub:AddToggle({
    Name = "Level Spoof", Default = false, Flag = "rv_spoof_level",
    Callback = function(v) spoofConfig.levelSpoof = v; if v then SpoofLeaderstats(LocalPlayer) end end,
})
SpoofSub:AddInput({
    Name = "Spoofed Level", Default = "996", Flag = "rv_spoof_levelval",
    Callback = function(t) spoofConfig.spoofedLevel = tonumber(t) or 996 end,
})
SpoofSub:AddToggle({
    Name = "Winstreak Spoof", Default = false, Flag = "rv_spoof_ws",
    Callback = function(v) spoofConfig.winstreakSpoof = v; if v then SpoofLeaderstats(LocalPlayer) end end,
})
SpoofSub:AddInput({
    Name = "Spoofed Winstreak", Default = "56", Flag = "rv_spoof_wsval",
    Callback = function(t) spoofConfig.spoofedWinstreak = tonumber(t) or 56 end,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- SYSTEM TAB
-- ══════════════════════════════════════════════════════════════════════════════
local SystemTab = Window:AddTab({ Name = "System", Subtitle = "Settings & config", Icon = "settings" })
local SettingsSub = SystemTab:AddSubTab("Settings")

if type(Library.SetTheme) == "function" then
    SettingsSub:AddDropdown({
        Name = "Theme", Options = { "Dark", "Light", "OLED" }, Default = "Dark",
        Flag = "rv_theme",
        Callback = function(v) pcall(function() Library:SetTheme(v) end) end,
    })
end

SettingsSub:AddSection("Performance")
local setFpsCap = setfpscap or (getfenv and getfenv().setfpscap)
if type(setFpsCap) == "function" then
    local fpsUnlocked = false
    local fpsCap = 240
    SettingsSub:AddToggle({
        Name = "Unlock FPS (Unlimited)", Default = false, Flag = "rv_fps_unlock",
        Callback = function(v)
            fpsUnlocked = v
            pcall(setFpsCap, v and 0 or fpsCap)
            Notify("FPS", v and "Unlocked (unlimited)" or ("Capped at " .. fpsCap), v and "Success" or "Info")
        end,
    })
    SettingsSub:AddSlider({
        Name = "FPS Cap", Min = 30, Max = 1000, Default = 240, Suffix = "", Flag = "rv_fps_cap",
        Callback = function(v)
            fpsCap = v
            if not fpsUnlocked then pcall(setFpsCap, v) end
        end,
    })
else
    SettingsSub:AddParagraph({
        Title = "FPS Unlock Unavailable",
        Text = "This executor does not expose setfpscap, so the FPS cap can't be changed from here.",
    })
end

if HAS_CONFIG then
    SettingsSub:AddSection("Configuration")
    SettingsSub:AddButton({
        Name = "Save Config", Primary = true,
        Callback = function()
            local ok = pcall(function() Library:SaveConfig(CONFIG_NAME) end)
            Notify("Config", ok and "Saved" or "Save failed", ok and "Success" or "Error")
        end,
    })
    SettingsSub:AddButton({
        Name = "Load Config",
        Callback = function()
            local ok = pcall(function() Library:LoadConfig(CONFIG_NAME) end)
            if ok then ResyncAll() end
            Notify("Config", ok and "Loaded" or "Load failed", ok and "Success" or "Error")
        end,
    })
else
    SettingsSub:AddParagraph({
        Title = "Config Saving Unavailable",
        Text = "This Oxide UI build does not expose the flag/config system. All other features still work.",
    })
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CLEANUP / UNLOAD
-- ══════════════════════════════════════════════════════════════════════════════
local function Cleanup()
    rage.enabled = false
    equipLoopAlive = false
    table.clear(deflecting)
    pcall(function() runSR:UnbindFromRenderStep("OxideRageRestore") end)
    noSpreadEnabled = false; ApplyNoSpread(false)
    rapidHitEnabled = false
    unlockEnabled = false; ApplyUnlockAll(false)
    spoofLoopAlive = false
    for _, c in ipairs(spoofConns) do pcall(function() c:Disconnect() end) end
    table.clear(spoofConns)
    wsEnabled = false; jpEnabled = false; infJump = false
    flyEnabled = false; noclipEnabled = false; fullbright = false
    for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
    table.clear(HUB.conns)
    for _, d in ipairs(HUB.drawings) do pcall(function() d:Remove() end) end
    table.clear(HUB.drawings)
    for _, h in pairs(HUB.highlights) do pcall(function() h:Destroy() end) end
    table.clear(HUB.highlights)
    pcall(function()
        Lighting.GlobalShadows = savedLighting.GlobalShadows
        Lighting.Ambient = savedLighting.Ambient
        if okOutdoor then pcall(function() Lighting.OutdoorAmbient = savedLighting.OutdoorAmbient end) end
        if okExp then pcall(function() Lighting.ExposureCompensation = savedLighting.ExposureCompensation end) end
    end)
    pcall(function() Window:Destroy() end)
end

function HUB.Unload()
    if HUB.dead then return end
    HUB.dead = true
    Cleanup()
end

SettingsSub:AddSection("Danger Zone")
SettingsSub:AddButton({
    Name = "Unload Hub",
    Callback = function()
        HUB.Unload()
        _G.OxideRivals = nil
    end,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- BOOT
-- ══════════════════════════════════════════════════════════════════════════════
Notify("RIVALS", "Oxide HUB loaded", "Success", 3)
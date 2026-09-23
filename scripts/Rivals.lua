-- ═══ HUB STRIP POINT — when executed through the hub ScriptLoader, which injects
--     "local Library = _G.ArcLib" above this line instead. ═══
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- RE-EXECUTION GUARD + RESOURCE TRACKING
-- ══════════════════════════════════════════════════════════════════════════════
do
    local prev = _G.ArcRivals
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, drawings = {}, highlights = {}, dead = false }
_G.ArcRivals = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end
local function trackDrawing(d) if d then table.insert(HUB.drawings, d) end; return d end

local Window = Library:CreateWindow({
    Name = "Arc HUB | RIVALS",
    LoadingAnimation = true,
    LoadingText = "Arc",
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

local function IsEnemyR(player, teamCheckOverride)
    if player == LocalPlayer then return false end
    local useTeamCheck = teamCheckOverride
    if useTeamCheck == nil then useTeamCheck = rage.teamCheck end
    if not useTeamCheck then return true end
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
            runSR:BindToRenderStep("ArcRageRestore", 101, function()
                if myRoot and myRoot.Parent then
                    myRoot.CFrame = oldCF
                    myRoot.Velocity = oldVel
                    myRoot.RotVelocity = oldRotVel
                end
                runSR:UnbindFromRenderStep("ArcRageRestore")
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

-- ── Feature registry ───────────────────────────────────────────────────────
-- The additions below live in their own scope (the chunk already has 134
-- top-level locals) and register their teardown here, so one call from Cleanup
-- restores every one of them.
local Addon = {}
function Addon.Reset()
    for _, name in ipairs({ "ResetCombat", "ResetSilent", "ResetAimbot", "ResetChams", "ResetHitFx", "ResetFX" }) do
        local fn = Addon[name]
        if type(fn) == "function" then pcall(fn) end
    end
end

do
    -- ══════════════════════════════════════════════════════════════════════════════
    -- SHARED: HIT PART LOOKUP
    -- Used by the ragebot, the silent aim and the aimbot so all three accept the
    -- same part names (R6 and R15, plus the virtual "Closest" / "Random" modes).
    -- ══════════════════════════════════════════════════════════════════════════════
    local HIT_PART_OPTIONS = {
        "Head", "Neck", "UpperTorso", "LowerTorso", "HumanoidRootPart", "Torso",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
        "Closest", "Random",
    }

    local function ResolveHitPart(char, partName)
        if not char then return nil end
        local function fc(n)
            local p = char:FindFirstChild(n)
            if p and p:IsA("BasePart") then return p end
            return nil
        end
        local torso = fc("UpperTorso") or fc("Torso") or fc("HumanoidRootPart")
        local map = {
            Head             = fc("Head"),
            Neck             = fc("Neck") or fc("Head"),
            UpperTorso       = fc("UpperTorso") or fc("Torso"),
            LowerTorso       = fc("LowerTorso") or fc("Torso"),
            HumanoidRootPart = fc("HumanoidRootPart") or torso,
            Torso            = torso,
            LeftUpperArm     = fc("LeftUpperArm") or fc("Left Arm"),
            LeftLowerArm     = fc("LeftLowerArm"),
            LeftHand         = fc("LeftHand") or fc("Left Arm"),
            RightUpperArm    = fc("RightUpperArm") or fc("Right Arm"),
            RightLowerArm    = fc("RightLowerArm"),
            RightHand        = fc("RightHand") or fc("Right Arm"),
            LeftUpperLeg     = fc("LeftUpperLeg") or fc("Left Leg"),
            LeftLowerLeg     = fc("LeftLowerLeg"),
            LeftFoot         = fc("LeftFoot") or fc("Left Leg"),
            RightUpperLeg    = fc("RightUpperLeg") or fc("Right Leg"),
            RightLowerLeg    = fc("RightLowerLeg"),
            RightFoot        = fc("RightFoot") or fc("Right Leg"),
        }
        if partName == "Closest" then
            local cam = workspace.CurrentCamera
            if cam then
                local best, bestD
                for _, p in ipairs(char:GetChildren()) do
                    if p:IsA("BasePart") then
                        local dir = (p.Position - cam.CFrame.Position)
                        if dir.Magnitude > 0.05 then
                            local d = 1 - cam.CFrame.LookVector:Dot(dir.Unit)
                            if not bestD or d < bestD then bestD = d; best = p end
                        end
                    end
                end
                if best then return best end
            end
            return fc("Head") or torso
        elseif partName == "Random" then
            local parts = {}
            for _, p in ipairs(char:GetChildren()) do
                if p:IsA("BasePart") then table.insert(parts, p) end
            end
            if #parts > 0 then return parts[math.random(1, #parts)] end
        end
        return map[partName] or fc("Head") or torso
    end

    -- ── Screen helpers ──────────────────────────────────────────────────────────
    local GuiServiceR = game:GetService("GuiService")

    local function ScreenCenter()
        local cam = workspace.CurrentCamera
        local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
        return Vector2.new(vp.X / 2, vp.Y / 2)
    end

    local function MousePoint()
        local m = uisR:GetMouseLocation()
        local inset = GuiServiceR:GetGuiInset()
        return Vector2.new(m.X, m.Y - inset.Y)
    end

    local function ScreenDistance(part, center)
        local cam = workspace.CurrentCamera
        if not cam or not part then return nil end
        local sp, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen or sp.Z <= 0 then return nil end
        return (Vector2.new(sp.X, sp.Y) - center).Magnitude
    end

    -- True when nothing solid sits between us and the target's head/root. The
    -- params object is built once and reused: this runs per target per frame.
    local visParams = RaycastParams.new()
    visParams.FilterType = Enum.RaycastFilterType.Exclude
    visParams.IgnoreWater = true

    local function LocalVisibility(char)
        if not char then return false end
        local cam = workspace.CurrentCamera
        local myChar = LocalPlayer.Character
        if not cam or not myChar then return true end
        local origin = cam.CFrame.Position
        local target = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not target then return false end
        local params = visParams
        local ok, visible = pcall(function()
            params.FilterDescendantsInstances = { myChar }
            local res = workspace:Raycast(origin, target.Position - origin, params)
            if not res or not res.Instance then return true end
            local hitModel = res.Instance:FindFirstAncestorOfClass("Model")
            return hitModel == char
        end)
        if not ok then return true end
        return visible
    end

    -- ══════════════════════════════════════════════════════════════════════════════
    -- SHARED: FOV CIRCLE RENDERING
    -- The hub's own ScreenGui belongs to the window, so the world effects live in a
    -- dedicated one that survives the UI being hidden and is destroyed on unload.
    -- ══════════════════════════════════════════════════════════════════════════════
    local FX = { gui = nil, circles = {} }

    local function FXGui()
        if FX.gui and FX.gui.Parent then return FX.gui end
        local plrGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not plrGui then return nil end
        local g = Instance.new("ScreenGui")
        g.Name = "ArcRivalsFX"
        g.ResetOnSpawn = false
        g.IgnoreGuiInset = true
        g.DisplayOrder = 4
        g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        g.Parent = plrGui
        FX.gui = g
        return g
    end

    local function MakeFovCircle(name)
        local gui = FXGui()
        if not gui then return nil end
        local holder = Instance.new("Frame")
        holder.Name = name
        holder.AnchorPoint = Vector2.new(0.5, 0.5)
        holder.BackgroundTransparency = 1
        holder.Visible = false
        holder.ZIndex = 2
        holder.Parent = gui

        local ring = Instance.new("Frame")
        ring.Size = UDim2.fromScale(1, 1)
        ring.BackgroundTransparency = 1
        ring.ZIndex = 2
        ring.Parent = holder
        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(1, 0); rc.Parent = ring
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Transparency = 0.15
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = ring
        local strokeGrad = Instance.new("UIGradient"); strokeGrad.Parent = stroke

        local fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(1, 1)
        fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        fill.BackgroundTransparency = 0.88
        fill.Visible = false
        fill.ZIndex = 1
        fill.Parent = holder
        local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = fill
        local fillGrad = Instance.new("UIGradient"); fillGrad.Parent = fill

        local circle = {
            holder = holder, stroke = stroke, strokeGrad = strokeGrad,
            fill = fill, fillGrad = fillGrad, ring = ring,
        }
        table.insert(FX.circles, circle)
        return circle
    end

    -- cfg: { radius, show, filled, fillColor, fillTransparency, outlineColor,
    --        outlineThickness, outlineTransparency, spin, spinSpeed,
    --        fillAnimated, fillSpeed, fillRotation }
    local function UpdateFovCircle(circle, cfg, center)
        if not circle then return end
        if not cfg.show or not center then
            circle.holder.Visible = false
            return
        end
        local r = math.max(4, cfg.radius or 120)
        circle.holder.Visible = true
        circle.holder.Size = UDim2.fromOffset(r * 2, r * 2)
        circle.holder.Position = UDim2.fromOffset(center.X, center.Y)
        circle.stroke.Thickness = cfg.outlineThickness or 1
        circle.stroke.Color = cfg.outlineColor or Color3.fromRGB(255, 255, 255)
        circle.stroke.Transparency = cfg.outlineTransparency or 0.15
        circle.fill.Visible = cfg.filled and true or false
        circle.fill.BackgroundColor3 = cfg.fillColor or Color3.fromRGB(255, 255, 255)
        circle.fill.BackgroundTransparency = cfg.fillTransparency or 0.88

        local t = tick()
        if cfg.spin then
            circle.strokeGrad.Rotation = (cfg.outlineRotation or 0) + (t * (cfg.spinSpeed or 1) * 90) % 360
        else
            circle.strokeGrad.Rotation = cfg.outlineRotation or 0
        end
        if cfg.fillAnimated then
            circle.fillGrad.Rotation = math.sin(t * (cfg.fillSpeed or 1)) * 180 + (cfg.fillRotation or 0)
        elseif cfg.spin then
            circle.fillGrad.Rotation = (cfg.fillRotation or 0) + (t * (cfg.spinSpeed or 1) * 90) % 360
        else
            circle.fillGrad.Rotation = cfg.fillRotation or 0
        end
        if not cfg.filled then circle.fillGrad.Rotation = 0 end
    end

    -- ══════════════════════════════════════════════════════════════════════════════
    -- COMBAT MODULES — weapon behaviour patches
    -- Each patch is installed once and gated by its own flag, so toggling is instant
    -- and the original functions are used verbatim when the feature is off.
    -- ══════════════════════════════════════════════════════════════════════════════
    local combat = {
        rapidFire = false,   -- zero the gun cooldown for the duration of a shot
        noRecoil = false,
        maxAccuracy = false, -- GameplayUtility.GetSpread -> no spread at all
        rapidAttack = false, -- melee attack cooldown
        noMuzzleFlash = false,
        antiKatana = false,  -- do not shoot / aim at a target that is parrying
    }

    local GunItemModule, MeleeItemModule, GameplayUtilityModule
    local origGunStartShoot, origMeleeStartShoot, origRecoilFn, origSpreadFn
    do
        local ok1, g = pcall(require, LocalPlayer.PlayerScripts.Modules.ItemTypes.Gun)
        if ok1 and type(g) == "table" then GunItemModule = g end
        local ok2, m = pcall(require, LocalPlayer.PlayerScripts.Modules.ItemTypes.Melee)
        if ok2 and type(m) == "table" then MeleeItemModule = m end
        local ok3, gu = pcall(require, repS.Modules.GameplayUtility)
        if ok3 and type(gu) == "table" then GameplayUtilityModule = gu end
    end

    if GunItemModule and type(GunItemModule.StartShooting) == "function" then
        origGunStartShoot = GunItemModule.StartShooting
        GunItemModule.StartShooting = function(self, ...)
            local args = table.pack(...)
            local info = self and self.Info
            local saved
            if combat.rapidFire and type(info) == "table" and info.ShootCooldown ~= nil then
                saved = info.ShootCooldown
                pcall(function() info.ShootCooldown = 0 end)
            end
            local results = table.pack(pcall(origGunStartShoot, self, table.unpack(args, 1, args.n)))
            if saved ~= nil then pcall(function() info.ShootCooldown = saved end) end
            if not results[1] then error(results[2], 0) end
            return table.unpack(results, 2, results.n)
        end
    end

    if GunItemModule and type(GunItemModule._Recoil) == "function" then
        origRecoilFn = GunItemModule._Recoil
        GunItemModule._Recoil = function(self, ...)
            if combat.noRecoil then return end
            return origRecoilFn(self, ...)
        end
    end

    if MeleeItemModule and type(MeleeItemModule.StartShooting) == "function" then
        origMeleeStartShoot = MeleeItemModule.StartShooting
        MeleeItemModule.StartShooting = function(self, ...)
            local args = table.pack(...)
            local info = self and self.Info
            local saved
            if combat.rapidAttack and type(info) == "table" and info.AttackCooldown ~= nil then
                saved = info.AttackCooldown
                pcall(function() info.AttackCooldown = 0 end)
            end
            local results = table.pack(pcall(origMeleeStartShoot, self, table.unpack(args, 1, args.n)))
            if saved ~= nil then pcall(function() info.AttackCooldown = saved end) end
            if not results[1] then error(results[2], 0) end
            return table.unpack(results, 2, results.n)
        end
    end

    if GameplayUtilityModule and type(GameplayUtilityModule.GetSpread) == "function" then
        origSpreadFn = GameplayUtilityModule.GetSpread
        GameplayUtilityModule.GetSpread = function(...)
            if combat.maxAccuracy then return CFrame.new() end
            return origSpreadFn(...)
        end
    end

    -- Muzzle flash lives inside the first-person viewmodel; the spotlight and its
    -- emitter are removed every frame while the toggle is on.
    local function StripMuzzleFlash()
        local vm = wsR:FindFirstChild("ViewModels")
        if not vm then return end
        local root = vm:FindFirstChild("FirstPerson") or vm
        for _, model in ipairs(root:GetChildren()) do
            if model:IsA("Model") then
                local itemVisual = model:FindFirstChild("ItemVisual")
                local body = itemVisual and itemVisual:FindFirstChild("Body")
                local primary = body and body:FindFirstChild("BodyPrimary")
                local muzzle = primary and primary:FindFirstChild("_muzzle")
                if muzzle then
                    for _, c in ipairs(muzzle:GetChildren()) do
                        if c:IsA("SpotLight") then
                            pcall(function() c:Destroy() end)
                        elseif c:IsA("ParticleEmitter") and (string.find(string.lower(c.Name), "muzzle", 1, true) or string.find(string.lower(c.Name), "flash", 1, true)) then
                            pcall(function() c:Destroy() end)
                        end
                    end
                end
            end
        end
    end

    local muzzleConn
    local function ApplyMuzzleFlash(on)
        if on then
            pcall(StripMuzzleFlash)
            if not muzzleConn then
                muzzleConn = runSR.RenderStepped:Connect(function()
                    if HUB.dead then return end
                    if not combat.noMuzzleFlash then return end
                    pcall(StripMuzzleFlash)
                end)
                table.insert(HUB.conns, muzzleConn)
            end
        elseif muzzleConn then
            pcall(function() muzzleConn:Disconnect() end)
            muzzleConn = nil
        end
    end

    local CombatSub = RageTab:AddSubTab("Combat")
    CombatSub:AddSection("Weapon Patches")
    CombatSub:AddToggle({
        Name = "Rapid Fire (No Cooldown)", Default = false, Flag = "rv_cmb_rapid",
        Description = "Zeroes the gun cooldown for the shot",
        Callback = function(v) combat.rapidFire = v end,
    })
    CombatSub:AddToggle({
        Name = "No Recoil", Default = false, Flag = "rv_cmb_recoil",
        Callback = function(v) combat.noRecoil = v end,
    })
    CombatSub:AddToggle({
        Name = "Max Accuracy", Default = false, Flag = "rv_cmb_accuracy",
        Description = "GameplayUtility.GetSpread returns no spread",
        Callback = function(v) combat.maxAccuracy = v end,
    })
    CombatSub:AddToggle({
        Name = "Rapid Attack (Melee)", Default = false, Flag = "rv_cmb_attack",
        Callback = function(v) combat.rapidAttack = v end,
    })
    CombatSub:AddToggle({
        Name = "No Muzzle Flash", Default = false, Flag = "rv_cmb_muzzle",
        Callback = function(v)
            combat.noMuzzleFlash = v
            ApplyMuzzleFlash(v)
        end,
    })
    CombatSub:AddToggle({
        Name = "Anti Katana", Default = false, Flag = "rv_cmb_katana",
        Description = "Never shoot or lock onto a target that is parrying",
        Callback = function(v) combat.antiKatana = v end,
    })
    CombatSub:AddParagraph({
        Title = "Note",
        Text = "These patch the live weapon modules. Rapid Fire and Rapid Attack only change the cooldown for the shot that is being fired, so the game's own timing stays intact.",
    })

    -- ══════════════════════════════════════════════════════════════════════════════
    -- SILENT AIM
    -- The shot is sent straight to the replication remote aimed at the target part,
    -- so the camera never moves and nothing is visible client side.
    -- ══════════════════════════════════════════════════════════════════════════════
    local silent = {
        enabled = false,
        autoShoot = false,
        holdKey = nil,
        hitPart = "Head",
        hitChance = 100,
        fovRadius = 120,
        maxDist = 1000,
        teamCheck = true,
        visibleCheck = false,
        weaponSlot = "Melee",
        showFov = false,
        filled = false,
        fillColor = Color3.fromRGB(255, 255, 255),
        fillTransparency = 0.9,
        fillAnimated = false,
        fillSpeed = 1,
        fillRotation = 0,
        outlineColor = Color3.fromRGB(255, 255, 255),
        outlineThickness = 1,
        outlineTransparency = 0.2,
        outlineRotation = 0,
        spin = false,
        spinSpeed = 1,
    }

    -- Keeps the configured silent-aim slot equipped while silent aim is on.
    task.spawn(function()
        while equipLoopAlive do
            task.wait(1)
            if silent.enabled and not rage.enabled and FighterController then
                local lf = FighterController.LocalFighter
                if lf then
                    pcall(function() lf:EquipItem(SLOT_NUM[silent.weaponSlot] or 3) end)
                end
            end
        end
    end)

    local silentLastFire = 0
    local silentHolding = false

    local function SilentShouldHit()
        if silent.hitChance >= 100 then return true end
        if silent.hitChance <= 0 then return false end
        return math.random(1, 100) <= silent.hitChance
    end

    local function SilentFindTarget()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
        local center = ScreenCenter()
        local best, bestDist = nil, math.huge
        for _, plr in ipairs(plrsR:GetPlayers()) do
            if plr ~= LocalPlayer and IsEnemyR(plr, silent.teamCheck) then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and root then
                    local dist = (root.Position - myRoot.Position).Magnitude
                    if dist <= silent.maxDist then
                        local sd = ScreenDistance(root, center)
                        if sd and sd <= silent.fovRadius and sd < bestDist then
                            if not silent.visibleCheck or LocalVisibility(char) then
                                bestDist = sd
                                best = char
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    local function SilentFire()
        if not silent.enabled or HUB.dead then return end
        if rage.enabled then return end            -- ragebot owns the trigger when both are on
        if not rageReady then return end
        local now = tick()
        if now - silentLastFire < RageFireDelay() then return end
        if not silentHolding then return end
        if not SilentShouldHit() then return end

        local char = SilentFindTarget()
        if not char then return end
        local plr = plrsR:GetPlayerFromCharacter(char)
        if combat.antiKatana and plr and deflecting[plr] then return end

        local part = ResolveHitPart(char, silent.hitPart)
        if not part then return end

        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local fighter = FighterController and FighterController.LocalFighter
        local item = fighter and fighter.EquippedItem
        if not item then return end
        local objId = item:Get("ObjectID")
        if not objId then return end

        silentLastFire = now
        local shootPos = myRoot.Position
        local targetPos = part.Position
        local data = {}
        data[utf8.char(1)] = {
            [utf8.char(0)] = RageUtil:EncodeCFrame(CFrame.new(shootPos, targetPos)),
            [utf8.char(1)] = RageUtil:EncodeCFrame(CFrame.new(shootPos, targetPos)),
            [utf8.char(2)] = part,
            [utf8.char(3)] = RageUtil:EncodeCFrame(CFrame.new(0.43, 0.25, 0.42)),
        }
        pcall(function()
            UseItemR:FireServer(objId, RageEnum:ToEnum("StartShooting"), data, nil)
        end)
    end

    local silentFovCircle = MakeFovCircle("SilentFOV")
    local silentLoop = runSR.RenderStepped:Connect(function()
        if HUB.dead then return end
        -- Hold tracking (LMB or the bound key)
        local holding = silent.autoShoot
            or uisR:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        if silent.holdKey then
            holding = holding or uisR:IsKeyDown(silent.holdKey)
        end
        silentHolding = holding

        if silent.enabled then
            -- The ragebot refreshes the parry map, but it is skipped while it is
            -- off, so Anti Katana would otherwise read stale data here.
            if combat.antiKatana and not rage.enabled then UpdateDeflection() end
            SilentFire()
        end

        if silentFovCircle then
            local center = ScreenCenter()
            UpdateFovCircle(silentFovCircle, {
                show = silent.enabled and silent.showFov,
                radius = silent.fovRadius,
                filled = silent.filled,
                fillColor = silent.fillColor,
                fillTransparency = silent.fillTransparency,
                fillAnimated = silent.fillAnimated,
                fillSpeed = silent.fillSpeed,
                fillRotation = silent.fillRotation,
                outlineColor = silent.outlineColor,
                outlineThickness = silent.outlineThickness,
                outlineTransparency = silent.outlineTransparency,
                outlineRotation = silent.outlineRotation,
                spin = silent.spin,
                spinSpeed = silent.spinSpeed,
            }, center)
        end
    end)
    table.insert(HUB.conns, silentLoop)

    -- ── Silent Aim UI ─────────────────────────────────────────────────────────
    local SilentSub = RageTab:AddSubTab("Silent Aim")
    SilentSub:AddSection("Silent Aim")
    SilentSub:AddToggle({
        Name = "Silent Aim", Default = false, Flag = "rv_silent",
        Callback = function(v)
            silent.enabled = v
            if v and rage.enabled then
                Notify("Silent Aim", "Ragebot is on and takes priority — turn it off to use silent aim", "Warn", 4)
            elseif v and not rageReady then
                Notify("Silent Aim", "Controllers/modules not found — unavailable", "Error", 3.5)
            else
                Notify("Silent Aim", v and "ON" or "OFF", v and "Success" or "Error")
            end
        end,
    })
    SilentSub:AddToggle({
        Name = "Auto Shoot", Default = false, Flag = "rv_silent_auto",
        Description = "Fire without holding the mouse button",
        Callback = function(v) silent.autoShoot = v end,
    })
    SilentSub:AddKeybind({
        Name = "Hold Key", Default = nil, Flag = "rv_silent_key",
        Callback = function(key) silent.holdKey = key end,
        OnKeyChanged = function(key) silent.holdKey = key end,
    })
    local applySilentSlot = function(v) silent.weaponSlot = v end
    local silentSlotDropdown = SilentSub:AddDropdown({
        Name = "Weapon Slot", Options = { "Primary", "Secondary", "Melee" }, Default = "Melee",
        MaxVisible = 3, Flag = "rv_silent_slot", Callback = applySilentSlot,
    })
    registerResync(silentSlotDropdown, applySilentSlot)
    local applySilentPart = function(v) silent.hitPart = v end
    local silentPartDropdown = SilentSub:AddDropdown({
        Name = "Hit Part", Options = HIT_PART_OPTIONS, Default = "Head", Searchable = true,
        MaxVisible = 6, Flag = "rv_silent_part", Callback = applySilentPart,
    })
    registerResync(silentPartDropdown, applySilentPart)
    SilentSub:AddSlider({
        Name = "Hit Chance", Min = 0, Max = 100, Default = 100, Suffix = "%", Flag = "rv_silent_chance",
        Callback = function(v) silent.hitChance = v end,
    })
    SilentSub:AddSlider({
        Name = "FOV Radius", Min = 10, Max = 800, Default = 120, Suffix = "px", Flag = "rv_silent_fov",
        Callback = function(v) silent.fovRadius = v end,
    })
    SilentSub:AddSlider({
        Name = "Max Distance", Min = 50, Max = 2000, Default = 1000, Suffix = "", Flag = "rv_silent_dist",
        Callback = function(v) silent.maxDist = v end,
    })
    SilentSub:AddToggle({
        Name = "Team Check", Default = true, Flag = "rv_silent_team",
        Callback = function(v) silent.teamCheck = v end,
    })
    SilentSub:AddToggle({
        Name = "Visible Only", Default = false, Flag = "rv_silent_vis",
        Callback = function(v) silent.visibleCheck = v end,
    })

    SilentSub:AddSection("FOV Circle")
    SilentSub:AddToggle({
        Name = "Show FOV", Default = false, Flag = "rv_silent_showfov",
        Callback = function(v) silent.showFov = v end,
    })
    SilentSub:AddToggle({
        Name = "Filled", Default = false, Flag = "rv_silent_filled",
        Callback = function(v) silent.filled = v end,
    })
    SilentSub:AddSlider({
        Name = "Fill Transparency", Min = 0, Max = 100, Default = 90, Suffix = "%", Flag = "rv_silent_filltrans",
        Callback = function(v) silent.fillTransparency = v / 100 end,
    })
    SilentSub:AddSlider({
        Name = "Outline Thickness", Min = 1, Max = 6, Default = 1, Suffix = "px", Flag = "rv_silent_othick",
        Callback = function(v) silent.outlineThickness = v end,
    })
    SilentSub:AddSlider({
        Name = "Outline Transparency", Min = 0, Max = 100, Default = 20, Suffix = "%", Flag = "rv_silent_otrans",
        Callback = function(v) silent.outlineTransparency = v / 100 end,
    })
    SilentSub:AddToggle({
        Name = "Spin", Default = false, Flag = "rv_silent_spin",
        Callback = function(v) silent.spin = v end,
    })
    SilentSub:AddSlider({
        Name = "Spin Speed", Min = 0, Max = 10, Default = 1, Suffix = "x", Flag = "rv_silent_spinspd",
        Callback = function(v) silent.spinSpeed = v end,
    })
    SilentSub:AddToggle({
        Name = "Animated Fill", Default = false, Flag = "rv_silent_fillanim",
        Callback = function(v) silent.fillAnimated = v end,
    })
    SilentSub:AddSlider({
        Name = "Fill Speed", Min = 0, Max = 10, Default = 1, Suffix = "x", Flag = "rv_silent_fillspd",
        Callback = function(v) silent.fillSpeed = v end,
    })
    SilentSub:AddColorPicker({
        Name = "Outline Color", Default = Color3.fromRGB(255, 255, 255), Flag = "rv_silent_ocol",
        Callback = function(c) silent.outlineColor = c end,
    })
    SilentSub:AddColorPicker({
        Name = "Fill Color", Default = Color3.fromRGB(255, 255, 255), Flag = "rv_silent_fcol",
        Callback = function(c) silent.fillColor = c end,
    })

    -- ══════════════════════════════════════════════════════════════════════════════
    -- AIMBOT
    -- Moves the real camera through Rivals' CameraController on the camera render
    -- step, so the aim is smooth and the crosshair follows it.
    -- ══════════════════════════════════════════════════════════════════════════════
    local aimbot = {
        enabled = false,
        activation = "Hold LMB",   -- Hold LMB / Always / Toggle Key
        key = nil,
        toggleState = false,
        smoothness = 3,
        curve = "Linear",
        hitPart = "Head",
        fovRadius = 160,
        maxDist = 1500,
        teamCheck = true,
        visibleCheck = false,
        followMuzzle = false,
        showFov = false,
        filled = false,
        fillColor = Color3.fromRGB(255, 255, 255),
        fillTransparency = 0.9,
        fillAnimated = false,
        fillSpeed = 1,
        fillRotation = 0,
        outlineColor = Color3.fromRGB(255, 255, 255),
        outlineThickness = 1,
        outlineTransparency = 0.2,
        outlineRotation = 0,
        spin = false,
        spinSpeed = 1,
    }

    local CameraControllerModule
    pcall(function()
        local ctrl = LocalPlayer.PlayerScripts:WaitForChild("Controllers", 5)
        local cc = ctrl and ctrl:FindFirstChild("CameraController")
        if cc and cc:IsA("ModuleScript") then CameraControllerModule = require(cc) end
    end)

    local AIMBOT_BIND = "ArcAimbotStep"
    local aimLockedPart, aimSmoothCF

    local function AimbotActive()
        if not aimbot.enabled then return false end
        if aimbot.activation == "Always" then return true end
        if aimbot.activation == "Toggle Key" then return aimbot.toggleState end
        return uisR:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or (aimbot.key ~= nil and uisR:IsKeyDown(aimbot.key))
    end

    local function AimbotLerpAlpha(dt)
        local smoothness = math.clamp(tonumber(aimbot.smoothness) or 3, 0.1, 10)
        local curve = aimbot.curve
        local speed = 6 / smoothness
        local t = math.clamp(speed * dt, 0, 1)
        if curve == "Instant" then
            return 1
        elseif curve == "Expo" then
            return 1 - math.exp(-(4 / smoothness) * dt)
        elseif curve == "EaseIn" then
            return t * t
        elseif curve == "EaseOut" then
            return 1 - (1 - t) * (1 - t)
        elseif curve == "EaseInOut" then
            if t < 0.5 then return 2 * t * t end
            return 1 - ((-2 * t + 2) ^ 2) / 2
        elseif curve == "Cubic" then
            return t * t * t
        end
        return t
    end

    local function AimbotFindPart()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
        local center = aimbot.followMuzzle and ScreenCenter() or MousePoint()
        local bestPart, bestDist = nil, math.huge
        for _, plr in ipairs(plrsR:GetPlayers()) do
            if plr ~= LocalPlayer and IsEnemyR(plr, aimbot.teamCheck) then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if char and hum and hum.Health > 0 then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root and (root.Position - myRoot.Position).Magnitude <= aimbot.maxDist then
                        local part = ResolveHitPart(char, aimbot.hitPart)
                        if part then
                            local sd = ScreenDistance(part, center)
                            if sd and sd <= aimbot.fovRadius and sd < bestDist then
                                if not aimbot.visibleCheck or LocalVisibility(char) then
                                    bestDist = sd
                                    bestPart = part
                                end
                            end
                        end
                    end
                end
            end
        end
        return bestPart
    end

    local function AimbotStep(dt)
        if HUB.dead then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        if not aimbot.enabled then
            aimLockedPart, aimSmoothCF = nil, nil
            return
        end
        if not AimbotActive() then
            aimLockedPart, aimSmoothCF = nil, nil
            return
        end
        if not aimLockedPart or not aimLockedPart.Parent or not aimLockedPart:IsDescendantOf(workspace) then
            aimLockedPart = AimbotFindPart()
            aimSmoothCF = cam.CFrame
            if not aimLockedPart then return end
        end
        if not aimSmoothCF then aimSmoothCF = cam.CFrame end
        local lookCF = CFrame.lookAt(cam.CFrame.Position, aimLockedPart.Position)
        aimSmoothCF = aimSmoothCF:Lerp(lookCF, AimbotLerpAlpha(dt or (1 / 240)))
        if CameraControllerModule and type(CameraControllerModule.MimicRotation) == "function" then
            pcall(function() CameraControllerModule:MimicRotation(aimSmoothCF) end)
        end
    end

    local aimbotBound = false
    local function AimbotRebind()
        if aimbotBound then
            pcall(function() runSR:UnbindFromRenderStep(AIMBOT_BIND) end)
            aimbotBound = false
        end
        if not aimbot.enabled then
            aimLockedPart, aimSmoothCF = nil, nil
            return
        end
        local ok = pcall(function()
            runSR:BindToRenderStep(AIMBOT_BIND, Enum.RenderPriority.Camera.Value + 1, AimbotStep)
        end)
        aimbotBound = ok
    end

    local aimbotFovCircle = MakeFovCircle("AimbotFOV")
    local aimbotLoop = runSR.RenderStepped:Connect(function()
        if HUB.dead then return end
        AimbotRebind()
        if aimbotFovCircle then
            local center = aimbot.followMuzzle and ScreenCenter() or MousePoint()
            UpdateFovCircle(aimbotFovCircle, {
                show = aimbot.enabled and aimbot.showFov and AimbotActive(),
                radius = aimbot.fovRadius,
                filled = aimbot.filled,
                fillColor = aimbot.fillColor,
                fillTransparency = aimbot.fillTransparency,
                fillAnimated = aimbot.fillAnimated,
                fillSpeed = aimbot.fillSpeed,
                fillRotation = aimbot.fillRotation,
                outlineColor = aimbot.outlineColor,
                outlineThickness = aimbot.outlineThickness,
                outlineTransparency = aimbot.outlineTransparency,
                outlineRotation = aimbot.outlineRotation,
                spin = aimbot.spin,
                spinSpeed = aimbot.spinSpeed,
            }, center)
        end
    end)
    table.insert(HUB.conns, aimbotLoop)

    -- ── Aimbot UI ─────────────────────────────────────────────────────────────
    local AimbotSub = RageTab:AddSubTab("Aimbot")
    AimbotSub:AddSection("Aimbot")
    AimbotSub:AddToggle({
        Name = "Aimbot", Default = false, Flag = "rv_aim",
        Callback = function(v)
            aimbot.enabled = v
            AimbotRebind()
            if v and not CameraControllerModule then
                Notify("Aimbot", "CameraController not found — aim may not follow", "Warn", 3.5)
            else
                Notify("Aimbot", v and "ON" or "OFF", v and "Success" or "Error")
            end
        end,
    })
    local applyActivation = function(v) aimbot.activation = v; aimbot.toggleState = false end
    local activationDropdown = AimbotSub:AddDropdown({
        Name = "Activation", Options = { "Hold LMB", "Always", "Toggle Key" }, Default = "Hold LMB",
        MaxVisible = 3, Flag = "rv_aim_activation", Callback = applyActivation,
    })
    registerResync(activationDropdown, applyActivation)
    AimbotSub:AddKeybind({
        Name = "Aim Key", Default = nil, Flag = "rv_aim_key",
        Callback = function(key)
            aimbot.key = key
            if aimbot.activation == "Toggle Key" and key ~= nil then
                aimbot.toggleState = not aimbot.toggleState
            end
        end,
        OnKeyChanged = function(key) aimbot.key = key end,
    })
    local applyAimPart = function(v) aimbot.hitPart = v end
    local aimPartDropdown = AimbotSub:AddDropdown({
        Name = "Hit Part", Options = HIT_PART_OPTIONS, Default = "Head", Searchable = true,
        MaxVisible = 6, Flag = "rv_aim_part", Callback = applyAimPart,
    })
    registerResync(aimPartDropdown, applyAimPart)
    AimbotSub:AddSlider({
        Name = "Smoothness", Min = 1, Max = 10, Default = 3, Suffix = "", Flag = "rv_aim_smooth",
        Callback = function(v) aimbot.smoothness = v end,
    })
    local applyCurve = function(v) aimbot.curve = v end
    local curveDropdown = AimbotSub:AddDropdown({
        Name = "Curve", Options = { "Linear", "Instant", "Expo", "EaseIn", "EaseOut", "EaseInOut", "Cubic" },
        Default = "Linear", MaxVisible = 5, Flag = "rv_aim_curve", Callback = applyCurve,
    })
    registerResync(curveDropdown, applyCurve)
    AimbotSub:AddSlider({
        Name = "FOV Radius", Min = 10, Max = 800, Default = 160, Suffix = "px", Flag = "rv_aim_fov",
        Callback = function(v) aimbot.fovRadius = v end,
    })
    AimbotSub:AddSlider({
        Name = "Max Distance", Min = 50, Max = 3000, Default = 1500, Suffix = "", Flag = "rv_aim_dist",
        Callback = function(v) aimbot.maxDist = v end,
    })
    AimbotSub:AddToggle({
        Name = "Team Check", Default = true, Flag = "rv_aim_team",
        Callback = function(v) aimbot.teamCheck = v end,
    })
    AimbotSub:AddToggle({
        Name = "Visible Only", Default = false, Flag = "rv_aim_vis",
        Callback = function(v) aimbot.visibleCheck = v end,
    })
    AimbotSub:AddToggle({
        Name = "FOV Follows Crosshair", Default = false, Flag = "rv_aim_muzzle",
        Description = "Center of the FOV circle follows your crosshair instead of the mouse",
        Callback = function(v) aimbot.followMuzzle = v end,
    })

    AimbotSub:AddSection("FOV Circle")
    AimbotSub:AddToggle({
        Name = "Show FOV", Default = false, Flag = "rv_aim_showfov",
        Callback = function(v) aimbot.showFov = v end,
    })
    AimbotSub:AddToggle({
        Name = "Filled", Default = false, Flag = "rv_aim_filled",
        Callback = function(v) aimbot.filled = v end,
    })
    AimbotSub:AddSlider({
        Name = "Fill Transparency", Min = 0, Max = 100, Default = 90, Suffix = "%", Flag = "rv_aim_filltrans",
        Callback = function(v) aimbot.fillTransparency = v / 100 end,
    })
    AimbotSub:AddSlider({
        Name = "Outline Thickness", Min = 1, Max = 6, Default = 1, Suffix = "px", Flag = "rv_aim_othick",
        Callback = function(v) aimbot.outlineThickness = v end,
    })
    AimbotSub:AddSlider({
        Name = "Outline Transparency", Min = 0, Max = 100, Default = 20, Suffix = "%", Flag = "rv_aim_otrans",
        Callback = function(v) aimbot.outlineTransparency = v / 100 end,
    })
    AimbotSub:AddToggle({
        Name = "Spin", Default = false, Flag = "rv_aim_spin",
        Callback = function(v) aimbot.spin = v end,
    })
    AimbotSub:AddSlider({
        Name = "Spin Speed", Min = 0, Max = 10, Default = 1, Suffix = "x", Flag = "rv_aim_spinspd",
        Callback = function(v) aimbot.spinSpeed = v end,
    })
    AimbotSub:AddToggle({
        Name = "Animated Fill", Default = false, Flag = "rv_aim_fillanim",
        Callback = function(v) aimbot.fillAnimated = v end,
    })
    AimbotSub:AddSlider({
        Name = "Fill Speed", Min = 0, Max = 10, Default = 1, Suffix = "x", Flag = "rv_aim_fillspd",
        Callback = function(v) aimbot.fillSpeed = v end,
    })
    AimbotSub:AddColorPicker({
        Name = "Outline Color", Default = Color3.fromRGB(255, 255, 255), Flag = "rv_aim_ocol",
        Callback = function(c) aimbot.outlineColor = c end,
    })
    AimbotSub:AddColorPicker({
        Name = "Fill Color", Default = Color3.fromRGB(255, 255, 255), Flag = "rv_aim_fcol",
        Callback = function(c) aimbot.fillColor = c end,
    })

        -- ── Teardown ────────────────────────────────────────────────────────────
        Addon.ResetCombat = function()
            combat.rapidFire = false
            combat.noRecoil = false
            combat.maxAccuracy = false
            combat.rapidAttack = false
            combat.noMuzzleFlash = false
            combat.antiKatana = false
            if muzzleConn then
                pcall(function() muzzleConn:Disconnect() end)
                muzzleConn = nil
            end
        end

        Addon.ResetSilent = function()
            silent.enabled = false
            silent.autoShoot = false
            silentHolding = false
            if silentFovCircle then
                pcall(function() silentFovCircle.holder.Visible = false end)
            end
        end

        Addon.ResetAimbot = function()
            aimbot.enabled = false
            aimbot.toggleState = false
            aimLockedPart, aimSmoothCF = nil, nil
            if aimbotBound then
                pcall(function() runSR:UnbindFromRenderStep(AIMBOT_BIND) end)
                aimbotBound = false
            end
        end

        Addon.ResetFX = function()
            if FX.gui then
                pcall(function() FX.gui:Destroy() end)
                FX.gui = nil
            end
            table.clear(FX.circles)
        end
end


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
        local sp = Camera:WorldToViewportPoint(corner)
        if sp.Z > 0 then
            anyOn = true
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
        for _, d in ipairs({ o.frame, o.outline, o.fill, o.name, o.dist, o.tracer, o.hpBack, o.hp, o.hpText, o.weapon }) do
            pcall(function() if d then d.Visible = false end end)
        end
        for _, l in ipairs(o.corners) do pcall(function() if l then l.Visible = false end end) end
        for _, l in ipairs(o.skel) do pcall(function() if l then l.Visible = false end end) end
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
                                pcall(function()
                                    o.tracer.Visible = true
                                    o.tracer.Color = rainbow or esp.color
                                    local sp = Camera:WorldToViewportPoint((hrp or char):GetPivot().Position)
                                    if sp.Z > 0 then
                                        local origin = center
                                        if esp.tracerOrigin == "Bottom" then origin = Vector2.new(center.X, Camera.ViewportSize.Y)
                                        elseif esp.tracerOrigin == "Top" then origin = Vector2.new(center.X, 0)
                                        elseif esp.tracerOrigin == "Mouse" then origin = UserInputService:GetMouseLocation() end
                                        o.tracer.From = origin
                                        o.tracer.To = Vector2.new(sp.X, sp.Y)
                                    end
                                end)
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
                                                if okA and okB and sa.Z > 0 and sb.Z > 0 then
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

do
    -- ══════════════════════════════════════════════════════════════════════════════
    -- CHAMS — recolour player characters (and optionally outline them)
    -- The original Material/Color/Transparency of every touched part is stored so
    -- the character is restored exactly when the feature is turned off.
    -- ══════════════════════════════════════════════════════════════════════════════
    local chams = {
        enabled = false,
        material = "ForceField",
        fillColor = Color3.fromRGB(130, 130, 255),
        teamColor = false,
        transparency = 0.35,
        outline = false,
        outlineColor = Color3.fromRGB(255, 255, 255),
        teamCheck = true,
        maxDist = 2000,
        refreshRate = 0.25,
    }

    local CHAM_MATERIALS = { "ForceField", "Neon", "Glass", "Plastic", "SmoothPlastic", "Metal", "Marble", "Ice", "Foil" }
    local CHAM_MATERIAL_ENUM = {
        ForceField = Enum.Material.ForceField, Neon = Enum.Material.Neon, Glass = Enum.Material.Glass,
        Plastic = Enum.Material.Plastic, SmoothPlastic = Enum.Material.SmoothPlastic,
        Metal = Enum.Material.Metal, Marble = Enum.Material.Marble,
        Ice = Enum.Material.Ice, Foil = Enum.Material.Foil,
    }
    local chamEntries = {}   -- [player] = { highlight = Highlight, parts = { [part] = {Material, Color, Transparency} } }
    local chamAccum = 0

    local function ChamTeamColor(plr)
        if not chams.teamColor then return chams.fillColor end
        local ok, team = pcall(function() return plr.Team end)
        if ok and team and team.TeamColor then return team.TeamColor.Color end
        return chams.fillColor
    end

    local function RestoreChams(entry)
        if not entry then return end
        for part, saved in pairs(entry.parts) do
            if part and part.Parent then
                pcall(function()
                    part.Material = saved.Material
                    part.Color = saved.Color
                    part.Transparency = saved.Transparency
                end)
            end
        end
        table.clear(entry.parts)
        if entry.highlight then
            pcall(function() entry.highlight:Destroy() end)
            entry.highlight = nil
        end
    end

    local function ApplyChams(plr, char)
        local entry = chamEntries[plr]
        if not entry then
            entry = { parts = {} }
            chamEntries[plr] = entry
        end
        local col = ChamTeamColor(plr)
        local material = CHAM_MATERIAL_ENUM[chams.material] or Enum.Material.ForceField
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("MeshPart") then
                if not entry.parts[d] then
                    entry.parts[d] = { Material = d.Material, Color = d.Color, Transparency = d.Transparency }
                end
            pcall(function()
                d.Material = material
                    d.Color = col
                    d.Transparency = chams.transparency
                end)
            end
        end
        if chams.outline then
            if not entry.highlight or not entry.highlight.Parent then
                local h = Instance.new("Highlight")
                h.Name = "ArcChamOutline"
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.FillTransparency = 1
                h.Parent = char
                entry.highlight = h
                table.insert(HUB.highlights, h)
            end
            pcall(function()
                entry.highlight.OutlineColor = chams.outlineColor
                entry.highlight.OutlineTransparency = 0
            end)
        elseif entry.highlight then
            pcall(function() entry.highlight:Destroy() end)
            entry.highlight = nil
        end
    end

    local function ChamsLoop(dt)
        if not chams.enabled then
            chamAccum = 0
            return
        end
        chamAccum = chamAccum + dt
        if chamAccum < chams.refreshRate then return end
        chamAccum = 0
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        for _, plr in ipairs(plrsR:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local ok = char and hum and hum.Health > 0
                if ok and chams.teamCheck then ok = IsEnemyR(plr, true) end
                if ok and myRoot and root and chams.maxDist > 0 then
                    ok = (root.Position - myRoot.Position).Magnitude <= chams.maxDist
                end
                if ok then
                    ApplyChams(plr, char)
                elseif chamEntries[plr] then
                    RestoreChams(chamEntries[plr])
                end
            end
        end
    end

    local function DisableChams()
        for plr, entry in pairs(chamEntries) do
            RestoreChams(entry)
            chamEntries[plr] = nil
        end
    end

    local ChamsSub = VisualsTab:AddSubTab("Chams")
    ChamsSub:AddSection("Player Chams")
    ChamsSub:AddToggle({
        Name = "Chams", Default = false, Flag = "rv_chams",
        Callback = function(v)
            chams.enabled = v
            if not v then DisableChams() end
        end,
    })
    local applyChamMaterial = function(v) chams.material = v end
    local chamMaterialDropdown = ChamsSub:AddDropdown({
        Name = "Material", Options = CHAM_MATERIALS, Default = "ForceField", MaxVisible = 5,
        Flag = "rv_chams_material", Callback = applyChamMaterial,
    })
    registerResync(chamMaterialDropdown, applyChamMaterial)
    ChamsSub:AddSlider({
        Name = "Transparency", Min = 0, Max = 100, Default = 35, Suffix = "%", Flag = "rv_chams_trans",
        Callback = function(v) chams.transparency = v / 100 end,
    })
    ChamsSub:AddColorPicker({
        Name = "Fill Color", Default = chams.fillColor, Flag = "rv_chams_color",
        Callback = function(c) chams.fillColor = c end,
    })
    ChamsSub:AddToggle({
        Name = "Use Team Color", Default = false, Flag = "rv_chams_teamcolor",
        Callback = function(v) chams.teamColor = v end,
    })
    ChamsSub:AddToggle({
        Name = "Team Check", Default = true, Flag = "rv_chams_team",
        Callback = function(v) chams.teamCheck = v end,
    })
    ChamsSub:AddSlider({
        Name = "Max Distance", Min = 0, Max = 5000, Default = 2000, Suffix = "", Flag = "rv_chams_dist",
        Callback = function(v) chams.maxDist = v end,
    })
    ChamsSub:AddSection("Outline")
    ChamsSub:AddToggle({
        Name = "Outline", Default = false, Flag = "rv_chams_outline",
        Callback = function(v) chams.outline = v end,
    })
    ChamsSub:AddColorPicker({
        Name = "Outline Color", Default = Color3.fromRGB(255, 255, 255), Flag = "rv_chams_outcol",
        Callback = function(c) chams.outlineColor = c end,
    })

    -- ══════════════════════════════════════════════════════════════════════════════
    -- HIT FX — hit sounds, kill sounds and damage notifications
    -- Enemy health is sampled on a slow loop; a drop is our hit. That keeps the
    -- whole thing passive (no remote hooks) and works for guns and melee alike.
    -- ══════════════════════════════════════════════════════════════════════════════
    local HIT_SOUNDS = {
        ["Rust HS"]        = "rbxassetid://5043539486",
        ["CSGO"]           = "rbxassetid://5764885315",
        ["Minecraft Hit"]  = "rbxassetid://8766809464",
        ["Bonk"]           = "rbxassetid://5766898159",
        ["Pop"]            = "rbxassetid://198598793",
        ["Bubble"]         = "rbxassetid://6534947588",
        ["Skeet"]          = "rbxassetid://5633695679",
        ["Custom"]         = nil,
    }

    local hitfx = {
        sounds = false,
        soundStyle = "Rust HS",
        customId = "",
        volume = 1,
        pitch = 1,
        killSound = false,
        notifications = false,
        notifDuration = 1.4,
        notifTextSize = 18,
        notifPosition = "Center",
        notifOffsetX = 0,
        notifOffsetY = -90,
        stackGap = 20,
        maxDist = 400,
    }

    local hitfxLast = {}
    local notifs = {}

    local function HitSoundId()
        if hitfx.soundStyle == "Custom" then return hitfx.customId end
        return HIT_SOUNDS[hitfx.soundStyle]
    end

    local function PlayAimSound(id, volume, pitch)
        if type(id) ~= "string" or id == "" then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local snd = Instance.new("Sound")
        snd.SoundId = id
        snd.Volume = volume or 1
        snd.Pitch = pitch or 1
        snd.Parent = cam
        pcall(function() snd:Play() end)
        task.delay(4, function() pcall(function() snd:Destroy() end) end)
    end

    local function NotifBase()
        local cam = workspace.CurrentCamera
        local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
        if hitfx.notifPosition == "Top" then
            return Vector2.new(vp.X / 2, 120)
        elseif hitfx.notifPosition == "Bottom" then
            return Vector2.new(vp.X / 2, vp.Y - 140)
        elseif hitfx.notifPosition == "Left" then
            return Vector2.new(220, vp.Y / 2)
        elseif hitfx.notifPosition == "Right" then
            return Vector2.new(vp.X - 220, vp.Y / 2)
        end
        return Vector2.new(vp.X / 2, vp.Y / 2)
    end

    local function PushHitNotif(text, color)
        if not hasDrawing then return end
        local ok, d = pcall(function() return Drawing.new("Text") end)
        if not ok or not d then return end
        pcall(function()
            d.Text = text
            d.Color = color or Color3.fromRGB(255, 255, 255)
            d.Size = hitfx.notifTextSize
            d.Center = true
            d.Outline = true
            d.OutlineColor = Color3.new(0, 0, 0)
            d.Visible = true
        end)
        local base = NotifBase()
        table.insert(notifs, {
            drawing = d,
            born = tick(),
            baseX = base.X + hitfx.notifOffsetX,
            baseY = base.Y + hitfx.notifOffsetY,
        })
    end

    local function UpdateNotifs()
        for i = #notifs, 1, -1 do
            local n = notifs[i]
            local age = tick() - n.born
            if age >= hitfx.notifDuration or not n.drawing then
                pcall(function() n.drawing:Remove() end)
                table.remove(notifs, i)
            else
                local p = age / hitfx.notifDuration
                local stack = 0
                for j = i + 1, #notifs do stack = stack + 1 end
                pcall(function()
                    n.drawing.Position = Vector2.new(n.baseX, n.baseY + stack * hitfx.stackGap - p * 18)
                    n.drawing.Transparency = p
                end)
            end
        end
    end

    local hitfxAccum = 0
    local function HitFxLoop(dt)
        UpdateNotifs()
        if not (hitfx.sounds or hitfx.killSound or hitfx.notifications) then return end
        hitfxAccum = hitfxAccum + dt
        if hitfxAccum < 0.15 then return end
        hitfxAccum = 0
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        for _, plr in ipairs(plrsR:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    local prev = hitfxLast[plr]
                    local now = hum.Health
                    local root = char:FindFirstChild("HumanoidRootPart")
                    local dist = (myRoot and root) and (myRoot.Position - root.Position).Magnitude or 0
                    local inRange = hitfx.maxDist <= 0 or dist <= hitfx.maxDist
                    if prev and inRange and now < prev then
                        local killed = now <= 0 and prev > 0
                        local damage = math.floor(prev - now + 0.5)
                        if hitfx.sounds then PlayAimSound(HitSoundId(), hitfx.volume, hitfx.pitch) end
                        if hitfx.killSound and killed then PlayAimSound(HitSoundId(), hitfx.volume, hitfx.pitch) end
                        if hitfx.notifications then
                            if killed then
                                PushHitNotif("KILL  " .. plr.DisplayName, Color3.fromRGB(255, 120, 120))
                            else
                                PushHitNotif("-" .. tostring(damage) .. "  " .. plr.DisplayName, Color3.fromRGB(255, 235, 140))
                            end
                        end
                    end
                    hitfxLast[plr] = now
                else
                    hitfxLast[plr] = nil
                end
            end
        end
    end

    local fxLoop = runSR.RenderStepped:Connect(function(dt)
        if HUB.dead then return end
        ChamsLoop(dt)
        HitFxLoop(dt)
    end)
    table.insert(HUB.conns, fxLoop)

    local HitFxSub = VisualsTab:AddSubTab("Hit FX")
    HitFxSub:AddSection("Hit Sound")
    HitFxSub:AddToggle({
        Name = "Hit Sounds", Default = false, Flag = "rv_hitsnd",
        Callback = function(v) hitfx.sounds = v end,
    })
    local applyHitSound = function(v) hitfx.soundStyle = v end
    local hitSoundDropdown = HitFxSub:AddDropdown({
        Name = "Sound", Options = { "Rust HS", "CSGO", "Minecraft Hit", "Bonk", "Pop", "Bubble", "Skeet", "Custom" },
        Default = "Rust HS", MaxVisible = 5, Flag = "rv_hitsnd_style", Callback = applyHitSound,
    })
    registerResync(hitSoundDropdown, applyHitSound)
    HitFxSub:AddInput({
        Name = "Custom SoundId", Placeholder = "rbxassetid://", Flag = "rv_hitsnd_custom",
        Callback = function(t)
            if t == nil or t == "" then hitfx.customId = "" return end
            if string.find(t, "^%d+$") then t = "rbxassetid://" .. t end
            hitfx.customId = t
        end,
    })
    HitFxSub:AddSlider({
        Name = "Volume", Min = 0, Max = 30, Default = 10, Suffix = "", Flag = "rv_hitsnd_vol",
        Callback = function(v) hitfx.volume = v / 10 end,
    })
    HitFxSub:AddSlider({
        Name = "Pitch", Min = 5, Max = 30, Default = 10, Suffix = "", Flag = "rv_hitsnd_pitch",
        Callback = function(v) hitfx.pitch = v / 10 end,
    })
    HitFxSub:AddToggle({
        Name = "Kill Sound", Default = false, Flag = "rv_hitsnd_kill",
        Callback = function(v) hitfx.killSound = v end,
    })
    HitFxSub:AddSlider({
        Name = "Max Distance", Min = 0, Max = 2000, Default = 400, Suffix = "", Flag = "rv_hitsnd_dist",
        Description = "0 = any distance",
        Callback = function(v) hitfx.maxDist = v end,
    })

    HitFxSub:AddSection("Hit Notifications")
    HitFxSub:AddToggle({
        Name = "Hit Notifications", Default = false, Flag = "rv_hitnotif",
        Callback = function(v) hitfx.notifications = v end,
    })
    HitFxSub:AddSlider({
        Name = "Duration", Min = 1, Max = 40, Default = 14, Suffix = "", Flag = "rv_hitnotif_dur",
        Description = "1 = 0.1s",
        Callback = function(v) hitfx.notifDuration = v / 10 end,
    })
    HitFxSub:AddSlider({
        Name = "Text Size", Min = 10, Max = 30, Default = 18, Suffix = "", Flag = "rv_hitnotif_size",
        Callback = function(v) hitfx.notifTextSize = v end,
    })
    local applyNotifPos = function(v) hitfx.notifPosition = v end
    local notifPosDropdown = HitFxSub:AddDropdown({
        Name = "Position", Options = { "Center", "Top", "Bottom", "Left", "Right" }, Default = "Center",
        MaxVisible = 5, Flag = "rv_hitnotif_pos", Callback = applyNotifPos,
    })
    registerResync(notifPosDropdown, applyNotifPos)
    HitFxSub:AddSlider({
        Name = "Offset X", Min = -800, Max = 800, Default = 0, Suffix = "", Flag = "rv_hitnotif_ox",
        Callback = function(v) hitfx.notifOffsetX = v end,
    })
    HitFxSub:AddSlider({
        Name = "Offset Y", Min = -800, Max = 800, Default = -90, Suffix = "", Flag = "rv_hitnotif_oy",
        Callback = function(v) hitfx.notifOffsetY = v end,
    })
    HitFxSub:AddSlider({
        Name = "Stack Gap", Min = 10, Max = 60, Default = 20, Suffix = "px", Flag = "rv_hitnotif_gap",
        Callback = function(v) hitfx.stackGap = v end,
    })
    HitFxSub:AddParagraph({
        Title = "Note",
        Text = "A hit is detected by watching enemy health, so it also counts damage from teammates and works with every weapon.",
    })

        -- ── Teardown ────────────────────────────────────────────────────────────
        Addon.ResetChams = function()
            chams.enabled = false
            DisableChams()
        end

        Addon.ResetHitFx = function()
            hitfx.sounds = false
            hitfx.killSound = false
            hitfx.notifications = false
            for i = #notifs, 1, -1 do
                pcall(function() notifs[i].drawing:Remove() end)
                table.remove(notifs, i)
            end
        end
end

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
local unlockFinishers = true
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
    if unlockFinishers and t == "Finisher" then
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

        -- OwnsCosmetic: every Skin/Charm/Dance/Emote/Wrap/Finisher is owned
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
                        if cosmeticType == "Skin" or cosmeticType == "Charm" or cosmeticType == "Wrap" or cosmeticType == "Wrapping" or cosmeticType == "Finisher" then
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
            Notify("Unlock All", v and "All cosmetics unlocked" or "Unlock All off", v and "Success" or "Error")
        end
    end,
})
UnlockSub:AddToggle({
    Name = "Include Finishers", Default = true, Flag = "rv_unlock_finish",
    Callback = function(v)
        unlockFinishers = v
        Notify("Unlock All", v and "Finishers included" or "Finishers excluded", v and "Success" or "Error")
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
        Text = "This Arc UI build does not expose the flag/config system. All other features still work.",
    })
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CLEANUP / UNLOAD
-- ══════════════════════════════════════════════════════════════════════════════
local function Cleanup()
    rage.enabled = false
    Addon.Reset()
    equipLoopAlive = false
    table.clear(deflecting)
    pcall(function() runSR:UnbindFromRenderStep("ArcRageRestore") end)
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
        _G.ArcRivals = nil
    end,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- BOOT
-- ══════════════════════════════════════════════════════════════════════════════
Notify("RIVALS", "Arc HUB loaded", "Success", 3)
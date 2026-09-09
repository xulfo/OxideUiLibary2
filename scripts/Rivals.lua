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
-- AIM TAB
-- ══════════════════════════════════════════════════════════════════════════════
local AimTab = Window:AddTab({ Name = "Aim", Subtitle = "Silent aim & FOV", Icon = "crosshair" })

local aim = {
    enabled = false,
    maxDist = 200,
    teamCheck = true,
    jitter = true,
    fov = 180,
    showFOV = true,
    fovColor = Color3.fromRGB(255, 255, 255),
    fovThickness = 1.5,
    fovFilled = false,
    fovRainbow = false,
    targetLine = false,
    targetLineColor = Color3.fromRGB(120, 200, 255),
}

-- Ragebot config (declared before the hooks because the UseItem hook closure
-- needs to skip cam-data overrides while the ragebot is driving its own shots).
local rage = {
    enabled = false,
    fireRate = 0.0005,
    weaponSlot = "Melee", -- Primary / Secondary / Melee
    maxDist = 500,
    teamCheck = true,
    deflectCheck = true,
    desync = true,
    knifeAdjust = true,
    randomOffset = true,
}

-- ── FOV circle ────────────────────────────────────────────────────────────
local fovCircle = hasDrawing and newDrawing("Circle", {
    Thickness = 1.5, NumSides = 64, Radius = 180, Filled = false,
    Visible = false, Color = Color3.fromRGB(255, 255, 255), Transparency = 1,
}) or nil
if fovCircle then pcall(function() fovCircle.ZIndex = 5 end) end

local targetLine = hasDrawing and newDrawing("Line", { Thickness = 1.5, Visible = false, Color = Color3.fromRGB(120, 200, 255) }) or nil

local fovRenderConn = RunService.RenderStepped:Connect(function()
    if HUB.dead then return end
    local enabled = aim.enabled
    if fovCircle then
        local show = enabled and aim.showFOV
        fovCircle.Visible = show
        if show then
            pcall(function()
                fovCircle.Radius = aim.fov
                fovCircle.Thickness = aim.fovThickness
                fovCircle.Filled = aim.fovFilled
                fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                if aim.fovRainbow then
                    fovCircle.Color = Color3.fromHSV((tick() % 5) / 5, 0.85, 1)
                else
                    fovCircle.Color = aim.fovColor
                end
            end)
        end
    end
end)
table.insert(HUB.conns, fovRenderConn)

-- ── Target acquisition ────────────────────────────────────────────────────
-- Distance-based closest-enemy lock (TeamID attribute team check), exactly
-- like the verified working script. Returns the target PLAYER.
local targetCache = { player = nil, at = 0 }
local TARGET_TTL = 0.05

local function FindTarget()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local myTeam = LocalPlayer:GetAttribute("TeamID")
    local closest, closestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then
            -- skip self
        else
            local pTeam = player:GetAttribute("TeamID")
            if not (aim.teamCheck and pTeam and myTeam and pTeam == myTeam) then
                local char = player.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    local head = char:FindFirstChild("Head")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if root and head and hum and hum.Health > 0 then
                        local dist = (myRoot.Position - root.Position).Magnitude
                        if dist <= aim.maxDist and dist < closestDist then
                            closestDist = dist
                            closest = player
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function GetTarget(force)
    if not aim.enabled then
        targetCache.player = nil
        return nil
    end
    local now = os.clock()
    if not force and now - targetCache.at < TARGET_TTL then
        return targetCache.player
    end
    targetCache.at = now
    targetCache.player = FindTarget()
    return targetCache.player
end

-- ── StartShooting hook (silent aim core) ─────────────────────────────────
-- Hooks Gun.StartShooting, rewrites the camdata table it returns (index 3)
-- so the shot registers on the target's head (index 4 = true), and desyncs
-- your character under the target first so the shot ignores walls.
local origStartShooting
local desyncActive = false
local desyncCurr = nil
local desyncConn = nil
local desyncTask = nil

local function StopDesync()
    desyncActive = false
    desyncCurr = nil
    if desyncConn then
        pcall(function() desyncConn:Disconnect() end)
        desyncConn = nil
    end
    if desyncTask then
        pcall(function() task.cancel(desyncTask) end)
        desyncTask = nil
    end
    pcall(function() RunService:UnbindFromRenderStep("OxideWB") end)
end

local function StartDesync(targetPlayer)
    if desyncConn then pcall(function() desyncConn:Disconnect() end) end
    desyncActive = true
    desyncCurr = targetPlayer
    desyncConn = RunService.Heartbeat:Connect(function()
        if not desyncActive then return end
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local tRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not tRoot then
            StopDesync()
            return
        end
        local oldCF = myRoot.CFrame
        local oldVel = myRoot.Velocity
        local oldRotVel = myRoot.RotVelocity
        myRoot.CFrame = tRoot.CFrame * CFrame.new(0, -5, 0)
        RunService:BindToRenderStep("OxideWB", 101, function()
            if myRoot and myRoot.Parent then
                myRoot.CFrame = oldCF
                myRoot.Velocity = oldVel
                myRoot.RotVelocity = oldRotVel
            end
            RunService:UnbindFromRenderStep("OxideWB")
        end)
    end)
end

local function InstallSilentAim()
    if origStartShooting then return end
    if not GunMod or type(GunMod.StartShooting) ~= "function" then return end
    origStartShooting = GunMod.StartShooting
    GunMod.StartShooting = function(self, ...)
        local results = { origStartShooting(self, ...) }
        -- Only touch shots from the local player's fighter
        if not self.ClientFighter or not self.ClientFighter.IsLocalPlayer then
            return unpack(results)
        end
        local camdata = results[3]
        if not camdata or typeof(camdata) ~= "table" then
            return unpack(results)
        end
        results[4] = true
        local targetPlayer = GetTarget()
        if not targetPlayer or not targetPlayer.Character then
            return unpack(results)
        end

        -- Desync under the target before the shot registers
        if not desyncActive or desyncCurr ~= targetPlayer then
            StartDesync(targetPlayer)
            task.wait(0.1)
        end
        if desyncTask then
            pcall(function() task.cancel(desyncTask) end)
            desyncTask = nil
        end

        local head = targetPlayer.Character:FindFirstChild("Head")
        if not head then return unpack(results) end

        local headPos = head.Position
        local headCF = head.CFrame
        local originPos = headPos - Vector3.new(0, 5, 0)
        local aimCF = CFrame.lookAt(originPos, headPos)
        local orient = aimCF:ToOrientation()
        local jitter = Vector3.zero
        if aim.jitter then
            jitter = Vector3.new(math.random(), math.random(), math.random())
        end
        local objOffset = headCF:ToObjectSpace(CFrame.new(headPos + jitter))

        camdata[utf8.char(0)] = U:EncodeCFrame(CFrame.new(originPos, headPos) * CFrame.Angles(orient))
        camdata[utf8.char(1)] = U:EncodeCFrame(CFrame.new(headPos) * CFrame.Angles(orient))
        camdata[utf8.char(2)] = head
        camdata[utf8.char(3)] = U:EncodeCFrame(objOffset)

        desyncTask = task.delay(0.15, function()
            StopDesync()
        end)
        return unpack(results)
    end
end

local function UninstallSilentAim()
    if origStartShooting and GunMod then
        pcall(function() GunMod.StartShooting = origStartShooting end)
        origStartShooting = nil
    end
    StopDesync()
end

-- ── Aim UI ────────────────────────────────────────────────────────────────
local SilentSub = AimTab:AddSubTab("Silent Aim")

SilentSub:AddSection("Silent Aim")
SilentSub:AddToggle({
    Name = "Silent Aim", Default = false, Flag = "rv_silent",
    Callback = function(v)
        aim.enabled = v
        if v then
            InstallSilentAim()
            if not GunMod or type(GunMod.StartShooting) ~= "function" then
                Notify("Aim", "Gun.StartShooting not found — silent aim unavailable", "Error", 3)
            end
        end
        Notify("Aim", v and "Silent Aim ON" or "Silent Aim OFF", v and "Success" or "Error")
    end,
})
SilentSub:AddSlider({
    Name = "Lock Range", Min = 20, Max = 600, Default = 200, Suffix = "studs", Flag = "rv_maxdist",
    Callback = function(v) aim.maxDist = v end,
})
SilentSub:AddToggle({
    Name = "Team Check", Default = true, Flag = "rv_teamcheck",
    Callback = function(v) aim.teamCheck = v end,
})
SilentSub:AddToggle({
    Name = "Jitter", Default = true, Flag = "rv_jitter",
    Callback = function(v) aim.jitter = v end,
})

local FovSub = AimTab:AddSubTab("FOV Circle")
FovSub:AddColorPicker({
    Name = "FOV Color", Default = aim.fovColor, Flag = "rv_fovcolor",
    Callback = function(c) aim.fovColor = c end,
})
FovSub:AddSlider({
    Name = "Thickness", Min = 1, Max = 5, Default = 1.5, Suffix = "", Flag = "rv_fovthick",
    Callback = function(v) aim.fovThickness = v end,
})
FovSub:AddToggle({
    Name = "Filled", Default = false, Flag = "rv_fovfilled",
    Callback = function(v) aim.fovFilled = v end,
})
FovSub:AddToggle({
    Name = "Rainbow FOV", Default = false, Flag = "rv_fovrainbow",
    Callback = function(v) aim.fovRainbow = v end,
})

local TargetSub = AimTab:AddSubTab("Target")
TargetSub:AddToggle({
    Name = "Target Line", Default = false, Flag = "rv_targetline",
    Callback = function(v) aim.targetLine = v end,
})
TargetSub:AddColorPicker({
    Name = "Line Color", Default = aim.targetLineColor, Flag = "rv_tlcolor",
    Callback = function(c) aim.targetLineColor = c end,
})
local targetStatus = TargetSub:AddLabel({ Text = "Target: none" })
track(RunService.RenderStepped:Connect(function()
    if HUB.dead then return end
    -- Only scan when something actually needs the target.
    local needTarget = aim.enabled
    if not needTarget then
        if targetLine then targetLine.Visible = false end
        return
    end
    local t = GetTarget(false)
    if targetLine and hasDrawing then
        targetLine.Visible = aim.targetLine and t ~= nil
        if targetLine.Visible then
            local head = t.Character and t.Character:FindFirstChild("Head")
            if head then
                targetLine.Color = aim.targetLineColor
                local sp, on = Camera:WorldToViewportPoint(head.Position)
                if on and sp.Z > 0 then
                    targetLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    targetLine.To = Vector2.new(sp.X, sp.Y)
                else
                    targetLine.Visible = false
                end
            end
        end
    end
    if targetStatus then
        local name = t and t.Name or "none"
        if t then name = t.DisplayName or t.Name end
        targetStatus:Set("Target: " .. name)
    end
end))

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

local NoSpreadSub = AimTab:AddSubTab("No Spread")
NoSpreadSub:AddSection("No Spread")
NoSpreadSub:AddToggle({
    Name = "No Spread", Default = false, Flag = "rv_nospread",
    Callback = function(v)
        noSpreadEnabled = v
        ApplyNoSpread(v)
        Notify("Aim", v and "No Spread ON" or "No Spread OFF", v and "Success" or "Error")
    end,
})
NoSpreadSub:AddParagraph({
    Title = "Note",
    Text = "This is the same IsFullyAiming patch the silent aim uses. It's safe to run both — the toggle just gives you the spread removal on its own.",
})

-- ══════════════════════════════════════════════════════════════════════════════
-- RAGE TAB (Ragebot — desync auto-fire)
-- ══════════════════════════════════════════════════════════════════════════════
local RageTab = Window:AddTab({ Name = "Rage", Subtitle = "Ragebot & desync", Icon = "bolt" })

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
                end
            end
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
    if tick() - lastFire < rage.fireRate then return end
    lastFire = tick()

    local originPos = desyncCF and desyncCF.Position or targetRoot.Position
    local targetPos = targetHead.Position
    local aimCF = CFrame.lookAt(originPos, targetPos)
    local targetCF = targetHead.CFrame
    local aimedPos = targetPos
    if rage.randomOffset then
        aimedPos = targetPos + Vector3.new(
            (math.random() - 0.5) * 0.1,
            (math.random() - 0.5) * 0.1,
            (math.random() - 0.5) * 0.1
        )
    end
    local objSpaceHeadOffset = targetHead.CFrame:ToObjectSpace(CFrame.new(aimedPos))
    local cameradata = {}
    cameradata[utf8.char(1)] = {
        [utf8.char(0)] = RageUtil:EncodeCFrame(aimCF),
        [utf8.char(1)] = RageUtil:EncodeCFrame(targetCF),
        [utf8.char(2)] = targetHead,
        [utf8.char(3)] = RageUtil:EncodeCFrame(objSpaceHeadOffset),
    }
    pcall(function()
        UseItemR:FireServer(
            item:Get("ObjectID"),
            RageEnum:ToEnum("StartShooting"),
            cameradata,
            nil
        )
    end)
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
    Name = "Fire Rate", Min = 0.0001, Max = 0.05, Default = 0.0005, Suffix = "s", Flag = "rv_rage_firerate",
    Callback = function(v) rage.fireRate = v end,
})
RageSub:AddSlider({
    Name = "Max Distance", Min = 50, Max = 2000, Default = 500, Suffix = "", Flag = "rv_rage_dist",
    Callback = function(v) rage.maxDist = v end,
})
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
    tracer = false, tracerOrigin = "Bottom",
    teamCheck = false, rainbow = false,
    maxDistance = 1000, textSize = 13,
    color = Color3.fromRGB(255, 80, 80),
    nameColor = Color3.fromRGB(255, 255, 255),
}
local playerObjects = {}

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
        o.corners = {}
        for i = 1, 8 do o.corners[i] = newDrawing("Line", { Thickness = 1, Visible = false, Color = Color3.new(1, 1, 1) }) end
    end
    playerObjects[plr] = o
    return o
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
        for _, d in ipairs({ o.frame, o.outline, o.fill, o.name, o.dist, o.tracer, o.hpBack, o.hp }) do
            if d then d.Visible = false end
        end
        for _, l in ipairs(o.corners) do if l then l.Visible = false end end
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
EspSub:AddSlider({ Name = "Text Size", Min = 10, Max = 20, Default = 13, Suffix = "", Flag = "rv_esptextsize", Callback = function(v) esp.textSize = v end })
EspSub:AddSection("Extras")
EspSub:AddToggle({ Name = "Tracers", Default = false, Flag = "rv_esptracer", Callback = function(v) esp.tracer = v end })
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
-- UNLOCK ALL EMOTES (Player tab)
-- ══════════════════════════════════════════════════════════════════════════════
local emotesEnabled = false
local CosmeticLibrary, EmoteController, PlayerDataController
local EmotesFolder
local origOwnsCosmetic, origCanEmote, origUseEmoteByName
local emoteConns = {}
local isLocalEmoting = false
local localEmoteObject = nil
local currentLocalEmote = nil
local runningEmoteConn = nil
local previousCameraMode = nil
local previousMinZoom = nil
local hookedEntity = nil
local oldEntityIsEmoting, oldEntityGetCurrentEmote

do
    local ok1, cl = pcall(require, reps.Modules.CosmeticLibrary)
    if ok1 then CosmeticLibrary = cl end
    local ok2, ec = pcall(require, LocalPlayer.PlayerScripts.Controllers.EmoteController)
    if ok2 then EmoteController = ec end
    local ok3, pd = pcall(require, LocalPlayer.PlayerScripts.Controllers.PlayerDataController)
    if ok3 then PlayerDataController = pd end
    EmotesFolder = reps.Modules:FindFirstChild("Emotes")
end

local function EmoteSafeFire(signal)
    if not signal then return end
    if type(signal) == "table" then
        if type(signal.Fire) == "function" then pcall(function() signal:Fire() end)
        elseif type(signal.fire) == "function" then pcall(function() signal:fire() end) end
    elseif typeof(signal) == "Instance" and signal:IsA("BindableEvent") then
        pcall(function() signal:Fire() end)
    end
end

local function StopLocalEmote()
    if not isLocalEmoting then return end
    isLocalEmoting = false
    localEmoteObject = nil
    pcall(function()
        if previousCameraMode ~= nil then
            LocalPlayer.CameraMode = previousCameraMode
            previousCameraMode = nil
        end
        if previousMinZoom ~= nil then
            LocalPlayer.CameraMinZoomDistance = previousMinZoom
            previousMinZoom = nil
        end
    end)
    local fighter = FighterController and FighterController:GetFighter(LocalPlayer)
    local entity = fighter and fighter.Entity
    if entity and entity.EmoteStatusChanged then
        EmoteSafeFire(entity.EmoteStatusChanged)
    end
    if currentLocalEmote then
        pcall(function() currentLocalEmote:Destroy() end)
        currentLocalEmote = nil
    end
end

local function SetupEmoteHumanoid(character)
    if not character then return end
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid then return end
    if runningEmoteConn then
        runningEmoteConn:Disconnect()
        runningEmoteConn = nil
    end
    runningEmoteConn = humanoid.Running:Connect(function(speed)
        if speed > 0.1 and isLocalEmoting then
            StopLocalEmote()
        end
    end)
end

local function EmoteGetLocalEntity()
    local fighter = FighterController and FighterController:GetFighter(LocalPlayer)
    if fighter and fighter.IsLocalPlayer then
        return fighter.Entity
    end
    return nil
end

local function EmoteHookEntity(entity)
    if not entity then return end
    if hookedEntity == entity then return end
    if hookedEntity and hookedEntity ~= entity then
        if hookedEntity and oldEntityIsEmoting then
            pcall(function() hookedEntity.IsEmoting = oldEntityIsEmoting end)
        end
        if hookedEntity and oldEntityGetCurrentEmote then
            pcall(function() hookedEntity.GetCurrentEmote = oldEntityGetCurrentEmote end)
        end
    end
    hookedEntity = entity
    oldEntityIsEmoting = entity.IsEmoting
    oldEntityGetCurrentEmote = entity.GetCurrentEmote
    entity.IsEmoting = function(self, ...)
        if isLocalEmoting then return true end
        return oldEntityIsEmoting(self, ...)
    end
    entity.GetCurrentEmote = function(self, ...)
        if isLocalEmoting and localEmoteObject then return localEmoteObject end
        return oldEntityGetCurrentEmote(self, ...)
    end
end

local function EmoteUnhookEntity()
    if hookedEntity then
        if oldEntityIsEmoting then pcall(function() hookedEntity.IsEmoting = oldEntityIsEmoting end) end
        if oldEntityGetCurrentEmote then pcall(function() hookedEntity.GetCurrentEmote = oldEntityGetCurrentEmote end) end
    end
    hookedEntity = nil
    oldEntityIsEmoting = nil
    oldEntityGetCurrentEmote = nil
end

local function ApplyEmotes(on)
    if on then
        if CosmeticLibrary and not origOwnsCosmetic then
            origOwnsCosmetic = CosmeticLibrary.OwnsCosmetic
            CosmeticLibrary.OwnsCosmetic = function(self, inventory, cosmeticName)
                local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[cosmeticName]
                if cosmetic and cosmetic.Type == "Emote" then return true end
                return origOwnsCosmetic(self, inventory, cosmeticName)
            end
        end
        if EmoteController and not origCanEmote then
            origCanEmote = EmoteController.CanEmote
            EmoteController.CanEmote = function(self, p2)
                local ok, result = pcall(origCanEmote, self, p2)
                if ok and result then return true end
                local fighter = FighterController and FighterController:GetFighter(LocalPlayer)
                if fighter and fighter.IsLocalPlayer and fighter:IsAlive() then
                    local entity = fighter.Entity
                    if entity and not entity:Get("IsFrozen") then return true end
                end
                return false
            end
        end
        if EmoteController and not origUseEmoteByName then
            origUseEmoteByName = EmoteController.UseEmoteByName
            EmoteController.UseEmoteByName = function(self, emoteName)
                StopLocalEmote()
                local ownsEmote = origOwnsCosmetic and origOwnsCosmetic(CosmeticLibrary, PlayerDataController and PlayerDataController:Get("CosmeticInventory"), emoteName) or false
                pcall(function() origUseEmoteByName(self, emoteName) end)
                if not ownsEmote then
                    task.spawn(function()
                        local emoteModule = EmotesFolder and EmotesFolder:FindFirstChild(emoteName)
                        local character = LocalPlayer.Character
                        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                        if emoteModule and humanoid then
                            task.wait(0.1)
                            pcall(function()
                                currentLocalEmote = require(emoteModule).new(humanoid)
                                previousCameraMode = LocalPlayer.CameraMode
                                previousMinZoom = LocalPlayer.CameraMinZoomDistance
                                LocalPlayer.CameraMode = Enum.CameraMode.Classic
                                LocalPlayer.CameraMinZoomDistance = 8
                                isLocalEmoting = true
                                localEmoteObject = currentLocalEmote
                                local entity = EmoteGetLocalEntity()
                                if entity then
                                    EmoteHookEntity(entity)
                                    if entity.EmoteStatusChanged then
                                        EmoteSafeFire(entity.EmoteStatusChanged)
                                    end
                                end
                                task.defer(currentLocalEmote.Simulate, currentLocalEmote)
                                currentLocalEmote.Destroying:Wait()
                                if isLocalEmoting then StopLocalEmote() end
                                EmoteUnhookEntity()
                            end)
                        end
                    end)
                end
            end
        end
        table.insert(emoteConns, LocalPlayer.CharacterAdded:Connect(function(character)
            StopLocalEmote()
            SetupEmoteHumanoid(character)
        end))
        SetupEmoteHumanoid(LocalPlayer.Character)
    else
        StopLocalEmote()
        EmoteUnhookEntity()
        if runningEmoteConn then runningEmoteConn:Disconnect(); runningEmoteConn = nil end
        for _, c in ipairs(emoteConns) do pcall(function() c:Disconnect() end) end
        table.clear(emoteConns)
        if CosmeticLibrary and origOwnsCosmetic then pcall(function() CosmeticLibrary.OwnsCosmetic = origOwnsCosmetic end); origOwnsCosmetic = nil end
        if EmoteController and origCanEmote then pcall(function() EmoteController.CanEmote = origCanEmote end); origCanEmote = nil end
        if EmoteController and origUseEmoteByName then pcall(function() EmoteController.UseEmoteByName = origUseEmoteByName end); origUseEmoteByName = nil end
    end
end

local EmoteSub = PlayerTab:AddSubTab("Emotes")
EmoteSub:AddSection("Unlock All Emotes")
EmoteSub:AddToggle({
    Name = "Unlock All Emotes", Default = false, Flag = "rv_emotes",
    Callback = function(v)
        emotesEnabled = v
        ApplyEmotes(v)
        if v and not (CosmeticLibrary and EmoteController) then
            Notify("Emotes", "Cosmetic/Emote modules not found", "Error", 3.5)
        else
            Notify("Emotes", v and "All emotes unlocked" or "Emotes off", v and "Success" or "Error")
        end
    end,
})
EmoteSub:AddParagraph({
    Title = "How it works",
    Text = "Spoofs OwnsCosmetic + CanEmote and simulates unowned emotes locally so they play for you. Open your emote wheel and pick anything.",
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
    aim.enabled = false
    rage.enabled = false
    equipLoopAlive = false
    table.clear(deflecting)
    pcall(function() runSR:UnbindFromRenderStep("OxideRageRestore") end)
    noSpreadEnabled = false; ApplyNoSpread(false)
    rapidHitEnabled = false
    emotesEnabled = false; ApplyEmotes(false)
    spoofLoopAlive = false
    for _, c in ipairs(spoofConns) do pcall(function() c:Disconnect() end) end
    table.clear(spoofConns)
    wsEnabled = false; jpEnabled = false; infJump = false
    flyEnabled = false; noclipEnabled = false; fullbright = false
    aim.enabled = false
    UninstallSilentAim()
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
if not GunMod or type(GunMod.StartShooting) ~= "function" then
    Notify("RIVALS", "Gun.StartShooting not found — silent aim & wallbang unavailable", "Error", 3)
else
    Notify("RIVALS", "Oxide HUB loaded — silent aim & wallbang ready", "Success", 3)
end
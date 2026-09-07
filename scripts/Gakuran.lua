-- ═══ HUB STRIP POINT — when deployed via the ScriptLoader the ScriptLoader injects
--     "local Library = _G.OxideLib" above this line instead. ═══
-- ══════════════════════════════════════════════════════════════════════════════

do
-- RE-EXECUTION GUARD
do
    local prev = _G.OxideGakuran
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, dead = false, loops = {} }
_G.OxideGakuran = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end

local Window = Library:CreateWindow({
    Name = "Oxide HUB | Gakuran",
    LoadingAnimation = true,
    LoadingText = "Oxide",
    LoadingDuration = 2.2,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG / FLAG PERSISTENCE
-- ══════════════════════════════════════════════════════════════════════════════
local HAS_CONFIG = type(Library.SaveConfig) == "function"
    and type(Library.LoadConfig) == "function"
    and type(Library.ListConfigs) == "function"
local CONFIG_NAME = "gakuran"

-- ══════════════════════════════════════════════════════════════════════════════
-- SERVICES / ENV
-- ══════════════════════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local function Notify(title, content, kind, dur)
    pcall(Window.Notify, Window, { Title = title, Content = content, Type = kind or "Info", Duration = dur or 2.5 })
end
local function notifyOn(feature, on)
    Notify(feature, on and "ON" or "OFF", on and "Success" or "Error")
end
local function safeCallback(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            pcall(Notify, "Oxide HUB", "Error: " .. tostring(err), "Error", 4)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- GAME API (pcall-guarded)
-- ══════════════════════════════════════════════════════════════════════════════
local ENV_OK = false
local Combat = {}
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function InitGameApi()
    local ok
    ok, Combat.Block = pcall(require, ReplicatedStorage:WaitForChild("CombatSystemClient"):WaitForChild("Combat"):WaitForChild("Base"):WaitForChild("Block"))
    if not ok then Combat.Block = nil end
    ok, Combat.Evasive = pcall(require, ReplicatedStorage:WaitForChild("CombatSystemClient"):WaitForChild("Combat"):WaitForChild("Base"):WaitForChild("Evasive"))
    if not ok then Combat.Evasive = nil end
    ok, Combat.M1 = pcall(require, ReplicatedStorage:WaitForChild("CombatSystemClient"):WaitForChild("Combat"):WaitForChild("Base"):WaitForChild("M1"))
    if not ok then Combat.M1 = nil end
    ok, Combat.M2 = pcall(require, ReplicatedStorage:WaitForChild("CombatSystemClient"):WaitForChild("Combat"):WaitForChild("Base"):WaitForChild("M2"))
    if not ok then Combat.M2 = nil end
    ok, Combat.Equip = pcall(require, ReplicatedStorage:WaitForChild("CombatSystemClient"):WaitForChild("Combat"):WaitForChild("Base"):WaitForChild("Equip"))
    if not ok then Combat.Equip = nil end

    ENV_OK = Combat.Block ~= nil and Combat.Evasive ~= nil
    return ENV_OK
end

-- ══════════════════════════════════════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════════════════════════════════════
-- Auto Parry / Evasive
local parryEnabled = false
local detectionRange = 18
local evasiveMode = false
local evasiveDirectional = false
local parryOnly = false
local pauseM1ForParry = false
local priority = "Parry"          -- Parry / Evasive
local facingStrictness = 0.6
local noParryCooldown = false
local noDodgeCooldown = false

-- Combat Tweaks
local autoPunish = false
local punishMethod = "M2"
local flingAura = false
local noStun = false
local noRagdoll = false
local lagSwitch = false
local disableGlassesKnocked = false
local noBlurWhenKnocked = false

-- Face Lock
local faceLockEnabled = false
local stickyTarget = false
local selectedTargetName = nil
local whitelist = {}   -- [userId] = true
local lockedTarget = nil
local faceHumanoid = nil
local savedAutoRotate = nil

-- Auto Green / Rhythm (best-effort)
local autoGreen = false
local greenAccuracy = "Perfect"
local autoRhythm = false
local rhythmSmoothFactor = 0.5
local rhythmState = { settings = nil, originalVertical = nil, service = nil, serviceScanAt = 0, heldKeys = {} }
local animSpeed = 1

-- ESP
local espEnabled = false
local espColor = Color3.fromRGB(255, 255, 255)
local espBoxes = false
local espFillTransparency = 0.5
local espOutlineTransparency = 0
local espHighlight = false
local espHeadDot = false
local espTracers = false
local espHpBar = false
local espShowName = true
local espShowHealth = true
local espShowDistance = true
local espMaxDistance = 500
local espFontSize = 14

-- World / Lighting
local visualState = {
    ambientR = 120, ambientG = 120, ambientB = 120, fov = 70,
    fullBright = false, night = false, origFov = nil, animationSpeeds = {},
}

-- Movement
local speedhack = false
local speedhackValue = 32
local flyEnabled = false
local flySpeed = 50
local infiniteJump = false
local infiniteStamina = false
local autoSprint = false
local noclip = false

-- Teleport
local teleportState = { waypoint = nil, target = nil }

-- Basketball / Reroll / Fun
local basketballState = { enabled = false, char = nil, nextDribbleAt = 0, dribbleIndex = 1 }
local rerollCategory = "Face"
local hairColor = Color3.fromRGB(0, 0, 0)

-- Server
local antiAfk = false
local antiMod = false
local antiModMethod = "Auto Disable"

-- ══════════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════════════════════════════════
-- This game uses a CUSTOM character system: the logical "Character" under
-- Players has no parts. The physical rig (HumanoidRootPart/Head) lives in
-- Workspace.Players.<Name>. Resolve the physical model first.
local function AttributeIsTrue(inst, name)
    if not inst then return false end
    local value = inst:GetAttribute(name)
    if value == true or value == 1 then return true end
    return type(value) == "string" and string.lower(value) == "true"
end

local function GetChar(plr)
    if not plr then return nil end
    local physicalFolder = Workspace:FindFirstChild("Players")
    local physical = physicalFolder and physicalFolder:FindFirstChild(plr.Name)
    if physical and (physical:FindFirstChild("HumanoidRootPart") or physical.PrimaryPart) then
        return physical
    end
    local logical = plr.Character
    if logical and (logical:FindFirstChild("HumanoidRootPart") or logical.PrimaryPart) then
        return logical
    end
    return physical or logical
end

local function GetHRP(plr)
    local c = GetChar(plr)
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")
end

local function GetHum(plr)
    local c = GetChar(plr)
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function GetMyChar() return GetChar(LocalPlayer) end
local function GetMyHRP() return GetHRP(LocalPlayer) end
local function GetMyHum() return GetHum(LocalPlayer) end
local function IsDead(plr)
    local hum = GetHum(plr)
    local c = GetChar(plr)
    return (hum and hum.Health <= 0) or AttributeIsTrue(c, "Dead")
end

local function IsUsableTarget(p)
    return p and p ~= LocalPlayer and not whitelist[p.UserId] and GetHRP(p) and not IsDead(p)
end

-- Resolve the selected target first, then keep the current target stable when requested.
local function ResolveTarget()
    if selectedTargetName and selectedTargetName ~= "" then
        local p = Players:FindFirstChild(selectedTargetName)
        if IsUsableTarget(p) then return p end
    end
    return nil
end

local function GetTarget()
    local selected = ResolveTarget()
    if selected then
        lockedTarget = selected
        return selected
    end
    if stickyTarget and IsUsableTarget(lockedTarget) then
        local myHrp, targetHrp = GetMyHRP(), GetHRP(lockedTarget)
        if myHrp and targetHrp and (targetHrp.Position - myHrp.Position).Magnitude <= detectionRange * 1.5 then
            return lockedTarget
        end
    end
    local hrp = GetMyHRP()
    if not hrp then
        lockedTarget = nil
        return nil
    end
    local best, bestD = nil, detectionRange
    for _, p in ipairs(Players:GetPlayers()) do
        if IsUsableTarget(p) then
            local ehrp = GetHRP(p)
            local d = ehrp and (ehrp.Position - hrp.Position).Magnitude or math.huge
            if d < bestD then best, bestD = p, d end
        end
    end
    lockedTarget = best
    return best
end

local function IsAttackingChar(char)
    if not char then return false end
    return AttributeIsTrue(char, "M1")
        or AttributeIsTrue(char, "M2")
        or AttributeIsTrue(char, "CombatAttacking")
        or AttributeIsTrue(char, "PendingM1")
        or AttributeIsTrue(char, "PendingM2")
end

local function IsMyCharLocked(char)
    if not char then return true end
    return AttributeIsTrue(char, "Ragdoll")
        or AttributeIsTrue(char, "Downed")
        or AttributeIsTrue(char, "GuardBroken")
        or AttributeIsTrue(char, "Grappling")
end

-- Face the target (rotate HRP toward them; run every frame while locked).
local function FaceTarget(target)
    local hrp = GetMyHRP()
    local thrp = GetHRP(target)
    if not (hrp and thrp) then return end
    local dir = thrp.Position - hrp.Position
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude < 0.1 then return end
    local hum = GetMyHum()
    if hum and faceHumanoid ~= hum then
        faceHumanoid = hum
        savedAutoRotate = hum.AutoRotate
    end
    if hum then hum.AutoRotate = false end
    hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat.Unit)
end

local function RestoreFaceLock()
    if faceHumanoid and faceHumanoid.Parent and savedAutoRotate ~= nil then
        faceHumanoid.AutoRotate = savedAutoRotate
    end
    faceHumanoid = nil
    savedAutoRotate = nil
    lockedTarget = nil
end

local function IsFacingTarget(target)
    if facingStrictness <= 0 then return true end
    local hrp, thrp = GetMyHRP(), GetHRP(target)
    if not (hrp and thrp) then return false end
    local flat = Vector3.new(thrp.Position.X - hrp.Position.X, 0, thrp.Position.Z - hrp.Position.Z)
    if flat.Magnitude < 0.1 then return true end
    return hrp.CFrame.LookVector:Dot(flat.Unit) >= math.max(0, math.min(1, facingStrictness))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE — COMBAT
-- ══════════════════════════════════════════════════════════════════════════════
local function ClearBlockCooldown()
    local chr = GetMyChar()
    if chr then
        chr:SetAttribute("BlockCooldown", nil)
        chr:SetAttribute("ParryWindowDisabled", nil)
    end
end

local function ClearDodgeCooldown()
    local chr = GetMyChar()
    if chr then
        chr:SetAttribute("IFRAMECD", nil)
        chr:SetAttribute("EvasiveCooldownRemaining", nil)
    end
end

local function DoEquip()
    if not Combat.Equip then return false end
    local chr = GetMyChar()
    if chr and AttributeIsTrue(chr, "Equip") then return true end
    local ok, err = pcall(function() Combat.Equip.Equip() end)
    return ok
end

local function DoBlock()
    if not Combat.Block then return false end
    if noParryCooldown then ClearBlockCooldown() end
    local ok, err = pcall(function() Combat.Block.Block() end)
    return ok
end

local function DoUnblock()
    if not Combat.Block then return false end
    pcall(function() Combat.Block.Unblock() end)
    return true
end

local function DoDodge()
    if not Combat.Evasive then return false end
    if noDodgeCooldown then ClearDodgeCooldown() end
    local ok, err = pcall(function() Combat.Evasive.Evasive() end)
    return ok
end

local function DoM1()
    if not Combat.M1 then return false end
    local ok = pcall(function() Combat.M1.OnM1Activated() end)
    return ok
end

local function DoM2()
    if not Combat.M2 then return false end
    local ok = pcall(function() Combat.M2.OnM2Activated() end)
    return ok
end

-- Combat loop: auto-parry / evasive / auto-punish / fling aura
local lastParryAt = 0
local lastDodgeAt = 0
local lastPunishAt = 0
local lastEquipAt = 0
local lastPvpAt = 0

local function CombatTick()
    if HUB.dead then return end
    if not (parryEnabled or evasiveMode or autoPunish or flingAura or noStun or noRagdoll or lagSwitch) then
        return
    end

    local chr = GetMyChar()
    if not chr then return end

    local now = os.clock()

    -- Auto-equip combat style so attacks/parry actually work (throttled)
    if not AttributeIsTrue(chr, "Equip") then
        if now - lastEquipAt > 2 then
            lastEquipAt = now
            DoEquip()
        end
    end

    -- Auto-enable PvP (combat is blocked while RpPvpEnabled is false)
    if not AttributeIsTrue(chr, "RpPvpEnabled") then
        if now - lastPvpAt > 3 then
            lastPvpAt = now
            pcall(function() Remotes:WaitForChild("RpPvpToggle"):InvokeServer() end)
        end
    end

    -- No stun: clear negative states
    if noStun then
        chr:SetAttribute("Stunned", nil)
        chr:SetAttribute("Parried", nil)
        chr:SetAttribute("CantAnything", nil)
        chr:SetAttribute("CombatRecovery", nil)
    end

    -- No ragdoll: stand back up instantly
    if noRagdoll then
        if AttributeIsTrue(chr, "Ragdoll") then
            chr:SetAttribute("Ragdoll", nil)
            local hum = GetHum(LocalPlayer)
            if hum then
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end)
            end
        end
    end

    if noParryCooldown then ClearBlockCooldown() end
    if noDodgeCooldown then ClearDodgeCooldown() end

    local target = GetTarget()
    if not target then return end
    local tchar = GetChar(target)
    local thrp = GetHRP(target)
    if not (tchar and thrp) then return end
    local hrp = GetMyHRP()
    if not hrp then return end
    local dist = (thrp.Position - hrp.Position).Magnitude

    -- Face lock
    if faceLockEnabled and dist < detectionRange * 1.5 then
        FaceTarget(target)
    end

    local attacking = IsAttackingChar(tchar)

    -- Defense: parry or dodge when enemy attacks
    local facingOkay = IsFacingTarget(target)
    if attacking and dist < detectionRange and (faceLockEnabled or facingOkay) and not IsMyCharLocked(chr) then
        local doDodge
        if evasiveMode and parryEnabled then
            doDodge = (priority == "Evasive")
        else
            doDodge = evasiveMode
        end
        if doDodge then
            if now - lastDodgeAt > 0.3 then
                lastDodgeAt = now
                if evasiveDirectional then
                    local hum = GetMyHum()
                    local away = Vector3.new(hrp.Position.X - thrp.Position.X, 0, hrp.Position.Z - thrp.Position.Z)
                    if hum and away.Magnitude > 0.1 then pcall(function() hum:Move(away.Unit, true) end) end
                end
                DoDodge()
            end
        else
            if now - lastParryAt > 0.3 then
                lastParryAt = now
                if pauseM1ForParry and Combat.M1 and Combat.M1.Hold then
                    pcall(function() Combat.M1.Hold("Stop") end)
                end
                DoBlock()
            end
        end
    else
        -- Release block shortly after the attack ends so we can move normally
        if AttributeIsTrue(chr, "Blocking") and now - lastParryAt > 0.4 then
            DoUnblock()
        end
    end

    -- Auto punish: after a parry/block, hit back
    if autoPunish and dist < detectionRange and not IsMyCharLocked(chr) then
        if now - lastPunishAt > 0.7 then
            lastPunishAt = now
            if not parryOnly then
                if punishMethod == "M2" then DoM2() else DoM1() end
            end
        end
    end

    -- Fling aura: knock nearby enemies around (velocity + optional ragdoll)
    if flingAura and dist < detectionRange * 1.2 and tchar then
        local ehrp = thrp
        if ehrp then
            local dir = (ehrp.Position - hrp.Position).Unit
            local fling = Vector3.new(dir.X * 60, 40 + math.random(0, 30), dir.Z * 60)
            ehrp.AssemblyLinearVelocity = fling
        end
    end
end

local lagAnchoredHrp = nil
local function LagSwitchTick()
    if HUB.dead then return end
    if not lagSwitch then
        if lagAnchoredHrp and lagAnchoredHrp.Parent then lagAnchoredHrp.Anchored = false end
        lagAnchoredHrp = nil
        return
    end
    local hrp = GetMyHRP()
    if hrp then
        lagAnchoredHrp = hrp
        hrp.Anchored = true
        task.wait(0.09)
        if hrp and hrp.Parent then hrp.Anchored = false end
        if lagAnchoredHrp == hrp then lagAnchoredHrp = nil end
    end
end

local function StartCombatLoop()
    if HUB.loops.combat then return end
    HUB.loops.combat = true
    while not HUB.dead and (parryEnabled or evasiveMode or autoPunish or flingAura or noStun or noRagdoll
        or noParryCooldown or noDodgeCooldown or faceLockEnabled) do
        HUB.lastCombatOk, HUB.lastCombatError = pcall(CombatTick)
        task.wait(0.05)
    end
    HUB.loops.combat = false
end

local function StartLagSwitchLoop()
    if HUB.loops.lagswitch then return end
    HUB.loops.lagswitch = true
    while not HUB.dead and lagSwitch do
        HUB.lastLagOk, HUB.lastLagError = pcall(LagSwitchTick)
        task.wait(0.6)
    end
    HUB.lastLagOk, HUB.lastLagError = pcall(LagSwitchTick)
    HUB.loops.lagswitch = false
end

local automationClock = { green = 0, rhythm = 0 }

local function AutoGreenTick()
    if not autoGreen then return end
    local ok, api = pcall(function()
        local folder = ReplicatedStorage:FindFirstChild("Shared")
        local services = folder and folder:FindFirstChild("Services")
        local basketball = services and services:FindFirstChild("BasketballService")
        local module = basketball and basketball:FindFirstChild("BasketballServiceClient")
        return module and require(module):Get()
    end)
    local active = false
    if ok and api then
        local activeOk
        activeOk, active = pcall(function() return api:IsActive() and api:IsHoldingBall() end)
        if not activeOk then active = false end
    else
        local chr = GetMyChar()
        active = AttributeIsTrue(chr, "BasketballActive")
            or AttributeIsTrue(chr, "BasketballHoldingBall")
            or AttributeIsTrue(chr, "BasketballMode")
    end
    if not active then return end
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end
    local meter
    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("BillboardGui") and object.Name == "BasketballShotMeterBar" and object.Enabled then
            meter = object
            break
        end
    end
    if not meter then return end
    local track = meter:FindFirstChild("Track")
    local fill = track and track:FindFirstChild("Fill")
    local target = track and track:FindFirstChild("Target")
    if not (fill and target) then return end
    local fillScale = fill.Size.Y.Scale
    local targetScale = 1 - target.Position.Y.Scale
    local tolerance = ({ Perfect = 0.035, Good = 0.08, Okay = 0.14, Bad = 0.22, Miss = 0.01 })[greenAccuracy] or 0.035
    if math.abs(fillScale - targetScale) <= tolerance and os.clock() - automationClock.green > 0.25 then
        automationClock.green = os.clock()
        if api then
            pcall(function() api:RequestShoot(false) end)
        else
            local remote = Remotes:FindFirstChild("Basketball")
            if remote and remote:IsA("RemoteEvent") then
                pcall(function() remote:FireServer({ "Shoot", false }) end)
            end
        end
    end
end

local function GetRhythmService()
    -- In a live client the rhythm modules are required during bootstrap and
    -- may no longer be parented under ReplicatedStorage. Resolve the public
    -- singleton first, then fall back to the already-created client service.
    if rhythmState.service then
        local valid = pcall(function()
            return type(rhythmState.service.IsPlaying) == "function"
                and type(rhythmState.service.StartPlay) == "function"
        end)
        if valid then return rhythmState.service end
        rhythmState.service = nil
    end

    local ok, service = pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        local services = shared and shared:FindFirstChild("Services")
        local rhythm = services and services:FindFirstChild("RhythmService")
        local module = rhythm and rhythm:FindFirstChild("RhythmServiceClient")
        if not module then return nil end
        local loaded = require(module)
        if type(loaded) == "table" and type(loaded.Get) == "function" then
            return loaded:Get()
        end
        return loaded
    end)
    if ok and service and type(service) == "table"
        and type(service.IsPlaying) == "function"
        and type(service.StartPlay) == "function" then
        rhythmState.service = service
        return service
    end

    if type(getgc) == "function" and os.clock() - rhythmState.serviceScanAt >= 0.5 then
        rhythmState.serviceScanAt = os.clock()
        local gcOk, objects = pcall(getgc, true)
        if gcOk and type(objects) == "table" then
            for _, candidate in ipairs(objects) do
                local candidateOk, isService = pcall(function()
                    return type(candidate) == "table"
                        and rawget(candidate, "_registry") ~= nil
                        and rawget(candidate, "_initialized") ~= nil
                        and type(candidate.IsPlaying) == "function"
                        and type(candidate.StartPlay) == "function"
                        and type(candidate.Stop) == "function"
                end)
                if candidateOk and isService then
                    rhythmState.service = candidate
                    return candidate
                end
            end
        end
    end
    return nil
end

local function SendRhythmKey(session, lane, isDown)
    local laneKeys = session and session._laneToKeys and session._laneToKeys[lane]
    local key = laneKeys and laneKeys[1]
    if not key then return false, nil end

    -- VirtualInputManager is RobloxScript-only in this executor. Use the
    -- executor's keypress/keyrelease bridge so the game's stale-key cleanup
    -- sees the lane as held and does not cancel hold notes next frame.
    local name = key.Name
    local code
    if type(name) == "string" and #name == 1 then
        code = string.byte(name:upper())
    else
        code = ({ Left = 0x25, Up = 0x26, Right = 0x27, Down = 0x28 })[name]
    end
    if code and type(keypress) == "function" and type(keyrelease) == "function" then
        local sent = pcall(function()
            if isDown then keypress(code) else keyrelease(code) end
        end)
        return sent, key
    end
    return false, key
end

local function ReleaseRhythmKeys()
    for lane, held in pairs(rhythmState.heldKeys) do
        if held and held.session then
            SendRhythmKey(held.session, lane, false)
            if type(held.session._handleLaneRelease) == "function" then
                pcall(function() held.session:_handleLaneRelease(lane) end)
            end
        end
        rhythmState.heldKeys[lane] = nil
    end
end

local function AutoRhythmTick()
    if not (autoRhythm == true or autoRhythm == 1
        or (type(autoRhythm) == "string" and autoRhythm:lower() == "true")) then
        ReleaseRhythmKeys()
        return
    end
    if os.clock() - automationClock.rhythm < 0.012 then return end

    local service = GetRhythmService()
    if not service then
        HUB.rhythmStatus = "Rhythm service unavailable"
        return
    end

    local playingOk, playing = pcall(function() return service:IsPlaying() end)
    if not playingOk or not playing then
        ReleaseRhythmKeys()
        HUB.rhythmStatus = "Equip guitar and start a song"
        return
    end

    local session = service._session
    local notes = session and session._liveNotes
    if type(session) ~= "table" or type(notes) ~= "table" or type(session._now) ~= "function"
        or type(session._handleLanePress) ~= "function" then
        ReleaseRhythmKeys()
        HUB.rhythmStatus = "Rhythm session not ready"
        return
    end

    local nowOk, now = pcall(function() return session:_now() end)
    if not nowOk or type(now) ~= "number" then
        HUB.rhythmStatus = "Rhythm clock unavailable"
        return
    end

    -- Keep the hit close to the receptor. The old 25–125 ms window often
    -- pressed early enough to score badly, and the old release timer released
    -- holds before their scheduled start.
    local timingWindow = 0.012 + math.max(0, math.min(1, rhythmSmoothFactor)) * 0.028
    local nextNote
    for _, note in ipairs(notes) do
        if note and not note.hit and not note.resolved
            and type(note.lane) == "number" and type(note.t) == "number" then
            local delta = note.t - now
            if delta >= -timingWindow and delta <= timingWindow
                and (not nextNote or note.t < nextNote.t) then
                nextNote = note
            end
        end
    end

    if not nextNote then
        HUB.rhythmStatus = "Running"
        return
    end

    automationClock.rhythm = os.clock()
    local lane = nextNote.lane
    local isHold = type(nextNote.len) == "number" and nextNote.len > 0
    local sentInput, key = false, nil

    if isHold then
        -- The engine reconciles stale keyboard releases every frame. A direct
        -- private method call therefore drops a hold on the next frame. Keep
        -- the real mapped lane key down for the whole hold instead.
        sentInput, key = SendRhythmKey(session, lane, true)
        rhythmState.heldKeys[lane] = {
            session = session,
            key = key,
            usedInput = sentInput,
        }
        task.delay(0.015, function()
            if HUB.dead or rhythmState.service ~= service or service._session ~= session then return end
            if not nextNote.hit and not nextNote.resolved then
                pcall(function() session:_handleLanePress(lane) end)
            end
        end)
    else
        sentInput = false
        pcall(function() session:_handleLanePress(lane) end)
    end

    HUB.rhythmStatus = (isHold and "Holding lane " or "Pressed lane ") .. tostring(lane)

    if isHold and type(session._handleLaneRelease) == "function" then
        -- Let RhythmEngine finish the hold on its own frame first. Releasing
        -- exactly at t+len is interpreted as an early manual release.
        local releaseAt = math.max(now, nextNote.t) + nextNote.len + 0.06
        task.delay(math.max(0, releaseAt - now), function()
            if HUB.dead or rhythmState.service ~= service or service._session ~= session then return end
            local held = rhythmState.heldKeys[lane]
            if held and held.session == session then
                if held.usedInput then SendRhythmKey(session, lane, false) end
                pcall(function() session:_handleLaneRelease(lane) end)
                rhythmState.heldKeys[lane] = nil
            end
        end)
    end
end

local function RestoreAnimationSpeeds()
    local tracks = {}
    for animation in pairs(visualState.animationSpeeds) do table.insert(tracks, animation) end
    for _, animation in ipairs(tracks) do
        local speed = visualState.animationSpeeds[animation]
        if animation and animation.Parent then
            pcall(function() animation:AdjustSpeed(speed) end)
        end
        visualState.animationSpeeds[animation] = nil
    end
end

local function AnimationSpeedTick()
    if animSpeed == 1 then
        RestoreAnimationSpeeds()
        return
    end
    local hum = GetMyHum()
    if not hum then return end
    for _, animation in ipairs(hum:GetPlayingAnimationTracks()) do
        if visualState.animationSpeeds[animation] == nil then
            local ok, speed = pcall(function() return animation.Speed end)
            visualState.animationSpeeds[animation] = ok and speed or 1
        end
        pcall(function() animation:AdjustSpeed(animSpeed) end)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE — KNOCKED FX (glasses / blur)
-- ══════════════════════════════════════════════════════════════════════════════
local blurOriginal = {}
local glassesOriginal = {}

local function RestoreBlur()
    local effects = {}
    for effect in pairs(blurOriginal) do table.insert(effects, effect) end
    for _, effect in ipairs(effects) do
        local state = blurOriginal[effect]
        if effect and effect.Parent then
            effect.Enabled = state.Enabled
            effect.Size = state.Size
        end
        blurOriginal[effect] = nil
    end
end

local function RestoreGlasses()
    local parts = {}
    for part in pairs(glassesOriginal) do table.insert(parts, part) end
    for _, part in ipairs(parts) do
        local transparency = glassesOriginal[part]
        if part and part.Parent then part.LocalTransparencyModifier = transparency end
        glassesOriginal[part] = nil
    end
end

local function RestoreKnockFx()
    RestoreBlur()
    RestoreGlasses()
end

local function KnockFxTick()
    if HUB.dead then return end
    local chr = GetMyChar()
    if not chr then
        RestoreKnockFx()
        return
    end
    local knocked = AttributeIsTrue(chr, "Downed") or AttributeIsTrue(chr, "Ragdoll")

    if knocked and noBlurWhenKnocked then
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("BlurEffect") then
                if blurOriginal[effect] == nil then
                    blurOriginal[effect] = { Enabled = effect.Enabled, Size = effect.Size }
                end
                effect.Enabled = false
            end
        end
    else
        RestoreBlur()
    end

    if knocked and disableGlassesKnocked then
        for _, part in ipairs(chr:GetDescendants()) do
            if part:IsA("BasePart") and part.Name:lower():find("glass") then
                if glassesOriginal[part] == nil then glassesOriginal[part] = part.LocalTransparencyModifier end
                part.LocalTransparencyModifier = 1
                part.AssemblyLinearVelocity = Vector3.zero
            end
        end
    else
        RestoreGlasses()
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE — MOVEMENT
-- ══════════════════════════════════════════════════════════════════════════════
local FLY = { hrp = nil, hum = nil, oldPlatformStand = nil }
local SP = { player = nil, oldOverride = nil, hum = nil, oldValue = nil }
local ST = { char = nil, oldValue = nil }
local SPRINT = { char = nil, oldValue = nil, inputHeld = false }
local collisionOriginal = {}

local function CleanupFly()
    if FLY.hrp and FLY.hrp.Parent then
        local bv = FLY.hrp:FindFirstChild("OxideFlyBody")
        local bg = FLY.hrp:FindFirstChild("OxideFlyGyro")
        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
    end
    if FLY.hum and FLY.hum.Parent and FLY.oldPlatformStand ~= nil then
        FLY.hum.PlatformStand = FLY.oldPlatformStand
    end
    FLY.hrp, FLY.hum, FLY.oldPlatformStand = nil, nil, nil
end

local function ApplyFly(on)
    if not on then
        CleanupFly()
        return
    end
    local hrp, hum = GetMyHRP(), GetMyHum()
    if not hrp then return end
    if FLY.hrp ~= hrp then CleanupFly() end
    FLY.hrp, FLY.hum = hrp, hum
    if FLY.hum and FLY.oldPlatformStand == nil then
        FLY.oldPlatformStand = FLY.hum.PlatformStand
        FLY.hum.PlatformStand = true
    end
    local bv = hrp:FindFirstChild("OxideFlyBody") or Instance.new("BodyVelocity")
    bv.Name = "OxideFlyBody"
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.P = 1e4
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    local bg = hrp:FindFirstChild("OxideFlyGyro") or Instance.new("BodyGyro")
    bg.Name = "OxideFlyGyro"
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P = 1e4
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp
end

local function FlyTick()
    if not flyEnabled then
        if FLY.hrp then CleanupFly() end
        return
    end
    local hrp = GetMyHRP()
    if not hrp then return end
    if FLY.hrp ~= hrp or not hrp:FindFirstChild("OxideFlyBody") then ApplyFly(true) end
    local bv = hrp:FindFirstChild("OxideFlyBody")
    local camera = Workspace.CurrentCamera
    if not (bv and camera) then return end
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
    bv.Velocity = dir.Magnitude > 0 and dir.Unit * flySpeed or Vector3.zero
end

local function RestoreSpeed()
    -- The game's MovementServiceClient overwrites WalkSpeed every tick, so a
    -- direct property set gets reverted immediately. It does honor
    -- AdminWalkSpeedOverride on the LocalPlayer, which is what we restore here.
    if SP.player and SP.player.Parent then
        SP.player:SetAttribute("AdminWalkSpeedOverride", SP.oldOverride)
    end
    SP.player, SP.oldOverride = nil, nil
    if SP.hum and SP.hum.Parent and SP.oldValue ~= nil then SP.hum.WalkSpeed = SP.oldValue end
    SP.hum, SP.oldValue = nil, nil
end

local function SpeedhackTick()
    local hum = GetMyHum()
    if not speedhack then
        if SP.player or SP.hum then RestoreSpeed() end
        return
    end
    if not hum then return end
    if SP.player ~= LocalPlayer then
        RestoreSpeed()
        SP.player = LocalPlayer
        SP.oldOverride = LocalPlayer:GetAttribute("AdminWalkSpeedOverride")
    end
    LocalPlayer:SetAttribute("AdminWalkSpeedOverride", speedhackValue)
    if SP.hum ~= hum then
        SP.oldValue = hum.WalkSpeed
        SP.hum = hum
    end
    hum.WalkSpeed = speedhackValue
end

local function RestoreStamina()
    if ST.char and ST.char.Parent and ST.oldValue ~= nil then
        ST.char:SetAttribute("Stamina", ST.oldValue)
    end
    ST.char, ST.oldValue = nil, nil
end

local function InfiniteStaminaTick()
    if not infiniteStamina then
        if ST.char then RestoreStamina() end
        return
    end
    local chr = GetMyChar()
    if not chr then return end
    if ST.char ~= chr then
        RestoreStamina()
        ST.char, ST.oldValue = chr, chr:GetAttribute("Stamina")
    end
    chr:SetAttribute("Stamina", 100)
end

local function StopAutoSprint()
    if SPRINT.inputHeld then
        local ok, virtualInput = pcall(function() return game:GetService("VirtualInputManager") end)
        if ok and virtualInput then
            pcall(function() virtualInput:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game) end)
        end
        SPRINT.inputHeld = false
    end
    if SPRINT.char and SPRINT.char.Parent and SPRINT.oldValue ~= nil then
        SPRINT.char:SetAttribute("Sprinting", SPRINT.oldValue)
    end
    SPRINT.char, SPRINT.oldValue = nil, nil
end

local function AutoSprintTick()
    if not autoSprint then
        if SPRINT.char or SPRINT.inputHeld then StopAutoSprint() end
        return
    end
    local chr = GetMyChar()
    if not chr then return end
    if SPRINT.char ~= chr then
        StopAutoSprint()
        SPRINT.char, SPRINT.oldValue = chr, chr:GetAttribute("Sprinting")
    end
    -- Let MovementServiceClient handle auth tokens, stamina and animations by
    -- holding the same key the game itself uses. Direct Sprint remotes are not
    -- valid for this game and the server silently ignores their old payload.
    local item = chr:GetAttribute("ItemEquipped")
    local instrument = chr:GetAttribute("PlayingInstrument")
    local arcade = chr:GetAttribute("PlayingArcade")
    local airHockey = chr:GetAttribute("PlayingAirHockey")
    local armWrestling = chr:GetAttribute("PlayingArmWrestling")
    local basketballLocked = AttributeIsTrue(chr, "BasketballMatchLocked")
    local blockedItem = (type(item) == "string" and item ~= "")
        or (type(instrument) == "string" and instrument ~= "")
        or arcade ~= nil or airHockey ~= nil or armWrestling ~= nil or basketballLocked
    if blockedItem or AttributeIsTrue(chr, "Ragdoll") or AttributeIsTrue(chr, "Downed") then
        if SPRINT.inputHeld then StopAutoSprint() end
        return
    end
    if not SPRINT.inputHeld then
        local got, virtualInput = pcall(function() return game:GetService("VirtualInputManager") end)
        if not got or not virtualInput then return end
        local ok = pcall(function() virtualInput:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game) end)
        if ok then SPRINT.inputHeld = true end
    end
end

local function RestoreNoclip()
    local parts = {}
    for part in pairs(collisionOriginal) do table.insert(parts, part) end
    for _, part in ipairs(parts) do
        local canCollide = collisionOriginal[part]
        if part and part.Parent then part.CanCollide = canCollide end
        collisionOriginal[part] = nil
    end
end

local function NoclipTick()
    if not noclip then
        if next(collisionOriginal) ~= nil then RestoreNoclip() end
        return
    end
    local chr = GetMyChar()
    if not chr then return end
    for _, part in ipairs(chr:GetDescendants()) do
        if part:IsA("BasePart") then
            if collisionOriginal[part] == nil then collisionOriginal[part] = part.CanCollide end
            part.CanCollide = false
        end
    end
end

local BasketballTick

local function StartMovementLoop()
    if HUB.loops.move then return end
    HUB.loops.move = true
    while not HUB.dead and (flyEnabled or infiniteStamina or autoSprint or noclip or basketballState.enabled
        or disableGlassesKnocked or noBlurWhenKnocked) do
        HUB.lastFlyOk, HUB.lastFlyError = pcall(FlyTick)
        HUB.lastStaminaOk, HUB.lastStaminaError = pcall(InfiniteStaminaTick)
        HUB.lastSprintOk, HUB.lastSprintError = pcall(AutoSprintTick)
        HUB.lastNoclipOk, HUB.lastNoclipError = pcall(NoclipTick)
        HUB.lastKnockFxOk, HUB.lastKnockFxError = pcall(KnockFxTick)
        HUB.lastBasketballOk, HUB.lastBasketballError = pcall(BasketballTick)
        task.wait(0.05)
    end
    pcall(FlyTick)
    pcall(InfiniteStaminaTick)
    pcall(AutoSprintTick)
    pcall(NoclipTick)
    pcall(KnockFxTick)
    HUB.loops.move = false
end

-- High-frequency loop (RenderStepped): speedhack + face lock.
local renderConn = nil
local jumpConn = nil
local function StartRenderLoop()
    if renderConn then return end
    local renderOk, render = pcall(function()
        return RunService.RenderStepped:Connect(function()
            if HUB.dead then return end
            HUB.lastSpeedOk, HUB.lastSpeedError = pcall(SpeedhackTick)
            if autoGreen then HUB.lastGreenOk, HUB.lastGreenError = pcall(AutoGreenTick) end
            if autoRhythm then HUB.lastRhythmOk, HUB.lastRhythmError = pcall(AutoRhythmTick) end
            HUB.lastAnimOk, HUB.lastAnimError = pcall(AnimationSpeedTick)
            if faceLockEnabled then
                local t = GetTarget()
                if t then FaceTarget(t) end
            elseif faceHumanoid then
                RestoreFaceLock()
            end
        end)
    end)
    if renderOk and render then
        renderConn = render
        track(renderConn)
    end

    local jumpSignal = UserInputService and UserInputService.JumpRequest
    if jumpSignal then
        local jumpOk, conn = pcall(function()
            return jumpSignal:Connect(function()
                if not infiniteJump then return end
                local hum = GetMyHum()
                if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
            end)
        end)
        if jumpOk and conn then
            jumpConn = conn
            track(jumpConn)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE — ESP (native screen-space 2D ESP, no drawing lib needed)
-- ══════════════════════════════════════════════════════════════════════════════
local espGui = nil
local espCache = {}   -- [player] = { model, holder, box, stroke, tracer, dot, nameLbl, hpLbl, distLbl, hpBg, hpFill, hl }

local function HideEsp2D(e)
    if not e then return end
    for _, object in ipairs({ e.box, e.tracer, e.dot, e.nameLbl, e.hpLbl, e.distLbl, e.hpBg }) do
        if object then object.Visible = false end
    end
end

local function GetEspGui()
    if espGui and espGui.Parent then return espGui end
    local oldParents = {}
    pcall(function() table.insert(oldParents, game:GetService("CoreGui")) end)
    pcall(function() table.insert(oldParents, LocalPlayer:FindFirstChildOfClass("PlayerGui")) end)
    for _, parent in ipairs(oldParents) do
        local old = parent and parent:FindFirstChild("OxideESPGui")
        if old then pcall(function() old:Destroy() end) end
    end

    espGui = Instance.new("ScreenGui")
    espGui.Name = "OxideESPGui"
    espGui.ResetOnSpawn = false
    -- WorldToViewportPoint is used below, so IgnoreGuiInset keeps coordinates exact.
    espGui.IgnoreGuiInset = true
    espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    espGui.DisplayOrder = 40
    local parent
    local ok, result = pcall(function()
        if type(gethui) == "function" then return gethui() end
        return game:GetService("CoreGui")
    end)
    if ok then parent = result end
    if not parent then parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui") end
    local parentOk = pcall(function() espGui.Parent = parent end)
    if not parentOk or not espGui.Parent then
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
        pcall(function() espGui.Parent = playerGui end)
    end
    return espGui
end

local function MakeHolder()
    local holder = Instance.new("Frame")
    holder.Name = "OxideESPEntry"
    holder.Position = UDim2.fromOffset(0, 0)
    holder.Size = UDim2.fromScale(1, 1)
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.ClipsDescendants = false
    holder.Active = false
    holder.Parent = GetEspGui()
    return holder
end

local function MakeBox(holder)
    local box = Instance.new("Frame")
    box.BackgroundColor3 = espColor
    box.BackgroundTransparency = espFillTransparency
    box.BorderSizePixel = 0
    box.Visible = false
    box.ZIndex = 2
    box.Parent = holder
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.2
    stroke.Color = espColor
    stroke.Parent = box
    return box, stroke
end

local function MakeTracer(holder)
    local tr = Instance.new("Frame")
    -- Center the line on its midpoint. Using a left-anchored, one-pixel frame
    -- made the rotation look offset on different viewport sizes/insets.
    tr.AnchorPoint = Vector2.new(0.5, 0.5)
    tr.BorderSizePixel = 0
    tr.BackgroundColor3 = espColor
    tr.BackgroundTransparency = 0.05
    tr.Size = UDim2.fromOffset(0, 2)
    tr.Visible = false
    tr.ZIndex = 5
    tr.Parent = holder
    return tr
end

local function MakeDot(holder)
    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.BorderSizePixel = 0
    dot.BackgroundColor3 = espColor
    dot.Size = UDim2.fromOffset(6, 6)
    dot.Visible = false
    dot.ZIndex = 3
    dot.Parent = holder
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dot
    return dot
end

local function MakeLabel(holder, color)
    local lbl = Instance.new("TextLabel")
    lbl.AnchorPoint = Vector2.new(0.5, 0)
    lbl.Size = UDim2.fromOffset(320, 24)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = espFontSize
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0.35
    lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.TextWrapped = false
    lbl.Visible = false
    lbl.ZIndex = 4
    lbl.Parent = holder
    return lbl
end

local function MakeHpBar(holder)
    local bg = Instance.new("Frame")
    bg.AnchorPoint = Vector2.new(0.5, 0)
    bg.BorderSizePixel = 0
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    bg.Size = UDim2.fromOffset(60, 4)
    bg.Visible = false
    bg.ZIndex = 3
    bg.Parent = holder
    local fill = Instance.new("Frame")
    fill.BorderSizePixel = 0
    fill.BackgroundColor3 = Color3.fromRGB(120, 255, 120)
    fill.Size = UDim2.fromScale(1, 1)
    fill.ZIndex = 4
    fill.Parent = bg
    return bg, fill
end

local function BuildEspEntry(p, chr)
    local holder = MakeHolder()
    pcall(function() holder:SetAttribute("OxidePlayerUserId", p.UserId) end)
    local box, stroke = MakeBox(holder)
    local e = {
        model = chr,
        holder = holder,
        box = box,
        stroke = stroke,
        tracer = MakeTracer(holder),
        dot = MakeDot(holder),
        nameLbl = MakeLabel(holder, espColor),
        hpLbl = MakeLabel(holder, Color3.fromRGB(130, 255, 130)),
        distLbl = MakeLabel(holder, Color3.fromRGB(180, 190, 255)),
        hl = nil,
    }
    e.hpBg, e.hpFill = MakeHpBar(holder)
    espCache[p] = e
    return e
end

local function RemoveEspEntry(p)
    local e = espCache[p]
    if not e then return end
    HideEsp2D(e)
    if e.holder then pcall(function() e.holder:Destroy() end) end
    if e.hl then pcall(function() e.hl:Destroy() end) end
    espCache[p] = nil
end

local function HpColor(frac)
    frac = math.max(0, math.min(1, frac))
    return Color3.fromRGB(math.floor(255 * (1 - frac)), math.floor(255 * frac), 60)
end

local function ProjectModelBounds(cam, chr, head, hrp)
    -- Keep the tracer target tied to the live root part. A box midpoint can
    -- drift during animations or when a custom rig has an asymmetric bounds.
    local targetPoint = cam:WorldToViewportPoint(hrp.Position)
    local ok, boxCf, boxSize = pcall(function() return chr:GetBoundingBox() end)
    if not ok or not boxCf or not boxSize then
        boxCf, boxSize = CFrame.new(hrp.Position), Vector3.new(2, 5, 2)
    end
    local half = boxSize * 0.5
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyInFront = false
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local worldPoint = boxCf:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
                local screen = cam:WorldToViewportPoint(worldPoint)
                if screen.Z > 0 then
                    anyInFront = true
                    minX, minY = math.min(minX, screen.X), math.min(minY, screen.Y)
                    maxX, maxY = math.max(maxX, screen.X), math.max(maxY, screen.Y)
                end
            end
        end
    end
    -- Return the root projection even when the model bounds are temporarily
    -- behind the camera, so the tracer can make its own visibility decision.
    if not anyInFront then return nil, nil, nil, nil, nil, targetPoint end
    local headPoint = cam:WorldToViewportPoint(head.Position)
    return minX, minY, maxX, maxY, headPoint, targetPoint
end

local function UpdateTracer(e, viewport, targetPoint)
    if not (e and e.tracer and espTracers and targetPoint and targetPoint.Z > 0) then
        if e and e.tracer then e.tracer.Visible = false end
        return
    end

    -- The start point is inside the viewport. Clip the ray to the viewport so
    -- off-screen players get a clean edge tracer instead of a line that jumps
    -- across the UI or rotates around the wrong endpoint.
    local sx, sy = viewport.X * 0.5, math.max(0, viewport.Y - 3)
    local tx, ty = targetPoint.X, targetPoint.Y
    local dx, dy = tx - sx, ty - sy
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then
        e.tracer.Visible = false
        return
    end

    local scale = 1
    if dx > 0 then scale = math.min(scale, (viewport.X - sx) / dx)
    elseif dx < 0 then scale = math.min(scale, (0 - sx) / dx) end
    if dy > 0 then scale = math.min(scale, (viewport.Y - sy) / dy)
    elseif dy < 0 then scale = math.min(scale, (0 - sy) / dy) end
    scale = math.max(0, math.min(1, scale))
    local ex, ey = sx + dx * scale, sy + dy * scale
    local cdx, cdy = ex - sx, ey - sy
    local clippedLength = math.sqrt(cdx * cdx + cdy * cdy)
    if clippedLength < 1 then
        e.tracer.Visible = false
        return
    end

    e.tracer.Visible = true
    e.tracer.Position = UDim2.fromOffset((sx + ex) * 0.5, (sy + ey) * 0.5)
    e.tracer.Size = UDim2.fromOffset(clippedLength, 2)
    e.tracer.Rotation = math.deg(math.atan2(cdy, cdx))
    e.tracer.BackgroundColor3 = espColor
end

local function UpdateEsp()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    GetEspGui()
    local viewport = cam.ViewportSize
    local myHrp = GetMyHRP()

    local function processPlayer(p)
        local chr, hrp = GetChar(p), GetHRP(p)
        local head = chr and chr:FindFirstChild("Head")
        if not espEnabled or not chr or not hrp or not head then
            RemoveEspEntry(p)
            return
        end
        local myPos = myHrp and myHrp.Position or cam.CFrame.Position
        local dist = (hrp.Position - myPos).Magnitude
        if dist > espMaxDistance then
            RemoveEspEntry(p)
            return
        end

        local e = espCache[p]
        if e and e.model ~= chr then
            RemoveEspEntry(p)
            e = nil
        end
        e = e or BuildEspEntry(p, chr)

        if espHighlight then
            if not e.hl or e.hl.Adornee ~= chr then
                if e.hl then pcall(function() e.hl:Destroy() end) end
                e.hl = Instance.new("Highlight")
                e.hl.Name = "OxideESP"
                e.hl.Adornee = chr
                e.hl.Parent = chr
            end
            e.hl.FillColor = espColor
            e.hl.OutlineColor = espColor
            e.hl.FillTransparency = espFillTransparency or 0.5
            e.hl.OutlineTransparency = espOutlineTransparency or 0
            e.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        elseif e.hl then
            e.hl:Destroy()
            e.hl = nil
        end

        local minX, minY, maxX, maxY, headPoint, targetPoint = ProjectModelBounds(cam, chr, head, hrp)
        UpdateTracer(e, viewport, targetPoint)
        if not (minX and minY and maxX and maxY and headPoint and headPoint.Z > 0)
            or maxX < 0 or minX > viewport.X or maxY < 0 or minY > viewport.Y then
            HideEsp2D(e)
            UpdateTracer(e, viewport, targetPoint)
            return
        end
        local cx = (minX + maxX) * 0.5
        local topY, bottomY = minY, maxY
        local width, height = math.max(2, maxX - minX), math.max(4, maxY - minY)
        local hum = GetHum(p)
        local hp = hum and math.max(0, hum.Health) or 0
        local maxHp = hum and math.max(1, hum.MaxHealth) or 1
        local hpFrac = math.max(0, math.min(1, hp / maxHp))
        local fillTransparency = espFillTransparency or 0.5
        local outlineTransparency = espOutlineTransparency or 0
        e.box.BackgroundColor3 = espColor
        e.box.BackgroundTransparency = fillTransparency
        e.stroke.Color = espColor
        e.stroke.Transparency = outlineTransparency
        e.tracer.BackgroundColor3 = espColor
        e.dot.BackgroundColor3 = espColor
        e.nameLbl.TextColor3 = espColor
        e.hpLbl.TextColor3 = HpColor(hpFrac)
        e.distLbl.TextColor3 = espColor

        if espBoxes then
            e.box.Visible = true
            e.box.Position = UDim2.fromOffset(minX, topY)
            e.box.Size = UDim2.fromOffset(width, height)
        else e.box.Visible = false end

        if espHeadDot then
            e.dot.Visible = true
            e.dot.Position = UDim2.fromOffset(headPoint.X, headPoint.Y)
            e.dot.BackgroundColor3 = espColor
        else e.dot.Visible = false end

        -- Tracer positioning is handled from the root projection above so it
        -- stays attached to the character even when the box is clipped.

        local labelY = topY - 26
        if espShowName then
            e.nameLbl.Visible = true
            e.nameLbl.Text = p.Name
            e.nameLbl.TextSize = espFontSize
            e.nameLbl.Position = UDim2.fromOffset(cx, labelY)
            labelY = labelY - math.max(20, espFontSize + 3)
        else e.nameLbl.Visible = false end
        if espShowHealth then
            e.hpLbl.Visible = true
            e.hpLbl.Text = string.format("%.0f HP", hp)
            e.hpLbl.TextSize = math.max(8, espFontSize - 1)
            e.hpLbl.Position = UDim2.fromOffset(cx, labelY)
            labelY = labelY - math.max(18, espFontSize + 2)
        else e.hpLbl.Visible = false end
        if espHpBar then
            e.hpBg.Visible = true
            e.hpBg.Position = UDim2.fromOffset(cx, labelY)
            e.hpBg.Size = UDim2.fromOffset(math.max(24, width + 8), 4)
            e.hpFill.Size = UDim2.fromScale(hpFrac, 1)
            e.hpFill.BackgroundColor3 = HpColor(hpFrac)
        else e.hpBg.Visible = false end
        if espShowDistance then
            e.distLbl.Visible = true
            e.distLbl.Text = string.format("%.0f studs", dist)
            e.distLbl.TextSize = math.max(8, espFontSize - 1)
            e.distLbl.Position = UDim2.fromOffset(cx, bottomY + 2)
        else e.distLbl.Visible = false end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then processPlayer(p) end
    end
    local stale = {}
    for p in pairs(espCache) do
        if not p.Parent then table.insert(stale, p) end
    end
    for _, p in ipairs(stale) do RemoveEspEntry(p) end
end

local function CleanupEsp()
    local players = {}
    for p in pairs(espCache) do table.insert(players, p) end
    for _, p in ipairs(players) do RemoveEspEntry(p) end
    table.clear(espCache)
    if espGui then pcall(function() espGui:Destroy() end) end
    espGui = nil
end

local espRenderConn = nil
local function StartEspLoop()
    if espRenderConn then return end
    espRenderConn = RunService.RenderStepped:Connect(function()
        if HUB.dead then return end
        if espEnabled then
            HUB.lastEspOk, HUB.lastEspError = pcall(UpdateEsp)
        elseif espGui then
            CleanupEsp()
        end
    end)
    track(espRenderConn)
    track(Players.PlayerRemoving:Connect(function(p) RemoveEspEntry(p) end))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE — WORLD / LIGHTING
-- ══════════════════════════════════════════════════════════════════════════════
local origLighting = {}
local lowGfxOriginal = { captured = false, particles = {}, quality = nil }

local function ApplyFullBright(on)
    visualState.fullBright = on == true
    if on then
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e6
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    elseif not visualState.night then
        if origLighting.Brightness ~= nil then Lighting.Brightness = origLighting.Brightness end
        if origLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = origLighting.GlobalShadows end
        if origLighting.ClockTime ~= nil then Lighting.ClockTime = origLighting.ClockTime end
        if origLighting.FogEnd ~= nil then Lighting.FogEnd = origLighting.FogEnd end
        if origLighting.Ambient ~= nil then Lighting.Ambient = origLighting.Ambient end
        if origLighting.OutdoorAmbient ~= nil then Lighting.OutdoorAmbient = origLighting.OutdoorAmbient end
        if origLighting.FogColor ~= nil then Lighting.FogColor = origLighting.FogColor end
    end
end

local function ApplyNightMode(on)
    visualState.night = on == true
    if on then
        Lighting.ClockTime = 0
        Lighting.Brightness = 0.4
        Lighting.Ambient = Color3.fromRGB(20, 30, 60)
        Lighting.OutdoorAmbient = Color3.fromRGB(20, 30, 60)
        Lighting.FogColor = Color3.fromRGB(10, 15, 30)
    elseif not visualState.fullBright then
        if origLighting.Brightness ~= nil then Lighting.Brightness = origLighting.Brightness end
        if origLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = origLighting.GlobalShadows end
        if origLighting.ClockTime ~= nil then Lighting.ClockTime = origLighting.ClockTime end
        if origLighting.FogEnd ~= nil then Lighting.FogEnd = origLighting.FogEnd end
        if origLighting.Ambient ~= nil then Lighting.Ambient = origLighting.Ambient end
        if origLighting.OutdoorAmbient ~= nil then Lighting.OutdoorAmbient = origLighting.OutdoorAmbient end
        if origLighting.FogColor ~= nil then Lighting.FogColor = origLighting.FogColor end
    end
end

local function ApplyAmbient()
    local c = Color3.fromRGB(visualState.ambientR, visualState.ambientG, visualState.ambientB)
    Lighting.Ambient = c
    Lighting.OutdoorAmbient = c
    Notify("Ambient", string.format("Set to %d,%d,%d", visualState.ambientR, visualState.ambientG, visualState.ambientB), "Success")
end

local function ApplyLowGfx(on)
    if on then
        if not lowGfxOriginal.captured then
            lowGfxOriginal.captured = true
            lowGfxOriginal.quality = nil
            pcall(function() lowGfxOriginal.quality = settings().Rendering.QualityLevel end)
            for _, object in ipairs(Workspace:GetDescendants()) do
                if object:IsA("ParticleEmitter") or object:IsA("Trail") then
                    lowGfxOriginal.particles[object] = object.Enabled
                end
            end
        end
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 300
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        for object in pairs(lowGfxOriginal.particles) do
            if object and object.Parent then object.Enabled = false end
        end
    else
        if lowGfxOriginal.captured then
            local particles = {}
            for object in pairs(lowGfxOriginal.particles) do table.insert(particles, object) end
            for _, object in ipairs(particles) do
                local enabled = lowGfxOriginal.particles[object]
                if object and object.Parent then object.Enabled = enabled end
                lowGfxOriginal.particles[object] = nil
            end
            if lowGfxOriginal.quality ~= nil then
                pcall(function() settings().Rendering.QualityLevel = lowGfxOriginal.quality end)
            end
            if not visualState.fullBright and not visualState.night then
                if origLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = origLighting.GlobalShadows end
                if origLighting.FogEnd ~= nil then Lighting.FogEnd = origLighting.FogEnd end
            end
            lowGfxOriginal.captured = false
        end
    end
end

local function ApplyFov()
    local cam = Workspace.CurrentCamera
    if cam then cam.FieldOfView = math.max(30, math.min(120, tonumber(visualState.fov) or 70)) end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE — TELEPORT
-- ══════════════════════════════════════════════════════════════════════════════
local function TeleportTo(targetPos)
    local hrp = GetMyHRP()
    if not hrp then return false end
    if flyEnabled then
        hrp.CFrame = CFrame.new(targetPos)
    else
        local hum = GetHum(LocalPlayer)
        local c = CFrame.new(targetPos) * CFrame.new(0, 3, 0)
        if hum and hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        hrp.CFrame = c
    end
    return true
end

local function TeleportToPlayer(plr)
    local thrp = GetHRP(plr)
    if not thrp then Notify("Teleport", "Target has no character", "Error"); return end
    if TeleportTo(thrp.Position + Vector3.new(0, 2, 2)) then
        Notify("Teleport", "Teleported to " .. plr.Name, "Success")
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE — BASKETBALL / REROLL / FUN
-- ══════════════════════════════════════════════════════════════════════════════
function BasketballTick()
    if not basketballState.enabled then
        basketballState.char = nil
        basketballState.nextDribbleAt = 0
        basketballState.dribbleIndex = 1
        return
    end

    local charOk, chr = pcall(GetMyChar)
    if not charOk then
        HUB.lastBasketballError = tostring(chr)
        return
    end
    if not chr then return end
    basketballState.char = chr

    -- Use the game's own client API instead of mutating BasketballHoldingBall.
    -- The server still validates the request, but this removes the local no-op
    -- that made the old toggle appear enabled without doing anything.
    local now = os.clock()
    if now < basketballState.nextDribbleAt then return end
    local ok, service = pcall(function()
        local folder = ReplicatedStorage:FindFirstChild("Shared")
        local services = folder and folder:FindFirstChild("Services")
        local basketball = services and services:FindFirstChild("BasketballService")
        local module = basketball and basketball:FindFirstChild("BasketballServiceClient")
        return module and require(module):Get()
    end)
    local active = false
    if ok and service then
        local activeOk
        activeOk, active = pcall(function()
            return service:IsActive() and service:IsHoldingBall()
        end)
        if not activeOk then active = false end
    else
        active = AttributeIsTrue(chr, "BasketballActive")
            or AttributeIsTrue(chr, "BasketballHoldingBall")
            or AttributeIsTrue(chr, "BasketballMode")
    end
    if not active then
        basketballState.nextDribbleAt = now + 0.2
        return
    end

    local pattern = { "Z", "X", "C" }
    local key = pattern[basketballState.dribbleIndex]
    basketballState.dribbleIndex = basketballState.dribbleIndex % #pattern + 1
    if service then
        pcall(function() service:RequestDribble(key) end)
    else
        local remote = Remotes:FindFirstChild("Basketball")
        if remote and remote:IsA("RemoteEvent") then
            pcall(function() remote:FireServer({ "Dribble", key }) end)
        end
    end
    basketballState.nextDribbleAt = now + 0.12
end

local function DoReroll()
    local ok, res = pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        local services = shared and shared:FindFirstChild("Services")
        local reroll = services and services:FindFirstChild("RerollService")
        local serviceModule = reroll and reroll:FindFirstChild("RerollCurrencyServiceClient")
        if serviceModule then
            local service = require(serviceModule)
            if type(service.Get) == "function" then service = service:Get() end
            if type(service.RequestReroll) == "function" then
                return service:RequestReroll(rerollCategory)
            end
        end
        local remote = Remotes:FindFirstChild("RerollSpin")
        if not remote then return false, "RerollSpin unavailable" end
        return remote:InvokeServer(rerollCategory)
    end)
    if ok and res ~= false then
        Notify("Reroll", "Reroll requested: " .. tostring(rerollCategory), "Success", 2)
    else
        Notify("Reroll", "Reroll failed: " .. tostring(res), "Error", 3)
    end
end

local function ShowCurrentValues()
    local chr = GetMyChar()
    if not chr then Notify("Reroll", "No character", "Error"); return end
    local data = chr:FindFirstChild("PlayerData") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("PlayerData"))
    if not data then Notify("Reroll", "Player data unavailable", "Error"); return end
    local lines = {}
    for _, k in ipairs({ "HairDescription", "FaceAccessoryDescription", "HeadAccessoryDescription",
        "ShoulderAccessoryDescription", "NeckAccessoryDescription", "WaistAccessoryDescription",
        "BackAccessoryDescription", "FirstNameDescription", "LastNameDescription",
        "HairID", "FaceID", "HairColor", "SkinTone" }) do
        local v = data:GetAttribute(k)
        if v ~= nil and tostring(v) ~= "" then table.insert(lines, k .. ": " .. tostring(v)) end
    end
    Notify("Current Values", #lines > 0 and table.concat(lines, "\n") or "No values", "Info", 5)
end

local function FindHairUtils()
    local candidates = {}
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local services = shared and shared:FindFirstChild("Services")
    local hairService = services and services:FindFirstChild("HairService")
    if hairService then table.insert(candidates, hairService:FindFirstChild("HairServiceUtils")) end
    local directShared = shared and shared:FindFirstChild("HairService")
    if directShared then table.insert(candidates, directShared:FindFirstChild("HairServiceUtils")) end
    for _, module in ipairs(candidates) do
        if module and module:IsA("ModuleScript") then
            local ok, result = pcall(require, module)
            if ok and type(result) == "table" then return result end
        end
    end
    return nil
end

local function ApplyHairColor()
    local chr = GetMyChar()
    if not chr then Notify("Hair Color", "No character loaded", "Error"); return end
    local data = chr:FindFirstChild("PlayerData")
    if not data then Notify("Hair Color", "Player data is still loading", "Error"); return end

    -- HairColor is stored on PlayerData, while the live rig needs its managed
    -- accessory texture updated as well because the server does not respawn the
    -- character for a local color-picker change.
    local dataUpdated = pcall(function() data:SetAttribute("HairColor", hairColor) end)
    local utils = FindHairUtils()
    local hairTargets, seen = 0, {}

    local function isHairAccessory(accessory)
        if not accessory or not accessory:IsA("Accessory") then return false end
        if utils and type(utils.ShouldTintWithHairColor) == "function" then
            local ok, result = pcall(function() return utils.ShouldTintWithHairColor(accessory) end)
            if ok then return result == true end
        end
        if utils and type(utils.ShouldApplyHairColor) == "function" then
            local ok, result = pcall(function() return utils.ShouldApplyHairColor(accessory) end)
            if ok then return result == true end
        end
        if accessory:GetAttribute("GakuranHairAccessory") == true
            or accessory:GetAttribute("GakuranAccessoryType") == "Hair" then
            return true
        end
        local ok, accessoryType = pcall(function() return accessory.AccessoryType end)
        if ok and accessoryType == Enum.AccessoryType.Hair then return true end
        local handle = accessory:FindFirstChild("Handle")
        return handle and handle:FindFirstChild("HairColorTexture") ~= nil
    end

    local function tintAccessory(accessory)
        if seen[accessory] or not isHairAccessory(accessory) then return end
        seen[accessory] = true
        if utils and type(utils.ApplyHairColorToAccessory) == "function" then
            local ok = pcall(function() utils:ApplyHairColorToAccessory(accessory, hairColor) end)
            if ok then hairTargets = hairTargets + 1; return end
        end
        local handle = accessory:FindFirstChild("Handle")
        if not (handle and handle:IsA("BasePart")) then return end
        local texture = handle:FindFirstChild("HairColorTexture")
        if not texture then
            texture = Instance.new("Texture")
            texture.Name = "HairColorTexture"
            texture.Texture = "rbxassetid://845083731"
            texture.Parent = handle
        end
        if texture:IsA("Texture") then
            texture.Texture = "rbxassetid://845083731"
            texture.Color3 = hairColor
            hairTargets = hairTargets + 1
        end
    end

    for _, child in ipairs(chr:GetDescendants()) do
        if child:IsA("Accessory") then tintAccessory(child) end
    end
    if hairTargets > 0 then
        Notify("Hair Color", "Applied to " .. tostring(hairTargets) .. " hair target(s)", "Success", 2)
    elseif dataUpdated then
        Notify("Hair Color", "Color saved; hair will refresh with the next appearance update", "Success", 2)
    else
        Notify("Hair Color", "No supported hair accessory is loaded", "Error", 3)
    end
end

local function KillSelf()
    local hum = GetHum(LocalPlayer)
    if hum then hum.Health = 0 end
end

local function InstantRespawn()
    -- Fire only remotes that are actually present; never block the UI on a
    -- missing optional revive endpoint.
    local revive = Remotes:FindFirstChild("Revive")
    if revive and revive:IsA("RemoteEvent") then pcall(function() revive:FireServer() end) end
    task.wait(0.1)
    local loadCharacter = Remotes:FindFirstChild("LoadCharacter")
    if loadCharacter and loadCharacter:IsA("RemoteFunction") then
        pcall(function() loadCharacter:InvokeServer() end)
    end
    task.wait(0.3)
    if not GetChar(LocalPlayer) then pcall(function() LocalPlayer:LoadCharacter() end) end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ENGINE — SERVER
-- ══════════════════════════════════════════════════════════════════════════════
local function AntiAfkTick()
    if not antiAfk then return end
    local virtualUser = game:GetService("VirtualUser")
    pcall(function()
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end

local function FindStaff()
    for _, p in ipairs(Players:GetPlayers()) do
        local chr = GetChar(p)
        if chr and (chr:GetAttribute("StaffModPeaceMode") == true or chr:GetAttribute("Owner") == true) then
            return p
        end
        if p.Name:lower():find("mod") or p.Name:lower():find("admin") or p.Name:lower():find("staff") then
            return p
        end
    end
    return nil
end

local function AntiModTick()
    if not antiMod then return end
    local staff = FindStaff()
    if not staff then return end
    if antiModMethod == "Notify Only" then
        Notify("Anti Mod", "Staff detected: " .. staff.Name, "Error", 4)
    elseif antiModMethod == "Auto Disable" then
        -- Disable visible exploits while staff is near
        if espEnabled then espEnabled = false; CleanupEsp() end
        if flingAura then flingAura = false end
        if speedhack then speedhack = false; RestoreSpeed() end
        Notify("Anti Mod", "Staff nearby — combat visuals disabled", "Error", 4)
    end
end

local function ServerHop()
    local listRemote = Remotes:FindFirstChild("ServerListGet")
    if not listRemote or not listRemote:IsA("RemoteFunction") then
        Notify("Server Hop", "Server list unavailable", "Error")
        return
    end
    local ok, result = pcall(function()
        return listRemote:InvokeServer({ searchQuery = "", typeFilter = "all" })
    end)
    if not (ok and type(result) == "table") then
        Notify("Server Hop", "Server list unavailable", "Error")
        return
    end
    local entries = result.entries or result
    local selected
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and type(entry.jobId) == "string" and not entry.isCurrent then
            selected = entry.jobId
            break
        end
    end
    if not selected then
        Notify("Server Hop", "No other server found", "Info")
        return
    end
    local teleportRemote = Remotes:FindFirstChild("ServerListTeleport")
    if not teleportRemote or not teleportRemote:IsA("RemoteFunction") then
        Notify("Server Hop", "Teleport endpoint unavailable", "Error")
        return
    end
    local joined, response = pcall(function()
        return teleportRemote:InvokeServer(selected)
    end)
    if not joined or (type(response) == "table" and response.success == false) then
        Notify("Server Hop", "Teleport rejected", "Error")
    end
end

local function Rejoin()
    pcall(function()
        local ts = game:GetService("TeleportService")
        ts:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local chatState = { logs = {}, conns = {}, running = false, recent = {} }
local function AppendChat(userName, message)
    if type(message) ~= "string" or message == "" then return end
    local now = os.clock()
    local key = tostring(userName) .. "\0" .. message
    if chatState.recent[key] and now - chatState.recent[key] < 0.2 then return end
    chatState.recent[key] = now
    table.insert(chatState.logs, string.format("[%s] %s: %s", os.date("%H:%M:%S"), tostring(userName), message))
    while #chatState.logs > 200 do table.remove(chatState.logs, 1) end
end

local function WatchPlayerChat(player)
    if not player then return end
    local connection = player.Chatted:Connect(function(message)
        AppendChat(player.Name, message)
    end)
    table.insert(chatState.conns, connection)
    track(connection)
end

local function StartChatLogger()
    if chatState.running then return end
    chatState.running = true
    for _, player in ipairs(Players:GetPlayers()) do WatchPlayerChat(player) end
    local playerAddedConnection = Players.PlayerAdded:Connect(WatchPlayerChat)
    table.insert(chatState.conns, playerAddedConnection)
    track(playerAddedConnection)
    pcall(function()
        local textConnection = game:GetService("TextChatService").MessageReceived:Connect(function(message)
            local source = message.TextSource
            local player = source and Players:GetPlayerByUserId(source.UserId)
            AppendChat(player and player.Name or "Unknown", message.Text)
        end)
        table.insert(chatState.conns, textConnection)
        track(textConnection)
    end)
end

local function StopChatLogger()
    for _, connection in ipairs(chatState.conns) do
        pcall(function() connection:Disconnect() end)
        for i, tracked in ipairs(HUB.conns) do
            if tracked == connection then table.remove(HUB.conns, i); break end
        end
    end
    table.clear(chatState.conns)
    table.clear(chatState.recent)
    chatState.running = false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- UI
-- ══════════════════════════════════════════════════════════════════════════════

-- ── Tab 1: Combat ─────────────────────────────────────────────────────────────
CombatTab = Window:AddTab({ Name = "Combat", Subtitle = "Parry, dodge & punish", Icon = "sword" })

-- Auto Parry
ParrySub = CombatTab:AddSubTab("Auto Parry")
ParrySub:AddToggle({
    Name = "Enable Auto Parry",
    Default = false,
    Flag = "parry_enabled",
    Callback = safeCallback(function(v)
        parryEnabled = v
        notifyOn("Auto Parry", v)
        if v then
            DoEquip()
            StartCombatLoop()
        end
    end),
})
ParrySub:AddSlider({
    Name = "Detection Range",
    Min = 5, Max = 50, Default = 18, Suffix = " studs",
    Flag = "detection_range",
    Callback = function(v) detectionRange = v end,
})
ParrySub:AddToggle({
    Name = "Evasive Mode",
    Default = false,
    Flag = "evasive_mode",
    Callback = safeCallback(function(v)
        evasiveMode = v
        notifyOn("Evasive Mode", v)
        if v then StartCombatLoop() end
    end),
})
ParrySub:AddToggle({
    Name = "Evasive Directional",
    Default = false,
    Flag = "evasive_directional",
    Callback = function(v) evasiveDirectional = v end,
})
ParrySub:AddToggle({
    Name = "Parry Only",
    Default = false,
    Flag = "parry_only",
    Callback = function(v) parryOnly = v end,
})
ParrySub:AddToggle({
    Name = "Pause M1 for Parry",
    Default = false,
    Flag = "pause_m1_for_parry",
    Callback = function(v) pauseM1ForParry = v end,
})
ParrySub:AddDropdown({
    Name = "Priority",
    Options = { "Parry", "Evasive" },
    Default = "Parry",
    Flag = "priority",
    Callback = function(v) priority = v end,
})
ParrySub:AddSlider({
    Name = "Facing Strictness",
    Min = 0, Max = 1, Default = 0.6, Suffix = "",
    Flag = "facing_strictness",
    Callback = function(v) facingStrictness = v end,
})
ParrySub:AddToggle({
    Name = "No Parry Cooldown",
    Default = false,
    Flag = "no_parry_cd",
    Callback = function(v)
        noParryCooldown = v
        StartCombatLoop()
    end,
})
ParrySub:AddToggle({
    Name = "No Dodge Cooldown",
    Default = false,
    Flag = "no_dodge_cd",
    Callback = function(v)
        noDodgeCooldown = v
        StartCombatLoop()
    end,
})

-- Combat Tweaks
TweaksSub = CombatTab:AddSubTab("Combat Tweaks")
TweaksSub:AddToggle({
    Name = "Auto Punish",
    Default = false,
    Flag = "auto_punish",
    Callback = safeCallback(function(v)
        autoPunish = v
        notifyOn("Auto Punish", v)
        if v then StartCombatLoop() end
    end),
})
TweaksSub:AddDropdown({
    Name = "Punish Method",
    Options = { "M2", "M1" },
    Default = "M2",
    Flag = "punish_method",
    Callback = function(v) punishMethod = v end,
})
TweaksSub:AddToggle({
    Name = "Fling Aura",
    Default = false,
    Flag = "fling_aura",
    Callback = safeCallback(function(v)
        flingAura = v
        notifyOn("Fling Aura", v)
        if v then StartCombatLoop() end
    end),
})
TweaksSub:AddToggle({
    Name = "No Stun",
    Default = false,
    Flag = "no_stun",
    Callback = function(v)
        noStun = v
        if v then StartCombatLoop() end
    end,
})
TweaksSub:AddToggle({
    Name = "No Ragdoll",
    Default = false,
    Flag = "no_ragdoll",
    Callback = function(v)
        noRagdoll = v
        if v then StartCombatLoop() end
    end,
})
TweaksSub:AddToggle({
    Name = "Lag Switch",
    Default = false,
    Flag = "lag_switch",
    Callback = safeCallback(function(v)
        lagSwitch = v
        notifyOn("Lag Switch", v)
        if not v and lagAnchoredHrp and lagAnchoredHrp.Parent then lagAnchoredHrp.Anchored = false end
        if v then StartLagSwitchLoop() end
    end),
})
TweaksSub:AddToggle({
    Name = "Disable Glasses Knocked",
    Default = false,
    Flag = "disable_glasses",
    Callback = function(v)
        disableGlassesKnocked = v
        if not v then RestoreGlasses() end
        if v then StartMovementLoop() end
    end,
})
TweaksSub:AddToggle({
    Name = "No Blur When Knocked",
    Default = false,
    Flag = "no_blur",
    Callback = function(v)
        noBlurWhenKnocked = v
        if not v then RestoreBlur() end
        if v then StartMovementLoop() end
    end,
})

-- Face Lock
LockSub = CombatTab:AddSubTab("Face Lock")
LockSub:AddToggle({
    Name = "Face Lock",
    Default = false,
    Flag = "face_lock",
    Callback = safeCallback(function(v)
        faceLockEnabled = v
        notifyOn("Face Lock", v)
        if v then StartCombatLoop() else RestoreFaceLock() end
    end),
})
LockSub:AddToggle({
    Name = "Sticky Target",
    Default = false,
    Flag = "sticky_target",
    Callback = function(v)
        stickyTarget = v
        if not v then lockedTarget = nil end
    end,
})
targetDropdown = LockSub:AddDropdown({
    Name = "Select Player",
    Options = {},
    Default = "",
    Flag = "target_player",
    Callback = function(v) selectedTargetName = v end,
})
LockSub:AddButton({
    Name = "Refresh Players",
    Callback = safeCallback(function()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        if targetDropdown and targetDropdown.SetOptions then
            targetDropdown:SetOptions(names)
        end
        Notify("Players", "Refreshed (" .. #names .. ")", "Success")
    end),
})
whitelistDropdown = LockSub:AddMultiDropdown({
    Name = "Whitelist Players",
    Options = {},
    Default = {},
    Flag = "whitelist",
    Callback = function(sel)
        whitelist = {}
        for _, name in ipairs(sel or {}) do
            local p = Players:FindFirstChild(name)
            if p then whitelist[p.UserId] = true end
        end
    end,
})

-- Auto Green
GreenSub = CombatTab:AddSubTab("Auto Green")
GreenSub:AddToggle({
    Name = "Auto Green",
    Default = false,
    Flag = "auto_green",
    Callback = safeCallback(function(v)
        autoGreen = v
        notifyOn("Auto Green", v)
    end),
})
GreenSub:AddDropdown({
    Name = "Accuracy",
    Options = { "Perfect", "Good", "Okay", "Bad", "Miss" },
    Default = "Perfect",
    Flag = "green_accuracy",
    Callback = function(v) greenAccuracy = v end,
})

-- Auto Rhythm
RhythmSub = CombatTab:AddSubTab("Auto Rhythm")
RhythmSub:AddToggle({
    Name = "Auto Rhythm",
    Default = false,
    Flag = "auto_rhythm",
    Callback = safeCallback(function(v)
        autoRhythm = v == true or v == 1
            or (type(v) == "string" and v:lower() == "true")
        if not autoRhythm then ReleaseRhythmKeys() end
        notifyOn("Auto Rhythm", autoRhythm)
    end),
})
RhythmSub:AddToggle({
    Name = "Vertical",
    Default = false,
    Flag = "rhythm_vertical",
    Callback = safeCallback(function(v)
        local ok, err = pcall(function()
            local target
            local module = ReplicatedStorage:FindFirstChild("Shared")
            local services = module and module:FindFirstChild("Services")
            local rhythm = services and services:FindFirstChild("RhythmService")
            local settingsModule = rhythm and rhythm:FindFirstChild("RhythmSettingsClient")
            if settingsModule then
                local settings = require(settingsModule)
                if settings.Get then settings = settings:Get() end
                if rhythmState.originalVertical == nil then
                    rhythmState.originalVertical = settings:IsUpscrollEnabled()
                end
                target = v and true or rhythmState.originalVertical
                if not settings:SetUpscrollEnabled(target) then error("server rejected rhythm setting") end
                rhythmState.settings = settings
            else
                local remote = Remotes:FindFirstChild("RhythmSettings")
                if not remote or not remote:IsA("RemoteFunction") then error("Rhythm settings API unavailable") end
                local got, stored = pcall(function() return remote:InvokeServer("Get") end)
                if not got or type(stored) ~= "table" then error("could not read rhythm settings") end
                if rhythmState.originalVertical == nil then rhythmState.originalVertical = stored.upscroll == true end
                target = v and true or rhythmState.originalVertical
                stored.upscroll = target
                local saved, result = pcall(function() return remote:InvokeServer("Set", stored) end)
                if not saved or result ~= true then error("server rejected rhythm setting") end
            end
            if not v then rhythmState.originalVertical = nil end
        end)
        if not ok then Notify("Auto Rhythm", "Vertical setting failed: " .. tostring(err), "Error", 3) end
    end),
})
RhythmSub:AddSlider({
    Name = "Smooth Factor",
    Min = 0, Max = 1, Default = 0.5, Suffix = "",
    Flag = "rhythm_smooth",
    Callback = function(v) rhythmSmoothFactor = v end,
})
RhythmSub:AddSlider({
    Name = "Animation Speed",
    Min = 0.5, Max = 3, Default = 1, Suffix = "x",
    Flag = "anim_speed",
    Callback = function(v)
        animSpeed = v
        if v == 1 then RestoreAnimationSpeeds() end
    end,
})

-- ── Tab 2: Visuals ────────────────────────────────────────────────────────────
VisualTab = Window:AddTab({ Name = "Visuals", Subtitle = "ESP & world", Icon = "eye" })

EspSub = VisualTab:AddSubTab("Player ESP")
EspSub:AddToggle({
    Name = "Player ESP",
    Default = false,
    Flag = "esp_enabled",
    Callback = safeCallback(function(v)
        espEnabled = v == true or v == 1
            or (type(v) == "string" and v:lower() == "true")
        notifyOn("Player ESP", espEnabled)
        if espEnabled then
            StartEspLoop()
        else
            CleanupEsp()
        end
    end),
})
EspSub:AddColorPicker({
    Name = "ESP Color",
    Default = Color3.fromRGB(255, 255, 255),
    Flag = "esp_color",
    Callback = function(v)
        espColor = v
        for _, e in pairs(espCache) do
            if e.box then e.box.BackgroundColor3 = v end
            if e.stroke then e.stroke.Color = v end
            if e.tracer then e.tracer.BackgroundColor3 = v end
            if e.dot then e.dot.BackgroundColor3 = v end
            if e.nameLbl then e.nameLbl.TextColor3 = v end
            if e.distLbl then e.distLbl.TextColor3 = v end
            if e.hl then e.hl.FillColor = v; e.hl.OutlineColor = v end
        end
    end,
})
EspSub:AddToggle({
    Name = "Boxes",
    Default = false,
    Flag = "esp_boxes",
    Callback = function(v) espBoxes = v end,
})
EspSub:AddSlider({
    Name = "Fill Transparency",
    Min = 0, Max = 1, Default = 0.5, Suffix = "",
    Flag = "esp_fill_transparency",
    Callback = function(v) espFillTransparency = v end,
})
EspSub:AddSlider({
    Name = "Outline Transparency",
    Min = 0, Max = 1, Default = 0, Suffix = "",
    Flag = "esp_outline_transparency",
    Callback = function(v) espOutlineTransparency = v end,
})
EspSub:AddToggle({
    Name = "Highlight",
    Default = false,
    Flag = "esp_highlight",
    Callback = function(v) espHighlight = v end,
})
EspSub:AddToggle({
    Name = "Head Dot",
    Default = false,
    Flag = "esp_head_dot",
    Callback = function(v) espHeadDot = v end,
})
EspSub:AddToggle({
    Name = "Tracers",
    Default = false,
    Flag = "esp_tracers",
    Callback = function(v) espTracers = v end,
})
EspSub:AddToggle({
    Name = "HP Bar",
    Default = false,
    Flag = "esp_hpbar",
    Callback = function(v) espHpBar = v end,
})
EspSub:AddToggle({
    Name = "Name",
    Default = true,
    Flag = "esp_name",
    Callback = function(v) espShowName = v end,
})
EspSub:AddToggle({
    Name = "Health",
    Default = true,
    Flag = "esp_health",
    Callback = function(v) espShowHealth = v end,
})
EspSub:AddToggle({
    Name = "Distance",
    Default = true,
    Flag = "esp_distance",
    Callback = function(v) espShowDistance = v end,
})
EspSub:AddSlider({
    Name = "Max Distance",
    Min = 50, Max = 2000, Default = 500, Suffix = "",
    Flag = "esp_max_distance",
    Callback = function(v) espMaxDistance = v end,
})
EspSub:AddSlider({
    Name = "Font Size",
    Min = 10, Max = 30, Default = 14, Suffix = "",
    Flag = "esp_font_size",
    Callback = function(v) espFontSize = v end,
})

WorldSub = VisualTab:AddSubTab("World / Lighting")
WorldSub:AddToggle({
    Name = "Full Bright",
    Default = false,
    Flag = "full_bright",
    Callback = function(v)
        ApplyFullBright(v)
    end,
})
WorldSub:AddToggle({
    Name = "Night Mode",
    Default = false,
    Flag = "night_mode",
    Callback = function(v)
        ApplyNightMode(v)
    end,
})
WorldSub:AddSlider({
    Name = "Ambient R", Min = 0, Max = 255, Default = 120, Suffix = "",
    Flag = "ambient_r", Callback = function(v) visualState.ambientR = v end,
})
WorldSub:AddSlider({
    Name = "Ambient G", Min = 0, Max = 255, Default = 120, Suffix = "",
    Flag = "ambient_g", Callback = function(v) visualState.ambientG = v end,
})
WorldSub:AddSlider({
    Name = "Ambient B", Min = 0, Max = 255, Default = 120, Suffix = "",
    Flag = "ambient_b", Callback = function(v) visualState.ambientB = v end,
})
WorldSub:AddButton({
    Name = "Apply Ambient",
    Callback = safeCallback(ApplyAmbient),
})
WorldSub:AddSlider({
    Name = "Camera FOV",
    Min = 30, Max = 120, Default = 70, Suffix = "",
    Flag = "camera_fov",
    Callback = function(v) visualState.fov = v; ApplyFov() end,
})
WorldSub:AddToggle({
    Name = "Low GFX",
    Default = false,
    Flag = "low_gfx",
    Callback = function(v)
        ApplyLowGfx(v)
    end,
})

-- ── Tab 3: Movement ───────────────────────────────────────────────────────────
MoveTab = Window:AddTab({ Name = "Movement", Subtitle = "Speed, fly & teleport", Icon = "run" })

MoveSub = MoveTab:AddSubTab("Movement")
MoveSub:AddToggle({
    Name = "Speedhack",
    Default = false,
    Flag = "speedhack",
    Callback = function(v)
        speedhack = v
        if not v then RestoreSpeed() end
        StartMovementLoop()
    end,
})
MoveSub:AddSlider({
    Name = "Speed",
    Min = 16, Max = 300, Default = 32, Suffix = "",
    Flag = "speedhack_value",
    Callback = function(v) speedhackValue = v end,
})
MoveSub:AddToggle({
    Name = "Fly",
    Default = false,
    Flag = "fly",
    Callback = safeCallback(function(v)
        flyEnabled = v
        ApplyFly(v)
        StartMovementLoop()
        notifyOn("Fly", v)
    end),
})
MoveSub:AddSlider({
    Name = "Fly Speed",
    Min = 10, Max = 200, Default = 50, Suffix = "",
    Flag = "fly_speed",
    Callback = function(v) flySpeed = v end,
})
MoveSub:AddToggle({
    Name = "Infinite Jump",
    Default = false,
    Flag = "inf_jump",
    Callback = function(v)
        infiniteJump = v
        StartMovementLoop()
    end,
})
MoveSub:AddToggle({
    Name = "Infinite Stamina",
    Default = false,
    Flag = "inf_stamina",
    Callback = function(v)
        infiniteStamina = v
        if not v then RestoreStamina() end
        StartMovementLoop()
    end,
})
MoveSub:AddToggle({
    Name = "Auto Sprint",
    Default = false,
    Flag = "auto_sprint",
    Callback = function(v)
        autoSprint = v
        if not v then StopAutoSprint() end
        StartMovementLoop()
    end,
})
MoveSub:AddToggle({
    Name = "Noclip",
    Default = false,
    Flag = "noclip",
    Callback = function(v)
        noclip = v
        if not v then RestoreNoclip() end
        StartMovementLoop()
    end,
})

TeleportSub = MoveTab:AddSubTab("Teleport")
tpPlayerDropdown = TeleportSub:AddDropdown({
    Name = "Teleport",
    Options = {},
    Default = "",
    Flag = "tp_player",
    Callback = function(v) teleportState.target = v end,
})
TeleportSub:AddButton({
    Name = "Teleport",
    Callback = safeCallback(function()
        local p = teleportState.target and Players:FindFirstChild(teleportState.target)
        if p then TeleportToPlayer(p) else Notify("Teleport", "Select a player", "Error") end
    end),
})
TeleportSub:AddButton({
    Name = "Save Waypoint",
    Callback = safeCallback(function()
        local hrp = GetHRP(LocalPlayer)
        if hrp then teleportState.waypoint = hrp.Position; Notify("Waypoint", "Saved", "Success") end
    end),
})
TeleportSub:AddButton({
    Name = "Teleport to Waypoint",
    Callback = safeCallback(function()
        if teleportState.waypoint then TeleportTo(teleportState.waypoint); Notify("Waypoint", "Teleported", "Success") end
    end),
})

-- ── Tab 4: Misc ───────────────────────────────────────────────────────────────
MiscTab = Window:AddTab({ Name = "Misc", Subtitle = "Game & server", Icon = "star" })

-- Basketball
BallSub = MiscTab:AddSubTab("Basketball")
BallSub:AddToggle({
    Name = "No Dribble Cooldown",
    Default = false,
    Flag = "no_dribble_cd",
    Callback = function(v)
        basketballState.enabled = v
        if not v then BasketballTick() end
        StartMovementLoop()
    end,
})

-- Reroll
RerollSub = MiscTab:AddSubTab("Reroll")
RerollSub:AddDropdown({
    Name = "Reroll",
    Options = { "HairColor", "Ethnicity", "Height", "Gender", "FirstName", "LastName", "HairID", "FaceID", "FightStyle", "Uniform", "FaceAccessoryID", "HeadAccessoryID", "ShoulderAccessoryID", "NeckAccessoryID", "WaistAccessoryID", "BackAccessoryID" },
    Default = "FaceID",
    Flag = "reroll_category",
    Callback = function(v) rerollCategory = v end,
})
RerollSub:AddButton({
    Name = "Reroll",
    Callback = safeCallback(DoReroll),
})
RerollSub:AddButton({
    Name = "Show Current Values",
    Callback = safeCallback(ShowCurrentValues),
})
RerollSub:AddButton({
    Name = "Stop All Rerolls",
    Callback = safeCallback(function()
        Notify("Reroll", "Stopped", "Info")
    end),
})
RerollSub:AddColorPicker({
    Name = "Change Hair Color",
    Default = Color3.fromRGB(0, 0, 0),
    Flag = "hair_color",
    Callback = safeCallback(function(v)
        hairColor = v
        HUB.lastHairOk, HUB.lastHairError = pcall(ApplyHairColor)
    end),
})

-- Fun
FunSub = MiscTab:AddSubTab("Fun")
FunSub:AddButton({
    Name = "Kill Self",
    Callback = safeCallback(function()
        KillSelf()
        Notify("Fun", "RIP", "Info")
    end),
})
FunSub:AddButton({
    Name = "Instant Respawn",
    Callback = safeCallback(InstantRespawn),
})

-- Server
ServerSub = MiscTab:AddSubTab("Server")
ServerSub:AddToggle({
    Name = "Anti AFK",
    Default = false,
    Flag = "anti_afk",
    Callback = function(v) antiAfk = v end,
})
ServerSub:AddToggle({
    Name = "Anti Mod",
    Default = false,
    Flag = "anti_mod",
    Callback = function(v) antiMod = v end,
})
ServerSub:AddDropdown({
    Name = "Anti Mod Method",
    Options = { "Auto Disable", "Notify Only" },
    Default = "Auto Disable",
    Flag = "anti_mod_method",
    Callback = function(v) antiModMethod = v end,
})
ServerSub:AddButton({
    Name = "Rejoin",
    Callback = safeCallback(Rejoin),
})
ServerSub:AddButton({
    Name = "Server Hop",
    Callback = safeCallback(ServerHop),
})
ServerSub:AddToggle({
    Name = "Chat Logger",
    Default = false,
    Flag = "chat_logger",
    Callback = function(v)
        if v then StartChatLogger() else StopChatLogger() end
    end,
})
ServerSub:AddButton({
    Name = "Show Chat Log",
    Callback = safeCallback(function()
        if #chatState.logs == 0 then Notify("Chat Log", "Empty", "Info"); return end
        local shown = table.concat(chatState.logs, "\n")
        Notify("Chat Log", #shown > 500 and shown:sub(1, 500) .. "..." or shown, "Info", 8)
    end),
})

-- Settings
SettingsSub = MiscTab:AddSubTab("Settings")
SettingsSub:AddButton({
    Name = "Save Config",
    Callback = function()
        if HAS_CONFIG then Library:SaveConfig(CONFIG_NAME); Notify("Config", "Saved!", "Success") end
    end,
})
SettingsSub:AddButton({
    Name = "Load Config",
    Callback = function()
        if HAS_CONFIG then Library:LoadConfig(CONFIG_NAME); Notify("Config", "Loaded!", "Success") end
    end,
})
SettingsSub:AddKeybind({
    Name = "Menu Keybind",
    Default = Enum.KeyCode.RightShift,
    Flag = "menu_keybind",
    OnPress = function()
        local sg = Window and Window.ScreenGui
        if sg then sg.Enabled = not sg.Enabled end
    end,
})
SettingsSub:AddButton({
    Name = "Unload",
    Callback = safeCallback(function()
        Notify("Oxide HUB", "Script unloaded", "Info")
        HUB.Unload()
    end),
})

-- ══════════════════════════════════════════════════════════════════════════════
-- PERSISTENT LOOPS (anti-afk, anti-mod, basketball, render)
-- ══════════════════════════════════════════════════════════════════════════════
track(task.spawn(function()
    while not HUB.dead do
        HUB.lastAfkOk, HUB.lastAfkError = pcall(AntiAfkTick)
        HUB.lastModOk, HUB.lastModError = pcall(AntiModTick)
        task.wait(1)
    end
end))

-- High-frequency features (speedhack / face lock / infinite jump) always on
StartRenderLoop()

-- ══════════════════════════════════════════════════════════════════════════════
-- GAME API INIT (after UI so failure only degrades engine)
-- ══════════════════════════════════════════════════════════════════════════════
-- Cache original lighting so we can restore
origLighting.Brightness = Lighting.Brightness
origLighting.GlobalShadows = Lighting.GlobalShadows
origLighting.ClockTime = Lighting.ClockTime
origLighting.FogEnd = Lighting.FogEnd
origLighting.Ambient = Lighting.Ambient
origLighting.OutdoorAmbient = Lighting.OutdoorAmbient
origLighting.FogColor = Lighting.FogColor
local initialCamera = Workspace.CurrentCamera
visualState.origFov = initialCamera and initialCamera.FieldOfView or 70

InitGameApi()
if ENV_OK then
    Notify("Gakuran", "Game API connected ✓", "Success", 3)
else
    Notify("Gakuran", "Game API not found — UI only", "Error", 4)
end

-- Refresh player dropdowns once loaded
task.delay(1, function()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    if targetDropdown and targetDropdown.SetOptions then targetDropdown:SetOptions(names) end
    if tpPlayerDropdown and tpPlayerDropdown.SetOptions then tpPlayerDropdown:SetOptions(names) end
    if whitelistDropdown and whitelistDropdown.SetOptions then whitelistDropdown:SetOptions(names) end
end)

function HUB.Unload()
    if HUB.dead then return end
    HUB.dead = true
    parryEnabled, evasiveMode, autoPunish, flingAura = false, false, false, false
    noStun, noRagdoll, lagSwitch = false, false, false
    speedhack, flyEnabled, infiniteJump, infiniteStamina, autoSprint, noclip = false, false, false, false, false, false
    espEnabled = false
    basketballState.enabled = false
    autoRhythm = false
    ReleaseRhythmKeys()
    if lagAnchoredHrp and lagAnchoredHrp.Parent then lagAnchoredHrp.Anchored = false end
    lagAnchoredHrp = nil
    StopChatLogger()
    RestoreFaceLock()
    RestoreSpeed()
    RestoreStamina()
    StopAutoSprint()
    RestoreNoclip()
    CleanupEsp()
    CleanupFly()
    RestoreKnockFx()
    RestoreAnimationSpeeds()
    ApplyLowGfx(false)
    ApplyFullBright(false)
    ApplyNightMode(false)
    local currentCamera = Workspace.CurrentCamera
    if currentCamera and visualState.origFov ~= nil then currentCamera.FieldOfView = visualState.origFov end
    for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
    table.clear(HUB.conns)
    pcall(function() Window:Destroy() end)
    _G.OxideGakuran = nil
end

print("[Oxide HUB] Gakuran loaded. ENV_OK:", ENV_OK)
end

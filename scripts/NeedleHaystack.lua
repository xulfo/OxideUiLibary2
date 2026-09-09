-- === HUB STRIP POINT - when executed through the hub ScriptLoader, which injects
--     "local Library = _G.OxideLib" above this line instead. ===
-- ==============================================================================

-- ==============================================================================
-- RE-EXECUTION GUARD + RESOURCE TRACKING
-- ==============================================================================
do
    local prev = _G.OxideNeedleHaystack
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, drawings = {}, highlights = {}, dead = false, loops = {} }
_G.OxideNeedleHaystack = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end
local function trackHighlight(h) if h then table.insert(HUB.highlights, h) end; return h end

-- interval: 0 (or nil) = every frame, >0 = run at most every N seconds
local function TrackLoop(id, fn, interval)
    HUB.loops[id] = true
    task.spawn(function()
        local last = 0
        while HUB.loops[id] and not HUB.dead do
            local now = os.clock()
            if (interval or 0) <= 0 or (now - last) >= interval then
                last = now
                local ok, err = pcall(fn)
                if not ok then warn("[Oxide NeedleHaystack] loop error " .. tostring(id) .. ": " .. tostring(err)) end
            end
            task.wait()
        end
    end)
end

local function KillLoop(id)
    HUB.loops[id] = nil
end

local Window = Library:CreateWindow({
    Name = "Oxide HUB | Kapitel 1 (Bauernhaus)",
    LoadingAnimation = true,
    LoadingText = "Oxide",
    LoadingDuration = 2.0,
})

-- ==============================================================================
-- CONFIG / FLAG PERSISTENCE
-- ==============================================================================
local HAS_CONFIG = type(Library.SaveConfig) == "function"
    and type(Library.LoadConfig) == "function"
    and type(Library.ListConfigs) == "function"
local CONFIG_NAME = "needlehaystack"

-- ==============================================================================
-- SERVICES & LOCALS
-- ==============================================================================
local Players             = game:GetService("Players")
local RS                  = game:GetService("ReplicatedStorage")
local ReplicatedStorage   = RS
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local Workspace           = game:GetService("Workspace")
local Lighting            = game:GetService("Lighting")
local TweenService        = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LP          = Players.LocalPlayer
local LocalPlayer = LP

local function GetCamera()
    return Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
end
local function GetChar()
    return LP.Character
end
local function GetHRP()
    local c = GetChar()
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end
local function GetHumanoid()
    local c = GetChar()
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

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

local function notifyOn(name, on)
    Notify(name, on and "Enabled" or "Disabled", on and "Success" or "Info", 1.2)
end

-- ==============================================================================
-- GAME KNOWLEDGE (from decompiled NeedleHaystack.Config / Surface)
-- ==============================================================================
local NH_FOLDER = "NeedleHaystack"
local PILE_CENTER   = Vector3.new(-199.18434, 2.1, 30.241207)
local PILE_RADIUS   = 17
local PILE_HEIGHT   = 12
local PROFILE_POWER = 1.35
local SELL_POS      = Vector3.new(-161.28688049316406, 6.126363754272461, 56.90555191040039)

local function GetNH()
    return RS:FindFirstChild(NH_FOLDER)
end
local function Remote(name)
    local nh = GetNH()
    return nh and nh:FindFirstChild(name) or nil
end

-- dome surface height at horizontal radius r (absolute Y, pile base at PILE_CENTER.Y)
local function surfaceHeight(r)
    local f = 1 - (r / PILE_RADIUS) * (r / PILE_RADIUS)
    if f <= 0 then return 0 end
    return PILE_CENTER.Y + PILE_HEIGHT * (f ^ PROFILE_POWER)
end
local function surfacePoint(angle, radius)
    return PILE_CENTER + Vector3.new(math.cos(angle) * radius, surfaceHeight(radius) - PILE_CENTER.Y, math.sin(angle) * radius)
end

local function GetHayState()
    local r = Remote("GetHayState")
    if not r then return nil end
    local ok, st = pcall(function() return r:InvokeServer() end)
    if ok and type(st) == "table" then return st end
    return nil
end
local function GetUpgradeState()
    local r = Remote("GetUpgradeState")
    if not r then return nil end
    local ok, st = pcall(function() return r:InvokeServer() end)
    if ok and type(st) == "table" then return st end
    return nil
end

local function Fire(name, ...)
    local r = Remote(name)
    if not r then return end
    local args = { ... }
    pcall(function() r:FireServer(unpack(args)) end)
end
local function Invoke(name, ...)
    local r = Remote(name)
    if not r then return nil end
    local args = { ... }
    local ok, res = pcall(function() return r:InvokeServer(unpack(args)) end)
    if ok then return res end
    return nil
end

-- ==============================================================================
-- SETTINGS (live state, driven by UI)
-- ==============================================================================
local S = {
    -- Auto
    autoDig         = false,
    digMode         = "Spiral",   -- Spiral / Ring / Center / Random
    digRadius       = 8,
    digPause        = 0.62,       -- matches base PICK_COOLDOWN (0.55)
    useGameInput    = true,       -- mouse-hold through the game's own client path
    autoSell        = false,
    sellThreshold   = 20,         -- sell when held >= threshold
    autoGems        = false,
    collectWith     = "Hand",
    -- Upgrades
    autoUpgrade     = false,
    maxUpgradeCost  = 100,
    upgradeTracks   = {},         -- track -> enabled
    -- ESP
    espEnabled      = false,
    espRainbow      = true,
    espNeedle       = true,
    espGems         = true,
    -- Player
    walkSpeed       = 16,
    jumpPower       = 50,
    infiniteJump    = false,
    fly             = false,
    noclip          = false,
    antiAFK         = false,
    fullbright      = false,
    -- internal
    _digAngle       = 0,
    _lastSell       = 0,
    _lastGems       = 0,
    _gemCache       = {},
    _needleCache    = {},
    _rainbowCache   = {},
    _lastStateTick  = 0,
    _stateLabels    = {},
}

local TRACK_COSTS = {
    Capacity          = { 0, 1, 2.5, 5, 10 },
    HandHold          = { 0, 1 },
    Speed             = { 0, 0.25, 0.5, 1, 2, 3 },
    Grab              = { 0, 0.25, 0.5, 1, 2, 4 },
    TntLuck           = { 0, 3, 6, 12, 24, 45 },
    TntCooldown       = { 0, 2, 5, 10, 20, 30 },
    TntPower          = { 0, 3, 7, 14, 28, 50 },
    PitchforkCooldown = { 0, 1, 2, 4, 8, 14 },
    PitchforkHold     = { 0, 1 },
    Pitchfork         = { 0, 1, 2, 4, 10, 23 },
    DroneSpeed        = { 0, 0.5, 1.5, 3, 6, 12 },
    DroneGrab         = { 0, 0.5, 1.5, 3, 6, 13 },
    DroneCapacity     = { 0, 0.5, 1, 2.5, 5, 9 },
    VacuumPower       = { 0, 6, 16, 32, 68, 128 },
    VacuumCooling     = { 0, 5, 12.5, 28, 56, 112 },
    VacuumRuntime     = { 0, 5, 12.5, 28, 60, 120 },
}

-- tool identifiers published via HeldToolState:FireServer(tool, phase)
local TOOL_NAMES = {
    Hand = "hand", TNT = "tnt", Pitchfork = "pitchfork",
    Drone = "drone", Vacuum = "vacuum", Needle = "needle",
}

-- ==============================================================================
-- ESP (Highlight-based, cleaned up on toggle-off / unload)
-- ==============================================================================
local ESP_COLOR = Color3.fromRGB(120, 255, 120)
local RAINBOW_COLOR = Color3.fromRGB(255, 90, 255)
local NEEDLE_COLOR = Color3.fromRGB(255, 60, 60)
local GEM_COLOR = Color3.fromRGB(90, 190, 255)

local function clearEsp()
    for _, h in ipairs(HUB.highlights) do
        pcall(h.Destroy, h)
    end
    HUB.highlights = {}
end

local function espPart(part, color)
    if not part or not part.Parent then return nil end
    local h = Instance.new("Highlight")
    h.Name = "OxideNeedleEsp"
    h.FillColor = color or ESP_COLOR
    h.OutlineColor = Color3.new(1, 1, 1)
    h.FillTransparency = 0.45
    h.OutlineTransparency = 0
    h.Parent = part
    trackHighlight(h)
    return h
end

local function highlightList(list, color)
    if not S.espEnabled then return end
    for _, part in ipairs(list) do
        if part and part.Parent then
            local existing = part:FindFirstChild("OxideNeedleEsp")
            if not existing then espPart(part, color) end
        end
    end
end

-- Rainbow hay detection: the game marks ~1/400 strands as rainbow (10x value).
-- Strands are deterministic by index (isRainbow in Config), but indexes are not
-- exposed on the parts, so we detect by color signature instead.
local function isRainbowPart(part)
    if part:IsA("BasePart") and part.Transparency < 0.9 then
        local c = part.Color
        local mx = math.max(c.R, c.G, c.B)
        local mn = math.min(c.R, c.G, c.B)
        local sat = mx > 0 and (mx - mn) / mx or 0
        -- rainbow strands are vivid + multi-colored, hay is brownish/golden
        if sat > 0.55 and c.B > 0.4 then
            return true
        end
        -- pink/purple hues strongly suggest rainbow
        if c.R > 0.8 and c.B > 0.6 and c.G < 0.5 then
            return true
        end
    end
    return false
end

TrackLoop("esp", function()
    if not S.espEnabled then return end
    -- rainbow hay (cached, rescanned every 6s to limit cost)
    local now = os.clock()
    if S.espRainbow and now - (S._rainbowCache.t or 0) > 6 then
        S._rainbowCache.t = now
        S._rainbowCache.parts = {}
        local pile = Workspace:FindFirstChild("Hay Pile")
        local roots = { Workspace }
        if pile then roots = { pile } end
        for _, root in ipairs(roots) do
            local c = 0
            for _, part in ipairs(root:GetDescendants()) do
                if part:IsA("BasePart") and part.Name:lower():find("hay", 1, true) then
                    if isRainbowPart(part) then
                        table.insert(S._rainbowCache.parts, part)
                    end
                    c = c + 1
                    if c > 4000 then break end
                end
            end
        end
    end
    if S.espRainbow then
        highlightList(S._rainbowCache.parts or {}, RAINBOW_COLOR)
    end
    -- gems
    if S.espGems and now - (S._gemCache.t or 0) > 2 then
        S._gemCache.t = now
        S._gemCache.parts = {}
        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") and part.Name:lower():find("gem", 1, true)
                and not part:GetFullName():find("GemsClient", 1, true) then
                table.insert(S._gemCache.parts, part)
            end
        end
    end
    if S.espGems then
        highlightList(S._gemCache.parts or {}, GEM_COLOR)
    end
    -- needle
    if S.espNeedle then
        local st = GetHayState()
        if st and (st.needleRevealed or st.needleClaimed == false) then
            if now - (S._needleCache.t or 0) > 2 then
                S._needleCache.t = now
                S._needleCache.parts = {}
                for _, part in ipairs(Workspace:GetDescendants()) do
                    if part.Name:lower():find("needle", 1, true) and part:IsA("BasePart") then
                        table.insert(S._needleCache.parts, part)
                    end
                end
            end
            highlightList(S._needleCache.parts or {}, NEEDLE_COLOR)
        end
    end
end, 0.5)

-- ==============================================================================
-- MOVEMENT
-- ==============================================================================
local _activeTween = nil
local function TweenTo(position, speed)
    local hrp = GetHRP()
    if not hrp then return end
    if _activeTween then
        pcall(function() _activeTween:Cancel() end)
        _activeTween = nil
    end
    local dist = (hrp.Position - position).Magnitude
    if dist < 2 then return end
    local duration = math.clamp(dist / math.max(1, speed or S.walkSpeed), 0.1, 3)
    local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, info, { CFrame = CFrame.new(position, position + Vector3.new(0, 0, 1)) })
    tween:Play()
    _activeTween = tween
    tween.Completed:Connect(function()
        if _activeTween == tween then _activeTween = nil end
    end)
end

local function TeleportTo(position)
    local hrp = GetHRP()
    if not hrp then return end
    if _activeTween then
        pcall(function() _activeTween:Cancel() end)
        _activeTween = nil
    end
    hrp.CFrame = CFrame.new(position, position + Vector3.new(0, 0, 1))
end

-- ==============================================================================
-- CONFIG RESYNC (re-apply loaded flags to live state)
-- ==============================================================================
local function ResyncAll()
    local ok, err = pcall(function()
        S.autoDig       = Window:Get("dig_enabled", false)
        S.digMode       = Window:Get("dig_mode", "Spiral")
        S.digRadius     = Window:Get("dig_radius", 8)
        S.useGameInput  = Window:Get("dig_gameinput", true)
        S.autoSell      = Window:Get("sell_enabled", false)
        S.sellThreshold = Window:Get("sell_threshold", 20)
        S.autoGems      = Window:Get("gems_enabled", false)
        S.collectWith   = Window:Get("collect_with", "Hand")
        S.autoUpgrade   = Window:Get("upg_enabled", false)
        S.maxUpgradeCost = Window:Get("upg_maxcost", 100)
        S.espEnabled    = Window:Get("esp_enabled", false)
        S.espRainbow    = Window:Get("esp_rainbow", true)
        S.espNeedle     = Window:Get("esp_needle", true)
        S.espGems       = Window:Get("esp_gems", true)
        S.walkSpeed     = Window:Get("walkspeed", 16)
        S.jumpPower     = Window:Get("jumppower", 50)
        S.infiniteJump  = Window:Get("infjump", false)
        S.fly           = Window:Get("fly", false)
        S.noclip        = Window:Get("noclip", false)
        S.antiAFK       = Window:Get("antiafk", false)
        S.fullbright    = Window:Get("fullbright", false)
        if not S.espEnabled then clearEsp() end
    end)
    if not ok then warn("[Oxide NeedleHaystack] ResyncAll: " .. tostring(err)) end
end

-- ==============================================================================
-- TOOLS (equip via the game's HeldToolState publish remote)
-- ==============================================================================
local function EquipTool(toolName)
    local name = TOOL_NAMES[toolName]
    if not name then return end
    Fire("HeldToolState", name, "idle")
end

-- ==============================================================================
-- AUTO DIG
-- ==============================================================================
local function standAt(angle, radius)
    -- stand on the pile surface just inside the dig point so the game's reach
    -- validation (HOLD_DISTANCE 3.6 / INTERACT_DISTANCE 20) always passes
    local pos = surfacePoint(angle, radius)
    local hrp = GetHRP()
    if hrp and (hrp.Position - pos).Magnitude > 12 then
        TeleportTo(pos + Vector3.new(0, 2.5, 0))
    end
end

local function nextDigPoint()
    local angle = S._digAngle
    S._digAngle = S._digAngle + (S.digMode == "Random" and math.random() * 2 or 0.75)
    local radius
    if S.digMode == "Center" then
        radius = math.min(2 + math.random() * 2, PILE_RADIUS - 1)
    elseif S.digMode == "Ring" then
        radius = S.digRadius
    elseif S.digMode == "Random" then
        radius = 1 + math.random() * (PILE_RADIUS - 2)
    else -- Spiral
        radius = 2 + ((S._digAngle / (math.pi * 2)) % 1) * (PILE_RADIUS - 3)
    end
    return surfacePoint(angle, math.clamp(radius, 1, PILE_RADIUS - 1))
end

local function DigOnceDirect()
    -- direct PickHay fire at the surface point (works when the executor's input
    -- simulation is blocked; the server still validates reach + dig grid)
    local pos = nextDigPoint()
    standAt(S._digAngle, 4)
    Fire("PickHay", pos)
    return pos
end

local function DigOnceGameInput()
    -- Let the game's own client controller do the picking: aim the camera at a
    -- surface point and hold mouse1 there. This uses the exact validated path
    -- the real player uses, so it can never send a malformed pick.
    local pos = nextDigPoint()
    standAt(S._digAngle, 4)
    local cam = GetCamera()
    local hrp = GetHRP()
    if not cam or not hrp then return end
    cam.CFrame = CFrame.new(cam.CFrame.Position, pos)
    task.wait(0.08)
    local screen = cam:WorldToScreenPoint(pos)
    if screen.Z > 0 then
        VirtualInputManager:SendMouseButtonEvent(screen.X, screen.Y, 0, true, game, 1)
        task.wait(0.16)
        VirtualInputManager:SendMouseButtonEvent(screen.X, screen.Y, 0, false, game, 1)
    end
end

TrackLoop("dig", function()
    if not S.autoDig then return end
    local st = GetHayState()
    if st and st.needleClaimed then
        -- round finished / needle handed in; nothing left to dig
        return
    end
    EquipTool(S.collectWith)
    if S.useGameInput then
        DigOnceGameInput()
    else
        DigOnceDirect()
    end
    task.wait(S.digPause)
end, 0.05)

-- ==============================================================================
-- AUTO SELL
-- ==============================================================================
local function SellNow()
    local st = GetUpgradeState()
    if st and tonumber(st.held or 0) <= 0 then
        return 0
    end
    Fire("SellHay")
    return 1
end

TrackLoop("sell", function()
    if not S.autoSell then return end
    local now = os.clock()
    if now - S._lastSell < 1 then return end
    local st = GetUpgradeState()
    if not st then return end
    local held = tonumber(st.held or 0)
    if held < S.sellThreshold then return end
    local hrp = GetHRP()
    if hrp and (hrp.Position - SELL_POS).Magnitude > 14 then
        TweenTo(SELL_POS + Vector3.new(0, 0, 2), S.walkSpeed)
        return
    end
    SellNow()
    S._lastSell = now
end, 0.3)

-- ==============================================================================
-- AUTO COLLECT GEMS
-- ==============================================================================
local function fireCollectGem(part)
    if not part or not part.Parent then return end
    local r = Remote("CollectGem")
    if not r then return end
    pcall(function() r:FireServer(part) end)
end

track(function()
    local gemSpawned = Remote("GemSpawned")
    if not gemSpawned then return end
    gemSpawned.OnClientEvent:Connect(function(...)
        local a = { ... }
        local target = nil
        for _, v in ipairs(a) do
            if typeof(v) == "Instance" then target = v; break end
            if typeof(v) == "Vector3" and not target then
                target = { Position = v }
            end
        end
        if target then
            table.insert(S._gemCache.parts or {}, target)
            if S.autoGems then
                task.spawn(function()
                    if typeof(target) == "Instance" and target:IsA("BasePart") then
                        fireCollectGem(target)
                    end
                end)
            end
        end
    end)
end)

TrackLoop("gems", function()
    if not S.autoGems then return end
    local now = os.clock()
    if now - S._lastGems < 0.8 then return end
    S._lastGems = now
    local hrp = GetHRP()
    if not hrp then return end
    local best, bestDist
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Name:lower():find("gem", 1, true)
            and not part:GetFullName():find("GemsClient", 1, true) then
            local d = (part.Position - hrp.Position).Magnitude
            if not bestDist or d < bestDist then
                best, bestDist = part, d
            end
        end
    end
    if best and bestDist <= 25 then
        fireCollectGem(best)
    elseif best then
        TweenTo(best.Position, S.walkSpeed)
    end
end, 0.5)

-- ==============================================================================
-- AUTO UPGRADE
-- ==============================================================================
local function BuyUpgrade(track, level)
    Fire("BuyUpgrade", track, level)
end

TrackLoop("upgrade", function()
    if not S.autoUpgrade then return end
    local st = GetUpgradeState()
    if not st then return end
    local cash = tonumber(st.cash or 0)
    for track, enabled in pairs(S.upgradeTracks) do
        if enabled then
            local costs = TRACK_COSTS[track]
            if costs then
                local cur = tonumber(st.levels and st.levels[track] or 1)
                local nextLevel = cur + 1
                local cost = costs[nextLevel]
                if cost and cost <= cash and cost <= S.maxUpgradeCost then
                    BuyUpgrade(track, nextLevel)
                    cash = cash - cost
                    task.wait(0.35)
                    st = GetUpgradeState() or st
                    cash = tonumber(st.cash or cash)
                end
            end
        end
    end
end, 1)

local function BuyAllNow()
    task.spawn(function()
        local bought = 0
        for attempt = 1, 40 do
            local st = GetUpgradeState()
            if not st then break end
            local cash = tonumber(st.cash or 0)
            local any = false
            for track, enabled in pairs(S.upgradeTracks) do
                if enabled then
                    local costs = TRACK_COSTS[track]
                    if costs then
                        local cur = tonumber(st.levels and st.levels[track] or 1)
                        local nextLevel = cur + 1
                        local cost = costs[nextLevel]
                        if cost and cost <= cash and cost <= S.maxUpgradeCost then
                            BuyUpgrade(track, nextLevel)
                            cash = cash - cost
                            any = true
                            bought = bought + 1
                            task.wait(0.35)
                        end
                    end
                end
            end
            if not any then break end
            task.wait(0.5)
        end
        Notify("Upgrades", ("Bought %d upgrade level(s)"):format(bought), bought > 0 and "Success" or "Info")
    end)
end

-- ==============================================================================
-- PLAYER ENGINE
-- ==============================================================================
do
    local flyBodyVel, flyBodyGyro
    local flyOn = false

    local function StopFly()
        if flyOn and flyBodyVel then
            pcall(flyBodyVel.Destroy, flyBodyVel)
            pcall(flyBodyGyro.Destroy, flyBodyGyro)
        end
        flyBodyVel, flyBodyGyro = nil, nil
        flyOn = false
    end

    local function StartFly()
        local hrp = GetHRP()
        local h = GetHumanoid()
        if not hrp then return end
        StopFly()
        if h then
            pcall(function() h:ChangeState(Enum.HumanoidStateType.Flying) end)
        end
        flyBodyVel = Instance.new("BodyVelocity")
        flyBodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        flyBodyVel.Velocity = Vector3.zero
        flyBodyVel.Parent = hrp
        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        flyBodyGyro.P = 1
        flyBodyGyro.D = 1
        flyBodyGyro.Parent = hrp
        flyOn = true
    end

    TrackLoop("fly", function()
        if S.fly then
            local hrp = GetHRP()
            if not hrp then return end
            if not flyOn then StartFly() end
            local cam = GetCamera()
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
            if dir.Magnitude > 0 then
                flyBodyVel.Velocity = dir.Unit * S.walkSpeed * 3
            else
                flyBodyVel.Velocity = Vector3.zero
            end
        elseif flyOn then
            StopFly()
        end
    end)

    TrackLoop("movement", function()
        local h = GetHumanoid()
        if h then
            if h.WalkSpeed ~= S.walkSpeed then h.WalkSpeed = S.walkSpeed end
            if h.JumpPower ~= S.jumpPower then h.JumpPower = S.jumpPower end
        end
    end, 0.3)

    TrackLoop("infjump", function()
        if S.infiniteJump then
            local h = GetHumanoid()
            if h then
                pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
            end
        end
    end)

    TrackLoop("noclip", function()
        if not S.noclip then return end
        local c = GetChar()
        if not c then return end
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end, 0.2)

    TrackLoop("afk", function()
        if S.antiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end, 60)

    TrackLoop("bright", function()
        if S.fullbright then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
        end
    end, 2)

    HUB._StopFly = StopFly
end

-- ==============================================================================
-- UI
-- ==============================================================================
local AutoTab = Window:AddTab({ Name = "Auto", Subtitle = "Farm", Icon = "lightning" })

local DigSub = AutoTab:AddSubTab("Auto Dig")
DigSub:AddToggle({
    Name = "Enable Auto Dig",
    Default = false,
    Flag = "dig_enabled",
    Callback = safeCallback(function(v)
        S.autoDig = v
        notifyOn("Auto Dig", v)
    end),
})
DigSub:AddDropdown({
    Name = "Dig Target Mode",
    Options = { "Spiral", "Ring", "Center", "Random" },
    Default = "Spiral",
    Flag = "dig_mode",
    Callback = function(v) S.digMode = v end,
})
DigSub:AddSlider({
    Name = "Dig Radius (Ring mode)",
    Min = 3,
    Max = 16,
    Default = 8,
    Suffix = "studs",
    Flag = "dig_radius",
    Callback = function(v) S.digRadius = v end,
})
DigSub:AddSlider({
    Name = "Pick Speed",
    Min = 4,
    Max = 25,
    Default = 15,
    Suffix = "picks/s",
    Flag = "dig_pause",
    Callback = function(v) S.digPause = math.clamp(1 / v, 0.04, 0.25) end,
})
DigSub:AddToggle({
    Name = "Use Game Input (mouse hold)",
    Default = true,
    Flag = "dig_gameinput",
    Description = "Pick through the game's own input path (most reliable). Off = direct PickHay fire.",
    Callback = function(v) S.useGameInput = v end,
})
DigSub:AddButton({
    Name = "Teleport To Hay Pile",
    Callback = safeCallback(function()
        TeleportTo(surfacePoint(0, 4) + Vector3.new(0, 2, 0))
        Notify("Teleport", "Moved to the hay pile", "Success")
    end),
})

local SellSub = AutoTab:AddSubTab("Auto Sell")
SellSub:AddToggle({
    Name = "Enable Auto Sell",
    Default = false,
    Flag = "sell_enabled",
    Callback = safeCallback(function(v)
        S.autoSell = v
        notifyOn("Auto Sell", v)
    end),
})
SellSub:AddSlider({
    Name = "Sell When Holding",
    Min = 5,
    Max = 250,
    Default = 20,
    Suffix = "hay",
    Flag = "sell_threshold",
    Callback = function(v) S.sellThreshold = v end,
})
SellSub:AddButton({
    Name = "Sell Now",
    Callback = safeCallback(function()
        task.spawn(function()
            local hrp = GetHRP()
            if hrp and (hrp.Position - SELL_POS).Magnitude > 14 then
                TweenTo(SELL_POS + Vector3.new(0, 0, 2), S.walkSpeed)
                task.wait(1.2)
            end
            local n = SellNow()
            Notify("Sell", n > 0 and "Sold!" or "Nothing to sell", n > 0 and "Success" or "Info")
        end)
    end),
})
SellSub:AddButton({
    Name = "Teleport To Sell Cow",
    Callback = safeCallback(function()
        TeleportTo(SELL_POS + Vector3.new(0, 0, 2))
        Notify("Teleport", "Moved to the sell cow", "Success")
    end),
})

local GemSub = AutoTab:AddSubTab("Gems & Tools")
GemSub:AddToggle({
    Name = "Auto Collect Gems",
    Default = false,
    Flag = "gems_enabled",
    Callback = safeCallback(function(v)
        S.autoGems = v
        notifyOn("Auto Collect Gems", v)
    end),
})
GemSub:AddDropdown({
    Name = "Collect With",
    Options = { "Hand", "TNT", "Pitchfork", "Drone", "Vacuum" },
    Default = "Hand",
    Flag = "collect_with",
    Callback = function(v)
        S.collectWith = v
        EquipTool(v)
    end,
})

local UpgTab = Window:AddTab({ Name = "Upgrades", Subtitle = "Buy", Icon = "star" })

local UpgradeMain = UpgTab:AddSubTab("General")
UpgradeMain:AddToggle({
    Name = "Enable Auto Upgrade",
    Default = false,
    Flag = "upg_enabled",
    Callback = safeCallback(function(v)
        S.autoUpgrade = v
        notifyOn("Auto Upgrade", v)
    end),
})
UpgradeMain:AddSlider({
    Name = "Max Cost Per Level",
    Min = 1,
    Max = 130,
    Default = 100,
    Suffix = "coins",
    Flag = "upg_maxcost",
    Callback = function(v) S.maxUpgradeCost = v end,
})
UpgradeMain:AddButton({
    Name = "Buy All Enabled Now",
    Callback = safeCallback(BuyAllNow),
})

local trackGroups = {
    { Name = "Hand",      Tracks = { "Capacity", "HandHold", "Speed", "Grab" } },
    { Name = "TNT",       Tracks = { "TntLuck", "TntCooldown", "TntPower" } },
    { Name = "Pitchfork", Tracks = { "PitchforkCooldown", "PitchforkHold", "Pitchfork" } },
    { Name = "Drone",     Tracks = { "DroneSpeed", "DroneGrab", "DroneCapacity" } },
    { Name = "Vacuum",    Tracks = { "VacuumPower", "VacuumCooling", "VacuumRuntime" } },
}

local TRACK_DISPLAY = {
    Capacity = "Carry Capacity", HandHold = "Hold", Speed = "Speed", Grab = "Grasp",
    TntLuck = "Lucky Blast", TntCooldown = "TNT Cooldown", TntPower = "TNT Power",
    PitchforkCooldown = "Fork Cooldown", PitchforkHold = "Fork Hold", Pitchfork = "Fork Sweep",
    DroneSpeed = "Drone Speed", DroneGrab = "Drone Grasp", DroneCapacity = "Drone Capacity",
    VacuumPower = "Vacuum Power", VacuumCooling = "Vacuum Cooling", VacuumRuntime = "Vacuum Runtime",
}

local upgSubs = {}
for _, group in ipairs(trackGroups) do
    local sub = UpgTab:AddSubTab(group.Name)
    upgSubs[group.Name] = sub
    sub:AddToggle({
        Name = "Enable " .. group.Name .. " Track",
        Default = true,
        Flag = "upg_group_" .. string.lower(group.Name),
        Callback = function(v)
            for _, t in ipairs(group.Tracks) do
                S.upgradeTracks[t] = v
            end
        end,
    })
    for _, t in ipairs(group.Tracks) do
        local costs = TRACK_COSTS[t]
        sub:AddToggle({
            Name = TRACK_DISPLAY[t] .. " (" .. (costs and #costs or 1) .. " lvls)",
            Default = true,
            Flag = "upg_" .. t,
            Callback = function(v) S.upgradeTracks[t] = v end,
        })
    end
end
for _, group in ipairs(trackGroups) do
    for _, t in ipairs(group.Tracks) do
        S.upgradeTracks[t] = true
    end
end

local EspTab = Window:AddTab({ Name = "ESP", Subtitle = "See it all", Icon = "eye" })

local EspMain = EspTab:AddSubTab("ESP")
EspMain:AddToggle({
    Name = "Master Enable",
    Default = false,
    Flag = "esp_enabled",
    Callback = function(v)
        S.espEnabled = v
        if not v then clearEsp() end
    end,
})
EspMain:AddToggle({
    Name = "Rainbow Hay ESP",
    Default = true,
    Flag = "esp_rainbow",
    Description = "Highlights 10x-value rainbow strands",
    Callback = function(v) S.espRainbow = v end,
})
EspMain:AddToggle({
    Name = "Needle ESP",
    Default = true,
    Flag = "esp_needle",
    Description = "Highlights the needle when it is in the pile",
    Callback = function(v) S.espNeedle = v end,
})
EspMain:AddToggle({
    Name = "Gem ESP",
    Default = true,
    Flag = "esp_gems",
    Callback = function(v) S.espGems = v end,
})

local StatsSub = EspTab:AddSubTab("Stats")
local function addStat(label)
    local lbl = StatsSub:AddLabel({ Text = label })
    table.insert(S._stateLabels, lbl)
    return lbl
end
addStat("Cash: --  |  Holding: --")
addStat("Pile remaining: --  |  Needle: --")

TrackLoop("stats", function()
    local up = GetUpgradeState()
    local hay = GetHayState()
    if not up then return end
    local cash = tostring(up.cash or 0)
    local held = tostring(up.held or 0)
    local rem = hay and tostring(hay.remaining or "?") or "?"
    local needle = "?"
    if hay then
        if hay.needleClaimed then needle = "Claimed"
        elseif hay.needleRevealed then needle = "Revealed!"
        else needle = "Hidden" end
    end
    local ok1, ok2 = pcall(function()
        if S._stateLabels[1] then
            S._stateLabels[1]:Set("Cash: " .. cash .. "  |  Holding: " .. held)
        end
        if S._stateLabels[2] then
            S._stateLabels[2]:Set("Pile remaining: " .. rem .. "  |  Needle: " .. needle)
        end
    end)
    if not ok1 then S._stateLabels = {} end
end, 1)

local PlayerTab = Window:AddTab({ Name = "Player", Subtitle = "Movement", Icon = "user" })

local MoveSub = PlayerTab:AddSubTab("Movement")
MoveSub:AddSlider({
    Name = "WalkSpeed",
    Min = 8,
    Max = 250,
    Default = 16,
    Suffix = "",
    Flag = "walkspeed",
    Callback = function(v) S.walkSpeed = v end,
})
MoveSub:AddSlider({
    Name = "JumpPower",
    Min = 25,
    Max = 350,
    Default = 50,
    Suffix = "",
    Flag = "jumppower",
    Callback = function(v) S.jumpPower = v end,
})
MoveSub:AddToggle({
    Name = "Infinite Jump",
    Default = false,
    Flag = "infjump",
    Callback = function(v) S.infiniteJump = v end,
})
MoveSub:AddToggle({
    Name = "Smooth Fly",
    Default = false,
    Flag = "fly",
    Description = "Hold Space to fly up, Shift to fly down",
    Callback = function(v) S.fly = v end,
})
MoveSub:AddToggle({
    Name = "Noclip",
    Default = false,
    Flag = "noclip",
    Callback = function(v) S.noclip = v end,
})

local UtilSub = PlayerTab:AddSubTab("Utility")
UtilSub:AddToggle({
    Name = "Anti-AFK",
    Default = false,
    Flag = "antiafk",
    Callback = function(v) S.antiAFK = v end,
})
UtilSub:AddToggle({
    Name = "Fullbright",
    Default = false,
    Flag = "fullbright",
    Callback = function(v) S.fullbright = v end,
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
SettingsSub:AddKeybind({
    Name = "Toggle HUB",
    Default = "RightShift",
    Flag = "toggle_keybind",
    Callback = function()
        pcall(function() Window:Toggle() end)
    end,
})
SettingsSub:AddButton({
    Name = "Unload HUB",
    Callback = safeCallback(function()
        Notify("Oxide HUB", "Script unloaded", "Info")
        task.wait(0.3)
        pcall(function() Window:Destroy() end)
    end),
})

-- ==============================================================================
-- UNLOAD
-- ==============================================================================
function HUB.Unload()
    HUB.dead = true
    for id in pairs(HUB.loops) do HUB.loops[id] = nil end
    for _, c in ipairs(HUB.conns) do
        pcall(c.Disconnect, c)
    end
    HUB.conns = {}
    clearEsp()
    if HUB._StopFly then pcall(HUB._StopFly) end
    local sg = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("OxideNeedleHaystackUI")
    if sg then pcall(sg.Destroy, sg) end
    if HAS_CONFIG then
        pcall(function() Library.SaveConfig(CONFIG_NAME) end)
    end
end

-- ==============================================================================
-- END
-- ==============================================================================
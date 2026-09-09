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
    Name = "Oxide HUB | Search For The Needle",
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
local VirtualUser         = game:GetService("VirtualUser")

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
-- GAME MODULES (client-replicated -> exact server math)
-- ==============================================================================
local GameConfig, GameSurface
do
    local okC, cfg = pcall(require, RS:WaitForChild("NeedleHaystack"):WaitForChild("Config", 10))
    if okC and type(cfg) == "table" then GameConfig = cfg end
    local okS, surf = pcall(require, RS:FindFirstChild("NeedleHaystack") and RS.NeedleHaystack:FindFirstChild("Surface"))
    if okS and type(surf) == "table" then GameSurface = surf end
end

local PILE_CENTER  = GameConfig and GameConfig.PILE_CENTER or Vector3.new(-199.18434, 2.1, 30.241207)
local PILE_RADIUS  = GameConfig and GameConfig.PILE_RADIUS or 17
local RENDERED_HAY = GameConfig and GameConfig.RENDERED_HAY or 13000
local TOTAL_HAY    = GameConfig and GameConfig.TOTAL_HAY or 100000
local SELL_POS     = Vector3.new(-161.28688049316406, 6.126363754272461, 56.90555191040039)

local function GetNH()
    return RS:FindFirstChild("NeedleHaystack")
end
local function Remote(name)
    local nh = GetNH()
    return nh and nh:FindFirstChild(name) or nil
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

-- Exact position of a rendered hay strand (matches the server's placement).
-- Passing p97=true skips the dug-depth subtraction -> full surface position.
local function strandPosition(index)
    if GameSurface and GameSurface.strandCFrame then
        local ok, cf = pcall(function()
            return GameSurface.strandCFrame(index, RENDERED_HAY, 11, 0, 0, true, 0, false)
        end)
        if ok and typeof(cf) == "CFrame" then
            return cf.Position
        end
    end
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
    digSpeed        = 1,          -- 1 = base cooldown, 2 = as fast as the server allows
    rainbowMode     = "Off",      -- Off / Priority / Only
    autoSell        = false,
    sellThreshold   = 20,
    autoGems        = false,
    autoNeedle      = false,
    collectWith     = "Hand",
    -- Upgrades
    autoUpgrade     = false,
    maxUpgradeCost  = 100,
    upgradeTracks   = {},
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
    _lastNeedle     = 0,
    _lastPick       = 0,
    _rainbowList    = nil,        -- cached [index] = position
    _rainbowCacheT  = 0,
    _rainbowNext    = 1,
    _pickedHay      = {},         -- strand indices we already picked this run
    _gemCache       = {},
    _needleCache    = {},
    _stateLabels    = {},
    _needleTarget   = nil,        -- from NeedleTargetChanged hook
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

-- Speed upgrade level -> pick cooldown seconds (from Config.UPGRADE_TRACKS.Speed)
local PICK_COOLDOWNS = { 0.55, 0.5, 0.45, 0.4, 0.35, 0.3 }

local TOOL_NAMES = {
    Hand = "hand", TNT = "tnt", Pitchfork = "pitchfork",
    Drone = "drone", Vacuum = "vacuum", Needle = "needle",
}

-- ==============================================================================
-- RAINBOW STRAND INDEX (deterministic, mirrors Config.isRainbow)
-- ==============================================================================
local function isRainbowIndex(index)
    if GameConfig and type(GameConfig.isRainbow) == "function" then
        local ok, res = pcall(GameConfig.isRainbow, index)
        if ok then return res == true end
    end
    local v = math.sin(index * 7.31413 + 8242026 * 0.00037 + 1913.77) * 24634.6345
    return (v - math.floor(v)) < 0.0025
end

-- Build the full rainbow list once: { {index=..., pos=Vector3}, ... } sorted by angle
local function BuildRainbowList()
    local out = {}
    for i = 1, RENDERED_HAY do
        if isRainbowIndex(i) then
            local pos = strandPosition(i)
            if pos then
                table.insert(out, { index = i, pos = pos })
            end
        end
    end
    table.sort(out, function(a, b)
        return math.atan2(a.pos.X - PILE_CENTER.X, a.pos.Z - PILE_CENTER.Z)
            < math.atan2(b.pos.X - PILE_CENTER.X, b.pos.Z - PILE_CENTER.Z)
    end)
    return out
end

local function GetRainbowList()
    local now = os.clock()
    if not S._rainbowList or now - S._rainbowCacheT > 30 then
        S._rainbowCacheT = now
        S._rainbowList = BuildRainbowList()
        S._rainbowNext = 1
    end
    return S._rainbowList
end

-- ==============================================================================
-- ESP (Highlight-based)
-- ==============================================================================
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
    h.FillColor = color or RAINBOW_COLOR
    h.OutlineColor = Color3.new(1, 1, 1)
    h.FillTransparency = 0.45
    h.OutlineTransparency = 0
    h.Parent = part
    trackHighlight(h)
    return h
end

-- Highlight the rendered hay part sitting at a computed strand position.
local function espAtPosition(pos, color)
    if not pos then return end
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Name:lower():find("hay", 1, true) and not part:FindFirstChild("OxideNeedleEsp") then
            if (part.Position - pos).Magnitude < 1.2 then
                espPart(part, color)
                return
            end
        end
    end
end

TrackLoop("esp", function()
    if not S.espEnabled then return end
    local now = os.clock()
    if S.espRainbow then
        local list = GetRainbowList()
        local perFrame = math.min(6, #list)
        for k = 1, perFrame do
            local entry = list[(now * 17 + k * 7) % #list + 1]
            if entry then espAtPosition(entry.pos, RAINBOW_COLOR) end
        end
    end
    if S.espGems and now - (S._gemCache.t or 0) > 2 then
        S._gemCache.t = now
        S._gemCache.parts = {}
        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") and part.Name:lower():find("gem", 1, true)
                and not part:GetFullName():find("GemsClient", 1, true) then
                table.insert(S._gemCache.parts, part)
            end
        end
        for _, part in ipairs(S._gemCache.parts or {}) do
            if part.Parent and not part:FindFirstChild("OxideNeedleEsp") then
                espPart(part, GEM_COLOR)
            end
        end
    end
    if S.espNeedle then
        local st = GetHayState()
        if st and (st.needleRevealed or S._needleTarget) then
            local target = S._needleTarget
            if not target then
                if now - (S._needleCache.t or 0) > 2 then
                    S._needleCache.t = now
                    S._needleCache.parts = {}
                    for _, part in ipairs(Workspace:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name:lower():find("needle", 1, true) then
                            table.insert(S._needleCache.parts, part)
                        end
                    end
                end
                local parts = S._needleCache.parts or {}
                for _, part in ipairs(parts) do
                    if part.Parent and not part:FindFirstChild("OxideNeedleEsp") then
                        espPart(part, NEEDLE_COLOR)
                    end
                end
            else
                espAtPosition(target, NEEDLE_COLOR)
            end
        end
    end
end, 0.4)

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
-- TOOLS
-- ==============================================================================
local function EquipTool(toolName)
    local name = TOOL_NAMES[toolName]
    if not name then return end
    Fire("HeldToolState", name, "idle")
end

-- ==============================================================================
-- AUTO DIG (VERIFIED: PickHay(strandIndex, {}))
-- ==============================================================================
local function nextDigIndex()
    local hrp = GetHRP()
    local hrpPos = hrp and hrp.Position or PILE_CENTER

    -- Rainbow mode: always pick the next rainbow strand
    if S.rainbowMode ~= "Off" then
        local list = GetRainbowList()
        for tries = 1, #list do
            local entry = list[S._rainbowNext]
            S._rainbowNext = S._rainbowNext % #list + 1
            if entry and not S._pickedHay[entry.index] then
                -- move close to the rainbow strand so the pick always lands
                if (entry.pos - hrpPos).Magnitude > 10 then
                    TeleportTo(entry.pos + Vector3.new(0, 2, 0))
                end
                return entry.index
            end
        end
        if S.rainbowMode == "Only" then
            return nil -- all rainbows picked this pass; wait for re-scan
        end
    end

    -- normal dig: pick a strand near the character
    for tries = 1, 24 do
        local idx = math.random(1, RENDERED_HAY)
        if not S._pickedHay[idx] then
            local pos = strandPosition(idx)
            if pos and (pos - hrpPos).Magnitude < 14 then
                return idx
            end
        end
    end
    -- fall back to any strand we haven't picked
    for tries = 1, 40 do
        local idx = math.random(1, RENDERED_HAY)
        if not S._pickedHay[idx] then return idx end
    end
    return math.random(1, RENDERED_HAY)
end

TrackLoop("dig", function()
    if not S.autoDig then return end
    local st = GetHayState()
    if st and st.needleClaimed then
        return -- round finished
    end
    local now = os.clock()
    local up = GetUpgradeState()
    local speedLvl = up and tonumber(up.levels and up.levels.Speed or 1) or 1
    local cooldown = (PICK_COOLDOWNS[speedLvl] or 0.3) / S.digSpeed
    if now - S._lastPick < cooldown then return end

    EquipTool(S.collectWith)
    local idx = nextDigIndex()
    if not idx then return end
    S._pickedHay[idx] = true
    Fire("PickHay", idx, {})
    S._lastPick = now

    -- rotate the character around the pile when digging normally
    if S.rainbowMode == "Off" and S.digMode ~= "Random" then
        S._digAngle = S._digAngle + 0.12
        local radius = S.digMode == "Center" and 4
            or (S.digMode == "Ring" and S.digRadius or (8 + math.sin(S._digAngle) * 6))
        local pos = PILE_CENTER + Vector3.new(math.cos(S._digAngle) * radius, 2, math.sin(S._digAngle) * radius)
        local hrp = GetHRP()
        if hrp and (hrp.Position - pos).Magnitude > 16 then
            TeleportTo(pos)
        end
    end

    -- keep the picked set bounded (13000 entries is fine, but trim old rounds)
    local n = 0
    for _ in pairs(S._pickedHay) do
        n = n + 1
        if n > 8000 then break end
    end
    if n > 8000 then S._pickedHay = {} end
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
-- AUTO COLLECT GEMS (hook GemSpawned + workspace scan)
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
        local target
        for _, v in ipairs(a) do
            if typeof(v) == "Instance" then target = v; break end
            if typeof(v) == "Vector3" and not target then
                target = { Position = v }
            end
        end
        if target then
            table.insert(S._gemCache.parts or {}, target)
            if S.autoGems and typeof(target) == "Instance" and target:IsA("BasePart") then
                task.spawn(function()
                    fireCollectGem(target)
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
    if best then
        if bestDist <= 25 then
            fireCollectGem(best)
        else
            TeleportTo(best.Position)
        end
    end
end, 0.5)

-- ==============================================================================
-- AUTO NEEDLE (teleport to the needle + hand it in when revealed)
-- ==============================================================================
track(function()
    local ntc = Remote("NeedleTargetChanged")
    if not ntc then return end
    ntc.OnClientEvent:Connect(function(...)
        local a = { ... }
        for _, v in ipairs(a) do
            if typeof(v) == "Vector3" then
                S._needleTarget = v
            elseif typeof(v) == "Instance" and v:IsA("BasePart") then
                S._needleTarget = v.Position
            end
        end
    end)
end)

TrackLoop("needle", function()
    if not S.autoNeedle then return end
    local now = os.clock()
    if now - S._lastNeedle < 1.5 then return end
    S._lastNeedle = now
    local st = GetHayState()
    if not st or st.needleClaimed then return end
    local target = S._needleTarget
    if not target and st.needleRevealed then
        -- scan workspace for the needle part
        local found
        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") and part.Name:lower():find("needle", 1, true) then
                found = part
                break
            end
        end
        if found then target = found.Position end
    end
    if not target then return end
    local hrp = GetHRP()
    if not hrp then return end
    if (hrp.Position - target).Magnitude > 8 then
        TeleportTo(target + Vector3.new(0, 3, 0))
        return
    end
    -- in range: hand in the needle
    Fire("NeedleHandIn")
    Notify("Needle", "Needle found - handed it in!", "Success", 3)
    S._lastNeedle = now + 5
end, 0.6)

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
            flyBodyVel.Velocity = dir.Magnitude > 0 and (dir.Unit * S.walkSpeed * 3) or Vector3.zero
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
        if v then
            S._pickedHay = {}
            S._rainbowNext = 1
        end
    end),
})
DigSub:AddDropdown({
    Name = "Rainbow Farmer",
    Options = { "Off", "Priority", "Only" },
    Default = "Off",
    Flag = "dig_rainbow",
    Description = "Only = pick ONLY the deterministic 10x-value rainbow strands. Priority = rainbows first, then normal hay.",
    Callback = function(v)
        S.rainbowMode = v
        S._pickedHay = {}
        S._rainbowNext = 1
    end,
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
    Name = "Dig Speed",
    Min = 1,
    Max = 3,
    Default = 1,
    Suffix = "x",
    Description = "2x/3x ignores the base 0.55s pick cooldown (server may throttle)",
    Flag = "dig_speed",
    Callback = function(v) S.digSpeed = v end,
})
DigSub:AddButton({
    Name = "Teleport To Hay Pile",
    Callback = safeCallback(function()
        TeleportTo(PILE_CENTER + Vector3.new(4, 2, 4))
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
                TeleportTo(SELL_POS + Vector3.new(0, 0, 2))
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

local SpecialSub = AutoTab:AddSubTab("Gems & Needle")
SpecialSub:AddToggle({
    Name = "Auto Collect Gems",
    Default = false,
    Flag = "gems_enabled",
    Callback = safeCallback(function(v)
        S.autoGems = v
        notifyOn("Auto Collect Gems", v)
    end),
})
SpecialSub:AddToggle({
    Name = "Auto Needle (teleport + hand in)",
    Default = false,
    Flag = "needle_enabled",
    Description = "Teleports to the needle as soon as it is revealed and hands it in for the 5000 reward",
    Callback = safeCallback(function(v)
        S.autoNeedle = v
        notifyOn("Auto Needle", v)
    end),
})
SpecialSub:AddDropdown({
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
    Description = "Highlights the 10x-value rainbow strands (computed positions)",
    Callback = function(v) S.espRainbow = v end,
})
EspMain:AddToggle({
    Name = "Needle ESP",
    Default = true,
    Flag = "esp_needle",
    Callback = function(v) S.espNeedle = v end,
})
EspMain:AddToggle({
    Name = "Gem ESP",
    Default = true,
    Flag = "esp_gems",
    Callback = function(v) S.espGems = v end,
})

local StatsSub = EspTab:AddSubTab("Stats")
local function addStat(text)
    local lbl = StatsSub:AddLabel({ Text = text })
    table.insert(S._stateLabels, lbl)
    return lbl
end
addStat("Cash: --  |  Holding: --")
addStat("Pile remaining: --  |  Needle: --")
addStat("Rainbow strands: --")

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
    local rb = #GetRainbowList()
    local ok1, ok2 = pcall(function()
        if S._stateLabels[1] then S._stateLabels[1]:Set("Cash: " .. cash .. "  |  Holding: " .. held) end
        if S._stateLabels[2] then S._stateLabels[2]:Set("Pile remaining: " .. rem .. "  |  Needle: " .. needle) end
        if S._stateLabels[3] then S._stateLabels[3]:Set("Rainbow strands: " .. rb .. " (10x value)") end
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
-- CONFIG RESYNC (re-apply loaded flags to live state)
-- ==============================================================================
local function ResyncAll()
    local ok, err = pcall(function()
        S.autoDig        = Window:Get("dig_enabled", false)
        S.rainbowMode    = Window:Get("dig_rainbow", "Off")
        S.digMode        = Window:Get("dig_mode", "Spiral")
        S.digRadius      = Window:Get("dig_radius", 8)
        S.digSpeed       = Window:Get("dig_speed", 1)
        S.autoSell       = Window:Get("sell_enabled", false)
        S.sellThreshold  = Window:Get("sell_threshold", 20)
        S.autoGems       = Window:Get("gems_enabled", false)
        S.autoNeedle     = Window:Get("needle_enabled", false)
        S.collectWith    = Window:Get("collect_with", "Hand")
        S.autoUpgrade    = Window:Get("upg_enabled", false)
        S.maxUpgradeCost = Window:Get("upg_maxcost", 100)
        S.espEnabled     = Window:Get("esp_enabled", false)
        S.espRainbow     = Window:Get("esp_rainbow", true)
        S.espNeedle      = Window:Get("esp_needle", true)
        S.espGems        = Window:Get("esp_gems", true)
        S.walkSpeed      = Window:Get("walkspeed", 16)
        S.jumpPower      = Window:Get("jumppower", 50)
        S.infiniteJump   = Window:Get("infjump", false)
        S.fly            = Window:Get("fly", false)
        S.noclip         = Window:Get("noclip", false)
        S.antiAFK        = Window:Get("antiafk", false)
        S.fullbright     = Window:Get("fullbright", false)
        if not S.espEnabled then clearEsp() end
    end)
    if not ok then warn("[Oxide NeedleHaystack] ResyncAll: " .. tostring(err)) end
end

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
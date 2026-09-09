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
local hasHooks   = type(hookfunction) == "function"

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
    fov = 180,
    showFOV = true,
    teamCheck = true,
    wallCheck = false,
    hitPart = "Head",
    hitChance = 100,
    useMouseCenter = false,
    fovColor = Color3.fromRGB(255, 255, 255),
    fovThickness = 1.5,
    fovFilled = false,
    fovRainbow = false,
    targetLine = false,
    targetLineColor = Color3.fromRGB(120, 200, 255),
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
    local enabled = aim.enabled and hasHooks
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
local function IsEnemy(plr)
    if plr == LocalPlayer then return false end
    local c = plr.Character
    if not c then return false end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if aim.teamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then return false end
    return true
end

local function PickHitPart(char)
    local want = aim.hitPart
    if want == "Random" then
        want = (math.random() > 0.5) and "Head" or "HumanoidRootPart"
    end
    local part = char:FindFirstChild(want) or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if part and part:IsA("BasePart") then return part end
    return nil
end

local function IsVisible(part)
    if not aim.wallCheck then return true end
    local camPos = Camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, part.Parent, Camera }
    local dir = part.Position - camPos
    local res = Workspace:Raycast(camPos, dir, params)
    if res and res.Instance and not res.Instance:IsDescendantOf(part.Parent) then return false end
    return true
end

local function GetTarget()
    if not aim.enabled or not hasHooks then return nil end
    if math.random(1, 100) > aim.hitChance then return nil end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local ref = aim.useMouseCenter and UserInputService:GetMouseLocation() or center
    local bestPart, bestDist = nil, aim.fov
    for _, ent in ipairs(CollectionService:GetTagged("Entity")) do
        if ent:IsA("Model") and ent ~= LocalPlayer.Character then
            local plr = Players:GetPlayerFromCharacter(ent)
            if plr and IsEnemy(plr) then
                local part = PickHitPart(ent)
                if part and IsVisible(part) then
                    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - ref).Magnitude
                        if d < bestDist then bestDist, bestPart = d, part end
                    end
                end
            end
        end
    end
    return bestPart
end

-- ── Cam-data spoof payload (same structure the game expects) ─────────────
local function MakeCamData(origin, part)
    local cf = part.CFrame
    local d = {}
    d[utf8.char(1)] = {
        [utf8.char(0)] = U and U:EncodeCFrame(CFrame.lookAt(origin, part.Position)) or CFrame.lookAt(origin, part.Position),
        [utf8.char(1)] = U and U:EncodeCFrame(cf) or cf,
        [utf8.char(2)] = part,
        [utf8.char(3)] = U and U:EncodeCFrame(cf:ToObjectSpace(CFrame.new(part.Position))) or cf:ToObjectSpace(CFrame.new(part.Position)),
    }
    return d
end

-- ── Hooks (restored on unload) ────────────────────────────────────────────
local hooksInstalled = false
local originalRaycastHook, originalFireServer, originalIsFullyAiming

local function InstallHooks()
    if hooksInstalled or not hasHooks then return end
    -- 1. Redirect the raycast the server uses to validate hits
    if GU and type(GU.GetEntitiesFromRaycast) == "function" then
        originalRaycastHook = GU.GetEntitiesFromRaycast
        GU.GetEntitiesFromRaycast = function(self, envID, params, origin, dir, maxDist, ...)
            local t = GetTarget()
            if t then
                local dist = (t.Position - origin).Magnitude
                dir = (t.Position - origin).Unit
                if dist > maxDist then maxDist = dist + 5 end
            end
            return originalRaycastHook(self, envID, params, origin, dir, maxDist, ...)
        end
    end
    -- 2. Spoof cam data on the UseItem remote so shots count as on-target
    if UseItem and type(UseItem.FireServer) == "function" then
        originalFireServer = UseItem.FireServer
        local fire = originalFireServer
        local wrap = newcclosure or function(fn) return fn end
        UseItem.FireServer = wrap(function(self, objID, enumVal, camdata, extra)
            if aim.enabled and enumVal == enumStartShooting then
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local t = GetTarget()
                if root and t then camdata = MakeCamData(root.Position, t) end
            end
            return fire(self, objID, enumVal, camdata, extra)
        end)
    end
    -- 3. Always "fully aiming" while the hub is up
    if GunMod and type(GunMod.IsFullyAiming) == "function" then
        originalIsFullyAiming = GunMod.IsFullyAiming
        GunMod.IsFullyAiming = function() return true end
    end
    hooksInstalled = true
end

local function UninstallHooks()
    if not hooksInstalled then return end
    if GU and originalRaycastHook then
        pcall(function() GU.GetEntitiesFromRaycast = originalRaycastHook end)
        originalRaycastHook = nil
    end
    if UseItem and originalFireServer then
        pcall(function() UseItem.FireServer = originalFireServer end)
        originalFireServer = nil
    end
    if GunMod and originalIsFullyAiming then
        pcall(function() GunMod.IsFullyAiming = originalIsFullyAiming end)
        originalIsFullyAiming = nil
    end
    hooksInstalled = false
end

-- ── Aim UI ────────────────────────────────────────────────────────────────
local SilentSub = AimTab:AddSubTab("Silent Aim")

SilentSub:AddSection("Silent Aim")
SilentSub:AddToggle({
    Name = "Silent Aim", Default = false, Flag = "rv_silent",
    Description = "Redirects shots to nearest enemy in FOV (raycast + camdata hooks)",
    Callback = function(v)
        aim.enabled = v
        if v then
            InstallHooks()
            if not hasHooks then
                Notify("Aim", "Executor has no hookfunction — silent aim unavailable", "Error", 3)
            end
        end
        Notify("Aim", v and "Silent Aim ON" or "Silent Aim OFF", v and "Success" or "Error")
    end,
})
SilentSub:AddSlider({
    Name = "FOV Radius", Min = 10, Max = 600, Default = 180, Suffix = "px", Flag = "rv_fov",
    Callback = function(v) aim.fov = v end,
})
SilentSub:AddToggle({
    Name = "Show FOV", Default = true, Flag = "rv_showfov",
    Callback = function(v) aim.showFOV = v end,
})
SilentSub:AddToggle({
    Name = "Team Check", Default = true, Flag = "rv_teamcheck",
    Description = "Skips players on your team (auto-off in FFA)",
    Callback = function(v) aim.teamCheck = v end,
})
SilentSub:AddToggle({
    Name = "Wall Check", Default = false, Flag = "rv_wallcheck",
    Description = "Only targets enemies you can actually see",
    Callback = function(v) aim.wallCheck = v end,
})
SilentSub:AddSlider({
    Name = "Hit Chance", Min = 0, Max = 100, Default = 100, Suffix = "%", Flag = "rv_hitchance",
    Callback = function(v) aim.hitChance = v end,
})
SilentSub:AddToggle({
    Name = "Aim at Mouse", Default = false, Flag = "rv_mousecenter",
    Description = "Measure FOV from cursor instead of screen center",
    Callback = function(v) aim.useMouseCenter = v end,
})
local applyHitPart = function(v) aim.hitPart = v end
local hitPartDropdown = SilentSub:AddDropdown({
    Name = "Hit Part", Options = { "Head", "HumanoidRootPart", "UpperTorso", "Random" },
    Default = "Head", MaxVisible = 4, Flag = "rv_hitpart", Callback = applyHitPart,
})
registerResync(hitPartDropdown, applyHitPart)

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
    Description = "Draws a line from your crosshair to the locked target",
    Callback = function(v) aim.targetLine = v end,
})
TargetSub:AddColorPicker({
    Name = "Line Color", Default = aim.targetLineColor, Flag = "rv_tlcolor",
    Callback = function(c) aim.targetLineColor = c end,
})
local targetStatus = TargetSub:AddLabel({ Text = "Target: none" })
track(RunService.RenderStepped:Connect(function()
    if HUB.dead then return end
    local t = GetTarget()
    if targetLine and hasDrawing then
        targetLine.Visible = aim.targetLine and aim.enabled and t ~= nil
        if targetLine.Visible then
            targetLine.Color = aim.targetLineColor
            local sp, on = Camera:WorldToViewportPoint(t.Position)
            if on and sp.Z > 0 then
                targetLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                targetLine.To = Vector2.new(sp.X, sp.Y)
            else
                targetLine.Visible = false
            end
        end
    end
    if targetStatus then
        local name = t and (t.Parent and t.Parent.Name or "?") or "none"
        if t then
            local plr = Players:GetPlayerFromCharacter(t.Parent)
            name = plr and plr.DisplayName or t.Parent.Name
        end
        targetStatus:Set("Target: " .. name)
    end
end))

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
EspSub:AddSlider({ Name = "Max Distance", Min = 0, Max = 5000, Default = 1000, Suffix = "m", Flag = "rv_espmaxdist", Description = "0 = unlimited", Callback = function(v) esp.maxDistance = v end })
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
        Description = "Removes the FPS cap (infinite)",
        Callback = function(v)
            fpsUnlocked = v
            pcall(setFpsCap, v and 0 or fpsCap)
            Notify("FPS", v and "Unlocked (unlimited)" or ("Capped at " .. fpsCap), v and "Success" or "Info")
        end,
    })
    SettingsSub:AddSlider({
        Name = "FPS Cap", Min = 30, Max = 1000, Default = 240, Suffix = "", Flag = "rv_fps_cap",
        Description = "Used when FPS is not unlocked",
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
    wsEnabled = false; jpEnabled = false; infJump = false
    flyEnabled = false; noclipEnabled = false; fullbright = false
    UninstallHooks()
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
if not hasHooks then
    Notify("RIVALS", "hookfunction not available — silent aim disabled", "Error", 3)
elseif not (U and GU and EL and GunMod and UseItem and enumStartShooting) then
    Notify("RIVALS", "Some game modules changed — silent aim may be limited", "Error", 3)
else
    Notify("RIVALS", "Oxide HUB loaded — silent aim ready", "Success", 3)
end
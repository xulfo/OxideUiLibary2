-- RE-EXECUTION GUARD + RESOURCE TRACKING
-- Cleans up a previous run (window, drawings, highlights, connections) so the
-- hub can be re-executed without stacking render loops or duplicate ESP.
-- ══════════════════════════════════════════════════════════════════════════════
do
    local prev = _G.OxideUniversal
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, drawings = {}, highlights = {}, dead = false }
_G.OxideUniversal = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end
local function trackDrawing(d) if d then table.insert(HUB.drawings, d) end; return d end

local Window = Library:CreateWindow({
    Name = "Oxide HUB | Universal",
    LoadingAnimation = true,
    LoadingText = "Oxide",
    LoadingDuration = 2.5,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- SERVICES / LOCALS
-- ══════════════════════════════════════════════════════════════════════════════
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local Workspace          = game:GetService("Workspace")
local Lighting           = game:GetService("Lighting")
local TeleportService    = game:GetService("TeleportService")
local VirtualUser        = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG / FLAG PERSISTENCE (Oxide UI v2.3+ flag system; feature-guarded)
-- ══════════════════════════════════════════════════════════════════════════════
local HAS_CONFIG  = type(Library.SaveConfig) == "function"
    and type(Library.LoadConfig) == "function"
    and type(Library.ListConfigs) == "function"
local CONFIG_NAME = "universal"

-- Dropdowns apply through Set, which does NOT re-fire the element callback,
-- so we re-sync script variables after a config load (same pattern as GAG2).
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
-- CHARACTER HELPERS (re-resolved on respawn)
-- ══════════════════════════════════════════════════════════════════════════════
local function GetCharacter() return LocalPlayer.Character end
local function GetHumanoid()
    local c = GetCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function GetHRP()
    local c = GetCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetRootCFrame()
    local hrp = GetHRP()
    return hrp and hrp.CFrame
end

local function Notify(title, content, kind, dur)
    Window:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = dur or 2.5 })
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PLAYER TAB
-- ══════════════════════════════════════════════════════════════════════════════
local PlayerTab = Window:AddTab({ Name = "Player", Subtitle = "Movement & character", Icon = "player" })

-- ── MOVEMENT ──────────────────────────────────────────────────────────────────
local MoveSub = PlayerTab:AddSubTab("Movement")

local wsEnabled, wsValue   = false, 16
local jpEnabled, jpValue   = false, 50
local infJump              = false
local gravityEnabled, gravityValue = false, 196.2
local defaultGravity = Workspace.Gravity

MoveSub:AddSection("Speed & Jump")
MoveSub:AddToggle({
    Name = "WalkSpeed", Default = false, Flag = "ws_enabled",
    Callback = function(v)
        wsEnabled = v
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = v and wsValue or 16 end
    end,
})
MoveSub:AddSlider({
    Name = "WalkSpeed Value", Min = 16, Max = 500, Default = 16, Suffix = "", Flag = "ws_value",
    Callback = function(v)
        wsValue = v
        if wsEnabled then local hum = GetHumanoid(); if hum then hum.WalkSpeed = v end end
    end,
})
MoveSub:AddToggle({
    Name = "JumpPower", Default = false, Flag = "jp_enabled",
    Callback = function(v)
        jpEnabled = v
        local hum = GetHumanoid()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = v and jpValue or 50
        end
    end,
})
MoveSub:AddSlider({
    Name = "JumpPower Value", Min = 50, Max = 500, Default = 50, Suffix = "", Flag = "jp_value",
    Callback = function(v)
        jpValue = v
        if jpEnabled then local hum = GetHumanoid(); if hum then hum.UseJumpPower = true; hum.JumpPower = v end end
    end,
})
MoveSub:AddToggle({
    Name = "Infinite Jump", Default = false, Flag = "inf_jump",
    Callback = function(v) infJump = v end,
})

MoveSub:AddSection("Gravity")
MoveSub:AddToggle({
    Name = "Custom Gravity", Default = false, Flag = "grav_enabled",
    Callback = function(v)
        gravityEnabled = v
        Workspace.Gravity = v and gravityValue or defaultGravity
    end,
})
MoveSub:AddSlider({
    Name = "Gravity", Min = 0, Max = 400, Default = 196, Suffix = "", Flag = "grav_value",
    Callback = function(v)
        gravityValue = v
        if gravityEnabled then Workspace.Gravity = v end
    end,
})

-- Re-apply movement stats whenever the character respawns
track(LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    task.wait(0.2)
    if HUB.dead then return end
    if wsEnabled then hum.WalkSpeed = wsValue end
    if jpEnabled then hum.UseJumpPower = true; hum.JumpPower = jpValue end
end))

track(UserInputService.JumpRequest:Connect(function()
    if HUB.dead then return end
    if infJump then
        local hum = GetHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

-- ── FLY / NOCLIP ────────────────────────────────────────────────────────────────
local FlySub = PlayerTab:AddSubTab("Fly & Noclip")

local flying, flySpeed = false, 50
local noclip = false
local noclipParts = {}  -- [BasePart] = true (parts we disabled collision on, restored on toggle-off)
local flyConn, noclipConn

local function startFly()
    local hum = GetHumanoid()
    local hrp = GetHRP()
    if not hum or not hrp then return end
    hum.PlatformStand = true
    if flyConn then flyConn:Disconnect() end
    flyConn = RunService.RenderStepped:Connect(function()
        if HUB.dead or not flying then return end
        local h = GetHumanoid(); local root = GetHRP()
        if not h or not root then return end
        h.PlatformStand = true
        local dir = Vector3.zero
        local cf = Camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit * flySpeed else dir = Vector3.zero end
        root.AssemblyLinearVelocity = dir
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    local hum = GetHumanoid()
    if hum then hum.PlatformStand = false end
    local root = GetHRP()
    if root then root.AssemblyLinearVelocity = Vector3.zero end  -- kill residual momentum
end

FlySub:AddToggle({
    Name = "Fly", Default = false, Flag = "fly_enabled",
    Callback = function(v)
        flying = v
        if v then startFly() else stopFly() end
        Notify("Fly", v and "Enabled (W/A/S/D, Space, Shift)" or "Disabled", v and "Success" or "Error")
    end,
})
FlySub:AddSlider({
    Name = "Fly Speed", Min = 10, Max = 500, Default = 50, Suffix = "", Flag = "fly_speed",
    Callback = function(v) flySpeed = v end,
})

local function startNoclip()
    if noclipConn then noclipConn:Disconnect() end
    noclipConn = RunService.Stepped:Connect(function()
        if HUB.dead or not noclip then return end
        local char = GetCharacter()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                noclipParts[part] = true   -- remember it was collidable so we can restore it
                part.CanCollide = false
            end
        end
    end)
end

local function stopNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    for part in pairs(noclipParts) do
        if part and part.Parent then pcall(function() part.CanCollide = true end) end
    end
    table.clear(noclipParts)
end

FlySub:AddToggle({
    Name = "Noclip", Default = false, Flag = "noclip_enabled",
    Callback = function(v)
        noclip = v
        if v then startNoclip() else stopNoclip() end
        Notify("Noclip", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end,
})

-- ── CHARACTER ─────────────────────────────────────────────────────────────────
local CharSub = PlayerTab:AddSubTab("Character")

CharSub:AddButton({
    Name = "Respawn", Primary = true,
    Callback = function()
        local hum = GetHumanoid()
        if hum then hum.Health = 0 end
        Notify("Character", "Respawning...", "Info")
    end,
})
CharSub:AddButton({
    Name = "Reset Stats",
    Callback = function()
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = 16; hum.JumpPower = 50; hum.UseJumpPower = true end
        Workspace.Gravity = defaultGravity
        Notify("Character", "Stats reset to default", "Success")
    end,
})

local antiAFK = true
CharSub:AddToggle({
    Name = "Anti-AFK", Default = true, Flag = "anti_afk",
    Callback = function(v) antiAFK = v end,
})

if not _G.OxideUniversalAntiAFK then
    _G.OxideUniversalAntiAFK = true
    LocalPlayer.Idled:Connect(function()
        if antiAFK then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
            end)
        end
    end)
end

-- ── AVATAR (hip height) ─────────────────────────────────────────────────────────
local AvatarSub = PlayerTab:AddSubTab("Avatar")

local hipEnabled, hipValue = false, 2

AvatarSub:AddSection("Hip Height")
AvatarSub:AddToggle({
    Name = "Custom Hip Height", Default = false, Flag = "hip_enabled",
    Description = "How high the character floats",
    Callback = function(v)
        hipEnabled = v
        local hum = GetHumanoid()
        if hum then hum.HipHeight = v and hipValue or 2 end
    end,
})
AvatarSub:AddSlider({
    Name = "Hip Height", Min = 0, Max = 20, Default = 2, Suffix = "", Flag = "hip_value",
    Callback = function(v) hipValue = v; if hipEnabled then local h = GetHumanoid(); if h then h.HipHeight = v end end end,
})

-- Re-apply hip height on respawn
track(LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid", 10)
    task.wait(0.4)
    if HUB.dead then return end
    if hipEnabled then local h = GetHumanoid(); if h then h.HipHeight = hipValue end end
end))

-- ══════════════════════════════════════════════════════════════════════════════
-- TELEPORT TAB
-- ══════════════════════════════════════════════════════════════════════════════
local TpTab = Window:AddTab({ Name = "Teleport", Subtitle = "Players & waypoints", Icon = "teleport" })

-- ── PLAYERS ───────────────────────────────────────────────────────────────────
local PlayerTpSub = TpTab:AddSubTab("Players")
local selectedPlayer = nil

local function GetPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    table.sort(names)
    if #names == 0 then names = { "(no other players)" } end
    return names
end

local function ResolvePlayer(name)
    if not name then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name then return p end
    end
    return nil
end

local function applyPlayerSelect(v) selectedPlayer = v end
local playerDropdown = PlayerTpSub:AddDropdown({
    Name = "Player", Options = GetPlayerNames(), Default = nil,
    MaxVisible = 6, Searchable = true, Flag = "tp_player",
    Callback = applyPlayerSelect,
})
registerResync(playerDropdown, applyPlayerSelect)

PlayerTpSub:AddButton({
    Name = "Refresh Players",
    Callback = function()
        playerDropdown:SetOptions(GetPlayerNames())
        Notify("Teleport", "Player list refreshed", "Info")
    end,
})
PlayerTpSub:AddButton({
    Name = "Teleport To Player", Primary = true,
    Callback = function()
        local target = ResolvePlayer(selectedPlayer)
        local myHRP = GetHRP()
        local tHRP = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if myHRP and tHRP then
            myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3)
            Notify("Teleport", "Teleported to " .. target.Name, "Success")
        else
            Notify("Teleport", "Target unavailable", "Error")
        end
    end,
})

-- Continuous follow (re-teleports near the target until disabled)
local following = false
PlayerTpSub:AddToggle({
    Name = "Follow Player", Default = false, Flag = "tp_follow",
    Callback = function(v) following = v end,
})
task.spawn(function()
    while true do
        if HUB.dead then break end
        if following then
            local target = ResolvePlayer(selectedPlayer)
            local myHRP = GetHRP()
            local tHRP = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if myHRP and tHRP then
                myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 4)
            end
        end
        task.wait(0.4)
    end
end)

-- ── WAYPOINTS ───────────────────────────────────────────────────────────────────
local WaypointSub = TpTab:AddSubTab("Waypoints")
local waypoints = {}          -- [name] = CFrame
local pendingName = "Spot 1"
local selectedWaypoint = nil

local function WaypointNames()
    local names = {}
    for name in pairs(waypoints) do table.insert(names, name) end
    table.sort(names)
    if #names == 0 then names = { "(none)" } end
    return names
end

WaypointSub:AddInput({
    Name = "Waypoint Name", Placeholder = "Spot 1", Default = "Spot 1", Flag = "wp_name",
    Callback = function(text) pendingName = (text ~= "" and text) or "Spot 1" end,
})

local applyWpSelect = function(v) selectedWaypoint = v end
local waypointDropdown

WaypointSub:AddButton({
    Name = "Save Current Position", Primary = true,
    Callback = function()
        local cf = GetRootCFrame()
        if not cf then Notify("Waypoints", "No character", "Error"); return end
        waypoints[pendingName] = cf
        if waypointDropdown then waypointDropdown:SetOptions(WaypointNames()) end
        Notify("Waypoints", "Saved '" .. pendingName .. "'", "Success")
    end,
})

waypointDropdown = WaypointSub:AddDropdown({
    Name = "Saved Waypoints", Options = WaypointNames(), Default = nil,
    MaxVisible = 6, Searchable = true, Flag = "wp_selected",
    Callback = applyWpSelect,
})
registerResync(waypointDropdown, applyWpSelect)

WaypointSub:AddButton({
    Name = "Teleport To Waypoint",
    Callback = function()
        local cf = selectedWaypoint and waypoints[selectedWaypoint]
        local hrp = GetHRP()
        if cf and hrp then
            hrp.CFrame = cf
            Notify("Waypoints", "Teleported to '" .. selectedWaypoint .. "'", "Success")
        else
            Notify("Waypoints", "Waypoint unavailable", "Error")
        end
    end,
})
WaypointSub:AddButton({
    Name = "Delete Waypoint",
    Callback = function()
        if selectedWaypoint and waypoints[selectedWaypoint] then
            local removed = selectedWaypoint
            waypoints[selectedWaypoint] = nil
            waypointDropdown:SetOptions(WaypointNames())
            Notify("Waypoints", "Deleted '" .. removed .. "'", "Info")
        end
    end,
})

-- ── MISC TELEPORT ───────────────────────────────────────────────────────────────
local TpMiscSub = TpTab:AddSubTab("Misc")
local clickTp = false

TpMiscSub:AddToggle({
    Name = "Click Teleport", Default = false, Flag = "tp_click",
    Description = "Hold the keybind and click to teleport there",
    Callback = function(v)
        clickTp = v
        Notify("Click TP", v and "Enabled - press key to teleport to cursor" or "Disabled", v and "Success" or "Error")
    end,
})
TpMiscSub:AddKeybind({
    Name = "Click TP Key", Default = Enum.KeyCode.T, Flag = "tp_click_key",
    OnPress = function()
        if not clickTp then return end
        local hrp = GetHRP()
        if not hrp then return end
        local mouseLoc = UserInputService:GetMouseLocation()
        local ray = Camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { GetCharacter() }
        local result = Workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
        if result then
            hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
        end
    end,
})
TpMiscSub:AddButton({
    Name = "Teleport To Spawn",
    Callback = function()
        local hrp = GetHRP()
        local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
        if hrp and spawn then
            hrp.CFrame = spawn.CFrame * CFrame.new(0, 3, 0)
            Notify("Teleport", "Teleported to spawn", "Success")
        else
            Notify("Teleport", "No spawn found", "Error")
        end
    end,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- VISUALS TAB (ESP + world)
-- ══════════════════════════════════════════════════════════════════════════════
local VisualsTab = Window:AddTab({ Name = "Visuals", Subtitle = "ESP & lighting", Icon = "eye" })

-- ── ESP ─────────────────────────────────────────────────────────────────────
local EspSub = VisualsTab:AddSubTab("ESP")

local hasDrawing = (typeof(Drawing) == "table") or (Drawing ~= nil and pcall(function() return Drawing.new end))

local esp = {
    enabled = true, players = true, npcs = false,
    -- chams
    chams = false, chamsFillT = 0.55, chamsOutlineT = 0,
    -- 2D
    box = false, boxStyle = "Corner", boxFill = false, boxFillT = 0.8, boxThickness = 1,
    name = false, distance = false, health = false, healthText = false, healthPercent = false,
    tool = false, tracer = false, tracerOrigin = "Bottom",
    skeleton = false, hat = false, arrow = false, look = false,
    halo = false, headCircle = false, ring = false,
    -- behavior
    teamCheck = false, friendCheck = false, visibleCheck = false, rainbow = false, smooth = true,
    distanceFade = false, chamsDepth = "AlwaysOnTop",
    maxDistance = 1000, textSize = 14, font = 2,
    color        = Color3.fromRGB(30, 90, 220),
    visibleColor = Color3.fromRGB(95, 220, 120),
    hiddenColor  = Color3.fromRGB(235, 75, 75),
    friendColor  = Color3.fromRGB(95, 150, 255),
    npcColor     = Color3.fromRGB(235, 200, 70),
}
local espObjects = {}  -- [player] = obj
local npcObjects = {}  -- [model]  = obj
local FONT_MAP = { UI = 0, System = 1, Plain = 2, Monospace = 3 }

local function getEspParent()
    local ok, parent = pcall(function() return (gethui and gethui()) or game:GetService("CoreGui") end)
    if ok and parent then return parent end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function newDrawing(class, props)
    if not hasDrawing then return nil end
    local ok, d = pcall(function() return Drawing.new(class) end)
    if not ok or not d then return nil end
    for k, v in pairs(props or {}) do pcall(function() d[k] = v end) end
    return trackDrawing(d)
end

-- Rig joint connection tables for skeleton ESP
local R15_BONES = {
    {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
}
local R6_BONES = {
    {"Head","Torso"}, {"Torso","Left Arm"}, {"Torso","Right Arm"},
    {"Torso","Left Leg"}, {"Torso","Right Leg"},
}
local MAX_BONES = #R15_BONES
local RING_SEGMENTS = 16
local DRAW_KEYS = { "boxFill","boxOutline","box","hpOutline","hp","hpText","name","dist","tool","tracer","look","hat","arrow","halo","headCircle" }

local espCounter = 0
local function createEspObject()
    local obj = { skeleton = {}, corners = {}, ring = {} }
    espCounter = espCounter + 1

    local hl = Instance.new("Highlight")
    hl.Name = "OxideESP_" .. espCounter
    hl.FillTransparency = esp.chamsFillT
    hl.OutlineTransparency = esp.chamsOutlineT
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = false
    pcall(function() hl.Parent = getEspParent() end)
    obj.highlight = hl
    table.insert(HUB.highlights, hl)

    if hasDrawing then
        obj.boxFill    = newDrawing("Square", { Filled = true, Transparency = 0.2, Color = esp.color, ZIndex = 0, Visible = false })
        obj.boxOutline = newDrawing("Square", { Thickness = 3, Filled = false, Color = Color3.new(0,0,0), ZIndex = 1, Visible = false })
        obj.box        = newDrawing("Square", { Thickness = 1, Filled = false, Color = esp.color, ZIndex = 2, Visible = false })
        for i = 1, 8 do obj.corners[i] = newDrawing("Line", { Thickness = 1.5, Color = esp.color, ZIndex = 2, Visible = false }) end
        obj.hpOutline  = newDrawing("Line",   { Thickness = 3, Color = Color3.new(0,0,0), ZIndex = 1, Visible = false })
        obj.hp         = newDrawing("Line",   { Thickness = 1, Color = Color3.fromRGB(0,255,0), ZIndex = 2, Visible = false })
        obj.hpText     = newDrawing("Text",   { Size = 11, Center = false, Outline = true, Font = esp.font, Color = Color3.new(1,1,1), ZIndex = 3, Visible = false })
        obj.name       = newDrawing("Text",   { Size = 14, Center = true, Outline = true, Font = esp.font, Color = esp.color, ZIndex = 3, Visible = false })
        obj.dist       = newDrawing("Text",   { Size = 13, Center = true, Outline = true, Font = esp.font, Color = Color3.new(1,1,1), ZIndex = 3, Visible = false })
        obj.tool       = newDrawing("Text",   { Size = 12, Center = true, Outline = true, Font = esp.font, Color = esp.color, ZIndex = 3, Visible = false })
        obj.tracer     = newDrawing("Line",   { Thickness = 1.5, Color = esp.color, ZIndex = 2, Visible = false })
        obj.look       = newDrawing("Line",   { Thickness = 1.5, Color = Color3.new(1,1,1), ZIndex = 2, Visible = false })
        obj.hat        = newDrawing("Triangle",{ Thickness = 1, Filled = true, Color = esp.color, ZIndex = 2, Visible = false })
        obj.arrow      = newDrawing("Triangle",{ Thickness = 1, Filled = true, Color = esp.color, ZIndex = 2, Visible = false })
        obj.halo       = newDrawing("Circle", { Thickness = 2, Filled = false, Color = esp.color, ZIndex = 2, Visible = false })
        obj.headCircle = newDrawing("Circle", { Thickness = 1.5, Filled = false, Color = esp.color, ZIndex = 2, Visible = false })
        for i = 1, RING_SEGMENTS do
            obj.ring[i] = newDrawing("Line", { Thickness = 1.5, Color = esp.color, ZIndex = 2, Visible = false })
        end
        for i = 1, MAX_BONES do
            obj.skeleton[i] = newDrawing("Line", { Thickness = 1, Color = esp.color, ZIndex = 2, Visible = false })
        end
    end
    return obj
end

local function removeEspObject(obj)
    if not obj then return end
    if obj.highlight then obj.highlight:Destroy() end
    for _, key in ipairs(DRAW_KEYS) do
        if obj[key] then pcall(function() obj[key]:Remove() end) end
    end
    for _, l in ipairs(obj.corners or {}) do pcall(function() l:Remove() end) end
    for _, l in ipairs(obj.ring or {}) do pcall(function() l:Remove() end) end
    for _, l in ipairs(obj.skeleton or {}) do pcall(function() l:Remove() end) end
end

local function createEsp(player)
    if espObjects[player] then return end
    local obj = createEspObject()
    obj.isFriend = false
    task.spawn(function()
        local ok, res = pcall(function() return LocalPlayer:IsFriendsWith(player.UserId) end)
        if ok then obj.isFriend = res == true end
    end)
    espObjects[player] = obj
end

local function removeEsp(player)
    local obj = espObjects[player]
    if not obj then return end
    removeEspObject(obj)
    espObjects[player] = nil
end

local function isFriendlyTeam(player)
    if not esp.teamCheck then return false end
    return player.Team ~= nil and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team
end

local function baseColorNow()
    if esp.rainbow then return Color3.fromHSV((tick() * 0.4) % 1, 1, 1) end
    return esp.color
end

local function healthColor(frac)
    return Color3.fromRGB(math.floor(255 * (1 - frac)), math.floor(255 * frac), 0)
end

-- Wall check: is the target part visible from the camera?
local function isVisible(char, part)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { GetCharacter(), Camera }
    local origin = Camera.CFrame.Position
    local result = Workspace:Raycast(origin, part.Position - origin, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(char)
end

-- Project an oriented bounding box to a 2D screen rectangle
local function getBox2D(char)
    local cf, size = char:GetBoundingBox()
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyOn = false
    for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
        local corner = (cf * CFrame.new(size.X/2 * x, size.Y/2 * y, size.Z/2 * z)).Position
        local sp, on = Camera:WorldToViewportPoint(corner)
        if sp.Z > 0 then
            anyOn = anyOn or on
            minX = math.min(minX, sp.X); minY = math.min(minY, sp.Y)
            maxX = math.max(maxX, sp.X); maxY = math.max(maxY, sp.Y)
        end
    end end end
    if minX == math.huge then return nil end
    return minX, minY, maxX, maxY, anyOn
end

local function hideObj(obj)
    for _, key in ipairs(DRAW_KEYS) do if obj[key] then obj[key].Visible = false end end
    for _, l in ipairs(obj.corners) do l.Visible = false end
    for _, l in ipairs(obj.ring) do l.Visible = false end
    for _, l in ipairs(obj.skeleton) do l.Visible = false end
    if obj.highlight then obj.highlight.Enabled = false end
end

local function setCornerBox(obj, l, t, r, b, col, thick)
    local L = math.clamp((r - l) * 0.28, 4, 16)
    local segs = {
        {Vector2.new(l, t), Vector2.new(l + L, t)}, {Vector2.new(l, t), Vector2.new(l, t + L)},
        {Vector2.new(r, t), Vector2.new(r - L, t)}, {Vector2.new(r, t), Vector2.new(r, t + L)},
        {Vector2.new(l, b), Vector2.new(l + L, b)}, {Vector2.new(l, b), Vector2.new(l, b - L)},
        {Vector2.new(r, b), Vector2.new(r - L, b)}, {Vector2.new(r, b), Vector2.new(r, b - L)},
    }
    for i, s in ipairs(segs) do
        local line = obj.corners[i]
        line.From, line.To, line.Color, line.Thickness, line.Visible = s[1], s[2], col, thick + 0.5, true
    end
end

-- Per-frame shared context
local F = {}

-- Renders one entity (player character or NPC model)
local function renderEntity(obj, char, displayName, isPlayer, player)
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart or char:FindFirstChildWhichIsA("BasePart"))
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local dist = (hrp and F.myHRP) and (hrp.Position - F.myHRP.Position).Magnitude or 0

    local gate = isPlayer and esp.players or (not isPlayer and esp.npcs)
    local allowed = gate and char ~= nil and hrp ~= nil
        and (esp.maxDistance <= 0 or dist <= esp.maxDistance)
        and (not hum or hum.Health > 0)
    if isPlayer and allowed and isFriendlyTeam(player) then allowed = false end

    -- color resolution
    local col = isPlayer and F.baseCol or esp.npcColor
    if allowed and isPlayer and esp.friendCheck and obj.isFriend then col = esp.friendColor end
    if allowed and esp.visibleCheck then
        local probe = char:FindFirstChild("Head") or hrp
        col = isVisible(char, probe) and esp.visibleColor or esp.hiddenColor
    end

    -- Chams
    if obj.highlight then
        obj.highlight.Enabled = allowed and esp.chams
        if allowed and esp.chams then
            obj.highlight.Adornee = char
            obj.highlight.FillColor = col
            obj.highlight.OutlineColor = col
            obj.highlight.FillTransparency = esp.chamsFillT
            obj.highlight.OutlineTransparency = esp.chamsOutlineT
            obj.highlight.DepthMode = esp.chamsDepth == "Occluded"
                and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
        end
    end

    if not hasDrawing then return end
    if not allowed or not F.anyDraw then hideObj(obj); return end

    local fade = esp.distanceFade and math.clamp(1 - dist / math.max(esp.maxDistance, 1), 0.2, 1) or 1
    local rootScreen, rootOn = Camera:WorldToViewportPoint(hrp.Position)
    local onScreen = rootScreen.Z > 0 and rootOn
    local left, top, right, bottom, boxOn = getBox2D(char)
    local haveBox = left ~= nil and boxOn

    if haveBox and esp.smooth then
        local prev = obj._rect
        if prev then
            local a = 0.45
            left   = prev[1] + (left - prev[1]) * a
            top    = prev[2] + (top - prev[2]) * a
            right  = prev[3] + (right - prev[3]) * a
            bottom = prev[4] + (bottom - prev[4]) * a
        end
        obj._rect = { left, top, right, bottom }
    end

    -- 2D Box
    local showFull = esp.box and haveBox and esp.boxStyle == "Full"
    local showCorner = esp.box and haveBox and esp.boxStyle == "Corner"
    obj.box.Visible = showFull
    obj.boxOutline.Visible = showFull
    if showFull then
        local pos = Vector2.new(left, top)
        local sz  = Vector2.new(right - left, bottom - top)
        obj.boxOutline.Position = pos - Vector2.new(1, 1); obj.boxOutline.Size = sz + Vector2.new(2, 2)
        obj.boxOutline.Thickness = esp.boxThickness + 2
        obj.box.Position = pos; obj.box.Size = sz; obj.box.Color = col; obj.box.Thickness = esp.boxThickness
    end
    if showCorner then setCornerBox(obj, left, top, right, bottom, col, esp.boxThickness)
    else for _, l in ipairs(obj.corners) do l.Visible = false end end

    -- Box fill
    if esp.box and esp.boxFill and haveBox then
        obj.boxFill.Position = Vector2.new(left, top)
        obj.boxFill.Size = Vector2.new(right - left, bottom - top)
        obj.boxFill.Color = col
        obj.boxFill.Transparency = esp.boxFillT * fade
        obj.boxFill.Visible = true
    else obj.boxFill.Visible = false end

    -- Health bar (left of box)
    local frac = hum and math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1) or 1
    if esp.health and haveBox and hum then
        local barX = left - 5
        obj.hpOutline.From = Vector2.new(barX, top - 1); obj.hpOutline.To = Vector2.new(barX, bottom + 1); obj.hpOutline.Visible = true
        obj.hp.From = Vector2.new(barX, bottom); obj.hp.To = Vector2.new(barX, bottom - (bottom - top) * frac)
        obj.hp.Color = healthColor(frac); obj.hp.Visible = true
    else obj.hp.Visible = false; obj.hpOutline.Visible = false end

    -- Health text
    if esp.healthText and haveBox and hum then
        obj.hpText.Text = esp.healthPercent and (math.floor(frac * 100) .. "%") or tostring(math.floor(hum.Health))
        obj.hpText.Font = esp.font
        obj.hpText.Position = Vector2.new(left - 24, (top + bottom) / 2 - 6)
        obj.hpText.Color = healthColor(frac)
        obj.hpText.Visible = true
    else obj.hpText.Visible = false end

    -- Name
    if esp.name and haveBox then
        obj.name.Text = displayName
        obj.name.Size = esp.textSize
        obj.name.Font = esp.font
        obj.name.Position = Vector2.new((left + right) / 2, top - esp.textSize - 2)
        obj.name.Color = col
        obj.name.Visible = true
    else obj.name.Visible = false end

    -- Distance
    if esp.distance and haveBox then
        obj.dist.Text = math.floor(dist) .. "m"
        obj.dist.Size = esp.textSize - 1
        obj.dist.Font = esp.font
        obj.dist.Position = Vector2.new((left + right) / 2, bottom + 2)
        obj.dist.Visible = true
    else obj.dist.Visible = false end

    -- Tool / held item
    if esp.tool and haveBox then
        local toolInst = char:FindFirstChildOfClass("Tool")
        if toolInst then
            obj.tool.Text = toolInst.Name
            obj.tool.Size = esp.textSize - 2
            obj.tool.Font = esp.font
            obj.tool.Position = Vector2.new((left + right) / 2, bottom + 2 + (esp.distance and esp.textSize or 0))
            obj.tool.Color = col
            obj.tool.Visible = true
        else obj.tool.Visible = false end
    else obj.tool.Visible = false end

    -- Tracer
    if esp.tracer and onScreen then
        obj.tracer.From = F.tracerFrom
        obj.tracer.To = Vector2.new(rootScreen.X, rootScreen.Y)
        obj.tracer.Color = col
        obj.tracer.Visible = true
    else obj.tracer.Visible = false end

    -- Look direction line
    if esp.look and char:FindFirstChild("Head") then
        local head = char.Head
        local fromP = Camera:WorldToViewportPoint(head.Position)
        local toP = Camera:WorldToViewportPoint(head.Position + head.CFrame.LookVector * 4)
        if fromP.Z > 0 and toP.Z > 0 then
            obj.look.From = Vector2.new(fromP.X, fromP.Y)
            obj.look.To = Vector2.new(toP.X, toP.Y)
            obj.look.Color = col
            obj.look.Visible = true
        else obj.look.Visible = false end
    else obj.look.Visible = false end

    -- Chinese hat cone
    if esp.hat and char:FindFirstChild("Head") then
        local head = char.Head
        local topPos = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.6, 0)
        local sp, on = Camera:WorldToViewportPoint(topPos)
        if sp.Z > 0 and on then
            local apex = Vector2.new(sp.X, sp.Y)
            local w = math.clamp(haveBox and (right - left) * 0.45 or 9, 6, 26)
            local h = w * 1.1
            obj.hat.PointA = apex
            obj.hat.PointB = apex + Vector2.new(-w, -h)
            obj.hat.PointC = apex + Vector2.new(w, -h)
            obj.hat.Color = col
            obj.hat.Visible = true
        else obj.hat.Visible = false end
    else obj.hat.Visible = false end

    -- Halo (hollow ring floating above the head)
    if esp.halo and char:FindFirstChild("Head") then
        local head = char.Head
        local topPos = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 1.4, 0)
        local sp, on = Camera:WorldToViewportPoint(topPos)
        if sp.Z > 0 and on then
            obj.halo.Position = Vector2.new(sp.X, sp.Y)
            obj.halo.Radius = math.clamp(haveBox and (right - left) * 0.35 or 10, 6, 34)
            obj.halo.Color = col
            obj.halo.Visible = true
        else obj.halo.Visible = false end
    else obj.halo.Visible = false end

    -- Head circle (ring around the head)
    if esp.headCircle and char:FindFirstChild("Head") then
        local head = char.Head
        local sp, on = Camera:WorldToViewportPoint(head.Position)
        local edge = Camera:WorldToViewportPoint(head.Position + Camera.CFrame.UpVector * (head.Size.Y * 0.6))
        if sp.Z > 0 and on then
            local r = math.clamp((Vector2.new(sp.X, sp.Y) - Vector2.new(edge.X, edge.Y)).Magnitude, 4, 40)
            obj.headCircle.Position = Vector2.new(sp.X, sp.Y)
            obj.headCircle.Radius = r
            obj.headCircle.Color = col
            obj.headCircle.Visible = true
        else obj.headCircle.Visible = false end
    else obj.headCircle.Visible = false end

    -- Ground ring (projected 3D circle at the feet)
    if esp.ring then
        local cf, size = char:GetBoundingBox()
        local feetY = cf.Position.Y - size.Y * 0.5
        local centerW = Vector3.new(hrp.Position.X, feetY, hrp.Position.Z)
        local worldR = math.max(size.X, size.Z) * 0.55 + 1
        local pts = {}
        for i = 1, RING_SEGMENTS do
            local a = (i - 1) / RING_SEGMENTS * math.pi * 2
            local wp = centerW + Vector3.new(math.cos(a) * worldR, 0, math.sin(a) * worldR)
            local s = Camera:WorldToViewportPoint(wp)
            pts[i] = { Vector2.new(s.X, s.Y), s.Z > 0 }
        end
        for i = 1, RING_SEGMENTS do
            local a, b = pts[i], pts[i % RING_SEGMENTS + 1]
            local line = obj.ring[i]
            if a[2] and b[2] then
                line.From, line.To, line.Color, line.Visible = a[1], b[1], col, true
            else line.Visible = false end
        end
    else
        for _, l in ipairs(obj.ring) do l.Visible = false end
    end

    -- Skeleton
    if esp.skeleton then
        local bones = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
        local i = 0
        for _, pair in ipairs(bones) do
            local a = char:FindFirstChild(pair[1])
            local b = char:FindFirstChild(pair[2])
            if a and b then
                local sa = Camera:WorldToViewportPoint(a.Position)
                local sb = Camera:WorldToViewportPoint(b.Position)
                if sa.Z > 0 and sb.Z > 0 then
                    i = i + 1
                    local line = obj.skeleton[i]
                    if line then
                        line.From = Vector2.new(sa.X, sa.Y)
                        line.To = Vector2.new(sb.X, sb.Y)
                        line.Color = col
                        line.Visible = true
                    end
                end
            end
        end
        for j = i + 1, MAX_BONES do obj.skeleton[j].Visible = false end
    else
        for _, l in ipairs(obj.skeleton) do l.Visible = false end
    end

    -- Off-screen arrow
    if esp.arrow and not onScreen then
        local dir = Vector2.new(rootScreen.X, rootScreen.Y) - F.center
        if rootScreen.Z < 0 then dir = -dir end
        if dir.Magnitude > 0 then
            dir = dir.Unit
            local arrowPos = F.center + dir * math.min(F.vp.X, F.vp.Y) * 0.32
            local ang = math.atan2(dir.Y, dir.X)
            local s = 16
            obj.arrow.PointA = arrowPos + Vector2.new(math.cos(ang), math.sin(ang)) * s
            obj.arrow.PointB = arrowPos + Vector2.new(math.cos(ang + 2.6), math.sin(ang + 2.6)) * s
            obj.arrow.PointC = arrowPos + Vector2.new(math.cos(ang - 2.6), math.sin(ang - 2.6)) * s
            obj.arrow.Color = col
            obj.arrow.Visible = true
        else obj.arrow.Visible = false end
    else obj.arrow.Visible = false end

    -- Distance fade (scales transparency of visible drawings)
    if esp.distanceFade or obj._faded then
        local t = esp.distanceFade and fade or 1
        for _, k in ipairs(DRAW_KEYS) do
            if k ~= "boxFill" then local d = obj[k]; if d and d.Visible then d.Transparency = t end end
        end
        for _, l in ipairs(obj.corners) do if l.Visible then l.Transparency = t end end
        for _, l in ipairs(obj.ring) do if l.Visible then l.Transparency = t end end
        for _, l in ipairs(obj.skeleton) do if l.Visible then l.Transparency = t end end
        obj._faded = esp.distanceFade
    end
end

track(RunService.RenderStepped:Connect(function()
    if HUB.dead then return end
    F.myHRP = GetHRP()
    F.baseCol = baseColorNow()
    F.vp = Camera.ViewportSize
    F.center = Vector2.new(F.vp.X / 2, F.vp.Y / 2)
    F.tracerFrom = F.center
    if esp.tracerOrigin == "Bottom" then F.tracerFrom = Vector2.new(F.vp.X / 2, F.vp.Y)
    elseif esp.tracerOrigin == "Top" then F.tracerFrom = Vector2.new(F.vp.X / 2, 0)
    elseif esp.tracerOrigin == "Mouse" then
        local m = UserInputService:GetMouseLocation(); F.tracerFrom = Vector2.new(m.X, m.Y)
    end
    F.anyDraw = esp.box or esp.name or esp.distance or esp.health or esp.healthText
        or esp.tool or esp.tracer or esp.skeleton or esp.hat or esp.arrow or esp.look
        or esp.halo or esp.headCircle or esp.ring

    if esp.enabled then
        for player, obj in pairs(espObjects) do
            renderEntity(obj, player.Character, player.DisplayName, true, player)
        end
        for model, obj in pairs(npcObjects) do
            if model.Parent then renderEntity(obj, model, model.Name, false, nil)
            else hideObj(obj) end
        end
    else
        for _, obj in pairs(espObjects) do hideObj(obj) end
        for _, obj in pairs(npcObjects) do hideObj(obj) end
    end
end))

-- NPC discovery (throttled): track non-player Humanoid models
local function isPlayerCharacter(model)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return true end
    end
    return false
end

local function refreshNPCs()
    if not esp.npcs then
        for model, obj in pairs(npcObjects) do removeEspObject(obj); npcObjects[model] = nil end
        return
    end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Humanoid") then
            local model = d.Parent
            if model and model:IsA("Model") and not npcObjects[model] and not isPlayerCharacter(model) then
                local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if part then npcObjects[model] = createEspObject() end
            end
        end
    end
    for model, obj in pairs(npcObjects) do
        if not model.Parent or not model:FindFirstChildOfClass("Humanoid") or isPlayerCharacter(model) then
            removeEspObject(obj); npcObjects[model] = nil
        end
    end
end

task.spawn(function()
    while not HUB.dead do
        pcall(refreshNPCs)
        task.wait(2)
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then createEsp(p) end
end
track(Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then createEsp(p) end end))
track(Players.PlayerRemoving:Connect(removeEsp))

if not hasDrawing then
    EspSub:AddParagraph({
        Title = "Limited ESP Mode",
        Text = "This executor has no Drawing API, so only Chams (Highlight) is available. Box / skeleton / hat / tracers need Drawing.",
    })
end

EspSub:AddSection("Targets")
EspSub:AddToggle({ Name = "Master Enable", Default = true, Flag = "esp_enabled", Callback = function(v) esp.enabled = v end })
EspSub:AddToggle({ Name = "Players", Default = true, Flag = "esp_players", Callback = function(v) esp.players = v end })
EspSub:AddToggle({ Name = "NPCs", Default = false, Flag = "esp_npcs", Description = "Non-player humanoids (mobs)", Callback = function(v) esp.npcs = v end })

EspSub:AddSection("Boxes")
EspSub:AddToggle({ Name = "2D Box", Default = false, Flag = "esp_box", Callback = function(v) esp.box = v end })
local applyBoxStyle = function(v) esp.boxStyle = v end
local boxStyleDropdown = EspSub:AddDropdown({
    Name = "Box Style", Options = { "Corner", "Full" }, Default = "Corner",
    MaxVisible = 2, Flag = "esp_boxstyle", Callback = applyBoxStyle,
})
registerResync(boxStyleDropdown, applyBoxStyle)
EspSub:AddSlider({ Name = "Box Thickness", Min = 1, Max = 5, Default = 1, Suffix = "", Flag = "esp_boxthick", Callback = function(v) esp.boxThickness = v end })
EspSub:AddToggle({ Name = "Box Fill", Default = false, Flag = "esp_boxfill", Callback = function(v) esp.boxFill = v end })
EspSub:AddSlider({ Name = "Box Fill Opacity", Min = 0, Max = 100, Default = 80, Suffix = "%", Flag = "esp_boxfill_op", Callback = function(v) esp.boxFillT = v / 100 end })

EspSub:AddSection("Chams")
EspSub:AddToggle({ Name = "Chams (Highlight)", Default = false, Flag = "esp_chams", Callback = function(v) esp.chams = v end })
local applyChamsDepth = function(v) esp.chamsDepth = v end
local chamsDepthDropdown = EspSub:AddDropdown({
    Name = "Chams Depth", Options = { "AlwaysOnTop", "Occluded" }, Default = "AlwaysOnTop",
    MaxVisible = 2, Flag = "esp_chamsdepth", Callback = applyChamsDepth,
})
registerResync(chamsDepthDropdown, applyChamsDepth)
EspSub:AddSlider({ Name = "Chams Fill", Min = 0, Max = 100, Default = 45, Suffix = "%", Flag = "esp_chams_fill", Callback = function(v) esp.chamsFillT = 1 - v / 100 end })
EspSub:AddSlider({ Name = "Chams Outline", Min = 0, Max = 100, Default = 100, Suffix = "%", Flag = "esp_chams_out", Callback = function(v) esp.chamsOutlineT = 1 - v / 100 end })

EspSub:AddSection("Text & Bars")
EspSub:AddToggle({ Name = "Name", Default = false, Flag = "esp_name", Callback = function(v) esp.name = v end })
EspSub:AddToggle({ Name = "Distance", Default = false, Flag = "esp_distance", Callback = function(v) esp.distance = v end })
EspSub:AddToggle({ Name = "Held Tool", Default = false, Flag = "esp_tool", Callback = function(v) esp.tool = v end })
EspSub:AddToggle({ Name = "Health Bar", Default = false, Flag = "esp_health", Callback = function(v) esp.health = v end })
EspSub:AddToggle({ Name = "Health Number", Default = false, Flag = "esp_healthtext", Callback = function(v) esp.healthText = v end })
EspSub:AddToggle({ Name = "Health As %", Default = false, Flag = "esp_healthpct", Callback = function(v) esp.healthPercent = v end })
EspSub:AddSlider({ Name = "Text Size", Min = 10, Max = 22, Default = 14, Suffix = "", Flag = "esp_textsize", Callback = function(v) esp.textSize = v end })
local applyFont = function(v) esp.font = FONT_MAP[v] or 2 end
local fontDropdown = EspSub:AddDropdown({
    Name = "Text Font", Options = { "UI", "System", "Plain", "Monospace" }, Default = "Plain",
    MaxVisible = 4, Flag = "esp_font", Callback = applyFont,
})
registerResync(fontDropdown, applyFont)

EspSub:AddSection("Extras")
EspSub:AddToggle({ Name = "Halo (head ring)", Default = false, Flag = "esp_halo", Callback = function(v) esp.halo = v end })
EspSub:AddToggle({ Name = "Head Circle", Default = false, Flag = "esp_headcircle", Callback = function(v) esp.headCircle = v end })
EspSub:AddToggle({ Name = "Ground Ring (3D)", Default = false, Flag = "esp_ring", Callback = function(v) esp.ring = v end })
EspSub:AddToggle({ Name = "Skeleton", Default = false, Flag = "esp_skeleton", Callback = function(v) esp.skeleton = v end })
EspSub:AddToggle({ Name = "Chinese Hat (cone)", Default = false, Flag = "esp_hat", Callback = function(v) esp.hat = v end })
EspSub:AddToggle({ Name = "Look Direction", Default = false, Flag = "esp_look", Callback = function(v) esp.look = v end })
EspSub:AddToggle({ Name = "Tracers", Default = false, Flag = "esp_tracers", Callback = function(v) esp.tracer = v end })
EspSub:AddToggle({ Name = "Off-Screen Arrows", Default = false, Flag = "esp_arrow", Callback = function(v) esp.arrow = v end })
local applyTracerOrigin = function(v) esp.tracerOrigin = v end
local tracerOriginDropdown = EspSub:AddDropdown({
    Name = "Tracer Origin", Options = { "Bottom", "Center", "Top", "Mouse" },
    Default = "Bottom", MaxVisible = 4, Flag = "esp_tracer_origin",
    Callback = applyTracerOrigin,
})
registerResync(tracerOriginDropdown, applyTracerOrigin)

EspSub:AddSection("Behavior")
EspSub:AddToggle({ Name = "Team Check (hide allies)", Default = false, Flag = "esp_team", Callback = function(v) esp.teamCheck = v end })
EspSub:AddToggle({ Name = "Friend Color", Default = false, Flag = "esp_friend", Description = "Color Roblox friends differently", Callback = function(v) esp.friendCheck = v end })
EspSub:AddToggle({
    Name = "Visibility Check", Default = false, Flag = "esp_visible",
    Description = "Color targets by line-of-sight",
    Callback = function(v) esp.visibleCheck = v end,
})
EspSub:AddToggle({ Name = "Box Smoothing", Default = true, Flag = "esp_smooth", Callback = function(v) esp.smooth = v end })
EspSub:AddToggle({ Name = "Distance Fade", Default = false, Flag = "esp_fade", Description = "Fade ESP for far targets", Callback = function(v) esp.distanceFade = v end })
EspSub:AddToggle({ Name = "Rainbow", Default = false, Flag = "esp_rainbow", Callback = function(v) esp.rainbow = v end })
EspSub:AddSlider({
    Name = "Max Distance", Min = 0, Max = 5000, Default = 1000, Suffix = "m", Flag = "esp_maxdist",
    Description = "0 = unlimited", Callback = function(v) esp.maxDistance = v end,
})

EspSub:AddSection("Colors")
EspSub:AddColorPicker({ Name = "Main Color", Default = Color3.fromRGB(30, 90, 220), Flag = "esp_color", Callback = function(c) esp.color = c end })
EspSub:AddColorPicker({ Name = "Visible Color", Default = Color3.fromRGB(95, 220, 120), Flag = "esp_viscolor", Callback = function(c) esp.visibleColor = c end })
EspSub:AddColorPicker({ Name = "Hidden Color", Default = Color3.fromRGB(235, 75, 75), Flag = "esp_hidcolor", Callback = function(c) esp.hiddenColor = c end })
EspSub:AddColorPicker({ Name = "Friend Color", Default = Color3.fromRGB(95, 150, 255), Flag = "esp_friendcolor", Callback = function(c) esp.friendColor = c end })
EspSub:AddColorPicker({ Name = "NPC Color", Default = Color3.fromRGB(235, 200, 70), Flag = "esp_npccolor", Callback = function(c) esp.npcColor = c end })


-- ── WORLD / LIGHTING ─────────────────────────────────────────────────────────
local WorldSub = VisualsTab:AddSubTab("World")

local fullbright = false
local savedLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
}

WorldSub:AddToggle({
    Name = "Fullbright", Default = false, Flag = "fullbright",
    Callback = function(v)
        fullbright = v
        if v then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 1e9
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        else
            Lighting.Brightness = savedLighting.Brightness
            Lighting.ClockTime = savedLighting.ClockTime
            Lighting.FogEnd = savedLighting.FogEnd
            Lighting.GlobalShadows = savedLighting.GlobalShadows
            Lighting.Ambient = savedLighting.Ambient
        end
    end,
})

local defaultFOV = Camera.FieldOfView
WorldSub:AddSlider({
    Name = "Field of View", Min = 30, Max = 120, Default = math.floor(defaultFOV), Suffix = "°", Flag = "fov",
    Callback = function(v) Camera.FieldOfView = v end,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- COMBAT TAB (Aimbot)
-- ══════════════════════════════════════════════════════════════════════════════
local CombatTab = Window:AddTab({ Name = "Combat", Subtitle = "Aimbot", Icon = "target" })
local AimSub = CombatTab:AddSubTab("Aimbot")

local aim = {
    enabled    = false,
    smoothness = 12,        -- higher = slower / smoother (alpha = 1/smoothness)
    fov        = 150,       -- target acquisition radius in pixels
    prediction = 0,         -- lead the target by velocity * this many seconds (0 = off)
    part       = "Head",    -- aim target part
    teamCheck  = false,
    visibleCheck = false,   -- raycast wall check
    aliveCheck = true,
    useRightClick = true,   -- hold RMB to aim
    altKey     = nil,       -- optional alternate hold key
    toggleMode = false,     -- press to toggle lock instead of hold
    showFov    = true,
    fovColor   = Color3.fromRGB(30, 90, 220),
}

-- Input / lock state
local mb2Down, altDown, toggleLocked = false, false, false
local function aimWanted()
    if aim.toggleMode then return toggleLocked end
    return (aim.useRightClick and mb2Down) or (aim.altKey ~= nil and altDown)
end

track(UserInputService.InputBegan:Connect(function(input, gp)
    if HUB.dead then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then mb2Down = true end
    if aim.altKey and input.KeyCode == aim.altKey then
        altDown = true
        if aim.toggleMode then toggleLocked = not toggleLocked end
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 and aim.toggleMode and aim.useRightClick then
        toggleLocked = not toggleLocked
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then mb2Down = false end
    if aim.altKey and input.KeyCode == aim.altKey then altDown = false end
end))

-- FOV circle (Drawing API, optional)
local fovCircle = newDrawing("Circle", { Thickness = 1.5, Filled = false, Visible = false })

local function getAimPart(char)
    if not char then return nil end
    return char:FindFirstChild(aim.part)
        or char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
end

local function isAlive(char)
    if not aim.aliveCheck then return true end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function isVisible(char, part)
    if not aim.visibleCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { GetCharacter() }
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local result = Workspace:Raycast(origin, dir, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(char)
end

local function getClosestTarget()
    local best, bestDist
    local mouse = UserInputService:GetMouseLocation()
    local vp = Camera.ViewportSize
    local center = Vector2.new(mouse.X, mouse.Y)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local isTeammate = aim.teamCheck and p.Team ~= nil and LocalPlayer.Team ~= nil and p.Team == LocalPlayer.Team
            if not isTeammate then
                local char = p.Character
                local part = getAimPart(char)
                if part and isAlive(char) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local d = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if d <= aim.fov and (not bestDist or d < bestDist) then
                            if isVisible(char, part) then
                                best, bestDist = part, d
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

track(RunService.RenderStepped:Connect(function()
    if HUB.dead then return end
    if fovCircle then
        fovCircle.Visible = aim.enabled and aim.showFov
        if fovCircle.Visible then
            local mouse = UserInputService:GetMouseLocation()
            fovCircle.Position = Vector2.new(mouse.X, mouse.Y)
            fovCircle.Radius = aim.fov
            fovCircle.Color = aim.fovColor
        end
    end

    if not aim.enabled or not aimWanted() then return end
    local target = getClosestTarget()
    if not target then return end

    local camPos = Camera.CFrame.Position
    -- Lead moving targets by their velocity so the lock tracks ahead of them
    local aimPos = target.Position
    if aim.prediction > 0 then
        aimPos = aimPos + target.AssemblyLinearVelocity * aim.prediction
    end
    local goal = CFrame.new(camPos, aimPos)
    local alpha = math.clamp(1 / math.max(aim.smoothness, 1), 0, 1)
    Camera.CFrame = Camera.CFrame:Lerp(goal, alpha)
end))

AimSub:AddSection("Aimbot")
AimSub:AddToggle({
    Name = "Enabled", Default = false, Flag = "aim_enabled",
    Callback = function(v)
        aim.enabled = v
        if not v then toggleLocked = false end
        Notify("Aimbot", v and "Enabled (hold Right-Click)" or "Disabled", v and "Success" or "Error")
    end,
})
AimSub:AddSlider({
    Name = "Smoothness", Min = 1, Max = 40, Default = 12, Suffix = "",
    Description = "Higher = smoother / slower lock", Flag = "aim_smooth",
    Callback = function(v) aim.smoothness = v end,
})
AimSub:AddSlider({
    Name = "FOV (px)", Min = 30, Max = 600, Default = 150, Suffix = "", Flag = "aim_fov",
    Callback = function(v) aim.fov = v end,
})
AimSub:AddSlider({
    Name = "Prediction", Min = 0, Max = 100, Default = 0, Suffix = "", Flag = "aim_prediction",
    Description = "Leads moving targets · raise if shots land behind them",
    Callback = function(v) aim.prediction = v / 1000 end,
})

local applyAimPart = function(v) aim.part = v end
local aimPartDropdown = AimSub:AddDropdown({
    Name = "Target Part", Options = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" },
    Default = "Head", MaxVisible = 4, Flag = "aim_part",
    Callback = applyAimPart,
})
registerResync(aimPartDropdown, applyAimPart)

AimSub:AddSection("Filters")
AimSub:AddToggle({ Name = "Team Check", Default = false, Flag = "aim_team", Callback = function(v) aim.teamCheck = v end })
AimSub:AddToggle({ Name = "Wall Check (visible only)", Default = false, Flag = "aim_visible", Callback = function(v) aim.visibleCheck = v end })
AimSub:AddToggle({ Name = "Alive Check", Default = true, Flag = "aim_alive", Callback = function(v) aim.aliveCheck = v end })

AimSub:AddSection("Activation")
AimSub:AddToggle({ Name = "Hold Right-Click", Default = true, Flag = "aim_rmb", Callback = function(v) aim.useRightClick = v end })
AimSub:AddToggle({
    Name = "Toggle Mode", Default = false, Flag = "aim_toggle",
    Description = "Press the key/button to lock instead of holding",
    Callback = function(v) aim.toggleMode = v; toggleLocked = false end,
})
AimSub:AddKeybind({
    Name = "Alt Aim Key", Default = nil, Flag = "aim_altkey",
    Callback = function(k) aim.altKey = k; altDown = false end,
})

AimSub:AddSection("FOV Circle")
AimSub:AddToggle({
    Name = "Show FOV Circle", Default = true, Flag = "aim_showfov",
    Description = hasDrawing and "Follows the cursor" or "Drawing API unavailable on this executor",
    Callback = function(v)
        aim.showFov = v and hasDrawing
        if v and not hasDrawing then Notify("Aimbot", "FOV circle needs Drawing API", "Warning", 3) end
    end,
})
AimSub:AddColorPicker({
    Name = "FOV Circle Color", Default = Color3.fromRGB(30, 90, 220), Flag = "aim_fovcolor",
    Callback = function(c) aim.fovColor = c end,
})

-- ══════════════════════════════════════════════════════════════════════════════
-- SERVER TAB
-- ══════════════════════════════════════════════════════════════════════════════
local ServerTab = Window:AddTab({ Name = "Server", Subtitle = "Join & hop", Icon = "globe" })
local ServerSub = ServerTab:AddSubTab("Actions")

ServerSub:AddButton({
    Name = "Rejoin Server", Primary = true,
    Callback = function()
        Notify("Server", "Rejoining...", "Info")
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end,
})
ServerSub:AddButton({
    Name = "Server Hop",
    Callback = function()
        Notify("Server", "Finding a new server...", "Info")
        task.spawn(function()
            local ok, err = pcall(function()
                local HttpService = game:GetService("HttpService")
                local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
                local raw = game:HttpGet(url)
                local data = HttpService:JSONDecode(raw)
                for _, s in ipairs(data.data or {}) do
                    if type(s.playing) == "number" and s.playing < s.maxPlayers and s.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                        return
                    end
                end
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
            if not ok then Notify("Server", "Hop failed: " .. tostring(err), "Error", 4) end
        end)
    end,
})
ServerSub:AddButton({
    Name = "Copy Job ID",
    Callback = function()
        local ok = pcall(function() (setclipboard or toclipboard or writeclipboard)(game.JobId) end)
        Notify("Server", ok and "Job ID copied" or "Clipboard unavailable", ok and "Success" or "Error")
    end,
})

ServerSub:AddParagraph({
    Title = "Session Info",
    Text = ("Place: %d\nJob: %s\nPlayers: %d/%d")
        :format(game.PlaceId, tostring(game.JobId), #Players:GetPlayers(), Players.MaxPlayers),
})

-- ══════════════════════════════════════════════════════════════════════════════
-- SETTINGS TAB
-- ══════════════════════════════════════════════════════════════════════════════
local SettingsTab = Window:AddTab({ Name = "Settings", Subtitle = "Config & UI", Icon = "settings" })
local SettingsSub = SettingsTab:AddSubTab("General")

if type(Library.SetTheme) == "function" then
    SettingsSub:AddDropdown({
        Name = "Theme", Options = { "Dark", "Light", "OLED" }, Default = "Dark",
        Flag = "ui_theme",
        Callback = function(v) pcall(function() Library:SetTheme(v) end) end,
    })
end

-- ── PERFORMANCE / FPS ─────────────────────────────────────────────────────────
local setFpsCap = setfpscap or (getfenv and getfenv().setfpscap)
SettingsSub:AddSection("Performance")
if type(setFpsCap) == "function" then
    local fpsUnlocked = false
    local fpsCap = 240
    SettingsSub:AddToggle({
        Name = "Unlock FPS (Unlimited)", Default = false, Flag = "fps_unlock",
        Description = "Removes the FPS cap (infinite)",
        Callback = function(v)
            fpsUnlocked = v
            pcall(setFpsCap, v and 0 or fpsCap)
            Notify("FPS", v and "Unlocked (unlimited)" or ("Capped at " .. fpsCap), v and "Success" or "Info")
        end,
    })
    SettingsSub:AddSlider({
        Name = "FPS Cap", Min = 30, Max = 1000, Default = 240, Suffix = "", Flag = "fps_cap",
        Description = "Used when FPS is not unlocked (0 via unlock = ∞)",
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
        Text = "This Oxide UI build does not expose the flag/config system (requires v2.3+). All other features still work.",
    })
end

SettingsSub:AddSection("UI")

function HUB.Unload()
    if HUB.dead then return end
    HUB.dead = true
    -- stop feature loops / states
    flying = false; noclip = false; following = false; aim.enabled = false
    pcall(function() if flyConn then flyConn:Disconnect() end end)
    pcall(stopNoclip)
    -- disconnect all tracked connections
    for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
    -- remove all drawings (ESP + FOV circle)
    for _, d in ipairs(HUB.drawings) do pcall(function() d:Remove() end) end
    -- destroy all highlights
    for _, h in ipairs(HUB.highlights) do pcall(function() h:Destroy() end) end
    table.clear(espObjects)
    table.clear(npcObjects)
    -- restore world / character state
    pcall(function()
        local hum = GetHumanoid()
        if hum then hum.PlatformStand = false; hum.WalkSpeed = 16; hum.JumpPower = 50 end
    end)
    Workspace.Gravity = defaultGravity
    Camera.FieldOfView = defaultFOV
    if fullbright then
        Lighting.Brightness = savedLighting.Brightness
        Lighting.ClockTime = savedLighting.ClockTime
        Lighting.FogEnd = savedLighting.FogEnd
        Lighting.GlobalShadows = savedLighting.GlobalShadows
        Lighting.Ambient = savedLighting.Ambient
    end
    pcall(function() Window:Destroy() end)
end

SettingsSub:AddButton({
    Name = "Unload Hub",
    Callback = function()
        HUB.Unload()
        _G.OxideUniversal = nil
    end,
})

Notify("Oxide HUB", "Universal loaded successfully", "Success", 4)

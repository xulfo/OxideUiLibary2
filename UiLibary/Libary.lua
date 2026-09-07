local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")
local Players          = game:GetService("Players")
local Stats            = game:GetService("Stats")
local RunService       = game:GetService("RunService")
local AssetService     = game:GetService("AssetService")
local TextService      = game:GetService("TextService")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")

local DEFAULT_LOGO = "rbxassetid://114345069590059"
local TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local NOTIFICATION_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local PROFILE_TWEEN = TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- ════════════════════════════════════════════════════════════════════════════
-- BUILT-IN ICON LIBRARY
-- ════════════════════════════════════════════════════════════════════════════
local ICONS = {
    home            = "rbxassetid://4562959382",
    dashboard       = "rbxassetid://115870883170035",
    search          = "rbxassetid://18733177504",
    settings        = "rbxassetid://4738901432",
    gear            = "rbxassetid://117427252698455",
    menu            = "rbxassetid://10734896206",
    list            = "rbxassetid://10709790373",
    grid            = "rbxassetid://10734950309",
    sliders         = "rbxassetid://10734897102",
    swords          = "rbxassetid://10747384394",
    sword           = "rbxassetid://10747384394",
    combat          = "rbxassetid://10747384394",
    shield          = "rbxassetid://98206735878224",
    target          = "rbxassetid://123292899197910",
    crosshair       = "rbxassetid://10723434538",
    aim             = "rbxassetid://10723434538",
    bolt            = "rbxassetid://79160363518966",
    lightning       = "rbxassetid://125222658692748",
    zap             = "rbxassetid://79160363518966",
    fire            = "rbxassetid://10723415285",
    flame           = "rbxassetid://10723415285",
    star            = "rbxassetid://10734924532",
    sparkle         = "rbxassetid://10723422246",
    player          = "rbxassetid://82179723353246",
    user            = "rbxassetid://10747387118",
    person          = "rbxassetid://77052607579460",
    users           = "rbxassetid://10747387298",
    team            = "rbxassetid://10747387298",
    group           = "rbxassetid://10747387298",
    eye             = "rbxassetid://131012605615689",
    visible         = "rbxassetid://10709790644",
    visuals         = "rbxassetid://10709790644",
    render          = "rbxassetid://10709790644",
    esp             = "rbxassetid://10709790644",
    eyeoff          = "rbxassetid://10709790497",
    hidden          = "rbxassetid://10709790497",
    globe           = "rbxassetid://13567318216",
    world           = "rbxassetid://10709778567",
    compass         = "rbxassetid://10709790373",
    map             = "rbxassetid://84513890895579",
    move            = "rbxassetid://10723422998",
    arrows          = "rbxassetid://10723422998",
    heart           = "rbxassetid://10723415389",
    like            = "rbxassetid://10723415389",
    bell            = "rbxassetid://10723345067",
    notification    = "rbxassetid://10723345067",
    alert           = "rbxassetid://10723345067",
    info            = "rbxassetid://10723415389",
    about           = "rbxassetid://10723415389",
    help            = "rbxassetid://10723415389",
    warning         = "rbxassetid://10747387522",
    caution         = "rbxassetid://10747387522",
    check           = "rbxassetid://5180860280",
    checkmark       = "rbxassetid://5180860280",
    lock            = "rbxassetid://10723417148",
    unlock          = "rbxassetid://10723422607",
    power           = "rbxassetid://10723422754",
    toggle          = "rbxassetid://10723422754",
    refresh         = "rbxassetid://10723417783",
    folder          = "rbxassetid://10709791437",
    file            = "rbxassetid://10709791258",
    save            = "rbxassetid://10709791258",
    download        = "rbxassetid://10709790497",
    clipboard       = "rbxassetid://10709751190",
    play            = "rbxassetid://10723422607",
    music           = "rbxassetid://10723421745",
    volume          = "rbxassetid://10723421745",
    camera          = "rbxassetid://10709778567",
    image           = "rbxassetid://10709791437",
    clock           = "rbxassetid://10723345037",
    time            = "rbxassetid://10723345037",
    timer           = "rbxassetid://10723345037",
    wrench          = "rbxassetid://100244385350031",
    tool            = "rbxassetid://10734950309",
    code            = "rbxassetid://10709751190",
    terminal        = "rbxassetid://10709751190",
    script          = "rbxassetid://10709751190",
    bug             = "rbxassetid://10723415903",
    debug           = "rbxassetid://10723415903",
    layers          = "rbxassetid://10723417148",
    inventory       = "rbxassetid://14118896735",
    backpack        = "rbxassetid://10723415285",
    box             = "rbxassetid://10723415285",
    package         = "rbxassetid://10723415285",
    gift            = "rbxassetid://10723415389",
    crown           = "rbxassetid://10734924532",
    gem             = "rbxassetid://10723421745",
    coin            = "rbxassetid://13522871708",
    magic           = "rbxassetid://11111111111",
    wand            = "rbxassetid://10734924532",
    potion          = "rbxassetid://10723415285",
    skull           = "rbxassetid://10747384394",
    death           = "rbxassetid://10747384394",
    gamepad         = "rbxassetid://10723422998",
    controller      = "rbxassetid://10723422998",
    teleport        = "rbxassetid://10090587519",
    speed           = "rbxassetid://11111111111",
    running         = "rbxassetid://10723422998",
    favorite        = "rbxassetid://10734924532",
}

local NOTIFICATION_STYLES = {
    info    = { Name = "Info",    Color = Color3.fromRGB(118, 151, 194), Icon = "rbxassetid://10723345067" },
    success = { Name = "Success", Color = Color3.fromRGB(105, 166, 124), Icon = "rbxassetid://5180860280" },
    warning = { Name = "Warning", Color = Color3.fromRGB(190, 154, 84),  Icon = "rbxassetid://10747387522" },
    error   = { Name = "Error",   Color = Color3.fromRGB(190, 99, 99),   Icon = "rbxassetid://10747387522" },
}

local C = {
    WindowBg     = Color3.fromRGB(20, 20, 20),
    CardBg       = Color3.fromRGB(24, 24, 24),
    Border       = Color3.fromRGB(35, 35, 35),
    Element      = Color3.fromRGB(31, 31, 31),
    ElementHover = Color3.fromRGB(38, 38, 38),
    Badge        = Color3.fromRGB(42, 42, 42),
    BadgeIdle    = Color3.fromRGB(34, 34, 34),
    NavActive    = Color3.fromRGB(30, 30, 30),
    NavHover     = Color3.fromRGB(26, 26, 26),
    PillActive   = Color3.fromRGB(36, 36, 36),
    White        = Color3.fromRGB(255, 255, 255),
    TextGray     = Color3.fromRGB(154, 154, 154),
    TextDim      = Color3.fromRGB(139, 139, 139),
    KnobOff      = Color3.fromRGB(85, 85, 85),
    KnobOn       = Color3.fromRGB(17, 17, 17),
    TrackBg      = Color3.fromRGB(43, 43, 43),
    Placeholder  = Color3.fromRGB(86, 86, 86),
    HotbarBg     = Color3.fromRGB(24, 24, 24),
    HotbarBorder = Color3.fromRGB(35, 35, 35),
    HotbarActive = Color3.fromRGB(31, 31, 31),
    HotbarHover  = Color3.fromRGB(38, 38, 38),
    HotbarDot    = Color3.fromRGB(220, 220, 220),
    Accent       = Color3.fromRGB(167, 200, 244),
    AccentDim    = Color3.fromRGB(26, 46, 74),
    AccentText   = Color3.fromRGB(10, 16, 26),
    KnobAccent   = Color3.fromRGB(16, 22, 32),
}

local THEMES = {
    Dark = table.clone(C),
    Light = {
        WindowBg     = Color3.fromRGB(245, 245, 245),
        CardBg       = Color3.fromRGB(249, 249, 249),
        Border       = Color3.fromRGB(218, 218, 218),
        Element      = Color3.fromRGB(235, 235, 235),
        ElementHover = Color3.fromRGB(229, 229, 229),
        Badge        = Color3.fromRGB(224, 224, 224),
        BadgeIdle    = Color3.fromRGB(232, 232, 232),
        NavActive    = Color3.fromRGB(238, 238, 238),
        NavHover     = Color3.fromRGB(242, 242, 242),
        PillActive   = Color3.fromRGB(226, 226, 226),
        White        = Color3.fromRGB(20, 20, 20),
        TextGray     = Color3.fromRGB(84, 84, 84),
        TextDim      = Color3.fromRGB(105, 105, 105),
        KnobOff      = Color3.fromRGB(150, 150, 150),
        KnobOn       = Color3.fromRGB(250, 250, 250),
        TrackBg      = Color3.fromRGB(210, 210, 210),
        Placeholder  = Color3.fromRGB(135, 135, 135),
        HotbarBg     = Color3.fromRGB(249, 249, 249),
        HotbarBorder = Color3.fromRGB(218, 218, 218),
        HotbarActive = Color3.fromRGB(235, 235, 235),
        HotbarHover  = Color3.fromRGB(229, 229, 229),
        HotbarDot    = Color3.fromRGB(60, 60, 60),
        Accent       = Color3.fromRGB(94, 148, 214),
        AccentDim    = Color3.fromRGB(198, 220, 248),
        AccentText   = Color3.fromRGB(255, 255, 255),
        KnobAccent   = Color3.fromRGB(255, 255, 255),
    },
    OLED = {
        WindowBg     = Color3.fromRGB(0, 0, 0),
        CardBg       = Color3.fromRGB(5, 5, 5),
        Border       = Color3.fromRGB(25, 25, 25),
        Element      = Color3.fromRGB(12, 12, 12),
        ElementHover = Color3.fromRGB(20, 20, 20),
        Badge        = Color3.fromRGB(28, 28, 28),
        BadgeIdle    = Color3.fromRGB(16, 16, 16),
        NavActive    = Color3.fromRGB(9, 9, 9),
        NavHover     = Color3.fromRGB(6, 6, 6),
        PillActive   = Color3.fromRGB(22, 22, 22),
        White        = Color3.fromRGB(255, 255, 255),
        TextGray     = Color3.fromRGB(165, 165, 165),
        TextDim      = Color3.fromRGB(125, 125, 125),
        KnobOff      = Color3.fromRGB(75, 75, 75),
        KnobOn       = Color3.fromRGB(3, 3, 3),
        TrackBg      = Color3.fromRGB(32, 32, 32),
        Placeholder  = Color3.fromRGB(90, 90, 90),
        HotbarBg     = Color3.fromRGB(5, 5, 5),
        HotbarBorder = Color3.fromRGB(25, 25, 25),
        HotbarActive = Color3.fromRGB(12, 12, 12),
        HotbarHover  = Color3.fromRGB(20, 20, 20),
        HotbarDot    = Color3.fromRGB(200, 200, 200),
        Accent       = Color3.fromRGB(178, 210, 250),
        AccentDim    = Color3.fromRGB(16, 32, 56),
        AccentText   = Color3.fromRGB(5, 9, 16),
        KnobAccent   = Color3.fromRGB(8, 12, 20),
    },
}

local REVERSE = {}
local function rebuildReverse()
    table.clear(REVERSE)
    for key, color in pairs(C) do
        REVERSE[color:ToHex()] = key
    end
end
rebuildReverse()

local function tween(inst, props)
    TweenService:Create(inst, TWEEN, props):Play()
end
local function paint(inst, prop, key, instant)
    inst:SetAttribute("Theme_" .. prop, key)
    if instant then inst[prop] = C[key] else tween(inst, { [prop] = C[key] }) end
end
local function safeHex(value)
    if typeof(value) ~= "Color3" then return nil end
    local ok, result = pcall(function() return value:ToHex() end)
    return ok and result or nil
end

local function make(className, props)
    local inst = Instance.new(className)
    if inst:IsA("GuiObject") then
        inst.BorderSizePixel = 0
        inst.BackgroundColor3 = C.WindowBg
    end
    if inst:IsA("GuiButton") then inst.AutoButtonColor = false end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        inst.Font = Enum.Font.Gotham
        inst.TextColor3 = C.White
        inst.TextSize = 13
    end
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    if inst:IsA("GuiObject") then
        local key = REVERSE[safeHex(inst.BackgroundColor3)]
        if key then inst:SetAttribute("Theme_BackgroundColor3", key) end
    end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        local key = REVERSE[safeHex(inst.TextColor3)]
        if key then inst:SetAttribute("Theme_TextColor3", key) end
    end
    if inst:IsA("TextBox") then
        local key = REVERSE[safeHex(inst.PlaceholderColor3)]
        if key then inst:SetAttribute("Theme_PlaceholderColor3", key) end
    end
    if inst:IsA("ScrollingFrame") then
        local key = REVERSE[safeHex(inst.ScrollBarImageColor3)]
        if key then inst:SetAttribute("Theme_ScrollBarImageColor3", key) end
    end
    if inst:IsA("UIStroke") then
        local key = REVERSE[safeHex(inst.Color)]
        if key then inst:SetAttribute("Theme_Color", key) end
    end
    inst.Parent = props.Parent
    return inst
end

local function corner(parent, radius) return make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent }) end
local function circle(parent) return make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent }) end
local function stroke(parent, color)
    return make("UIStroke", {
        Color = color or C.Border, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
    })
end
local function pad(parent, top, bottom, left, right)
    return make("UIPadding", {
        PaddingTop = UDim.new(0, top), PaddingBottom = UDim.new(0, bottom),
        PaddingLeft = UDim.new(0, left), PaddingRight = UDim.new(0, right),
        Parent = parent,
    })
end

-- Rebuild an "accent at both ends" gradient from the theme keys stored on it.
-- Called on creation and again by Library:SetTheme so the colours follow the
-- active palette. The keys live on attributes because a UIGradient's Color is a
-- ColorSequence, which the attribute-driven repaint in SetTheme cannot handle.
local function refreshEdgeGradient(g)
    local edgeKey = g:GetAttribute("ThemeGradient_Edge")
    if not edgeKey then return end
    local edge = C[edgeKey]
    if not edge then return end
    local midKey = g:GetAttribute("ThemeGradient_Mid")
    if midKey then
        -- Static: accent at both ends, base colour across the middle.
        local mid = C[midKey]
        if not mid then return end
        local span = math.clamp(tonumber(g:GetAttribute("ThemeGradient_Span")) or 0.15, 0.02, 0.49)
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, edge),
            ColorSequenceKeypoint.new(span, mid),
            ColorSequenceKeypoint.new(1 - span, mid),
            ColorSequenceKeypoint.new(1, edge),
        })
    else
        -- Travelling band: accent at rest, whitening at the crest. Animated by
        -- sliding the gradient's Offset.
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, edge),
            ColorSequenceKeypoint.new(0.42, edge),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.58, edge),
            ColorSequenceKeypoint.new(1.00, edge),
        })
    end
end

-- Vertical fade driven by theme keys: top colour -> bottom colour. Used by
-- cards that want a coloured-to-base transition (e.g. light-blue accent
-- rising from the bottom). Kept theme-aware through attributes so that
-- Library:SetTheme repaints it like the edge gradients above.
local function refreshVerticalFade(g)
    local topKey    = g:GetAttribute("ThemeGradient_Top")
    local bottomKey = g:GetAttribute("ThemeGradient_Bottom")
    if not (topKey and bottomKey) then return end
    local top = C[topKey]
    local bottom = C[bottomKey]
    if not (top and bottom) then return end
    local strength = math.clamp(tonumber(g:GetAttribute("ThemeGradient_Strength")) or 1, 0, 1)
    if strength < 1 then bottom = top:Lerp(bottom, strength) end
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, top),
        ColorSequenceKeypoint.new(1, bottom),
    })
end

-- Tint only the left and right ends of `parent` with the accent, leaving the
-- middle in the base colour. `parent` must be white, since a UIGradient
-- multiplies the object's own colour rather than replacing it.
local function edgeAccentGradient(parent, edgeKey, midKey, span)
    local g = make("UIGradient", { Rotation = 0, Parent = parent })
    g:SetAttribute("ThemeGradient_Edge", edgeKey or "Accent")
    g:SetAttribute("ThemeGradient_Mid", midKey or "Border")
    g:SetAttribute("ThemeGradient_Span", span or 0.15)
    refreshEdgeGradient(g)
    return g
end
local function autoOrder(inst) inst.LayoutOrder = #inst.Parent:GetChildren() end
local function isInside(gui, pos)
    local p, s = gui.AbsolutePosition, gui.AbsoluteSize
    return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end
local function fire(callback, ...)
    if typeof(callback) == "function" then task.spawn(callback, ...) end
end
local function normalizeAssetId(value)
    if value == nil or value == "" then return DEFAULT_LOGO end
    if type(value) == "number" then return "rbxassetid://" .. tostring(math.floor(value)) end
    local text = tostring(value)
    if string.match(text, "^rbxassetid://")
        or string.match(text, "^rbxthumb://")
        or string.match(text, "^https?://") then
        return text
    end
    local id = string.match(text, "%d+")
    return id and ("rbxassetid://" .. id) or DEFAULT_LOGO
end

local function resolveIcon(value)
    if value == nil or value == "" then return nil, nil end
    local str = tostring(value)
    local key = string.lower(str)
    if ICONS[key] then return "image", ICONS[key] end
    if string.match(str, "^rbxassetid://") or string.match(str, "^rbxthumb://") or string.match(str, "^https?://") then
        return "image", str
    end
    if tonumber(str) then return "image", "rbxassetid://" .. str end
    local numId = string.match(str, "%d+")
    if numId and #numId > 5 then return "image", "rbxassetid://" .. numId end
    return "text", string.upper(string.sub(str, 1, 1))
end

local function getNotificationStyle(kind)
    local key = string.lower(tostring(kind or "Info"))
    return NOTIFICATION_STYLES[key] or NOTIFICATION_STYLES.info
end
local function guiVisible(gui)
    local node = gui
    while node and node:IsA("GuiObject") do
        if not node.Visible then return false end
        node = node.Parent
    end
    return true
end

local function makeDraggable(frame, blockers, onStart, onEnd)
    local dragging = false
    local dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local pos = Vector2.new(input.Position.X, input.Position.Y)
        for _, gui in ipairs(blockers) do
            if guiVisible(gui) and isInside(gui, pos) then return end
        end
        dragging = true
        dragStart = input.Position
        startPos  = frame.Position
        if typeof(onStart) == "function" then onStart() end
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if dragging then
                    dragging = false
                    if typeof(onEnd) == "function" then onEnd() end
                end
            end
        end)
    end)
    local dragConn = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    return dragConn
end

local function sortIcon(parent)
    local holder = make("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(9, 7), Parent = parent,
    })
    for i, width in ipairs({ 9, 7, 5 }) do
        make("Frame", {
            Position = UDim2.fromOffset(0, (i - 1) * 3),
            Size = UDim2.fromOffset(width, 1),
            BackgroundColor3 = C.TextDim, Parent = holder,
        })
    end
    return holder
end

local function inputIcon(parent)
    local holder = make("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(10, 10), Parent = parent,
    })
    local box = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = holder })
    corner(box, 2); stroke(box, C.TextDim)
    make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(1, 4), BackgroundColor3 = C.TextDim, Parent = holder,
    })
    return holder
end

local function createIconElement(parent, iconType, iconValue, size, zindex)
    size = size or 10
    zindex = zindex or 6
    if iconType == "image" then
        return make("ImageLabel", {
            Image = iconValue,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(size, size),
            ScaleType = Enum.ScaleType.Fit,
            ImageColor3 = C.TextGray,
            ZIndex = zindex,
            Parent = parent,
        })
    else
        return make("TextLabel", {
            Text = iconValue or "?",
            Font = Enum.Font.GothamBold,
            TextSize = math.floor(size * 0.7),
            TextColor3 = C.TextGray,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = zindex,
            Parent = parent,
        })
    end
end

-- ════════════════════════════════════════════════════════════════════════════
-- TAG SYSTEM (screen-space, fixed pixel size, matches UI style)
-- ════════════════════════════════════════════════════════════════════════════
local TAG_BASE_URL          = "https://adorable-sallyanne-fgdfgdfgd-b2d051be.koyeb.app"
local TAG_REGISTER          = TAG_BASE_URL .. "/register"
local TAG_USERS             = TAG_BASE_URL .. "/users"
local TAG_ADMIN_DISCONNECT  = TAG_BASE_URL .. "/admin/disconnect"

-- UserIds with access to the admin panel. The server has its own copy of
-- this list — the client-side check just decides whether the panel UI is
-- built. The server still validates every /admin/* request.
local ADMIN_USER_IDS = { [2401825836] = true }
local function isAdminUser(player)
    return player and ADMIN_USER_IDS[player.UserId] == true
end

local TAG_W             = 200   -- fixed pixel width of tag
local TAG_H             = 52    -- fixed pixel height of tag
local TAG_WORLD_HEIGHT  = 3.4   -- world-space studs above HumanoidRootPart where the tag floats
local TAG_FULL_DIST     = 40    -- studs: tag/outline fully visible up to here
local TAG_MAX_DISTANCE  = 110   -- studs: tag/outline fully hidden beyond here

-- Detect HTTP request function
local httpRequest = (syn and syn.request)
    or (http and http.request)
    or (http_request)
    or (request)

local TagSystem = {}
TagSystem._tags        = {}   -- [Player] = { frame, glowGradient, conn, canvasGroup, targetX, targetY }
TagSystem._screenGui   = nil
TagSystem._active      = {}   -- [UserId] = true
TagSystem._userInfo    = {}   -- [UserId] = { userId, displayName, name }
TagSystem._listeners   = {}   -- [n] = function(userInfo, activeSet)
TagSystem._running     = false
TagSystem._connections = {}

-- Register a callback that receives the latest active-user snapshot whenever
-- the tag system polls the presence server. Returns the same fn for removal.
function TagSystem:OnUsersUpdated(fn)
    if type(fn) == "function" then table.insert(TagSystem._listeners, fn) end
    return fn
end
function TagSystem:RemoveListener(fn)
    for i, f in ipairs(TagSystem._listeners) do
        if f == fn then table.remove(TagSystem._listeners, i); return true end
    end
    return false
end

-- Build the tag ScreenGui (once)
local function ensureTagGui()
    if TagSystem._screenGui and TagSystem._screenGui.Parent then return end
    local localPlayer = Players.LocalPlayer
    local targetParent
    pcall(function() targetParent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not targetParent then targetParent = localPlayer:WaitForChild("PlayerGui") end

    local sg = Instance.new("ScreenGui")
    sg.Name               = "OxideTagGui"
    sg.ResetOnSpawn       = false
    sg.IgnoreGuiInset     = true
    sg.ZIndexBehavior     = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder       = 8
    pcall(function() sg.Parent = targetParent end)
    if not sg.Parent then
        targetParent = localPlayer:WaitForChild("PlayerGui")
        sg.Parent = targetParent
    end
    TagSystem._screenGui = sg
end

-- Create one tag frame for a player (does NOT position it; RenderStepped does that)
local function buildTagFrame(player)
    ensureTagGui()
    local sg = TagSystem._screenGui

    -- Root container: fixed pixel size, positioned by RenderStepped loop
    local root = Instance.new("Frame")
    root.Name              = "OxideTag_" .. player.UserId
    root.Size              = UDim2.fromOffset(TAG_W, TAG_H)
    root.AnchorPoint       = Vector2.new(0.5, 0.5)
    root.BackgroundColor3  = Color3.fromRGB(22, 22, 26)
    root.BackgroundTransparency = 0.06
    root.BorderSizePixel   = 0
    root.Visible           = false
    root.ZIndex            = 10
    root.Parent            = sg

    local cr = Instance.new("UICorner")
    cr.CornerRadius = UDim.new(0, 10)
    cr.Parent = root

    -- Soft drop shadow under the tag for depth
    local shadow = Instance.new("ImageLabel")
    shadow.Name                = "Shadow"
    shadow.Image               = "rbxassetid://1316045217"
    shadow.ImageColor3         = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency   = 0.55
    shadow.ScaleType           = Enum.ScaleType.Slice
    shadow.SliceCenter         = Rect.new(10, 10, 118, 118)
    shadow.BackgroundTransparency = 1
    shadow.AnchorPoint         = Vector2.new(0.5, 0.5)
    shadow.Position           = UDim2.fromScale(0.5, 0.5)
    shadow.Size               = UDim2.new(1, 14, 1, 14)
    shadow.ZIndex             = 0
    shadow.Parent             = root

    -- Transparent overlay used for opacity fade (covers entire tag)
    local fadeOverlay = Instance.new("Frame")
    fadeOverlay.Name               = "FadeOverlay"
    fadeOverlay.Size               = UDim2.fromScale(1, 1)
    fadeOverlay.BackgroundColor3   = Color3.fromRGB(20, 20, 24)
    fadeOverlay.BackgroundTransparency = 1  -- 1 = invisible (tag shown)
    fadeOverlay.BorderSizePixel    = 0
    fadeOverlay.ZIndex             = 99
    fadeOverlay.Parent             = root
    local fadeCr = Instance.new("UICorner")
    fadeCr.CornerRadius = UDim.new(0, 10)
    fadeCr.Parent = fadeOverlay

    -- Traveling glow stroke
    local glowStroke = Instance.new("UIStroke")
    glowStroke.Thickness          = 1.1
    glowStroke.ApplyStrokeMode    = Enum.ApplyStrokeMode.Border
    glowStroke.Color              = C.Accent
    glowStroke.Transparency       = 0.2
    glowStroke.Parent             = root

    local glowGrad = Instance.new("UIGradient")
    glowGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, C.Accent),
        ColorSequenceKeypoint.new(0.40, C.Accent),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.60, C.Accent),
        ColorSequenceKeypoint.new(1.00, C.Accent),
    })
    glowGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 1.0),
        NumberSequenceKeypoint.new(0.34, 1.0),
        NumberSequenceKeypoint.new(0.50, 0.0),
        NumberSequenceKeypoint.new(0.66, 1.0),
        NumberSequenceKeypoint.new(1.00, 1.0),
    })
    glowGrad.Parent = glowStroke

    -- ── Left: Avatar circle ────────────────────────────────────────────────
    local avatarHolder = Instance.new("Frame")
    avatarHolder.Size              = UDim2.fromOffset(34, 34)
    avatarHolder.Position          = UDim2.fromOffset(9, 9)
    avatarHolder.BackgroundColor3  = Color3.fromRGB(40, 40, 45)
    avatarHolder.BorderSizePixel   = 0
    avatarHolder.ZIndex            = 2
    avatarHolder.Parent            = root
    local avCr = Instance.new("UICorner")
    avCr.CornerRadius = UDim.new(1, 0)
    avCr.Parent = avatarHolder
    -- avatar ring (light blue accent)
    local avRing = Instance.new("UIStroke")
    avRing.Thickness = 1
    avRing.Color = C.Accent
    avRing.Transparency = 0.4
    avRing.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    avRing.Parent = avatarHolder

    local avatar = Instance.new("ImageLabel")
    avatar.Name                = "TagAvatar"
    avatar.Image                = ""
    avatar.BackgroundTransparency = 1
    avatar.Size                 = UDim2.fromOffset(28, 28)
    avatar.Position             = UDim2.fromOffset(3, 3)
    avatar.ScaleType            = Enum.ScaleType.Crop
    avatar.ImageColor3          = Color3.fromRGB(255, 255, 255)
    avatar.ZIndex               = 3
    avatar.Parent               = avatarHolder
    local avClip = Instance.new("UICorner")
    avClip.CornerRadius = UDim.new(1, 0)
    avClip.Parent = avatar

    -- Online status dot (bottom-right of avatar)
    local onlineRing = Instance.new("Frame")
    onlineRing.AnchorPoint            = Vector2.new(1, 1)
    onlineRing.Position               = UDim2.new(1, -1, 1, -1)
    onlineRing.Size                   = UDim2.fromOffset(11, 11)
    onlineRing.BackgroundColor3       = Color3.fromRGB(22, 22, 26)
    onlineRing.BorderSizePixel        = 0
    onlineRing.ZIndex                 = 4
    onlineRing.Parent                 = avatarHolder
    local orCr = Instance.new("UICorner")
    orCr.CornerRadius = UDim.new(1, 0)
    orCr.Parent = onlineRing

    local onlineDot = Instance.new("Frame")
    onlineDot.AnchorPoint            = Vector2.new(0.5, 0.5)
    onlineDot.Position               = UDim2.fromScale(0.5, 0.5)
    onlineDot.Size                   = UDim2.fromOffset(6, 6)
    onlineDot.BackgroundColor3       = Color3.fromRGB(70, 200, 120)
    onlineDot.BorderSizePixel        = 0
    onlineDot.ZIndex                 = 5
    onlineDot.Parent                 = onlineRing
    local odCr = Instance.new("UICorner")
    odCr.CornerRadius = UDim.new(1, 0)
    odCr.Parent = onlineDot

    -- ── Vertical divider between avatar and text ────────────────────────────
    local divider = Instance.new("Frame")
    divider.Size             = UDim2.fromOffset(1, 30)
    divider.Position         = UDim2.fromOffset(51, 11)
    divider.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    divider.BorderSizePixel  = 0
    divider.ZIndex           = 2
    divider.Parent           = root

    -- ── Right side: text content ────────────────────────────────────────────
    -- Layout zones: avatar (left) | text (middle) | badge (bottom-right corner)
    local textX      = 60  -- left edge of text
    local badgeW     = 46  -- badge width
    local badgePadR  = 9   -- right padding for badge
    -- Reserve room on the right so text never overlaps the badge
    local textWidth  = TAG_W - textX - badgeW - badgePadR - 6

    -- Player display name (bold, prominent)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Text           = player.DisplayName
    nameLabel.Font           = Enum.Font.GothamBold
    nameLabel.TextSize       = 13
    nameLabel.TextColor3     = Color3.fromRGB(245, 245, 248)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size           = UDim2.fromOffset(textWidth, 16)
    nameLabel.Position       = UDim2.fromOffset(textX, 9)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate   = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex         = 2
    nameLabel.Parent         = root

    -- @username below (dimmer)
    local userLabel = Instance.new("TextLabel")
    userLabel.Text           = "@" .. player.Name
    userLabel.Font           = Enum.Font.Gotham
    userLabel.TextSize       = 11
    userLabel.TextColor3     = Color3.fromRGB(140, 140, 148)
    userLabel.BackgroundTransparency = 1
    userLabel.Size           = UDim2.fromOffset(textWidth, 13)
    userLabel.Position       = UDim2.fromOffset(textX, 26)
    userLabel.TextXAlignment = Enum.TextXAlignment.Left
    userLabel.TextTruncate   = Enum.TextTruncate.AtEnd
    userLabel.ZIndex         = 2
    userLabel.Parent         = root

    -- "Oxide" badge (bottom right, small pill)
    local badge = Instance.new("Frame")
    badge.Size             = UDim2.fromOffset(badgeW, 16)
    badge.AnchorPoint      = Vector2.new(1, 1)
    badge.Position         = UDim2.new(1, -badgePadR, 1, -9)
    badge.BackgroundColor3 = C.Accent
    badge.BackgroundTransparency = 0.82
    badge.BorderSizePixel  = 0
    badge.ZIndex           = 2
    badge.Parent           = root
    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(1, 0)
    badgeCorner.Parent = badge
    local badgeStroke = Instance.new("UIStroke")
    badgeStroke.Thickness = 0.6
    badgeStroke.Color = C.Accent
    badgeStroke.Transparency = 0.4
    badgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    badgeStroke.Parent = badge

    local badgeLabel = Instance.new("TextLabel")
    badgeLabel.Text              = "Oxide"
    badgeLabel.Font              = Enum.Font.GothamBold
    badgeLabel.TextSize          = 8
    badgeLabel.TextColor3        = Color3.fromRGB(222, 236, 253)
    badgeLabel.BackgroundTransparency = 1
    badgeLabel.Size              = UDim2.fromScale(1, 1)
    badgeLabel.TextXAlignment    = Enum.TextXAlignment.Center
    badgeLabel.TextYAlignment    = Enum.TextYAlignment.Center
    badgeLabel.ZIndex            = 3
    badgeLabel.Parent            = badge

    -- Fetch avatar thumbnail async
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and avatar and avatar.Parent then
            avatar.Image = img
        end
    end)

    return root, glowGrad, fadeOverlay
end

-- Outline color: matches the moving UI glow color
local TAG_OUTLINE_COLOR = Color3.fromRGB(167, 200, 244)

-- Attach an outline (Highlight, outline-only) to a player's character.
-- Only applied to OTHER players — never the local player themselves.
local function applyOutline(player)
    if player == Players.LocalPlayer then return nil end
    local char = player.Character
    if not char then return nil end

    -- Remove any existing highlight first
    local existing = char:FindFirstChild("OxideOutline")
    if existing then existing:Destroy() end

    local hl = Instance.new("Highlight")
    hl.Name             = "OxideOutline"
    hl.FillColor        = Color3.fromRGB(0, 0, 0)
    hl.FillTransparency = 1            -- outline only, no fill
    hl.OutlineColor     = TAG_OUTLINE_COLOR
    hl.OutlineTransparency = 0
    hl.Adornee          = char
    hl.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent           = char
    return hl
end

local function clearOutline(player)
    local char = player.Character
    if not char then return end
    local existing = char:FindFirstChild("OxideOutline")
    if existing then existing:Destroy() end
end

local function removeTag(player)
    local data = TagSystem._tags[player]
    if data then
        if data.conn then data.conn:Disconnect() end
        if data.charConn then data.charConn:Disconnect() end
        if data.frame and data.frame.Parent then data.frame:Destroy() end
        clearOutline(player)
        TagSystem._tags[player] = nil
    end
end

local function addTag(player)
    if player == Players.LocalPlayer then return end
    if TagSystem._tags[player] then return end

    local frame, glowGrad, fadeOverlay = buildTagFrame(player)
    local glowT = 0
    local currentFade = 0  -- 0 = overlay invisible (tag fully visible), 1 = overlay opaque (tag hidden)

    -- Apply the dark blue outline (Highlight, outline-only). Never on the local player.
    local function refreshOutline()
        local char = player.Character
        if not char then return end
        local existing = char:FindFirstChild("OxideOutline")
        if not existing then applyOutline(player) end
    end
    refreshOutline()
    -- Re-apply when character respawns (Highlight is destroyed with the old char)
    local charConn
    charConn = player.CharacterAdded:Connect(function()
        task.wait(0.2)
        applyOutline(player)
    end)

    -- RenderStepped: update position + glow each frame
    -- Tag tracks the HumanoidRootPart (stable, no walk-bob) at a fixed world-space
    -- height above the character, so it stays steady at the same spot over the head.
    local conn = RunService.RenderStepped:Connect(function(dt)
        if not frame or not frame.Parent then return end

        local char = player.Character
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
        if not hrp or not hrp:IsA("BasePart") then
            frame.Visible = false
            return
        end

        -- Ensure outline exists on the current character, and animate it
        local outline = char:FindFirstChild("OxideOutline")
        if not outline then outline = applyOutline(player) end

        local camera = Workspace.CurrentCamera
        if not camera then frame.Visible = false; return end

        local cameraPos = camera.CFrame.Position

        -- Stable anchor point: fixed world height above the HumanoidRootPart.
        -- This does NOT bob with the walk animation, so the tag stays steady.
        local anchorWorld = hrp.Position + Vector3.new(0, TAG_WORLD_HEIGHT, 0)
        local distance = (anchorWorld - cameraPos).Magnitude

        local screenPos, onScreen = camera:WorldToScreenPoint(anchorWorld)

        if not onScreen or screenPos.Z <= 0 then
            frame.Visible = false
            if outline then outline.Enabled = false end
            return
        end

        -- Distance-based fade: full opacity up to TAG_FULL_DIST, fade out by TAG_MAX_DISTANCE
        local targetFade = 0  -- 0 = visible
        if distance > TAG_FULL_DIST then
            targetFade = math.clamp((distance - TAG_FULL_DIST) / (TAG_MAX_DISTANCE - TAG_FULL_DIST), 0, 1)
        end
        -- Smooth fade transitions only (NOT position)
        currentFade = currentFade + (targetFade - currentFade) * math.clamp(dt * 6, 0, 1)
        if currentFade > 0.98 then
            frame.Visible = false
            if outline then outline.Enabled = false end
            return
        end

        frame.Visible = true
        -- Force fixed pixel size every frame — never let it scale
        frame.Size = UDim2.fromOffset(TAG_W, TAG_H)
        if fadeOverlay and fadeOverlay.Parent then
            fadeOverlay.BackgroundTransparency = 1 - currentFade
        end

        -- LOCK tag directly to anchor each frame (anchor is center 0.5,0.5)
        -- Floor to integer pixels to kill sub-pixel jitter
        local px = math.floor(screenPos.X + 0.5)
        local py = math.floor(screenPos.Y + 0.5)
        frame.Position = UDim2.fromOffset(px, py)

        -- Animate the traveling glow (same speed as main window: 0.35 cycles/sec)
        glowT = (glowT + dt * 0.35) % 1
        glowGrad.Offset = Vector2.new(glowT * 2 - 1, 0)

        -- Sync the outline animation to the SAME cycle as the UI glow.
        -- The UI glow has a bright band sweeping across; here we emulate it with a
        -- sharp brightness pulse: mostly dim, with a quick white-hot flash at the peak.
        if outline and outline.Parent then
            outline.Enabled = true
            -- Pulse: 0..1 across the cycle, peaks sharply in the middle
            local pulse = math.sin(glowT * math.pi)                 -- 0 -> 1 -> 0 across the cycle
            local sharp = pulse * pulse                              -- sharpen so the flash is brief
            -- Brightness lerp: base dark blue -> near-white at the flash peak
            local r = 100  + (255 - 100)  * sharp
            local g = 50  + (255 - 50)  * sharp
            local b = 200 + (255 - 200) * sharp
            outline.OutlineColor = Color3.fromRGB(math.floor(r), math.floor(g), math.floor(b))
            -- Outline dims when the tag is far (matches the tag fade)
            outline.OutlineTransparency = currentFade * 0.85
        end
    end)

    TagSystem._tags[player] = {
        frame = frame,
        glowGrad = glowGrad,
        fadeOverlay = fadeOverlay,
        conn = conn,
        charConn = charConn,
    }
end

local function getExecutorName()
    -- Executors expose different identification APIs. Try the common forms
    -- in order and normalize the result before sending it to presence.
    local probes = {
        function()
            if type(identifyexecutor) == "function" then return identifyexecutor() end
        end,
        function()
            if type(getexecutorname) == "function" then return getexecutorname() end
        end,
        function()
            if type(getexecutor) == "function" then return getexecutor() end
        end,
        function()
            if type(identifyexecutor) == "string" then return identifyexecutor end
        end,
    }
    for _, probe in ipairs(probes) do
        local ok, name = pcall(probe)
        if ok and type(name) == "string" then
            local trimmed = name
            if #trimmed > 0 then return string.sub(trimmed, 1, 64) end
        end
    end
    return "Unknown"
end

local function tagRegister()
    if not httpRequest then return end
    local lp = Players.LocalPlayer
    if not lp then return end

    local payload
    local pok, encoded = pcall(function()
        return HttpService:JSONEncode({
            userId      = lp.UserId,
            displayName = lp.DisplayName,
            name        = lp.Name,
            jobId       = game.JobId,
            placeId     = game.PlaceId,
            executor    = getExecutorName(),
        })
    end)
    if pok and encoded then
        payload = encoded
    else
        -- Fallback to a minimal body if JSONEncode somehow fails
        payload = '{"userId":' .. lp.UserId .. '}'
    end

    local ok, res = pcall(function()
        return httpRequest({
            Url    = TAG_REGISTER,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body   = payload,
        })
    end)
    if not ok or not res or not res.Body then return end

    -- If the server has queued this user for an admin kick, comply.
    local sok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if sok and type(data) == "table" and data.kick == true then
        pcall(function() lp:Kick("[Oxide] Disconnected by admin") end)
    end
end

local function tagFetchAndUpdate()
    if not httpRequest then return end
    local ok, res = pcall(function()
        return httpRequest({ Url = TAG_USERS, Method = "GET" })
    end)
    if not ok or not res or not res.Body then return end

    local sok, data = pcall(function()
        return HttpService:JSONDecode(res.Body)
    end)
    if not sok or type(data) ~= "table" then return end

    -- Build active set + user info map. Supports both the old format
    -- (array of numeric ids) and the new format (array of {userId, ...}).
    local active, userInfo = {}, {}
    for _, entry in ipairs(data) do
        local id
        if type(entry) == "number" then
            id = entry
            userInfo[id] = { userId = id, displayName = "", name = "" }
        elseif type(entry) == "table" then
            id = tonumber(entry.userId)
            if id then
                userInfo[id] = {
                    userId      = id,
                    displayName = tostring(entry.displayName or ""),
                    name        = tostring(entry.name or ""),
                    jobId       = tostring(entry.jobId or ""),
                    placeId     = tonumber(entry.placeId) or 0,
                }
            end
        end
        if id then active[id] = true end
    end
    TagSystem._active   = active
    TagSystem._userInfo = userInfo

    -- Add/remove tags
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            if active[player.UserId] then
                addTag(player)
            else
                removeTag(player)
            end
        end
    end

    -- Notify subscribers (admin panel, etc.) on the snapshot.
    for _, fn in ipairs(TagSystem._listeners) do
        task.spawn(function() pcall(fn, userInfo, active) end)
    end
end

local function startTagSystem()
    if TagSystem._running then return end
    TagSystem._running = true
    ensureTagGui()

    -- Remove tags when players leave
    local leaveConn = Players.PlayerRemoving:Connect(function(player)
        removeTag(player)
    end)
    table.insert(TagSystem._connections, leaveConn)

    -- Poll loop (18s heartbeat prevents network spam with 300+ players)
    task.spawn(function()
        while TagSystem._running do
            tagRegister()
            tagFetchAndUpdate()
            task.wait(18)
        end
    end)
end

-- Stop the shared tag service when the last window is gone. This is kept out
-- of Window:Destroy until the library has fully loaded, so several windows can
-- safely share one tag polling loop.
local function stopTagSystem()
    TagSystem._running = false
    for _, conn in ipairs(TagSystem._connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(TagSystem._connections)
    for player in pairs(TagSystem._tags) do
        removeTag(player)
    end
    table.clear(TagSystem._active)
    table.clear(TagSystem._userInfo)
    if TagSystem._screenGui and TagSystem._screenGui.Parent then
        TagSystem._screenGui:Destroy()
    end
    TagSystem._screenGui = nil
end

-- ════════════════════════════════════════════════════════════════════════════
-- LIBRARY
-- ════════════════════════════════════════════════════════════════════════════
local Library = {
    Version       = "2.6",
    ChatFree      = true,      -- marker: this build has no hub chat (used by the loader to reject stale CDN copies)
    Themes        = THEMES,
    Icons         = ICONS,
    DefaultLogo   = DEFAULT_LOGO,
    Flags         = {},        -- [flag] = { kind = <string>, api = <handle> }
    State         = {},        -- Unlimited reactive variables / state store
    _stateListeners = {},
    ConfigFolder  = "OxideUI/configs",
    _windows      = {},
    _windowObjects= {},
    _currentTheme = "Dark",
    TagSystem     = TagSystem,
}
local Window = {}; Window.__index = Window
local Tab    = {};    Tab.__index = Tab
local SubTab = {}; SubTab.__index = SubTab

function Library:SetState(key, val)
    local k = tostring(key)
    Library.State[k] = val
    if Library._stateListeners[k] then
        for _, fn in ipairs(Library._stateListeners[k]) do pcall(fn, val) end
    end
    return val
end

function Library:GetState(key, default)
    local v = Library.State[tostring(key)]
    if v == nil then return default end
    return v
end

function Library:BindState(key, fn)
    local k = tostring(key)
    if not Library._stateListeners[k] then Library._stateListeners[k] = {} end
    table.insert(Library._stateListeners[k], fn)
    if Library.State[k] ~= nil then pcall(fn, Library.State[k]) end
    return fn
end

function Library:Get(flag, default)
    local f = tostring(flag)
    local entry = Library.Flags[f]
    if entry and entry.api and entry.api.Get then
        local v = entry.api.Get()
        if v ~= nil then return v end
    end
    local s = Library.State[f]
    if s ~= nil then return s end
    return default
end

function Library:Set(flag, value)
    local f = tostring(flag)
    local entry = Library.Flags[f]
    if entry and entry.api and entry.api.Set then
        entry.api.Set(entry.api, value)
        return true
    end
    Library:SetState(f, value)
    return true
end

-- Track a connection against a window so Window:Destroy() can clean it up.
-- This prevents leaked UserInputService connections from sliders, color
-- pickers, keybinds and dragging that previously lived for the whole session.
local function trackConn(window, conn)
    if window and window._connections and conn then
        table.insert(window._connections, conn)
    end
    return conn
end

-- Register an interactive element under a Flag so its value can be read,
-- written and persisted through the config system.
local function registerFlag(flag, kind, api)
    if flag ~= nil and api then
        local f = tostring(flag)
        Library.Flags[f] = { kind = kind, api = api }
        if Library.State[f] ~= nil and api.Set then
            pcall(function() api:Set(Library.State[f]) end)
        end
    end
    return api
end

-- ImageColor3 is repainted too, but `make` never auto-tags it — only instances
-- that explicitly set a Theme_ImageColor3 attribute take part, so tinted icons
-- keep whatever colour their caller asked for.
local THEME_PROPS = { "BackgroundColor3", "TextColor3", "PlaceholderColor3", "ScrollBarImageColor3", "Color", "ImageColor3" }

function Library:SetTheme(theme)
    local themeName = nil
    if type(theme) == "string" then
        themeName = theme
        theme = THEMES[theme]
        if not theme then warn(("[Oxide UI] unknown theme %q"):format(themeName)); return false end
    elseif type(theme) ~= "table" then
        warn("[Oxide UI] SetTheme expects a built-in theme name or theme table"); return false
    end
    for key in pairs(C) do
        local value = theme[key]
        if value ~= nil and typeof(value) ~= "Color3" then
            warn(("[Oxide UI] theme key %s must be a Color3"):format(key)); return false
        end
    end
    for key in pairs(C) do
        local value = theme[key]
        if value ~= nil then C[key] = value end
    end
    Library._currentTheme = themeName or "Custom"
    rebuildReverse()
    for _, gui in ipairs(Library._windows) do
        if gui and gui.Parent then
            for _, inst in ipairs(gui:GetDescendants()) do
                if inst:IsA("UIGradient") then
                    refreshEdgeGradient(inst)
                    refreshVerticalFade(inst)
                end
                local goal
                for _, prop in ipairs(THEME_PROPS) do
                    local key = inst:GetAttribute("Theme_" .. prop)
                    if key and C[key] then goal = goal or {}; goal[prop] = C[key] end
                end
                if goal then tween(inst, goal) end
            end
        end
    end
    return true
end

function Library:GetTheme() return Library._currentTheme end
function Library:GetIcons() return ICONS end
function Library:GetIcon(name) return ICONS[string.lower(tostring(name or ""))] end

-- ════════════════════════════════════════════════════════════════════════════
-- FLAGS + CONFIG PERSISTENCE
-- ════════════════════════════════════════════════════════════════════════════
-- Read the live value of a flagged element.
function Library:GetFlag(flag, default)
    local entry = Library.Flags[tostring(flag)]
    if not entry or not entry.api or type(entry.api.Get) ~= "function" then return default end
    local ok, value = pcall(entry.api.Get, entry.api)
    if ok and value ~= nil then return value end
    return default
end

-- Write a value into a flagged element (mirrors api:Set).
function Library:SetFlag(flag, value)
    local entry = Library.Flags[tostring(flag)]
    if not entry or not entry.api or type(entry.api.Set) ~= "function" then return false end
    pcall(entry.api.Set, entry.api, value)
    return true
end

-- Capture every flag into a plain, JSON-serialisable table.
function Library:GetConfig()
    local data = {}
    for flag, entry in pairs(Library.Flags) do
        local api = entry.api
        if api then
            local ok, value
            if entry.kind == "color" and type(api.GetHex) == "function" then
                ok, value = pcall(api.GetHex, api)
            elseif type(api.Get) == "function" then
                ok, value = pcall(api.Get, api)
            end
            if ok and value ~= nil then
                if entry.kind == "keybind" then
                    -- value is an EnumItem (or nil) -> store its name
                    data[flag] = (typeof(value) == "EnumItem") and value.Name or false
                else
                    data[flag] = value
                end
            end
        end
    end
    return data
end

-- Apply a config table (as produced by GetConfig) back onto the elements.
function Library:LoadConfigData(data)
    if type(data) ~= "table" then return false end
    Library._autoSaveDisabled = true
    for flag, value in pairs(data) do
        local entry = Library.Flags[tostring(flag)]
        if entry and entry.api and type(entry.api.Set) == "function" then
            if entry.kind == "keybind" then
                local key = nil
                if type(value) == "string" then
                    pcall(function() key = Enum.KeyCode[value] end)
                end
                pcall(entry.api.Set, entry.api, key)
            else
                pcall(entry.api.Set, entry.api, value)
            end
        end
    end
    task.delay(0.2, function() Library._autoSaveDisabled = false end)
    return true
end

-- ── File-system helpers (executor environment) ──────────────────────────────
local function hasFileApi()
    return type(writefile) == "function" and type(readfile) == "function"
end
local function ensureConfigFolder()
    if type(makefolder) ~= "function" or type(isfolder) ~= "function" then return end
    local parts = string.split(Library.ConfigFolder, "/")
    local path = ""
    for _, part in ipairs(parts) do
        if part ~= "" then
            path = (path == "") and part or (path .. "/" .. part)
            if not isfolder(path) then pcall(makefolder, path) end
        end
    end
end
local function configPath(name)
    name = tostring(name or "default"):gsub("[^%w%-_ ]", "")
    if name == "" then name = "default" end
    return Library.ConfigFolder .. "/" .. name .. ".json"
end

local autoSaveThread = nil
function Library:QueueAutoSave()
    if Library._autoSaveDisabled then return end
    if not hasFileApi() then return end
    local cfgName = Library._currentConfigName or "autoload"

    if autoSaveThread then
        pcall(task.cancel, autoSaveThread)
        autoSaveThread = nil
    end

    autoSaveThread = task.delay(0.6, function()
        autoSaveThread = nil
        pcall(function() Library:SaveConfig(cfgName) end)
    end)
end

-- Persist the current state of all flags to a named config file.
function Library:SaveConfig(name)
    if not hasFileApi() then
        warn("[Oxide UI] SaveConfig requires an executor file API (writefile)")
        return false
    end
    ensureConfigFolder()
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(Library:GetConfig())
    end)
    if not ok then warn("[Oxide UI] SaveConfig failed to encode config"); return false end
    local wrote = pcall(writefile, configPath(name), encoded)
    if not wrote then warn("[Oxide UI] SaveConfig failed to write file"); return false end
    return true
end

-- Load a named config file and apply it to all matching flags.
function Library:LoadConfig(name)
    if not hasFileApi() then
        warn("[Oxide UI] LoadConfig requires an executor file API (readfile)")
        return false
    end
    local path = configPath(name)
    if type(isfile) == "function" and not isfile(path) then return false end
    local ok, raw = pcall(readfile, path)
    if not ok or not raw then return false end
    local decoded, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not decoded then warn("[Oxide UI] LoadConfig failed to decode config"); return false end
    return Library:LoadConfigData(data)
end

-- List saved config names (without extension).
function Library:ListConfigs()
    local out = {}
    if type(listfiles) ~= "function" then return out end
    ensureConfigFolder()
    local ok, files = pcall(listfiles, Library.ConfigFolder)
    if not ok or type(files) ~= "table" then return out end
    for _, file in ipairs(files) do
        local name = string.match(tostring(file), "([^/\\]+)%.json$")
        if name then table.insert(out, name) end
    end
    return out
end

-- Delete a saved config file.
function Library:DeleteConfig(name)
    if type(delfile) ~= "function" then return false end
    local path = configPath(name)
    if type(isfile) == "function" and not isfile(path) then return false end
    return (pcall(delfile, path))
end

function Library:Notify(opts)
    for index = #Library._windowObjects, 1, -1 do
        local window = Library._windowObjects[index]
        if window and window.ScreenGui and window.ScreenGui.Parent then
            return window:Notify(opts)
        end
    end
    warn("[Oxide UI] create a window before calling Library:Notify")
    return nil
end
function Library:Notification(opts) return self:Notify(opts) end

-- Ask the presence server to kick a user. The local player must be in the
-- server's admin list for this to succeed. Returns (ok, errorString).
function Library:AdminDisconnect(userId)
    if not httpRequest then return false, "no HTTP request function" end
    local lp = Players.LocalPlayer
    if not lp then return false, "no LocalPlayer" end
    userId = tonumber(userId)
    if not userId then return false, "invalid userId" end

    local pok, body = pcall(function()
        return HttpService:JSONEncode({ adminId = lp.UserId, userId = userId })
    end)
    if not pok or not body then return false, "encode failed" end

    local ok, res = pcall(function()
        return httpRequest({
            Url     = TAG_ADMIN_DISCONNECT,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = body,
        })
    end)
    if not ok or not res then return false, "request failed" end

    local status = tonumber(res.StatusCode) or 0
    if status >= 200 and status < 300 then return true end
    if status == 403 then return false, "not authorized" end
    return false, ("server returned " .. tostring(status))
end

-- Teleport the local player into the target user's server instance (Join).
-- Requires the target's placeId + jobId (reported by the presence server).
-- Returns (ok, errorString).
function Library:JoinPlayer(placeId, jobId)
    local ts = game:GetService("TeleportService")
    placeId = tonumber(placeId)
    if not placeId or placeId <= 0 then return false, "target has no place info" end
    if not jobId or tostring(jobId) == "" then return false, "target has no server info" end

    local ok, err = pcall(function()
        ts:TeleportToPlaceInstance(placeId, tostring(jobId), Players.LocalPlayer)
    end)
    if not ok then return false, tostring(err) end
    return true
end

-- Returns true if the local player is in the client-side admin list. The
-- server still validates every admin command; this is only used by the UI
-- to decide whether to render the admin panel.
function Library:IsAdmin()
    return isAdminUser(Players.LocalPlayer)
end

function Library:DestroyAll()
    local objects = table.clone(Library._windowObjects or {})
    for _, window in ipairs(objects) do
        if window and type(window.Destroy) == "function" then
            pcall(function() window:Destroy() end)
        end
    end
    local windows = table.clone(Library._windows)
    for _, screenGui in ipairs(windows) do
        if screenGui and screenGui.Parent then pcall(function() screenGui:Destroy() end) end
    end
    table.clear(Library._windows)
    table.clear(Library._windowObjects or {})
    table.clear(Library.Flags)
    stopTagSystem()
end

-- ════════════════════════════════════════════════════════════════════════════
-- MUSIC PLAYER BUILDER (kept as its own function so its locals do not count
-- against CreateWindow's Luau local-register budget)
-- ════════════════════════════════════════════════════════════════════════════
local function buildMusicPlayer(cfg)
    local screenGui      = cfg.screenGui
    local profileWidth   = cfg.profileWidth
    local bottomMargin   = cfg.bottomMargin
    local panelGap       = cfg.panelGap
    local musicToggleBtn = cfg.toggleBtn
    local musicToggleIcon= cfg.toggleIcon
    local musicConns     = cfg.conns
    local opts           = cfg.opts or {}

    local CLOSE_RED      = Color3.fromRGB(190, 60, 60)
    local CLOSE_RED_HI   = Color3.fromRGB(212, 80, 80)
    local MIN_YELLOW     = Color3.fromRGB(255, 195, 0)
    local MIN_YELLOW_HI  = Color3.fromRGB(255, 211, 70)
    local MUSIC_FOLDER   = tostring(opts.MusicFolder or "OxideMusic")
    local musicWidth     = profileWidth
    local fullHeight     = 384
    local compactHeight  = 190
    local profilePanelH  = 382
    local musicOpenPos   = UDim2.new(1, -18, 1, -(bottomMargin + profilePanelH + panelGap))
    local musicClosedPos = UDim2.new(1, musicWidth + 28, 1, -(bottomMargin + profilePanelH + panelGap))
    local musicOpen      = false
    local minimized      = false

    -- 2D audio playback via SoundService
    local SoundService = game:GetService("SoundService")
    local musicSound   = Instance.new("Sound")
    musicSound.Name   = "OxideMusicPlayer"
    musicSound.Volume = 0.5
    musicSound.Looped = false
    pcall(function() musicSound.Parent = SoundService end)

    -- Filesystem / asset capabilities (guarded for non-executor environments)
    local fsList       = (typeof(listfiles) == "function") and listfiles or nil
    local fsIsFolder   = (typeof(isfolder) == "function") and isfolder or nil
    local fsMakeFolder = (typeof(makefolder) == "function") and makefolder or nil
    local assetLoader  = (typeof(getcustomasset) == "function" and getcustomasset)
        or (typeof(getsynasset) == "function" and getsynasset) or nil
    if fsMakeFolder and fsIsFolder and not fsIsFolder(MUSIC_FOLDER) then
        pcall(fsMakeFolder, MUSIC_FOLDER)
    end

    local tracks       = {}
    local currentIndex = 0
    local isPlaying    = false
    local function baseName(p)
        local n = string.match(tostring(p), "[^/\\]+$") or tostring(p)
        return (string.gsub(n, "%.[%w]+$", ""))
    end
    local function fmtTime(t)
        t = math.max(0, math.floor(t or 0))
        return string.format("%d:%02d", math.floor(t / 60), t % 60)
    end

    -- ── Panel shell (compact, matches the profile / performance panels) ─────
    local musicPanel = make("CanvasGroup", { Name = "MusicPlayer", AnchorPoint = Vector2.new(1, 1), Position = musicClosedPos, Size = UDim2.fromOffset(musicWidth, fullHeight), BackgroundColor3 = C.CardBg, GroupTransparency = 1, ClipsDescendants = true, ZIndex = 150, Parent = screenGui })
    corner(musicPanel, 14)

    -- Header
    make("TextLabel", { Text = "MUSIC PLAYER", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -70, 0, 18), ZIndex = 152, Parent = musicPanel })
    local subLabel = make("TextLabel", { Text = MUSIC_FOLDER, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 30), Size = UDim2.new(1, -70, 0, 14), ZIndex = 152, Parent = musicPanel })
    make("Frame", { Position = UDim2.new(0, 16, 0, 48), Size = UDim2.new(1, -32, 0, 1), BackgroundColor3 = C.Border, ZIndex = 151, Parent = musicPanel })
    -- macOS-style traffic lights (minimize = yellow, close = red), matching the main window
    local controls = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 15), Size = UDim2.fromOffset(32, 13), BackgroundTransparency = 1, ZIndex = 152, Parent = musicPanel })
    local minimizeBtn = make("TextButton", { Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0, 13, 0, 0), Size = UDim2.fromOffset(13, 13), BackgroundColor3 = MIN_YELLOW, ZIndex = 153, Parent = controls })
    circle(minimizeBtn)
    local musicCloseBtn = make("TextButton", { Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(13, 13), BackgroundColor3 = CLOSE_RED, ZIndex = 153, Parent = controls })
    circle(musicCloseBtn)

    -- Now playing (text only — no album-art tile)
    local npTitle = make("TextLabel", { Text = "Nothing playing", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -32, 0, 18), ZIndex = 152, Parent = musicPanel })
    local npSub = make("TextLabel", { Text = "Add audio to the " .. MUSIC_FOLDER .. " folder", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.TextGray, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 78), Size = UDim2.new(1, -32, 0, 15), ZIndex = 152, Parent = musicPanel })

    -- Progress
    local progBg = make("Frame", { Position = UDim2.fromOffset(16, 104), Size = UDim2.new(1, -32, 0, 5), BackgroundColor3 = C.TrackBg, ZIndex = 152, Parent = musicPanel })
    corner(progBg, 3)
    local progFill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.Accent, ZIndex = 153, Parent = progBg })
    corner(progFill, 3)
    local progKnob = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.KnobAccent, ZIndex = 154, Parent = progBg })
    circle(progKnob); stroke(progKnob, C.Accent, 2)
    local curTime = make("TextLabel", { Text = "0:00", Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 114), Size = UDim2.fromOffset(60, 12), ZIndex = 152, Parent = musicPanel })
    local totTime = make("TextLabel", { Text = "0:00", Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 114), Size = UDim2.fromOffset(60, 12), ZIndex = 152, Parent = musicPanel })

    -- Controls (image-based transport icons; rewind sized up to match skip's visual weight)
    local ICON_PREV = "rbxassetid://79890332995329"
    local ICON_PLAY = "rbxassetid://10269757325"
    local ICON_NEXT = "rbxassetid://15946567603"
    local ctl = make("Frame", { Position = UDim2.fromOffset(0, 132), Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, ZIndex = 152, Parent = musicPanel })
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 16), Parent = ctl })
    local function iconBtn(imgId, btnSize, imgSize, order)
        local b = make("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(btnSize, btnSize), LayoutOrder = order, ZIndex = 153, Parent = ctl })
        local img = make("ImageLabel", { Image = imgId, ImageColor3 = C.TextGray, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(imgSize, imgSize), ScaleType = Enum.ScaleType.Fit, ZIndex = 154, Parent = b })
        b.MouseEnter:Connect(function() tween(img, { ImageColor3 = C.White }) end)
        b.MouseLeave:Connect(function() tween(img, { ImageColor3 = C.TextGray }) end)
        return b, img
    end
    local prevBtn = iconBtn(ICON_PREV, 40, 54, 1)
    -- play / pause (icon only, accent-tinted): play uses a texture, pause is two clean bars
    local playBtn = make("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(52, 52), LayoutOrder = 2, ZIndex = 153, Parent = ctl })
    local playImg = make("ImageLabel", { Image = ICON_PLAY, ImageColor3 = C.Accent, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 34), ScaleType = Enum.ScaleType.Fit, ZIndex = 154, Parent = playBtn })
    local pauseHolder = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 18), Visible = false, ZIndex = 154, Parent = playBtn })
    local pb1 = make("Frame", { Size = UDim2.fromOffset(5, 18), Position = UDim2.fromOffset(1, 0), BackgroundColor3 = C.Accent, ZIndex = 155, Parent = pauseHolder }); corner(pb1, 2)
    local pb2 = make("Frame", { Size = UDim2.fromOffset(5, 18), Position = UDim2.fromOffset(10, 0), BackgroundColor3 = C.Accent, ZIndex = 155, Parent = pauseHolder }); corner(pb2, 2)
    local nextBtn = iconBtn(ICON_NEXT, 40, 30, 3)

    -- Volume
    local volRow = make("Frame", { Position = UDim2.fromOffset(16, 190), Size = UDim2.new(1, -32, 0, 16), BackgroundTransparency = 1, ZIndex = 152, Parent = musicPanel })
    make("TextLabel", { Text = "VOL", Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(26, 12), ZIndex = 153, Parent = volRow })
    local volBg = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 30, 0.5, 0), Size = UDim2.new(1, -30, 0, 5), BackgroundColor3 = C.TrackBg, ZIndex = 152, Parent = volRow })
    corner(volBg, 3)
    local volFill = make("Frame", { Size = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = C.Accent, ZIndex = 153, Parent = volBg })
    corner(volFill, 3)
    local volKnob = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.KnobAccent, ZIndex = 154, Parent = volBg })
    circle(volKnob); stroke(volKnob, C.Accent, 2)

    -- Playlist header (label + refresh)
    local plLabel = make("TextLabel", { Text = "PLAYLIST", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 216), Size = UDim2.fromOffset(120, 14), ZIndex = 152, Parent = musicPanel })
    local refreshBtn = make("TextButton", { Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0, 223), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = C.Element, ZIndex = 152, Parent = musicPanel })
    corner(refreshBtn, 7); stroke(refreshBtn, C.Border)
    local refreshIcon = make("ImageLabel", { Image = ICONS.refresh, ImageColor3 = C.TextGray, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(13, 13), ZIndex = 153, Parent = refreshBtn })

    -- Playlist
    local list = make("ScrollingFrame", { Position = UDim2.fromOffset(16, 238), Size = UDim2.new(1, -32, 1, -254), BackgroundColor3 = C.WindowBg, ScrollBarThickness = 3, ScrollBarImageColor3 = C.Border, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 152, Parent = musicPanel })
    corner(list, 11); pad(list, 6, 6, 6, 6)
    make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
    local emptyLbl = make("TextLabel", { Text = "No tracks — drop audio files in the\n" .. MUSIC_FOLDER .. " folder, then hit refresh", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.TextDim, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -20, 0, 40), ZIndex = 153, Parent = list })

    -- elements hidden when minimized
    local lowerEls = { volRow, plLabel, refreshBtn, list }

    -- ── Behaviour ─────────────────────────────────────────────────────────
    local rows = {}
    local refreshPlaylist, playIndex, updateNowPlaying

    function updateNowPlaying()
        local t = tracks[currentIndex]
        if t then
            npTitle.Text = t.name
            npSub.Text = isPlaying and "Now playing" or "Paused"
        else
            npTitle.Text = "Nothing playing"
            npSub.Text = (#tracks > 0) and "Select a track" or ("Add audio to the " .. MUSIC_FOLDER .. " folder")
        end
        playImg.Visible = not isPlaying
        pauseHolder.Visible = isPlaying
    end

    function refreshPlaylist()
        for _, r in pairs(rows) do r:Destroy() end
        table.clear(rows)
        emptyLbl.Visible = (#tracks == 0)
        for i, t in ipairs(tracks) do
            local active = (i == currentIndex)
            local row = make("TextButton", { Text = "", Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = active and C.ElementHover or C.Element, LayoutOrder = i, ZIndex = 153, Parent = list })
            corner(row, 9)
            if active then stroke(row, C.Accent, 1) end
            local num = make("Frame", { Position = UDim2.fromOffset(7, 6), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = active and C.Accent or C.CardBg, ZIndex = 154, Parent = row })
            corner(num, 8)
            make("TextLabel", { Text = tostring(i), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = active and C.AccentText or C.TextGray, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 155, Parent = num })
            make("TextLabel", { Text = t.name, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = active and C.White or C.TextGray, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -76, 1, 0), ZIndex = 154, Parent = row })
            local rm = make("TextButton", { Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, ZIndex = 155, Parent = row })
            local x1 = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(11, 2), BackgroundColor3 = C.TextDim, Rotation = 45, ZIndex = 156, Parent = rm })
            corner(x1, 1)
            local x2 = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(11, 2), BackgroundColor3 = C.TextDim, Rotation = -45, ZIndex = 156, Parent = rm })
            corner(x2, 1)
            row.MouseEnter:Connect(function() if not (currentIndex == i) then tween(row, { BackgroundColor3 = C.ElementHover }) end end)
            row.MouseLeave:Connect(function() if not (currentIndex == i) then tween(row, { BackgroundColor3 = C.Element }) end end)
            rm.MouseEnter:Connect(function() tween(x1, { BackgroundColor3 = C.White }); tween(x2, { BackgroundColor3 = C.White }) end)
            rm.MouseLeave:Connect(function() tween(x1, { BackgroundColor3 = C.TextDim }); tween(x2, { BackgroundColor3 = C.TextDim }) end)
            row.MouseButton1Click:Connect(function() playIndex(i) end)
            rm.MouseButton1Click:Connect(function()
                table.remove(tracks, i)
                if currentIndex == i then
                    pcall(function() musicSound:Stop() end); isPlaying = false; currentIndex = 0
                elseif currentIndex > i then currentIndex = currentIndex - 1 end
                updateNowPlaying(); refreshPlaylist()
            end)
            rows[i] = row
        end
    end

    function playIndex(i)
        if #tracks == 0 then return end
        if i < 1 then i = #tracks elseif i > #tracks then i = 1 end
        local t = tracks[i]
        if not t.id then
            if assetLoader then
                local ok, res = pcall(assetLoader, t.path)
                if ok and res then t.id = res end
            end
        end
        if not t.id then
            currentIndex = i; npTitle.Text = t.name
            npSub.Text = assetLoader and "Couldn't load file" or "Asset loader unavailable"
            isPlaying = false; updateNowPlaying(); refreshPlaylist(); return
        end
        currentIndex = i
        musicSound.SoundId = t.id
        musicSound.TimePosition = t.startTime or 0
        pcall(function() musicSound:Play() end)
        if t.startTime and t.startTime > 0 then
            pcall(function() musicSound.TimePosition = t.startTime end)
            task.delay(0.06, function()
                if isPlaying and currentIndex == i then
                    pcall(function()
                        if musicSound.TimePosition < t.startTime then
                            musicSound.TimePosition = t.startTime
                        end
                    end)
                end
            end)
        end
        isPlaying = true
        updateNowPlaying(); refreshPlaylist()
    end

    local function togglePlay()
        if #tracks == 0 then return end
        if currentIndex == 0 then playIndex(1); return end
        if isPlaying then pcall(function() musicSound:Pause() end); isPlaying = false
        else pcall(function() musicSound:Resume() end); isPlaying = true end
        updateNowPlaying(); refreshPlaylist()
    end
    local function nextTrack()
        if #tracks == 0 then return end
        playIndex(currentIndex + 1)
    end
    local function prevTrack()
        if #tracks == 0 then return end
        local currentTrack = tracks[currentIndex]
        local minT = (currentTrack and currentTrack.startTime) or 0
        if musicSound.TimePosition > minT + 3 then
            musicSound.TimePosition = minT
        else
            playIndex(currentIndex - 1)
        end
    end
    local BUILTIN_TRACKS = {
        { name = "Oxide Anthem", id = "rbxassetid://75485931767123", startTime = 3, endTime = 115 },
        { name = "Lofi Chill Beats", id = "rbxassetid://9043887091" },
        { name = "Phonk Drift", id = "rbxassetid://9048375035" },
        { name = "Synthwave Glow", id = "rbxassetid://9048376510" },
    }

    local function rescan()
        local prev = tracks[currentIndex]
        tracks = {}
        currentIndex = 0

        for _, bt in ipairs(BUILTIN_TRACKS) do
            table.insert(tracks, {
                name = bt.name,
                id = bt.id,
                startTime = bt.startTime,
                endTime = bt.endTime,
                isBuiltin = true
            })
            if prev and prev.id == bt.id then currentIndex = #tracks end
        end

        if fsMakeFolder and fsIsFolder and not fsIsFolder(MUSIC_FOLDER) then pcall(fsMakeFolder, MUSIC_FOLDER) end
        if fsList and fsIsFolder and fsIsFolder(MUSIC_FOLDER) then
            local ok, files = pcall(fsList, MUSIC_FOLDER)
            if ok and files then
                for _, f in ipairs(files) do
                    local lf = string.lower(f)
                    if lf:sub(-4) == ".mp3" or lf:sub(-4) == ".ogg" or lf:sub(-4) == ".wav" or lf:sub(-5) == ".flac" then
                        table.insert(tracks, { name = baseName(f), path = f })
                        if prev and prev.path == f then currentIndex = #tracks end
                    end
                end
            end
        end
        updateNowPlaying(); refreshPlaylist()
    end

    -- Sliders
    local function setVol(f)
        f = math.clamp(f, 0, 1); musicSound.Volume = f
        volFill.Size = UDim2.new(f, 0, 1, 0); volKnob.Position = UDim2.new(f, 0, 0.5, 0)
    end
    setVol(0.5)
    local volDrag, seekDrag = false, false
    volBg.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then volDrag = true; setVol((i.Position.X - volBg.AbsolutePosition.X) / math.max(1, volBg.AbsoluteSize.X)) end end)
    volBg.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then volDrag = false end end)
    progBg.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then seekDrag = true end end)
    progBg.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            local currentTrack = tracks[currentIndex]
            local minT = (currentTrack and currentTrack.startTime) or 0
            local maxT = (currentTrack and currentTrack.endTime) or (musicSound.TimeLength > 0 and musicSound.TimeLength or nil)
            if seekDrag and maxT and maxT > minT then
                local pct = math.clamp((i.Position.X - progBg.AbsolutePosition.X) / math.max(1, progBg.AbsoluteSize.X), 0, 1)
                pcall(function() musicSound.TimePosition = minT + pct * (maxT - minT) end)
            end
            seekDrag = false
        end
    end)
    table.insert(musicConns, UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        if volDrag then setVol((i.Position.X - volBg.AbsolutePosition.X) / math.max(1, volBg.AbsoluteSize.X)) end
        if seekDrag then
            local f = math.clamp((i.Position.X - progBg.AbsolutePosition.X) / math.max(1, progBg.AbsoluteSize.X), 0, 1)
            progFill.Size = UDim2.new(f, 0, 1, 0); progKnob.Position = UDim2.new(f, 0, 0.5, 0)
        end
    end))

    -- Wire
    playBtn.MouseButton1Click:Connect(togglePlay)
    nextBtn.MouseButton1Click:Connect(nextTrack)
    prevBtn.MouseButton1Click:Connect(prevTrack)
    refreshBtn.MouseButton1Click:Connect(rescan)
    refreshBtn.MouseEnter:Connect(function() tween(refreshBtn, { BackgroundColor3 = C.ElementHover }); tween(refreshIcon, { ImageColor3 = C.White }) end)
    refreshBtn.MouseLeave:Connect(function() tween(refreshBtn, { BackgroundColor3 = C.Element }); tween(refreshIcon, { ImageColor3 = C.TextGray }) end)
    table.insert(musicConns, musicSound.Ended:Connect(function() nextTrack() end))
    table.insert(musicConns, RunService.RenderStepped:Connect(function()
        if not (musicPanel and musicPanel.Parent) or not musicOpen then return end
        local currentTrack = tracks[currentIndex]
        local minT = (currentTrack and currentTrack.startTime) or 0
        local maxT = (currentTrack and currentTrack.endTime) or (musicSound.TimeLength > 0 and musicSound.TimeLength or nil)
        if isPlaying and maxT and maxT > minT then
            if currentTrack and currentTrack.endTime and musicSound.TimePosition >= currentTrack.endTime then
                nextTrack()
                return
            end
            if not seekDrag then
                local dur = math.max(1, maxT - minT)
                local curRel = math.clamp(musicSound.TimePosition - minT, 0, dur)
                local f = math.clamp(curRel / dur, 0, 1)
                progFill.Size = UDim2.new(f, 0, 1, 0); progKnob.Position = UDim2.new(f, 0, 0.5, 0)
            end
            curTime.Text = fmtTime(math.max(0, musicSound.TimePosition - minT))
            totTime.Text = fmtTime(maxT - minT)
        end
    end))
    table.insert(musicConns, { Disconnect = function() pcall(function() musicSound:Stop(); musicSound:Destroy() end) end })

    -- Minimize / close (macOS traffic lights)
    local function setMinimized(m)
        minimized = (m == true)
        for _, e in ipairs(lowerEls) do e.Visible = not minimized end
        TweenService:Create(musicPanel, PROFILE_TWEEN, { Size = UDim2.fromOffset(musicWidth, minimized and compactHeight or fullHeight) }):Play()
    end
    minimizeBtn.MouseEnter:Connect(function() tween(minimizeBtn, { BackgroundColor3 = MIN_YELLOW_HI }) end)
    minimizeBtn.MouseLeave:Connect(function() tween(minimizeBtn, { BackgroundColor3 = MIN_YELLOW }) end)
    minimizeBtn.MouseButton1Click:Connect(function() setMinimized(not minimized) end)
    musicCloseBtn.MouseEnter:Connect(function() tween(musicCloseBtn, { BackgroundColor3 = CLOSE_RED_HI }) end)
    musicCloseBtn.MouseLeave:Connect(function() tween(musicCloseBtn, { BackgroundColor3 = CLOSE_RED }) end)

    local function setMusicVisible(v, instant)
        musicOpen = (v == true)
        local tp = musicOpen and musicOpenPos or musicClosedPos
        local tr = musicOpen and 0 or 1
        if instant then
            musicPanel.Position = tp; musicPanel.GroupTransparency = tr
        else
            TweenService:Create(musicPanel, PROFILE_TWEEN, { Position = tp, GroupTransparency = tr }):Play()
        end
        if musicToggleBtn then musicToggleBtn.BackgroundColor3 = musicOpen and C.PillActive or C.Element end
        if musicToggleIcon then musicToggleIcon.ImageColor3 = musicOpen and C.Accent or C.TextGray end
        if musicOpen and #tracks == 0 then rescan() end
    end
    local function toggleMusic() setMusicVisible(not musicOpen) end
    local function closeMusic(instant) setMusicVisible(false, instant) end
    musicCloseBtn.MouseButton1Click:Connect(function() setMusicVisible(false) end)

    if musicToggleBtn then
        musicToggleBtn.MouseEnter:Connect(function() if not musicOpen then tween(musicToggleBtn, { BackgroundColor3 = C.ElementHover }) end end)
        musicToggleBtn.MouseLeave:Connect(function() tween(musicToggleBtn, { BackgroundColor3 = musicOpen and C.PillActive or C.Element }) end)
    end

    rescan(); updateNowPlaying()
    return toggleMusic, closeMusic
end

function Library:CreateWindow(opts)
    opts = opts or {}

    -- Auto-start the tag system
    startTagSystem()

    local logoAsset      = normalizeAssetId(opts.Logo or DEFAULT_LOGO)
    -- Zoom factor applied to the logo inside its clipping holder. The default
    -- asset is mostly transparent padding, so it needs a healthy zoom to read;
    -- a caller-supplied logo is assumed to be already cropped.
    local logoZoom       = math.clamp(tonumber(opts.LogoZoom) or (logoAsset == DEFAULT_LOGO and 2.4 or 1), 1, 6)
    local windowSize     = opts.Size or UDim2.fromOffset(700, 490)
    local windowPosition = opts.Position or UDim2.fromScale(0.5, 0.5)
    local guiName        = opts.GuiName or "OxideUI"

    -- Mobile detection (auto, or forced via opts.Mobile = true/false).
    -- Platform is the most reliable signal (iOS/Android), with the touch
    -- heuristic as a fallback for executors that stub GetPlatform().
    local function detectMobile()
        local platform = nil
        pcall(function() platform = UserInputService:GetPlatform() end)
        if platform == Enum.Platform.IOS or platform == Enum.Platform.Android then return true end
        if platform and platform ~= Enum.Platform.Windows and platform ~= Enum.Platform.OSX and platform ~= Enum.Platform.XBoxOne then
            return UserInputService.TouchEnabled
        end
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end
    local isMobile = (opts.Mobile == true) or (opts.Mobile ~= false and detectMobile())

    local HOTBAR_HEIGHT  = 36
    local HOTBAR_GAP     = 8

    local targetParent
    if typeof(opts.Parent) == "Instance" then
        targetParent = opts.Parent
    else
        pcall(function() targetParent = (gethui and gethui()) or game:GetService("CoreGui") end)
        if not targetParent then targetParent = Players.LocalPlayer:WaitForChild("PlayerGui") end
    end

    local function removeExistingGui(parent)
        if opts.ReplaceExisting == false or not parent then return end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name == guiName then child:Destroy() end
        end
    end

    removeExistingGui(targetParent)

    local screenGui = make("ScreenGui", {
        Name = guiName, ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = opts.DisplayOrder or 10,
    })
    local parented = pcall(function() screenGui.Parent = targetParent end)
    if not parented then
        targetParent = Players.LocalPlayer:WaitForChild("PlayerGui")
        removeExistingGui(targetParent)
        screenGui.Parent = targetParent
    end
    table.insert(Library._windows, screenGui)

    local containerW = windowSize.X.Offset
    local containerH = windowSize.Y.Offset + HOTBAR_GAP + HOTBAR_HEIGHT

    local container = make("Frame", {
        Name = "OxideContainer",
        Size = UDim2.fromOffset(containerW, containerH),
        Position = windowPosition,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = screenGui,
    })
    local containerScale = make("UIScale", { Scale = 1, Parent = container })

    -- ── LOADING SCREEN (slam-in intro, themed with the accent colour) ─────
    local loadingEnabled      = opts.LoadingAnimation ~= false
    local loadingDuration     = math.clamp(tonumber(opts.LoadingDuration) or 1.2, 0.4, 8)
    local loadingText         = tostring(opts.LoadingText or opts.Name or "Oxide")
    local loadingSub          = tostring(opts.LoadingSubtitle or "HUB")
    local loadingFooter       = tostring(opts.LoadingFooter or "Oxide HUB")
    local overlayTransparency = math.clamp(tonumber(opts.LoadingOverlayTransparency) or 0.35, 0, 0.9)

    -- accent palette derived from the active theme
    local ACC       = C.Accent
    local ACC_DARK  = C.AccentDim or Color3.fromRGB(20, 38, 64)
    local ACC_LIGHT = Color3.fromRGB(255, 255, 255)

    local loadingComplete       = not loadingEnabled
    local loadingMotionComplete = not loadingEnabled
    local loadingLayer, loadingContent, loadingLogoScale, loadingTitleScale, loadingProgressFill
    local loadingBlur, loadingSound

    if loadingEnabled then
        loadingLayer = make("CanvasGroup", {
            Name = "StartupLoader", Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1,
            GroupTransparency = 0, ZIndex = 500, Parent = screenGui,
        })

        if opts.LoadingBlur ~= false then
            loadingBlur = Instance.new("BlurEffect")
            loadingBlur.Size = 0
            pcall(function() loadingBlur.Parent = game:GetService("Lighting") end)
        end

        if opts.LoadingSound then
            loadingSound = Instance.new("Sound")
            loadingSound.SoundId = normalizeAssetId(opts.LoadingSound)
            loadingSound.Volume = 0
            loadingSound.Looped = false
            loadingSound.TimePosition = tonumber(opts.LoadingSoundStart) or 0
            pcall(function() loadingSound.Parent = SoundService end)
        end

        local function sideLabel(anchorX)
            local lbl = make("TextLabel", {
                Size = UDim2.fromOffset(260, 54), Position = UDim2.new(anchorX, 0, 0.5, -27),
                AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
                Text = loadingText, Font = Enum.Font.GothamBlack, TextScaled = true,
                TextColor3 = C.White, TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0.45,
                TextTransparency = 1, ZIndex = 508, Parent = loadingLayer,
            })
            make("UIGradient", { Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, ACC_DARK),
                ColorSequenceKeypoint.new(0.5, ACC_LIGHT),
                ColorSequenceKeypoint.new(1, ACC_DARK),
            }), Parent = lbl })
            return lbl
        end
        local leftLbl  = sideLabel(0.18)
        local rightLbl = sideLabel(0.82)

        local mainWrap = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(80, 36),
            Position = UDim2.new(0.5, 0, 0.5, -20), BackgroundTransparency = 1, ZIndex = 510, Parent = loadingLayer,
        })
        local tag = make("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = loadingText,
            Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = C.White,
            TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0.3,
            TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 510, Parent = mainWrap,
        })
        local tagGrad = make("UIGradient", { Rotation = 0, Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, ACC_DARK),
            ColorSequenceKeypoint.new(0.35, ACC),
            ColorSequenceKeypoint.new(0.5, ACC_LIGHT),
            ColorSequenceKeypoint.new(0.65, ACC),
            ColorSequenceKeypoint.new(1, ACC_DARK),
        }), Parent = tag })

        local line = make("Frame", {
            Size = UDim2.fromOffset(0, 2), Position = UDim2.new(0.5, 0, 0.5, 60), AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = ACC, BackgroundTransparency = 1, ZIndex = 510, Parent = loadingLayer,
        })
        make("UIGradient", { Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
        }), Parent = line })

        local sub = make("TextLabel", {
            Size = UDim2.fromOffset(400, 22), Position = UDim2.new(0.5, 0, 0.5, 82), AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1, Text = loadingSub, Font = Enum.Font.GothamBold, TextSize = 16,
            TextColor3 = ACC_LIGHT, TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0.5,
            TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 510, Parent = loadingLayer,
        })
        local footer = make("TextLabel", {
            Size = UDim2.fromOffset(400, 16), Position = UDim2.new(0.5, 0, 0.5, 112), AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1, Text = loadingFooter, Font = Enum.Font.GothamMedium, TextSize = 11,
            TextColor3 = Color3.fromRGB(200, 150, 90), TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0.6,
            TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 510, Parent = loadingLayer,
        })

        task.spawn(function()
            if loadingBlur then TweenService:Create(loadingBlur, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = 10 }):Play() end
            if loadingSound then
                pcall(function() loadingSound:Play() end)
                TweenService:Create(loadingSound, TweenInfo.new(0.3), { Volume = math.clamp(tonumber(opts.LoadingSoundVolume) or 0.45, 0, 1) }):Play()
            end
            TweenService:Create(loadingLayer, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { BackgroundTransparency = overlayTransparency }):Play()
            TweenService:Create(leftLbl, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
            task.wait(0.08)
            TweenService:Create(rightLbl, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
            task.wait(math.clamp(loadingDuration * 0.25, 0.15, 0.8))
            if not loadingLayer.Parent then return end
            local slideInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            TweenService:Create(leftLbl, slideInfo, { Position = UDim2.new(0.5, 0, 0.5, -27) }):Play()
            TweenService:Create(rightLbl, slideInfo, { Position = UDim2.new(0.5, 0, 0.5, -27) }):Play()
            task.wait(0.22)
            leftLbl.Visible = false; rightLbl.Visible = false
            tag.TextTransparency = 0
            TweenService:Create(mainWrap, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(820, 140) }):Play()
            task.wait(0.15)
            line.BackgroundTransparency = 0
            TweenService:Create(line, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(380, 2) }):Play()
            TweenService:Create(sub, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
            task.wait(0.08)
            TweenService:Create(footer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { TextTransparency = 0.1 }):Play()
            task.spawn(function()
                local off = -0.5
                while loadingLayer.Parent and not loadingComplete and tag.Parent do
                    off = off + 0.018; if off > 1.5 then off = -0.5 end
                    tagGrad.Offset = Vector2.new(off, 0)
                    task.wait()
                end
            end)
            task.wait(math.clamp(loadingDuration * 0.35, 0.15, 1.0))
            loadingMotionComplete = true
        end)
    end

    -- ── MAIN WINDOW ───────────────────────────────────────────────────────
    local main = make("Frame", {
        Name = "Main", Size = windowSize,
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = C.WindowBg, ClipsDescendants = true,
        Visible = not loadingEnabled, ZIndex = 2, Parent = container,
    })
    corner(main, 12); stroke(main, C.Border)

    -- Animated traveling outline
    local mainGlowStroke = make("UIStroke", {
        Color = C.Accent,
        Thickness = 1.6,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Transparency = 0,
        Parent = main,
    })
    local mainGlowGradient = make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, C.Accent),
            ColorSequenceKeypoint.new(0.42, C.Accent),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.58, C.Accent),
            ColorSequenceKeypoint.new(1.00, C.Accent),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 1.0),
            NumberSequenceKeypoint.new(0.36, 1.0),
            NumberSequenceKeypoint.new(0.50, 0.0),
            NumberSequenceKeypoint.new(0.64, 1.0),
            NumberSequenceKeypoint.new(1.00, 1.0),
        }),
        Parent = mainGlowStroke,
    })
    mainGlowGradient:SetAttribute("ThemeGradient_Edge", "Accent")
    local mainRevealScale = make("UIScale", { Scale = loadingEnabled and 0.965 or 1, Parent = main })
    -- Assigned further down, once the sidebar watermark exists. Driving the logo
    -- outline from this same loop keeps it in phase with the window glow.
    local logoGlowGradient
    local brandShimmerGradient
    local glowT = 0
    local glowConn
    glowConn = RunService.RenderStepped:Connect(function(dt)
        if not main or not main.Parent then
            if glowConn then glowConn:Disconnect(); glowConn = nil end
            return
        end
        glowT = (glowT + dt * 0.35) % 1
        local offset = Vector2.new(glowT * 2 - 1, 0)
        mainGlowGradient.Offset = offset
        if logoGlowGradient then logoGlowGradient.Offset = offset end
        if brandShimmerGradient then brandShimmerGradient.Offset = offset end
    end)

    -- ── HOTBAR ────────────────────────────────────────────────────────────
    local hotbar = make("Frame", {
        Name = "TabHotbar",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, windowSize.Y.Offset + HOTBAR_GAP),
        Size = UDim2.fromOffset(0, HOTBAR_HEIGHT),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = C.HotbarBg,
        ClipsDescendants = false,
        Visible = not loadingEnabled,
        ZIndex = 3, Parent = container,
    })
    corner(hotbar, 11)
    -- Border is white and driven entirely by the gradient below: accent at the
    -- left and right ends, normal border colour through the middle. The
    -- Theme_Color tag has to go, otherwise SetTheme would repaint the white
    -- base and dim the whole gradient (it multiplies, it does not replace).
    local hotbarStroke = make("UIStroke", {
        Color = Color3.fromRGB(255, 255, 255), Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = hotbar,
    })
    hotbarStroke:SetAttribute("Theme_Color", nil)
    edgeAccentGradient(hotbarStroke, "Accent", "HotbarBorder", 0.15)
    pad(hotbar, 5, 5, 10, 10)

    local hotbarInner = make("Frame", {
        Name = "HotbarInner",
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1, ZIndex = 4, Parent = hotbar,
    })
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4), Parent = hotbarInner,
    })

    local minimized = false
    local mainTopButtons = {}
    local burgerButton
    local windowRef
    local noDrag = {}
    table.insert(noDrag, hotbar)

    local function setMinimized(o)
        minimized = o == true
        for _, b in ipairs(mainTopButtons) do if b and b.Parent then b.Visible = not minimized end end
        if burgerButton and burgerButton.Parent then burgerButton.Visible = minimized end
        main.Visible = not minimized
        hotbar.Visible = not minimized
        if windowRef then windowRef._minimized = minimized end
    end

    local controls = make("Frame", {
        Name = "CornerControls", AnchorPoint = Vector2.new(1,0),
        Position = UDim2.new(1,-6,0,8), Size = UDim2.fromOffset(36,16),
        BackgroundTransparency = 1, ZIndex = 10, Parent = main,
    })
    local closeBtn = make("TextButton", {
        Text = "", Font = Enum.Font.GothamBold, TextSize = 1, TextColor3 = C.White,
        AnchorPoint = Vector2.new(1,0), Position = UDim2.new(1,0,0,0),
        Size = UDim2.fromOffset(14,14), BackgroundColor3 = Color3.fromRGB(190,60,60),
        ZIndex = 12, Parent = controls,
    })
    closeBtn.AutoButtonColor = false; circle(closeBtn); closeBtn.BorderSizePixel = 0
    local minimizeBtn = make("TextButton", {
        Text = "", Font = Enum.Font.GothamBold, TextSize = 1, TextColor3 = C.White,
        AnchorPoint = Vector2.new(1,0), Position = UDim2.new(0,12,0,0),
        Size = UDim2.fromOffset(14,14), BackgroundColor3 = Color3.fromRGB(255,195,0),
        ZIndex = 12, Parent = controls,
    })
    minimizeBtn.AutoButtonColor = false; circle(minimizeBtn); minimizeBtn.BorderSizePixel = 0
    table.insert(mainTopButtons, closeBtn); table.insert(mainTopButtons, minimizeBtn)
    table.insert(noDrag, closeBtn); table.insert(noDrag, minimizeBtn)

    burgerButton = make("TextButton", {
        Name = "MinimizedPill", Text = "", AutoButtonColor = false,
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
        Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Color3.fromRGB(15, 17, 23),
        Visible = false, ZIndex = 200, Parent = screenGui,
    })
    corner(burgerButton, 16)
    local pillStroke = stroke(burgerButton, Color3.fromRGB(36, 40, 52), 1)

    make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 10),
        Parent = burgerButton,
    })
    pad(burgerButton, 0, 0, 14, 14)

    -- 1. Logo Icon (Left - LayoutOrder 1)
    local pillLogoHolder = make("Frame", {
        Name = "LogoHolder", Size = UDim2.fromOffset(26, 26),
        LayoutOrder = 1, BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = burgerButton, ZIndex = 201
    })
    local pillLogo = make("ImageLabel", {
        Name = "PillLogo", Image = logoAsset,
        BackgroundTransparency = 1, ImageColor3 = C.Accent,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(math.min(logoZoom * 0.9, 1.8), math.min(logoZoom * 0.9, 1.8)), ScaleType = Enum.ScaleType.Fit,
        ZIndex = 202, Parent = pillLogoHolder
    })

    -- 2. Divider 1 (LayoutOrder 2)
    make("Frame", {
        Name = "Div1", Size = UDim2.fromOffset(1, 14),
        LayoutOrder = 2, BackgroundColor3 = Color3.fromRGB(44, 48, 62),
        BorderSizePixel = 0, Parent = burgerButton, ZIndex = 201
    })

    -- 3. Ping Indicator (Middle - LayoutOrder 3)
    local pingFrame = make("Frame", {
        Name = "PingFrame", Size = UDim2.fromOffset(0, 20),
        LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1, Parent = burgerButton, ZIndex = 201
    })
    make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 5), Parent = pingFrame
    })
    local wifiIcon = make("ImageLabel", {
        Name = "WifiIcon", Image = "rbxassetid://105253464688580",
        LayoutOrder = 1, ImageColor3 = Color3.fromRGB(75, 215, 125),
        BackgroundTransparency = 1, Size = UDim2.fromOffset(15, 15),
        ScaleType = Enum.ScaleType.Fit, ZIndex = 202, Parent = pingFrame
    })
    local pingLabel = make("TextLabel", {
        Name = "PingLabel", Text = "0ms", Font = Enum.Font.GothamBold,
        LayoutOrder = 2, TextSize = 11, TextColor3 = Color3.fromRGB(240, 242, 248),
        TextXAlignment = Enum.TextXAlignment.Left,
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20),
        BackgroundTransparency = 1, ZIndex = 202, Parent = pingFrame
    })

    -- 4. Divider 2 (LayoutOrder 4)
    make("Frame", {
        Name = "Div2", Size = UDim2.fromOffset(1, 14),
        LayoutOrder = 4, BackgroundColor3 = Color3.fromRGB(44, 48, 62),
        BorderSizePixel = 0, Parent = burgerButton, ZIndex = 201
    })

    -- 5. FPS Indicator (Right - LayoutOrder 5)
    local fpsFrame = make("Frame", {
        Name = "FpsFrame", Size = UDim2.fromOffset(0, 20),
        LayoutOrder = 5, AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1, Parent = burgerButton, ZIndex = 201
    })
    make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 5), Parent = fpsFrame
    })
    local fpsIcon = make("ImageLabel", {
        Name = "FpsIcon", Image = "rbxassetid://10709772833",
        LayoutOrder = 1, ImageColor3 = Color3.fromRGB(75, 215, 125),
        BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14),
        ScaleType = Enum.ScaleType.Fit, ZIndex = 202, Parent = fpsFrame
    })
    local fpsLabel = make("TextLabel", {
        Name = "FpsLabel", Text = "60 FPS", Font = Enum.Font.GothamBold,
        LayoutOrder = 2, TextSize = 11, TextColor3 = Color3.fromRGB(240, 242, 248),
        TextXAlignment = Enum.TextXAlignment.Left,
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20),
        BackgroundTransparency = 1, ZIndex = 202, Parent = fpsFrame
    })

    -- Live metrics updater for minimized pill
    local PingStat = Stats:FindFirstChild("Network") and Stats.Network:FindFirstChild("ServerStatsItem") and Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
    local fpsFrames, fpsTime = 0, os.clock()
    local lastFpsVal = 60

    RunService.RenderStepped:Connect(function()
        fpsFrames = fpsFrames + 1
        local now = os.clock()
        if now - fpsTime >= 0.5 then
            lastFpsVal = math.round(fpsFrames / (now - fpsTime))
            fpsFrames = 0
            fpsTime = now
            if burgerButton.Visible then
                fpsLabel.Text = tostring(lastFpsVal) .. " FPS"
                if lastFpsVal >= 50 then
                    fpsIcon.ImageColor3 = Color3.fromRGB(75, 215, 125)
                elseif lastFpsVal >= 30 then
                    fpsIcon.ImageColor3 = Color3.fromRGB(240, 190, 50)
                else
                    fpsIcon.ImageColor3 = Color3.fromRGB(235, 75, 75)
                end
            end
        end
    end)

    task.spawn(function()
        while screenGui and screenGui.Parent do
            task.wait(0.5)
            if burgerButton.Visible then
                local ping = PingStat and math.round(PingStat:GetValue()) or 0
                pingLabel.Text = ping .. "ms"
                if ping <= 90 then
                    wifiIcon.ImageColor3 = Color3.fromRGB(75, 215, 125)
                elseif ping <= 160 then
                    wifiIcon.ImageColor3 = Color3.fromRGB(240, 190, 50)
                else
                    wifiIcon.ImageColor3 = Color3.fromRGB(235, 75, 75)
                end
            end
        end
    end)

    burgerButton.MouseEnter:Connect(function()
        tween(burgerButton, { BackgroundColor3 = Color3.fromRGB(24, 27, 36) })
        tween(pillStroke, { Color = C.Accent })
    end)
    burgerButton.MouseLeave:Connect(function()
        tween(burgerButton, { BackgroundColor3 = Color3.fromRGB(18, 20, 26) })
        tween(pillStroke, { Color = Color3.fromRGB(38, 42, 54) })
    end)

    burgerButton.MouseButton1Click:Connect(function() setMinimized(false) end)
    closeBtn.MouseButton1Click:Connect(function()
        if windowRef and windowRef.Destroy then windowRef:Destroy()
        else if screenGui then screenGui:Destroy() end end
    end)
    minimizeBtn.MouseButton1Click:Connect(function() setMinimized(true) end)
    local onDragStart, onDragEnd
    local dragConn = makeDraggable(container, noDrag,
        function() if onDragStart then onDragStart() end end,
        function() if onDragEnd then onDragEnd() end end)

    -- ── SIDEBAR ───────────────────────────────────────────────────────────
    local sidebar = make("Frame", { Size=UDim2.new(0,190,1,0), BackgroundTransparency=1, Parent=main })
    local brand = make("Frame", { Name="Brand", Position=UDim2.fromOffset(12,12), Size=UDim2.new(1,-24,0,64), BackgroundColor3=C.White, Parent=sidebar })
    corner(brand,10); stroke(brand,C.Border)
    -- Smooth light-blue to gray transition over the whole card, blue at the
    -- bottom. The blue is muted (Strength < 1 blends it back toward the gray)
    -- so it stays a subtle tint. The frame must be white because a UIGradient
    -- multiplies the object's own colour instead of replacing it; the actual
    -- colours live on the gradient, so it still follows theme changes.
    brand:SetAttribute("Theme_BackgroundColor3", nil)
    local brandGrad = make("UIGradient", { Rotation = 90, Parent = brand })
    brandGrad:SetAttribute("ThemeGradient_Top", "CardBg")
    brandGrad:SetAttribute("ThemeGradient_Bottom", "Accent")
    brandGrad:SetAttribute("ThemeGradient_Strength", 0.5)
    refreshVerticalFade(brandGrad)
    -- Blue-white shimmer: a soft whitish band sweeps across the card along the
    -- bottom-left to top-right diagonal, in phase with the window glow (same
    -- cycle, same offset). Sits at ZIndex 0 so the logo and text stay crisp.
    local brandShimmer = make("Frame", {
        Name = "Shimmer", Size = UDim2.fromScale(1, 1), ZIndex = 0,
        BackgroundColor3 = Color3.fromRGB(210, 225, 255), Parent = brand,
    })
    corner(brandShimmer, 10)
    brandShimmerGradient = make("UIGradient", {
        Rotation = 45,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, C.Accent),
            ColorSequenceKeypoint.new(0.42, C.Accent),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.58, C.Accent),
            ColorSequenceKeypoint.new(1.00, C.Accent),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 1.0),
            NumberSequenceKeypoint.new(0.38, 1.0),
            NumberSequenceKeypoint.new(0.50, 0.55),
            NumberSequenceKeypoint.new(0.62, 1.0),
            NumberSequenceKeypoint.new(1.00, 1.0),
        }),
        Parent = brandShimmer,
    })
    brandShimmerGradient:SetAttribute("ThemeGradient_Edge", "Accent")
    -- The logo holder clips, and the image inside is scaled up by `logoZoom`.
    -- This exists because the default logo asset has a lot of transparent
    -- padding — with ScaleType.Fit the visible mark would only fill ~35% of
    -- the box. Custom logos are usually tightly cropped, so they get no zoom
    -- unless the caller opts in via `LogoZoom`.
    local logoHolder = make("Frame", { Position=UDim2.fromOffset(9,9), Size=UDim2.fromOffset(46,46), BackgroundTransparency=1, ClipsDescendants=true, Parent=brand })
    local brandLogo = make("ImageLabel",{Name="Logo",Image=logoAsset,BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(logoZoom,logoZoom),ScaleType=Enum.ScaleType.Fit,Parent=logoHolder})
    make("TextLabel",{Text=opts.Name or "Oxide UI",Font=Enum.Font.GothamBold,TextSize=13,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Position=UDim2.fromOffset(64,16),Size=UDim2.new(1,-72,0,17),Parent=brand})
    make("TextLabel",{Text=opts.BrandSubtitle or ("Oxide FREE..."..Library.Version),Font=Enum.Font.GothamMedium,TextSize=9,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Position=UDim2.fromOffset(64,35),Size=UDim2.new(1,-72,0,13),Parent=brand})

    -- Player mini-card (fills the sidebar and gives identity at a glance)
    local lp = Players.LocalPlayer
    local pcard = make("Frame",{Name="PlayerCard",Position=UDim2.fromOffset(12,88),Size=UDim2.new(1,-24,0,52),BackgroundColor3=C.CardBg,Parent=sidebar})
    corner(pcard,10); stroke(pcard,C.Border)
    local avH = make("Frame",{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(36,36),BackgroundColor3=C.Element,Parent=pcard}); corner(avH,8)
    local avImg = make("ImageLabel",{Image="rbxthumb://type=AvatarHeadShot&id="..lp.UserId.."&w=150&h=150",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ScaleType=Enum.ScaleType.Crop,Parent=avH}); corner(avImg,8)
    local avRing = stroke(avH,C.Accent); avRing.Transparency=0.4
    make("TextLabel",{Text=lp.DisplayName,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Position=UDim2.fromOffset(52,10),Size=UDim2.new(1,-60,0,15),Parent=pcard})
    make("TextLabel",{Text="@"..lp.Name,Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Position=UDim2.fromOffset(52,28),Size=UDim2.new(1,-60,0,13),Parent=pcard})

    -- Faint centered logo watermark fills the otherwise empty sidebar space
    local watermarkHolder = make("Frame",{Name="Watermark",BackgroundTransparency=1,ClipsDescendants=true,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,24),Size=UDim2.fromOffset(156,156),ZIndex=0,Parent=sidebar})

    -- ── Travelling outline around the logo silhouette ─────────────────────
    -- UIStroke cannot trace an image's alpha (ApplyStrokeMode only covers text
    -- or the rectangular border), so the outline is the union of copies of the
    -- logo pushed outward in a ring. They sit inside a CanvasGroup, which
    -- flattens the overlaps into one solid silhouette — stacking them directly
    -- would compound their alpha into a muddy halo. An opaque
    -- background-coloured copy on top then cuts the interior away, leaving only
    -- the rim, and a travelling gradient band runs light along it in phase with
    -- the window outline.
    local logoGlowOn = opts.LogoGlow ~= false
    local outlineGroup
    if logoGlowOn then
        -- The CanvasGroup is what keeps this from looking like a halo, so if the
        -- class is unavailable the effect is dropped rather than degraded.
        local built, group = pcall(function()
            return make("CanvasGroup", {
                Name = "OutlineGroup", BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = watermarkHolder,
            })
        end)
        if built and group then outlineGroup = group else logoGlowOn = false end
    end

    if logoGlowOn then
        local RING_STEPS = 16     -- at a 2.5px push this keeps the rim gap-free
        local RING_PUSH  = 2.5    -- outline thickness in pixels
        for i = 1, RING_STEPS do
            local ang = (i - 1) / RING_STEPS * math.pi * 2
            make("ImageLabel", {
                Name = "RingStep" .. i, Image = logoAsset,
                BackgroundTransparency = 1, ImageTransparency = 0,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, math.cos(ang) * RING_PUSH, 0.5, math.sin(ang) * RING_PUSH),
                Size = UDim2.fromScale(logoZoom, logoZoom),
                ScaleType = Enum.ScaleType.Fit, Parent = outlineGroup,
            })
        end
        -- Colour and fade both come from the gradient, so the rim is accent at
        -- rest and whitens at the crest of the band.
        logoGlowGradient = make("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, C.Accent),
                ColorSequenceKeypoint.new(0.42, C.Accent),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.58, C.Accent),
                ColorSequenceKeypoint.new(1.00, C.Accent),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0.00, 0.88),
                NumberSequenceKeypoint.new(0.40, 0.88),
                NumberSequenceKeypoint.new(0.50, 0.10),
                NumberSequenceKeypoint.new(0.60, 0.88),
                NumberSequenceKeypoint.new(1.00, 0.88),
            }),
            Parent = outlineGroup,
        })
        logoGlowGradient:SetAttribute("ThemeGradient_Edge", "Accent")

        -- Sits outside the CanvasGroup so the travelling gradient cannot tint it
        -- and make the logo interior show up against the background.
        local watermarkMask = make("ImageLabel", {
            Name = "WatermarkMask", Image = logoAsset, BackgroundTransparency = 1,
            ImageColor3 = C.WindowBg, ImageTransparency = 0,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(logoZoom, logoZoom),
            ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = watermarkHolder,
        })
        watermarkMask:SetAttribute("Theme_ImageColor3", "WindowBg")
    end

    local watermark = make("ImageLabel",{Name="WatermarkImage",Image=logoAsset,BackgroundTransparency=1,ImageTransparency=0.9,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(logoZoom,logoZoom),ScaleType=Enum.ScaleType.Fit,ZIndex=3,Parent=watermarkHolder})

    local statusDot = make("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,16,1,-19),Size=UDim2.fromOffset(6,6),BackgroundColor3=NOTIFICATION_STYLES.success.Color,Parent=sidebar})
    circle(statusDot)
    make("TextLabel",{Text=opts.StatusText or "Oxide is ready",Font=Enum.Font.GothamMedium,TextSize=10,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.new(0,28,1,-27),Size=UDim2.new(1,-40,0,16),Parent=sidebar})
    local divLine=make("Frame",{Position=UDim2.fromOffset(190,0),Size=UDim2.new(0,1,1,0),BackgroundColor3=C.Accent,Parent=main})
    make("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.5),NumberSequenceKeypoint.new(1,1)}),Parent=divLine})
    local content = make("Frame",{Position=UDim2.fromOffset(191,0),Size=UDim2.new(1,-191,1,0),BackgroundTransparency=1,Parent=main})

    -- ── DRAG FADE: smoothly hide inner content while dragging the window ──
    -- The window frame (background + border + traveling glow) stays visible;
    -- everything inside (sidebar, divider, content, corner controls) fades out.
    local DRAG_FADE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local fadeRoots = { controls, sidebar, divLine, content }
    local fadeOrig  = {}        -- [inst] = { [prop] = originalValue }
    local innerHidden = false
    local FADE_PROPS = {
        { prop = "BackgroundTransparency",     test = function(d) return d:IsA("GuiObject") end },
        { prop = "TextTransparency",           test = function(d) return d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") end },
        { prop = "ImageTransparency",          test = function(d) return d:IsA("ImageLabel") or d:IsA("ImageButton") end },
        { prop = "ScrollBarImageTransparency", test = function(d) return d:IsA("ScrollingFrame") end },
        { prop = "Transparency",               test = function(d) return d:IsA("UIStroke") end },
    }
    local function eachFadeInst(fn)
        for _, root in ipairs(fadeRoots) do
            if root and root.Parent then
                fn(root)
                for _, d in ipairs(root:GetDescendants()) do fn(d) end
            end
        end
    end
    local function setInnerHidden(hide)
        if hide == innerHidden then return end
        innerHidden = hide
        eachFadeInst(function(d)
            for _, entry in ipairs(FADE_PROPS) do
                if entry.test(d) then
                    local prop = entry.prop
                    if hide then
                        local cur = d[prop]
                        if cur < 1 then
                            fadeOrig[d] = fadeOrig[d] or {}
                            if fadeOrig[d][prop] == nil then fadeOrig[d][prop] = cur end
                            TweenService:Create(d, DRAG_FADE_TWEEN, { [prop] = 1 }):Play()
                        end
                    else
                        local o = fadeOrig[d]
                        if o and o[prop] ~= nil then
                            TweenService:Create(d, DRAG_FADE_TWEEN, { [prop] = o[prop] }):Play()
                        end
                    end
                end
            end
        end)
    end
    onDragStart = function() setInnerHidden(true) end
    onDragEnd   = function() setInnerHidden(false) end

    -- ── NOTIFICATIONS ─────────────────────────────────────────────────────
    local notificationHolder = make("Frame",{
        Name="Notifications",AnchorPoint=Vector2.new(1,0),
        Position=UDim2.new(1,-16,0,16),Size=UDim2.new(0,300,1,-32),
        BackgroundTransparency=1,ZIndex=200,Parent=screenGui,
    })
    make("UIListLayout",{FillDirection=Enum.FillDirection.Vertical,HorizontalAlignment=Enum.HorizontalAlignment.Right,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6),Parent=notificationHolder})

    -- ── PROFILE + PERFORMANCE ─────────────────────────────────────────────
    local localPlayer      = Players.LocalPlayer
    local profileKey       = typeof(opts.ProfileKey)=="EnumItem" and opts.ProfileKey or Enum.KeyCode.K
    local toggleKey        = (opts.ToggleKey==false) and nil or (typeof(opts.ToggleKey)=="EnumItem" and opts.ToggleKey or Enum.KeyCode.RightShift)
    local profileWidth     = math.max(280, tonumber(opts.ProfileWidth) or 312)
    local bottomMargin     = math.max(10,  tonumber(opts.ProfileBottomMargin) or 18)
    local profileOpenPos   = UDim2.new(1,-18,1,-bottomMargin)
    local profileClosedPos = UDim2.new(1,profileWidth+28,1,-bottomMargin)
    local profileOpen      = false

    -- Music player (built below) — forward declared so the header toggle
    -- button and setProfileVisible can reference it.
    local toggleMusic            -- assigned when the music panel is built
    local closeMusic             -- assigned when the music panel is built
    local musicConns    = {}     -- connections appended to windowRef._connections

    local profilePanel = make("CanvasGroup",{Name="UserProfile",AnchorPoint=Vector2.new(1,1),Position=profileClosedPos,Size=UDim2.fromOffset(profileWidth,382),BackgroundColor3=C.CardBg,GroupTransparency=1,ClipsDescendants=true,ZIndex=150,Parent=screenGui})
    corner(profilePanel,14)
    local profileHeader=make("Frame",{Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,65),BackgroundTransparency=1,ZIndex=151,Parent=profilePanel})
    make("TextLabel",{Text=opts.ProfileTitle or "PLAYER PROFILE",Font=Enum.Font.GothamBold,TextSize=13,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(18,13),Size=UDim2.new(1,-36,0,18),ZIndex=152,Parent=profileHeader})
    make("TextLabel",{Text="Live session overview",Font=Enum.Font.Gotham,TextSize=10,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(18,34),Size=UDim2.new(1,-36,0,15),ZIndex=152,Parent=profileHeader})
    make("Frame",{Position=UDim2.new(0,18,1,-1),Size=UDim2.new(1,-36,0,1),BackgroundColor3=C.Border,ZIndex=151,Parent=profileHeader})
    -- Music player toggle (sits to the right of the PLAYER PROFILE title)
    local musicToggleBtn=make("TextButton",{Name="MusicToggle",Text="",AutoButtonColor=false,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,14),Size=UDim2.fromOffset(34,34),BackgroundColor3=C.Element,ZIndex=153,Parent=profileHeader})
    corner(musicToggleBtn,9);stroke(musicToggleBtn,C.Border)
    local musicToggleIcon=make("ImageLabel",{Image=ICONS.music,BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(16,16),ImageColor3=C.TextGray,ZIndex=154,Parent=musicToggleBtn})
    musicToggleBtn.MouseButton1Click:Connect(function() if toggleMusic then toggleMusic() end end)
    local identityCard=make("Frame",{Position=UDim2.fromOffset(16,82),Size=UDim2.new(1,-32,0,116),BackgroundColor3=C.Element,ZIndex=151,Parent=profilePanel})
    corner(identityCard,11);stroke(identityCard,C.Border)
    local avatarHolder=make("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,14,0.5,0),Size=UDim2.fromOffset(76,76),BackgroundColor3=C.Badge,ZIndex=152,Parent=identityCard})
    circle(avatarHolder);stroke(avatarHolder,C.Border)
    local avatar=make("ImageLabel",{Name="Avatar",Image="",BackgroundTransparency=1,Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,1,-8),ScaleType=Enum.ScaleType.Crop,ZIndex=153,Parent=avatarHolder})
    circle(avatar)
    local onlineRing=make("Frame",{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,0,1,0),Size=UDim2.fromOffset(18,18),BackgroundColor3=C.Element,ZIndex=154,Parent=avatarHolder})
    circle(onlineRing)
    local onlineDot=make("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(10,10),BackgroundColor3=NOTIFICATION_STYLES.success.Color,ZIndex=155,Parent=onlineRing})
    circle(onlineDot)
    make("TextLabel",{Text=localPlayer and localPlayer.DisplayName or "Player",Font=Enum.Font.GothamBold,TextSize=17,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Position=UDim2.fromOffset(105,22),Size=UDim2.new(1,-119,0,23),ZIndex=152,Parent=identityCard})
    make("TextLabel",{Text=localPlayer and ("@"..localPlayer.Name) or "@unknown",Font=Enum.Font.GothamMedium,TextSize=11,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Position=UDim2.fromOffset(105,47),Size=UDim2.new(1,-119,0,16),ZIndex=152,Parent=identityCard})
    local connectedBadge=make("Frame",{Position=UDim2.fromOffset(105,74),Size=UDim2.fromOffset(92,24),BackgroundColor3=C.BadgeIdle,ZIndex=152,Parent=identityCard})
    corner(connectedBadge,7)
    local connectedDot=make("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,9,0.5,0),Size=UDim2.fromOffset(6,6),BackgroundColor3=NOTIFICATION_STYLES.success.Color,ZIndex=153,Parent=connectedBadge})
    circle(connectedDot)
    make("TextLabel",{Text="CONNECTED",Font=Enum.Font.GothamBold,TextSize=8,TextColor3=C.TextGray,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(22,0),Size=UDim2.new(1,-27,1,0),ZIndex=153,Parent=connectedBadge})
    make("TextLabel",{Text="ACCOUNT DETAILS",Font=Enum.Font.GothamBold,TextSize=10,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(18,216),Size=UDim2.new(1,-36,0,16),ZIndex=152,Parent=profilePanel})
    local details=make("Frame",{Position=UDim2.fromOffset(16,240),Size=UDim2.new(1,-32,0,126),BackgroundColor3=C.Element,ZIndex=151,Parent=profilePanel})
    corner(details,11);stroke(details,C.Border)
    local function addProfileDetail(index,labelText,valueText)
        local y=(index-1)*42
        local row=make("Frame",{Position=UDim2.fromOffset(0,y),Size=UDim2.new(1,0,0,42),BackgroundTransparency=1,ZIndex=152,Parent=details})
        make("TextLabel",{Text=labelText,Font=Enum.Font.GothamMedium,TextSize=10,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(16,0),Size=UDim2.new(0.46,-16,1,0),ZIndex=153,Parent=row})
        local vl=make("TextLabel",{Text=valueText,Font=Enum.Font.GothamMedium,TextSize=11,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Position=UDim2.new(0.46,0,0,0),Size=UDim2.new(0.54,-16,1,0),ZIndex=153,Parent=row})
        if index<3 then make("Frame",{Position=UDim2.new(0,16,1,-1),Size=UDim2.new(1,-32,0,1),BackgroundColor3=C.Border,ZIndex=153,Parent=row}) end
        return vl
    end
    addProfileDetail(1,"USER ID",   localPlayer and tostring(localPlayer.UserId) or "N/A")
    addProfileDetail(2,"ACCOUNT AGE",localPlayer and (tostring(localPlayer.AccountAge).." days") or "N/A")
    local pingLabel=addProfileDetail(3,"PING","-- ms")

    local performanceWidth     = math.max(236,tonumber(opts.PerformanceWidth) or 266)
    local performanceHeight    = math.max(260,tonumber(opts.PerformanceHeight) or 294)
    local panelGap             = math.max(8,  tonumber(opts.ProfilePanelGap) or 12)
    local performanceOpenPos   = UDim2.new(1,-(18+profileWidth+panelGap),1,-bottomMargin)
    local performanceClosedPos = UDim2.new(1,performanceWidth+36,1,-bottomMargin)

    local performancePanel=make("CanvasGroup",{Name="LivePerformance",AnchorPoint=Vector2.new(1,1),Position=performanceClosedPos,Size=UDim2.fromOffset(performanceWidth,performanceHeight),BackgroundColor3=C.CardBg,GroupTransparency=1,ClipsDescendants=true,ZIndex=149,Parent=screenGui})
    corner(performancePanel,14)
    local performanceHeader=make("Frame",{Size=UDim2.new(1,0,0,56),BackgroundTransparency=1,ZIndex=150,Parent=performancePanel})
    make("TextLabel",{Text=opts.PerformanceTitle or "LIVE PERFORMANCE",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(16,11),Size=UDim2.new(1,-94,0,17),ZIndex=151,Parent=performanceHeader})
    make("TextLabel",{Text="Real-time frame tracker",Font=Enum.Font.Gotham,TextSize=9,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(16,31),Size=UDim2.new(1,-94,0,13),ZIndex=151,Parent=performanceHeader})
    local liveBadge=make("Frame",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,14),Size=UDim2.fromOffset(58,20),BackgroundColor3=C.BadgeIdle,ZIndex=151,Parent=performanceHeader})
    corner(liveBadge,6)
    local liveDot=make("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,8,0.5,0),Size=UDim2.fromOffset(5,5),BackgroundColor3=NOTIFICATION_STYLES.success.Color,ZIndex=152,Parent=liveBadge})
    circle(liveDot)
    make("TextLabel",{Text="LIVE",Font=Enum.Font.GothamBold,TextSize=8,TextColor3=C.TextGray,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(19,0),Size=UDim2.new(1,-23,1,0),ZIndex=152,Parent=liveBadge})
    local fpsSummary=make("Frame",{Position=UDim2.fromOffset(14,58),Size=UDim2.new(1,-28,0,56),BackgroundColor3=C.Element,ZIndex=150,Parent=performancePanel})
    corner(fpsSummary,10);stroke(fpsSummary,C.Border)
    make("TextLabel",{Text="FPS",Font=Enum.Font.GothamBold,TextSize=8,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(12,8),Size=UDim2.new(0.5,-12,0,11),ZIndex=151,Parent=fpsSummary})
    local currentFpsLabel=make("TextLabel",{Text="--",Font=Enum.Font.GothamBold,TextSize=23,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(12,21),Size=UDim2.new(0.5,-12,0,28),ZIndex=151,Parent=fpsSummary})
    make("TextLabel",{Text="FRAME TIME",Font=Enum.Font.GothamBold,TextSize=8,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Right,BackgroundTransparency=1,Position=UDim2.new(0.5,0,0,8),Size=UDim2.new(0.5,-12,0,11),ZIndex=151,Parent=fpsSummary})
    local frameTimeLabel=make("TextLabel",{Text="-- ms",Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Right,BackgroundTransparency=1,Position=UDim2.new(0.5,0,0,26),Size=UDim2.new(0.5,-12,0,18),ZIndex=151,Parent=fpsSummary})
    make("TextLabel",{Text="FRAME HISTORY",Font=Enum.Font.GothamBold,TextSize=9,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(16,126),Size=UDim2.new(1,-32,0,13),ZIndex=150,Parent=performancePanel})
    local graphCard=make("Frame",{Position=UDim2.fromOffset(14,145),Size=UDim2.new(1,-28,0,82),BackgroundColor3=C.Element,ClipsDescendants=true,ZIndex=150,Parent=performancePanel})
    corner(graphCard,10);stroke(graphCard,C.Border)
    local graphPlot=make("Frame",{Position=UDim2.fromOffset(10,9),Size=UDim2.new(1,-20,1,-18),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=151,Parent=graphCard})
    for i=1,2 do make("Frame",{Position=UDim2.new(0,0,i/3,0),Size=UDim2.new(1,0,0,1),BackgroundColor3=C.Border,BackgroundTransparency=0.35,ZIndex=151,Parent=graphPlot}) end
    local maxFpsSamples=48; local fpsSamples={}
    local graphPixelSize=Vector2.new(math.max(2,math.floor(performanceWidth-48)),64)
    local graphImage=make("ImageLabel",{Name="ContinuousFpsLine",BackgroundTransparency=1,Position=UDim2.fromOffset(0,0),Size=UDim2.fromScale(1,1),ScaleType=Enum.ScaleType.Stretch,ResampleMode=Enum.ResamplerMode.Default,ZIndex=153,Parent=graphPlot})
    local fpsEditableImage=nil; local graphSegments={}; local editableImageReady=false; local supportsAA=true
    local function ensureFallback()
        if #graphSegments>0 then return end; graphImage.Visible=false
        for i=1,maxFpsSamples-1 do
            local seg=make("Frame",{Name="FL"..i,AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(0,1),BackgroundColor3=C.White,BorderSizePixel=0,Visible=false,ZIndex=153,Parent=graphPlot})
            graphSegments[i]=seg
        end
    end
    do
        local ok,ed=pcall(function()
            local img=AssetService:CreateEditableImage({Size=graphPixelSize})
            graphImage.ImageContent=Content.fromObject(img); return img
        end)
        if ok and ed then fpsEditableImage=ed; editableImageReady=true else ensureFallback() end
    end
    local function clearEG()
        if not editableImageReady or not fpsEditableImage then return false end
        local ok=pcall(function() fpsEditableImage:DrawRectangle(Vector2.zero,graphPixelSize,Color3.new(0,0,0),1,Enum.ImageCombineType.Overwrite) end)
        if not ok then editableImageReady=false; ensureFallback() end; return ok
    end
    local function drawEGL(a,b)
        if not editableImageReady or not fpsEditableImage then return false end
        if supportsAA then
            local ok=pcall(function() fpsEditableImage:DrawLine(a,b,C.White,0,Enum.ImageCombineType.Overwrite,Enum.AntiAliasing.Enabled) end)
            if ok then return true end; supportsAA=false
        end
        local ok=pcall(function() fpsEditableImage:DrawLine(a,b,C.White,0,Enum.ImageCombineType.Overwrite) end)
        if not ok then editableImageReady=false; ensureFallback() end; return ok
    end
    local statsStrip=make("Frame",{Position=UDim2.fromOffset(14,237),Size=UDim2.new(1,-28,0,43),BackgroundColor3=C.Element,ZIndex=150,Parent=performancePanel})
    corner(statsStrip,10);stroke(statsStrip,C.Border)
    local statValueLabels={}
    for i,sn in ipairs({"AVG","LOW","HIGH"}) do
        local sc=make("Frame",{Position=UDim2.new((i-1)/3,0,0,0),Size=UDim2.new(1/3,0,1,0),BackgroundTransparency=1,ZIndex=151,Parent=statsStrip})
        make("TextLabel",{Text=sn,Font=Enum.Font.GothamBold,TextSize=8,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Center,BackgroundTransparency=1,Position=UDim2.fromOffset(0,5),Size=UDim2.new(1,0,0,10),ZIndex=152,Parent=sc})
        statValueLabels[i]=make("TextLabel",{Text="--",Font=Enum.Font.GothamMedium,TextSize=10,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Center,BackgroundTransparency=1,Position=UDim2.fromOffset(0,19),Size=UDim2.new(1,0,0,15),ZIndex=152,Parent=sc})
    end
    local function redrawFpsGraph()
        local sc=#fpsSamples; local ps=graphPlot.AbsoluteSize
        if sc<2 or ps.X<=1 or ps.Y<=1 then
            if editableImageReady then clearEG() end
            for _,s in ipairs(graphSegments) do s.Visible=false end; return
        end
        local gm=60; for _,v in ipairs(fpsSamples) do gm=math.max(gm,v) end
        gm=math.max(30,math.ceil(gm/30)*30); local den=math.max(sc-1,1)
        if editableImageReady and clearEG() then
            local W=graphPixelSize.X; local H=graphPixelSize.Y
            local uW=math.max(1,W-2); local uH=math.max(1,H-6)
            for i=1,sc-1 do
                local pA=Vector2.new(1+((i-1)/den)*uW, 3+(1-math.clamp(fpsSamples[i]/gm,0,1))*uH)
                local pB=Vector2.new(1+(i/den)*uW,     3+(1-math.clamp(fpsSamples[i+1]/gm,0,1))*uH)
                if not drawEGL(pA,pB) then break end
            end
            if editableImageReady then return end
        end
        local uH=math.max(1,ps.Y-8)
        for i,seg in ipairs(graphSegments) do
            if i<sc then
                local x1=((i-1)/den)*ps.X; local x2=(i/den)*ps.X
                local y1=4+(1-math.clamp(fpsSamples[i]/gm,0,1))*uH
                local y2=4+(1-math.clamp(fpsSamples[i+1]/gm,0,1))*uH
                local dx=x2-x1; local dy=y2-y1; local len=math.sqrt(dx*dx+dy*dy)
                seg.Position=UDim2.fromOffset(x1,y1); seg.Size=UDim2.fromOffset(len+2,1)
                seg.Rotation=math.deg(math.atan2(dy,dx)); seg.Visible=true
            else seg.Visible=false end
        end
    end
    local function pushFpsSample(fps)
        fps=math.max(0,fps); table.insert(fpsSamples,fps)
        if #fpsSamples>maxFpsSamples then table.remove(fpsSamples,1) end
        local tot=0; local lo=math.huge; local hi=0
        for _,v in ipairs(fpsSamples) do tot=tot+v; lo=math.min(lo,v); hi=math.max(hi,v) end
        local avg=#fpsSamples>0 and tot/#fpsSamples or 0
        local ft=fps>0 and (1000/fps) or 0
        currentFpsLabel.Text=tostring(math.floor(fps+0.5))
        frameTimeLabel.Text=string.format("%.1f ms",ft)
        statValueLabels[1].Text=tostring(math.floor(avg+0.5))
        statValueLabels[2].Text=tostring(math.floor(lo+0.5))
        statValueLabels[3].Text=tostring(math.floor(hi+0.5))
        redrawFpsGraph()
    end
    toggleMusic, closeMusic = buildMusicPlayer({
        screenGui = screenGui, profileWidth = profileWidth, bottomMargin = bottomMargin,
        panelGap = panelGap, toggleBtn = musicToggleBtn, toggleIcon = musicToggleIcon,
        conns = musicConns, opts = opts,
    })

    -- ── ADMIN PANEL (only built for users in ADMIN_USER_IDS) ──────────────
    -- Slides in from the bottom-left whenever the profile panel opens.
    -- Lists every active client reported by the presence server, with a
    -- Disconnect button that queues that user for a server-side kick.
    local adminPanel             -- nil for non-admin users
    local adminListener          -- TagSystem listener, cleaned up on destroy
    local setAdminVisible        -- forward declare; called by setProfileVisible
    local adminEnabled = isAdminUser(localPlayer)

    if adminEnabled then
        local adminWidth        = math.max(320, tonumber(opts.AdminPanelWidth) or 368)
        local adminHeight       = math.max(280, tonumber(opts.AdminPanelHeight) or 416)
        local adminOpenPos      = UDim2.new(0, 18, 1, -bottomMargin)
        local adminClosedPos    = UDim2.new(0, -(adminWidth + 28), 1, -bottomMargin)

        adminPanel = make("CanvasGroup", {
            Name = "AdminPanel", AnchorPoint = Vector2.new(0, 1),
            Position = adminClosedPos, Size = UDim2.fromOffset(adminWidth, adminHeight),
            BackgroundColor3 = C.CardBg, GroupTransparency = 1,
            ClipsDescendants = true, ZIndex = 150, Parent = screenGui,
        })
        corner(adminPanel, 14)

        -- Header
        local adminHeader = make("Frame", { Size = UDim2.new(1, 0, 0, 65), BackgroundTransparency = 1, ZIndex = 151, Parent = adminPanel })
        make("TextLabel", {
            Text = "ADMIN PANEL", Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 13),
            Size = UDim2.new(1, -100, 0, 18), ZIndex = 152, Parent = adminHeader,
        })
        make("TextLabel", {
            Text = "Active client management", Font = Enum.Font.Gotham, TextSize = 10,
            TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 34),
            Size = UDim2.new(1, -100, 0, 15), ZIndex = 152, Parent = adminHeader,
        })
        make("Frame", {
            Position = UDim2.new(0, 18, 1, -1), Size = UDim2.new(1, -36, 0, 1),
            BackgroundColor3 = C.Border, ZIndex = 151, Parent = adminHeader,
        })

        -- LIVE badge (top-right, mirrors the performance panel style)
        local liveBadge = make("Frame", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14),
            Size = UDim2.fromOffset(64, 20), BackgroundColor3 = C.BadgeIdle,
            ZIndex = 152, Parent = adminHeader,
        })
        corner(liveBadge, 6)
        local liveDot = make("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0),
            Size = UDim2.fromOffset(5, 5), BackgroundColor3 = NOTIFICATION_STYLES.success.Color,
            ZIndex = 153, Parent = liveBadge,
        })
        circle(liveDot)
        make("TextLabel", {
            Text = "LIVE", Font = Enum.Font.GothamBold, TextSize = 8,
            TextColor3 = C.TextGray, TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 0),
            Size = UDim2.new(1, -24, 1, 0), ZIndex = 153, Parent = liveBadge,
        })

        -- Summary card: count on the left, admin UID on the right
        local summaryCard = make("Frame", {
            Position = UDim2.fromOffset(16, 75), Size = UDim2.new(1, -32, 0, 56),
            BackgroundColor3 = C.Element, ZIndex = 151, Parent = adminPanel,
        })
        corner(summaryCard, 11); stroke(summaryCard, C.Border)
        make("TextLabel", {
            Text = "ACTIVE CLIENTS", Font = Enum.Font.GothamBold, TextSize = 8,
            TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 8),
            Size = UDim2.new(0.5, -12, 0, 11), ZIndex = 152, Parent = summaryCard,
        })
        local activeCountLabel = make("TextLabel", {
            Text = "0", Font = Enum.Font.GothamBold, TextSize = 23,
            TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 21),
            Size = UDim2.new(0.5, -12, 0, 28), ZIndex = 152, Parent = summaryCard,
        })
        make("TextLabel", {
            Text = "ADMIN UID", Font = Enum.Font.GothamBold, TextSize = 8,
            TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Right,
            BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 8),
            Size = UDim2.new(0.5, -12, 0, 11), ZIndex = 152, Parent = summaryCard,
        })
        make("TextLabel", {
            Text = localPlayer and tostring(localPlayer.UserId) or "N/A",
            Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.White,
            TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0, 26),
            Size = UDim2.new(0.5, -12, 0, 18), ZIndex = 152, Parent = summaryCard,
        })

        -- List header + refresh button
        make("TextLabel", {
            Text = "CLIENT LIST", Font = Enum.Font.GothamBold, TextSize = 10,
            TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 142),
            Size = UDim2.fromOffset(140, 14), ZIndex = 151, Parent = adminPanel,
        })
        local refreshAdminBtn = make("TextButton", {
            Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -16, 0, 149), Size = UDim2.fromOffset(22, 22),
            BackgroundColor3 = C.Element, ZIndex = 151, Parent = adminPanel,
        })
        corner(refreshAdminBtn, 7); stroke(refreshAdminBtn, C.Border)
        local refreshAdminIcon = make("ImageLabel", {
            Image = ICONS.refresh, ImageColor3 = C.TextGray, BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(13, 13), ZIndex = 152, Parent = refreshAdminBtn,
        })
        refreshAdminBtn.MouseEnter:Connect(function()
            tween(refreshAdminBtn, { BackgroundColor3 = C.ElementHover })
            tween(refreshAdminIcon, { ImageColor3 = C.White })
        end)
        refreshAdminBtn.MouseLeave:Connect(function()
            tween(refreshAdminBtn, { BackgroundColor3 = C.Element })
            tween(refreshAdminIcon, { ImageColor3 = C.TextGray })
        end)
        table.insert(noDrag, refreshAdminBtn)

        -- Scrolling list container + empty-state label (sibling so the
        -- UIListLayout doesn't move it around when the list is empty).
        local listFrame = make("ScrollingFrame", {
            Position = UDim2.fromOffset(16, 168),
            Size = UDim2.new(1, -32, 1, -184),
            BackgroundColor3 = C.Element, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.Border,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ZIndex = 151, Parent = adminPanel,
        })
        corner(listFrame, 11); stroke(listFrame, C.Border); pad(listFrame, 6, 6, 6, 6)
        make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = listFrame })
        table.insert(noDrag, listFrame)

        local emptyLabel = make("TextLabel", {
            Text = "No active clients", Font = Enum.Font.GothamMedium, TextSize = 11,
            TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0, 168 + ((adminHeight - 184) / 2)),
            Size = UDim2.fromOffset(adminWidth - 64, 22),
            ZIndex = 152, Parent = adminPanel,
        })

        local adminRows = {}  -- userId -> row Frame

        local function buildRow(info, order)
            local userId = info.userId
            local isSelf = (localPlayer and userId == localPlayer.UserId) or false
            local displayName = (info.displayName ~= nil and info.displayName ~= "")
                and info.displayName or ("User " .. tostring(userId))
            local handle = (info.name ~= nil and info.name ~= "") and ("@" .. info.name) or "@unknown"

            local row = make("Frame", {
                Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.WindowBg,
                LayoutOrder = order, ZIndex = 152, Parent = listFrame,
            })
            corner(row, 9); stroke(row, C.Border)

            -- Avatar
            local avH = make("Frame", {
                Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(36, 36),
                BackgroundColor3 = C.Element, ZIndex = 153, Parent = row,
            })
            corner(avH, 8)
            local avImg = make("ImageLabel", {
                Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150",
                BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
                ScaleType = Enum.ScaleType.Crop, ZIndex = 154, Parent = avH,
            })
            corner(avImg, 8)
            if isSelf then
                local ring = stroke(avH, C.Accent); ring.Transparency = 0.3
            end

            -- Reserve space on the right for the actions (JOIN + DISCONNECT
            -- buttons, or a 60px badge for self)
            local actionW = isSelf and 60 or 128
            local textRight = actionW + 18

            make("TextLabel", {
                Text = isSelf and (displayName .. "  (you)") or displayName,
                Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.White,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                BackgroundTransparency = 1, Position = UDim2.fromOffset(51, 6),
                Size = UDim2.new(1, -(51 + textRight), 0, 14),
                ZIndex = 153, Parent = row,
            })
            make("TextLabel", {
                Text = handle, Font = Enum.Font.Gotham, TextSize = 10,
                TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(51, 21),
                Size = UDim2.new(1, -(51 + textRight), 0, 12),
                ZIndex = 153, Parent = row,
            })
            make("TextLabel", {
                Text = "ID " .. tostring(userId),
                Font = Enum.Font.GothamMedium, TextSize = 9,
                TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1, Position = UDim2.fromOffset(51, 34),
                Size = UDim2.new(1, -(51 + textRight), 0, 11),
                ZIndex = 153, Parent = row,
            })

            if isSelf then
                local selfBadge = make("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -8, 0.5, 0),
                    Size = UDim2.fromOffset(54, 22),
                    BackgroundColor3 = C.Badge, ZIndex = 153, Parent = row,
                })
                corner(selfBadge, 6)
                make("TextLabel", {
                    Text = "YOU", Font = Enum.Font.GothamBold, TextSize = 9,
                    TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center,
                    BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
                    ZIndex = 154, Parent = selfBadge,
                })
            else
                local CLOSE_RED    = Color3.fromRGB(190, 60, 60)
                local CLOSE_RED_HI = Color3.fromRGB(212, 80, 80)
                local JOIN_GREEN    = Color3.fromRGB(60, 158, 90)
                local JOIN_GREEN_HI = Color3.fromRGB(80, 178, 108)

                -- JOIN button (teleports the admin into the target's server)
                local joinBtn = make("TextButton", {
                    Text = "JOIN", Font = Enum.Font.GothamBold, TextSize = 10,
                    TextColor3 = Color3.fromRGB(255, 255, 255), AutoButtonColor = false,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -94, 0.5, 0),
                    Size = UDim2.fromOffset(44, 24),
                    BackgroundColor3 = JOIN_GREEN, ZIndex = 153, Parent = row,
                })
                corner(joinBtn, 6)
                joinBtn.MouseEnter:Connect(function() tween(joinBtn, { BackgroundColor3 = JOIN_GREEN_HI }) end)
                joinBtn.MouseLeave:Connect(function() tween(joinBtn, { BackgroundColor3 = JOIN_GREEN }) end)
                joinBtn.MouseButton1Click:Connect(function()
                    if joinBtn:GetAttribute("Busy") then return end
                    joinBtn:SetAttribute("Busy", true)
                    joinBtn.Text = "..."
                    task.spawn(function()
                        local ok, err = Library:JoinPlayer(info.placeId, info.jobId)
                        if not ok then
                            joinBtn.Text = "JOIN"
                            joinBtn:SetAttribute("Busy", nil)
                            if windowRef and windowRef.Notify then
                                windowRef:Notify({
                                    Title = "Join",
                                    Content = "Can't join " .. displayName .. ": " .. tostring(err),
                                    Type = "error", Duration = 5,
                                })
                            end
                        end
                        -- On success TeleportToPlaceInstance navigates away,
                        -- so there is nothing to reset here.
                    end)
                end)
                table.insert(noDrag, joinBtn)

                local dcBtn = make("TextButton", {
                    Text = "DISCONNECT", Font = Enum.Font.GothamBold, TextSize = 10,
                    TextColor3 = Color3.fromRGB(255, 255, 255), AutoButtonColor = false,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -8, 0.5, 0),
                    Size = UDim2.fromOffset(78, 24),
                    BackgroundColor3 = CLOSE_RED, ZIndex = 153, Parent = row,
                })
                corner(dcBtn, 6)
                dcBtn.MouseEnter:Connect(function() tween(dcBtn, { BackgroundColor3 = CLOSE_RED_HI }) end)
                dcBtn.MouseLeave:Connect(function() tween(dcBtn, { BackgroundColor3 = CLOSE_RED }) end)
                dcBtn.MouseButton1Click:Connect(function()
                    if dcBtn:GetAttribute("Busy") then return end
                    dcBtn:SetAttribute("Busy", true)
                    dcBtn.Text = "..."
                    task.spawn(function()
                        local ok, err = Library:AdminDisconnect(userId)
                        if ok then
                            if windowRef and windowRef.Notify then
                                windowRef:Notify({
                                    Title = "Admin",
                                    Content = "Disconnect queued: " .. displayName,
                                    Type = "warning", Duration = 4,
                                })
                            end
                            -- Optimistically drop the row; the next poll
                            -- will reconcile anyway.
                            if row and row.Parent then row:Destroy() end
                            adminRows[userId] = nil
                        else
                            dcBtn.Text = "DISCONNECT"
                            dcBtn:SetAttribute("Busy", nil)
                            if windowRef and windowRef.Notify then
                                windowRef:Notify({
                                    Title = "Admin",
                                    Content = "Disconnect failed: " .. tostring(err),
                                    Type = "error", Duration = 5,
                                })
                            end
                        end
                    end)
                end)
                table.insert(noDrag, dcBtn)
            end
            return row
        end

        local adminIsOpen = false

        local function refreshAdminList(userInfos)
            userInfos = userInfos or TagSystem._userInfo or {}
            local merged = {}
            for id, info in pairs(userInfos) do merged[id] = info end
            if localPlayer and not merged[localPlayer.UserId] then
                merged[localPlayer.UserId] = {
                    userId      = localPlayer.UserId,
                    displayName = localPlayer.DisplayName,
                    name        = localPlayer.Name,
                }
            end

            local sorted = {}
            for _, info in pairs(merged) do table.insert(sorted, info) end
            table.sort(sorted, function(a, b)
                local aSelf = localPlayer and a.userId == localPlayer.UserId
                local bSelf = localPlayer and b.userId == localPlayer.UserId
                if aSelf ~= bSelf then return aSelf end
                local an = string.lower(tostring(a.displayName or ""))
                local bn = string.lower(tostring(b.displayName or ""))
                if an ~= bn then return an < bn end
                return a.userId < b.userId
            end)

            activeCountLabel.Text = tostring(#sorted)
            emptyLabel.Visible = (#sorted == 0)

            -- If the admin panel is closed, do NOT build rows (prevents lag with 300+ clients)
            if not adminIsOpen then
                return
            end

            -- Clear existing rows
            for uid, r in pairs(adminRows) do
                if r and r.Parent then r:Destroy() end
            end
            table.clear(adminRows)

            -- Cap rendered rows at 30 to completely prevent client lag
            local MAX_ROWS = 30
            for i = 1, math.min(#sorted, MAX_ROWS) do
                local info = sorted[i]
                local row = buildRow(info, i)
                adminRows[info.userId] = row
            end
        end

        refreshAdminBtn.MouseButton1Click:Connect(function()
            tween(refreshAdminIcon, { Rotation = refreshAdminIcon.Rotation + 360 })
            task.spawn(function()
                tagFetchAndUpdate()
                pcall(refreshAdminList, TagSystem._userInfo)
            end)
        end)

        -- Subscribe to live updates from the tag system poll loop.
        adminListener = TagSystem:OnUsersUpdated(function(userInfos)
            if not adminPanel or not adminPanel.Parent then return end
            task.spawn(function() pcall(refreshAdminList, userInfos) end)
        end)

        -- Initial render with whatever data we already have.
        refreshAdminList(TagSystem._userInfo)

        -- Trigger an immediate fetch in the background so the list populates
        -- without waiting for the next poll tick.
        task.spawn(function() pcall(tagFetchAndUpdate) end)

        function setAdminVisible(open, instant)
            adminIsOpen = open == true
            local pos = open and adminOpenPos or adminClosedPos
            local tr  = open and 0 or 1
            if instant then
                adminPanel.Position = pos
                adminPanel.GroupTransparency = tr
            else
                TweenService:Create(adminPanel, PROFILE_TWEEN, { Position = pos, GroupTransparency = tr }):Play()
            end
            if adminIsOpen then
                pcall(refreshAdminList, TagSystem._userInfo)
            end
        end
    end

    local function setProfileVisible(visible,instant)
        profileOpen=visible==true
        if not profileOpen and closeMusic then closeMusic(instant) end
        local tp=profileOpen and profileOpenPos or profileClosedPos
        local ep=profileOpen and performanceOpenPos or performanceClosedPos
        local tr=profileOpen and 0 or 1
        if instant then
            profilePanel.Position=tp; profilePanel.GroupTransparency=tr
            performancePanel.Position=ep; performancePanel.GroupTransparency=tr
        else
            TweenService:Create(profilePanel,PROFILE_TWEEN,{Position=tp,GroupTransparency=tr}):Play()
            TweenService:Create(performancePanel,PROFILE_TWEEN,{Position=ep,GroupTransparency=tr}):Play()
        end
        if setAdminVisible then setAdminVisible(profileOpen, instant) end
        if windowRef then windowRef._profileOpen=profileOpen end; return profileOpen
    end
    if localPlayer then
        task.spawn(function()
            local ok,img=pcall(function() return Players:GetUserThumbnailAsync(localPlayer.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size420x420) end)
            if ok and avatar and avatar.Parent then avatar.Image=img end
        end)
    end
    task.spawn(function()
        while screenGui and screenGui.Parent do
            local txt="N/A"
            local ok,val=pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
            if ok and type(val)=="number" then txt=tostring(math.floor(val+0.5)).." ms" end
            if pingLabel and pingLabel.Parent then pingLabel.Text=txt end; task.wait(1)
        end
    end)

    windowRef = setmetatable({
        ScreenGui=screenGui, Main=main, Container=container, Logo=brandLogo, Watermark=watermark,
        _logoAsset=logoAsset, _hotbar=hotbar, _hotbarInner=hotbarInner, _content=content,
        _notificationHolder=notificationHolder, _notificationOrder=0,
        _profilePanel=profilePanel, _performancePanel=performancePanel,
        _fpsEditableImage=fpsEditableImage, _profileKey=profileKey,
        _profileOpen=profileOpen, _setProfileVisible=setProfileVisible,
        _connections={}, _noDrag=noDrag, _tabs={}, _activeTab=nil,
        _containerScale=containerScale, _uiVisible=true, _toggleKey=toggleKey,
        _destroyed=false,
    }, Window)
    windowRef.Notify=function(s,m) return Window.Notify(windowRef,s==windowRef and m or s) end
    windowRef.Notification=windowRef.Notify
    if dragConn then table.insert(windowRef._connections, dragConn) end
    for _,c in ipairs(musicConns) do table.insert(windowRef._connections, c) end

    -- Clean up the admin panel's TagSystem listener on Window:Destroy()
    if adminListener then
        table.insert(windowRef._connections, {
            Disconnect = function() TagSystem:RemoveListener(adminListener) end,
        })
    end

    -- ── PERSISTENCE GUARD ─────────────────────────────────────────────────
    -- Some games / anti-cheats strip GUIs (from CoreGui or PlayerGui) when the
    -- character respawns, which made the whole window — and the minimized
    -- burger button in the top corner — vanish on death. Re-parent the window
    -- back to a safe host whenever it gets detached, so it never disappears.
    -- The burger button lives under screenGui too, so it returns with it.
    local function resolveHost()
        local host
        if typeof(opts.Parent) == "Instance" then
            host = opts.Parent
        else
            pcall(function() host = (gethui and gethui()) or game:GetService("CoreGui") end)
        end
        if not host then host = Players.LocalPlayer:WaitForChild("PlayerGui") end
        return host
    end
    local guardConn
    guardConn = screenGui.AncestryChanged:Connect(function(_, parent)
        -- parent == nil means it was detached from the DataModel (e.g. on death),
        -- not an intentional Destroy (which sets windowRef._destroyed).
        if parent ~= nil then return end
        if windowRef and windowRef._destroyed then return end
        task.defer(function()
            if windowRef and windowRef._destroyed then return end
            if screenGui.Parent ~= nil then return end
            pcall(function() screenGui.Parent = resolveHost() end)
        end)
    end)
    table.insert(windowRef._connections, guardConn)

    local ffc=0; local fe=0
    local fpsConn=RunService.RenderStepped:Connect(function(dt)
        if not screenGui or not screenGui.Parent then return end
        ffc=ffc+1; fe=fe+dt
        if fe>=0.25 then pushFpsSample(ffc/fe); ffc=0; fe=0 end
    end)
    table.insert(windowRef._connections,fpsConn)
    local pkConn=UserInputService.InputBegan:Connect(function(input,gp)
        if not loadingComplete or gp or UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode==profileKey and Library._windowObjects[#Library._windowObjects]==windowRef then
            windowRef:ToggleProfile()
        end
    end)
    table.insert(windowRef._connections,pkConn)
    if toggleKey then
        local tkConn=UserInputService.InputBegan:Connect(function(input,gp)
            if not loadingComplete or gp or UserInputService:GetFocusedTextBox() then return end
            if input.KeyCode==toggleKey then windowRef:ToggleUI() end
        end)
        table.insert(windowRef._connections,tkConn)
    end

    -- ── MOBILE / RESPONSIVE SCALING ──────────────────────────────────────
    -- The side panels live directly under the ScreenGui (not the container),
    -- so each gets its own UIScale that we drive together with the container.
    local function ensureScale(inst)
        if not inst then return nil end
        local us = inst:FindFirstChildOfClass("UIScale")
        if not us then us = make("UIScale", { Scale = 1, Parent = inst }) end
        return us
    end
    local musicPanel = screenGui:FindFirstChild("MusicPlayer")
    local scaleList = {}
    for _, inst in ipairs({ profilePanel, performancePanel, musicPanel, burgerButton, adminPanel }) do
        local us = ensureScale(inst); if us then table.insert(scaleList, us) end
    end
    local userScale = tonumber(opts.Scale) or 1

    -- Safe-area inset (notch / status bar). The ScreenGui ignores the GUI
    -- inset, so we account for it manually to keep the hub fully on-screen.
    local safeInset = Vector2.new(0, 0)
    pcall(function()
        local ins = GuiService:GetGuiInset()
        if ins then safeInset = ins end
    end)

    local function getViewport()
        local cam = Workspace.CurrentCamera
        if cam and cam.ViewportSize and cam.ViewportSize.X > 0 then
            return cam.ViewportSize
        end
        local ok, res = pcall(function() return GuiService:GetScreenResolution() end)
        if ok and res and res.X and res.X > 0 then return res end
        return Vector2.new(1280, 720)
    end

    local function applyResponsiveScale()
        local vp = getViewport()
        local s = 1
        if isMobile then
            local availX = math.max(1, vp.X - safeInset.X)
            local availY = math.max(1, vp.Y - safeInset.Y)
            local sx = (availX * 0.96) / math.max(1, containerW)
            local sy = (availY * 0.90) / math.max(1, containerH)
            -- Never upscale past 1 so the raster icons stay crisp; the lower
            -- clamp keeps text readable instead of shrinking it to nothing.
            s = math.clamp(math.min(sx, sy, 1), 0.36, 1)
        end
        s = s * userScale
        containerScale.Scale = s
        for _, us in ipairs(scaleList) do us.Scale = s end
    end
    applyResponsiveScale()
    windowRef._setScale = function(scale)
        userScale = math.clamp(tonumber(scale) or 1, 0.5, 1.5)
        applyResponsiveScale()
        return userScale
    end
    windowRef._getScale = function() return userScale end
    do
        local cam = Workspace.CurrentCamera
        if cam then
            table.insert(windowRef._connections, cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveScale))
        end
    end

    -- ── UI VISIBILITY TOGGLE (keyboard-free; drives the floating button) ──
    local uiHidden = false
    local function setUIVisible(v)
        v = (v ~= false)
        uiHidden = not v
        container.Visible = v
        hotbar.Visible = v and not minimized
        if burgerButton then burgerButton.Visible = v and minimized end
        windowRef._uiVisible = v
        return v
    end
    windowRef._setUIVisible = setUIVisible

    -- On mobile there is no toggle key, so add a draggable floating button.
    if isMobile then
        local fab = make("TextButton", {
            Name = "OxideMobileToggle", Text = "", AutoButtonColor = false,
            AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(14, safeInset.Y + 14),
            Size = UDim2.fromOffset(46, 46), BackgroundColor3 = C.CardBg,
            ZIndex = 60, Parent = screenGui,
        })
        corner(fab, 12); stroke(fab, C.Border)
        make("ImageLabel", { Image = logoAsset, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(26, 26), ScaleType = Enum.ScaleType.Fit, ZIndex = 61, Parent = fab })
        local fabDrag = makeDraggable(fab, {})
        if fabDrag then table.insert(windowRef._connections, fabDrag) end
        -- distinguish a tap (toggle) from a drag (move) using a movement threshold
        local downPos
        fab.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                downPos = input.Position
            end
        end)
        fab.InputEnded:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and downPos then
                local moved = (input.Position - downPos).Magnitude
                downPos = nil
                if moved < 8 then setUIVisible(uiHidden) end
            end
        end)
    end

    table.insert(Library._windowObjects,windowRef)
    if opts.Visible==false then screenGui.Enabled=false end

    if loadingEnabled and loadingLayer then
        task.defer(function()
            while not loadingMotionComplete and screenGui.Parent do RunService.Heartbeat:Wait() end
            if not screenGui.Parent or not loadingLayer.Parent then return end
            main.Visible=true; hotbar.Visible=true
            TweenService:Create(mainRevealScale,TweenInfo.new(0.3,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Scale=1}):Play()
            local fo=TweenService:Create(loadingLayer,TweenInfo.new(0.32,Enum.EasingStyle.Quart,Enum.EasingDirection.InOut),{GroupTransparency=1})
            local ce=loadingContent and TweenService:Create(loadingContent,TweenInfo.new(0.3,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Position=UDim2.new(0.5,0,0.5,-18),GroupTransparency=1})
            local le=loadingLogoScale and TweenService:Create(loadingLogoScale,TweenInfo.new(0.28,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Scale=0.84})
            local te=loadingTitleScale and TweenService:Create(loadingTitleScale,TweenInfo.new(0.28,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Scale=0.95})
            local pe
            if loadingProgressFill and loadingProgressFill.Parent then
                loadingProgressFill.AnchorPoint=Vector2.new(0.5,0.5); loadingProgressFill.Position=UDim2.fromScale(0.5,0.5)
                pe=TweenService:Create(loadingProgressFill,TweenInfo.new(0.2,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Size=UDim2.new(0,0,1,0)})
            end
            fo:Play(); if ce then ce:Play() end; if le then le:Play() end; if te then te:Play() end; if pe then pe:Play() end
            if loadingBlur then TweenService:Create(loadingBlur,TweenInfo.new(0.32,Enum.EasingStyle.Quart,Enum.EasingDirection.InOut),{Size=0}):Play() end
            if loadingSound then TweenService:Create(loadingSound,TweenInfo.new(0.3),{Volume=0}):Play() end
            fo.Completed:Wait()
            if loadingLayer and loadingLayer.Parent then loadingLayer:Destroy() end
            pcall(function() if loadingBlur then loadingBlur:Destroy() end end)
            pcall(function() if loadingSound then loadingSound:Stop(); loadingSound:Destroy() end end)
            if not screenGui.Parent then return end; loadingComplete=true
        end)
    end

    local cfgName = opts.ConfigName or (opts.Name and tostring(opts.Name):gsub("[^%w%-_]", ""):lower()) or tostring(game.PlaceId)
    Library._currentConfigName = cfgName

    if opts.AutoLoad ~= false then
        task.defer(function()
            task.wait(0.6)
            if hasFileApi() then
                pcall(function() Library:LoadConfig(cfgName) end)
            end
        end)
    end

    return windowRef
end

-- ════════════════════════════════════════════════════════════════════════════
-- WINDOW METHODS
-- ════════════════════════════════════════════════════════════════════════════
function Window:SetState(key, val) return Library:SetState(key, val) end
function Window:GetState(key, default) return Library:GetState(key, default) end
function Window:BindState(key, fn) return Library:BindState(key, fn) end
function Window:Get(flag, default) return Library:Get(flag, default) end
function Window:Set(flag, value) return Library:Set(flag, value) end

function Window:SetVisible(v) self.ScreenGui.Enabled = v==true end
function Window:Toggle() self.ScreenGui.Enabled = not self.ScreenGui.Enabled; return self.ScreenGui.Enabled end
function Window:SetUIVisible(v)
    if self._setUIVisible then return self._setUIVisible(v==true) end
    self.ScreenGui.Enabled = v==true; return v==true
end
function Window:ToggleUI() return self:SetUIVisible(not self._uiVisible) end
function Window:SetScale(value)
    local scale = math.clamp(tonumber(value) or 1, 0.5, 1.5)
    if self._setScale then return self._setScale(scale) end
    if self._containerScale then self._containerScale.Scale = scale end
    return scale
end
function Window:GetScale()
    if self._getScale then return self._getScale() end
    return self._containerScale and self._containerScale.Scale or 1
end
function Window:SetProfileVisible(v)
    if not self._setProfileVisible then return false end
    self._profileOpen=self._setProfileVisible(v==true); return self._profileOpen
end
function Window:ToggleProfile() return self:SetProfileVisible(not self._profileOpen) end
function Window:SetLogo(id)
    self._logoAsset=normalizeAssetId(id)
    if self.Logo then self.Logo.Image=self._logoAsset end
    if self.Watermark then self.Watermark.Image=self._logoAsset end
    return self._logoAsset
end

function Window:Notify(opts)
    if type(opts)=="string" then opts={Content=opts} end; opts=opts or {}
    local holder=self._notificationHolder; if not holder or not holder.Parent then return nil end
    local style=getNotificationStyle(opts.Type)
    local dur=tonumber(opts.Duration); if dur==nil then dur=4 end; dur=math.max(dur,0)
    self._notificationOrder=self._notificationOrder+1
    local title=tostring(opts.Title or style.Name)
    local body =tostring(opts.Content or opts.Description or opts.Message or "Notification")
    local slot=make("Frame",{Name="NotificationSlot",Size=UDim2.new(1,0,0,62),BackgroundTransparency=1,LayoutOrder=self._notificationOrder,ZIndex=200,Parent=holder})
    local card=make("CanvasGroup",{Name=style.Name.."Notification",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,12,0,0),Size=UDim2.fromScale(1,1),BackgroundColor3=C.White,GroupTransparency=1,ClipsDescendants=true,ZIndex=201,Parent=slot})
    corner(card,6);stroke(card,C.Border)
    -- Same look as the brand card: muted blue-to-gray fade (blue at the
    -- bottom) plus the diagonal blue-white shimmer sweep. The frame must be
    -- white because a UIGradient multiplies instead of replacing.
    card:SetAttribute("Theme_BackgroundColor3", nil)
    local cardGrad=make("UIGradient",{Rotation=90,Parent=card})
    cardGrad:SetAttribute("ThemeGradient_Top","CardBg")
    cardGrad:SetAttribute("ThemeGradient_Bottom","Accent")
    cardGrad:SetAttribute("ThemeGradient_Strength",0.5)
    refreshVerticalFade(cardGrad)
    local shimmer=make("Frame",{Name="Shimmer",Size=UDim2.fromScale(1,1),ZIndex=0,BackgroundColor3=Color3.fromRGB(210,225,255),Parent=card})
    corner(shimmer,6)
    local shimmerGrad=make("UIGradient",{
        Rotation=45,
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, C.Accent),
            ColorSequenceKeypoint.new(0.42, C.Accent),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.58, C.Accent),
            ColorSequenceKeypoint.new(1.00, C.Accent),
        }),
        Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 1.0),
            NumberSequenceKeypoint.new(0.38, 1.0),
            NumberSequenceKeypoint.new(0.50, 0.55),
            NumberSequenceKeypoint.new(0.62, 1.0),
            NumberSequenceKeypoint.new(1.00, 1.0),
        }),
        Parent=shimmer,
    })
    shimmerGrad:SetAttribute("ThemeGradient_Edge","Accent")
    -- Each notification drives its own shimmer sweep (same cycle as the
    -- window glow), disconnecting when the card is dismissed.
    local nGlowT=0
    local shimmerConn=RunService.RenderStepped:Connect(function(dt)
        if not card or not card.Parent then if shimmerConn then shimmerConn:Disconnect() end return end
        nGlowT=(nGlowT+dt*0.35)%1
        shimmerGrad.Offset=Vector2.new(nGlowT*2-1,0)
    end)
    -- Style accent: short colored bar on the left edge
    local accentBar=make("Frame",{Position=UDim2.fromOffset(0,10),Size=UDim2.fromOffset(3,42),BackgroundColor3=style.Color,ZIndex=202,Parent=card})
    corner(accentBar,2)
    -- Style icon chip
    local iconHolder=make("Frame",{Position=UDim2.fromOffset(14,17),Size=UDim2.fromOffset(28,28),BackgroundColor3=style.Color,BackgroundTransparency=0.88,ZIndex=202,Parent=card})
    corner(iconHolder,8)
    make("ImageLabel",{Image=style.Icon or ICONS.alert,ImageColor3=style.Color,BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(15,15),ScaleType=Enum.ScaleType.Fit,ZIndex=203,Parent=iconHolder})
    make("TextLabel",{Text=title,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=style.Color,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Position=UDim2.fromOffset(52,8),Size=UDim2.new(1,-84,0,16),ZIndex=202,Parent=card})
    make("TextLabel",{Text=body,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.TextGray,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,BackgroundTransparency=1,Position=UDim2.fromOffset(52,27),Size=UDim2.new(1,-64,0,26),ZIndex=202,Parent=card})
    local xb=make("TextButton",{Text="×",Font=Enum.Font.Gotham,TextSize=14,TextColor3=C.TextDim,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-7,0,5),Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,ZIndex=204,Parent=card})
    local closed=false; local handle={}
    local function close(reason)
        if closed then return end; closed=true
        TweenService:Create(card,NOTIFICATION_TWEEN,{Position=UDim2.new(1,12,0,0),GroupTransparency=1}):Play()
        task.delay(0.2,function() if slot and slot.Parent then slot:Destroy() end end)
        fire(opts.Callback or opts.OnClose,reason or "closed")
    end
    function handle:Close() close("manual") end
    function handle:IsOpen() return not closed end
    xb.MouseEnter:Connect(function() tween(xb,{TextColor3=C.White}) end)
    xb.MouseLeave:Connect(function() tween(xb,{TextColor3=C.TextDim}) end)
    xb.MouseButton1Click:Connect(function() close("manual") end)
    TweenService:Create(card,NOTIFICATION_TWEEN,{Position=UDim2.new(1,0,0,0),GroupTransparency=0}):Play()
    if dur>0 then task.delay(dur,function() close("timeout") end) end; return handle
end

function Window:Destroy()
    self._destroyed = true
    for _,c in ipairs(self._connections or {}) do pcall(function() c:Disconnect() end) end
    table.clear(self._connections or {})
    if self._fpsEditableImage then pcall(function() self._fpsEditableImage:Destroy() end); self._fpsEditableImage=nil end
    local i=table.find(Library._windows,self.ScreenGui); if i then table.remove(Library._windows,i) end
    local j=table.find(Library._windowObjects,self);     if j then table.remove(Library._windowObjects,j) end
    if self.ScreenGui then self.ScreenGui:Destroy() end
    if #Library._windowObjects == 0 then stopTagSystem() end
end

-- ════════════════════════════════════════════════════════════════════════════
-- TAB SYSTEM
-- ════════════════════════════════════════════════════════════════════════════
function Window:_selectTab(tab)
    if self._activeTab==tab then return end
    local prev=self._activeTab; self._activeTab=tab
    if prev then
        prev._page.Visible=false
        tween(prev._hBtn,{BackgroundColor3=C.HotbarBg})
        tween(prev._hLabel,{TextColor3=C.TextGray})
        if prev._hDot then tween(prev._hDot,{BackgroundTransparency=1}) end
        if prev._hIconElement then
            if prev._hIconElement:IsA("ImageLabel") then tween(prev._hIconElement,{ImageColor3=C.TextGray})
            elseif prev._hIconElement:IsA("TextLabel") then tween(prev._hIconElement,{TextColor3=C.TextGray}) end
        end
    end
    tab._page.Visible=true
    tween(tab._hBtn,{BackgroundColor3=C.HotbarActive})
    tween(tab._hLabel,{TextColor3=C.White})
    if tab._hDot then tween(tab._hDot,{BackgroundTransparency=0}) end
    if tab._hIconElement then
        if tab._hIconElement:IsA("ImageLabel") then tween(tab._hIconElement,{ImageColor3=C.White})
        elseif tab._hIconElement:IsA("TextLabel") then tween(tab._hIconElement,{TextColor3=C.White}) end
    end
end

function Window:AddTab(opts)
    if type(opts)=="string" then opts={Name=opts} end
    opts=opts or {}
    local name=opts.Name or "Tab"
    local iconInput = opts.Icon
    local win=self

    local iconType, iconValue = resolveIcon(iconInput)
    if not iconType then
        local autoKey = string.lower(name)
        if ICONS[autoKey] then iconType="image"; iconValue=ICONS[autoKey]
        else iconType="text"; iconValue=string.upper(string.sub(name,1,1)) end
    end

    local hBtn=make("TextButton",{
        Text="", AutomaticSize=Enum.AutomaticSize.X,
        Size=UDim2.new(0,0,1,0),
        BackgroundColor3=C.HotbarBg,
        ZIndex=5, Parent=self._hotbarInner,
    })
    hBtn.LayoutOrder=#self._hotbarInner:GetChildren()
    corner(hBtn,7); pad(hBtn,0,0,12,12)
    table.insert(win._noDrag,hBtn)

    local hRow=make("Frame",{BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,1,0),ZIndex=5,Parent=hBtn})
    make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6),Parent=hRow})

    local iconBadge=make("Frame",{Size=UDim2.fromOffset(20,20),BackgroundTransparency=1,LayoutOrder=1,ZIndex=6,Parent=hRow})
    local hIconElement = createIconElement(iconBadge, iconType, iconValue, 18, 7)

    local hLabel=make("TextLabel",{
        Text=name,Font=Enum.Font.GothamMedium,TextSize=12,
        TextColor3=C.TextGray,BackgroundTransparency=1,
        AutomaticSize=Enum.AutomaticSize.X,
        Size=UDim2.new(0,0,1,0),LayoutOrder=2,ZIndex=6,Parent=hRow,
    })

    local hDot=make("Frame",{
        AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,1,4),
        Size=UDim2.fromOffset(4,4), BackgroundColor3=C.Accent,
        BackgroundTransparency=1, ZIndex=6, Parent=hBtn,
    })
    circle(hDot)

    local page=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,Parent=self._content})
    local header=make("Frame",{Size=UDim2.new(1,0,0,88),BackgroundTransparency=1,Parent=page})

    local headerBadge=make("Frame",{Size=UDim2.fromOffset(32,32),Position=UDim2.fromOffset(14,14),BackgroundTransparency=1,Parent=header})
    local headerIconElement = createIconElement(headerBadge, iconType, iconValue, 26, 3)
    if headerIconElement:IsA("ImageLabel") then headerIconElement.ImageColor3=C.White
    elseif headerIconElement:IsA("TextLabel") then headerIconElement.TextColor3=C.White end

    make("TextLabel",{Text=name,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(54,17),Size=UDim2.new(1,-70,0,14),Parent=header})
    make("TextLabel",{Text=opts.Subtitle or "",Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(54,33),Size=UDim2.new(1,-70,0,12),Parent=header})
    local pillBar=make("Frame",{Position=UDim2.fromOffset(16,54),Size=UDim2.new(1,-32,0,24),BackgroundTransparency=1,ClipsDescendants=true,Parent=header})
    local pillScrollLeft=make("TextButton",{Text="‹",Font=Enum.Font.GothamBold,TextSize=18,TextColor3=C.TextGray,Size=UDim2.fromOffset(20,24),BackgroundColor3=C.WindowBg,Visible=false,Parent=pillBar})
    corner(pillScrollLeft,6); table.insert(win._noDrag,pillScrollLeft)
    local pillScroll=make("ScrollingFrame",{Position=UDim2.fromOffset(24,0),Size=UDim2.new(1,-48,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.X,AutomaticCanvasSize=Enum.AutomaticSize.X,CanvasSize=UDim2.new(),ClipsDescendants=true,Parent=pillBar})
    table.insert(win._noDrag,pillScroll)
    local pillRow=make("Frame",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,1,0),BackgroundTransparency=1,Parent=pillScroll})
    make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8),Parent=pillRow})
    local pillScrollRight=make("TextButton",{Text="›",Font=Enum.Font.GothamBold,TextSize=18,TextColor3=C.TextGray,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,0),Size=UDim2.fromOffset(20,24),BackgroundColor3=C.WindowBg,Visible=false,Parent=pillBar})
    corner(pillScrollRight,6); table.insert(win._noDrag,pillScrollRight)
    make("Frame",{Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1),BackgroundColor3=C.Border,Parent=header})
    local pagesHolder=make("Frame",{Position=UDim2.fromOffset(0,88),Size=UDim2.new(1,0,1,-88),BackgroundTransparency=1,Parent=page})

    local tab=setmetatable({
        _window=win,
        _hBtn=hBtn,_hLabel=hLabel,_hDot=hDot,_hIconElement=hIconElement,
        _page=page,_pillBar=pillBar,_pillScroll=pillScroll,_pillRow=pillRow,
        _pillScrollLeft=pillScrollLeft,_pillScrollRight=pillScrollRight,
        _pagesHolder=pagesHolder,
        _subTabs={},_activeSub=nil,
    },Tab)
    tab:_setupPillScroll()

    hBtn.MouseButton1Click:Connect(function() win:_selectTab(tab) end)
    hBtn.MouseEnter:Connect(function()
        if win._activeTab~=tab then tween(hBtn,{BackgroundColor3=C.HotbarHover}) end
    end)
    hBtn.MouseLeave:Connect(function()
        tween(hBtn,{BackgroundColor3=win._activeTab==tab and C.HotbarActive or C.HotbarBg})
    end)

    table.insert(self._tabs,tab)
    if not self._activeTab then self:_selectTab(tab) end
    return tab
end

-- ════════════════════════════════════════════════════════════════════════════
-- SUBTAB + ELEMENTS
-- ════════════════════════════════════════════════════════════════════════════
local PILL_SCROLL_STEP = 72

function Tab:_updatePillScroll()
    local scroll = self._pillScroll
    if not scroll then return end
    task.defer(function()
        if not scroll.Parent then return end
        local maxX = math.max(0, scroll.AbsoluteCanvasSize.X - scroll.AbsoluteWindowSize.X)
        local canScroll = maxX > 2
        if self._pillScrollLeft then
            self._pillScrollLeft.Visible = canScroll
            paint(self._pillScrollLeft, "TextColor3", scroll.CanvasPosition.X > 2 and "White" or "TextDim", true)
        end
        if self._pillScrollRight then
            self._pillScrollRight.Visible = canScroll
            paint(self._pillScrollRight, "TextColor3", scroll.CanvasPosition.X < maxX - 2 and "White" or "TextDim", true)
        end
        if not canScroll then
            scroll.CanvasPosition = Vector2.new(0, 0)
        end
    end)
end

function Tab:_scrollPillBy(delta)
    local scroll = self._pillScroll
    if not scroll then return end
    local maxX = math.max(0, scroll.AbsoluteCanvasSize.X - scroll.AbsoluteWindowSize.X)
    scroll.CanvasPosition = Vector2.new(math.clamp(scroll.CanvasPosition.X + delta, 0, maxX), 0)
    self:_updatePillScroll()
end

function Tab:_scrollPillIntoView(pill)
    local scroll = self._pillScroll
    if not scroll or not pill or not pill.Parent then return end
    task.defer(function()
        if not pill.Parent or not scroll.Parent then return end
        local maxX = math.max(0, scroll.AbsoluteCanvasSize.X - scroll.AbsoluteWindowSize.X)
        local relLeft = pill.AbsolutePosition.X - scroll.AbsolutePosition.X + scroll.CanvasPosition.X
        local relRight = relLeft + pill.AbsoluteSize.X
        local viewLeft = scroll.CanvasPosition.X
        local viewRight = viewLeft + scroll.AbsoluteWindowSize.X
        local nextX = scroll.CanvasPosition.X
        if relLeft < viewLeft + 4 then
            nextX = relLeft - 8
        elseif relRight > viewRight - 4 then
            nextX = relRight - scroll.AbsoluteWindowSize.X + 8
        end
        scroll.CanvasPosition = Vector2.new(math.clamp(nextX, 0, maxX), 0)
        self:_updatePillScroll()
    end)
end

function Tab:_setupPillScroll()
    local scroll = self._pillScroll
    local left = self._pillScrollLeft
    local right = self._pillScrollRight
    if not scroll then return end

    if left then
        left.MouseButton1Click:Connect(function() self:_scrollPillBy(-PILL_SCROLL_STEP) end)
        left.MouseEnter:Connect(function() tween(left, {BackgroundColor3=C.NavHover}) end)
        left.MouseLeave:Connect(function() tween(left, {BackgroundColor3=C.WindowBg}) end)
    end
    if right then
        right.MouseButton1Click:Connect(function() self:_scrollPillBy(PILL_SCROLL_STEP) end)
        right.MouseEnter:Connect(function() tween(right, {BackgroundColor3=C.NavHover}) end)
        right.MouseLeave:Connect(function() tween(right, {BackgroundColor3=C.WindowBg}) end)
    end

    scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function() self:_updatePillScroll() end)
    scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function() self:_updatePillScroll() end)
    scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:_updatePillScroll() end)

    trackConn(self._window, UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
        if not scroll.Visible or not self._page.Visible then return end
        local mouse = UserInputService:GetMouseLocation()
        local inset = GuiService:GetGuiInset()
        local pos = Vector2.new(mouse.X - inset.X, mouse.Y - inset.Y)
        local sPos, sSize = scroll.AbsolutePosition, scroll.AbsoluteSize
        if pos.X >= sPos.X and pos.X <= sPos.X + sSize.X and pos.Y >= sPos.Y and pos.Y <= sPos.Y + sSize.Y then
            self:_scrollPillBy(-input.Position.Z * PILL_SCROLL_STEP * 0.5)
        end
    end))
end

function Tab:_selectSub(sub)
    if self._activeSub==sub then return end
    local prev=self._activeSub; self._activeSub=sub
    if prev then prev._page.Visible=false; paint(prev._pill,"BackgroundColor3","WindowBg"); paint(prev._pill,"TextColor3","TextGray") end
    sub._page.Visible=true; paint(sub._pill,"BackgroundColor3","PillActive"); paint(sub._pill,"TextColor3","White")
    self:_scrollPillIntoView(sub._pill)
end

function Tab:AddSubTab(name)
    name=tostring(name or "General"); local tab=self
    local pill=make("TextButton",{Text=name,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=C.TextGray,BackgroundColor3=C.WindowBg,Size=UDim2.new(0,0,0,24),AutomaticSize=Enum.AutomaticSize.X,Parent=self._pillRow})
    autoOrder(pill);corner(pill,6);pad(pill,0,0,12,12)
    table.insert(tab._window._noDrag,pill)
    local page=make("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=2,ScrollBarImageColor3=C.Border,Parent=self._pagesHolder})
    pad(page,12,16,16,16)
    table.insert(tab._window._noDrag,page)
    local card=make("Frame",{Size=UDim2.new(1,-32,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.CardBg,Parent=page})
    corner(card,10);stroke(card);pad(card,14,14,16,16)
    make("UIListLayout",{FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8),Parent=card})
    local sub=setmetatable({_tab=tab,_window=tab._window,_pill=pill,_page=page,_card=card},SubTab)
    pill.MouseButton1Click:Connect(function() tab:_selectSub(sub) end)
    pill.MouseEnter:Connect(function() if tab._activeSub~=sub then tween(pill,{BackgroundColor3=C.NavHover}) end end)
    pill.MouseLeave:Connect(function() tween(pill,{BackgroundColor3=tab._activeSub==sub and C.PillActive or C.WindowBg}) end)
    table.insert(self._subTabs,sub)
    if not self._activeSub then self:_selectSub(sub) end
    self:_updatePillScroll()
    return sub
end

local function newRow(card,h)
    local r=make("Frame",{Size=UDim2.new(1,0,0,h),BackgroundTransparency=1,Parent=card}); autoOrder(r); return r
end
local function rowLabels(row,name,desc,rr)
    rr=rr or 0
    make("TextLabel",{Text=name,Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(0,0),Size=desc and UDim2.new(1,-rr,0,14) or UDim2.new(1,-rr,1,0),Parent=row})
    if desc then make("TextLabel",{Text=desc,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(0,16),Size=UDim2.new(1,-rr,0,12),Parent=row}) end
end

function SubTab:AddToggle(opts)
    opts=opts or {}; local value=opts.Default==true
    local row=newRow(self._card,30); rowLabels(row,opts.Name or "Toggle",opts.Description,44)
    local pill=make("TextButton",{Text="",Size=UDim2.fromOffset(34,18),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),BackgroundColor3=C.Badge,Parent=row})
    circle(pill)
    -- Blue accent outline around the pill toggle: bright when on, dim when
    -- off, with a soft outer halo for depth (theme-aware via stroke)
    local pillOutline=stroke(pill,C.Accent); pillOutline.Thickness=1.2
    local pillHalo=stroke(pill,C.Accent); pillHalo.Thickness=3.5; pillHalo.Transparency=0.88
    local knob=make("Frame",{Size=UDim2.fromOffset(14,14),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,2,0.5,0),BackgroundColor3=C.KnobOff,Parent=pill})
    circle(knob)
    local function render(a)
        local kp=value and UDim2.new(0,18,0.5,0) or UDim2.new(0,2,0.5,0)
        paint(pill,"BackgroundColor3",value and "Accent" or "Badge",not a)
        paint(knob,"BackgroundColor3",value and "KnobAccent" or "KnobOff",not a)
        if a then
            tween(pillOutline,{Transparency=value and 0.15 or 0.55})
            tween(pillHalo,{Transparency=value and 0.78 or 0.9})
        else
            pillOutline.Transparency=value and 0.15 or 0.55
            pillHalo.Transparency=value and 0.78 or 0.9
        end
        if a then tween(knob,{Position=kp}) else knob.Position=kp end
    end
    local function set(v) v=v==true; if v==value then return end; value=v; render(true); fire(opts.Callback,value); Library:QueueAutoSave() end
    pill.MouseButton1Click:Connect(function() set(not value) end); render(false)
    return registerFlag(opts.Flag, "toggle", {Set=function(_,v) set(v) end, Get=function() return value end})
end

function SubTab:AddButton(opts)
    opts=opts or {}
    local primary=opts.Primary==true or opts.Style=="primary"
    local btn=make("TextButton",{Text=opts.Name or "Button",Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=primary and C.AccentText or C.TextGray,Size=UDim2.new(1,0,0,28),BackgroundColor3=primary and C.Accent or C.Element,Parent=self._card})
    autoOrder(btn);corner(btn,6)
    if primary then btn.Font=Enum.Font.GothamBold end
    btn.MouseEnter:Connect(function() if primary then tween(btn,{BackgroundTransparency=0.14}) else tween(btn,{BackgroundColor3=C.ElementHover}) end end)
    btn.MouseLeave:Connect(function() if primary then tween(btn,{BackgroundTransparency=0}) else tween(btn,{BackgroundColor3=C.Element}) end end)
    btn.MouseButton1Click:Connect(function() fire(opts.Callback) end)
    return btn
end

function SubTab:AddSection(opts)
    if type(opts)=="string" then opts={Name=opts} end; opts=opts or {}
    local row=make("Frame",{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,Parent=self._card}); autoOrder(row)
    local tick=make("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,0,1,-4),Size=UDim2.fromOffset(3,11),BackgroundColor3=C.Accent,Parent=row}); corner(tick,2)
    make("TextLabel",{Text=string.upper(tostring(opts.Name or "Section")),Font=Enum.Font.GothamBold,TextSize=10,TextColor3=C.TextGray,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Bottom,BackgroundTransparency=1,Position=UDim2.fromOffset(9,0),Size=UDim2.new(1,-9,1,-3),Parent=row})
    make("Frame",{Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1),BackgroundColor3=C.Border,Parent=row})
    local accentUnderline=make("Frame",{Position=UDim2.new(0,0,1,-1),Size=UDim2.fromOffset(28,1),BackgroundColor3=C.Accent,Parent=row})
    return row
end

function SubTab:AddDivider()
    local row=make("Frame",{Size=UDim2.new(1,0,0,9),BackgroundTransparency=1,Parent=self._card}); autoOrder(row)
    make("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),Size=UDim2.new(1,0,0,1),BackgroundColor3=C.Border,Parent=row})
    return row
end

function SubTab:AddLabel(opts)
    if type(opts)=="string" then opts={Text=opts} end; opts=opts or {}
    local lbl=make("TextLabel",{Text=tostring(opts.Text or "Label"),Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Size=UDim2.new(1,0,0,16),Parent=self._card})
    autoOrder(lbl)
    return {Set=function(_,t) lbl.Text=tostring(t) end, Get=function() return lbl.Text end, Instance=lbl}
end

function SubTab:AddParagraph(opts)
    opts=opts or {}
    local card=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=self._card}); autoOrder(card)
    make("UIListLayout",{FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,3),Parent=card})
    if opts.Title then
        make("TextLabel",{Text=tostring(opts.Title),Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Size=UDim2.new(1,0,0,16),LayoutOrder=1,Parent=card})
    end
    local body=make("TextLabel",{Text=tostring(opts.Text or opts.Content or ""),Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),LayoutOrder=2,Parent=card})
    return {Set=function(_,t) body.Text=tostring(t) end, Get=function() return body.Text end, Instance=body}
end

function SubTab:AddKeybind(opts)
    opts=opts or {}
    local key=opts.Default
    if typeof(key)~="EnumItem" then key=nil end
    local row=newRow(self._card,30); rowLabels(row,opts.Name or "Keybind",opts.Description,80)
    local btn=make("TextButton",{Text=key and key.Name or "None",Font=Enum.Font.GothamMedium,TextSize=11,TextColor3=C.TextGray,Size=UDim2.fromOffset(70,22),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),BackgroundColor3=C.Element,Parent=row})
    corner(btn,6)
    local listening=false; local conn
    local function setKey(k)
        if k~=nil and typeof(k)~="EnumItem" then return end
        key=k; btn.Text=key and key.Name or "None"
        if opts.OnKeyChanged then fire(opts.OnKeyChanged,key) end
        Library:QueueAutoSave()
    end
    local function stopListening()
        listening=false
        if conn then conn:Disconnect(); conn=nil end
        btn.Text=key and key.Name or "None"
        tween(btn,{BackgroundColor3=C.Element,TextColor3=C.TextGray})
    end
    btn.MouseEnter:Connect(function() if not listening then tween(btn,{BackgroundColor3=C.ElementHover}) end end)
    btn.MouseLeave:Connect(function() if not listening then tween(btn,{BackgroundColor3=C.Element}) end end)
    btn.MouseButton1Click:Connect(function()
        if listening then stopListening(); return end
        listening=true; btn.Text="..."; tween(btn,{BackgroundColor3=C.PillActive,TextColor3=C.White})
        conn=UserInputService.InputBegan:Connect(function(input,gp)
            if gp then return end
            if input.UserInputType==Enum.UserInputType.Keyboard then
                if input.KeyCode==Enum.KeyCode.Escape then setKey(nil) else setKey(input.KeyCode) end
                stopListening()
            elseif input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.MouseButton2 then
                stopListening()
            end
        end)
    end)
    local pressConn=UserInputService.InputBegan:Connect(function(input,gp)
        if gp or listening or not key then return end
        if UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode==key then fire(opts.OnPress or opts.Pressed or opts.Callback,key) end
    end)
    table.insert(self._window._noDrag,btn)
    trackConn(self._window, pressConn)
    return registerFlag(opts.Flag, "keybind", {Set=function(_,k) setKey(k) end, Get=function() return key end, _connections={pressConn}})
end

function SubTab:AddInput(opts)
    opts=opts or {}
    local row=newRow(self._card,30); rowLabels(row,opts.Name or "Input",opts.Description,120)
    local holder=make("Frame",{Size=UDim2.fromOffset(110,22),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),BackgroundColor3=C.Element,Parent=row})
    corner(holder,6)
    local box=make("TextBox",{Text=opts.Default or "",PlaceholderText=opts.Placeholder or "...",PlaceholderColor3=C.Placeholder,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.TextGray,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,ClearTextOnFocus=false,ClipsDescendants=true,Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-30,1,0),Parent=holder})
    inputIcon(holder)
    box.FocusLost:Connect(function(ep) fire(opts.Callback,box.Text,ep); Library:QueueAutoSave() end)
    return registerFlag(opts.Flag, "input", {Set=function(_,t) box.Text=tostring(t) end, Get=function() return box.Text end})
end

function SubTab:AddDropdown(opts)
    opts=opts or {}
    local options=opts.Options or {}; local value=opts.Default or options[1] or ""
    local maxVisible=math.max(1,math.floor(opts.MaxVisible or 5)); local searchable=opts.Searchable==true
    local IH=22; local IP=2; local SH=26; local LW=160
    local row=newRow(self._card,30); rowLabels(row,opts.Name or "Dropdown",opts.Description,130)
    local btn=make("TextButton",{Text="",Size=UDim2.fromOffset(120,22),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),BackgroundColor3=C.Element,Parent=row})
    corner(btn,6)
    local vl=make("TextLabel",{Text=tostring(value),Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.TextGray,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-26,1,0),Parent=btn})
    sortIcon(btn)
    local win=self._window; local sp=self._page; local tp=self._tab._page
    local list=make("Frame",{Visible=false,Active=true,Position=UDim2.fromOffset(0,0),Size=UDim2.new(0,LW,0,0),BackgroundColor3=C.Element,ClipsDescendants=true,ZIndex=100,Parent=win.ScreenGui})
    corner(list,6);stroke(list); table.insert(win._noDrag,list)
    local sb; local fq=""
    if searchable then
        local sh=make("Frame",{Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,0,SH-4),BackgroundColor3=C.WindowBg,ZIndex=101,Parent=list}); corner(sh,4)
        sb=make("TextBox",{Text="",PlaceholderText="Search...",PlaceholderColor3=C.Placeholder,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,ClearTextOnFocus=false,Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-16,1,0),ZIndex=102,Parent=sh})
    end
    local sf=make("ScrollingFrame",{Position=UDim2.fromOffset(0,searchable and SH or 0),Size=UDim2.new(1,0,1,searchable and -SH or 0),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=3,ScrollBarImageColor3=C.Border,ZIndex=101,Parent=list})
    pad(sf,4,4,4,4)
    make("UIListLayout",{FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,IP),Parent=sf})
    local open=false; local cg=0; local oc={}; local co=options; local ob={}
    local function repo()
        local inset=GuiService:GetGuiInset(); local p,s=btn.AbsolutePosition,btn.AbsoluteSize
        list.Position=UDim2.fromOffset(p.X+inset.X+s.X-LW,p.Y+inset.Y+s.Y+4)
    end
    local function calcH()
        local fc=0; for _,o in ipairs(co) do if fq=="" or string.find(string.lower(tostring(o)),string.lower(fq),1,true) then fc=fc+1 end end
        local vc=math.min(math.max(fc,1),maxVisible)
        return vc*IH+math.max(vc-1,0)*IP+8+(searchable and SH or 0)
    end
    local function closeDD()
        if not open then return end; open=false; cg=cg+1
        for _,c in ipairs(oc) do c:Disconnect() end; table.clear(oc)
        tween(list,{Size=UDim2.new(0,LW,0,0)})
        local g=cg; task.delay(0.16,function() if g==cg and not open then list.Visible=false end end)
    end
    local function rebuild()
        for _,b in ipairs(ob) do if b and b.Parent then b:Destroy() end end; table.clear(ob)
        for _,o in ipairs(co) do
            local os=tostring(o)
            if fq=="" or string.find(string.lower(os),string.lower(fq),1,true) then
                local ob2=make("TextButton",{Text=os,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.TextGray,Size=UDim2.new(1,-8,0,IH),BackgroundColor3=C.Element,Parent=sf})
                autoOrder(ob2);corner(ob2,4);make("UIPadding",{PaddingLeft=UDim.new(0,8),Parent=ob2}); ob2.TextXAlignment=Enum.TextXAlignment.Left
                ob2.MouseEnter:Connect(function() tween(ob2,{BackgroundColor3=C.ElementHover,TextColor3=C.White}) end)
                ob2.MouseLeave:Connect(function() tween(ob2,{BackgroundColor3=C.Element,TextColor3=C.TextGray}) end)
                ob2.MouseButton1Click:Connect(function() value=o; vl.Text=os; closeDD(); fire(opts.Callback,o); Library:QueueAutoSave() end)
                table.insert(ob,ob2)
            end
        end
    end
    if sb then sb:GetPropertyChangedSignal("Text"):Connect(function() fq=sb.Text; rebuild(); if open then tween(list,{Size=UDim2.new(0,LW,0,calcH())}) end end) end
    rebuild()
    local function setOpen(o)
        if open==o then return end
        if o then
            open=true; cg=cg+1; repo(); list.Visible=true; tween(list,{Size=UDim2.new(0,LW,0,calcH())})
            table.insert(oc,btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                local bp,bs=btn.AbsolutePosition,btn.AbsoluteSize; local pp,ps=sp.AbsolutePosition,sp.AbsoluteSize
                if bp.Y+bs.Y<pp.Y or bp.Y>pp.Y+ps.Y then closeDD() else repo() end
            end))
            table.insert(oc,sp:GetPropertyChangedSignal("Visible"):Connect(function() if not sp.Visible then closeDD() end end))
            table.insert(oc,tp:GetPropertyChangedSignal("Visible"):Connect(function() if not tp.Visible then closeDD() end end))
            table.insert(oc,UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                    local pos=Vector2.new(input.Position.X,input.Position.Y)
                    if not isInside(btn,pos) and not isInside(list,pos) then closeDD() end
                end
            end))
        else closeDD() end
    end
    btn.MouseButton1Click:Connect(function() setOpen(not open) end)
    btn.MouseEnter:Connect(function() tween(btn,{BackgroundColor3=C.ElementHover}) end)
    btn.MouseLeave:Connect(function() tween(btn,{BackgroundColor3=C.Element}) end)
    return registerFlag(opts.Flag, "dropdown", {
        Set=function(_,o) value=o; vl.Text=tostring(o); fire(opts.Callback,o); Library:QueueAutoSave() end, Get=function() return value end,
        SetOptions=function(_,no)
            co=no or {}; local se=false
            for _,o in ipairs(co) do if o==value then se=true; break end end
            if not se and co[1] then value=co[1]; vl.Text=tostring(value) end
            rebuild(); if open then tween(list,{Size=UDim2.new(0,LW,0,calcH())}) end
        end,
        Refresh=function() rebuild() end,
    })
end

function SubTab:AddMultiDropdown(opts)
    opts=opts or {}
    local options=opts.Options or {}
    local maxVisible=math.max(1,math.floor(opts.MaxVisible or 5)); local searchable=opts.Searchable==true
    local IH=22; local IP=2; local SH=26; local LW=160
    local selected={}
    if type(opts.Default)=="table" then for _,o in ipairs(opts.Default) do selected[o]=true end end
    local row=newRow(self._card,30); rowLabels(row,opts.Name or "Dropdown",opts.Description,130)
    local btn=make("TextButton",{Text="",Size=UDim2.fromOffset(120,22),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),BackgroundColor3=C.Element,Parent=row})
    corner(btn,6)
    local vl=make("TextLabel",{Text="None",Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.TextGray,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-26,1,0),Parent=btn})
    sortIcon(btn)
    local win=self._window; local sp=self._page; local tp=self._tab._page
    local list=make("Frame",{Visible=false,Active=true,Position=UDim2.fromOffset(0,0),Size=UDim2.new(0,LW,0,0),BackgroundColor3=C.Element,ClipsDescendants=true,ZIndex=100,Parent=win.ScreenGui})
    corner(list,6);stroke(list); table.insert(win._noDrag,list)
    local sb; local fq=""
    if searchable then
        local sh=make("Frame",{Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,0,SH-4),BackgroundColor3=C.WindowBg,ZIndex=101,Parent=list}); corner(sh,4)
        sb=make("TextBox",{Text="",PlaceholderText="Search...",PlaceholderColor3=C.Placeholder,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,ClearTextOnFocus=false,Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-16,1,0),ZIndex=102,Parent=sh})
    end
    local sf=make("ScrollingFrame",{Position=UDim2.fromOffset(0,searchable and SH or 0),Size=UDim2.new(1,0,1,searchable and -SH or 0),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=3,ScrollBarImageColor3=C.Border,ZIndex=101,Parent=list})
    pad(sf,4,4,4,4)
    make("UIListLayout",{FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,IP),Parent=sf})
    local open=false; local cg=0; local oc={}; local co=options; local ob={}
    local function selectedList()
        local out={}
        for _,o in ipairs(co) do if selected[o] then table.insert(out,o) end end
        return out
    end
    local function updateSummary()
        local sel=selectedList()
        if #sel==0 then vl.Text="None"
        elseif #sel==1 then vl.Text=tostring(sel[1])
        else vl.Text=#sel.." selected" end
    end
    local function repo()
        local inset=GuiService:GetGuiInset(); local p,s=btn.AbsolutePosition,btn.AbsoluteSize
        list.Position=UDim2.fromOffset(p.X+inset.X+s.X-LW,p.Y+inset.Y+s.Y+4)
    end
    local function calcH()
        local fc=0; for _,o in ipairs(co) do if fq=="" or string.find(string.lower(tostring(o)),string.lower(fq),1,true) then fc=fc+1 end end
        local vc=math.min(math.max(fc,1),maxVisible)
        return vc*IH+math.max(vc-1,0)*IP+8+(searchable and SH or 0)
    end
    local function closeDD()
        if not open then return end; open=false; cg=cg+1
        for _,c in ipairs(oc) do c:Disconnect() end; table.clear(oc)
        tween(list,{Size=UDim2.new(0,LW,0,0)})
        local g=cg; task.delay(0.16,function() if g==cg and not open then list.Visible=false end end)
    end
    local function rebuild()
        for _,b in ipairs(ob) do if b and b.Parent then b:Destroy() end end; table.clear(ob)
        for _,o in ipairs(co) do
            local os=tostring(o)
            if fq=="" or string.find(string.lower(os),string.lower(fq),1,true) then
                local ob2=make("TextButton",{Text="",Size=UDim2.new(1,-8,0,IH),BackgroundColor3=C.Element,Parent=sf})
                autoOrder(ob2);corner(ob2,4)
                local box=make("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,8,0.5,0),Size=UDim2.fromOffset(12,12),BackgroundColor3=selected[o] and C.White or C.Badge,Parent=ob2})
                corner(box,3)
                local check=make("TextLabel",{Text="✓",Font=Enum.Font.GothamBold,TextSize=10,TextColor3=C.KnobOn,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Visible=selected[o]==true,Parent=box})
                make("TextLabel",{Text=os,Font=Enum.Font.Gotham,TextSize=12,TextColor3=selected[o] and C.White or C.TextGray,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,BackgroundTransparency=1,Position=UDim2.fromOffset(26,0),Size=UDim2.new(1,-32,1,0),Parent=ob2})
                ob2.MouseEnter:Connect(function() if not selected[o] then tween(ob2,{BackgroundColor3=C.ElementHover}) end end)
                ob2.MouseLeave:Connect(function() tween(ob2,{BackgroundColor3=C.Element}) end)
                ob2.MouseButton1Click:Connect(function()
                    selected[o]=not selected[o] or nil
                    box.BackgroundColor3=selected[o] and C.White or C.Badge
                    check.Visible=selected[o]==true
                    updateSummary(); fire(opts.Callback,selectedList()); Library:QueueAutoSave()
                end)
                table.insert(ob,ob2)
            end
        end
    end
    if sb then sb:GetPropertyChangedSignal("Text"):Connect(function() fq=sb.Text; rebuild(); if open then tween(list,{Size=UDim2.new(0,LW,0,calcH())}) end end) end
    rebuild(); updateSummary()
    local function setOpen(o)
        if open==o then return end
        if o then
            open=true; cg=cg+1; repo(); list.Visible=true; tween(list,{Size=UDim2.new(0,LW,0,calcH())})
            table.insert(oc,btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                local bp,bs=btn.AbsolutePosition,btn.AbsoluteSize; local pp,ps=sp.AbsolutePosition,sp.AbsoluteSize
                if bp.Y+bs.Y<pp.Y or bp.Y>pp.Y+ps.Y then closeDD() else repo() end
            end))
            table.insert(oc,sp:GetPropertyChangedSignal("Visible"):Connect(function() if not sp.Visible then closeDD() end end))
            table.insert(oc,tp:GetPropertyChangedSignal("Visible"):Connect(function() if not tp.Visible then closeDD() end end))
            table.insert(oc,UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                    local pos=Vector2.new(input.Position.X,input.Position.Y)
                    if not isInside(btn,pos) and not isInside(list,pos) then closeDD() end
                end
            end))
        else closeDD() end
    end
    btn.MouseButton1Click:Connect(function() setOpen(not open) end)
    btn.MouseEnter:Connect(function() tween(btn,{BackgroundColor3=C.ElementHover}) end)
    btn.MouseLeave:Connect(function() tween(btn,{BackgroundColor3=C.Element}) end)
    return registerFlag(opts.Flag, "multidropdown", {
        Set=function(_,sel)
            table.clear(selected)
            if type(sel)=="table" then for _,o in ipairs(sel) do selected[o]=true end end
            rebuild(); updateSummary(); fire(opts.Callback,selectedList()); Library:QueueAutoSave()
        end,
        Get=function() return selectedList() end,
        SetOptions=function(_,no)
            co=no or {}
            for o in pairs(selected) do
                local still=false
                for _,n in ipairs(co) do if n==o then still=true; break end end
                if not still then selected[o]=nil end
            end
            rebuild(); updateSummary(); if open then tween(list,{Size=UDim2.new(0,LW,0,calcH())}) end
        end,
        Refresh=function() rebuild(); updateSummary() end,
    })
end

-- ════════════════════════════════════════════════════════════════════════════
-- COLOR HELPERS
-- ════════════════════════════════════════════════════════════════════════════
local function colorToHex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5))
end
local function hexToColor(hex)
    hex = string.gsub(tostring(hex or ""), "#", "")
    if #hex ~= 6 then return nil end
    local r = tonumber(hex:sub(1,2),16)
    local g = tonumber(hex:sub(3,4),16)
    local b = tonumber(hex:sub(5,6),16)
    if not (r and g and b) then return nil end
    return Color3.fromRGB(r,g,b)
end

function SubTab:AddSlider(opts)
    opts=opts or {}
    local mn=opts.Min or 0; local mx=opts.Max or 100; local sf=opts.Suffix or ""
    local value=math.clamp(opts.Default or mn,mn,mx)
    local row=newRow(self._card,32)
    make("TextLabel",{Text=opts.Name or "Slider",Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=UDim2.fromOffset(0,0),Size=UDim2.new(0.6,0,0,14),Parent=row})
    local vl=make("TextLabel",{Text=tostring(value)..sf,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.TextDim,TextXAlignment=Enum.TextXAlignment.Right,BackgroundTransparency=1,Position=UDim2.fromOffset(0,1),Size=UDim2.new(1,0,0,13),Parent=row})
    local track=make("Frame",{Position=UDim2.fromOffset(0,24),Size=UDim2.new(1,0,0,4),BackgroundColor3=C.TrackBg,Parent=row}); circle(track)
    local fill=make("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=C.Accent,Parent=track}); circle(fill)
    local knob=make("Frame",{Size=UDim2.fromOffset(12,12),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,0,0.5,0),BackgroundColor3=C.White,ZIndex=2,Parent=track}); circle(knob); stroke(knob,C.Accent)
    local hit=make("TextButton",{Text="",BackgroundTransparency=1,Position=UDim2.new(0,-6,0,16),Size=UDim2.new(1,12,0,20),Parent=row})
    local function apply(v,a,fc)
        value=math.clamp(math.floor(v+0.5),mn,mx)
        local pct=mx>mn and (value-mn)/(mx-mn) or 0; vl.Text=tostring(value)..sf
        if a then tween(fill,{Size=UDim2.new(pct,0,1,0)}); tween(knob,{Position=UDim2.new(pct,0,0.5,0)})
        else fill.Size=UDim2.new(pct,0,1,0); knob.Position=UDim2.new(pct,0,0.5,0) end
        if fc then fire(opts.Callback,value); Library:QueueAutoSave() end
    end
    local function fromX(x) return mn+(mx-mn)*math.clamp((x-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1) end
    local dragging=false
    hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; apply(fromX(i.Position.X),true,true) end end)
    trackConn(self._window, UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then apply(fromX(i.Position.X),true,true) end end))
    trackConn(self._window, UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end))
    apply(value,false,false)
    return registerFlag(opts.Flag, "slider", {Set=function(_,v) apply(v,true,true) end, Get=function() return value end})
end

local function hsvToColor(h,s,v) return Color3.fromHSV(h,s,v) end
local function colorToHSV(c) return c:ToHSV() end

function SubTab:AddColorPicker(opts)
    opts=opts or {}
    local value = (typeof(opts.Default)=="Color3" and opts.Default) or hexToColor(opts.Default) or Color3.fromRGB(255,255,255)
    local h,s,v = colorToHSV(value)
    local row=newRow(self._card,30); rowLabels(row,opts.Name or "Color",opts.Description,44)

    local swatch=make("TextButton",{Text="",Size=UDim2.fromOffset(34,18),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),BackgroundColor3=value,Parent=row})
    corner(swatch,5);stroke(swatch,C.Border)

    local win=self._window; local sp=self._page; local tp=self._tab._page
    local PW=200
    local panel=make("Frame",{Visible=false,Active=true,Size=UDim2.fromOffset(PW,0),BackgroundColor3=C.Element,ClipsDescendants=true,ZIndex=100,Parent=win.ScreenGui})
    corner(panel,6);stroke(panel); table.insert(win._noDrag,panel)
    local inner=make("Frame",{Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(PW,168),BackgroundTransparency=1,ZIndex=101,Parent=panel})
    pad(inner,10,10,10,10)

    local svBox=make("Frame",{Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,110),BackgroundColor3=hsvToColor(h,1,1),ZIndex=101,Parent=inner})
    corner(svBox,4)
    make("UIGradient",{Color=ColorSequence.new(Color3.new(1,1,1),hsvToColor(h,1,1)),Parent=svBox})
    local svBlack=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),ZIndex=102,Parent=svBox}); corner(svBlack,4)
    make("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}),Parent=svBlack})
    local svCursor=make("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(8,8),BackgroundColor3=Color3.new(1,1,1),ZIndex=103,Parent=svBox}); circle(svCursor); stroke(svCursor,Color3.new(0,0,0))
    local svHit=make("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=104,Parent=svBox})

    local hueBox=make("Frame",{Position=UDim2.fromOffset(0,118),Size=UDim2.new(1,0,0,12),BackgroundColor3=Color3.new(1,1,1),ZIndex=101,Parent=inner})
    corner(hueBox,4)
    make("UIGradient",{Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0.00,Color3.fromRGB(255,0,0)),
        ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,255,0)),
        ColorSequenceKeypoint.new(0.33,Color3.fromRGB(0,255,0)),
        ColorSequenceKeypoint.new(0.50,Color3.fromRGB(0,255,255)),
        ColorSequenceKeypoint.new(0.67,Color3.fromRGB(0,0,255)),
        ColorSequenceKeypoint.new(0.83,Color3.fromRGB(255,0,255)),
        ColorSequenceKeypoint.new(1.00,Color3.fromRGB(255,0,0)),
    }),Parent=hueBox})
    local hueCursor=make("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0,0,0.5,0),Size=UDim2.fromOffset(4,16),BackgroundColor3=Color3.new(1,1,1),ZIndex=103,Parent=hueBox}); corner(hueCursor,2); stroke(hueCursor,Color3.new(0,0,0))
    local hueHit=make("TextButton",{Text="",BackgroundTransparency=1,Position=UDim2.fromOffset(0,-4),Size=UDim2.new(1,0,0,20),ZIndex=104,Parent=hueBox})

    local hexHolder=make("Frame",{Position=UDim2.fromOffset(0,140),Size=UDim2.new(1,0,0,22),BackgroundColor3=C.WindowBg,ZIndex=101,Parent=inner}); corner(hexHolder,5)
    local hexBox=make("TextBox",{Text=colorToHex(value),PlaceholderText="#FFFFFF",PlaceholderColor3=C.Placeholder,Font=Enum.Font.Gotham,TextSize=11,TextColor3=C.White,TextXAlignment=Enum.TextXAlignment.Center,BackgroundTransparency=1,ClearTextOnFocus=false,Size=UDim2.fromScale(1,1),ZIndex=102,Parent=hexHolder})

    local function applyVisuals(a)
        local hueColor=hsvToColor(h,1,1)
        if a then tween(swatch,{BackgroundColor3=value}) else swatch.BackgroundColor3=value end
        svBox.BackgroundColor3=hueColor
        for _,g in ipairs(svBox:GetChildren()) do if g:IsA("UIGradient") and g.Parent==svBox then g.Color=ColorSequence.new(Color3.new(1,1,1),hueColor) end end
        svCursor.Position=UDim2.new(s,0,1-v,0)
        svCursor.BackgroundColor3 = v>0.5 and Color3.new(0,0,0) or Color3.new(1,1,1)
        hueCursor.Position=UDim2.new(h,0,0.5,0)
        hexBox.Text=colorToHex(value)
    end
    local function recompute(fc,a)
        value=hsvToColor(h,s,v); applyVisuals(a)
        if fc then fire(opts.Callback,value); Library:QueueAutoSave() end
    end

    local svDragging=false; local hueDragging=false
    local function svFrom(px,py)
        local p,sz=svBox.AbsolutePosition,svBox.AbsoluteSize
        s=math.clamp((px-p.X)/math.max(sz.X,1),0,1)
        v=1-math.clamp((py-p.Y)/math.max(sz.Y,1),0,1)
    end
    local function hueFrom(px)
        local p,sz=hueBox.AbsolutePosition,hueBox.AbsoluteSize
        h=math.clamp((px-p.X)/math.max(sz.X,1),0,1)
    end
    svHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then svDragging=true; svFrom(i.Position.X,i.Position.Y); recompute(true,false) end end)
    hueHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then hueDragging=true; hueFrom(i.Position.X); recompute(true,false) end end)
    local moveConn=UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
        if svDragging then svFrom(i.Position.X,i.Position.Y); recompute(true,false)
        elseif hueDragging then hueFrom(i.Position.X); recompute(true,false) end
    end)
    local endConn=UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then svDragging=false; hueDragging=false end
    end)
    hexBox.FocusLost:Connect(function()
        local c=hexToColor(hexBox.Text)
        if c then value=c; h,s,v=colorToHSV(c); recompute(true,true) else hexBox.Text=colorToHex(value) end
    end)

    local open=false; local cg=0; local oc={}
    local function repo()
        local inset=GuiService:GetGuiInset(); local p,sz=swatch.AbsolutePosition,swatch.AbsoluteSize
        panel.Position=UDim2.fromOffset(p.X+inset.X+sz.X-PW,p.Y+inset.Y+sz.Y+4)
    end
    local function closePanel()
        if not open then return end; open=false; cg=cg+1
        for _,c in ipairs(oc) do c:Disconnect() end; table.clear(oc)
        tween(panel,{Size=UDim2.fromOffset(PW,0)})
        local g=cg; task.delay(0.16,function() if g==cg and not open then panel.Visible=false end end)
    end
    local function setOpen(o)
        if open==o then return end
        if o then
            open=true; cg=cg+1; repo(); panel.Visible=true; tween(panel,{Size=UDim2.fromOffset(PW,168)})
            table.insert(oc,swatch:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                local bp,bs=swatch.AbsolutePosition,swatch.AbsoluteSize; local pp,ps=sp.AbsolutePosition,sp.AbsoluteSize
                if bp.Y+bs.Y<pp.Y or bp.Y>pp.Y+ps.Y then closePanel() else repo() end
            end))
            table.insert(oc,sp:GetPropertyChangedSignal("Visible"):Connect(function() if not sp.Visible then closePanel() end end))
            table.insert(oc,tp:GetPropertyChangedSignal("Visible"):Connect(function() if not tp.Visible then closePanel() end end))
            table.insert(oc,UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                    local pos=Vector2.new(input.Position.X,input.Position.Y)
                    if not isInside(swatch,pos) and not isInside(panel,pos) then closePanel() end
                end
            end))
        else closePanel() end
    end
    swatch.MouseButton1Click:Connect(function() setOpen(not open) end)
    swatch.MouseEnter:Connect(function() tween(swatch,{BackgroundColor3=value}) end)
    recompute(false,false)
    trackConn(self._window, moveConn)
    trackConn(self._window, endConn)
    return registerFlag(opts.Flag, "color", {
        Set=function(_,c)
            c=(typeof(c)=="Color3" and c) or hexToColor(c)
            if not c then return end
            value=c; h,s,v=colorToHSV(c); recompute(true,true)
        end,
        Get=function() return value end,
        GetHex=function() return colorToHex(value) end,
        _connections={moveConn,endConn},
    })
end

function SubTab:AddComponents(list)
    if type(list) ~= "table" then return {} end
    local handles = {}
    for _, item in ipairs(list) do
        if type(item) == "table" and item.Type then
            local t = string.lower(item.Type)
            if t == "toggle" then
                handles[#handles + 1] = self:AddToggle(item)
            elseif t == "slider" then
                handles[#handles + 1] = self:AddSlider(item)
            elseif t == "dropdown" then
                handles[#handles + 1] = self:AddDropdown(item)
            elseif t == "multidropdown" then
                handles[#handles + 1] = self:AddMultiDropdown(item)
            elseif t == "button" then
                handles[#handles + 1] = self:AddButton(item)
            elseif t == "input" then
                handles[#handles + 1] = self:AddInput(item)
            elseif t == "keybind" then
                handles[#handles + 1] = self:AddKeybind(item)
            elseif t == "color" or t == "colorpicker" then
                handles[#handles + 1] = self:AddColorPicker(item)
            elseif t == "paragraph" then
                handles[#handles + 1] = self:AddParagraph(item)
            elseif t == "divider" then
                handles[#handles + 1] = self:AddDivider()
            elseif t == "section" then
                handles[#handles + 1] = self:AddSection(item.Name or item.Title)
            end
        end
    end
    return handles
end

return Library
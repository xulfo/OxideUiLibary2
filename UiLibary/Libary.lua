local HttpService = game:GetService("HttpService")

pcall(function()
    if not isfolder("Oxide") then
        makefolder("Oxide")
    end
    if not isfolder("Oxide/Config") then
        makefolder("Oxide/Config")
    end
    if not isfolder("Oxide/Cache") then
        makefolder("Oxide/Cache")
    end
end)

local univId = tostring(game.GameId)
if univId == "0" or univId == "" then
    univId = tostring(game.PlaceId)
end

local ConfigFile = "Oxide/Config/Oxide_" .. univId .. ".json"

ConfigData       = {}
Elements         = {}
CURRENT_VERSION  = nil

function SaveConfig()
    if writefile then
        ConfigData._version = CURRENT_VERSION
        pcall(function()
            writefile(ConfigFile, HttpService:JSONEncode(ConfigData))
        end)
    end
end

function LoadConfigFromFile()
    if not CURRENT_VERSION then return end
    
    local isFileSuccess, isFileResult = false, false
    if isfile then
        isFileSuccess, isFileResult = pcall(function() return isfile(ConfigFile) end)
    end

    if isFileSuccess and isFileResult then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(ConfigFile))
        end)
        if success and type(result) == "table" then
            if result._version == CURRENT_VERSION then
                ConfigData = result
            else
                ConfigData = { _version = CURRENT_VERSION }
            end
        else
            ConfigData = { _version = CURRENT_VERSION }
        end
    else
        ConfigData = { _version = CURRENT_VERSION }
    end
end

function LoadConfigElements()
    for key, element in pairs(Elements) do
        if ConfigData[key] ~= nil and element.Set then
            element:Set(ConfigData[key], true)
        end
    end
end

-- ============================================================
-- CONFIG PROFILE SYSTEM
-- ============================================================
local PROFILE_FOLDER = "Oxide/Profiles"

local function EnsureProfileFolder()
    pcall(function()
        if not isfolder("Oxide") then makefolder("Oxide") end
        if not isfolder("Oxide/Config") then makefolder("Oxide/Config") end
        if not isfolder(PROFILE_FOLDER) then makefolder(PROFILE_FOLDER) end
    end)
end

function GetProfileList()
    local profiles = {}
    pcall(function()
        EnsureProfileFolder()
        local files = listfiles(PROFILE_FOLDER)
        for _, filePath in ipairs(files) do
            local normalized = tostring(filePath):gsub("\\", "/")
            local fileName = normalized:match("([^/]+)$") or ""
            if fileName:match("%.json$") then
                table.insert(profiles, (fileName:gsub("%.json$", "")))
            end
        end
    end)
    table.sort(profiles)
    return profiles
end

function SaveProfile(name)
    if not name or name == "" then return false end
    EnsureProfileFolder()
    local ok, err = pcall(function()
        writefile(PROFILE_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(ConfigData))
    end)
    return ok, err
end

function LoadProfile(name)
    if not name or name == "" then return false end
    local path = PROFILE_FOLDER .. "/" .. name .. ".json"
    if not isfile then return false end
    local isFileSuccess, isFileResult = pcall(function() return isfile(path) end)
    if not isFileSuccess or not isFileResult then return false end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if ok and type(data) == "table" then
        for key, val in pairs(data) do
            ConfigData[key] = val
        end
        for key, element in pairs(Elements) do
            if ConfigData[key] ~= nil and element.Set then
                pcall(function()
                    element:Set(ConfigData[key])
                end)
                task.wait(0.03)
            end
        end
        SaveConfig()
        return true
    end
    return false
end

function DeleteProfile(name)
    if not name or name == "" then return false end
    local path = PROFILE_FOLDER .. "/" .. name .. ".json"
    local ok = pcall(function()
        if isfile(path) then delfile(path) end
    end)
    return ok
end

-- Footagesus icon data is intentionally kept outside ZeroLib.lua. Only the
-- Lucide resolver is loaded at runtime; the complete vendored source remains
-- available in this repository under vendor/footagesus-icons.
local FOOTAGESUS_ICON_URL = "https://raw.githubusercontent.com/iSylvesterr/library/925579b/ZeroinIcons.lua"
local IconPack = {
    Name = "Footagesus Lucide (unavailable)",
    GetIcon = function() return nil end,
    GetIconData = function() return nil end,
    HasIcon = function() return false end,
    ListIcons = function() return {} end,
}

do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(FOOTAGESUS_ICON_URL))()
    end)
    if ok and type(result) == "table" and type(result.GetIcon) == "function" then
        IconPack = result
    else
        warn("Oxide UI: Footagesus icon pack failed to load:", result)
    end
end

local Icons = setmetatable({}, {
    __index = function(_, name)
        return IconPack.GetIcon(name) or ""
    end,
})

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local CoreGui = game:GetService("CoreGui")
local viewport = workspace.CurrentCamera.ViewportSize

-- Oxide visual identity: grayscale surfaces with a soft blue accent,
-- matching the reference library theme (Aegis UiLibary Dark palette).
local ThemeColors = {
    BackgroundTop = Color3.fromRGB(20, 20, 20),
    BackgroundMid = Color3.fromRGB(24, 24, 24),
    BackgroundBottom = Color3.fromRGB(24, 24, 24),
    Accent = Color3.fromRGB(167, 200, 244),
    AccentBright = Color3.fromRGB(222, 234, 252),
    AccentDim = Color3.fromRGB(26, 46, 74),
    Border = Color3.fromRGB(35, 35, 35),
}

local function resolveImage(source)
    if source == nil then return "" end

    local value = tostring(source)
    if value == "" then return "" end
    if value:match("^rbxasset") or value:match("^https?://") then
        return value
    end
    if value:match("^%d+$") then
        return "rbxassetid://" .. value
    end

    -- Local images are useful during executor-side development. Published
    -- builds should pass a Roblox asset id so every user can load the logo.
    if getcustomasset then
        local ok, asset = pcall(getcustomasset, value)
        if ok and asset then return asset end
    end

    return value
end

local function resolveIcon(source)
    if source == nil then return "" end
    local value = tostring(source)
    local icon = IconPack.GetIcon(value)
    if icon then return icon end
    return resolveImage(value)
end

local function applyIcon(imageLabel, source)
    local data = type(IconPack.GetIconData) == "function" and IconPack.GetIconData(source) or nil
    if data then
        imageLabel.Image = data.Image or ""
        imageLabel.ImageRectOffset = data.ImageRectPosition or Vector2.new(0, 0)
        imageLabel.ImageRectSize = data.ImageRectSize or Vector2.new(0, 0)
    else
        imageLabel.Image = resolveIcon(source)
        imageLabel.ImageRectOffset = Vector2.new(0, 0)
        imageLabel.ImageRectSize = Vector2.new(0, 0)
    end
    return imageLabel
end

local function isMobileDevice()
    return UserInputService.TouchEnabled
        and not UserInputService.KeyboardEnabled
        and not UserInputService.MouseEnabled
end

local isMobile = isMobileDevice()

local function safeSize(pxWidth, pxHeight)
    local scaleX = pxWidth / viewport.X
    local scaleY = pxHeight / viewport.Y

    if isMobile then
        if scaleX > 0.5 then scaleX = 0.5 end
        if scaleY > 0.3 then scaleY = 0.3 end
    end

    return UDim2.new(scaleX, 0, scaleY, 0)
end

local function MakeDraggable(topbarobject, object, trackConnection, defaultWidth, defaultHeight, mobileLayout)
    local function CustomPos(topbarobject, object)
        local Dragging, DragInput, DragStart, StartPosition

        local function UpdatePos(input)
            local Delta = input.Position - DragStart
            local pos = UDim2.new(
                StartPosition.X.Scale,
                StartPosition.X.Offset + Delta.X,
                StartPosition.Y.Scale,
                StartPosition.Y.Offset + Delta.Y
            )
            local Tween = TweenService:Create(object, TweenInfo.new(0.2), { Position = pos })
            Tween:Play()
        end

        topbarobject.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                Dragging = true
                DragStart = input.Position
                StartPosition = object.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        Dragging = false
                    end
                end)
            end
        end)

        topbarobject.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                DragInput = input
            end
        end)

        local dragChangedConnection = UserInputService.InputChanged:Connect(function(input)
            if input == DragInput and Dragging then
                UpdatePos(input)
            end
        end)
        if trackConnection then trackConnection(dragChangedConnection) end
    end

    local function CustomSize(object)
        local Dragging, DragInput, DragStart, StartSize

        local minSizeX, minSizeY
        local defSizeX, defSizeY

        if mobileLayout then
            minSizeX, minSizeY = 300, 300
            defSizeX, defSizeY = defaultWidth or 470, defaultHeight or 520
        else
            minSizeX, minSizeY = 420, 280
            defSizeX, defSizeY = defaultWidth or 586, defaultHeight or 364
        end

        object.Size = UDim2.new(0, defSizeX, 0, defSizeY)

        local changesizeobject = Instance.new("Frame")
        changesizeobject.AnchorPoint = Vector2.new(1, 1)
        changesizeobject.BackgroundTransparency = 1
        changesizeobject.Size = UDim2.new(0, 40, 0, 40)
        changesizeobject.Position = UDim2.new(1, 20, 1, 20)
        changesizeobject.Name = "changesizeobject"
        changesizeobject.Parent = object

        local function UpdateSize(input)
            local Delta = input.Position - DragStart
            local newWidth = StartSize.X.Offset + Delta.X
            local newHeight = StartSize.Y.Offset + Delta.Y

            newWidth = math.max(newWidth, minSizeX)
            newHeight = math.max(newHeight, minSizeY)

            local Tween = TweenService:Create(object, TweenInfo.new(0.2), { Size = UDim2.new(0, newWidth, 0, newHeight) })
            Tween:Play()
        end

        changesizeobject.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                Dragging = true
                DragStart = input.Position
                StartSize = object.Size
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        Dragging = false
                    end
                end)
            end
        end)

        changesizeobject.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                DragInput = input
            end
        end)

        local resizeChangedConnection = UserInputService.InputChanged:Connect(function(input)
            if input == DragInput and Dragging then
                UpdateSize(input)
            end
        end)
        if trackConnection then trackConnection(resizeChangedConnection) end
    end

    CustomSize(object)
    CustomPos(topbarobject, object)
end

function CircleClick(Button, X, Y)
    spawn(function()
        Button.ClipsDescendants = true
        local Circle = Instance.new("ImageLabel")
        Circle.Image = "rbxassetid://266543268"
        Circle.ImageColor3 = Color3.fromRGB(80, 80, 80)
        Circle.ImageTransparency = 0.8999999761581421
        Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Circle.BackgroundTransparency = 1
        Circle.ZIndex = 10
        Circle.Name = "Circle"
        Circle.Parent = Button

        local NewX = X - Circle.AbsolutePosition.X
        local NewY = Y - Circle.AbsolutePosition.Y
        Circle.Position = UDim2.new(0, NewX, 0, NewY)
        local Size = 0
        if Button.AbsoluteSize.X > Button.AbsoluteSize.Y then
            Size = Button.AbsoluteSize.X * 1.5
        elseif Button.AbsoluteSize.X < Button.AbsoluteSize.Y then
            Size = Button.AbsoluteSize.Y * 1.5
        elseif Button.AbsoluteSize.X == Button.AbsoluteSize.Y then
            Size = Button.AbsoluteSize.X * 1.5
        end

        local Time = 0.5
        Circle:TweenSizeAndPosition(UDim2.new(0, Size, 0, Size), UDim2.new(0.5, -Size / 2, 0.5, -Size / 2), "Out", "Quad",
            Time, false, nil)
        for i = 1, 10 do
            Circle.ImageTransparency = Circle.ImageTransparency + 0.01
            wait(Time / 10)
        end
        Circle:Destroy()
    end)
end

-- ════════════════════════════════════════════════════════════════
-- TAG SYSTEM + LIVE TRACKING (ported from the Oxide reference UI)
-- Koyeb presence server + one-shot launch tracker.
-- ════════════════════════════════════════════════════════════════
local TagPlayers     = game:GetService("Players")
local TagWorkspace   = game:GetService("Workspace")
local TagRunService  = game:GetService("RunService")

local TAG_BASE_URL          = "https://adorable-sallyanne-fgdfgdfgd-b2d051be.koyeb.app"
local TAG_REGISTER          = TAG_BASE_URL .. "/register"
local TAG_USERS             = TAG_BASE_URL .. "/users"
local TAG_ADMIN_DISCONNECT  = TAG_BASE_URL .. "/admin/disconnect"
local TAG_CHAT_SEND         = TAG_BASE_URL .. "/chat/send"
local TAG_CHAT_MESSAGES     = TAG_BASE_URL .. "/chat/messages"

-- One-shot execution tracker (uses the same httpRequest pipeline as the tag
-- system, so it reaches the worker even on executors that block request/HttpGet).
local TRACK_LAUNCH_URL = "https://premium-keys.oxide-premium.workers.dev/track"
local _launchTracked   = false

-- Pretty game names mirrored from the worker's GAMES list.
local GAME_TRACK_NAMES = {
    [83038462357724]  = "Graben und reinigen",
    [94640181989498]  = "Grow a Chicken Fighter",
    [107778070777162] = "Steal an Egg",
    [100068273119174] = "Leaf Simulator",
    [128736949265057] = "Gakuran",
}

local TAG_W             = 200   -- fixed pixel width of tag
local TAG_H             = 52    -- fixed pixel height of tag
local TAG_WORLD_HEIGHT  = 3.4   -- world-space studs above HumanoidRootPart
local TAG_FULL_DIST     = 40    -- studs: tag fully visible up to here
local TAG_MAX_DISTANCE  = 110   -- studs: tag fully hidden beyond here

-- Detect HTTP request function
local httpRequest = (syn and syn.request)
    or (http and http.request)
    or (http_request)
    or (request)

local TagSystem = {}
TagSystem._tags        = {}   -- [Player] = { frame, glowGradient, conn, charConn }
TagSystem._screenGui   = nil
TagSystem._active      = {}   -- [UserId] = true
TagSystem._userInfo    = {}   -- [UserId] = { userId, displayName, name, jobId, placeId }
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

-- Small construction helpers for the tag frames
local function tagMake(className, props)
    local inst = Instance.new(className)
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    return inst
end
local function tagCorner(inst, radius)
    tagMake("UICorner", { CornerRadius = UDim.new(0, radius), Parent = inst })
end
local function tagStroke(inst, color, thickness)
    tagMake("UIStroke", {
        Color = color, Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inst,
    })
end

-- Build the tag ScreenGui (once)
local function ensureTagGui()
    if TagSystem._screenGui and TagSystem._screenGui.Parent then return end
    local localPlayer = TagPlayers.LocalPlayer
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

-- Create one tag frame for a player (positioned by RenderStepped)
local function buildTagFrame(player)
    ensureTagGui()
    local sg = TagSystem._screenGui

    local ACC       = ThemeColors.Accent
    local WHITE     = Color3.fromRGB(255, 255, 255)
    local TEXT_DIM  = Color3.fromRGB(139, 139, 139)
    local ELEMENT   = Color3.fromRGB(31, 31, 31)
    local ONLINE    = Color3.fromRGB(70, 200, 120)

    local root = tagMake("Frame", {
        Name = "OxideTag_" .. player.UserId,
        Size = UDim2.fromOffset(TAG_W, TAG_H),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(22, 22, 26),
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 10,
        Parent = sg,
    })
    tagCorner(root, 10)

    -- Soft drop shadow under the tag for depth
    tagMake("ImageLabel", {
        Name = "Shadow", Image = "rbxassetid://1316045217",
        ImageColor3 = Color3.fromRGB(0, 0, 0), ImageTransparency = 0.55,
        ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(10, 10, 118, 118),
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 14, 1, 14),
        ZIndex = 0, Parent = root,
    })

    -- Transparent overlay used for opacity fade
    local fadeOverlay = tagMake("Frame", {
        Name = "FadeOverlay", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(20, 20, 24),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ZIndex = 99, Parent = root,
    })
    tagCorner(fadeOverlay, 10)

    -- Traveling glow stroke
    local glowStroke = tagMake("UIStroke", {
        Thickness = 1.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = ACC, Transparency = 0.2, Parent = root,
    })
    local glowGrad = tagMake("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, ACC),
            ColorSequenceKeypoint.new(0.40, ACC),
            ColorSequenceKeypoint.new(0.50, WHITE),
            ColorSequenceKeypoint.new(0.60, ACC),
            ColorSequenceKeypoint.new(1.00, ACC),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 1.0),
            NumberSequenceKeypoint.new(0.34, 1.0),
            NumberSequenceKeypoint.new(0.50, 0.0),
            NumberSequenceKeypoint.new(0.66, 1.0),
            NumberSequenceKeypoint.new(1.00, 1.0),
        }),
        Parent = glowStroke,
    })

    -- Left: avatar circle
    local avatarHolder = tagMake("Frame", {
        Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(9, 9),
        BackgroundColor3 = Color3.fromRGB(40, 40, 45), BorderSizePixel = 0,
        ZIndex = 2, Parent = root,
    })
    tagCorner(avatarHolder, 99)
    tagStroke(avatarHolder, ACC, 1).Transparency = 0.4

    local avatar = tagMake("ImageLabel", {
        Name = "TagAvatar", Image = "", BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(3, 3),
        ScaleType = Enum.ScaleType.Crop, ImageColor3 = WHITE,
        ZIndex = 3, Parent = avatarHolder,
    })
    tagCorner(avatar, 99)

    -- Online status dot (bottom-right of avatar)
    local onlineRing = tagMake("Frame", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -1, 1, -1),
        Size = UDim2.fromOffset(11, 11), BackgroundColor3 = Color3.fromRGB(22, 22, 26),
        BorderSizePixel = 0, ZIndex = 4, Parent = avatarHolder,
    })
    tagCorner(onlineRing, 99)
    local onlineDot = tagMake("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(6, 6), BackgroundColor3 = ONLINE,
        BorderSizePixel = 0, ZIndex = 5, Parent = onlineRing,
    })
    tagCorner(onlineDot, 99)

    -- Vertical divider between avatar and text
    tagMake("Frame", {
        Size = UDim2.fromOffset(1, 30), Position = UDim2.fromOffset(51, 11),
        BackgroundColor3 = Color3.fromRGB(45, 45, 50), BorderSizePixel = 0,
        ZIndex = 2, Parent = root,
    })

    -- Right side: text content
    local textX     = 60
    local badgeW    = 46
    local badgePadR = 9
    local textWidth = TAG_W - textX - badgeW - badgePadR - 6

    local nameLabel = tagMake("TextLabel", {
        Text = player.DisplayName, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = Color3.fromRGB(245, 245, 248), BackgroundTransparency = 1,
        Size = UDim2.fromOffset(textWidth, 16), Position = UDim2.fromOffset(textX, 9),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2, Parent = root,
    })

    local userLabel = tagMake("TextLabel", {
        Text = "@" .. player.Name, Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = Color3.fromRGB(140, 140, 148), BackgroundTransparency = 1,
        Size = UDim2.fromOffset(textWidth, 13), Position = UDim2.fromOffset(textX, 26),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2, Parent = root,
    })

    -- "Oxide" badge (bottom right)
    local badge = tagMake("Frame", {
        Size = UDim2.fromOffset(badgeW, 16), AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -badgePadR, 1, -9),
        BackgroundColor3 = ACC, BackgroundTransparency = 0.82,
        BorderSizePixel = 0, ZIndex = 2, Parent = root,
    })
    tagCorner(badge, 99)
    tagStroke(badge, ACC, 0.6).Transparency = 0.4
    tagMake("TextLabel", {
        Text = "Oxide", Font = Enum.Font.GothamBold, TextSize = 8,
        TextColor3 = Color3.fromRGB(222, 236, 253), BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 3, Parent = badge,
    })

    -- Fetch avatar thumbnail async
    task.spawn(function()
        local ok, img = pcall(function()
            return TagPlayers:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and avatar and avatar.Parent then
            avatar.Image = img
        end
    end)

    return root, glowGrad, fadeOverlay
end

-- Outline color matches the moving UI glow color
local TAG_OUTLINE_COLOR = ThemeColors.Accent

-- Attach an outline (Highlight, outline-only) to a player's character.
-- Only applied to OTHER players, never the local player.
local function applyOutline(player)
    if player == TagPlayers.LocalPlayer then return nil end
    local char = player.Character
    if not char then return nil end

    local existing = char:FindFirstChild("OxideOutline")
    if existing then existing:Destroy() end

    local hl = Instance.new("Highlight")
    hl.Name             = "OxideOutline"
    hl.FillColor        = Color3.fromRGB(0, 0, 0)
    hl.FillTransparency = 1
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
    if player == TagPlayers.LocalPlayer then return end
    if TagSystem._tags[player] then return end

    local frame, glowGrad, fadeOverlay = buildTagFrame(player)
    local glowT = 0
    local currentFade = 0  -- 0 = visible, 1 = hidden

    local function refreshOutline()
        local char = player.Character
        if not char then return end
        local existing = char:FindFirstChild("OxideOutline")
        if not existing then applyOutline(player) end
    end
    refreshOutline()

    local charConn
    charConn = player.CharacterAdded:Connect(function()
        task.wait(0.2)
        applyOutline(player)
    end)

    local conn = TagRunService.RenderStepped:Connect(function(dt)
        if not frame or not frame.Parent then return end

        local char = player.Character
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
        if not hrp or not hrp:IsA("BasePart") then
            frame.Visible = false
            return
        end

        local outline = char:FindFirstChild("OxideOutline")
        if not outline then outline = applyOutline(player) end

        local camera = TagWorkspace.CurrentCamera
        if not camera then frame.Visible = false; return end

        local anchorWorld = hrp.Position + Vector3.new(0, TAG_WORLD_HEIGHT, 0)
        local distance = (anchorWorld - camera.CFrame.Position).Magnitude
        local screenPos, onScreen = camera:WorldToScreenPoint(anchorWorld)

        if not onScreen or screenPos.Z <= 0 then
            frame.Visible = false
            if outline then outline.Enabled = false end
            return
        end

        local targetFade = 0
        if distance > TAG_FULL_DIST then
            targetFade = math.clamp((distance - TAG_FULL_DIST) / (TAG_MAX_DISTANCE - TAG_FULL_DIST), 0, 1)
        end
        currentFade = currentFade + (targetFade - currentFade) * math.clamp(dt * 6, 0, 1)
        if currentFade > 0.98 then
            frame.Visible = false
            if outline then outline.Enabled = false end
            return
        end

        frame.Visible = true
        frame.Size = UDim2.fromOffset(TAG_W, TAG_H)
        if fadeOverlay and fadeOverlay.Parent then
            fadeOverlay.BackgroundTransparency = 1 - currentFade
        end

        local px = math.floor(screenPos.X + 0.5)
        local py = math.floor(screenPos.Y + 0.5)
        frame.Position = UDim2.fromOffset(px, py)

        glowT = (glowT + dt * 0.35) % 1
        glowGrad.Offset = Vector2.new(glowT * 2 - 1, 0)

        if outline and outline.Parent then
            outline.Enabled = true
            local pulse = math.sin(glowT * math.pi)
            local sharp = pulse * pulse
            local r = 100  + (255 - 100)  * sharp
            local g = 50  + (255 - 50)  * sharp
            local b = 200 + (255 - 200) * sharp
            outline.OutlineColor = Color3.fromRGB(math.floor(r), math.floor(g), math.floor(b))
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
    local lp = TagPlayers.LocalPlayer
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
        payload = '{"userId":' .. lp.UserId .. '}'
    end

    local ok, res = pcall(function()
        return httpRequest({
            Url     = TAG_REGISTER,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = payload,
        })
    end)
    if not ok or not res or not res.Body then return end

    -- One-shot: report this execution to the worker's launch counter.
    if not _launchTracked and httpRequest then
        _launchTracked = true
        local tname = GAME_TRACK_NAMES[game.PlaceId] or "Unsupported"
        local tid   = tostring(game.PlaceId)
        local eid   = getExecutorName()
        local uid   = tostring(lp.UserId or "")
        local function escapeQuery(value)
            value = tostring(value or "")
            value = string.gsub(value, "%%", "%%25")
            value = string.gsub(value, " ", "%%20")
            value = string.gsub(value, "&", "%%26")
            value = string.gsub(value, "?", "%%3F")
            return value
        end
        local tu = TRACK_LAUNCH_URL .. "?kind=launch&game=" .. escapeQuery(tname)
            .. "&place_id=" .. tid .. "&user_id=" .. uid .. "&executor=" .. escapeQuery(eid)
        pcall(function()
            httpRequest({ Url = tu, Method = "GET" })
        end)
    end

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

    for _, player in ipairs(TagPlayers:GetPlayers()) do
        if player ~= TagPlayers.LocalPlayer then
            if active[player.UserId] then
                addTag(player)
            else
                removeTag(player)
            end
        end
    end

    for _, fn in ipairs(TagSystem._listeners) do
        task.spawn(function() pcall(fn, userInfo, active) end)
    end
end

local function startTagSystem()
    if TagSystem._running then return end
    TagSystem._running = true
    ensureTagGui()

    local leaveConn = TagPlayers.PlayerRemoving:Connect(function(player)
        removeTag(player)
    end)
    table.insert(TagSystem._connections, leaveConn)

    -- Poll loop (18s heartbeat prevents network spam)
    task.spawn(function()
        while TagSystem._running do
            tagRegister()
            tagFetchAndUpdate()
            task.wait(18)
        end
    end)
end

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

function Oxide:StartTagSystem()
    startTagSystem()
end
function Oxide:StopTagSystem()
    stopTagSystem()
end

local DEFAULT_OXIDE_NOTIFICATION_LOGO = "108040120753581"
local Oxide = {
    NotificationIcon = DEFAULT_OXIDE_NOTIFICATION_LOGO,
    TagSystem = TagSystem,
}

function Oxide:GetIcon(name)
    return IconPack.GetIcon(name)
end

function Oxide:GetIconData(name)
    return type(IconPack.GetIconData) == "function" and IconPack.GetIconData(name) or nil
end

function Oxide:HasIcon(name)
    return IconPack.HasIcon(name)
end

function Oxide:GetIconNames()
    return IconPack.ListIcons()
end

function Oxide:MakeNotify(NotifyConfig)
    local NotifyConfig = NotifyConfig or {}
    NotifyConfig.Title = NotifyConfig.Title or "Oxide"
    NotifyConfig.Description = NotifyConfig.Description or "Notification"
    NotifyConfig.Content = NotifyConfig.Content or "Content"
    NotifyConfig.Icon = NotifyConfig.Icon or Oxide.NotificationIcon or DEFAULT_OXIDE_NOTIFICATION_LOGO
    NotifyConfig.Color = NotifyConfig.Color or Color3.fromRGB(150, 150, 150)
    NotifyConfig.Time = NotifyConfig.Time or 0.5
    NotifyConfig.Delay = NotifyConfig.Delay or 5
    local NotifyFunction = {}
    spawn(function()
        if not CoreGui:FindFirstChild("NotifyGui") then
            local NotifyGui = Instance.new("ScreenGui");
            NotifyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            NotifyGui.Name = "NotifyGui"
            NotifyGui.Parent = CoreGui
        end
        if not CoreGui.NotifyGui:FindFirstChild("NotifyLayout") then
            local NotifyLayout = Instance.new("Frame");
            NotifyLayout.AnchorPoint = Vector2.new(1, 0)
            NotifyLayout.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            NotifyLayout.BackgroundTransparency = 0.9990000128746033
            NotifyLayout.BorderColor3 = Color3.fromRGB(0, 0, 0)
            NotifyLayout.BorderSizePixel = 0
            NotifyLayout.Position = UDim2.new(1, -30, 0, 30)
            NotifyLayout.Size = UDim2.new(0, 320, 1, 0)
            NotifyLayout.Name = "NotifyLayout"
            NotifyLayout.Parent = CoreGui.NotifyGui
            local Count = 0
            CoreGui.NotifyGui.NotifyLayout.ChildRemoved:Connect(function()
                Count = 0
                for i, v in CoreGui.NotifyGui.NotifyLayout:GetChildren() do
                    TweenService:Create(
                        v,
                        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                        { Position = UDim2.new(0, 0, 0, ((v.Size.Y.Offset + 12) * Count)) }
                    ):Play()
                    Count = Count + 1
                end
            end)
        end
        local NotifyPosHeigh = 0
        for i, v in CoreGui.NotifyGui.NotifyLayout:GetChildren() do
            NotifyPosHeigh = v.Position.Y.Offset + v.Size.Y.Offset + 12
        end
        local NotifyFrame = Instance.new("Frame");
        local NotifyFrameReal = Instance.new("Frame");
        local UICorner = Instance.new("UICorner");
        local DropShadowHolder = Instance.new("Frame");
        local DropShadow = Instance.new("ImageLabel");
        local Top = Instance.new("Frame");
        local TextLabel = Instance.new("TextLabel");
        local UICorner1 = Instance.new("UICorner");
        local TextLabel1 = Instance.new("TextLabel");
        local Close = Instance.new("TextButton");
        local ImageLabel = Instance.new("ImageLabel");
        local TextLabel2 = Instance.new("TextLabel");

        NotifyFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
        NotifyFrame.BorderColor3 = Color3.fromRGB(24, 24, 24)
        NotifyFrame.BorderSizePixel = 0
        NotifyFrame.Size = UDim2.new(1, 0, 0, 150)
        NotifyFrame.Name = "NotifyFrame"
        NotifyFrame.BackgroundTransparency = 1
        NotifyFrame.Parent = CoreGui.NotifyGui.NotifyLayout
        NotifyFrame.AnchorPoint = Vector2.new(0, 0)
        NotifyFrame.Position = UDim2.new(0, 0, 0, NotifyPosHeigh)

        NotifyFrameReal.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        NotifyFrameReal.BorderColor3 = Color3.fromRGB(0, 0, 0)
        NotifyFrameReal.BorderSizePixel = 0
        NotifyFrameReal.Position = UDim2.new(0, 400, 0, 0)
        NotifyFrameReal.Size = UDim2.new(1, 0, 1, 0)
        NotifyFrameReal.Name = "NotifyFrameReal"
        NotifyFrameReal.Parent = NotifyFrame

        UICorner.Parent = NotifyFrameReal
        UICorner.CornerRadius = UDim.new(0, 8)

        DropShadowHolder.BackgroundTransparency = 1
        DropShadowHolder.BorderSizePixel = 0
        DropShadowHolder.Size = UDim2.new(1, 0, 1, 0)
        DropShadowHolder.ZIndex = 0
        DropShadowHolder.Name = "DropShadowHolder"
        DropShadowHolder.Parent = NotifyFrameReal

        local NotifIcon = Instance.new("ImageLabel")
        NotifIcon.Image = resolveIcon(NotifyConfig.Icon)
        NotifIcon.BackgroundTransparency = 1
        NotifIcon.ImageTransparency = 0
        NotifIcon.BorderSizePixel = 0
        NotifIcon.Size = UDim2.new(0, 60, 0, 60)
        NotifIcon.Position = UDim2.new(0., 0, 0.05, 0)
        NotifIcon.ScaleType = Enum.ScaleType.Fit
        NotifIcon.Name = "NotifIcon"
        NotifIcon.ZIndex = 0
        NotifIcon.Parent = NotifyFrameReal

        Top.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Top.BackgroundTransparency = 0.9990000128746033
        Top.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Top.BorderSizePixel = 0
        Top.Position = UDim2.new(0, 55, 0, 0)
        Top.Size = UDim2.new(1, -55, 0, 36)
        Top.Name = "Top"
        Top.Parent = NotifyFrameReal

        TextLabel.Font = Enum.Font.GothamBold
        TextLabel.Text = NotifyConfig.Title
        TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel.TextSize = 14
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel.BackgroundTransparency = 0.9990000128746033
        TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
        TextLabel.BorderSizePixel = 0
        TextLabel.Size = UDim2.new(1, 0, 1, 0)
        TextLabel.Parent = Top
        TextLabel.Position = UDim2.new(0, 10, 0, 0)

        UICorner1.Parent = Top
        UICorner1.CornerRadius = UDim.new(0, 5)

        TextLabel1.Font = Enum.Font.GothamBold
        TextLabel1.Text = NotifyConfig.Description
        TextLabel1.TextColor3 = NotifyConfig.Color
        TextLabel1.TextSize = 14
        TextLabel1.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel1.BackgroundColor3 = Color3.fromRGB(255, 130, 130)
        TextLabel1.BackgroundTransparency = 0.9990000128746033
        TextLabel1.TextTransparency = 0.3
        TextLabel1.BorderColor3 = Color3.fromRGB(0, 0, 0)
        TextLabel1.BorderSizePixel = 0
        TextLabel1.Size = UDim2.new(1, 0, 1, 0)
        TextLabel1.Position = UDim2.new(0, TextLabel.TextBounds.X + 15, 0, 0)
        TextLabel1.Parent = Top

        Close.Font = Enum.Font.SourceSans
        Close.Text = ""
        Close.TextColor3 = Color3.fromRGB(0, 0, 0)
        Close.TextSize = 14
        Close.AnchorPoint = Vector2.new(1, 0.5)
        Close.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Close.BackgroundTransparency = 0.9990000128746033
        Close.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Close.BorderSizePixel = 0
        Close.Position = UDim2.new(1, -5, 0.5, 0)
        Close.Size = UDim2.new(0, 25, 0, 25)
        Close.Name = "Close"
        Close.Parent = Top

        ImageLabel.Image = resolveIcon("x")
        ImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        ImageLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ImageLabel.BackgroundTransparency = 0.9990000128746033
        ImageLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
        ImageLabel.BorderSizePixel = 0
        ImageLabel.Position = UDim2.new(0.49000001, 0, 0.5, 0)
        ImageLabel.Size = UDim2.new(1, -8, 1, -8)
        ImageLabel.Parent = Close

        TextLabel2.Font = Enum.Font.GothamBold
        TextLabel2.TextColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel2.TextSize = 13
        TextLabel2.Text = NotifyConfig.Content
        TextLabel2.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel2.TextYAlignment = Enum.TextYAlignment.Top
        TextLabel2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TextLabel2.BackgroundTransparency = 0.9990000128746033
        TextLabel2.TextColor3 = Color3.fromRGB(150.0000062584877, 150.0000062584877, 150.0000062584877)
        TextLabel2.BorderColor3 = Color3.fromRGB(0, 0, 0)
        TextLabel2.BorderSizePixel = 0
        TextLabel2.Position = UDim2.new(0, 65, 0, 27)
        TextLabel2.Parent = NotifyFrameReal
        TextLabel2.Size = UDim2.new(1, -90, 0, 13)

        TextLabel2.Size = UDim2.new(1, -90, 0, 13 + (13 * (TextLabel2.TextBounds.X // TextLabel2.AbsoluteSize.X)))
        TextLabel2.TextWrapped = true

        if TextLabel2.AbsoluteSize.Y < 27 then
            NotifyFrame.Size = UDim2.new(1, 0, 0, 65)
        else
            NotifyFrame.Size = UDim2.new(1, 0, 0, TextLabel2.AbsoluteSize.Y + 40)
        end
        local waitbruh = false
        function NotifyFunction:Close()
            if waitbruh then
                return false
            end
            waitbruh = true
            TweenService:Create(
                NotifyFrameReal,
                TweenInfo.new(tonumber(NotifyConfig.Time), Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
                { Position = UDim2.new(0, 400, 0, 0) }
            ):Play()
            task.wait(tonumber(NotifyConfig.Time) / 1.2)
            NotifyFrame:Destroy()
        end

        Close.Activated:Connect(function()
            NotifyFunction:Close()
        end)
        TweenService:Create(
            NotifyFrameReal,
            TweenInfo.new(tonumber(NotifyConfig.Time), Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
            { Position = UDim2.new(0, 0, 0, 0) }
        ):Play()
        task.wait(tonumber(NotifyConfig.Delay))
        NotifyFunction:Close()
    end)
    return NotifyFunction
end

function notif(msg, delay, color, title, desc)
    return Oxide:MakeNotify({
        Title = title or "Oxide",
        Description = desc or "Notification",
        Content = msg or "Content",
        Color = color or Color3.fromRGB(150, 150, 150),
        Delay = delay or 4
    })
end

function Oxide:Window(GuiConfig)
    -- Single-instance lifecycle. Because this registry lives in the executor
    -- environment, it survives a new loadstring execution. Re-executing a
    -- script therefore cleans the previous window before creating this one.
    local GlobalEnvironment = (getgenv and getgenv()) or _G
    local ActiveWindowKey = "__OXIDE_ACTIVE_WINDOW"
    local previousWindow = GlobalEnvironment[ActiveWindowKey]
    if previousWindow then
        local ok, err = pcall(function()
            if type(previousWindow.Destroy) == "function" then
                previousWindow:Destroy()
            elseif type(previousWindow.Close) == "function" then
                previousWindow:Close()
            end
        end)
        if not ok then warn("Oxide previous window cleanup error:", err) end
        GlobalEnvironment[ActiveWindowKey] = nil
    end

    -- Fallback for legacy/stale instances that predate the registry or were
    -- interrupted during construction.
    for _, guiName in ipairs({ "OxideOnTop", "ToggleUIOxide", "NotifyGui" }) do
        local staleGui = CoreGui:FindFirstChild(guiName)
        if staleGui then
            pcall(function() staleGui:Destroy() end)
        end
    end

    GuiConfig              = GuiConfig or {}
    GuiConfig.Title        = GuiConfig.Title or "Oxide"
    GuiConfig.Footer       = GuiConfig.Footer or "Oxide >:D"
    GuiConfig.Color        = GuiConfig.Color or ThemeColors.Accent
    GuiConfig.Color2       = GuiConfig.Color2 or ThemeColors.BackgroundTop
    GuiConfig["Tab Width"] = GuiConfig["Tab Width"] or 120
    GuiConfig.Version      = GuiConfig.Version or 1
    GuiConfig.NotificationIcon = GuiConfig.NotificationIcon
        or GuiConfig.LogoHUB
        or DEFAULT_OXIDE_NOTIFICATION_LOGO
    GuiConfig.Discord      = GuiConfig.Discord or "https://discord.gg/OxideHub"
    GuiConfig.BuiltInInfo  = GuiConfig.BuiltInInfo ~= false

    local currentViewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or viewport
    local UseMobileLayout = GuiConfig.ForceMobile == true
        or isMobile
        or currentViewport.Y > currentViewport.X
    local DefaultWindowWidth = UseMobileLayout
        and math.max(300, math.min(586, currentViewport.X - 20))
        or 586
    local DefaultWindowHeight = UseMobileLayout
        and math.max(300, math.min(620, currentViewport.Y - 64))
        or 364
    local EffectiveTabWidth = UseMobileLayout
        and math.min(104, GuiConfig["Tab Width"])
        or GuiConfig["Tab Width"]

    Oxide.NotificationIcon = GuiConfig.NotificationIcon
    CURRENT_VERSION        = GuiConfig.Version
    LoadConfigFromFile()

    local GuiFunc = {}
    local cleanupResources = {}
    local closeCallbacks = {}
    local activeToggles = {}
    local windowElementKeys = {}
    local isDestroyed = false
    local cleanupStarted = false
    local runCleanup
    local publicWindow

    local function cleanupResource(resource)
        if resource == nil then return end
        local resourceType = typeof(resource)
        local ok, err = pcall(function()
            if resourceType == "function" then
                resource()
            elseif resourceType == "RBXScriptConnection" then
                if resource.Connected then resource:Disconnect() end
            elseif resourceType == "Instance" then
                resource:Destroy()
            elseif resourceType == "thread" then
                task.cancel(resource)
            elseif type(resource) == "table" then
                if type(resource.Cleanup) == "function" then
                    resource:Cleanup()
                elseif type(resource.Destroy) == "function" then
                    resource:Destroy()
                elseif type(resource.Disconnect) == "function" then
                    resource:Disconnect()
                elseif type(resource.Cancel) == "function" then
                    resource:Cancel()
                end
            end
        end)
        if not ok then warn("Oxide cleanup error:", err) end
    end

    local function trackCleanup(resource)
        if resource == nil then return resource end
        if isDestroyed then
            cleanupResource(resource)
        else
            table.insert(cleanupResources, resource)
        end
        return resource
    end

    function GuiFunc:AddCleanup(resource)
        return trackCleanup(resource)
    end

    function GuiFunc:OnClose(callback)
        if type(callback) ~= "function" then return callback end
        if isDestroyed then
            cleanupResource(callback)
        else
            table.insert(closeCallbacks, callback)
        end
        return callback
    end

    function GuiFunc:IsDestroyed()
        return isDestroyed
    end

    function GuiFunc:CreateCleanupToken()
        local token = { Alive = not isDestroyed }
        trackCleanup(function()
            token.Alive = false
        end)
        return token
    end

    function GuiFunc:Spawn(callback)
        assert(type(callback) == "function", "Window:Spawn expects a function")
        local token = GuiFunc:CreateCleanupToken()
        local thread = task.spawn(callback, token)
        trackCleanup(thread)
        return thread, token
    end

    local OxideOnTop = Instance.new("ScreenGui");
    local DropShadowHolder = Instance.new("Frame");
    local DropShadow = Instance.new("ImageLabel");
    local Main = Instance.new("Frame");
    local UICorner = Instance.new("UICorner");
    local Top = Instance.new("Frame");
    local TextLabel = Instance.new("TextLabel");
    local UICorner1 = Instance.new("UICorner");
    local TextLabel1 = Instance.new("TextLabel");
    local Close = Instance.new("TextButton");
    local ImageLabel1 = Instance.new("ImageLabel");
    local Min = Instance.new("TextButton");
    local ImageLabel2 = Instance.new("ImageLabel");
    local FullScreen = Instance.new("TextButton")
    local ImageLabel3 = Instance.new("ImageLabel")
    local LayersTab = Instance.new("Frame");
    local UICorner2 = Instance.new("UICorner");
    local UICorner3 = Instance.new("UICorner")
    local DecideFrame = Instance.new("Frame");
    local Layers = Instance.new("Frame");
    local UICorner6 = Instance.new("UICorner");
    local NameTab = Instance.new("TextLabel");
    local LayersReal = Instance.new("Frame");
    local LayersFolder = Instance.new("Folder");
    local LayersPageLayout = Instance.new("UIPageLayout");

    OxideOnTop.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    OxideOnTop.Name = "OxideOnTop"
    OxideOnTop.ResetOnSpawn = false
    -- Ignore the top-bar inset so top-anchored elements (minimized pill,
    -- loading screen) sit flush with the very top of the screen, matching
    -- the Libary.lua reference library.
    OxideOnTop.IgnoreGuiInset = true
    OxideOnTop.Parent = game:GetService("CoreGui")

    -- Global dropdown portal. Popup menus live outside the scroll/page tree so
    -- bottom-row dropdowns can never be clipped by the window content.
    local DropdownPortal = Instance.new("Frame")
    DropdownPortal.Name = "DropdownPortal"
    DropdownPortal.BackgroundTransparency = 1
    DropdownPortal.BorderSizePixel = 0
    DropdownPortal.Position = UDim2.fromOffset(0, 0)
    DropdownPortal.Size = UDim2.fromScale(1, 1)
    DropdownPortal.Active = false
    DropdownPortal.ZIndex = 190
    DropdownPortal.Parent = OxideOnTop

    -- ════════════════════════════════════════════════════════════════
    -- LOADING SCREEN - slam-in intro, matching the Aegis UiLibary (Libary.lua)
    -- ════════════════════════════════════════════════════════════════
    local loadingEnabled      = GuiConfig.LoadingAnimation ~= false
    local loadingDuration     = math.clamp(tonumber(GuiConfig.LoadingDuration) or 1.2, 0.4, 8)
    local loadingText         = tostring(GuiConfig.LoadingText or GuiConfig.Title or "Oxide")
    local loadingSub          = tostring(GuiConfig.LoadingSubtitle or "HUB")
    local loadingFooter       = tostring(GuiConfig.LoadingFooter or "Oxide HUB")

    -- Accent palette derived from the active theme
    local ACC       = ThemeColors.Accent
    local ACC_DARK  = ThemeColors.AccentDim
    local ACC_LIGHT = Color3.fromRGB(255, 255, 255)

    local loadingComplete       = not loadingEnabled
    local loadingMotionComplete = not loadingEnabled
    local LoadingLayer, loadingBlur

    if loadingEnabled then
        LoadingLayer = Instance.new("CanvasGroup")
        LoadingLayer.Name = "StartupLoader"
        LoadingLayer.Size = UDim2.fromScale(1, 1)
        LoadingLayer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        LoadingLayer.BackgroundTransparency = 1
        LoadingLayer.GroupTransparency = 0
        LoadingLayer.ZIndex = 500
        LoadingLayer.Parent = OxideOnTop

        if GuiConfig.LoadingBlur ~= false then
            loadingBlur = Instance.new("BlurEffect")
            loadingBlur.Size = 0
            pcall(function() loadingBlur.Parent = game:GetService("Lighting") end)
        end

        local function sideLabel(anchorX)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.fromOffset(260, 54)
            lbl.Position = UDim2.new(anchorX, 0, 0.5, -27)
            lbl.AnchorPoint = Vector2.new(0.5, 0.5)
            lbl.BackgroundTransparency = 1
            lbl.Text = loadingText
            lbl.Font = Enum.Font.GothamBlack
            lbl.TextScaled = true
            lbl.TextColor3 = ACC_LIGHT
            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            lbl.TextStrokeTransparency = 0.45
            lbl.TextTransparency = 1
            lbl.ZIndex = 508
            lbl.Parent = LoadingLayer
            local grad = Instance.new("UIGradient")
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, ACC_DARK),
                ColorSequenceKeypoint.new(0.5, ACC_LIGHT),
                ColorSequenceKeypoint.new(1, ACC_DARK),
            })
            grad.Parent = lbl
            return lbl
        end
        local leftLbl  = sideLabel(0.18)
        local rightLbl = sideLabel(0.82)

        local mainWrap = Instance.new("Frame")
        mainWrap.AnchorPoint = Vector2.new(0.5, 0.5)
        mainWrap.Size = UDim2.fromOffset(80, 36)
        mainWrap.Position = UDim2.new(0.5, 0, 0.5, -20)
        mainWrap.BackgroundTransparency = 1
        mainWrap.ZIndex = 510
        mainWrap.Parent = LoadingLayer

        local tag = Instance.new("TextLabel")
        tag.Size = UDim2.fromScale(1, 1)
        tag.BackgroundTransparency = 1
        tag.Text = loadingText
        tag.Font = Enum.Font.GothamBlack
        tag.TextScaled = true
        tag.TextColor3 = ACC_LIGHT
        tag.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        tag.TextStrokeTransparency = 0.3
        tag.TextXAlignment = Enum.TextXAlignment.Center
        tag.TextTransparency = 1
        tag.ZIndex = 510
        tag.Parent = mainWrap

        local tagGrad = Instance.new("UIGradient")
        tagGrad.Rotation = 0
        tagGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, ACC_DARK),
            ColorSequenceKeypoint.new(0.35, ACC),
            ColorSequenceKeypoint.new(0.5, ACC_LIGHT),
            ColorSequenceKeypoint.new(0.65, ACC),
            ColorSequenceKeypoint.new(1, ACC_DARK),
        })
        tagGrad.Parent = tag

        local line = Instance.new("Frame")
        line.Size = UDim2.fromOffset(0, 2)
        line.Position = UDim2.new(0.5, 0, 0.5, 60)
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BackgroundColor3 = ACC
        line.BackgroundTransparency = 1
        line.ZIndex = 510
        line.Parent = LoadingLayer
        local lineGrad = Instance.new("UIGradient")
        lineGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        lineGrad.Parent = line

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.fromOffset(400, 22)
        sub.Position = UDim2.new(0.5, 0, 0.5, 82)
        sub.AnchorPoint = Vector2.new(0.5, 0.5)
        sub.BackgroundTransparency = 1
        sub.Text = loadingSub
        sub.Font = Enum.Font.GothamBold
        sub.TextSize = 16
        sub.TextColor3 = ACC_LIGHT
        sub.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        sub.TextStrokeTransparency = 0.5
        sub.TextXAlignment = Enum.TextXAlignment.Center
        sub.TextTransparency = 1
        sub.ZIndex = 510
        sub.Parent = LoadingLayer

        local footer = Instance.new("TextLabel")
        footer.Size = UDim2.fromOffset(400, 16)
        footer.Position = UDim2.new(0.5, 0, 0.5, 112)
        footer.AnchorPoint = Vector2.new(0.5, 0.5)
        footer.BackgroundTransparency = 1
        footer.Text = loadingFooter
        footer.Font = Enum.Font.GothamMedium
        footer.TextSize = 11
        footer.TextColor3 = Color3.fromRGB(200, 150, 90)
        footer.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        footer.TextStrokeTransparency = 0.6
        footer.TextXAlignment = Enum.TextXAlignment.Center
        footer.TextTransparency = 1
        footer.ZIndex = 510
        footer.Parent = LoadingLayer

        task.spawn(function()
            if loadingBlur then
                TweenService:Create(loadingBlur, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = 10 }):Play()
            end
            TweenService:Create(leftLbl, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
            task.wait(0.08)
            if isDestroyed then return end
            TweenService:Create(rightLbl, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
            task.wait(math.clamp(loadingDuration * 0.25, 0.15, 0.8))
            if isDestroyed or not LoadingLayer.Parent then return end
            local slideInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            TweenService:Create(leftLbl, slideInfo, { Position = UDim2.new(0.5, 0, 0.5, -27) }):Play()
            TweenService:Create(rightLbl, slideInfo, { Position = UDim2.new(0.5, 0, 0.5, -27) }):Play()
            task.wait(0.22)
            if isDestroyed then return end
            leftLbl.Visible = false
            rightLbl.Visible = false
            tag.TextTransparency = 0
            TweenService:Create(mainWrap, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(820, 140) }):Play()
            task.wait(0.15)
            if isDestroyed then return end
            line.BackgroundTransparency = 0
            TweenService:Create(line, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(380, 2) }):Play()
            TweenService:Create(sub, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
            task.wait(0.08)
            if isDestroyed then return end
            TweenService:Create(footer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { TextTransparency = 0.1 }):Play()
            task.spawn(function()
                local off = -0.5
                while LoadingLayer.Parent and not loadingComplete and tag.Parent do
                    off = off + 0.018
                    if off > 1.5 then off = -0.5 end
                    tagGrad.Offset = Vector2.new(off, 0)
                    task.wait()
                end
            end)
            task.wait(math.clamp(loadingDuration * 0.35, 0.15, 1.0))
            loadingMotionComplete = true
        end)
    end


    local ActiveDropdownCloser

    DropShadowHolder.BackgroundTransparency = 1
	--DropShadowHolder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    DropShadowHolder.BorderSizePixel = 0
    DropShadowHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    DropShadowHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropShadowHolder.Size = UDim2.fromOffset(DefaultWindowWidth, DefaultWindowHeight)
    DropShadowHolder:SetAttribute("MobileLayout", UseMobileLayout)
    DropShadowHolder.ZIndex = 0
    DropShadowHolder.Name = "DropShadowHolder"
    DropShadowHolder.Parent = OxideOnTop

    DropShadowHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropShadow.Image = "rbxassetid://6015897843"
    DropShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    DropShadow.ImageTransparency = 0.6
    DropShadow.ScaleType = Enum.ScaleType.Slice
    DropShadow.SliceCenter = Rect.new(49, 49, 450, 450)
    DropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    DropShadow.BackgroundTransparency = 1
    DropShadow.BorderSizePixel = 0
    DropShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropShadow.Size = UDim2.new(1, 47, 1, 47)
    DropShadow.ZIndex = 0
    DropShadow.Name = "DropShadow"
    DropShadow.Parent = DropShadowHolder

    if GuiConfig.Theme then
        Main:Destroy()
        Main = Instance.new("ImageLabel")
        Main.Image = "rbxassetid://" .. GuiConfig.Theme
        Main.ScaleType = Enum.ScaleType.Crop
        Main.BackgroundTransparency = 0.15
        Main.ImageTransparency = GuiConfig.ThemeTransparency or 0.15
    else
        -- A single dark-emerald material avoids Roblox UIGradient banding on
        -- very dark colors while preserving the requested black/green blend.
        Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        Main.BackgroundTransparency = 0.01
    end

    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Main.BorderSizePixel = 0
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.Size = UDim2.new(1, -47, 1, -47)
    Main.Name = "Main"
    Main.Parent = DropShadow

    UICorner3.Parent = Main
    UICorner3.CornerRadius = UDim.new(0.02, 0)

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = ThemeColors.Border
    MainStroke.Transparency = 0.18
    MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    MainStroke.Thickness = 1.2
    MainStroke.Parent = Main

    Top.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Top.BackgroundTransparency = 0.01
    Top.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Top.BorderSizePixel = 0
    Top.Size = UDim2.new(1, 0, 0, 38)
    Top.Name = "Top"
    Top.Parent = Main

    TextLabel.Font = Enum.Font.GothamBold
    TextLabel.Text = GuiConfig.Title
    TextLabel.TextColor3 = Color3.fromRGB(154, 154, 154)
    TextLabel.TextSize = 14
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel.BackgroundTransparency = 0.9990000128746033
    TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
    TextLabel.BorderSizePixel = 0
    TextLabel.Size = UDim2.new(1, -100, 1, 0)
    TextLabel.Position = UDim2.new(0, 38, 0, 0)
    TextLabel.Visible = not UseMobileLayout
    TextLabel.Parent = Top

    local LogoImg = Instance.new("ImageLabel")
    LogoImg.Image = resolveImage(GuiConfig.LogoHUB or DEFAULT_OXIDE_NOTIFICATION_LOGO)
	LogoImg.BackgroundTransparency = 1
	LogoImg.BorderSizePixel = 0
	LogoImg.Size = UDim2.new(0, 22, 0, 22)
	LogoImg.Position = UDim2.new(0, 8, 0.5, -11)
	LogoImg.ScaleType = Enum.ScaleType.Fit
	LogoImg.Name = "LogoImg"
	LogoImg.Parent = Top

    UICorner1.Parent = Top

    local RightContainer = Instance.new("Frame")
    RightContainer.Name = "RightContainer"
    RightContainer.BackgroundTransparency = 1
    RightContainer.Size = UDim2.new(0.6, 0, 1, 0)
    RightContainer.Position = UDim2.new(1, -110, 0, 0)
    RightContainer.AnchorPoint = Vector2.new(1, 0)
    RightContainer.Parent = Top

    local TopListLayout = Instance.new("UIListLayout")
    TopListLayout.FillDirection = Enum.FillDirection.Horizontal
    TopListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    TopListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    TopListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TopListLayout.Padding = UDim.new(0, 8)
    TopListLayout.Parent = RightContainer

    local function styleStatusChip(frame, order)
        frame.LayoutOrder = order
        frame.Size = UDim2.new(0, 0, 0, 20)
        frame.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
        frame.BackgroundTransparency = 0
        frame.BorderSizePixel = 0
        frame.AutomaticSize = Enum.AutomaticSize.X
        frame.Parent = RightContainer

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 7)
        padding.PaddingRight = UDim.new(0, 7)
        padding.Parent = frame

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 5)
        layout.Parent = frame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(35, 35, 35)
        stroke.Transparency = 0.18
        stroke.Thickness = 1
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = frame
    end

    local function makeChipIcon(parent, image, order)
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.LayoutOrder = order
        icon.Size = UDim2.fromOffset(12, 12)
        icon.BackgroundTransparency = 1
        icon.Image = image
        icon.ImageColor3 = Color3.fromRGB(167, 200, 244)
        icon.ImageTransparency = 0.08
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = parent
        return icon
    end

    local function compactStatusText(value, maxLength)
        value = tostring(value or "Unknown")
        if #value > maxLength then
            return value:sub(1, math.max(1, maxLength - 1)) .. "…"
        end
        return value
    end

    local detectedGameName = tostring(game.Name)
    local gameNameListeners = {}

    local GameFrame = Instance.new("Frame")
    GameFrame.Name = "GameFrame"
    styleStatusChip(GameFrame, 1)
    makeChipIcon(GameFrame, resolveIcon("gamepad-2"), 1)

    local GameTextLabel = Instance.new("TextLabel")
    GameTextLabel.Name = "GameText"
    GameTextLabel.LayoutOrder = 2
    GameTextLabel.Size = UDim2.new(0, 0, 1, 0)
    GameTextLabel.BackgroundTransparency = 1
    GameTextLabel.Font = Enum.Font.GothamMedium
    GameTextLabel.Text = compactStatusText(detectedGameName, 20)
    GameTextLabel.TextColor3 = Color3.fromRGB(154, 154, 154)
    GameTextLabel.TextSize = 10
    GameTextLabel.TextXAlignment = Enum.TextXAlignment.Center
    GameTextLabel.AutomaticSize = Enum.AutomaticSize.X
    GameTextLabel.Parent = GameFrame
    GameFrame:SetAttribute("FullGameName", detectedGameName)
    GameFrame:SetAttribute("PlaceId", game.PlaceId)
    GameFrame.Visible = not UseMobileLayout

    local function updateTopTitleSpace()
        if not GameFrame.Parent or not TextLabel.Parent then return end
        local statusLeft = UseMobileLayout and RightContainer.AbsolutePosition.X
            or GameFrame.AbsolutePosition.X
        local available = statusLeft - TextLabel.AbsolutePosition.X - 8
        TextLabel.Size = UDim2.new(0, math.max(0, available), 1, 0)
    end
    GameFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateTopTitleSpace)
    GameFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTopTitleSpace)
    Top:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTopTitleSpace)
    task.defer(updateTopTitleSpace)

    -- Product info gives the experience's public place name. Resolve it in a
    -- managed task so a slow MarketplaceService response never blocks the UI.
    trackCleanup(task.spawn(function()
        local detectedName = detectedGameName
        local ok, productInfo = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        end)
        if ok and type(productInfo) == "table" and productInfo.Name and productInfo.Name ~= "" then
            detectedName = tostring(productInfo.Name)
        end
        if not isDestroyed and GameFrame.Parent then
            detectedGameName = detectedName
            GameTextLabel.Text = compactStatusText(detectedGameName, 20)
            GameFrame:SetAttribute("FullGameName", detectedGameName)
            for _, listener in ipairs(gameNameListeners) do
                task.spawn(listener, detectedGameName)
            end
            task.defer(updateTopTitleSpace)
        end
    end))

    local FooterFrame = Instance.new("Frame")
    FooterFrame.Name = "FooterFrame"
    styleStatusChip(FooterFrame, 2)
    makeChipIcon(FooterFrame, Icons.stat, 1)

    TextLabel1.Name = "FooterText"
    TextLabel1.LayoutOrder = 2
    TextLabel1.Size = UDim2.new(0, 0, 1, 0)
    TextLabel1.BackgroundTransparency = 1
    TextLabel1.Font = Enum.Font.GothamMedium
    TextLabel1.Text = "-- FPS"
    TextLabel1.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel1.TextSize = 10
    TextLabel1.TextXAlignment = Enum.TextXAlignment.Center
    TextLabel1.AutomaticSize = Enum.AutomaticSize.X
    TextLabel1.Parent = FooterFrame

    local RunService = game:GetService("RunService")
    local fpsFrames, fpsElapsed, displayedFps = 0, 0, 60
    local fpsConnection
    fpsConnection = RunService.RenderStepped:Connect(function(deltaTime)
        fpsFrames = fpsFrames + 1
        fpsElapsed = fpsElapsed + deltaTime
        if fpsElapsed >= 0.5 then
            local currentFps = fpsFrames / fpsElapsed
            displayedFps = math.floor((displayedFps * 0.35) + (currentFps * 0.65) + 0.5)
            TextLabel1.Text = tostring(displayedFps) .. " FPS"
            fpsFrames, fpsElapsed = 0, 0
        end
    end)
    trackCleanup(fpsConnection)
    OxideOnTop.Destroying:Connect(function()
        if runCleanup then runCleanup(true) end
    end)

    local execName = tostring((identifyexecutor and identifyexecutor()) or "Unknown")
    execName = execName:gsub("%s*[Vv]ersion.*$", "")
    execName = compactStatusText(execName, 12)

    local Executor = Instance.new("Frame")
    Executor.Name = "Executor"
    styleStatusChip(Executor, 3)
    makeChipIcon(Executor, Icons.plug, 1)

    local ExecutorTextLabel = Instance.new("TextLabel")
    ExecutorTextLabel.Name = "TextLabel"
    ExecutorTextLabel.LayoutOrder = 2
    ExecutorTextLabel.Size = UDim2.new(0, 0, 1, 0)
    ExecutorTextLabel.BackgroundTransparency = 1
    ExecutorTextLabel.Font = Enum.Font.GothamMedium
    ExecutorTextLabel.Text = execName
    ExecutorTextLabel.TextColor3 = Color3.fromRGB(154, 154, 154)
    ExecutorTextLabel.TextSize = 10
    ExecutorTextLabel.TextXAlignment = Enum.TextXAlignment.Center
    ExecutorTextLabel.AutomaticSize = Enum.AutomaticSize.X
    ExecutorTextLabel.Parent = Executor

    Close.Font = Enum.Font.SourceSans
    Close.Text = ""
    Close.TextColor3 = Color3.fromRGB(0, 0, 0)
    Close.TextSize = 14
    Close.AnchorPoint = Vector2.new(1, 0.5)
    Close.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Close.BackgroundTransparency = 0.9990000128746033
    Close.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Close.BorderSizePixel = 0
    Close.Position = UDim2.new(1, -8, 0.5, 0)
    Close.Size = UDim2.new(0, 25, 0, 25)
    Close.Name = "Close"
    Close.Parent = Top

    ImageLabel1.Image = resolveIcon("x")
    ImageLabel1.AnchorPoint = Vector2.new(0.5, 0.5)
    ImageLabel1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ImageLabel1.BackgroundTransparency = 0.9990000128746033
    ImageLabel1.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ImageLabel1.BorderSizePixel = 0
    ImageLabel1.Position = UDim2.new(0.49, 0, 0.5, 0)
    ImageLabel1.Size = UDim2.new(1, -8, 1, -8)
    ImageLabel1.Parent = Close

    Min.Font = Enum.Font.SourceSans
    Min.Text = ""
    Min.TextColor3 = Color3.fromRGB(0, 0, 0)
    Min.TextSize = 14
    Min.AnchorPoint = Vector2.new(1, 0.5)
    Min.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Min.BackgroundTransparency = 0.9990000128746033
    Min.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Min.BorderSizePixel = 0
    Min.Position = UDim2.new(1, -68, 0.5, 0) --(1, -38, 0.5, 0)
    Min.Size = UDim2.new(0, 25, 0, 25)
    Min.Name = "Min"
    Min.Parent = Top

    ImageLabel2.Image = resolveIcon("minus")
    ImageLabel2.AnchorPoint = Vector2.new(0.5, 0.5)
    ImageLabel2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ImageLabel2.BackgroundTransparency = 0.9990000128746033
    ImageLabel2.ImageTransparency = 0.2
    ImageLabel2.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ImageLabel2.BorderSizePixel = 0
    ImageLabel2.Position = UDim2.new(0.5, 0, 0.5, 0)
    ImageLabel2.Size = UDim2.new(1, -9, 1, -9)
    ImageLabel2.Parent = Min

    FullScreen.Font = Enum.Font.SourceSans
    FullScreen.Text = ""
    FullScreen.TextColor3 = Color3.fromRGB(0, 0, 0)
    FullScreen.TextSize = 14
    FullScreen.AnchorPoint = Vector2.new(1, 0.5)
    FullScreen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    FullScreen.BackgroundTransparency = 0.9990000128746033
    FullScreen.BorderColor3 = Color3.fromRGB(0, 0, 0)
    FullScreen.BorderSizePixel = 0
    FullScreen.Position = UDim2.new(1, -38, 0.5, 0) --(1, -68, 0.5, 0)
    FullScreen.Size = UDim2.new(0, 25, 0, 25)
    FullScreen.Name = "FullScreen"
    FullScreen.Parent = Top

    ImageLabel3.Image = resolveIcon("maximize-2")
    ImageLabel3.AnchorPoint = Vector2.new(0.5, 0.5)
    ImageLabel3.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ImageLabel3.BackgroundTransparency = 0.9990000128746033
    ImageLabel3.ImageTransparency = 0.2
    ImageLabel3.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ImageLabel3.BorderSizePixel = 0
    ImageLabel3.Position = UDim2.new(0.5, 0, 0.5, 0)
    ImageLabel3.Size = UDim2.new(1, -9, 1, -9)
    ImageLabel3.Parent = FullScreen

    LayersTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    LayersTab.BackgroundTransparency = 1
    LayersTab.BorderColor3 = Color3.fromRGB(0, 0, 0)
    LayersTab.BorderSizePixel = 0
    -- Center the sidebar content between the window edge and divider.
    LayersTab.Position = UDim2.new(0, 8, 0, 50)
    -- Equal 8px gutters on both sides when Tab Width is 130.
    LayersTab.Size = UDim2.new(0, EffectiveTabWidth - 3, 1, -104)
    LayersTab.Name = "LayersTab"
    LayersTab.Parent = Main

    local TabDivider = Instance.new("Frame")
    TabDivider.Name = "TabDivider"
    TabDivider.AnchorPoint = Vector2.new(0, 0)
    TabDivider.BackgroundColor3 = ThemeColors.Border
    TabDivider.BackgroundTransparency = 0.65
    TabDivider.BorderSizePixel = 0
    TabDivider.Position = UDim2.new(0, EffectiveTabWidth + 13, 0, 38)
    TabDivider.Size = UDim2.new(0, 1, 1, -38)
    TabDivider.Parent = Main

    local SearchBarFrame = Instance.new("Frame")
    SearchBarFrame.Name = "SearchBarFrame"
    SearchBarFrame.Size = UDim2.new(1, 0, 0, 26)
    SearchBarFrame.Position = UDim2.new(0, 0, 0, 0)
    SearchBarFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SearchBarFrame.BackgroundTransparency = 0.93
    SearchBarFrame.Parent = LayersTab

    local SearchBarCorner = Instance.new("UICorner")
    SearchBarCorner.CornerRadius = UDim.new(0, 6)
    SearchBarCorner.Parent = SearchBarFrame

    local SearchBarStroke = Instance.new("UIStroke")
    SearchBarStroke.Thickness = 1
    SearchBarStroke.Transparency = 0.7
    SearchBarStroke.Color = GuiConfig.Color
    SearchBarStroke.Parent = SearchBarFrame

    local SearchBox = Instance.new("TextBox")
    SearchBox.Name = "SearchBox"
    SearchBox.BackgroundTransparency = 1
    SearchBox.Size = UDim2.new(1, -30, 1, 0)
    SearchBox.Position = UDim2.new(0, 24, 0, 0)
    SearchBox.TextSize = 11
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.Text = ""
    SearchBox.PlaceholderText = "Search..."
    SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    SearchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    SearchBox.Parent = SearchBarFrame

    local SearchIcon = Instance.new("ImageLabel")
    SearchIcon.Name = "SearchIcon"
    SearchIcon.BackgroundTransparency = 1
    SearchIcon.Image = resolveIcon("search")
    SearchIcon.AnchorPoint = Vector2.new(0, 0.5)
    SearchIcon.Position = UDim2.new(0, 7, 0.5, 0)
    SearchIcon.Size = UDim2.new(0, 13, 0, 13)
    SearchIcon.Parent = SearchBarFrame



    local DiscordUrl = GuiConfig.Discord

    local DiscordCard = Instance.new("Frame")
    DiscordCard.Name = "DiscordCard"
    DiscordCard.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    DiscordCard.BackgroundTransparency = 0
    DiscordCard.BorderSizePixel = 0
    DiscordCard.Position = UDim2.new(0, 8, 1, -50)
    DiscordCard.Size = UDim2.new(0, EffectiveTabWidth - 3, 0, 40)
    DiscordCard.Parent = Main

    local DiscordCorner = Instance.new("UICorner")
    DiscordCorner.CornerRadius = UDim.new(0, 6)
    DiscordCorner.Parent = DiscordCard

    local DiscordStroke = Instance.new("UIStroke")
    DiscordStroke.Name = "Outline"
    DiscordStroke.Color = Color3.fromRGB(35, 35, 35)
    DiscordStroke.Transparency = 0.35
    DiscordStroke.Thickness = 1
    DiscordStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    DiscordStroke.Parent = DiscordCard

    local DiscordIcon = Instance.new("ImageLabel")
    DiscordIcon.Name = "DiscordIcon"
    DiscordIcon.BackgroundTransparency = 1
    applyIcon(DiscordIcon, "discord")
    DiscordIcon.ImageColor3 = Color3.fromRGB(167, 200, 244)
    DiscordIcon.ImageTransparency = 0.08
    DiscordIcon.Position = UDim2.new(0, 7, 0, 12)
    DiscordIcon.Size = UDim2.fromOffset(16, 16)
    DiscordIcon.ScaleType = Enum.ScaleType.Fit
    DiscordIcon.Parent = DiscordCard

    local DiscordTitle = Instance.new("TextLabel")
    DiscordTitle.Name = "Title"
    DiscordTitle.BackgroundTransparency = 1
    DiscordTitle.Font = Enum.Font.GothamBold
    DiscordTitle.Text = "Discord"
    DiscordTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    DiscordTitle.TextSize = 11
    DiscordTitle.TextXAlignment = Enum.TextXAlignment.Left
    DiscordTitle.Position = UDim2.new(0, 29, 0, 8)
    DiscordTitle.Size = UDim2.new(1, -35, 0, 12)
    DiscordTitle.Parent = DiscordCard

    local DiscordLink = Instance.new("TextLabel")
    DiscordLink.Name = "Link"
    DiscordLink.BackgroundTransparency = 1
    DiscordLink.Font = Enum.Font.GothamMedium
    DiscordLink.Text = DiscordUrl:gsub("^https?://", "")
    DiscordLink.TextColor3 = Color3.fromRGB(167, 200, 244)
    DiscordLink.TextSize = 7
    DiscordLink.TextTruncate = Enum.TextTruncate.AtEnd
    DiscordLink.TextXAlignment = Enum.TextXAlignment.Left
    DiscordLink.Position = UDim2.new(0, 29, 0, 20)
    DiscordLink.Size = UDim2.new(1, -35, 0, 10)
    DiscordLink.Parent = DiscordCard

    local DiscordButton = Instance.new("TextButton")
    DiscordButton.Name = "CopyButton"
    DiscordButton.BackgroundTransparency = 1
    DiscordButton.Text = ""
    DiscordButton.Size = UDim2.fromScale(1, 1)
    DiscordButton.ZIndex = 4
    DiscordButton.Parent = DiscordCard

    local function copyDiscordInvite()
        if setclipboard then
            local ok = pcall(setclipboard, DiscordUrl)
            if ok then
                notif("Discord invite copied to clipboard!", 3, GuiConfig.Color, "Oxide", "Discord")
                return true
            end
            notif("Failed to copy Discord invite.", 3, Color3.fromRGB(220, 90, 90), "Oxide", "Discord")
        else
            notif("Clipboard is not supported by this executor.", 3, Color3.fromRGB(220, 170, 80), "Oxide", "Discord")
        end
        return false
    end

    DiscordButton.Activated:Connect(function()
        CircleClick(DiscordButton, Mouse.X, Mouse.Y)
        copyDiscordInvite()
    end)

    UICorner2.CornerRadius = UDim.new(0, 2)
    UICorner2.Parent = LayersTab

    DecideFrame.AnchorPoint = Vector2.new(0.5, 0)
    DecideFrame.BackgroundColor3 = ThemeColors.Border
    DecideFrame.BackgroundTransparency = 0.65
    DecideFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
    DecideFrame.BorderSizePixel = 0
    DecideFrame.Position = UDim2.new(0.5, 0, 0, 38)
    DecideFrame.Size = UDim2.new(1, 0, 0, 1)
    DecideFrame.Name = "DecideFrame"
    DecideFrame.Parent = Main

    Layers.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Layers.BackgroundTransparency = 0.9990000128746033
    Layers.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Layers.BorderSizePixel = 0
    Layers.Position = UDim2.new(0, EffectiveTabWidth + 18, 0, 50)
    Layers.Size = UDim2.new(1, -(EffectiveTabWidth + 9 + 18), 1, -59)
    Layers.Name = "Layers"
    Layers.Parent = Main

    UICorner6.CornerRadius = UDim.new(0, 2)
    UICorner6.Parent = Layers

	local WindowImg1 = Instance.new("ImageLabel")
	WindowImg1.Image = resolveImage(GuiConfig.LogoHUB)
	WindowImg1.BackgroundTransparency = 1
	WindowImg1.ImageTransparency = 0.8
	WindowImg1.BorderSizePixel = 0
	WindowImg1.Size = UDim2.new(0.5, 0, 0.9, 0)
	WindowImg1.Position = UDim2.new(0, 0, 0.1, 0)
	WindowImg1.ScaleType = Enum.ScaleType.Fit
	WindowImg1.Name = "WindowImg1"
	WindowImg1.ZIndex = -1
	WindowImg1.Parent = Layers
    WindowImg1.Visible = false

	local WindowImg2 = Instance.new("ImageLabel")
	WindowImg2.Image = resolveImage(GuiConfig.WindowIMG)
	WindowImg2.BackgroundTransparency = 1
	WindowImg2.ImageTransparency = 0.8
	WindowImg2.BorderSizePixel = 0
    WindowImg2.AnchorPoint = Vector2.new(0.5, 0.5)
	WindowImg2.Size = UDim2.new(0.78, 0, 0.94, 0)
	WindowImg2.Position = UDim2.new(0.5, 0, 0.5, 0)
	WindowImg2.ScaleType = Enum.ScaleType.Fit
	WindowImg2.Name = "WindowImg2"
	WindowImg2.ZIndex = 0
	WindowImg2.Parent = Layers
    WindowImg2.Visible = true

    -- NameTab.Font = Enum.Font.GothamBold
    -- NameTab.Text = ""
    -- NameTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    -- NameTab.TextSize = 24
    -- NameTab.TextWrapped = true
    -- NameTab.TextXAlignment = Enum.TextXAlignment.Left
    -- NameTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    -- NameTab.BackgroundTransparency = 0.9990000128746033
    -- NameTab.BorderColor3 = Color3.fromRGB(0, 0, 0)
    -- NameTab.BorderSizePixel = 0
    -- NameTab.Size = UDim2.new(1, 0, 0, 30)
    -- NameTab.Name = "NameTab"
    -- NameTab.Parent = Layers

    LayersReal.AnchorPoint = Vector2.new(0, 1)
    LayersReal.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    LayersReal.BackgroundTransparency = 0.9990000128746033
    LayersReal.BorderColor3 = Color3.fromRGB(0, 0, 0)
    LayersReal.BorderSizePixel = 0
    LayersReal.ClipsDescendants = true
    LayersReal.Position = UDim2.new(0, 0, 1, 0)
    LayersReal.Size = UDim2.new(1, 0, 1, 0)
    LayersReal.Name = "LayersReal"
    LayersReal.Parent = Layers

    LayersFolder.Name = "LayersFolder"
    LayersFolder.Parent = LayersReal

    LayersPageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    LayersPageLayout.Name = "LayersPageLayout"
    LayersPageLayout.Parent = LayersFolder
    LayersPageLayout.TweenTime = 0.5
    LayersPageLayout.EasingDirection = Enum.EasingDirection.InOut
    LayersPageLayout.EasingStyle = Enum.EasingStyle.Quad

    local ScrollTab = Instance.new("ScrollingFrame");
    local UIListLayout = Instance.new("UIListLayout");

    ScrollTab.CanvasSize = UDim2.new(0, 0, 1.10000002, 0)
    ScrollTab.ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0)
    ScrollTab.ScrollBarThickness = 0
    ScrollTab.Active = true
    ScrollTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ScrollTab.BackgroundTransparency = 0.9990000128746033
    ScrollTab.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ScrollTab.BorderSizePixel = 0
    ScrollTab.Size = UDim2.new(1, 0, 1, -36)
	ScrollTab.Position = UDim2.new(0, 0, 0, 36)
    ScrollTab.Name = "ScrollTab"
    ScrollTab.Parent = LayersTab

    UIListLayout.Padding = UDim.new(0, 3)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = ScrollTab

    local function UpdateSize1()
        local OffsetY = 0
        for _, child in ScrollTab:GetChildren() do
            if child.Name ~= "UIListLayout" then
                OffsetY = OffsetY + 3 + child.Size.Y.Offset
            end
        end
        ScrollTab.CanvasSize = UDim2.new(0, 0, 0, OffsetY)
    end
    ScrollTab.ChildAdded:Connect(UpdateSize1)
    ScrollTab.ChildRemoved:Connect(UpdateSize1)

    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(SearchBox.Text)
        local jumpedToTab = false
        for _, scrolLayers in pairs(LayersFolder:GetChildren()) do
            if scrolLayers:IsA("ScrollingFrame") and scrolLayers.Name == "ScrolLayers" then
                for _, section in pairs(scrolLayers:GetChildren()) do
                    if section.Name == "Section" then
                        local sectionAdd = section:FindFirstChild("SectionAdd")
                        local sectionReal = section:FindFirstChild("SectionReal")
                        if sectionAdd and sectionReal then
                            local sectionVisible = false
                            local searchableItems = {}
                            for _, descendant in ipairs(sectionAdd:GetDescendants()) do
                                if descendant:IsA("GuiObject") and descendant:GetAttribute("OxideSectionItem") then
                                    table.insert(searchableItems, descendant)
                                end
                            end

                            for _, item in ipairs(searchableItems) do
                                local match = query == ""
                                if not match then
                                    for _, desc in ipairs(item:GetDescendants()) do
                                        if desc:IsA("TextLabel") and (string.find(desc.Name, "Title") or string.find(desc.Name, "Text")) then
                                            local txt = string.lower(desc.Text)
                                            if string.find(txt, query, 1, true) then
                                                match = true
                                                if not jumpedToTab then
                                                    jumpedToTab = true
                                                    for _, sideTab in pairs(ScrollTab:GetChildren()) do
                                                        if sideTab.Name == "Tab" and sideTab.LayoutOrder == scrolLayers.LayoutOrder then
                                                            local selectEvt = sideTab:FindFirstChild("SelectEvent")
                                                            if selectEvt then selectEvt:Fire() end
                                                            break
                                                        end
                                                    end
                                                end
                                                break
                                            end
                                        end
                                    end
                                end
                                item.Visible = match
                                if match then sectionVisible = true end
                            end
                            if query ~= "" then
                                section.Visible = sectionVisible
                            else
                                section.Visible = true
                            end
                        end
                    end
                end
            end
        end
    end)

    runCleanup = function(guiAlreadyDestroying)
        if cleanupStarted then return end
        cleanupStarted = true
        isDestroyed = true

        -- Disable every active feature first. This invokes its normal toggle
        -- callback with false but deliberately does not overwrite saved config.
        for index = #activeToggles, 1, -1 do
            local toggle = activeToggles[index]
            if toggle and toggle.Value and toggle.Cleanup then
                local ok, err = pcall(function() toggle:Cleanup() end)
                if not ok then warn("Oxide toggle cleanup error:", err) end
            end
        end

        for index = #closeCallbacks, 1, -1 do
            cleanupResource(closeCallbacks[index])
        end
        table.clear(closeCallbacks)

        for index = #cleanupResources, 1, -1 do
            cleanupResource(cleanupResources[index])
        end
        table.clear(cleanupResources)
        table.clear(activeToggles)

        for key in pairs(windowElementKeys) do
            Elements[key] = nil
        end
        table.clear(windowElementKeys)

        if GlobalEnvironment[ActiveWindowKey] == publicWindow
            or GlobalEnvironment[ActiveWindowKey] == GuiFunc then
            GlobalEnvironment[ActiveWindowKey] = nil
        end

        local toggleGui = CoreGui:FindFirstChild("ToggleUIOxide")
        if toggleGui then toggleGui:Destroy() end
        local notifyGui = CoreGui:FindFirstChild("NotifyGui")
        if notifyGui then notifyGui:Destroy() end
        -- Stop the Koyeb tag service + live tracking when the window closes.
        pcall(stopTagSystem)
        if not guiAlreadyDestroying and OxideOnTop and OxideOnTop.Parent then
            OxideOnTop:Destroy()
        end
    end

    function GuiFunc:Destroy()
        runCleanup(false)
    end

    function GuiFunc:Close()
        runCleanup(false)
    end

    -- Backward-compatible alias.
    function GuiFunc:DestroyGui()
        runCleanup(false)
    end

    -- Lightweight window minimize/restore animation. Only the root UIScale
    -- and root Position are animated, so descendants do not get individual
    -- tweens and the effect remains inexpensive on lower-end devices.
    local MinimizeScale = Instance.new("UIScale")
    MinimizeScale.Name = "MinimizeScale"
    MinimizeScale.Scale = 1
    MinimizeScale.Parent = DropShadowHolder

    local windowAnimationLocked = false
    local restorePosition = DropShadowHolder.Position
    local minimizeDuration = 0.2

    local function offsetPosition(position, yOffset)
        return UDim2.new(
            position.X.Scale,
            position.X.Offset,
            position.Y.Scale,
            position.Y.Offset + yOffset
        )
    end

    -- ════════════════════════════════════════════════════════════════
    -- MINIMIZED PILL - matches the Libary.lua minimized pill: accent logo,
    -- live ping (ms) and FPS, pinned to the top-middle while minimized.
    -- ════════════════════════════════════════════════════════════════
    local MinimizedBar = Instance.new("TextButton")
    MinimizedBar.Name = "MinimizedPill"
    MinimizedBar.Text = ""
    MinimizedBar.AutoButtonColor = false
    MinimizedBar.AnchorPoint = Vector2.new(0.5, 0)
    MinimizedBar.Position = UDim2.new(0.5, 0, 0, 10)
    MinimizedBar.Size = UDim2.new(0, 0, 0, 32)
    MinimizedBar.AutomaticSize = Enum.AutomaticSize.X
    MinimizedBar.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
    MinimizedBar.BorderSizePixel = 0
    MinimizedBar.Visible = false
    MinimizedBar.ZIndex = 200
    MinimizedBar.Parent = OxideOnTop

    Instance.new("UICorner", MinimizedBar).CornerRadius = UDim.new(0, 16)

    local MinimizedBarStroke = Instance.new("UIStroke")
    MinimizedBarStroke.Color = Color3.fromRGB(36, 40, 52)
    MinimizedBarStroke.Thickness = 1
    MinimizedBarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    MinimizedBarStroke.Parent = MinimizedBar

    local MinimizedBarLayout = Instance.new("UIListLayout")
    MinimizedBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MinimizedBarLayout.FillDirection = Enum.FillDirection.Horizontal
    MinimizedBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    MinimizedBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    MinimizedBarLayout.Padding = UDim.new(0, 10)
    MinimizedBarLayout.Parent = MinimizedBar

    local MinimizedBarPadding = Instance.new("UIPadding")
    MinimizedBarPadding.PaddingLeft = UDim.new(0, 14)
    MinimizedBarPadding.PaddingRight = UDim.new(0, 14)
    MinimizedBarPadding.Parent = MinimizedBar

    -- 1. Logo (accent tinted)
    local MinimizedLogoHolder = Instance.new("Frame")
    MinimizedLogoHolder.Name = "LogoHolder"
    MinimizedLogoHolder.Size = UDim2.fromOffset(26, 26)
    MinimizedLogoHolder.LayoutOrder = 1
    MinimizedLogoHolder.BackgroundTransparency = 1
    MinimizedLogoHolder.ClipsDescendants = true
    MinimizedLogoHolder.Parent = MinimizedBar

    local MinimizedLogo = Instance.new("ImageLabel")
    MinimizedLogo.Name = "PillLogo"
    MinimizedLogo.Image = resolveImage(DEFAULT_OXIDE_NOTIFICATION_LOGO)
    MinimizedLogo.BackgroundTransparency = 1
    MinimizedLogo.ImageColor3 = ThemeColors.Accent
    MinimizedLogo.AnchorPoint = Vector2.new(0.5, 0.5)
    MinimizedLogo.Position = UDim2.fromScale(0.5, 0.5)
    MinimizedLogo.Size = UDim2.fromScale(1, 1)
    MinimizedLogo.ScaleType = Enum.ScaleType.Fit
    MinimizedLogo.Parent = MinimizedLogoHolder

    -- 2. Divider
    local MinimizedDiv1 = Instance.new("Frame")
    MinimizedDiv1.Name = "Div1"
    MinimizedDiv1.Size = UDim2.fromOffset(1, 14)
    MinimizedDiv1.LayoutOrder = 2
    MinimizedDiv1.BackgroundColor3 = Color3.fromRGB(70, 84, 116)
    MinimizedDiv1.BorderSizePixel = 0
    MinimizedDiv1.Parent = MinimizedBar

    -- 3. Ping (ms)
    local MinimizedPingFrame = Instance.new("Frame")
    MinimizedPingFrame.Name = "PingFrame"
    MinimizedPingFrame.Size = UDim2.fromOffset(0, 20)
    MinimizedPingFrame.LayoutOrder = 3
    MinimizedPingFrame.AutomaticSize = Enum.AutomaticSize.X
    MinimizedPingFrame.BackgroundTransparency = 1
    MinimizedPingFrame.Parent = MinimizedBar
    local pingLayout = Instance.new("UIListLayout")
    pingLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pingLayout.FillDirection = Enum.FillDirection.Horizontal
    pingLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    pingLayout.Padding = UDim.new(0, 5)
    pingLayout.Parent = MinimizedPingFrame

    local MinimizedWifiIcon = Instance.new("ImageLabel")
    MinimizedWifiIcon.Name = "WifiIcon"
    MinimizedWifiIcon.Image = "rbxassetid://105253464688580"
    MinimizedWifiIcon.LayoutOrder = 1
    MinimizedWifiIcon.ImageColor3 = Color3.fromRGB(75, 215, 125)
    MinimizedWifiIcon.BackgroundTransparency = 1
    MinimizedWifiIcon.Size = UDim2.fromOffset(15, 15)
    MinimizedWifiIcon.ScaleType = Enum.ScaleType.Fit
    MinimizedWifiIcon.Parent = MinimizedPingFrame

    local MinimizedPingLabel = Instance.new("TextLabel")
    MinimizedPingLabel.Name = "PingLabel"
    MinimizedPingLabel.Text = "0ms"
    MinimizedPingLabel.Font = Enum.Font.GothamBold
    MinimizedPingLabel.LayoutOrder = 2
    MinimizedPingLabel.TextSize = 11
    MinimizedPingLabel.TextColor3 = Color3.fromRGB(240, 242, 248)
    MinimizedPingLabel.TextXAlignment = Enum.TextXAlignment.Left
    MinimizedPingLabel.AutomaticSize = Enum.AutomaticSize.X
    MinimizedPingLabel.Size = UDim2.fromOffset(0, 20)
    MinimizedPingLabel.BackgroundTransparency = 1
    MinimizedPingLabel.Parent = MinimizedPingFrame

    -- 4. Divider
    local MinimizedDiv2 = Instance.new("Frame")
    MinimizedDiv2.Name = "Div2"
    MinimizedDiv2.Size = UDim2.fromOffset(1, 14)
    MinimizedDiv2.LayoutOrder = 4
    MinimizedDiv2.BackgroundColor3 = Color3.fromRGB(70, 84, 116)
    MinimizedDiv2.BorderSizePixel = 0
    MinimizedDiv2.Parent = MinimizedBar

    -- 5. FPS
    local MinimizedFpsFrame = Instance.new("Frame")
    MinimizedFpsFrame.Name = "FpsFrame"
    MinimizedFpsFrame.Size = UDim2.fromOffset(0, 20)
    MinimizedFpsFrame.LayoutOrder = 5
    MinimizedFpsFrame.AutomaticSize = Enum.AutomaticSize.X
    MinimizedFpsFrame.BackgroundTransparency = 1
    MinimizedFpsFrame.Parent = MinimizedBar
    local fpsLayout = Instance.new("UIListLayout")
    fpsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    fpsLayout.FillDirection = Enum.FillDirection.Horizontal
    fpsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    fpsLayout.Padding = UDim.new(0, 5)
    fpsLayout.Parent = MinimizedFpsFrame

    local MinimizedFpsIcon = Instance.new("ImageLabel")
    MinimizedFpsIcon.Name = "FpsIcon"
    MinimizedFpsIcon.Image = "rbxassetid://10709772833"
    MinimizedFpsIcon.LayoutOrder = 1
    MinimizedFpsIcon.ImageColor3 = Color3.fromRGB(75, 215, 125)
    MinimizedFpsIcon.BackgroundTransparency = 1
    MinimizedFpsIcon.Size = UDim2.fromOffset(14, 14)
    MinimizedFpsIcon.ScaleType = Enum.ScaleType.Fit
    MinimizedFpsIcon.Parent = MinimizedFpsFrame

    local MinimizedFpsLabel = Instance.new("TextLabel")
    MinimizedFpsLabel.Name = "FpsLabel"
    MinimizedFpsLabel.Text = "60 FPS"
    MinimizedFpsLabel.Font = Enum.Font.GothamBold
    MinimizedFpsLabel.LayoutOrder = 2
    MinimizedFpsLabel.TextSize = 11
    MinimizedFpsLabel.TextColor3 = Color3.fromRGB(240, 242, 248)
    MinimizedFpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    MinimizedFpsLabel.AutomaticSize = Enum.AutomaticSize.X
    MinimizedFpsLabel.Size = UDim2.fromOffset(0, 20)
    MinimizedFpsLabel.BackgroundTransparency = 1
    MinimizedFpsLabel.Parent = MinimizedFpsFrame

    -- Hover glow + click to restore
    MinimizedBar.MouseEnter:Connect(function()
        TweenService:Create(MinimizedBar, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(24, 27, 36) }):Play()
        TweenService:Create(MinimizedBarStroke, TweenInfo.new(0.15), { Color = ThemeColors.Accent }):Play()
    end)
    MinimizedBar.MouseLeave:Connect(function()
        TweenService:Create(MinimizedBar, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(18, 20, 26) }):Play()
        TweenService:Create(MinimizedBarStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(36, 40, 52) }):Play()
    end)
    MinimizedBar.MouseButton1Click:Connect(function()
        CircleClick(MinimizedBar, Mouse.X, Mouse.Y)
        DropShadowHolder.Visible = true
        MinimizedBar.Visible = false
    end)

    -- Live metrics for the minimized pill (same as Libary.lua)
    local MinimizedStats = game:GetService("Stats")
    local MinimizedPingStat = MinimizedStats:FindFirstChild("Network")
        and MinimizedStats.Network:FindFirstChild("ServerStatsItem")
        and MinimizedStats.Network.ServerStatsItem:FindFirstChild("Data Ping")
    local minimizedFpsFrames, minimizedFpsTime = 0, os.clock()
    local minimizedLastFps = 60
    local minimizedRenderConnection = RunService.RenderStepped:Connect(function()
        minimizedFpsFrames = minimizedFpsFrames + 1
        local now = os.clock()
        if now - minimizedFpsTime >= 0.5 then
            minimizedLastFps = math.round(minimizedFpsFrames / (now - minimizedFpsTime))
            minimizedFpsFrames = 0
            minimizedFpsTime = now
            if MinimizedBar.Visible then
                MinimizedFpsLabel.Text = tostring(minimizedLastFps) .. " FPS"
                if minimizedLastFps >= 50 then
                    MinimizedFpsIcon.ImageColor3 = Color3.fromRGB(75, 215, 125)
                elseif minimizedLastFps >= 30 then
                    MinimizedFpsIcon.ImageColor3 = Color3.fromRGB(240, 190, 50)
                else
                    MinimizedFpsIcon.ImageColor3 = Color3.fromRGB(235, 75, 75)
                end
            end
        end
    end)
    trackCleanup(minimizedRenderConnection)

    local minimizedPingThread = task.spawn(function()
        while not isDestroyed do
            task.wait(0.5)
            if MinimizedBar and MinimizedBar.Visible then
                local ping = MinimizedPingStat and math.round(MinimizedPingStat:GetValue()) or 0
                MinimizedPingLabel.Text = ping .. "ms"
                if ping <= 90 then
                    MinimizedWifiIcon.ImageColor3 = Color3.fromRGB(75, 215, 125)
                elseif ping <= 160 then
                    MinimizedWifiIcon.ImageColor3 = Color3.fromRGB(240, 190, 50)
                else
                    MinimizedWifiIcon.ImageColor3 = Color3.fromRGB(235, 75, 75)
                end
            end
        end
    end)
    trackCleanup(minimizedPingThread)

    local function SetWindowVisible(visible)
        if windowAnimationLocked or not DropShadowHolder then return end
        if visible == DropShadowHolder.Visible and not windowAnimationLocked then return end

        windowAnimationLocked = true

        if visible then
            DropShadowHolder.Visible = true
            MinimizeScale.Scale = 0.88
            DropShadowHolder.Position = offsetPosition(restorePosition, 12)

            local scaleTween = TweenService:Create(
                MinimizeScale,
                TweenInfo.new(minimizeDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Scale = 1 }
            )
            local positionTween = TweenService:Create(
                DropShadowHolder,
                TweenInfo.new(minimizeDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Position = restorePosition }
            )
            scaleTween:Play()
            positionTween:Play()
            scaleTween.Completed:Once(function()
                MinimizeScale.Scale = 1
                DropShadowHolder.Position = restorePosition
                MinimizedBar.Visible = false
                windowAnimationLocked = false
            end)
        else
            restorePosition = DropShadowHolder.Position
            local scaleTween = TweenService:Create(
                MinimizeScale,
                TweenInfo.new(minimizeDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
                { Scale = 0.88 }
            )
            local positionTween = TweenService:Create(
                DropShadowHolder,
                TweenInfo.new(minimizeDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
                { Position = offsetPosition(restorePosition, 12) }
            )
            scaleTween:Play()
            positionTween:Play()
            scaleTween.Completed:Once(function()
                DropShadowHolder.Visible = false
                DropShadowHolder.Position = restorePosition
                MinimizeScale.Scale = 1
                MinimizedBar.Visible = true
                windowAnimationLocked = false
            end)
        end
    end

    local function ToggleWindowVisibility()
        SetWindowVisible(not DropShadowHolder.Visible)
    end

    Min.Activated:Connect(function()
        CircleClick(Min, Mouse.X, Mouse.Y)
        SetWindowVisible(false)
    end)
    Close.Activated:Connect(function()
        CircleClick(Close, Mouse.X, Mouse.Y)

        local Overlay = Instance.new("Frame")
        Overlay.Size = UDim2.new(1, 0, 1, 0)
        Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Overlay.BackgroundTransparency = 0.3
        Overlay.ZIndex = 50
        Overlay.Parent = DropShadowHolder

        local Dialog = Instance.new("ImageLabel")
        Dialog.Size = UDim2.new(0, 300, 0, 150)
        Dialog.Position = UDim2.new(0.5, -150, 0.5, -75)
        Dialog.Image = "rbxassetid://9542022979"
        Dialog.ImageTransparency = 0
        Dialog.BorderSizePixel = 0
        Dialog.ZIndex = 51
        Dialog.Parent = Overlay
        local UICorner = Instance.new("UICorner", Dialog)
        UICorner.CornerRadius = UDim.new(0, 8)

        local DialogGlow = Instance.new("Frame")
        DialogGlow.Size = UDim2.new(0, 310, 0, 160)
        DialogGlow.Position = UDim2.new(0.5, -155, 0.5, -80)
        DialogGlow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        DialogGlow.BackgroundTransparency = 0.75
        DialogGlow.BorderSizePixel = 0
        DialogGlow.ZIndex = 50
        DialogGlow.Parent = Overlay

        local GlowCorner = Instance.new("UICorner", DialogGlow)
        GlowCorner.CornerRadius = UDim.new(0, 10)

        local Gradient = Instance.new("UIGradient")
        Gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 191, 255)),
            ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 140, 255)),
            ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1.0, Color3.fromRGB(0, 191, 255))
        })
        Gradient.Rotation = 90
        Gradient.Parent = DialogGlow

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, 0, 0, 40)
        Title.Position = UDim2.new(0, 0, 0, 4)
        Title.BackgroundTransparency = 1
        Title.Font = Enum.Font.GothamBold
        Title.Text = "Oxide Window"
        Title.TextSize = 22
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.ZIndex = 52
        Title.Parent = Dialog

        local Message = Instance.new("TextLabel")
        Message.Size = UDim2.new(1, -20, 0, 60)
        Message.Position = UDim2.new(0, 10, 0, 30)
        Message.BackgroundTransparency = 1
        Message.Font = Enum.Font.Gotham
        Message.Text = "Do you want to close this window?\nYou will not be able to open it again"
        Message.TextSize = 14
        Message.TextColor3 = Color3.fromRGB(200, 200, 200)
        Message.TextWrapped = true
        Message.ZIndex = 52
        Message.Parent = Dialog

        local Yes = Instance.new("TextButton")
        Yes.Size = UDim2.new(0.45, -10, 0, 35)
        Yes.Position = UDim2.new(0.05, 0, 1, -55)
        Yes.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Yes.BackgroundTransparency = 0.935
        Yes.Text = "Yes"
        Yes.Font = Enum.Font.GothamBold
        Yes.TextSize = 15
        Yes.TextColor3 = Color3.fromRGB(255, 255, 255)
        Yes.TextTransparency = 0.3
        Yes.ZIndex = 52
        Yes.Name = "Yes"
        Yes.Parent = Dialog
        Instance.new("UICorner", Yes).CornerRadius = UDim.new(0, 6)

        local Cancel = Instance.new("TextButton")
        Cancel.Size = UDim2.new(0.45, -10, 0, 35)
        Cancel.Position = UDim2.new(0.5, 10, 1, -55)
        Cancel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Cancel.BackgroundTransparency = 0.935
        Cancel.Text = "Cancel"
        Cancel.Font = Enum.Font.GothamBold
        Cancel.TextSize = 15
        Cancel.TextColor3 = Color3.fromRGB(255, 255, 255)
        Cancel.TextTransparency = 0.3
        Cancel.ZIndex = 52
        Cancel.Name = "Cancel"
        Cancel.Parent = Dialog
        Instance.new("UICorner", Cancel).CornerRadius = UDim.new(0, 6)

        Yes.MouseButton1Click:Connect(function()
            runCleanup(false)
        end)

        Cancel.MouseButton1Click:Connect(function()
            Overlay:Destroy()
        end)
    end)

    -- Profile panels toggle (K, like the old UI); assigned below.
    local ToggleProfilePanels

    -- Press Alt to minimize/restore the UI; override with
    -- GuiConfig.ToggleKey (an EnumItem).
    local ToggleKey = typeof(GuiConfig.ToggleKey) == "EnumItem" and GuiConfig.ToggleKey or Enum.KeyCode.LeftAlt
    trackCleanup(UserInputService.InputBegan:Connect(function(input, gpe)
        if isDestroyed or gpe then return end
        if not loadingComplete then return end
        if input.KeyCode == ToggleKey then
            ToggleWindowVisibility()
        end
    end))

    -- Press K to open/close the profile + live performance panels (old UI
    -- behavior); override with GuiConfig.ProfileKey (an EnumItem).
    local ProfileKey = typeof(GuiConfig.ProfileKey) == "EnumItem" and GuiConfig.ProfileKey or Enum.KeyCode.K
    trackCleanup(UserInputService.InputBegan:Connect(function(input, gpe)
        if isDestroyed or gpe then return end
        if not loadingComplete then return end
        if UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == ProfileKey and ToggleProfilePanels then
            ToggleProfilePanels()
        end
    end))



    DropShadowHolder.Size = UDim2.new(0, 115 + TextLabel.TextBounds.X + 1 + TextLabel1.TextBounds.X, 0, 350)
    MakeDraggable(
        Top,
        DropShadowHolder,
        trackCleanup,
        DefaultWindowWidth,
        DefaultWindowHeight,
        UseMobileLayout
    )
    local isFullscreen = false
    local originalSize = DropShadowHolder.Size
    local originalPos  = DropShadowHolder.Position

    FullScreen.Activated:Connect(function()
        CircleClick(FullScreen, Mouse.X, Mouse.Y)
        isFullscreen = not isFullscreen

        if isFullscreen then
            -- simpan size & pos sebelum fullscreen
            originalSize = DropShadowHolder.Size
            originalPos  = DropShadowHolder.Position

            TweenService:Create(DropShadowHolder, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size     = UDim2.new(0.980000019, 0, 0.949999988, 0),
                Position = UDim2.new(0.5, 0, 0.5, 0),
            }):Play()
        else
            TweenService:Create(DropShadowHolder, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size     = originalSize,
                Position = originalPos,
            }):Play()
        end
    end)

    local MoreBlur = Instance.new("Frame");
    local DropShadowHolder1 = Instance.new("Frame");
    local DropShadow1 = Instance.new("ImageLabel");
    local UICorner28 = Instance.new("UICorner");
    local ConnectButton = Instance.new("TextButton");

    MoreBlur.AnchorPoint = Vector2.new(1, 1)
    MoreBlur.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    MoreBlur.BackgroundTransparency = 0.999
    MoreBlur.BorderColor3 = Color3.fromRGB(0, 0, 0)
    MoreBlur.BorderSizePixel = 0
    MoreBlur.ClipsDescendants = true
    MoreBlur.Position = UDim2.new(1, 8, 1, 8)
    MoreBlur.Size = UDim2.new(1, 154, 1, 54)
    MoreBlur.Visible = false
    MoreBlur.Name = "MoreBlur"
    MoreBlur.Parent = Layers

    DropShadowHolder1.BackgroundTransparency = 1
    DropShadowHolder1.BorderSizePixel = 0
    DropShadowHolder1.Size = UDim2.new(1, 0, 1, 0)
    DropShadowHolder1.ZIndex = 0
    DropShadowHolder1.Name = "DropShadowHolder"
    DropShadowHolder1.Parent = MoreBlur

    DropShadow1.Image = "rbxassetid://6015897843"
    DropShadow1.ImageColor3 = Color3.fromRGB(0, 0, 0)
    DropShadow1.ImageTransparency = 1
    DropShadow1.ScaleType = Enum.ScaleType.Slice
    DropShadow1.SliceCenter = Rect.new(49, 49, 450, 450)
    DropShadow1.AnchorPoint = Vector2.new(0.5, 0.5)
    DropShadow1.BackgroundTransparency = 1
    DropShadow1.BorderSizePixel = 0
    DropShadow1.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropShadow1.Size = UDim2.new(1, 35, 1, 35)
    DropShadow1.ZIndex = 0
    DropShadow1.Name = "DropShadow"
    DropShadow1.Parent = DropShadowHolder1

    UICorner28.Parent = MoreBlur

    ConnectButton.Font = Enum.Font.SourceSans
    ConnectButton.Text = ""
    ConnectButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    ConnectButton.TextSize = 14
    ConnectButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ConnectButton.BackgroundTransparency = 0.999
    ConnectButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ConnectButton.BorderSizePixel = 0
    ConnectButton.Size = UDim2.new(1, 0, 1, 0)
    ConnectButton.Name = "ConnectButton"
    ConnectButton.Parent = MoreBlur

    local DropdownSelect = Instance.new("Frame");
    local UICorner36 = Instance.new("UICorner");
    local UIStroke14 = Instance.new("UIStroke");
    local DropdownSelectReal = Instance.new("Frame");
    local DropdownFolder = Instance.new("Folder");
    local DropPageLayout = Instance.new("UIPageLayout");

    DropdownSelect.AnchorPoint = Vector2.new(1, 0.5)
    DropdownSelect.BackgroundColor3 = Color3.fromRGB(30.00000011175871, 30.00000011175871, 30.00000011175871)
    DropdownSelect.BorderColor3 = Color3.fromRGB(0, 0, 0)
    DropdownSelect.BorderSizePixel = 0
    DropdownSelect.LayoutOrder = 1
    DropdownSelect.Position = UDim2.new(1, 172, 0.5, 0)
    DropdownSelect.Size = UDim2.new(0, 160, 1, -16)
    DropdownSelect.Name = "DropdownSelect"
    DropdownSelect.ClipsDescendants = true
    DropdownSelect.Parent = MoreBlur

    ConnectButton.Activated:Connect(function()
        if MoreBlur.Visible then
            TweenService:Create(MoreBlur, TweenInfo.new(0.3), { BackgroundTransparency = 0.999 }):Play()
            TweenService:Create(DropdownSelect, TweenInfo.new(0.3), { Position = UDim2.new(1, 172, 0.5, 0) }):Play()
            task.wait(0.3)
            MoreBlur.Visible = false
        end
    end)
    UICorner36.CornerRadius = UDim.new(0, 3)
    UICorner36.Parent = DropdownSelect

    UIStroke14.Color = Color3.fromRGB(12, 159, 255)
    UIStroke14.Thickness = 2.5
    UIStroke14.Transparency = 0.8
    UIStroke14.Parent = DropdownSelect

    DropdownSelectReal.AnchorPoint = Vector2.new(0.5, 0.5)
    DropdownSelectReal.BackgroundColor3 = Color3.fromRGB(30, 30, 30) -- Latar Warna Dropdown
    DropdownSelectReal.BackgroundTransparency = 0.7
    DropdownSelectReal.BorderColor3 = Color3.fromRGB(0, 0, 0)
    DropdownSelectReal.BorderSizePixel = 0
    DropdownSelectReal.LayoutOrder = 1
    DropdownSelectReal.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropdownSelectReal.Size = UDim2.new(1, 1, 1, 1)
    DropdownSelectReal.Name = "DropdownSelectReal"
    DropdownSelectReal.Parent = DropdownSelect

    DropdownFolder.Name = "DropdownFolder"
    DropdownFolder.Parent = DropdownSelectReal

    DropPageLayout.EasingDirection = Enum.EasingDirection.InOut
    DropPageLayout.EasingStyle = Enum.EasingStyle.Quad
    DropPageLayout.TweenTime = 0.009999999776482582
    DropPageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    DropPageLayout.FillDirection = Enum.FillDirection.Vertical
    DropPageLayout.Archivable = false
    DropPageLayout.Name = "DropPageLayout"
    DropPageLayout.Parent = DropdownFolder
    --// Tabs
    local Tabs = {}
    publicWindow = Tabs
    GlobalEnvironment[ActiveWindowKey] = Tabs

    -- The public Window object is Tabs. Forward lifecycle methods from the
    -- internal controller so scripts can manage every feature from Window.
    function Tabs:AddCleanup(resource)
        return GuiFunc:AddCleanup(resource)
    end
    function Tabs:OnClose(callback)
        return GuiFunc:OnClose(callback)
    end
    function Tabs:CreateCleanupToken()
        return GuiFunc:CreateCleanupToken()
    end
    function Tabs:Spawn(callback)
        return GuiFunc:Spawn(callback)
    end
    function Tabs:IsDestroyed()
        return GuiFunc:IsDestroyed()
    end
    function Tabs:Destroy()
        return GuiFunc:Destroy()
    end
    function Tabs:Close()
        return GuiFunc:Close()
    end
    function Tabs:DestroyGui()
        return GuiFunc:DestroyGui()
    end

    local CountTab = 0
    local CountDropdown = 0
    local BuiltInInfoTab
    local PageTransitionToken = 0

    local function SetSectionArrowsVisible(visible)
        for _, descendant in ipairs(LayersFolder:GetDescendants()) do
            if descendant.Name == "FeatureImg" and descendant:IsA("ImageLabel") then
                descendant.Visible = visible
            end
        end
    end

    local function HideArrowsDuringPageTransition()
        PageTransitionToken = PageTransitionToken + 1
        local token = PageTransitionToken
        SetSectionArrowsVisible(false)
        task.delay(LayersPageLayout.TweenTime + 0.04, function()
            if token == PageTransitionToken then
                SetSectionArrowsVisible(true)
            end
        end)
    end
    function Tabs:AddTab(TabConfig)
        local TabConfig = TabConfig or {}
        TabConfig.Name = TabConfig.Name or "Tab"
        TabConfig.Icon = TabConfig.Icon or ""

        -- Script lama yang masih membuat tab Info tidak menghasilkan duplikat.
        if BuiltInInfoTab and tostring(TabConfig.Name):lower() == "info" then
            return BuiltInInfoTab
        end

        local ScrolLayers = Instance.new("ScrollingFrame");
        local UIListLayout1 = Instance.new("UIListLayout");

        ScrolLayers.ScrollBarImageColor3 = Color3.fromRGB(80.00000283122063, 80.00000283122063, 80.00000283122063)
        ScrolLayers.ScrollBarThickness = 0
        ScrolLayers.Active = true
        ScrolLayers.LayoutOrder = CountTab
        ScrolLayers.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ScrolLayers.BackgroundTransparency = 0.9990000128746033
        ScrolLayers.BorderColor3 = Color3.fromRGB(0, 0, 0)
        ScrolLayers.BorderSizePixel = 0
        ScrolLayers.Size = UDim2.new(1, 0, 1, 0)
        ScrolLayers.Name = "ScrolLayers"
        ScrolLayers.Parent = LayersFolder

        -- Balanced section rhythm: enough separation from the previous box
        -- without making stacked sections feel disconnected.
        UIListLayout1.Padding = UDim.new(0, 5)
        UIListLayout1.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout1.Parent = ScrolLayers

        local Tab = Instance.new("Frame");
        local UICorner3 = Instance.new("UICorner");
        local TabButton = Instance.new("TextButton");
        local TabName = Instance.new("TextLabel")
        local TabIconImg
        local UIStroke2 = Instance.new("UIStroke");
        local UICorner4 = Instance.new("UICorner");

        Tab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        if CountTab == 0 then
            Tab.BackgroundTransparency = 0.9200000166893005
        else
            Tab.BackgroundTransparency = 0.9990000128746033
        end
        Tab.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Tab.BorderSizePixel = 0
        Tab.LayoutOrder = CountTab
        Tab.Size = UDim2.new(1, 0, 0, 30)
        Tab.Name = "Tab"
        Tab.Parent = ScrollTab

        UICorner3.CornerRadius = UDim.new(0, 4)
        UICorner3.Parent = Tab

        TabButton.Font = Enum.Font.GothamBold
        TabButton.Text = ""
        TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabButton.TextSize = 13
        TabButton.TextXAlignment = Enum.TextXAlignment.Left
        TabButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TabButton.BackgroundTransparency = 0.9990000128746033
        TabButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
        TabButton.BorderSizePixel = 0
        TabButton.Size = UDim2.new(1, 0, 1, 0)
        TabButton.Name = "TabButton"
        TabButton.Parent = Tab

        local textOffsetX = 8

        if TabConfig.Icon and TabConfig.Icon ~= "" then
            TabIconImg = Instance.new("ImageLabel")
            TabIconImg.Name = "TabIcon"
            TabIconImg.Size = UDim2.fromOffset(14, 14)
            TabIconImg.Position = UDim2.new(0, 8, 0.5, 0)
            TabIconImg.AnchorPoint = Vector2.new(0, 0.5)
            TabIconImg.BackgroundTransparency = 1
            TabIconImg.Image = resolveIcon(TabConfig.Icon)
            TabIconImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
            TabIconImg.ImageTransparency = CountTab == 0 and 0 or 0.4
            TabIconImg.ScaleType = Enum.ScaleType.Fit
            TabIconImg.Parent = Tab
            textOffsetX = 28
        end

        TabName.Font = Enum.Font.GothamMedium
        TabName.Text = tostring(TabConfig.Name)
        TabName.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabName.TextSize = 12
        TabName.TextTransparency = CountTab == 0 and 0 or 0.4
        TabName.TextXAlignment = Enum.TextXAlignment.Left
        TabName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TabName.BackgroundTransparency = 0.9990000128746033
        TabName.BorderColor3 = Color3.fromRGB(0, 0, 0)
        TabName.BorderSizePixel = 0
        TabName.Size = UDim2.new(1, -textOffsetX, 1, 0)
        TabName.Position = UDim2.new(0, textOffsetX, 0, 0)
        TabName.Name = "TabName"
        TabName.Parent = Tab

        if CountTab == 0 then
            LayersPageLayout:JumpToIndex(0)
            NameTab.Text = TabConfig.Name
            local ChooseFrame = Instance.new("Frame");
            ChooseFrame.BackgroundColor3 = GuiConfig.Color
            ChooseFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
            ChooseFrame.BorderSizePixel = 0
            ChooseFrame.Position = UDim2.new(0, 2, 0, 9)
            ChooseFrame.Size = UDim2.new(0, 1, 0, 12)
            ChooseFrame.Name = "ChooseFrame"
            ChooseFrame.Parent = Tab

            UIStroke2.Color = GuiConfig.Color
            UIStroke2.Thickness = 1.600000023841858
            UIStroke2.Parent = ChooseFrame

            UICorner4.Parent = ChooseFrame
        end

        local SelectEvent = Instance.new("BindableEvent")
        SelectEvent.Name = "SelectEvent"
        SelectEvent.Parent = Tab

        TabButton.Activated:Connect(function()
            CircleClick(TabButton, Mouse.X, Mouse.Y)
            SelectEvent:Fire()
        end)

        SelectEvent.Event:Connect(function()
            local FrameChoose
            for a, s in ScrollTab:GetChildren() do
                for i, v in s:GetChildren() do
                    if v.Name == "ChooseFrame" then
                        FrameChoose = v
                        break
                    end
                end
            end
            if FrameChoose ~= nil and Tab.LayoutOrder ~= LayersPageLayout.CurrentPage.LayoutOrder then
                for _, TabFrame in ScrollTab:GetChildren() do
                    if TabFrame.Name == "Tab" then
                        TweenService:Create(
                            TabFrame,
                            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
                            { BackgroundTransparency = 0.9990000128746033 }
                        ):Play()
                        
                        local tIcon = TabFrame:FindFirstChild("TabIcon")
                        local tName = TabFrame:FindFirstChild("TabName")
                        if tIcon then
                            TweenService:Create(tIcon, TweenInfo.new(0.3), { ImageTransparency = 0.4 }):Play()
                        end
                        if tName then
                            TweenService:Create(tName, TweenInfo.new(0.3), { TextTransparency = 0.4 }):Play()
                        end
                    end
                end
                TweenService:Create(
                    Tab,
                    TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
                    { BackgroundTransparency = 0.9200000166893005 }
                ):Play()
                
                if TabIconImg then
                    TweenService:Create(TabIconImg, TweenInfo.new(0.6), { ImageTransparency = 0 }):Play()
                end
                TweenService:Create(TabName, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()

                TweenService:Create(
                    FrameChoose,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                    { Position = UDim2.new(0, 2, 0, 9 + (33 * Tab.LayoutOrder)) }
                ):Play()
                HideArrowsDuringPageTransition()
                LayersPageLayout:JumpToIndex(Tab.LayoutOrder)
                task.wait(0.05)
                NameTab.Text = TabConfig.Name
                TweenService:Create(
                    FrameChoose,
                    TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                    { Size = UDim2.new(0, 1, 0, 20) }
                ):Play()
                task.wait(0.2)
                TweenService:Create(
                    FrameChoose,
                    TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                    { Size = UDim2.new(0, 1, 0, 12) }
                ):Play()
            end
        end)
        --// Section
        local Sections = {}
        local CountSection = 0
        function Sections:AddSection(Title, AlwaysOpen)
            local SectionConfig = {}
            if type(Title) == "table" then
                SectionConfig = Title
                Title = SectionConfig.Title or SectionConfig.Name
            elseif type(AlwaysOpen) == "table" then
                SectionConfig = AlwaysOpen
            end
            local Title = Title or "Title"
            local LayoutMode = tostring(SectionConfig.Layout or "Grid"):lower()
            local UseIndependentColumns = LayoutMode == "columns" or LayoutMode == "column"
            local ColumnGap = math.max(0, tonumber(SectionConfig.ColumnGap) or 6)
            local ItemGap = math.max(0, tonumber(SectionConfig.ItemGap) or 2)

            -- Sections are intentionally always open. A boolean second
            -- argument is retained only for backward API compatibility;
            -- a table config enables script-controlled layout behavior.
            local Section = Instance.new("Frame")
            Section.Name = "Section"
            Section.BackgroundTransparency = 1
            Section.BorderSizePixel = 0
            Section.ClipsDescendants = false
            Section.LayoutOrder = CountSection
            Section.Size = UDim2.new(1, 0, 0, 36)
            Section.Parent = ScrolLayers

            local SectionReal = Instance.new("Frame")
            SectionReal.Name = "SectionReal"
            SectionReal.BackgroundTransparency = 1
            SectionReal.BorderSizePixel = 0
            SectionReal.Position = UDim2.fromOffset(0, 0)
            SectionReal.Size = UDim2.new(1, 0, 0, SectionConfig.HideTitle and 0 or 20)
            SectionReal.Parent = Section

            local SectionTitle = Instance.new("TextLabel")
            SectionTitle.Name = "SectionTitle"
            SectionTitle.Font = Enum.Font.GothamBold
            SectionTitle.Text = Title
            SectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
            SectionTitle.TextSize = tonumber(SectionConfig.TextSize) or 13
            SectionTitle.TextTransparency = math.clamp(tonumber(SectionConfig.TextTransparency) or 0, 0, 1)
            local titleAlignment = tostring(SectionConfig.TextXAlignment or "Left"):lower()
            SectionTitle.TextXAlignment = titleAlignment == "center" and Enum.TextXAlignment.Center
                or titleAlignment == "right" and Enum.TextXAlignment.Right
                or Enum.TextXAlignment.Left
            SectionTitle.TextYAlignment = Enum.TextYAlignment.Top
            SectionTitle.BackgroundTransparency = 1
            -- Lower only the title text; the section box geometry stays fixed.
            SectionTitle.Position = UDim2.fromOffset(6, 1)
            SectionTitle.Size = UDim2.new(1, -12, 0, 18)
            SectionTitle.Visible = not SectionConfig.HideTitle
            SectionTitle.Parent = SectionReal

            local SectionContentOffset = SectionConfig.HideTitle and 0 or 20
            local SectionAdd = Instance.new("Frame")
            SectionAdd.Name = "SectionAdd"
            SectionAdd.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
            SectionAdd.BackgroundTransparency = 0.28
            SectionAdd.BorderSizePixel = 0
            SectionAdd.ClipsDescendants = true
            -- 2px inset keeps the Border stroke visible on both sides.
            SectionAdd.Position = UDim2.fromOffset(2, SectionContentOffset)
            SectionAdd.Size = UDim2.new(1, -4, 0, 0)
            SectionAdd.Parent = Section

            local SectionAddCorner = Instance.new("UICorner")
            SectionAddCorner.CornerRadius = UDim.new(0, 6)
            SectionAddCorner.Parent = SectionAdd

            -- Popup portal for dropdown menus. It lives at section level so
            -- buttons outside a 46px dropdown row remain hit-testable, while
            -- still moving together with the section when the page scrolls.
            local SectionOverlay = Instance.new("Frame")
            SectionOverlay.Name = "SectionOverlay"
            SectionOverlay.BackgroundTransparency = 1
            SectionOverlay.BorderSizePixel = 0
            SectionOverlay.Position = SectionAdd.Position
            SectionOverlay.Size = SectionAdd.Size
            SectionOverlay.Active = false
            SectionOverlay.ZIndex = 80
            SectionOverlay.Parent = Section

            local SectionAddStroke = Instance.new("UIStroke")
            SectionAddStroke.Name = "SectionOutline"
            SectionAddStroke.Color = Color3.fromRGB(35, 35, 35)
            SectionAddStroke.Transparency = 0.22
            SectionAddStroke.Thickness = 1
            SectionAddStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            SectionAddStroke.Parent = SectionAdd

            local RowsLayout = Instance.new("UIListLayout")
            RowsLayout.Name = "RowsLayout"
            RowsLayout.Padding = UDim.new(0, ItemGap)
            RowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
            RowsLayout.Parent = SectionAdd

            local UIPadding = Instance.new("UIPadding")
            UIPadding.PaddingTop = UDim.new(0, 4)
            UIPadding.PaddingBottom = UDim.new(0, 8)
            UIPadding.PaddingLeft = UDim.new(0, 8)
            UIPadding.PaddingRight = UDim.new(0, 8)
            UIPadding.Parent = SectionAdd

            local function UpdateSizeScroll()
                local layout = ScrolLayers:FindFirstChildOfClass("UIListLayout")
                if layout then
                    ScrolLayers.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
                end
            end

            local function UpdateSizeSection()
                local contentHeight = RowsLayout.AbsoluteContentSize.Y + 16 -- account for top/bottom padding
                SectionAdd.Size = UDim2.new(1, -4, 0, contentHeight)
                SectionOverlay.Position = SectionAdd.Position
                SectionOverlay.Size = SectionAdd.Size
                Section.Size = UDim2.new(1, 0, 0, SectionContentOffset + contentHeight)
                task.defer(UpdateSizeScroll)
            end

            RowsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateSizeSection)

            local NextItem = 0
            local PendingRow
            local RowsByIndex = {}
            local ColumnsRow
            local ColumnCells = {}
            local ColumnLayouts = {}
            local NextColumnOrder = { Left = 0, Right = 0 }

            local function updateColumnsHeight()
                if not ColumnsRow then return end
                local leftHeight = ColumnLayouts.Left and ColumnLayouts.Left.AbsoluteContentSize.Y or 0
                local rightHeight = ColumnLayouts.Right and ColumnLayouts.Right.AbsoluteContentSize.Y or 0
                local height = math.max(leftHeight, rightHeight)
                if ColumnCells.Left then ColumnCells.Left.Size = UDim2.new(0.5, -(ColumnGap / 2), 0, leftHeight) end
                if ColumnCells.Right then ColumnCells.Right.Size = UDim2.new(0.5, -(ColumnGap / 2), 0, rightHeight) end
                ColumnsRow.Size = UDim2.new(1, 0, 0, height)
                task.defer(UpdateSizeSection)
            end

            local function ensureColumnsRow(order)
                if ColumnsRow then
                    ColumnsRow.LayoutOrder = math.min(ColumnsRow.LayoutOrder, order)
                    return ColumnsRow
                end

                ColumnsRow = Instance.new("Frame")
                ColumnsRow.Name = "SectionColumns"
                ColumnsRow:SetAttribute("OxideLayout", "Columns")
                ColumnsRow.BackgroundTransparency = 1
                ColumnsRow.BorderSizePixel = 0
                ColumnsRow.LayoutOrder = order
                ColumnsRow.Size = UDim2.new(1, 0, 0, 0)
                ColumnsRow.Parent = SectionAdd

                for _, column in ipairs({ "Left", "Right" }) do
                    local isLeft = column == "Left"
                    local cell = Instance.new("Frame")
                    cell.Name = column .. "Column"
                    cell.BackgroundTransparency = 1
                    cell.BorderSizePixel = 0
                    cell.Position = isLeft
                        and UDim2.fromOffset(0, 0)
                        or UDim2.new(0.5, ColumnGap / 2, 0, 0)
                    cell.Size = UDim2.new(0.5, -(ColumnGap / 2), 0, 0)
                    cell.Parent = ColumnsRow
                    ColumnCells[column] = cell

                    local list = Instance.new("UIListLayout")
                    list.Name = column .. "Layout"
                    list.Padding = UDim.new(0, ItemGap)
                    list.SortOrder = Enum.SortOrder.LayoutOrder
                    list.Parent = cell
                    ColumnLayouts[column] = list
                    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateColumnsHeight)
                end

                task.defer(updateColumnsHeight)
                return ColumnsRow
            end

            local function columnOrderOccupied(column, order)
                local cell = ColumnCells[column]
                if not cell then return false end
                for _, child in ipairs(cell:GetChildren()) do
                    if child:IsA("GuiObject") and child.LayoutOrder == order then
                        return true
                    end
                end
                return false
            end

            local function mountIndependentColumnItem(item, column, explicitRow)
                local order = explicitRow and (explicitRow - 1) or NextColumnOrder[column]
                ensureColumnsRow(order)
                if columnOrderOccupied(column, order) then
                    local requested = order + 1
                    repeat order = order + 1 until not columnOrderOccupied(column, order)
                    warn(("Oxide UI: Row %d Column %s is occupied; using Row %d."):format(requested, column, order + 1))
                end
                NextColumnOrder[column] = math.max(NextColumnOrder[column], order + 1)
                ColumnsRow.LayoutOrder = math.min(ColumnsRow.LayoutOrder, order)

                item:SetAttribute("OxideSectionItem", true)
                item:SetAttribute("OxideColumn", column)
                item:SetAttribute("OxideRow", order + 1)
                item.LayoutOrder = order
                item.AnchorPoint = Vector2.zero
                item.Position = UDim2.fromOffset(0, 0)
                item.Size = UDim2.new(1, 0, item.Size.Y.Scale, item.Size.Y.Offset)
                item.BackgroundTransparency = 1
                item.BorderSizePixel = 0
                item.Parent = ColumnCells[column]

                item:GetPropertyChangedSignal("Size"):Connect(updateColumnsHeight)
                item:GetPropertyChangedSignal("Visible"):Connect(updateColumnsHeight)
                task.defer(updateColumnsHeight)
            end

            local function updateRowHeight(row)
                if not row then return end
                local leftCell = row:FindFirstChild("LeftCell")
                local rightCell = row:FindFirstChild("RightCell")
                local fullCell = row:FindFirstChild("FullCell")
                local function cellHeight(cell)
                    if not cell then return 0 end
                    local item = cell:FindFirstChildWhichIsA("GuiObject")
                    return (item and item.Visible) and item.Size.Y.Offset or 0
                end
                local height
                if fullCell then
                    height = cellHeight(fullCell)
                    fullCell.Size = UDim2.new(1, 0, 0, height)
                else
                    local leftHeight = cellHeight(leftCell)
                    local rightHeight = cellHeight(rightCell)
                    height = math.max(leftHeight, rightHeight)
                    if leftCell then leftCell.Size = UDim2.new(0.5, -3, 0, height) end
                    if rightCell then rightCell.Size = UDim2.new(0.5, -3, 0, height) end
                end
                row.Size = UDim2.new(1, 0, 0, height)
                task.defer(UpdateSizeSection)
            end

            local function makeRow(order)
                if RowsByIndex[order] then return RowsByIndex[order] end
                local row = Instance.new("Frame")
                row.Name = "SectionRow"
                row:SetAttribute("OxideRow", order + 1)
                row.BackgroundTransparency = 1
                row.BorderSizePixel = 0
                row.LayoutOrder = order
                row.Size = UDim2.new(1, 0, 0, 0)
                row.Parent = SectionAdd
                RowsByIndex[order] = row
                return row
            end

            local function rowHasSlot(row, column)
                if not row then return false end
                if column == "Full" then
                    return not row:FindFirstChild("FullCell")
                        and not row:FindFirstChild("LeftCell")
                        and not row:FindFirstChild("RightCell")
                end
                return not row:FindFirstChild("FullCell")
                    and not row:FindFirstChild(column .. "Cell")
            end

            local function findAvailableRow(column, startIndex)
                local index = math.max(0, startIndex or 0)
                while not rowHasSlot(RowsByIndex[index], column) and RowsByIndex[index] do
                    index = index + 1
                end
                return index
            end

            local function MountSectionItem(item, config, defaultFullWidth)
                config = config or {}
                local requestedColumn = config.Column
                if type(requestedColumn) == "string" then
                    requestedColumn = requestedColumn:sub(1, 1):upper() .. requestedColumn:sub(2):lower()
                end
                if requestedColumn ~= "Left" and requestedColumn ~= "Right" and requestedColumn ~= "Full" then
                    requestedColumn = nil
                end

                -- Column is the primary public layout API. Normalize
                -- FullWidth so component-specific visual layouts (dropdown,
                -- slider, etc.) automatically match the requested column.
                if requestedColumn == "Left" or requestedColumn == "Right" then
                    -- Mobile stacks both sides as full-width cards. Component
                    -- internals (input/dropdown label geometry) should also use
                    -- their full-width variant.
                    config.FullWidth = UseMobileLayout and true or false
                elseif requestedColumn == "Full" then
                    config.FullWidth = true
                end

                local explicitRow = tonumber(config.Row)
                if explicitRow then explicitRow = math.max(1, math.floor(explicitRow)) end

                local fullWidth = requestedColumn == "Full"
                    or (requestedColumn == nil and config.FullWidth == true)
                    or (requestedColumn == nil and config.FullWidth == nil and defaultFullWidth)

                local column = fullWidth and "Full" or requestedColumn
                local rowIndex

                if UseMobileLayout and not fullWidth then
                    if column ~= "Left" and column ~= "Right" then
                        column = (NextItem % 2 == 0) and "Left" or "Right"
                        NextItem = NextItem + 1
                    end
                    local mobileRow = explicitRow and (explicitRow - 1)
                        or math.floor(NextItem / 2)
                    local mobileOrder = mobileRow * 3 + (column == "Right" and 1 or 0)

                    local row = Instance.new("Frame")
                    row.Name = "SectionRow"
                    row:SetAttribute("OxideRow", mobileRow + 1)
                    row:SetAttribute("OxideMobileStack", true)
                    row.BackgroundTransparency = 1
                    row.BorderSizePixel = 0
                    row.LayoutOrder = mobileOrder
                    row.Size = UDim2.new(1, 0, 0, item.Size.Y.Offset)
                    row.Parent = SectionAdd

                    local cell = Instance.new("Frame")
                    cell.Name = "FullCell"
                    cell.BackgroundTransparency = 1
                    cell.BorderSizePixel = 0
                    cell.Size = UDim2.new(1, 0, 0, item.Size.Y.Offset)
                    cell.Parent = row

                    item:SetAttribute("OxideSectionItem", true)
                    item:SetAttribute("OxideColumn", column)
                    item:SetAttribute("OxideRow", mobileRow + 1)
                    item:SetAttribute("OxideMobileStack", true)
                    item.LayoutOrder = 0
                    item.AnchorPoint = Vector2.zero
                    item.Position = UDim2.fromOffset(0, 0)
                    item.Size = UDim2.new(1, 0, item.Size.Y.Scale, item.Size.Y.Offset)
                    item.BackgroundTransparency = 1
                    item.BorderSizePixel = 0
                    item.Parent = cell

                    local function refreshMobileRow()
                        local height = item.Visible and item.Size.Y.Offset or 0
                        cell.Size = UDim2.new(1, 0, 0, height)
                        row.Size = UDim2.new(1, 0, 0, height)
                        task.defer(UpdateSizeSection)
                    end
                    item:GetPropertyChangedSignal("Size"):Connect(refreshMobileRow)
                    item:GetPropertyChangedSignal("Visible"):Connect(refreshMobileRow)
                    task.defer(refreshMobileRow)
                    return
                end

                if UseIndependentColumns and not fullWidth then
                    if column ~= "Left" and column ~= "Right" then
                        column = (NextItem % 2 == 0) and "Left" or "Right"
                        NextItem = NextItem + 1
                    end
                    mountIndependentColumnItem(item, column, explicitRow)
                    return
                end

                if explicitRow then
                    rowIndex = explicitRow - 1
                    column = column or "Left"
                    if not rowHasSlot(RowsByIndex[rowIndex], column) and RowsByIndex[rowIndex] then
                        warn(("Oxide UI: Row %d Column %s is occupied; using next free row."):format(explicitRow, column))
                        rowIndex = findAvailableRow(column, rowIndex + 1)
                    end
                elseif column then
                    rowIndex = findAvailableRow(column, 0)
                else
                    -- Legacy automatic sequence: left, right, then next row.
                    column = (NextItem % 2 == 0) and "Left" or "Right"
                    rowIndex = math.floor(NextItem / 2)
                    if not rowHasSlot(RowsByIndex[rowIndex], column) and RowsByIndex[rowIndex] then
                        rowIndex = findAvailableRow(column, rowIndex)
                    end
                    NextItem = math.max(NextItem + 1, (rowIndex * 2) + (column == "Right" and 2 or 1))
                end

                local layoutRowIndex = UseMobileLayout and (rowIndex * 3) or rowIndex
                local row = makeRow(layoutRowIndex)
                if UseMobileLayout then row:SetAttribute("OxideRow", rowIndex + 1) end
                local cell = Instance.new("Frame")

                if column == "Full" then
                    cell.Name = "FullCell"
                    cell.Position = UDim2.fromOffset(0, 0)
                    cell.Size = UDim2.new(1, 0, 0, item.Size.Y.Offset)
                    NextItem = math.max(NextItem, (rowIndex + 1) * 2)
                    PendingRow = nil
                else
                    local isLeft = column == "Left"
                    cell.Name = column .. "Cell"
                    cell.Position = isLeft and UDim2.fromOffset(0, 0) or UDim2.new(0.5, 3, 0, 0)
                    cell.Size = UDim2.new(0.5, -3, 0, item.Size.Y.Offset)
                    NextItem = math.max(NextItem, (rowIndex * 2) + (isLeft and 1 or 2))
                end

                cell.BackgroundTransparency = 1
                cell.BorderSizePixel = 0
                cell.Parent = row

                item:SetAttribute("OxideSectionItem", true)
                item:SetAttribute("OxideColumn", column)
                item:SetAttribute("OxideRow", rowIndex + 1)
                item.LayoutOrder = 0
                item.AnchorPoint = Vector2.zero
                item.Position = UDim2.fromOffset(0, 0)
                item.Size = UDim2.new(1, 0, item.Size.Y.Scale, item.Size.Y.Offset)
                item.BackgroundTransparency = 1
                item.BorderSizePixel = 0
                item.Parent = cell

                local function refresh()
                    updateRowHeight(row)
                end
                item:GetPropertyChangedSignal("Size"):Connect(refresh)
                item:GetPropertyChangedSignal("Visible"):Connect(refresh)
                task.defer(refresh)
            end

            local layout = ScrolLayers:FindFirstChildOfClass("UIListLayout")
            if layout then
                layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateSizeScroll)
            end

            local Items = {}
            local CountItem = 0

            function Items:AddParagraph(ParagraphConfig)
                local ParagraphConfig = ParagraphConfig or {}
                ParagraphConfig.Title = ParagraphConfig.Title or "Title"
                ParagraphConfig.Content = ParagraphConfig.Content or "Content"
                local ParagraphFunc = {}

                local Paragraph = Instance.new("Frame")
                local UICorner14 = Instance.new("UICorner")
                local ParagraphTitle = Instance.new("TextLabel")
                local ParagraphContent = Instance.new("TextLabel")

                Paragraph.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Paragraph.BackgroundTransparency = 0.935
                Paragraph.BorderSizePixel = 0
                Paragraph.LayoutOrder = CountItem
                Paragraph.Size = UDim2.new(1, 0, 0, 40)
                Paragraph.Name = "Paragraph"
                MountSectionItem(Paragraph, ParagraphConfig, true)

                UICorner14.CornerRadius = UDim.new(0, 4)
                UICorner14.Parent = Paragraph

                local iconOffset = 10
                local IconImg
                local paragraphIconSize = math.max(12, tonumber(ParagraphConfig.IconSize or ParagraphConfig.ImageSize) or 20)
                if ParagraphConfig.Icon then
                    IconImg = Instance.new("ImageLabel")
                    IconImg.Size = UDim2.fromOffset(paragraphIconSize, paragraphIconSize)
                    IconImg.Position = UDim2.new(0, 8, 0, 8)
                    IconImg.BackgroundTransparency = 1
                    IconImg.Name = "ParagraphIcon"
                    IconImg.Parent = Paragraph

                    IconImg.Image = resolveIcon(ParagraphConfig.Icon)
                    IconImg.ImageColor3 = Color3.fromRGB(167, 200, 244)

                    iconOffset = paragraphIconSize + 12
                end

                ParagraphTitle.Font = Enum.Font.GothamBold
                ParagraphTitle.Text = ParagraphConfig.Title
                ParagraphTitle.TextColor3 = Color3.fromRGB(231, 231, 231)
                ParagraphTitle.TextSize = 13
                ParagraphTitle.TextXAlignment = Enum.TextXAlignment.Left
                ParagraphTitle.TextYAlignment = Enum.TextYAlignment.Top
                ParagraphTitle.BackgroundTransparency = 1
                ParagraphTitle.Position = UDim2.new(0, iconOffset, 0, 8)
                ParagraphTitle.Size = UDim2.new(1, -(iconOffset + 8), 0, 13)
                ParagraphTitle.Name = "ParagraphTitle"
                ParagraphTitle.Parent = Paragraph

                ParagraphContent.Font = Enum.Font.Gotham
                ParagraphContent.Text = ParagraphConfig.Content
                ParagraphContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                ParagraphContent.TextSize = 12
                ParagraphContent.TextXAlignment = Enum.TextXAlignment.Left
                ParagraphContent.TextYAlignment = Enum.TextYAlignment.Top
                ParagraphContent.BackgroundTransparency = 1
                ParagraphContent.Position = UDim2.new(0, iconOffset, 0, 21)
                ParagraphContent.Name = "ParagraphContent"
                ParagraphContent.TextWrapped = true
                ParagraphContent.RichText = true
                ParagraphContent.Parent = Paragraph

                ParagraphContent.Size = UDim2.new(1, -(iconOffset + 8), 0, 12)

                local ParagraphButton
                if ParagraphConfig.ButtonText then
                    ParagraphButton = Instance.new("TextButton")
                    ParagraphButton.Position = UDim2.new(0, 10, 0, 36)
                    ParagraphButton.Size = UDim2.new(1, -22, 0, 28)
                    ParagraphButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    ParagraphButton.BackgroundTransparency = 0.935
                    ParagraphButton.Font = Enum.Font.GothamBold
                    ParagraphButton.TextSize = 12
                    ParagraphButton.TextTransparency = 0.3
                    ParagraphButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                    ParagraphButton.Text = ParagraphConfig.ButtonText
                    ParagraphButton.Parent = Paragraph

                    local btnCorner = Instance.new("UICorner")
                    btnCorner.CornerRadius = UDim.new(0, 6)
                    btnCorner.Parent = ParagraphButton

                    if ParagraphConfig.ButtonCallback then
                        ParagraphButton.MouseButton1Click:Connect(ParagraphConfig.ButtonCallback)
                    end
                end

                local updatingParagraph = false
                local function UpdateSize()
                    if updatingParagraph then return end
                    updatingParagraph = true

                    local contentHeight = math.max(12, math.ceil(ParagraphContent.TextBounds.Y))
                    ParagraphContent.Size = UDim2.new(1, -(iconOffset + 8), 0, contentHeight)

                    local contentBottom = ParagraphContent.Position.Y.Offset + contentHeight
                    local totalHeight
                    if ParagraphButton then
                        ParagraphButton.Position = UDim2.new(0, 10, 0, contentBottom + 6)
                        totalHeight = ParagraphButton.Position.Y.Offset + ParagraphButton.Size.Y.Offset + 8
                    else
                        totalHeight = contentBottom + 8
                    end

                    -- Keep enough room for the optional icon even with very
                    -- short content, while expanding naturally for long text.
                    local iconMinHeight = IconImg and (IconImg.Position.Y.Offset + paragraphIconSize + 8) or 40
                    Paragraph.Size = UDim2.new(1, 0, 0, math.max(totalHeight, 40, iconMinHeight))
                    updatingParagraph = false
                end

                task.defer(UpdateSize)

                ParagraphContent:GetPropertyChangedSignal("TextBounds"):Connect(UpdateSize)
                ParagraphContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateSize)

                function ParagraphFunc:SetContent(content)
                    content = content or "Content"
                    ParagraphContent.Text = content
                    UpdateSize()
                end

                function ParagraphFunc:SetTitle(title)
                    ParagraphTitle.Text = title or "Title"
                end

                function ParagraphFunc:SetIcon(source)
                    if IconImg then
                        IconImg.Image = resolveIcon(source)
                    end
                end

                ParagraphFunc.Frame = Paragraph
                CountItem = CountItem + 1
                return ParagraphFunc
            end

            function Items:AddPanel(PanelConfig)
                PanelConfig = PanelConfig or {}
                PanelConfig.Title = PanelConfig.Title or "Title"
                PanelConfig.Content = PanelConfig.Content or ""
                PanelConfig.Placeholder = PanelConfig.Placeholder or nil
                PanelConfig.Default = PanelConfig.Default or ""
                PanelConfig.ButtonText = PanelConfig.Button or PanelConfig.ButtonText or "Confirm"
                PanelConfig.ButtonCallback = PanelConfig.Callback or PanelConfig.ButtonCallback or function() end
                PanelConfig.SubButtonText = PanelConfig.SubButton or PanelConfig.SubButtonText or nil
                PanelConfig.SubButtonCallback = PanelConfig.SubCallback or PanelConfig.SubButtonCallback or
                    function() end

                local configKey = "Panel_" .. PanelConfig.Title
                if ConfigData[configKey] ~= nil then
                    PanelConfig.Default = ConfigData[configKey]
                end

                local PanelFunc = { Value = PanelConfig.Default }

                local baseHeight = 44

                if PanelConfig.Placeholder then
                    baseHeight = baseHeight + 36
                end

                if PanelConfig.SubButtonText then
                    baseHeight = baseHeight + 36
                else
                    baseHeight = baseHeight + 32
                end

                local Panel = Instance.new("Frame")
                Panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Panel.BackgroundTransparency = 0.935
                Panel.Size = UDim2.new(1, 0, 0, baseHeight)
                Panel.LayoutOrder = CountItem
                MountSectionItem(Panel, PanelConfig, true)

                local UICorner = Instance.new("UICorner")
                UICorner.CornerRadius = UDim.new(0, 4)
                UICorner.Parent = Panel

                local Title = Instance.new("TextLabel")
                Title.Font = Enum.Font.GothamBold
                Title.Text = PanelConfig.Title
                Title.TextSize = 13
                Title.TextColor3 = Color3.fromRGB(255, 255, 255)
                Title.TextXAlignment = Enum.TextXAlignment.Left
                Title.BackgroundTransparency = 1
                Title.Position = UDim2.new(0, 10, 0, 10)
                Title.Size = UDim2.new(1, -20, 0, 13)
                Title.Parent = Panel

                local Content = Instance.new("TextLabel")
                Content.Font = Enum.Font.Gotham
                Content.Text = PanelConfig.Content
                Content.TextSize = 12
                Content.TextColor3 = Color3.fromRGB(255, 255, 255)
                Content.TextTransparency = 0
                Content.TextXAlignment = Enum.TextXAlignment.Left
                Content.BackgroundTransparency = 1
                Content.RichText = true
                Content.Position = UDim2.new(0, 10, 0, 26)
                Content.Size = UDim2.new(1, -20, 0, 14)
                Content.Parent = Panel

                local InputBox
                if PanelConfig.Placeholder then
                    local InputFrame = Instance.new("Frame")
                    InputFrame.AnchorPoint = Vector2.new(0.5, 0)
                    InputFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    InputFrame.BackgroundTransparency = 0.95
                    InputFrame.Position = UDim2.new(0.5, 0, 0, 44)
                    InputFrame.Size = UDim2.new(1, -20, 0, 30)
                    InputFrame.Parent = Panel

                    local inputCorner = Instance.new("UICorner")
                    inputCorner.CornerRadius = UDim.new(0, 4)
                    inputCorner.Parent = InputFrame

                    InputBox = Instance.new("TextBox")
                    InputBox.Font = Enum.Font.GothamBold
                    InputBox.PlaceholderText = PanelConfig.Placeholder
                    InputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
                    InputBox.Text = PanelConfig.Default
                    InputBox.TextSize = 11
                    InputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                    InputBox.BackgroundTransparency = 1
                    InputBox.TextXAlignment = Enum.TextXAlignment.Left
                    InputBox.Size = UDim2.new(1, -10, 1, -6)
                    InputBox.Position = UDim2.new(0, 5, 0, 3)
                    InputBox.Parent = InputFrame
                end

                local yBtn = 0
                if PanelConfig.Placeholder then
                    yBtn = 88
                else
                    yBtn = 48
                end

                local ButtonMain = Instance.new("TextButton")
                ButtonMain.Font = Enum.Font.GothamBold
                ButtonMain.Text = PanelConfig.ButtonText
                ButtonMain.TextColor3 = Color3.fromRGB(255, 255, 255)
                ButtonMain.TextSize = 12
                ButtonMain.TextTransparency = 0.3
                ButtonMain.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                ButtonMain.BackgroundTransparency = 0.935
                ButtonMain.Size = PanelConfig.SubButtonText and UDim2.new(0.5, -12, 0, 28) or UDim2.new(1, -20, 0, 28)
                ButtonMain.Position = UDim2.new(0, 10, 0, yBtn)
                ButtonMain.Parent = Panel

                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 6)
                btnCorner.Parent = ButtonMain

                ButtonMain.MouseButton1Click:Connect(function()
                    PanelConfig.ButtonCallback(InputBox and InputBox.Text or "")
                end)

                if PanelConfig.SubButtonText then
                    local SubButton = Instance.new("TextButton")
                    SubButton.Font = Enum.Font.GothamBold
                    SubButton.Text = PanelConfig.SubButtonText
                    SubButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                    SubButton.TextSize = 12
                    SubButton.TextTransparency = 0.3
                    SubButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    SubButton.BackgroundTransparency = 0.935
                    SubButton.Size = UDim2.new(0.5, -12, 0, 28)
                    SubButton.Position = UDim2.new(0.5, 2, 0, yBtn)
                    SubButton.Parent = Panel

                    local subCorner = Instance.new("UICorner")
                    subCorner.CornerRadius = UDim.new(0, 6)
                    subCorner.Parent = SubButton

                    SubButton.MouseButton1Click:Connect(function()
                        PanelConfig.SubButtonCallback(InputBox and InputBox.Text or "")
                    end)
                end

                if InputBox then
                    InputBox.FocusLost:Connect(function()
                        PanelFunc.Value = InputBox.Text
                        ConfigData[configKey] = InputBox.Text
                        SaveConfig()
                    end)
                end

                function PanelFunc:GetInput()
                    return InputBox and InputBox.Text or ""
                end

                CountItem = CountItem + 1
                return PanelFunc
            end

            function Items:AddButton(ButtonConfig)
                ButtonConfig = ButtonConfig or {}
                ButtonConfig.Title = ButtonConfig.Title or "Confirm"
                ButtonConfig.Callback = ButtonConfig.Callback or function() end
                ButtonConfig.SubTitle = ButtonConfig.SubTitle or nil
                ButtonConfig.SubCallback = ButtonConfig.SubCallback or function() end
                ButtonConfig.Icon = ButtonConfig.Icon or "arrow-right"
                ButtonConfig.SubIcon = ButtonConfig.SubIcon or "arrow-right"

                local Button = Instance.new("Frame")
                Button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Button.BackgroundTransparency = 1
                Button.Size = UDim2.new(1, 0, 0, 34)
                Button.LayoutOrder = CountItem
                MountSectionItem(Button, ButtonConfig, true)

                local UICorner = Instance.new("UICorner")
                UICorner.CornerRadius = UDim.new(0, 4)
                UICorner.Parent = Button

                -- Konfigurasi Animasi
                local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

                -- MAIN BUTTON
                local MainButton = Instance.new("TextButton")
                MainButton.Font = Enum.Font.GothamBold
                MainButton.Text = "    " .. ButtonConfig.Title
                MainButton.TextSize = 12
                MainButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                MainButton.TextTransparency = 0.3
                MainButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                MainButton.BackgroundTransparency = 0.935
                MainButton.AutoButtonColor = false
                MainButton.TextXAlignment = Enum.TextXAlignment.Left

                local ButtonIcon = Instance.new("ImageLabel")
                ButtonIcon.Name = "Icon"
                ButtonIcon.Parent = MainButton -- Masuk ke dalam MainButton

                -- Ukuran & Posisi (Sesuaikan angka di bawah dengan kebutuhanmu)
                ButtonIcon.Size = UDim2.new(0, 20, 0, 20) -- Ganti 20, 20 dengan ukuranmu
                ButtonIcon.Position = UDim2.new(1, -8, 0.5, 0)
                ButtonIcon.AnchorPoint = Vector2.new(1, 0.5)

                -- Properti Tampilan
                ButtonIcon.BackgroundTransparency = 1 -- Agar background icon tidak kelihatan
                ButtonIcon.Image = resolveIcon(ButtonConfig.Icon)
                ButtonIcon.ImageColor3 = Color3.fromRGB(255, 255, 255) -- Warna icon
                ButtonIcon.ImageTransparency = 0.3 -- Biar estetik (cocok dengan teksmu yang transparan 0.3)
                ButtonIcon.ScaleType = Enum.ScaleType.Fit -- Agar gambar tidak gepeng
                
                local mainNormalSize = ButtonConfig.SubTitle
                    and UDim2.new(0.5, -4, 1, 0)
                    or  UDim2.new(1, 0, 1, 0)
                local mainShrinkSize = UDim2.new(
                    mainNormalSize.X.Scale,
                    mainNormalSize.X.Offset - 2,
                    mainNormalSize.Y.Scale,
                    mainNormalSize.Y.Offset - 2
                )

                MainButton.Size     = mainNormalSize
                MainButton.Position = UDim2.new(0, 0, 0, 0)
                MainButton.AnchorPoint = Vector2.new(0, 0)
                MainButton.Parent = Button


                local mainCorner = Instance.new("UICorner")
                mainCorner.CornerRadius = UDim.new(0, 4)
                mainCorner.Parent = MainButton

                -- Efek Animasi Main Button
                MainButton.MouseButton1Down:Connect(function()
                    TweenService:Create(MainButton, tweenInfo, {Size = mainShrinkSize}):Play()
                end)
                MainButton.MouseButton1Up:Connect(function()
                    TweenService:Create(MainButton, tweenInfo, {Size = mainNormalSize}):Play()
                end)
                MainButton.MouseLeave:Connect(function()
                    TweenService:Create(MainButton, tweenInfo, {Size = mainNormalSize}):Play()
                end)

                MainButton.MouseButton1Click:Connect(ButtonConfig.Callback)

                -- SUB BUTTON
                if ButtonConfig.SubTitle then
                    local SubButton = Instance.new("TextButton")
                    SubButton.Font = Enum.Font.GothamBold
                    SubButton.Text = "    " .. ButtonConfig.SubTitle
                    SubButton.TextSize = 12
                    SubButton.TextTransparency = 0.3
                    SubButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                    SubButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    SubButton.BackgroundTransparency = 0.935
                    SubButton.AutoButtonColor = false
                    SubButton.TextXAlignment = Enum.TextXAlignment.Left
                    
                    local SubButtonIcon = Instance.new("ImageLabel")
                    SubButtonIcon.Name = "Icon"
                    SubButtonIcon.Parent = SubButton
                    SubButtonIcon.Size = UDim2.new(0, 20, 0, 20)
                    SubButtonIcon.Position = UDim2.new(1, -8, 0.5, 0)
                    SubButtonIcon.AnchorPoint = Vector2.new(1, 0.5)
                    SubButtonIcon.BackgroundTransparency = 1
                    SubButtonIcon.Image = resolveIcon(ButtonConfig.SubIcon)
                    SubButtonIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
                    SubButtonIcon.ImageTransparency = 0.3
                    SubButtonIcon.ScaleType = Enum.ScaleType.Fit

                    local subNormalSize = UDim2.new(0.5, -4, 1, 0)
                    local subShrinkSize = UDim2.new(
                        subNormalSize.X.Scale,
                        subNormalSize.X.Offset - 2,
                        subNormalSize.Y.Scale,
                        subNormalSize.Y.Offset - 2
                    )

                    SubButton.Size     = subNormalSize
                    SubButton.Position = UDim2.new(0.5, 4, 0, 0)
                    SubButton.AnchorPoint = Vector2.new(0, 0)
                    SubButton.Parent = Button


                    local subCorner = Instance.new("UICorner")
                    subCorner.CornerRadius = UDim.new(0, 4)
                    subCorner.Parent = SubButton

                    -- Efek Animasi Sub Button
                    SubButton.MouseButton1Down:Connect(function()
                        TweenService:Create(SubButton, tweenInfo, {Size = subShrinkSize}):Play()
                    end)
                    SubButton.MouseButton1Up:Connect(function()
                        TweenService:Create(SubButton, tweenInfo, {Size = subNormalSize}):Play()
                    end)
                    SubButton.MouseLeave:Connect(function()
                        TweenService:Create(SubButton, tweenInfo, {Size = subNormalSize}):Play()
                    end)

                    SubButton.MouseButton1Click:Connect(ButtonConfig.SubCallback)
                end

                CountItem = CountItem + 1
            end

            function Items:AddToggle(ToggleConfig)
                local ToggleConfig = ToggleConfig or {}
                ToggleConfig.Title = ToggleConfig.Title or "Title"
                ToggleConfig.Title2 = ToggleConfig.Title2 or ""
                ToggleConfig.Content = ToggleConfig.Content or ""
                ToggleConfig.Default = ToggleConfig.Default or false
                ToggleConfig.Callback = ToggleConfig.Callback or function() end
                ToggleConfig.Keybind = ToggleConfig.Keybind or false

                local configKey = "Toggle_" .. ToggleConfig.Title
                local keybindConfigKey = configKey .. "_Keybind"

                if ConfigData[configKey] ~= nil then
                    ToggleConfig.Default = ConfigData[configKey]
                end

                local currentKeybind = nil
                if ConfigData[keybindConfigKey] ~= nil then
                    currentKeybind = ConfigData[keybindConfigKey]
                end

                local ToggleFunc = { Value = ToggleConfig.Default }

                local Toggle = Instance.new("Frame")
                local UICorner20 = Instance.new("UICorner")
                local ToggleTitle = Instance.new("TextLabel")
                local ToggleContent = Instance.new("TextLabel")
                local ToggleButton = Instance.new("TextButton")
                local FeatureFrame2 = Instance.new("Frame")
                local KeybindFrame = Instance.new("Frame")
                local UICorner22 = Instance.new("UICorner")
                local UIStroke8 = Instance.new("UIStroke")
                local ToggleCircle = Instance.new("Frame")
                local UICorner23 = Instance.new("UICorner")
                local UICorner24 = Instance.new("UICorner")
                local KeybindButton = Instance.new("TextButton")

                Toggle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Toggle.BackgroundTransparency = 0.935
                Toggle.BorderSizePixel = 0
                Toggle.LayoutOrder = CountItem
                Toggle.Name = "Toggle"
                MountSectionItem(Toggle, ToggleConfig, false)

                UICorner20.CornerRadius = UDim.new(0, 4)
                UICorner20.Parent = Toggle

                ToggleTitle.Font = Enum.Font.GothamBold
                ToggleTitle.Text = ToggleConfig.Title
                ToggleTitle.TextSize = 13
                ToggleTitle.TextColor3 = Color3.fromRGB(231, 231, 231)
                ToggleTitle.TextXAlignment = Enum.TextXAlignment.Left
                ToggleTitle.TextYAlignment = Enum.TextYAlignment.Center
                ToggleTitle.TextTruncate = Enum.TextTruncate.AtEnd
                ToggleTitle.BackgroundTransparency = 1
                ToggleTitle.Position = UDim2.new(0, 10, 0, 0)
                local toggleTextRightInset = UseMobileLayout and 62 or 100
                ToggleTitle.Size = UDim2.new(1, -toggleTextRightInset, 1, 0)
                ToggleTitle.Name = "ToggleTitle"
                ToggleTitle.Parent = Toggle

                local ToggleTitle2 = Instance.new("TextLabel")
                ToggleTitle2.Font = Enum.Font.GothamBold
                ToggleTitle2.Text = ToggleConfig.Title2
                ToggleTitle2.TextSize = 12
                ToggleTitle2.TextColor3 = Color3.fromRGB(231, 231, 231)
                ToggleTitle2.TextXAlignment = Enum.TextXAlignment.Left
                ToggleTitle2.TextYAlignment = Enum.TextYAlignment.Top
                ToggleTitle2.BackgroundTransparency = 1
                ToggleTitle2.Position = UDim2.new(0, 10, 0, 20)
                ToggleTitle2.Size = UDim2.new(1, -toggleTextRightInset, 0, 12)
                ToggleTitle2.Name = "ToggleTitle2"
                ToggleTitle2.Parent = Toggle

                ToggleContent.Font = Enum.Font.GothamBold
                ToggleContent.Text = ToggleConfig.Content
                ToggleContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                ToggleContent.TextSize = 12
                ToggleContent.TextTransparency = 0.6
                ToggleContent.TextXAlignment = Enum.TextXAlignment.Left
                ToggleContent.TextYAlignment = Enum.TextYAlignment.Top
                ToggleContent.BackgroundTransparency = 1
                ToggleContent.TextWrapped = true
                ToggleContent.Size = UDim2.new(1, -toggleTextRightInset, 0, 12)
                ToggleContent.Name = "ToggleContent"
                ToggleContent.Parent = Toggle

                local hasTitle2 = ToggleConfig.Title2 ~= ""
                local hasDescription = ToggleConfig.Content ~= ""
                local updatingToggleLayout = false

                local function UpdateToggleLayout()
                    if updatingToggleLayout then return end
                    updatingToggleLayout = true

                    if not hasDescription and not hasTitle2 then
                        -- Two compact title-only toggles plus the default 2px
                        -- ItemGap total exactly 64px, matching one dropdown.
                        Toggle.Size = UDim2.new(1, 0, 0, 31)
                        ToggleTitle.Position = UDim2.fromOffset(10, 0)
                        ToggleTitle.Size = UDim2.new(1, -toggleTextRightInset, 1, 0)
                        ToggleTitle.TextYAlignment = Enum.TextYAlignment.Center
                        ToggleTitle2.Visible = false
                        ToggleContent.Visible = false
                    else
                        ToggleTitle.Position = UDim2.fromOffset(10, 5)
                        ToggleTitle.Size = UDim2.new(1, -toggleTextRightInset, 0, 14)
                        ToggleTitle.TextYAlignment = Enum.TextYAlignment.Top

                        local descriptionY
                        if hasTitle2 then
                            ToggleTitle2.Visible = true
                            ToggleTitle2.Position = UDim2.fromOffset(10, 18)
                            descriptionY = 32
                        else
                            ToggleTitle2.Visible = false
                            descriptionY = 20
                        end

                        if hasDescription then
                            ToggleContent.Visible = true
                            ToggleContent.Position = UDim2.fromOffset(10, descriptionY)
                            local contentHeight = math.max(12, math.ceil(ToggleContent.TextBounds.Y))
                            ToggleContent.Size = UDim2.new(1, -toggleTextRightInset, 0, contentHeight)
                            Toggle.Size = UDim2.new(1, 0, 0, descriptionY + contentHeight + 7)
                        else
                            ToggleContent.Visible = false
                            Toggle.Size = UDim2.new(1, 0, 0, 36)
                        end
                    end

                    updatingToggleLayout = false
                    task.defer(UpdateSizeSection)
                end

                task.defer(UpdateToggleLayout)
                ToggleContent:GetPropertyChangedSignal("TextBounds"):Connect(UpdateToggleLayout)
                ToggleContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateToggleLayout)

                ToggleButton.Font = Enum.Font.SourceSans
                ToggleButton.Text = ""
                ToggleButton.BackgroundTransparency = 1
                ToggleButton.Name = "ToggleButton"
                ToggleButton.Active = true
                ToggleButton.Selectable = true
                ToggleButton.AutoButtonColor = false

                FeatureFrame2.AnchorPoint = Vector2.new(1, 0.5)
                FeatureFrame2.BackgroundTransparency = 0.92
                FeatureFrame2.BorderSizePixel = 0
                FeatureFrame2.Position = UDim2.new(1, -15, 0.5, 0)
                FeatureFrame2.Size = UDim2.new(0, 30, 0, 15)
                FeatureFrame2.Name = "FeatureFrame"
                FeatureFrame2.Active = true
                FeatureFrame2.Parent = Toggle

                -- Only this switch hit area can toggle the value. It is wider
                -- than the visual track for comfortable mouse/touch input, but
                -- no longer overlaps the title or description.
                ToggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
                ToggleButton.Position = UDim2.new(0.5, 0, 0.5, 0)
                ToggleButton.Size = UDim2.fromOffset(38, 25)
                ToggleButton.ZIndex = 20
                ToggleButton.Parent = FeatureFrame2

                UICorner22.Parent = FeatureFrame2

                UIStroke8.Color = Color3.fromRGB(255, 255, 255)
                UIStroke8.Thickness = 2
                UIStroke8.Transparency = 0.9
                UIStroke8.Parent = FeatureFrame2

                ToggleCircle.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
                ToggleCircle.BorderSizePixel = 0
                ToggleCircle.Size = UDim2.new(0, 14, 0, 14)
                ToggleCircle.Name = "ToggleCircle"
                ToggleCircle.Parent = FeatureFrame2

                UICorner23.CornerRadius = UDim.new(0, 15)
                UICorner23.Parent = ToggleCircle

                KeybindFrame.AnchorPoint = Vector2.new(1, 0.5)
                KeybindFrame.BackgroundTransparency = 0.92
                KeybindFrame.BorderSizePixel = 0
                KeybindFrame.Position = UDim2.new(0.9, -20, 0.5, 0)
                KeybindFrame.Size = UDim2.new(0, 70, 0, 20)
                KeybindFrame.Name = "KeybindFrame"
                KeybindFrame.Parent = Toggle

                UICorner24.Parent = KeybindFrame

                KeybindButton.Font = Enum.Font.GothamBold
                KeybindButton.Text = "Keybind"
                KeybindButton.BackgroundTransparency = 1
                KeybindButton.Size = UDim2.new(1, 0, 1, 0)
                KeybindButton.Position = UDim2.new(0, 0, 0, 0)
                KeybindButton.TextXAlignment = Enum.TextXAlignment.Center
                KeybindButton.TextYAlignment = Enum.TextYAlignment.Center
                KeybindButton.Name = "KeybindButton"
                KeybindButton.TextColor3 = Color3.fromRGB(225, 225, 225)
                KeybindButton.TextSize = 12
                KeybindButton.Parent = KeybindFrame

                local isRecording = false
                local lastRecordCancel = 0

                local ignoredKeys = {
                    [Enum.KeyCode.LeftControl] = true, [Enum.KeyCode.RightControl] = true,
                    [Enum.KeyCode.LeftAlt] = true, [Enum.KeyCode.RightAlt] = true,
                    [Enum.KeyCode.LeftShift] = true, [Enum.KeyCode.RightShift] = true,
                    [Enum.KeyCode.Unknown] = true
                }

                local function GetModifiersString(excludeKey)
                    local keys = ""
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and excludeKey ~= Enum.KeyCode.LeftControl then keys = keys .. "LeftControl + " end
                    if UserInputService:IsKeyDown(Enum.KeyCode.RightControl) and excludeKey ~= Enum.KeyCode.RightControl then keys = keys .. "RightControl + " end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) and excludeKey ~= Enum.KeyCode.LeftAlt then keys = keys .. "LeftAlt + " end
                    if UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) and excludeKey ~= Enum.KeyCode.RightAlt then keys = keys .. "RightAlt + " end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and excludeKey ~= Enum.KeyCode.LeftShift then keys = keys .. "LeftShift + " end
                    if UserInputService:IsKeyDown(Enum.KeyCode.RightShift) and excludeKey ~= Enum.KeyCode.RightShift then keys = keys .. "RightShift + " end
                    return keys
                end

                KeybindButton:GetPropertyChangedSignal("TextBounds"):Connect(function()
                    KeybindFrame.Size = UDim2.new(0, KeybindButton.TextBounds.X + 20, 0, 20)
                end)

                if not ToggleConfig.Keybind or isMobile then
                    KeybindFrame.Visible = false
                else
                    if currentKeybind then
                        KeybindButton.Text = "[ " .. currentKeybind .. " ]"
                    else
                        KeybindButton.Text = "Keybind"
                    end

                    KeybindButton.MouseButton1Click:Connect(function()
                        if not isRecording and tick() - lastRecordCancel > 0.1 then
                            isRecording = true
                            KeybindButton.Text = "[ ... ]"
                        end
                    end)

                    trackCleanup(UserInputService.InputBegan:Connect(function(input, gameProcessed)
                        if isDestroyed then return end
                        if isRecording then
                            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                isRecording = false
                                lastRecordCancel = tick()
                                currentKeybind = nil
                                KeybindButton.Text = "Keybind"
                                ConfigData[keybindConfigKey] = nil
                                SaveConfig()
                            elseif input.UserInputType == Enum.UserInputType.Keyboard then
                                local key = input.KeyCode
                                if key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace then
                                    isRecording = false
                                    currentKeybind = nil
                                    KeybindButton.Text = "Keybind"
                                    ConfigData[keybindConfigKey] = nil
                                    SaveConfig()
                                elseif ignoredKeys[key] then
                                    if key ~= Enum.KeyCode.Unknown then
                                        KeybindButton.Text = "[ " .. GetModifiersString() .. "... ]"
                                    end
                                else
                                    local finalBind = GetModifiersString() .. key.Name
                                    currentKeybind = finalBind
                                    KeybindButton.Text = "[ " .. finalBind .. " ]"
                                    isRecording = false
                                    ConfigData[keybindConfigKey] = currentKeybind
                                    SaveConfig()
                                end
                            end
                        else
                            if not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard then
                                if currentKeybind then
                                    local checkStr = GetModifiersString(input.KeyCode) .. input.KeyCode.Name
                                    if checkStr == currentKeybind then
                                        ToggleFunc.Value = not ToggleFunc.Value
                                        ToggleFunc:Set(ToggleFunc.Value)
                                    end
                                end
                            end
                        end
                    end))

                    trackCleanup(UserInputService.InputEnded:Connect(function(input, gameProcessed)
                        if isRecording and ignoredKeys[input.KeyCode] and input.KeyCode ~= Enum.KeyCode.Unknown then
                            currentKeybind = input.KeyCode.Name
                            KeybindButton.Text = "[ " .. currentKeybind .. " ]"
                            isRecording = false
                            ConfigData[keybindConfigKey] = currentKeybind
                            SaveConfig()
                        end
                    end))
                end

                ToggleButton.Activated:Connect(function()
                    ToggleFunc.Value = not ToggleFunc.Value
                    ToggleFunc:Set(ToggleFunc.Value)
                end)

                function ToggleFunc:Set(Value, skipSave)
                    Value = Value == true
                    ToggleFunc.Value = Value
                    if typeof(ToggleConfig.Callback) == "function" then
                        local ok, err = pcall(function()
                            ToggleConfig.Callback(Value)
                        end)
                        if not ok then warn("Toggle Callback error:", err) end
                    end
                    if not skipSave then
                        ConfigData[configKey] = Value
                        SaveConfig()
                    end
                    if Value then
                        TweenService:Create(ToggleTitle, TweenInfo.new(0.2), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
                        TweenService:Create(ToggleCircle, TweenInfo.new(0.2), { Position = UDim2.new(0, 15, 0, 0), BackgroundColor3 = Color3.fromRGB(46, 46, 46) })
                            :Play()
                        TweenService:Create(UIStroke8, TweenInfo.new(0.2), { Color = Color3.fromRGB(255, 255, 255), Transparency = 0 })
                            :Play()
                        TweenService:Create(FeatureFrame2, TweenInfo.new(0.2),
                            { BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0 }):Play()
                    else
                        TweenService:Create(ToggleTitle, TweenInfo.new(0.2),
                            { TextColor3 = Color3.fromRGB(230, 230, 230) }):Play()
                        TweenService:Create(ToggleCircle, TweenInfo.new(0.2), { Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(230, 230, 230) }):Play()
                        TweenService:Create(UIStroke8, TweenInfo.new(0.2),
                            { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.9 }):Play()
                        TweenService:Create(FeatureFrame2, TweenInfo.new(0.2),
                            { BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.92 }):Play()
                    end
                end

                function ToggleFunc:Cleanup()
                    if ToggleFunc.Value then
                        ToggleFunc:Set(false, true)
                    end
                end

                ToggleFunc:Set(ToggleFunc.Value, true)
                table.insert(activeToggles, ToggleFunc)
                CountItem = CountItem + 1
                Elements[configKey] = ToggleFunc
                windowElementKeys[configKey] = true
                return ToggleFunc
            end

            function Items:AddSlider(SliderConfig)
                local SliderConfig = SliderConfig or {}
                SliderConfig.Title = SliderConfig.Title or "Slider"
                SliderConfig.Content = SliderConfig.Content or ""
                SliderConfig.Increment = SliderConfig.Increment or 1
                SliderConfig.Min = SliderConfig.Min or 0
                SliderConfig.Max = SliderConfig.Max or 100
                SliderConfig.Default = SliderConfig.Default or 50
                SliderConfig.Callback = SliderConfig.Callback or function() end

                local configKey = "Slider_" .. SliderConfig.Title
                if ConfigData[configKey] ~= nil then
                    SliderConfig.Default = ConfigData[configKey]
                end

                local SliderFunc = { Value = SliderConfig.Default }

                local Slider = Instance.new("Frame");
                local UICorner15 = Instance.new("UICorner");
                local SliderTitle = Instance.new("TextLabel");
                local SliderContent = Instance.new("TextLabel");
                local SliderInput = Instance.new("Frame");
                local UICorner16 = Instance.new("UICorner");
                local TextBox = Instance.new("TextBox");
                local SliderFrame = Instance.new("Frame");
                local UICorner17 = Instance.new("UICorner");
                local SliderDraggable = Instance.new("Frame");
                local UICorner18 = Instance.new("UICorner");
                local UIStroke5 = Instance.new("UIStroke");
                local SliderCircle = Instance.new("Frame");
                local UICorner19 = Instance.new("UICorner");
                local UIStroke6 = Instance.new("UIStroke");
                local UIStroke7 = Instance.new("UIStroke");

                Slider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Slider.BackgroundTransparency = 0.935
                Slider.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Slider.BorderSizePixel = 0
                Slider.LayoutOrder = CountItem
                Slider.Size = UDim2.new(1, 0, 0, 40)
                Slider.Name = "Slider"
                MountSectionItem(Slider, SliderConfig, true)

                UICorner15.CornerRadius = UDim.new(0, 4)
                UICorner15.Parent = Slider

                SliderTitle.Font = Enum.Font.GothamBold
                SliderTitle.Text = SliderConfig.Title
                SliderTitle.TextColor3 = Color3.fromRGB(230.77499270439148, 230.77499270439148, 230.77499270439148)
                SliderTitle.TextSize = 13
                SliderTitle.TextXAlignment = Enum.TextXAlignment.Left
                SliderTitle.TextYAlignment = Enum.TextYAlignment.Top
                SliderTitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                SliderTitle.BackgroundTransparency = 0.9990000128746033
                SliderTitle.BorderColor3 = Color3.fromRGB(0, 0, 0)
                SliderTitle.BorderSizePixel = 0
                SliderTitle.Position = UDim2.new(0, 10, 0, 8)
                SliderTitle.Size = (SliderConfig.FullWidth ~= false)
                    and UDim2.new(1, -180, 0, 13)
                    or UDim2.new(1, -20, 0, 13)
                SliderTitle.Name = "SliderTitle"
                SliderTitle.Parent = Slider

                SliderContent.Font = Enum.Font.GothamBold
                SliderContent.Text = SliderConfig.Content
                SliderContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                SliderContent.TextSize = 12
                SliderContent.TextTransparency = 0.6000000238418579
                SliderContent.TextXAlignment = Enum.TextXAlignment.Left
                SliderContent.TextYAlignment = Enum.TextYAlignment.Bottom
                SliderContent.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                SliderContent.BackgroundTransparency = 0.9990000128746033
                SliderContent.BorderColor3 = Color3.fromRGB(0, 0, 0)
                SliderContent.BorderSizePixel = 0
                SliderContent.Position = UDim2.new(0, 10, 0, 21)
                SliderContent.Size = (SliderConfig.FullWidth ~= false)
                    and UDim2.new(1, -180, 0, 12)
                    or UDim2.new(1, -20, 0, 12)
                SliderContent.Name = "SliderContent"
                SliderContent.Parent = Slider

                local sliderTextWidthOffset = (SliderConfig.FullWidth ~= false) and -180 or -20
                local sliderBottomPadding = (SliderConfig.FullWidth ~= false) and 27 or 52
                SliderContent.Size = UDim2.new(1, sliderTextWidthOffset, 0,
                    12 + (12 * (SliderContent.TextBounds.X // math.max(1, SliderContent.AbsoluteSize.X))))
                SliderContent.TextWrapped = true
                Slider.Size = UDim2.new(1, 0, 0, SliderContent.AbsoluteSize.Y + sliderBottomPadding)

                SliderContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    SliderContent.TextWrapped = false
                    SliderContent.Size = UDim2.new(1, sliderTextWidthOffset, 0,
                        12 + (12 * (SliderContent.TextBounds.X // math.max(1, SliderContent.AbsoluteSize.X))))
                    Slider.Size = UDim2.new(1, 0, 0, SliderContent.AbsoluteSize.Y + sliderBottomPadding)
                    SliderContent.TextWrapped = true
                    UpdateSizeSection()
                end)

                SliderInput.AnchorPoint = Vector2.new(1, 0.5)
                SliderInput.BackgroundColor3 = GuiConfig.Color
                SliderInput.BorderColor3 = Color3.fromRGB(0, 0, 0)
                SliderInput.BackgroundTransparency = 1
                SliderInput.BorderSizePixel = 0
                SliderInput.Position = (SliderConfig.FullWidth ~= false)
                    and UDim2.new(1, -155, 0.5, 0)
                    or UDim2.new(1, -10, 1, -15)
                SliderInput.Size = UDim2.new(0, 28, 0, 20)
                SliderInput.Name = "SliderInput"
                SliderInput.Parent = Slider

                UICorner16.CornerRadius = UDim.new(0, 2)
                UICorner16.Parent = SliderInput

                TextBox.Font = Enum.Font.GothamBold
                TextBox.Text = "90"
                TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                TextBox.TextSize = 13
                TextBox.TextWrapped = true
                TextBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                TextBox.BackgroundTransparency = 0.9990000128746033
                TextBox.BorderColor3 = Color3.fromRGB(0, 0, 0)
                TextBox.BorderSizePixel = 0
                TextBox.Position = UDim2.new(0, -1, 0, 0)
                TextBox.Size = UDim2.new(1, 0, 1, 0)
                TextBox.Parent = SliderInput

                SliderFrame.AnchorPoint = (SliderConfig.FullWidth ~= false)
                    and Vector2.new(1, 0.5)
                    or Vector2.new(0, 0.5)
                SliderFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                SliderFrame.BackgroundTransparency = 0.800000011920929
                SliderFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
                SliderFrame.BorderSizePixel = 0
                SliderFrame.Position = (SliderConfig.FullWidth ~= false)
                    and UDim2.new(1, -20, 0.5, 0)
                    or UDim2.new(0, 10, 1, -15)
                SliderFrame.Size = (SliderConfig.FullWidth ~= false)
                    and UDim2.new(0, 100, 0, 3)
                    or UDim2.new(1, -58, 0, 3)
                SliderFrame.Name = "SliderFrame"
                SliderFrame.Parent = Slider

                local SliderHitbox = Instance.new("Frame")
                SliderHitbox.Name = "SliderHitbox"
                SliderHitbox.AnchorPoint = SliderFrame.AnchorPoint
                SliderHitbox.BackgroundTransparency = 1
                SliderHitbox.BorderSizePixel = 0
                SliderHitbox.Position = SliderFrame.Position
                SliderHitbox.Size = UDim2.new(SliderFrame.Size.X.Scale, SliderFrame.Size.X.Offset, 0, 24)
                SliderHitbox.Active = true
                SliderHitbox.ZIndex = SliderFrame.ZIndex + 2
                SliderHitbox.Parent = Slider

                UICorner17.Parent = SliderFrame

                SliderDraggable.AnchorPoint = Vector2.new(0, 0.5)
                SliderDraggable.BackgroundColor3 = GuiConfig.Color
                SliderDraggable.BorderColor3 = Color3.fromRGB(0, 0, 0)
                SliderDraggable.BorderSizePixel = 0
                SliderDraggable.Position = UDim2.new(0, 0, 0.5, 0)
                SliderDraggable.Size = UDim2.new(0.899999976, 0, 0, 1)
                SliderDraggable.Name = "SliderDraggable"
                SliderDraggable.Parent = SliderFrame

                UICorner18.Parent = SliderDraggable

                SliderCircle.AnchorPoint = Vector2.new(1, 0.5)
                SliderCircle.BackgroundColor3 = GuiConfig.Color
                SliderCircle.BorderColor3 = Color3.fromRGB(0, 0, 0)
                SliderCircle.BorderSizePixel = 0
                SliderCircle.Position = UDim2.new(1, 4, 0.5, 0)
                SliderCircle.Size = UDim2.new(0, 8, 0, 8)
                SliderCircle.Name = "SliderCircle"
                SliderCircle.Parent = SliderDraggable

                UICorner19.Parent = SliderCircle

                UIStroke6.Color = GuiConfig.Color
                UIStroke6.Parent = SliderCircle

                local Dragging = false
                local UpdatingTextInternally = false
                local function Round(Number, Factor)
                    local Result = math.floor(Number / Factor + (math.sign(Number) * 0.5)) * Factor
                    if Result < 0 then
                        Result = Result + Factor
                    end
                    return Result
                end
                function SliderFunc:Set(Value, options)
                    options = options or {}
                    Value = math.clamp(Round(Value, SliderConfig.Increment), SliderConfig.Min, SliderConfig.Max)
                    SliderFunc.Value = Value
                    local valueText = tostring(Value)
                    if TextBox.Text ~= valueText then
                        UpdatingTextInternally = true
                        TextBox.Text = valueText
                        UpdatingTextInternally = false
                    end
                    local fillSize = UDim2.fromScale((Value - SliderConfig.Min) / (SliderConfig.Max - SliderConfig.Min), 1)
                    if options.Instant then
                        SliderDraggable.Size = fillSize
                    else
                        TweenService:Create(
                            SliderDraggable,
                            TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { Size = fillSize }
                        ):Play()
                    end

                    SliderConfig.Callback(Value)
                    if options.Save ~= false then
                        ConfigData[configKey] = Value
                        SaveConfig()
                    end
                end

                local function updateFromPosition(x)
                    local SizeScale = math.clamp(
                        (x - SliderFrame.AbsolutePosition.X) / math.max(1, SliderFrame.AbsoluteSize.X),
                        0,
                        1
                    )
                    SliderFunc:Set(
                        SliderConfig.Min + ((SliderConfig.Max - SliderConfig.Min) * SizeScale),
                        { Instant = true, Save = false }
                    )
                end

                SliderHitbox.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        Dragging = true
                        TweenService:Create(
                            SliderCircle,
                            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { Size = UDim2.new(0, 14, 0, 14) }
                        ):Play()
                        updateFromPosition(Input.Position.X)
                    end
                end)

                trackCleanup(UserInputService.InputEnded:Connect(function(Input)
                    if isDestroyed then return end
                    if Dragging and (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
                        Dragging = false
                        ConfigData[configKey] = SliderFunc.Value
                        SaveConfig()
                        TweenService:Create(
                            SliderCircle,
                            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { Size = UDim2.new(0, 8, 0, 8) }
                        ):Play()
                    end
                end))

                trackCleanup(UserInputService.InputChanged:Connect(function(Input)
                    if isDestroyed then return end
                    if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
                        updateFromPosition(Input.Position.X)
                    end
                end))

                -- Numeric editing is committed only when focus leaves the box.
                -- This allows temporary states such as "", "1", or "-" while
                -- typing instead of immediately replacing them with Min.
                TextBox:GetPropertyChangedSignal("Text"):Connect(function()
                    if UpdatingTextInternally then return end
                    local sanitized = TextBox.Text:gsub("[^%d%.%-]", "")
                    -- Keep a single leading minus and one decimal separator.
                    local isNegative = sanitized:sub(1, 1) == "-"
                    sanitized = sanitized:gsub("%-", "")
                    if isNegative then sanitized = "-" .. sanitized end
                    local firstDot = sanitized:find("%.")
                    if firstDot then
                        sanitized = sanitized:sub(1, firstDot)
                            .. sanitized:sub(firstDot + 1):gsub("%.", "")
                    end
                    if sanitized ~= TextBox.Text then
                        local cursor = TextBox.CursorPosition
                        UpdatingTextInternally = true
                        TextBox.Text = sanitized
                        TextBox.CursorPosition = math.min(cursor, #sanitized + 1)
                        UpdatingTextInternally = false
                    end
                end)

                TextBox.FocusLost:Connect(function()
                    local numericValue = tonumber(TextBox.Text)
                    if numericValue == nil then
                        -- Empty/partial input reverts to the last slider value.
                        UpdatingTextInternally = true
                        TextBox.Text = tostring(SliderFunc.Value)
                        UpdatingTextInternally = false
                        return
                    end
                    SliderFunc:Set(numericValue, { Instant = false, Save = true })
                end)

                SliderFunc:Set(SliderConfig.Default)
                CountItem = CountItem + 1
                Elements[configKey] = SliderFunc
                windowElementKeys[configKey] = true
                return SliderFunc
            end

            function Items:AddInput(InputConfig)
                local InputConfig = InputConfig or {}
                InputConfig.Title = InputConfig.Title or "Title"
                InputConfig.Content = InputConfig.Content or ""
                InputConfig.Callback = InputConfig.Callback or function() end
                InputConfig.Default = InputConfig.Default or ""

                local configKey = "Input_" .. InputConfig.Title
                if ConfigData[configKey] ~= nil then
                    InputConfig.Default = ConfigData[configKey]
                end

                local InputFunc = { Value = InputConfig.Default }

                local Input = Instance.new("Frame");
                local UICorner12 = Instance.new("UICorner");
                local InputTitle = Instance.new("TextLabel");
                local InputContent = Instance.new("TextLabel");
                local InputFrame = Instance.new("Frame");
                local UICorner13 = Instance.new("UICorner");
                local InputTextBox = Instance.new("TextBox");

                Input.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Input.BackgroundTransparency = 0.935
                Input.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Input.BorderSizePixel = 0
                Input.LayoutOrder = CountItem
                Input.Size = UDim2.new(1, 0, 0, 40)
                Input.Name = "Input"
                MountSectionItem(Input, InputConfig, true)

                UICorner12.CornerRadius = UDim.new(0, 4)
                UICorner12.Parent = Input

                InputTitle.Font = Enum.Font.GothamBold
                InputTitle.Text = InputConfig.Title or "TextBox"
                InputTitle.TextColor3 = Color3.fromRGB(230.77499270439148, 230.77499270439148, 230.77499270439148)
                InputTitle.TextSize = 13
                InputTitle.TextXAlignment = Enum.TextXAlignment.Left
                InputTitle.TextYAlignment = Enum.TextYAlignment.Top
                InputTitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputTitle.BackgroundTransparency = 0.9990000128746033
                InputTitle.BorderColor3 = Color3.fromRGB(0, 0, 0)
                InputTitle.BorderSizePixel = 0
                InputTitle.Position = UDim2.new(0, 10, 0, 8)
                InputTitle.Size = UDim2.new(1, -20, 0, 13)
                InputTitle.Name = "InputTitle"
                InputTitle.Parent = Input

                InputContent.Font = Enum.Font.GothamBold
                InputContent.Text = InputConfig.Content or "This is a TextBox"
                InputContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                InputContent.TextSize = 12
                InputContent.TextTransparency = 0.6000000238418579
                InputContent.TextWrapped = true
                InputContent.TextXAlignment = Enum.TextXAlignment.Left
                InputContent.TextYAlignment = Enum.TextYAlignment.Bottom
                InputContent.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputContent.BackgroundTransparency = 0.9990000128746033
                InputContent.BorderColor3 = Color3.fromRGB(0, 0, 0)
                InputContent.BorderSizePixel = 0
                InputContent.Position = UDim2.new(0, 10, 0, 21)
                InputContent.Size = UDim2.new(1, -20, 0, 12)
                InputContent.Name = "InputContent"
                InputContent.Parent = Input

                if InputConfig.Content == "" then
                    InputContent.Visible = false
                    InputContent.Size = UDim2.new(1, -20, 0, 0)
                    Input.Size = UDim2.new(1, 0, 0, 66)
                else
                    InputContent.Size = UDim2.new(1, -20, 0,
                        12 + (12 * (InputContent.TextBounds.X // math.max(1, InputContent.AbsoluteSize.X))))
                    InputContent.TextWrapped = true
                    Input.Size = UDim2.new(1, 0, 0, InputContent.AbsoluteSize.Y + 68)
                end

                InputContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    if InputConfig.Content ~= "" then
                        InputContent.TextWrapped = false
                        InputContent.Size = UDim2.new(1, -20, 0,
                            12 + (12 * (InputContent.TextBounds.X // math.max(1, InputContent.AbsoluteSize.X))))
                        Input.Size = UDim2.new(1, 0, 0, InputContent.AbsoluteSize.Y + 68)
                        InputFrame.Position = UDim2.new(0.5, 0, 0, InputContent.Position.Y.Offset + InputContent.AbsoluteSize.Y + 8)
                        InputContent.TextWrapped = true
                        UpdateSizeSection()
                    end
                end)

                InputFrame.AnchorPoint = Vector2.new(0.5, 0)
                InputFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputFrame.BackgroundTransparency = 0.949999988079071
                InputFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
                InputFrame.BorderSizePixel = 0
                InputFrame.ClipsDescendants = true
                if InputConfig.Content == "" then
                    InputFrame.Position = UDim2.new(0.5, 0, 0, 29)
                else
                    InputFrame.Position = UDim2.new(0.5, 0, 0, InputContent.Position.Y.Offset + InputContent.AbsoluteSize.Y + 8)
                end
                InputFrame.Size = UDim2.new(1, -20, 0, 30)
                InputFrame.Name = "InputFrame"
                InputFrame.Parent = Input

                UICorner13.CornerRadius = UDim.new(0, 4)
                UICorner13.Parent = InputFrame

                InputTextBox.CursorPosition = -1
                InputTextBox.Font = Enum.Font.GothamBold
                InputTextBox.PlaceholderColor3 = Color3.fromRGB(120.00000044703484, 120.00000044703484,
                    120.00000044703484)
                InputTextBox.PlaceholderText = "Write ur input here!"
                InputTextBox.Text = InputConfig.Default
                InputTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                InputTextBox.TextSize = 12
                InputTextBox.TextXAlignment = Enum.TextXAlignment.Left
                InputTextBox.AnchorPoint = Vector2.new(0, 0.5)
                InputTextBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputTextBox.BackgroundTransparency = 0.9990000128746033
                InputTextBox.BorderColor3 = Color3.fromRGB(0, 0, 0)
                InputTextBox.BorderSizePixel = 0
                InputTextBox.Position = UDim2.new(0, 5, 0.5, 0)
                InputTextBox.Size = UDim2.new(1, -10, 1, -8)
                InputTextBox.Name = "InputTextBox"
                InputTextBox.Parent = InputFrame
                function InputFunc:Set(Value)
                    InputTextBox.Text = Value
                    InputFunc.Value = Value
                    InputConfig.Callback(Value)
                    ConfigData[configKey] = Value
                    SaveConfig()
                end

                InputFunc:Set(InputFunc.Value)

                InputTextBox.FocusLost:Connect(function()
                    InputFunc:Set(InputTextBox.Text)
                end)
                CountItem = CountItem + 1
                Elements[configKey] = InputFunc
                windowElementKeys[configKey] = true
                return InputFunc
            end
            
            function Items:AddDropdown(DropdownConfig)
                local DropdownConfig = DropdownConfig or {}
                DropdownConfig.Title = DropdownConfig.Title or "Title"
                DropdownConfig.Content = DropdownConfig.Content or ""
                DropdownConfig.Multi = DropdownConfig.Multi or false
                DropdownConfig.Options = DropdownConfig.Options or {}
                DropdownConfig.Default = DropdownConfig.Default or (DropdownConfig.Multi and {} or nil)
                DropdownConfig.Callback = DropdownConfig.Callback or function() end

                local configKey = "Dropdown_" .. DropdownConfig.Title
                if ConfigData[configKey] ~= nil then
                    DropdownConfig.Default = ConfigData[configKey]
                end

                local DropdownFunc = { Value = DropdownConfig.Default, Options = DropdownConfig.Options }

                local Dropdown = Instance.new("Frame")
                local DropdownButton = Instance.new("TextButton")
                local UICorner10 = Instance.new("UICorner")
                local DropdownTitle = Instance.new("TextLabel")
                local DropdownContent = Instance.new("TextLabel")
                local SelectOptionsFrame = Instance.new("Frame")
                local UICorner11 = Instance.new("UICorner")
                local OptionSelecting = Instance.new("TextLabel")
                local OptionImg = Instance.new("ImageLabel")

                Dropdown.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Dropdown.BackgroundTransparency = 0.935
                Dropdown.BorderSizePixel = 0
                -- The compact popup may extend below the 40px dropdown row.
                Dropdown.ClipsDescendants = false
                Dropdown.LayoutOrder = CountItem
                Dropdown.Size = UDim2.new(1, 0, 0, 40)
                Dropdown.Name = "Dropdown"
                MountSectionItem(Dropdown, DropdownConfig, true)

                DropdownButton.Text = ""
                DropdownButton.BackgroundTransparency = 1
                DropdownButton.Name = "ToggleButton"

                UICorner10.CornerRadius = UDim.new(0, 4)
                UICorner10.Parent = Dropdown

                DropdownTitle.Font = Enum.Font.GothamBold
                DropdownTitle.Text = DropdownConfig.Title
                DropdownTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
                DropdownTitle.TextSize = 13
                DropdownTitle.TextXAlignment = Enum.TextXAlignment.Left
                DropdownTitle.BackgroundTransparency = 1
                DropdownTitle.Position = UDim2.new(0, 10, 0, 8)
                DropdownTitle.Size = (DropdownConfig.FullWidth ~= false)
                    and UDim2.new(1, -180, 0, 13)
                    or UDim2.new(1, -20, 0, 13)
                DropdownTitle.Name = "DropdownTitle"
                DropdownTitle.Parent = Dropdown

                DropdownContent.Font = Enum.Font.GothamBold
                DropdownContent.Text = DropdownConfig.Content
                DropdownContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                DropdownContent.TextSize = 12
                DropdownContent.TextTransparency = 0.6
                DropdownContent.TextWrapped = true
                DropdownContent.TextXAlignment = Enum.TextXAlignment.Left
                DropdownContent.BackgroundTransparency = 1
                DropdownContent.Position = UDim2.new(0, 10, 0, 21)
                DropdownContent.Size = (DropdownConfig.FullWidth ~= false)
                    and UDim2.new(1, -180, 0, 12)
                    or UDim2.new(1, -20, 0, 12)
                DropdownContent.Name = "DropdownContent"
                DropdownContent.Parent = Dropdown

                if DropdownConfig.FullWidth ~= false then
                    Dropdown.Size = UDim2.new(1, 0, 0, 40)
                    SelectOptionsFrame.AnchorPoint = Vector2.new(1, 0.5)
                    SelectOptionsFrame.Position = UDim2.new(1, -7, 0.5, 0)
                    SelectOptionsFrame.Size = UDim2.new(0, 148, 0, 26)
                else
                    Dropdown.Size = UDim2.new(1, 0, 0, 64)
                    SelectOptionsFrame.AnchorPoint = Vector2.new(0.5, 1)
                    SelectOptionsFrame.Position = UDim2.new(0.5, 0, 1, -7)
                    SelectOptionsFrame.Size = UDim2.new(1, -20, 0, 24)
                end
                SelectOptionsFrame.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
                SelectOptionsFrame.BackgroundTransparency = 0
                SelectOptionsFrame.Name = "SelectOptionsFrame"
                SelectOptionsFrame.LayoutOrder = CountDropdown
                SelectOptionsFrame.Parent = Dropdown

                UICorner11.CornerRadius = UDim.new(0, 5)
                UICorner11.Parent = SelectOptionsFrame

                local SelectStroke = Instance.new("UIStroke")
                SelectStroke.Color = Color3.fromRGB(35, 35, 35)
                SelectStroke.Transparency = 0.45
                SelectStroke.Thickness = 1
                SelectStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                SelectStroke.Parent = SelectOptionsFrame

                -- The selector itself owns the interaction button. Keeping the
                -- hit target inside this visual frame makes open/close toggling
                -- deterministic even while the popup overlay is active.
                DropdownButton.Size = UDim2.fromScale(1, 1)
                DropdownButton.Position = UDim2.fromOffset(0, 0)
                DropdownButton.ZIndex = 123
                DropdownButton.Active = true
                DropdownButton.Selectable = true
                DropdownButton.AutoButtonColor = false
                DropdownButton.Parent = SelectOptionsFrame

                OptionSelecting.Font = Enum.Font.GothamBold
                OptionSelecting.Text = DropdownConfig.Multi and "Select Options" or "Select Option"
                OptionSelecting.TextColor3 = Color3.fromRGB(255, 255, 255)
                OptionSelecting.TextSize = 12
                OptionSelecting.TextTransparency = 0.6
                OptionSelecting.TextXAlignment = Enum.TextXAlignment.Left
                OptionSelecting.AnchorPoint = Vector2.new(0, 0.5)
                OptionSelecting.BackgroundTransparency = 1
                OptionSelecting.Position = UDim2.new(0, 5, 0.5, 0)
                OptionSelecting.Size = UDim2.new(1, -30, 1, -8)
                OptionSelecting.Name = "OptionSelecting"
                OptionSelecting.ZIndex = 121
                OptionSelecting.Parent = SelectOptionsFrame

                OptionImg.Image = resolveIcon("chevron-down")
                OptionImg.ImageColor3 = Color3.fromRGB(230, 230, 230)
                OptionImg.AnchorPoint = Vector2.new(1, 0.5)
                OptionImg.BackgroundTransparency = 1
                OptionImg.Position = UDim2.new(1, 0, 0.5, 0)
                OptionImg.Size = UDim2.new(0, 25, 0, 25)
                OptionImg.Name = "OptionImg"
                OptionImg.ZIndex = 121
                OptionImg.Parent = SelectOptionsFrame

                local DropdownContainer = Instance.new("CanvasGroup")
                DropdownContainer.Name = "InlineMenu"
                DropdownContainer.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                DropdownContainer.BackgroundTransparency = 0
                DropdownContainer.BorderSizePixel = 0
                DropdownContainer.ClipsDescendants = true
                DropdownContainer.Active = true
                DropdownContainer.AnchorPoint = Vector2.new(0, 0)
                DropdownContainer.Size = UDim2.fromOffset(220, 0)
                DropdownContainer.Visible = false
                DropdownContainer.GroupTransparency = 1
                DropdownContainer.ZIndex = 100
                DropdownContainer.Parent = DropdownPortal

                local MenuCorner = Instance.new("UICorner")
                MenuCorner.CornerRadius = UDim.new(0, 6)
                MenuCorner.Parent = DropdownContainer

                local MenuScale = Instance.new("UIScale")
                MenuScale.Name = "MenuScale"
                MenuScale.Scale = 0.96
                MenuScale.Parent = DropdownContainer

                local MenuShield = Instance.new("TextButton")
                MenuShield.Name = "InteractionShield"
                MenuShield.BackgroundTransparency = 1
                MenuShield.BorderSizePixel = 0
                MenuShield.Text = ""
                MenuShield.AutoButtonColor = false
                MenuShield.Active = true
                MenuShield.Selectable = false
                MenuShield.Size = UDim2.fromScale(1, 1)
                MenuShield.ZIndex = 101
                MenuShield.Parent = DropdownContainer

                local MenuStroke = Instance.new("UIStroke")
                MenuStroke.Color = Color3.fromRGB(35, 35, 35)
                MenuStroke.Transparency = 0.3
                MenuStroke.Thickness = 1
                MenuStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                MenuStroke.Parent = DropdownContainer

                local SearchBox = Instance.new("TextBox")
                SearchBox.PlaceholderText = "Search options..."
                SearchBox.PlaceholderColor3 = Color3.fromRGB(86, 86, 86)
                SearchBox.Font = Enum.Font.GothamMedium
                SearchBox.Text = ""
                SearchBox.TextSize = 10
                SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                SearchBox.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
                SearchBox.BackgroundTransparency = 0
                SearchBox.BorderSizePixel = 0
                SearchBox.Size = UDim2.new(1, -10, 0, 25)
                SearchBox.Position = UDim2.fromOffset(5, 5)
                SearchBox.ZIndex = 105
                SearchBox.ClearTextOnFocus = false
                SearchBox.Name = "SearchBox"
                SearchBox.Parent = DropdownContainer

                local SearchCorner = Instance.new("UICorner")
                SearchCorner.CornerRadius = UDim.new(0, 4)
                SearchCorner.Parent = SearchBox

                local ScrollSelect = Instance.new("ScrollingFrame")
                ScrollSelect.Size = UDim2.new(1, -10, 1, -40)
                ScrollSelect.Position = UDim2.fromOffset(5, 35)
                ScrollSelect.ZIndex = 103
                ScrollSelect.Active = true
                ScrollSelect.ScrollBarImageColor3 = Color3.fromRGB(35, 35, 35)
                ScrollSelect.ScrollBarImageTransparency = 0.25
                ScrollSelect.BorderSizePixel = 0
                ScrollSelect.BackgroundTransparency = 1
                ScrollSelect.ScrollBarThickness = 2
                ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, 0)
                ScrollSelect.Name = "ScrollSelect"
                ScrollSelect.Parent = DropdownContainer

                local UIListLayout4 = Instance.new("UIListLayout")
                UIListLayout4.Padding = UDim.new(0, 2)
                UIListLayout4.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayout4.Parent = ScrollSelect

                UIListLayout4:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, UIListLayout4.AbsoluteContentSize.Y)
                end)

                local updateInlineMenuSize

                SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
                    local query = string.lower(SearchBox.Text)
                    for _, option in pairs(ScrollSelect:GetChildren()) do
                        if option.Name == "Option" and option:FindFirstChild("OptionText") then
                            local text = string.lower(option.OptionText.Text)
                            option.Visible = query == "" or string.find(text, query, 1, true)
                        end
                    end
                    ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, UIListLayout4.AbsoluteContentSize.Y)
                    task.defer(function()
                        if updateInlineMenuSize then updateInlineMenuSize() end
                    end)
                end)

                local DropCount = 0
                local MenuOpen = false
                local MenuAnimationToken = 0
                local ActiveMenuTweens = {}
                Dropdown:SetAttribute("MenuOpen", false)
                local MaxVisibleOptions = 5
                local MenuAnimationDuration = 0.16

                local function countVisibleOptions()
                    local count = 0
                    for _, option in ipairs(ScrollSelect:GetChildren()) do
                        if option.Name == "Option" and option.Visible then
                            count = count + 1
                        end
                    end
                    return count
                end

                local PopupSide = "Right"
                local PopupFinalPosition = UDim2.fromOffset(0, 0)
                local PopupHiddenPosition = UDim2.fromOffset(0, 0)

                local function calculatePopupGeometry()
                    local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
                        or Vector2.new(1920, 1080)
                    local windowPosition = Main.AbsolutePosition
                    local windowSize = Main.AbsoluteSize
                    local popupWidth = math.clamp(math.floor(windowSize.X * 0.42), 200, 260)

                    local visibleCount = math.max(1, countVisibleOptions())
                    local desiredHeight = 40 + math.min(visibleCount, MaxVisibleOptions) * 32
                    local popupHeight = math.min(desiredHeight, math.max(104, windowSize.Y - 12))

                    local gap = 6
                    local rightSpace = viewportSize.X - (windowPosition.X + windowSize.X)
                    local leftSpace = windowPosition.X
                    if rightSpace >= popupWidth + gap then
                        PopupSide = "Right"
                    elseif leftSpace >= popupWidth + gap then
                        PopupSide = "Left"
                    else
                        PopupSide = rightSpace >= leftSpace and "Right" or "Left"
                    end

                    local popupX = PopupSide == "Right"
                        and (windowPosition.X + windowSize.X + gap)
                        or (windowPosition.X - popupWidth - gap)
                    popupX = math.clamp(popupX, 4, math.max(4, viewportSize.X - popupWidth - 4))

                    -- Start near the selected row, but never leave the visual
                    -- top/bottom bounds of the Oxide window.
                    local preferredY = SelectOptionsFrame.AbsolutePosition.Y
                    local minY = windowPosition.Y + 6
                    local maxY = windowPosition.Y + windowSize.Y - popupHeight - 6
                    local popupY = math.clamp(preferredY, minY, math.max(minY, maxY))
                    local hiddenX = popupX + (PopupSide == "Right" and -10 or 10)

                    DropdownContainer.Size = UDim2.fromOffset(popupWidth, popupHeight)
                    PopupFinalPosition = UDim2.fromOffset(popupX, popupY)
                    PopupHiddenPosition = UDim2.fromOffset(hiddenX, popupY)
                    DropdownContainer:SetAttribute("PopupSide", PopupSide)
                    DropdownContainer:SetAttribute("SourceDropdown", DropdownConfig.Title)
                    DropdownContainer:SetAttribute("PopupWidth", popupWidth)
                    DropdownContainer:SetAttribute("PopupHeight", popupHeight)
                end

                updateInlineMenuSize = function()
                    calculatePopupGeometry()
                    Dropdown:SetAttribute("MenuOpen", MenuOpen)
                end

                local function updatePopupPosition()
                    if DropdownContainer.Visible then
                        calculatePopupGeometry()
                        DropdownContainer.Position = MenuOpen and PopupFinalPosition or PopupHiddenPosition
                    end
                end

                local function cancelMenuTweens()
                    for _, tween in ipairs(ActiveMenuTweens) do
                        pcall(function() tween:Cancel() end)
                    end
                    table.clear(ActiveMenuTweens)
                end

                local function playMenuTween(target, tweenInfo, properties)
                    local tween = TweenService:Create(target, tweenInfo, properties)
                    table.insert(ActiveMenuTweens, tween)
                    tween:Play()
                    return tween
                end

                local function setMenuOpen(open)
                    if open == MenuOpen and DropdownContainer.Visible == open then return end
                    MenuOpen = open
                    MenuAnimationToken = MenuAnimationToken + 1
                    local animationToken = MenuAnimationToken
                    cancelMenuTweens()

                    local cell = Dropdown.Parent
                    local row = cell and cell.Parent
                    local tweenInfo = TweenInfo.new(
                        MenuAnimationDuration,
                        Enum.EasingStyle.Quart,
                        open and Enum.EasingDirection.Out or Enum.EasingDirection.In
                    )

                    -- Keep the whole portal interactive and elevated until the
                    -- close animation finishes, preventing click-through.
                    Dropdown.ZIndex = 90
                    if cell and cell:IsA("GuiObject") then cell.ZIndex = 89 end
                    if row and row:IsA("GuiObject") then row.ZIndex = 88 end
                    SelectOptionsFrame.ZIndex = 91
                    DropdownButton.ZIndex = 123
                    DropdownPortal.Active = false
                    Dropdown:SetAttribute("MenuOpen", MenuOpen)
                    updateInlineMenuSize()

                    playMenuTween(OptionImg, tweenInfo, { Rotation = open and 180 or 0 })

                    if open then
                        if ActiveDropdownCloser and ActiveDropdownCloser ~= setMenuOpen then
                            pcall(ActiveDropdownCloser, false, true)
                        end
                        ActiveDropdownCloser = setMenuOpen
                        DropdownContainer.Visible = true
                        DropdownContainer.Active = true
                        DropdownContainer.Position = PopupHiddenPosition
                        DropdownContainer.GroupTransparency = 1
                        MenuScale.Scale = 0.96
                        playMenuTween(DropdownContainer, tweenInfo, {
                            Position = PopupFinalPosition,
                            GroupTransparency = 0,
                        })
                        playMenuTween(MenuScale, tweenInfo, { Scale = 1 })
                    else
                        SearchBox:ReleaseFocus()
                        playMenuTween(DropdownContainer, tweenInfo, {
                            Position = PopupHiddenPosition,
                            GroupTransparency = 1,
                        })
                        playMenuTween(MenuScale, tweenInfo, { Scale = 0.96 })

                        task.delay(MenuAnimationDuration, function()
                            if animationToken ~= MenuAnimationToken or MenuOpen then return end
                            DropdownContainer.Visible = false
                            DropdownContainer.Active = false
                            Dropdown.ZIndex = 1
                            if cell and cell:IsA("GuiObject") then cell.ZIndex = 1 end
                            if row and row:IsA("GuiObject") then row.ZIndex = 1 end
                            SelectOptionsFrame.ZIndex = 1
                            DropdownButton.ZIndex = 123
                            if ActiveDropdownCloser == setMenuOpen then
                                ActiveDropdownCloser = nil
                                DropdownPortal.Active = false
                            end
                        end)
                    end
                end

                DropdownButton.Activated:Connect(function()
                    setMenuOpen(not MenuOpen)
                end)

                local function pointInside(guiObject, point)
                    if not guiObject or not guiObject.Visible then return false end
                    local position = guiObject.AbsolutePosition
                    local size = guiObject.AbsoluteSize
                    return point.X >= position.X
                        and point.X <= position.X + size.X
                        and point.Y >= position.Y
                        and point.Y <= position.Y + size.Y
                end

                -- Close the popup when clicking/tapping anywhere outside the
                -- selector and popup. Interactions inside search/options remain
                -- untouched and therefore do not dismiss the menu.
                trackCleanup(UserInputService.InputBegan:Connect(function(input)
                    if isDestroyed or not MenuOpen then return end

                    if input.KeyCode == Enum.KeyCode.Escape then
                        setMenuOpen(false)
                        return
                    end

                    if input.UserInputType ~= Enum.UserInputType.MouseButton1
                        and input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                    end

                    local point = Vector2.new(input.Position.X, input.Position.Y)

                    -- The selector button owns open/close toggling. The global
                    -- handler only dismisses clicks outside the selector/menu.
                    if pointInside(SelectOptionsFrame, point) then return end

                    if not pointInside(DropdownContainer, point) then
                        setMenuOpen(false)
                    end
                end))

                ScrolLayers:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                    if MenuOpen then updatePopupPosition() end
                end)
                Dropdown:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                    if MenuOpen then updatePopupPosition() end
                end)
                Main:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                    if MenuOpen then updatePopupPosition() end
                end)
                Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    if MenuOpen then updatePopupPosition() end
                end)

                function DropdownFunc:Clear()
                    for _, DropFrame in ScrollSelect:GetChildren() do
                        if DropFrame.Name == "Option" then
                            DropFrame:Destroy()
                        end
                    end
                    DropdownFunc.Value = DropdownConfig.Multi and {} or nil
                    DropdownFunc.Options = {}
                    OptionSelecting.Text = DropdownConfig.Multi and "Select Options" or "Select Option"
                    DropCount = 0
                    updateInlineMenuSize()
                end

                function DropdownFunc:AddOption(option)
                    local label, value
                    if typeof(option) == "table" and option.Label and option.Value ~= nil then
                        label = tostring(option.Label)
                        value = option.Value
                    else
                        label = tostring(option)
                        value = option
                    end

                    local Option = Instance.new("Frame")
                    local OptionButton = Instance.new("TextButton")
                    local OptionText = Instance.new("TextLabel")
                    local ChooseFrame = Instance.new("Frame")
                    local UIStroke15 = Instance.new("UIStroke")
                    local UICorner38 = Instance.new("UICorner")
                    local UICorner37 = Instance.new("UICorner")

                    Option.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
                    Option.BackgroundTransparency = 1
                    Option.Size = UDim2.new(1, -2, 0, 26)
                    Option.Name = "Option"
                    Option.ZIndex = 104
                    Option.Parent = ScrollSelect

                    UICorner37.CornerRadius = UDim.new(0, 3)
                    UICorner37.Parent = Option

                    OptionButton.BackgroundTransparency = 1
                    OptionButton.Size = UDim2.new(1, 0, 1, 0)
                    OptionButton.ZIndex = 106
                    OptionButton.Active = true
                    OptionButton.Selectable = true
                    OptionButton.AutoButtonColor = false
                    OptionButton.Text = ""
                    OptionButton.Name = "OptionButton"
                    OptionButton.Parent = Option

                    OptionText.Font = Enum.Font.GothamBold
                    OptionText.Text = label
                    OptionText.TextSize = 12
                    OptionText.TextColor3 = Color3.fromRGB(220, 220, 220)
                    OptionText.Position = UDim2.new(0, 9, 0, 8)
                    OptionText.Size = UDim2.new(1, -30, 0, 13)
                    OptionText.BackgroundTransparency = 1
                    OptionText.TextXAlignment = Enum.TextXAlignment.Left
                    OptionText.ZIndex = 105
                    OptionText.Name = "OptionText"
                    OptionText.Parent = Option

                    Option:SetAttribute("RealValue", value)

                    ChooseFrame.AnchorPoint = Vector2.new(0, 0.5)
                    ChooseFrame.BackgroundColor3 = GuiConfig.Color
                    ChooseFrame.Position = UDim2.new(0, 2, 0.5, 0)
                    ChooseFrame.Size = UDim2.new(0, 0, 0, 0)
                    ChooseFrame.Name = "ChooseFrame"
                    ChooseFrame.ZIndex = 105
                    ChooseFrame.Parent = Option

                    UIStroke15.Color = GuiConfig.Color
                    UIStroke15.Thickness = 1.6
                    UIStroke15.Transparency = 0.999
                    UIStroke15.Parent = ChooseFrame
                    UICorner38.Parent = ChooseFrame

                    OptionButton.Activated:Connect(function()
                        if DropdownConfig.Multi then
                            if not table.find(DropdownFunc.Value, value) then
                                table.insert(DropdownFunc.Value, value)
                            else
                                for i, v in pairs(DropdownFunc.Value) do
                                    if v == value then
                                        table.remove(DropdownFunc.Value, i)
                                        break
                                    end
                                end
                            end
                        else
                            DropdownFunc.Value = value
                        end
                        DropdownFunc:Set(DropdownFunc.Value)
                        -- Keep the popup open after selection, matching the
                        -- original dropdown behavior. Click the selector again
                        -- to close it.
                    end)
                    DropCount = DropCount + 1
                    updateInlineMenuSize()
                end

                function DropdownFunc:Set(Value)
                    if DropdownConfig.Multi then
                        DropdownFunc.Value = type(Value) == "table" and Value or {}
                    else
                        DropdownFunc.Value = (type(Value) == "table" and Value[1]) or Value
                    end

                    ConfigData[configKey] = DropdownFunc.Value
                    SaveConfig()

                    local texts = {}
                    for _, Drop in ScrollSelect:GetChildren() do
                        if Drop.Name == "Option" and Drop:FindFirstChild("OptionText") then
                            local v = Drop:GetAttribute("RealValue")
                            local selected = DropdownConfig.Multi and table.find(DropdownFunc.Value, v) or
                                DropdownFunc.Value == v

                            if selected then
                                TweenService:Create(Drop.ChooseFrame, TweenInfo.new(0.2),
                                    { Size = UDim2.new(0, 1, 0, 12) }):Play()
                                TweenService:Create(Drop.ChooseFrame.UIStroke, TweenInfo.new(0.2), { Transparency = 0 })
                                    :Play()
                                TweenService:Create(Drop, TweenInfo.new(0.2), { BackgroundTransparency = 0.935 }):Play()
                                table.insert(texts, Drop.OptionText.Text)
                            else
                                TweenService:Create(Drop.ChooseFrame, TweenInfo.new(0.1),
                                    { Size = UDim2.new(0, 0, 0, 0) }):Play()
                                TweenService:Create(Drop.ChooseFrame.UIStroke, TweenInfo.new(0.1),
                                    { Transparency = 0.999 }):Play()
                                TweenService:Create(Drop, TweenInfo.new(0.1), { BackgroundTransparency = 0.999 }):Play()
                            end
                        end
                    end

                    OptionSelecting.Text = (#texts == 0)
                        and (DropdownConfig.Multi and "Select Options" or "Select Option")
                        or table.concat(texts, ", ")

                    updateInlineMenuSize()

                    if DropdownConfig.Callback then
                        if DropdownConfig.Multi then
                            DropdownConfig.Callback(DropdownFunc.Value)
                        else
                            local str = (DropdownFunc.Value ~= nil) and tostring(DropdownFunc.Value) or ""
                            DropdownConfig.Callback(str)
                        end
                    end
                end

                function DropdownFunc:SetValue(val)
                    self:Set(val)
                end

                function DropdownFunc:GetValue()
                    return self.Value
                end

                function DropdownFunc:SetValues(newList, selecting)
                    newList = newList or {}
                    selecting = selecting or (DropdownConfig.Multi and {} or nil)
                    DropdownFunc:Clear()
                    for _, v in ipairs(newList) do
                        DropdownFunc:AddOption(v)
                    end
                    DropdownFunc.Options = newList
                    DropdownFunc:Set(selecting)
                end

                DropdownFunc:SetValues(DropdownFunc.Options, DropdownFunc.Value)

                CountItem = CountItem + 1
                CountDropdown = CountDropdown + 1
                Elements[configKey] = DropdownFunc
                windowElementKeys[configKey] = true
                return DropdownFunc
            end

            function Items:AddDivider()
                local Divider = Instance.new("Frame")
                Divider.Name = "Divider"
                MountSectionItem(Divider, { Column = "Full" }, true)
                Divider.AnchorPoint = Vector2.new(0.5, 0)
                Divider.Position = UDim2.new(0.5, 0, 0, 0)
                Divider.Size = UDim2.new(1, 0, 0, 2)
                Divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Divider.BackgroundTransparency = 0
                Divider.BorderSizePixel = 0
                Divider.LayoutOrder = CountItem

                local UIGradient = Instance.new("UIGradient")
                UIGradient.Color = ColorSequence.new {
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 90, 90)),
                    ColorSequenceKeypoint.new(0.5, GuiConfig.Color),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 90, 90))
                }
                UIGradient.Parent = Divider

                local UICorner = Instance.new("UICorner")
                UICorner.CornerRadius = UDim.new(0, 2)
                UICorner.Parent = Divider

                CountItem = CountItem + 1
                return Divider
            end

            function Items:AddSubSection(title)
                title = title or "Sub Section"

                local SubSection = Instance.new("Frame")
                SubSection.Name = "SubSection"
                MountSectionItem(SubSection, { Column = "Full" }, true)
                SubSection.BackgroundTransparency = 1
                SubSection.Size = UDim2.new(1, 0, 0, 22)
                SubSection.LayoutOrder = CountItem

                local Background = Instance.new("Frame")
                Background.Parent = SubSection
                Background.Size = UDim2.new(1, 0, 1, 0)
                Background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Background.BackgroundTransparency = 1
                Background.BorderSizePixel = 0
                Instance.new("UICorner", Background).CornerRadius = UDim.new(0, 6)

                local Label = Instance.new("TextLabel")
                Label.Parent = SubSection
                Label.AnchorPoint = Vector2.new(0, 0.5)
                Label.Position = UDim2.new(0, 10, 0.5, 0)
                Label.Size = UDim2.new(1, -20, 1, 0)
                Label.BackgroundTransparency = 1
                Label.Font = Enum.Font.GothamBold
                Label.Text = title
                Label.TextColor3 = GuiConfig.Color
                Label.TextSize = 12
                Label.TextXAlignment = Enum.TextXAlignment.Left

                CountItem = CountItem + 1
                return SubSection
            end

            CountSection = CountSection + 1
            return Items
        end

        CountTab = CountTab + 1
        local safeName = TabConfig.Name:gsub("%s+", "_")
        _G[safeName] = Sections
        return Sections
    end

    if GuiConfig.BuiltInInfo then
        BuiltInInfoTab = Tabs:AddTab({
            Name = "Info",
            Icon = "info"
        })

        local InfoSection = BuiltInInfoTab:AddSection({
            Title = "Info Script Hub",
            Layout = "Grid",
            ItemGap = 4
        })

        InfoSection:AddParagraph({
            Title = "Welcome to " .. tostring(GuiConfig.Title),
            Content = "Welcome! This hub is designed to keep every feature organized, responsive, and easy to use. Select a tab from the sidebar to get started.",
            Icon = "sparkles",
            Column = "Full",
            Row = 1
        })

        local DiscordSection = BuiltInInfoTab:AddSection({
            Title = "Discord",
            HideTitle = true,
            Layout = "Grid",
            ItemGap = 4
        })

        local DiscordInfo = DiscordSection:AddParagraph({
            Title = "Loading Discord Server...",
            Content = "Fetching member and online counts from Discord.",
            Icon = "discord",
            IconSize = 42,
            Column = "Full",
            Row = 1
        })

        local InviteCode = DiscordUrl:match("discord%.gg/([^/?#]+)")
            or DiscordUrl:match("discord%.com/invite/([^/?#]+)")
            or "OxideHub"
        local DiscordAPI = "https://discord.com/api/v10/invites/" .. InviteCode
            .. "?with_counts=true&with_expiration=true"

        local function formatCount(value)
            local number = math.max(0, math.floor(tonumber(value) or 0))
            local formatted = tostring(number)
            repeat
                local replaced
                formatted, replaced = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
            until replaced == 0
            return formatted
        end

        local function httpGetBody(url, accept)
            local requester = (syn and syn.request)
                or (http and http.request)
                or http_request
                or request

            if requester then
                local response = requester({
                    Url = url,
                    Method = "GET",
                    Headers = { ["Accept"] = accept or "*/*" }
                })
                local status = response and (response.StatusCode or response.Status)
                if status and tonumber(status) and tonumber(status) >= 400 then
                    error("HTTP " .. tostring(status))
                end
                local body = response and (response.Body or response.body)
                if not body or body == "" then error("Empty HTTP response") end
                return body
            end
            return game:HttpGet(url)
        end

        local function requestDiscordInfo()
            local responseBody = httpGetBody(DiscordAPI, "application/json")
            local decoded = HttpService:JSONDecode(responseBody)
            if type(decoded) ~= "table" or type(decoded.guild) ~= "table" then
                error(decoded and decoded.message or "Invalid Discord invite response")
            end
            return decoded
        end

        local function getDiscordIconAsset(guild)
            if not guild or not guild.id or not guild.icon then return nil end
            if not writefile or not getcustomasset then return nil end

            local extension = tostring(guild.icon):sub(1, 2) == "a_" and "gif" or "png"
            local cachePath = "Oxide/Cache/discord_" .. tostring(guild.id)
                .. "_" .. tostring(guild.icon) .. "." .. extension

            local cached = false
            if isfile then
                local ok, exists = pcall(isfile, cachePath)
                cached = ok and exists
            end

            if not cached then
                local iconUrl = "https://cdn.discordapp.com/icons/" .. tostring(guild.id)
                    .. "/" .. tostring(guild.icon) .. "." .. extension .. "?size=256"
                local bytes = httpGetBody(iconUrl, "image/*")
                writefile(cachePath, bytes)
            end

            local ok, asset = pcall(getcustomasset, cachePath)
            return ok and asset or nil
        end

        local function updateDiscordInfo(showNotification)
            DiscordInfo:SetTitle("Loading Discord Server...")
            DiscordInfo:SetContent("Fetching member and online counts from Discord.")
            DiscordInfo:SetIcon("discord")

            local ok, response = pcall(requestDiscordInfo)
            if isDestroyed then return end

            if ok and response and response.guild then
                local guild = response.guild
                DiscordInfo:SetTitle(tostring(guild.name or "Discord Server"))
                DiscordInfo:SetContent(
                    ' <font color="#52525b">•</font> Member Count: '
                    .. formatCount(response.approximate_member_count)
                    .. '\n <font color="#16a34a">•</font> Online Count: '
                    .. formatCount(response.approximate_presence_count)
                )
                if guild.id and guild.icon then
                    local iconOk, iconAsset = pcall(getDiscordIconAsset, guild)
                    if iconOk and iconAsset then
                        DiscordInfo:SetIcon(iconAsset)
                    else
                        DiscordInfo:SetIcon("discord")
                    end
                end
                if showNotification then
                    notif("Discord server information updated.", 3, GuiConfig.Color, "Oxide", "Discord")
                end
            else
                DiscordInfo:SetTitle("Error Receiving Discord Information")
                DiscordInfo:SetContent(tostring(response or "Unknown error occurred"))
                DiscordInfo:SetIcon("triangle-alert")
                if showNotification then
                    notif("Unable to update Discord server information.", 3, Color3.fromRGB(220, 90, 90), "Oxide", "Discord")
                end
            end
        end

        DiscordSection:AddButton({
            Title = "Copy Discord Invite",
            SubTitle = "Update Info",
            Column = "Full",
            Row = 2,
            Icon = "link",
            SubIcon = "refresh-cw",
            Callback = copyDiscordInvite,
            SubCallback = function()
                trackCleanup(task.spawn(updateDiscordInfo, true))
            end
        })

        trackCleanup(task.spawn(updateDiscordInfo, false))
    end

    -- ═══════════════════════════════════════════════════
    -- SETTINGS TAB (Config Profile System)
    -- ═══════════════════════════════════════════════════
    function Tabs:AddConfigTab()
        pcall(function()
            local SettingsTab = Tabs:AddTab({ Name = "Config", Icon = "settings" })

            -- helper notif dengan title "Config" (global notif: msg, delay, color, title)
            local function cnotif(msg, delay)
                notif(msg, delay, GuiConfig.Color, "Config")
            end

            -- ═══ INFO SECTION ═══
            -- local InfoSection = SettingsTab:AddSection("Informasi", true)
            -- InfoSection:AddParagraph({
            --     Title   = "Auto-Save Aktif",
            --     Content = "Semua perubahan (toggle, slider, dropdown) otomatis tersimpan ke file saat kamu ubah. Saat relog, setting kamu akan otomatis ter-load kembali.\n\nGunakan Profile untuk menyimpan beberapa preset yang berbeda."
            -- })

            -- ═══ AUTO-LOAD SAAT STARTUP ═══
            -- Panggil LoadConfigElements setelah semua element dibuat
            task.defer(function()
                pcall(function()
                    LoadConfigElements()
                end)
            end)

            -- ═══ PROFILE SECTION ═══
            local ConfigSection = SettingsTab:AddSection("Config Profile")

            local profileDropdown
            local selectedProfile = "None"

            local function RefreshProfileDropdown()
                local fresh = GetProfileList()
                if #fresh == 0 then table.insert(fresh, "None") end
                if profileDropdown and profileDropdown.SetValues then
                    profileDropdown:SetValues(fresh, fresh[1] or "None")
                end
                selectedProfile = fresh[1] or "None"
                return fresh
            end

            local profiles = GetProfileList()
            if #profiles == 0 then table.insert(profiles, "None") end

            profileDropdown = ConfigSection:AddDropdown({
                Title   = "Select Profile",
                Content = "Select the profile you want to load or delete",
                Options = profiles,
                Default = profiles[1] or "None",
                Multi   = false,
                Callback = function(val)
                    selectedProfile = val
                end
            })

            ConfigSection:AddButton({
                Title = "Refresh",
                Callback = function()
                    local fresh = RefreshProfileDropdown()
                    cnotif("Found " .. tostring(#fresh) .. " profiles", 3)
                end
            })

            local profileNameInput = ConfigSection:AddInput({
                Title   = "New Profile Name",
                Content = "Type a name to save new profile",
                Default = "",
                Callback = function(val) end
            })


            ConfigSection:AddButton({
                Title    = "Save Profile",
                SubTitle = "Load Profile",
                Callback = function()
                    local name = profileNameInput.Value
                    if not name or name == "" or name == "None" then
                        cnotif("Type a profile name first!", 3)
                        return
                    end
                    name = name:gsub("[^%w_%-]", "_")
                    local ok = SaveProfile(name)
                    if ok then
                        cnotif("Profile '" .. name .. "' saved successfully!", 4)
                        task.wait(0.2)
                        local newList = GetProfileList()
                        if not table.find(newList, name) then
                            table.insert(newList, name)
                            table.sort(newList)
                        end
                        if #newList > 1 then
                            for i = #newList, 1, -1 do
                                if newList[i] == "None" then table.remove(newList, i) end
                            end
                        end
                        if profileDropdown and profileDropdown.SetValues then
                            profileDropdown:SetValues(newList, name)
                        end
                        selectedProfile = name
                    else
                        cnotif("Failed to save profile!", 3)
                    end
                end,
                SubCallback = function()
                    if not selectedProfile or selectedProfile == "" or selectedProfile == "None" then
                        cnotif("Select a profile from the dropdown first!", 3)
                        return
                    end
                    cnotif("Loading '" .. selectedProfile .. "'...", 2)
                    task.spawn(function()
                        local ok = LoadProfile(selectedProfile)
                        if ok then
                            cnotif("Profile '" .. selectedProfile .. "' loaded successfully!", 4)
                        else
                            cnotif("Failed to load profile!", 3)
                        end
                    end)
                end
            })

            ConfigSection:AddButton({
                Title    = "Delete Profile",
                SubTitle = "Copy Config",
                Callback = function()
                    if not selectedProfile or selectedProfile == "" or selectedProfile == "None" then
                        cnotif("Select the profile you want to delete!", 3)
                        return
                    end
                    local ok = DeleteProfile(selectedProfile)
                    if ok then
                        cnotif("Profile '" .. selectedProfile .. "' dihapus!", 3)
                        selectedProfile = "None"
                        local newList = GetProfileList()
                        if #newList == 0 then table.insert(newList, "None") end
                        if profileDropdown and profileDropdown.SetValues then
                            profileDropdown:SetValues(newList, newList[1])
                        end
                    else
                        cnotif("Failed to delete profile!", 3)
                    end
                end,
                SubCallback = function()
                    -- Copy current ConfigData as JSON to clipboard
                    if setclipboard then
                        local json = HttpService:JSONEncode(ConfigData)
                        setclipboard(json)
                        cnotif("Config copied to clipboard successfully!", 3)
                    else
                        cnotif("Executor does not support clipboard!", 3)
                    end
                end
            })

            -- ═══ IMPORT CONFIG ═══
            local ImportSection = SettingsTab:AddSection("Import Config")

            local importInput = ImportSection:AddPanel({
                Title       = "Paste JSON Config",
                Placeholder = "Paste JSON Config here...",
                ButtonText  = "Import & Load",
                Callback    = function(val)
                    if not val or val == "" then
                        cnotif("JSON Input is empty!", 3)
                        return
                    end
                    local ok, data = pcall(function()
                        return HttpService:JSONDecode(val)
                    end)
                    if not ok or type(data) ~= "table" then
                        cnotif("Invalid JSON!", 3)
                        return
                    end
                    -- Apply ke ConfigData dan semua elemen
                    for key, v in pairs(data) do
                        ConfigData[key] = v
                    end
                    SaveConfig()
                    for key, element in pairs(Elements) do
                        if ConfigData[key] ~= nil and element.Set then
                            pcall(function()
                                element:Set(ConfigData[key])
                            end)
                            task.wait(0.02)
                        end
                    end
                    cnotif("Config imported successfully!", 4)
                end
            })


            -- ═══ THEME SECTION ═══
            local ThemeSection = SettingsTab:AddSection("Theme")

            local themePresets = {
                ["Blue"]  = { color = Color3.fromRGB(150, 150, 150),  color2 = Color3.fromRGB(0, 0, 14) },
                ["Red"] = { color = Color3.fromRGB(255, 66, 66),  color2 = Color3.fromRGB(14, 0, 0) },
                ["Purple"]  = { color = Color3.fromRGB(160, 30, 255), color2 = Color3.fromRGB(10, 0, 14) },
            }

            ThemeSection:AddDropdown({
                Title   = "Theme",
                Options = { "Blue", "Red", "Purple" },
                Default = "Blue",
                Callback = function(value)
                    local preset = themePresets[value]
                    if preset then
                        Tabs:SetTheme(preset.color, preset.color2)
                    end
                end
            })
        end)
    end


    -- Kumpulkan referensi elemen warna yang bisa diubah secara dinamis
    local _themeColorElements = {
        titleLabel  = TextLabel,
        footerFrm   = FooterFrame,
        mainStroke  = MainStroke,
        decideFrm   = DecideFrame,
        tabDivider  = TabDivider,
        mainBG      = Main,
        topBar      = Top,
        executorFrm = Executor,
    }
    local _themeTabChooseFrames = {} -- referensi semua ChooseFrame tab

    function Tabs:SetTheme(newColor, newColor2)
        GuiConfig.Color  = newColor
        GuiConfig.Color2 = newColor2 or newColor

        -- Update topbar (Title & Footer text)
        -- TweenService:Create(_themeColorElements.titleLabel, TweenInfo.new(0.4), { TextColor3 = newColor }):Play()
        local chipSurface = newColor:Lerp(Color3.fromRGB(24, 24, 24), 0.9)
        if _themeColorElements.footerFrm then
            TweenService:Create(_themeColorElements.footerFrm, TweenInfo.new(0.4), {
                BackgroundColor3 = chipSurface
            }):Play()
        end
        if _themeColorElements.executorFrm then
            TweenService:Create(_themeColorElements.executorFrm, TweenInfo.new(0.4), {
                BackgroundColor3 = chipSurface
            }):Play()
        end

        -- Update border stroke, DecideFrame & TabDivider
        TweenService:Create(_themeColorElements.mainStroke, TweenInfo.new(0.4), {
            Color = newColor:Lerp(Color3.fromRGB(35, 35, 35), 0.75)
        }):Play()
        TweenService:Create(_themeColorElements.decideFrm, TweenInfo.new(0.4), {
            BackgroundColor3 = newColor:Lerp(Color3.fromRGB(35, 35, 35), 0.75),
            BackgroundTransparency = 0.65
        }):Play()
        if _themeColorElements.tabDivider then
            TweenService:Create(_themeColorElements.tabDivider, TweenInfo.new(0.4), {
                BackgroundColor3 = newColor:Lerp(Color3.fromRGB(35, 35, 35), 0.75),
                BackgroundTransparency = 0.65
            }):Play()
        end

        -- Solid tinted surfaces eliminate color banding entirely. Lerp keeps
        -- alternate themes dark while retaining a visible accent undertone.
        TweenService:Create(_themeColorElements.mainBG, TweenInfo.new(0.4), {
            BackgroundColor3 = newColor:Lerp(Color3.fromRGB(20, 20, 20), 0.93)
        }):Play()
        if _themeColorElements.topBar then
            TweenService:Create(_themeColorElements.topBar, TweenInfo.new(0.4), {
                BackgroundColor3 = newColor:Lerp(Color3.fromRGB(20, 20, 20), 0.93),
                BackgroundTransparency = 0.01
            }):Play()
        end

        -- Update ChooseFrame & UIStroke di semua tab
        for _, tab in ScrollTab:GetChildren() do
            if tab.Name == "Tab" then
                local cf = tab:FindFirstChild("ChooseFrame")
                if cf then
                    TweenService:Create(cf, TweenInfo.new(0.3), { BackgroundColor3 = newColor }):Play()
                    local stk = cf:FindFirstChildOfClass("UIStroke")
                    if stk then
                        TweenService:Create(stk, TweenInfo.new(0.3), { Color = newColor }):Play()
                    end
                end
            end
        end

        -- Update semua elemen di dalam OxideOnTop secara langsung
        for _, gui in OxideOnTop:GetDescendants() do
            if gui.Name == "SectionTitle" and gui:IsA("TextLabel") then
                local sectionReal = gui.Parent
                if sectionReal and sectionReal.Name == "SectionReal" then
                    local featureFrame = sectionReal:FindFirstChild("FeatureFrame")
                    -- Jika FeatureFrame tidak ada (AlwaysOpen=true) atau rotasinya 90 (terbuka)
                    if not featureFrame or featureFrame.Rotation > 45 then
                        TweenService:Create(gui, TweenInfo.new(0.4), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
                    end
                end
            end

            -- SubSection label
            if gui.Name == "SubSection" and gui:IsA("Frame") then
                local lbl = gui:FindFirstChildOfClass("TextLabel")
                if lbl then
                    TweenService:Create(lbl, TweenInfo.new(0.4), { TextColor3 = newColor }):Play()
                end
            end

            -- Divider gradient
            if gui.Name == "Divider" and gui:IsA("Frame") then
                local grad = gui:FindFirstChildOfClass("UIGradient")
                if grad then
                    grad.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 90, 90)),
                        ColorSequenceKeypoint.new(0.5, newColor),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 90, 90))
                    })
                end
            end

            -- Dropdown ChooseFrame option
            if gui.Name == "ChooseFrame" and gui:IsA("Frame") and gui.Parent and gui.Parent.Name == "Option" then
                TweenService:Create(gui, TweenInfo.new(0.3), { BackgroundColor3 = newColor }):Play()
                local stk = gui:FindFirstChildOfClass("UIStroke")
                if stk then
                    TweenService:Create(stk, TweenInfo.new(0.3), { Color = newColor }):Play()
                end
            end

            -- Toggle yang sedang ON (FeatureFrame.BackgroundTransparency ≈ 0)
            if gui.Name == "FeatureFrame" and gui:IsA("Frame") and gui.Parent and gui.Parent.Name == "Toggle" then
                if gui.BackgroundTransparency < 0.1 then
                    -- toggle ini ON, update warnanya langsung
                    TweenService:Create(gui, TweenInfo.new(0.3), { BackgroundColor3 = newColor }):Play()
                    local stk = gui:FindFirstChildOfClass("UIStroke")
                    if stk then
                        TweenService:Create(stk, TweenInfo.new(0.3), { Color = newColor }):Play()
                    end
                    -- update juga teks judul toggle yang ON
                    local toggleParent = gui.Parent
                    if toggleParent then
                        local ttl = toggleParent:FindFirstChild("ToggleTitle")
                        if ttl then
                            TweenService:Create(ttl, TweenInfo.new(0.3), { TextColor3 = newColor }):Play()
                        end
                    end
                end
            end

        end
    end

    -- Keep the window hidden while the startup loader plays; reveal once
    -- the slam-in intro finishes (same flow as Libary.lua).
    if loadingEnabled and LoadingLayer then
        DropShadowHolder.Visible = false
        task.defer(function()
            while not loadingMotionComplete and not isDestroyed do
                RunService.Heartbeat:Wait()
            end
            if isDestroyed or not LoadingLayer.Parent then return end
            DropShadowHolder.Visible = true
            MinimizedBar.Visible = false
            local fo = TweenService:Create(LoadingLayer, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
                GroupTransparency = 1,
            })
            fo:Play()
            if loadingBlur then
                TweenService:Create(loadingBlur, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), { Size = 0 }):Play()
            end
            fo.Completed:Wait()
            if LoadingLayer and LoadingLayer.Parent then LoadingLayer:Destroy() end
            pcall(function() if loadingBlur then loadingBlur:Destroy() end end)
            if isDestroyed then return end
            loadingComplete = true
        end)
    end

    -- ════════════════════════════════════════════════════════════════
    -- PROFILE + LIVE PERFORMANCE PANELS (K to toggle, old UI style)
    -- ════════════════════════════════════════════════════════════════
    local profileWidth     = math.max(280, tonumber(GuiConfig.ProfileWidth) or 300)
    local bottomMargin     = math.max(10, tonumber(GuiConfig.ProfileBottomMargin) or 18)
    local profileOpenPos   = UDim2.new(1, -18, 1, -bottomMargin)
    local profileClosedPos = UDim2.new(1, profileWidth + 28, 1, -bottomMargin)
    local profileOpen      = false
    local PROFILE_TWEEN    = TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    local PANEL_ACC       = ThemeColors.Accent
    local PANEL_WHITE     = Color3.fromRGB(255, 255, 255)
    local PANEL_TEXT_GRAY = Color3.fromRGB(154, 154, 154)
    local PANEL_TEXT_DIM  = Color3.fromRGB(139, 139, 139)
    local PANEL_ELEMENT   = Color3.fromRGB(31, 31, 31)
    local PANEL_CARD      = Color3.fromRGB(24, 24, 24)
    local PANEL_BORDER    = ThemeColors.Border
    local PANEL_BADGE     = Color3.fromRGB(42, 42, 42)
    local PANEL_BADGE_IDLE= Color3.fromRGB(34, 34, 34)
    local PANEL_GREEN     = Color3.fromRGB(105, 166, 124)

    local function panelCorner(inst, radius)
        Instance.new("UICorner", inst).CornerRadius = UDim.new(0, radius)
    end
    local function panelStroke(inst, color)
        local s = Instance.new("UIStroke")
        s.Color = color
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = inst
    end

    -- ── Profile panel ────────────────────────────────────────────────────
    local ProfilePanel = Instance.new("CanvasGroup")
    ProfilePanel.Name = "UserProfile"
    ProfilePanel.AnchorPoint = Vector2.new(1, 1)
    ProfilePanel.Position = profileClosedPos
    ProfilePanel.Size = UDim2.fromOffset(profileWidth, 330)
    ProfilePanel.BackgroundColor3 = PANEL_CARD
    ProfilePanel.GroupTransparency = 1
    ProfilePanel.ClipsDescendants = true
    ProfilePanel.ZIndex = 150
    ProfilePanel.Parent = OxideOnTop
    panelCorner(ProfilePanel, 14)

    local profileHeader = Instance.new("Frame")
    profileHeader.Size = UDim2.new(1, 0, 0, 60)
    profileHeader.BackgroundTransparency = 1
    profileHeader.ZIndex = 151
    profileHeader.Parent = ProfilePanel
    local profileTitle = Instance.new("TextLabel")
    profileTitle.Text = tostring(GuiConfig.ProfileTitle or "PLAYER PROFILE")
    profileTitle.Font = Enum.Font.GothamBold
    profileTitle.TextSize = 13
    profileTitle.TextColor3 = PANEL_WHITE
    profileTitle.TextXAlignment = Enum.TextXAlignment.Left
    profileTitle.BackgroundTransparency = 1
    profileTitle.Position = UDim2.fromOffset(18, 12)
    profileTitle.Size = UDim2.new(1, -36, 0, 18)
    profileTitle.ZIndex = 152
    profileTitle.Parent = profileHeader
    local profileSub = Instance.new("TextLabel")
    profileSub.Text = "Live session overview"
    profileSub.Font = Enum.Font.Gotham
    profileSub.TextSize = 10
    profileSub.TextColor3 = PANEL_TEXT_DIM
    profileSub.TextXAlignment = Enum.TextXAlignment.Left
    profileSub.BackgroundTransparency = 1
    profileSub.Position = UDim2.fromOffset(18, 32)
    profileSub.Size = UDim2.new(1, -36, 0, 15)
    profileSub.ZIndex = 152
    profileSub.Parent = profileHeader
    local profileHeaderLine = Instance.new("Frame")
    profileHeaderLine.Position = UDim2.new(0, 18, 1, -1)
    profileHeaderLine.Size = UDim2.new(1, -36, 0, 1)
    profileHeaderLine.BackgroundColor3 = PANEL_BORDER
    profileHeaderLine.ZIndex = 151
    profileHeaderLine.Parent = profileHeader

    local identityCard = Instance.new("Frame")
    identityCard.Position = UDim2.fromOffset(16, 72)
    identityCard.Size = UDim2.new(1, -32, 0, 106)
    identityCard.BackgroundColor3 = PANEL_ELEMENT
    identityCard.ZIndex = 151
    identityCard.Parent = ProfilePanel
    panelCorner(identityCard, 11)
    panelStroke(identityCard, PANEL_BORDER)

    local profileAvatarHolder = Instance.new("Frame")
    profileAvatarHolder.AnchorPoint = Vector2.new(0, 0.5)
    profileAvatarHolder.Position = UDim2.new(0, 14, 0.5, 0)
    profileAvatarHolder.Size = UDim2.fromOffset(70, 70)
    profileAvatarHolder.BackgroundColor3 = PANEL_BADGE
    profileAvatarHolder.ZIndex = 152
    profileAvatarHolder.Parent = identityCard
    panelCorner(profileAvatarHolder, 99)
    panelStroke(profileAvatarHolder, PANEL_BORDER)

    local profileAvatar = Instance.new("ImageLabel")
    profileAvatar.Name = "Avatar"
    profileAvatar.Image = ""
    profileAvatar.BackgroundTransparency = 1
    profileAvatar.Position = UDim2.fromOffset(4, 4)
    profileAvatar.Size = UDim2.new(1, -8, 1, -8)
    profileAvatar.ScaleType = Enum.ScaleType.Crop
    profileAvatar.ZIndex = 153
    profileAvatar.Parent = profileAvatarHolder
    panelCorner(profileAvatar, 99)

    local profileOnlineRing = Instance.new("Frame")
    profileOnlineRing.AnchorPoint = Vector2.new(1, 1)
    profileOnlineRing.Position = UDim2.new(1, 0, 1, 0)
    profileOnlineRing.Size = UDim2.fromOffset(16, 16)
    profileOnlineRing.BackgroundColor3 = PANEL_ELEMENT
    profileOnlineRing.ZIndex = 154
    profileOnlineRing.Parent = profileAvatarHolder
    panelCorner(profileOnlineRing, 99)
    local profileOnlineDot = Instance.new("Frame")
    profileOnlineDot.AnchorPoint = Vector2.new(0.5, 0.5)
    profileOnlineDot.Position = UDim2.fromScale(0.5, 0.5)
    profileOnlineDot.Size = UDim2.fromOffset(9, 9)
    profileOnlineDot.BackgroundColor3 = PANEL_GREEN
    profileOnlineDot.ZIndex = 155
    profileOnlineDot.Parent = profileOnlineRing
    panelCorner(profileOnlineDot, 99)

    local profileName = Instance.new("TextLabel")
    profileName.Text = LocalPlayer and LocalPlayer.DisplayName or "Player"
    profileName.Font = Enum.Font.GothamBold
    profileName.TextSize = 15
    profileName.TextColor3 = PANEL_WHITE
    profileName.TextXAlignment = Enum.TextXAlignment.Left
    profileName.TextTruncate = Enum.TextTruncate.AtEnd
    profileName.BackgroundTransparency = 1
    profileName.Position = UDim2.fromOffset(98, 16)
    profileName.Size = UDim2.new(1, -112, 0, 20)
    profileName.ZIndex = 152
    profileName.Parent = identityCard

    local profileHandle = Instance.new("TextLabel")
    profileHandle.Text = LocalPlayer and ("@" .. LocalPlayer.Name) or "@unknown"
    profileHandle.Font = Enum.Font.GothamMedium
    profileHandle.TextSize = 11
    profileHandle.TextColor3 = PANEL_TEXT_DIM
    profileHandle.TextXAlignment = Enum.TextXAlignment.Left
    profileHandle.TextTruncate = Enum.TextTruncate.AtEnd
    profileHandle.BackgroundTransparency = 1
    profileHandle.Position = UDim2.fromOffset(98, 38)
    profileHandle.Size = UDim2.new(1, -112, 0, 16)
    profileHandle.ZIndex = 152
    profileHandle.Parent = identityCard

    local profileConnectedBadge = Instance.new("Frame")
    profileConnectedBadge.Position = UDim2.fromOffset(98, 60)
    profileConnectedBadge.Size = UDim2.fromOffset(88, 22)
    profileConnectedBadge.BackgroundColor3 = PANEL_BADGE_IDLE
    profileConnectedBadge.ZIndex = 152
    profileConnectedBadge.Parent = identityCard
    panelCorner(profileConnectedBadge, 7)
    local profileConnectedDot = Instance.new("Frame")
    profileConnectedDot.AnchorPoint = Vector2.new(0, 0.5)
    profileConnectedDot.Position = UDim2.new(0, 8, 0.5, 0)
    profileConnectedDot.Size = UDim2.fromOffset(6, 6)
    profileConnectedDot.BackgroundColor3 = PANEL_GREEN
    profileConnectedDot.ZIndex = 153
    profileConnectedDot.Parent = profileConnectedBadge
    panelCorner(profileConnectedDot, 99)
    local profileConnectedText = Instance.new("TextLabel")
    profileConnectedText.Text = "CONNECTED"
    profileConnectedText.Font = Enum.Font.GothamBold
    profileConnectedText.TextSize = 8
    profileConnectedText.TextColor3 = PANEL_TEXT_GRAY
    profileConnectedText.TextXAlignment = Enum.TextXAlignment.Left
    profileConnectedText.BackgroundTransparency = 1
    profileConnectedText.Position = UDim2.fromOffset(20, 0)
    profileConnectedText.Size = UDim2.new(1, -25, 1, 0)
    profileConnectedText.ZIndex = 153
    profileConnectedText.Parent = profileConnectedBadge

    local detailsTitle = Instance.new("TextLabel")
    detailsTitle.Text = "ACCOUNT DETAILS"
    detailsTitle.Font = Enum.Font.GothamBold
    detailsTitle.TextSize = 10
    detailsTitle.TextColor3 = PANEL_TEXT_DIM
    detailsTitle.TextXAlignment = Enum.TextXAlignment.Left
    detailsTitle.BackgroundTransparency = 1
    detailsTitle.Position = UDim2.fromOffset(18, 192)
    detailsTitle.Size = UDim2.new(1, -36, 0, 14)
    detailsTitle.ZIndex = 152
    detailsTitle.Parent = ProfilePanel

    local detailsCard = Instance.new("Frame")
    detailsCard.Position = UDim2.fromOffset(16, 210)
    detailsCard.Size = UDim2.new(1, -32, 0, 102)
    detailsCard.BackgroundColor3 = PANEL_ELEMENT
    detailsCard.ZIndex = 151
    detailsCard.Parent = ProfilePanel
    panelCorner(detailsCard, 11)
    panelStroke(detailsCard, PANEL_BORDER)

    local profilePingLabel
    local function addProfileDetail(index, labelText, valueText)
        local y = (index - 1) * 34
        local row = Instance.new("Frame")
        row.Position = UDim2.fromOffset(0, y)
        row.Size = UDim2.new(1, 0, 0, 34)
        row.BackgroundTransparency = 1
        row.ZIndex = 152
        row.Parent = detailsCard
        local label = Instance.new("TextLabel")
        label.Text = labelText
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 10
        label.TextColor3 = PANEL_TEXT_DIM
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(14, 0)
        label.Size = UDim2.new(0.46, -14, 1, 0)
        label.ZIndex = 153
        label.Parent = row
        local value = Instance.new("TextLabel")
        value.Text = valueText
        value.Font = Enum.Font.GothamMedium
        value.TextSize = 11
        value.TextColor3 = PANEL_WHITE
        value.TextXAlignment = Enum.TextXAlignment.Right
        value.TextTruncate = Enum.TextTruncate.AtEnd
        value.BackgroundTransparency = 1
        value.Position = UDim2.new(0.46, 0, 0, 0)
        value.Size = UDim2.new(0.54, -14, 1, 0)
        value.ZIndex = 153
        value.Parent = row
        if index < 3 then
            local sep = Instance.new("Frame")
            sep.Position = UDim2.new(0, 14, 1, -1)
            sep.Size = UDim2.new(1, -28, 0, 1)
            sep.BackgroundColor3 = PANEL_BORDER
            sep.ZIndex = 153
            sep.Parent = row
        end
        return value
    end
    addProfileDetail(1, "USER ID",     LocalPlayer and tostring(LocalPlayer.UserId) or "N/A")
    addProfileDetail(2, "ACCOUNT AGE", LocalPlayer and (tostring(LocalPlayer.AccountAge) .. " days") or "N/A")
    profilePingLabel = addProfileDetail(3, "PING", "-- ms")

    -- ── Live performance panel ──────────────────────────────────────────
    local perfWidth     = math.max(236, tonumber(GuiConfig.PerformanceWidth) or 260)
    local perfHeight    = math.max(250, tonumber(GuiConfig.PerformanceHeight) or 262)
    local panelGap      = math.max(8, tonumber(GuiConfig.ProfilePanelGap) or 12)
    local perfOpenPos   = UDim2.new(1, -(18 + profileWidth + panelGap), 1, -bottomMargin)
    local perfClosedPos = UDim2.new(1, perfWidth + 36, 1, -bottomMargin)

    local PerfPanel = Instance.new("CanvasGroup")
    PerfPanel.Name = "LivePerformance"
    PerfPanel.AnchorPoint = Vector2.new(1, 1)
    PerfPanel.Position = perfClosedPos
    PerfPanel.Size = UDim2.fromOffset(perfWidth, perfHeight)
    PerfPanel.BackgroundColor3 = PANEL_CARD
    PerfPanel.GroupTransparency = 1
    PerfPanel.ClipsDescendants = true
    PerfPanel.ZIndex = 149
    PerfPanel.Parent = OxideOnTop
    panelCorner(PerfPanel, 14)

    local perfHeader = Instance.new("Frame")
    perfHeader.Size = UDim2.new(1, 0, 0, 52)
    perfHeader.BackgroundTransparency = 1
    perfHeader.ZIndex = 150
    perfHeader.Parent = PerfPanel
    local perfTitle = Instance.new("TextLabel")
    perfTitle.Text = tostring(GuiConfig.PerformanceTitle or "LIVE PERFORMANCE")
    perfTitle.Font = Enum.Font.GothamBold
    perfTitle.TextSize = 12
    perfTitle.TextColor3 = PANEL_WHITE
    perfTitle.TextXAlignment = Enum.TextXAlignment.Left
    perfTitle.BackgroundTransparency = 1
    perfTitle.Position = UDim2.fromOffset(16, 10)
    perfTitle.Size = UDim2.new(1, -94, 0, 17)
    perfTitle.ZIndex = 151
    perfTitle.Parent = perfHeader
    local perfSub = Instance.new("TextLabel")
    perfSub.Text = "Real-time frame tracker"
    perfSub.Font = Enum.Font.Gotham
    perfSub.TextSize = 9
    perfSub.TextColor3 = PANEL_TEXT_DIM
    perfSub.TextXAlignment = Enum.TextXAlignment.Left
    perfSub.BackgroundTransparency = 1
    perfSub.Position = UDim2.fromOffset(16, 29)
    perfSub.Size = UDim2.new(1, -94, 0, 13)
    perfSub.ZIndex = 151
    perfSub.Parent = perfHeader
    local perfLiveBadge = Instance.new("Frame")
    perfLiveBadge.AnchorPoint = Vector2.new(1, 0)
    perfLiveBadge.Position = UDim2.new(1, -12, 0, 13)
    perfLiveBadge.Size = UDim2.fromOffset(56, 18)
    perfLiveBadge.BackgroundColor3 = PANEL_BADGE_IDLE
    perfLiveBadge.ZIndex = 151
    perfLiveBadge.Parent = perfHeader
    panelCorner(perfLiveBadge, 6)
    local perfLiveDot = Instance.new("Frame")
    perfLiveDot.AnchorPoint = Vector2.new(0, 0.5)
    perfLiveDot.Position = UDim2.new(0, 8, 0.5, 0)
    perfLiveDot.Size = UDim2.fromOffset(5, 5)
    perfLiveDot.BackgroundColor3 = PANEL_GREEN
    perfLiveDot.ZIndex = 152
    perfLiveDot.Parent = perfLiveBadge
    panelCorner(perfLiveDot, 99)
    local perfLiveText = Instance.new("TextLabel")
    perfLiveText.Text = "LIVE"
    perfLiveText.Font = Enum.Font.GothamBold
    perfLiveText.TextSize = 8
    perfLiveText.TextColor3 = PANEL_TEXT_GRAY
    perfLiveText.TextXAlignment = Enum.TextXAlignment.Left
    perfLiveText.BackgroundTransparency = 1
    perfLiveText.Position = UDim2.fromOffset(19, 0)
    perfLiveText.Size = UDim2.new(1, -23, 1, 0)
    perfLiveText.ZIndex = 152
    perfLiveText.Parent = perfLiveBadge

    -- FPS summary card
    local fpsSummary = Instance.new("Frame")
    fpsSummary.Position = UDim2.fromOffset(14, 56)
    fpsSummary.Size = UDim2.new(1, -28, 0, 52)
    fpsSummary.BackgroundColor3 = PANEL_ELEMENT
    fpsSummary.ZIndex = 150
    fpsSummary.Parent = PerfPanel
    panelCorner(fpsSummary, 10)
    panelStroke(fpsSummary, PANEL_BORDER)
    local fpsSummaryTitle = Instance.new("TextLabel")
    fpsSummaryTitle.Text = "FPS"
    fpsSummaryTitle.Font = Enum.Font.GothamBold
    fpsSummaryTitle.TextSize = 8
    fpsSummaryTitle.TextColor3 = PANEL_TEXT_DIM
    fpsSummaryTitle.TextXAlignment = Enum.TextXAlignment.Left
    fpsSummaryTitle.BackgroundTransparency = 1
    fpsSummaryTitle.Position = UDim2.fromOffset(12, 6)
    fpsSummaryTitle.Size = UDim2.new(0.5, -12, 0, 11)
    fpsSummaryTitle.ZIndex = 151
    fpsSummaryTitle.Parent = fpsSummary
    local currentFpsLabel = Instance.new("TextLabel")
    currentFpsLabel.Text = "--"
    currentFpsLabel.Font = Enum.Font.GothamBold
    currentFpsLabel.TextSize = 21
    currentFpsLabel.TextColor3 = PANEL_WHITE
    currentFpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    currentFpsLabel.BackgroundTransparency = 1
    currentFpsLabel.Position = UDim2.fromOffset(12, 18)
    currentFpsLabel.Size = UDim2.new(0.5, -12, 0, 26)
    currentFpsLabel.ZIndex = 151
    currentFpsLabel.Parent = fpsSummary
    local frameTimeTitle = Instance.new("TextLabel")
    frameTimeTitle.Text = "FRAME TIME"
    frameTimeTitle.Font = Enum.Font.GothamBold
    frameTimeTitle.TextSize = 8
    frameTimeTitle.TextColor3 = PANEL_TEXT_DIM
    frameTimeTitle.TextXAlignment = Enum.TextXAlignment.Right
    frameTimeTitle.BackgroundTransparency = 1
    frameTimeTitle.Position = UDim2.new(0.5, 0, 0, 7)
    frameTimeTitle.Size = UDim2.new(0.5, -12, 0, 11)
    frameTimeTitle.ZIndex = 151
    frameTimeTitle.Parent = fpsSummary
    local frameTimeLabel = Instance.new("TextLabel")
    frameTimeLabel.Text = "-- ms"
    frameTimeLabel.Font = Enum.Font.GothamMedium
    frameTimeLabel.TextSize = 11
    frameTimeLabel.TextColor3 = PANEL_WHITE
    frameTimeLabel.TextXAlignment = Enum.TextXAlignment.Right
    frameTimeLabel.BackgroundTransparency = 1
    frameTimeLabel.Position = UDim2.new(0.5, 0, 0, 22)
    frameTimeLabel.Size = UDim2.new(0.5, -12, 0, 16)
    frameTimeLabel.ZIndex = 151
    frameTimeLabel.Parent = fpsSummary

    -- Frame history graph
    local graphTitle = Instance.new("TextLabel")
    graphTitle.Text = "FRAME HISTORY"
    graphTitle.Font = Enum.Font.GothamBold
    graphTitle.TextSize = 9
    graphTitle.TextColor3 = PANEL_TEXT_DIM
    graphTitle.TextXAlignment = Enum.TextXAlignment.Left
    graphTitle.BackgroundTransparency = 1
    graphTitle.Position = UDim2.fromOffset(16, 118)
    graphTitle.Size = UDim2.new(1, -32, 0, 13)
    graphTitle.ZIndex = 150
    graphTitle.Parent = PerfPanel

    local graphCard = Instance.new("Frame")
    graphCard.Position = UDim2.fromOffset(14, 136)
    graphCard.Size = UDim2.new(1, -28, 0, 68)
    graphCard.BackgroundColor3 = PANEL_ELEMENT
    graphCard.ClipsDescendants = true
    graphCard.ZIndex = 150
    graphCard.Parent = PerfPanel
    panelCorner(graphCard, 10)
    panelStroke(graphCard, PANEL_BORDER)
    local graphPlot = Instance.new("Frame")
    graphPlot.Position = UDim2.fromOffset(10, 7)
    graphPlot.Size = UDim2.new(1, -20, 1, -14)
    graphPlot.BackgroundTransparency = 1
    graphPlot.ClipsDescendants = true
    graphPlot.ZIndex = 151
    graphPlot.Parent = graphCard

    local maxFpsSamples = 48
    local fpsSamples = {}
    local graphSegments = {}
    for i = 1, maxFpsSamples - 1 do
        local seg = Instance.new("Frame")
        seg.Name = "FL" .. i
        seg.AnchorPoint = Vector2.new(0, 0.5)
        seg.Size = UDim2.fromOffset(0, 1)
        seg.BackgroundColor3 = PANEL_ACC
        seg.BorderSizePixel = 0
        seg.Visible = false
        seg.ZIndex = 153
        seg.Parent = graphPlot
        graphSegments[i] = seg
    end

    -- AVG / LOW / HIGH strip
    local statsStrip = Instance.new("Frame")
    statsStrip.Position = UDim2.fromOffset(14, 214)
    statsStrip.Size = UDim2.new(1, -28, 0, 34)
    statsStrip.BackgroundColor3 = PANEL_ELEMENT
    statsStrip.ZIndex = 150
    statsStrip.Parent = PerfPanel
    panelCorner(statsStrip, 10)
    panelStroke(statsStrip, PANEL_BORDER)
    local statValueLabels = {}
    for i, sn in ipairs({ "AVG", "LOW", "HIGH" }) do
        local sc = Instance.new("Frame")
        sc.Position = UDim2.new((i - 1) / 3, 0, 0, 0)
        sc.Size = UDim2.new(1 / 3, 0, 1, 0)
        sc.BackgroundTransparency = 1
        sc.ZIndex = 151
        sc.Parent = statsStrip
        local snLabel = Instance.new("TextLabel")
        snLabel.Text = sn
        snLabel.Font = Enum.Font.GothamBold
        snLabel.TextSize = 8
        snLabel.TextColor3 = PANEL_TEXT_DIM
        snLabel.TextXAlignment = Enum.TextXAlignment.Center
        snLabel.BackgroundTransparency = 1
        snLabel.Position = UDim2.fromOffset(0, 4)
        snLabel.Size = UDim2.new(1, 0, 0, 10)
        snLabel.ZIndex = 152
        snLabel.Parent = sc
        statValueLabels[i] = Instance.new("TextLabel")
        statValueLabels[i].Text = "--"
        statValueLabels[i].Font = Enum.Font.GothamMedium
        statValueLabels[i].TextSize = 10
        statValueLabels[i].TextColor3 = PANEL_WHITE
        statValueLabels[i].TextXAlignment = Enum.TextXAlignment.Center
        statValueLabels[i].BackgroundTransparency = 1
        statValueLabels[i].Position = UDim2.fromOffset(0, 17)
        statValueLabels[i].Size = UDim2.new(1, 0, 0, 14)
        statValueLabels[i].ZIndex = 152
        statValueLabels[i].Parent = sc
    end

    local function redrawFpsGraph()
        local sc = #fpsSamples
        local ps = graphPlot.AbsoluteSize
        if sc < 2 or ps.X <= 1 or ps.Y <= 1 then
            for _, s in ipairs(graphSegments) do s.Visible = false end
            return
        end
        local gm = 60
        for _, v in ipairs(fpsSamples) do gm = math.max(gm, v) end
        gm = math.max(30, math.ceil(gm / 30) * 30)
        local den = math.max(sc - 1, 1)
        local uH = math.max(1, ps.Y - 6)
        for i, seg in ipairs(graphSegments) do
            if i < sc then
                local x1 = ((i - 1) / den) * ps.X
                local x2 = (i / den) * ps.X
                local y1 = 3 + (1 - math.clamp(fpsSamples[i] / gm, 0, 1)) * uH
                local y2 = 3 + (1 - math.clamp(fpsSamples[i + 1] / gm, 0, 1)) * uH
                local dx = x2 - x1
                local dy = y2 - y1
                local len = math.sqrt(dx * dx + dy * dy)
                seg.Position = UDim2.fromOffset(x1, y1)
                seg.Size = UDim2.fromOffset(len + 2, 1)
                seg.Rotation = math.deg(math.atan2(dy, dx))
                seg.Visible = true
            else
                seg.Visible = false
            end
        end
    end

    local function pushFpsSample(fps)
        fps = math.max(0, fps)
        table.insert(fpsSamples, fps)
        if #fpsSamples > maxFpsSamples then table.remove(fpsSamples, 1) end
        local tot, lo, hi = 0, math.huge, 0
        for _, v in ipairs(fpsSamples) do
            tot = tot + v
            lo = math.min(lo, v)
            hi = math.max(hi, v)
        end
        local avg = #fpsSamples > 0 and tot / #fpsSamples or 0
        local ft = fps > 0 and (1000 / fps) or 0
        currentFpsLabel.Text = tostring(math.floor(fps + 0.5))
        frameTimeLabel.Text = string.format("%.1f ms", ft)
        statValueLabels[1].Text = tostring(math.floor(avg + 0.5))
        statValueLabels[2].Text = tostring(math.floor(lo + 0.5))
        statValueLabels[3].Text = tostring(math.floor(hi + 0.5))
        redrawFpsGraph()
    end

    -- Live metrics loops (only tick while a panel is open, like the old UI)
    local profilePingThread = task.spawn(function()
        while not isDestroyed do
            task.wait(1)
            if profileOpen and profilePingLabel and profilePingLabel.Parent then
                local txt = "N/A"
                local ok, val = pcall(function()
                    return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
                end)
                if ok and type(val) == "number" then txt = tostring(math.floor(val + 0.5)) .. " ms" end
                profilePingLabel.Text = txt
            end
        end
    end)
    trackCleanup(profilePingThread)

    local perfFrames, perfElapsed = 0, 0
    local perfConn = RunService.RenderStepped:Connect(function(dt)
        perfFrames = perfFrames + 1
        perfElapsed = perfElapsed + dt
        if perfElapsed >= 0.25 then
            pushFpsSample(perfFrames / perfElapsed)
            perfFrames, perfElapsed = 0, 0
        end
    end)
    trackCleanup(perfConn)

    -- Avatar thumbnail
    if LocalPlayer then
        task.spawn(function()
            local ok, img = pcall(function()
                return game:GetService("Players"):GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
            end)
            if ok and profileAvatar and profileAvatar.Parent then
                profileAvatar.Image = img
            end
        end)
    end

    -- Panel visibility (slides both panels together)
    local function SetProfileVisible(visible, instant)
        profileOpen = visible == true
        local tp = profileOpen and profileOpenPos or profileClosedPos
        local ep = profileOpen and perfOpenPos or perfClosedPos
        local tr = profileOpen and 0 or 1
        if instant then
            ProfilePanel.Position = tp
            ProfilePanel.GroupTransparency = tr
            PerfPanel.Position = ep
            PerfPanel.GroupTransparency = tr
        else
            TweenService:Create(ProfilePanel, PROFILE_TWEEN, { Position = tp, GroupTransparency = tr }):Play()
            TweenService:Create(PerfPanel, PROFILE_TWEEN, { Position = ep, GroupTransparency = tr }):Play()
        end
        return profileOpen
    end

    ToggleProfilePanels = function()
        SetProfileVisible(not profileOpen)
    end

    function GuiFunc:ToggleProfile() return ToggleProfilePanels() end
    function GuiFunc:SetProfileVisible(visible, instant) return SetProfileVisible(visible, instant) end
    function GuiFunc:IsProfileOpen() return profileOpen end

    -- Start the Koyeb tag system + live tracking for this window.
    startTagSystem()

    return Tabs
end

-- -- ============================================================
-- -- UI TESTING / EXECUTION
-- -- ============================================================
-- local ICON_ID = "108203634075572"
-- local function notif(content, duration, title)
--     if Oxide and Oxide.MakeNotify then
--         Oxide:MakeNotify({
--             Title   = title or "Oxide",
--             Content = content,
--             Delay   = duration or 4,
--             Icon    = ICON_ID
--         })
--     end
-- end

-- local MarketplaceService = game:GetService("MarketplaceService")

-- local GameName = "Unknown"

-- pcall(function()
--     GameName = MarketplaceService:GetProductInfo(game.PlaceId).Name
-- end)

-- local Window = Oxide:Window({
--     Title    = "Oxide",
--     Footer   = GameName,
--     Color    = Color3.fromRGB(150, 150, 150),
--     Color2   = Color3.fromRGB(0, 0, 14),
--     ["Tab Width"] = 130,
--     Image      = "76157300179532",
--     WindowIMG  = "91334002283698",
--     LogoHUB    = "122210019620425"
-- })
-- local Tabs = Window

-- local function LoadInfoTab()
--     local InfoTab = Tabs:AddTab({ Name = "About", Icon = "info" })
--     local InfoSection = InfoTab:AddSection("About Oxide", true)

--     local inviteCode = "OxideHub"
--     local discordLink = "https://discord.gg/" .. inviteCode

--     local DiscordParagraph = InfoSection:AddParagraph({
--         Title          = "Loading...",
--         Icon           = "nplnv4",
--         Content        = "Members: Loading... | Online: Loading...",
--         ButtonText     = "Copy Link",
--         ButtonCallback = function()
--             if setclipboard then
--                 setclipboard(discordLink)
--                 notif("Successfully copied the link!", 3, "Oxide")
--             end
--         end
--     })

--     task.spawn(function()
--         pcall(function()
--             local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
--             local res
--             if req then
--                 res = req({
--                     Url = "https://discord.com/api/v9/invites/" .. inviteCode .. "?with_counts=true",
--                     Method = "GET"
--                 })
--                 res = res.Body
--             else
--                 res = game:HttpGet("https://discord.com/api/v9/invites/" .. inviteCode .. "?with_counts=true")
--             end
            
--             local decoded = game:GetService("HttpService"):JSONDecode(res)
--             if decoded and decoded.guild then
--                 DiscordParagraph:SetTitle(decoded.guild.name)
--                 DiscordParagraph:SetContent("Members: " .. tostring(decoded.approximate_member_count) .. " | Online: " .. tostring(decoded.approximate_presence_count))
--             end
--         end)
--     end)

-- 	InfoSection:AddButton({ Title = "Tes", Callback = function(value) end })
-- end

-- local function LoadMainTab()
--     local MainTab = Tabs:AddTab({ Name = "Main", Icon = "home" })
    
--     local DemoSection = MainTab:AddSection("Elements Showcase")

--     -- DemoSection:AddParagraph({
--     --     Title          = "Paragraph Demo",
--     --     Content        = "This is a paragraph example.\nYou can write multiline descriptions here.",
--     --     ButtonText     = "Click Me",
--     --     ButtonCallback = function()
--     --         notif("Paragraph button clicked!", 2)
--     --     end
--     -- })

--     -- DemoSection:AddButton({
--     --     Title = "Normal Button",
--     --     Callback = function()
--     --         notif("Normal button clicked!", 2)
--     --     end
--     -- })

--     -- DemoSection:AddButton({
--     --     Title       = "Dual Button",
--     --     SubTitle    = "Second Button",
--     --     Callback    = function()
--     --         notif("Main button clicked!", 2)
--     --     end,
--     --     SubCallback = function()
--     --         notif("Sub button clicked!", 2)
--     --     end
--     -- })

--     -- DemoSection:AddDivider()

--     -- DemoSection:AddSubSection("Toggles & Sliders")

--     DemoSection:AddToggle({
--         Title    = "Example Toggle",
--         Default  = false,
--         Keybind  = true,
--         Callback = function(value)
--             notif("Toggle is now: " .. tostring(value), 2)
--         end
--     })

--     -- DemoSection:AddSlider({
--     --     Title     = "Example Slider",
--     --     Increment = 1,
--     --     Min       = 1,
--     --     Max       = 100,
--     --     Default   = 50,
--     --     Callback  = function(value)
--     --         -- notif("Slider value: " .. tostring(value), 2)
--     --     end
--     -- })

--     -- DemoSection:AddDivider()

--     -- DemoSection:AddSubSection("Inputs & Dropdowns")

--     -- DemoSection:AddInput({
--     --     Title    = "Example Input",
--     --     Content  = "Type something and press enter",
--     --     Default  = "",
--     --     Callback = function(val)
--     --         notif("Input submitted: " .. tostring(val), 2)
--     --     end
--     -- })

--     -- DemoSection:AddInput({
--     --     Title    = "Example Input 2",
--     --     Callback = function(val)
--     --         notif("Input submitted: " .. tostring(val), 2)
--     --     end
--     -- })

--     -- DemoSection:AddPanel({
--     --     Title       = "Example Panel",
--     --     Placeholder = "Enter text here...",
--     --     ButtonText  = "Submit Panel",
--     --     Callback    = function(val)
--     --         notif("Panel submitted: " .. tostring(val), 2)
--     --     end
--     -- })

--     -- DemoSection:AddDropdown({
--     --     Title    = "Single Dropdown",
--     --     Content  = "Select one option",
--     --     Options  = { "Option 1", "Option 2", "Option 3" },
--     --     Default  = "Option 1",
--     --     Multi    = false,
--     --     Callback = function(val)
--     --         notif("Selected: " .. tostring(val), 2)
--     --     end
--     -- })

--     -- DemoSection:AddDropdown({
--     --     Title    = "Multi Dropdown",
--     --     Content  = "Select multiple options",
--     --     Options  = { "Apple", "Banana", "Orange" },
--     --     Default  = {"Apple"},
--     --     Multi    = true,
--     --     Callback = function(val)
--     --         -- val is a table of selected items
--     --     end
--     -- })
-- end

-- LoadInfoTab()
-- LoadMainTab()

-- -- Panggil fungsi untuk menambahkan tab config di urutan paling akhir
-- Tabs:AddConfigTab()

return Oxide
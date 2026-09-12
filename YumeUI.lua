--[[
    YumeUI 1.1.0
    A standalone anime-inspired Roblox interface library.

    This file only defines and returns the library. It never creates a window
    by itself; use YumeUI_Example.lua (or your own loader) to mount an app.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local YumeUI = {
    Name = "YumeUI",
    Version = "1.1.0",
    Build = "YUME-ORIGINAL-2-MINIDOCK",
}

local App = {}
local Page = {}
local Section = {}
App.__index = App
Page.__index = Page
Section.__index = Section

local DEFAULT_THEME = {
    Background = Color3.fromRGB(13, 12, 24),
    Surface = Color3.fromRGB(24, 22, 39),
    SurfaceSoft = Color3.fromRGB(31, 28, 49),
    SurfaceHover = Color3.fromRGB(42, 37, 63),
    Text = Color3.fromRGB(247, 244, 255),
    Muted = Color3.fromRGB(166, 159, 188),
    Stroke = Color3.fromRGB(88, 78, 120),
    Accent = Color3.fromRGB(255, 112, 181),
    Accent2 = Color3.fromRGB(110, 216, 255),
    Success = Color3.fromRGB(103, 230, 178),
    Warning = Color3.fromRGB(255, 196, 103),
    Danger = Color3.fromRGB(255, 103, 137),
}

local function merge(base, extra)
    local result = {}
    for key, value in pairs(base) do
        result[key] = value
    end
    if type(extra) == "table" then
        for key, value in pairs(extra) do
            result[key] = value
        end
    end
    return result
end

local function create(className, properties, children)
    local object = Instance.new(className)
    local parent = properties and properties.Parent
    if properties then
        for property, value in pairs(properties) do
            if property ~= "Parent" then
                local ok, message = pcall(function()
                    object[property] = value
                end)
                if not ok then
                    warn(string.format("[YumeUI] %s.%s: %s", className, property, tostring(message)))
                end
            end
        end
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = object
        end
    end
    object.Parent = parent
    return object
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius),
        Parent = parent,
    })
end

local function addStroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function addPadding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or left or 0),
        PaddingTop = UDim.new(0, top or left or 0),
        PaddingBottom = UDim.new(0, bottom or top or left or 0),
        Parent = parent,
    })
end

local function makeGradient(parent, first, second, rotation, transparency)
    return create("UIGradient", {
        Color = ColorSequence.new(first, second),
        Rotation = rotation or 0,
        Transparency = transparency or NumberSequence.new(0),
        Parent = parent,
    })
end

local function tween(object, duration, properties, style, direction)
    if not object or not object.Parent then
        return nil
    end
    local animation = TweenService:Create(
        object,
        TweenInfo.new(
            duration or 0.2,
            style or Enum.EasingStyle.Quint,
            direction or Enum.EasingDirection.Out
        ),
        properties
    )
    animation:Play()
    return animation
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return true
    end
    local ok, message = pcall(callback, ...)
    if not ok then
        warn("[YumeUI Callback] " .. tostring(message))
    end
    return ok, message
end

local function sanitize(value)
    return tostring(value or "Yume"):gsub("[^%w_]", "_"):sub(1, 42)
end

local function resolveKeyCode(value)
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        return value
    end
    if type(value) == "string" then
        return Enum.KeyCode[value]
    end
    return nil
end

local function normalizeControlOptions(value, callback)
    if type(value) == "table" then
        return value
    end
    return {
        Title = tostring(value or "Control"),
        Callback = callback,
    }
end

local function getGuiParent()
    local parent
    if type(gethui) == "function" then
        pcall(function()
            parent = gethui()
        end)
    end
    if not parent and LocalPlayer then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    return parent
end

local function setCanvasFromLayout(scroller, layout, extra)
    local function update()
        scroller.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + (extra or 0))
    end
    update()
    return layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
end

local function textWidth(text, size, font)
    local bounds = TextService:GetTextSize(
        tostring(text or ""),
        size,
        font or Enum.Font.GothamMedium,
        Vector2.new(1000, 40)
    )
    return bounds.X
end

local function copyThemeColor(value, fallback)
    if typeof(value) == "Color3" then
        return value
    end
    return fallback
end

function YumeUI.mount(config)
    assert(type(config) == "table", "YumeUI.mount(config) requires a config table")
    local self = setmetatable({}, App)
    self:_initialize(config)
    return self
end

YumeUI.create = YumeUI.mount

function App:_track(item)
    table.insert(self._cleanup, item)
    return item
end

function App:_connect(signal, callback)
    return self:_track(signal:Connect(callback))
end

function App:_initialize(config)
    self._destroyed = false
    self._cleanup = {}
    self._pages = {}
    self._pageOrder = {}
    self._searchItems = {}
    self._accentObjects = {}
    self._accentGradients = {}
    self._modelAngle = 0
    self._modelDragging = false
    self._modelAutoRotate = true
    self._modelRotationSpeed = 18
    self._visible = true
    self._config = config
    self._theme = merge(DEFAULT_THEME, config.Theme)
    self._theme.Accent = copyThemeColor(config.Accent, self._theme.Accent)
    self._theme.Accent2 = copyThemeColor(config.Accent2, self._theme.Accent2)
    self._baseSize = config.Size or Vector2.new(920, 570)
    self._baseSize = Vector2.new(
        math.clamp(self._baseSize.X, 760, 1120),
        math.clamp(self._baseSize.Y, 500, 720)
    )
    self._toggleKey = resolveKeyCode(config.ToggleKey) or Enum.KeyCode.RightControl

    self:_buildScreen()
    self:_buildWindow()
    self:_buildModelStage()
    self:_buildPageHost()
    self:_buildSearch()
    self:_buildNotifications()
    self:_installWindowInput()
    self:_installResponsiveScale()
    self:_installModelInput()
    self:_applyInitialModel(config.Model)

    if config.Blur ~= false then
        self:_enableBlur(tonumber(config.BlurStrength) or 10)
    end
end

function App:_buildScreen()
    local parent = getGuiParent()
    assert(parent, "YumeUI could not find a GUI parent")

    self._screenName = "YumeUI_" .. sanitize(self._config.Id or self._config.Title)
    local previous = parent:FindFirstChild(self._screenName)
    if previous then
        previous:Destroy()
    end

    self._screen = create("ScreenGui", {
        Name = self._screenName,
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = tonumber(self._config.DisplayOrder) or 80,
        Parent = parent,
    })

    pcall(function()
        self._screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    end)

    if type(protectgui) == "function" then
        pcall(protectgui, self._screen)
    elseif syn and type(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, self._screen)
    end
end

function App:_buildWindow()
    local theme = self._theme

    self._shadow = create("Frame", {
        Name = "SoftShadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 10),
        Size = UDim2.fromOffset(self._baseSize.X + 18, self._baseSize.Y + 18),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.42,
        BorderSizePixel = 0,
        Parent = self._screen,
    })
    addCorner(self._shadow, 30)

    self._root = create("Frame", {
        Name = "YumeWindow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(self._baseSize.X, self._baseSize.Y),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.035,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = self._screen,
    })
    addCorner(self._root, 26)
    self._rootStroke = addStroke(self._root, theme.Stroke, 0.34, 1)

    self._scale = create("UIScale", {
        Scale = 1,
        Parent = self._root,
    })
    self._shadowScale = create("UIScale", {
        Scale = 1,
        Parent = self._shadow,
    })

    local wash = create("Frame", {
        Name = "ColorWash",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        Parent = self._root,
    })
    addCorner(wash, 26)
    local washGradient = makeGradient(
        wash,
        theme.Accent,
        theme.Accent2,
        28,
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.82),
            NumberSequenceKeypoint.new(0.48, 0.97),
            NumberSequenceKeypoint.new(1, 0.88),
        })
    )
    table.insert(self._accentGradients, washGradient)

    local accentLine = create("Frame", {
        Name = "AccentLine",
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -48, 0, 3),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Parent = self._root,
    })
    addCorner(accentLine, 8)
    local lineGradient = makeGradient(accentLine, theme.Accent, theme.Accent2, 0)
    table.insert(self._accentGradients, lineGradient)

    self._header = create("Frame", {
        Name = "Header",
        Position = UDim2.fromOffset(16, 12),
        Size = UDim2.new(1, -32, 0, 58),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.14,
        BorderSizePixel = 0,
        Active = true,
        Parent = self._root,
    })
    addCorner(self._header, 18)
    addStroke(self._header, theme.Stroke, 0.62, 1)

    local logo = create("Frame", {
        Name = "Logo",
        Position = UDim2.fromOffset(10, 9),
        Size = UDim2.fromOffset(40, 40),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Parent = self._header,
    })
    addCorner(logo, 14)
    table.insert(self._accentObjects, {Object = logo, Property = "BackgroundColor3", Slot = 1})
    local logoGradient = makeGradient(logo, theme.Accent, theme.Accent2, 45)
    table.insert(self._accentGradients, logoGradient)
    create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = self._config.LogoText or "✦",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 22,
        Font = Enum.Font.GothamBold,
        Parent = logo,
    })

    create("TextLabel", {
        Name = "Title",
        Position = UDim2.fromOffset(62, 8),
        Size = UDim2.fromOffset(245, 22),
        BackgroundTransparency = 1,
        Text = self._config.Title or "Yume Interface",
        TextColor3 = theme.Text,
        TextSize = 17,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = self._header,
    })
    create("TextLabel", {
        Name = "Subtitle",
        Position = UDim2.fromOffset(62, 30),
        Size = UDim2.fromOffset(245, 17),
        BackgroundTransparency = 1,
        Text = self._config.Subtitle or "ANIME CONTROL SPACE",
        TextColor3 = theme.Muted,
        TextSize = 10,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = self._header,
    })

    self._searchBox = create("TextBox", {
        Name = "Search",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -92, 0.5, 0),
        Size = UDim2.fromOffset(220, 36),
        BackgroundColor3 = theme.SurfaceSoft,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = "搜索页面和功能…",
        PlaceholderColor3 = theme.Muted,
        Text = "",
        TextColor3 = theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self._header,
    })
    addCorner(self._searchBox, 12)
    addStroke(self._searchBox, theme.Stroke, 0.65, 1)
    addPadding(self._searchBox, 14, 36, 0, 0)

    create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -103, 0.5, 0),
        Size = UDim2.fromOffset(22, 22),
        BackgroundTransparency = 1,
        Text = "⌕",
        TextColor3 = theme.Muted,
        TextSize = 19,
        Font = Enum.Font.GothamBold,
        Parent = self._header,
    })

    self:_createHeaderButton("−", 48, function()
        self:hide()
    end)
    self:_createHeaderButton("×", 8, function()
        if self._config.CloseDestroys == true then
            self:destroy()
        else
            self:hide()
        end
    end)

    self._pageBar = create("ScrollingFrame", {
        Name = "PageBar",
        Position = UDim2.fromOffset(16, 78),
        Size = UDim2.new(1, -32, 0, 40),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 0,
        Parent = self._root,
    })
    self._pageBarLayout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8),
        Parent = self._pageBar,
    })
    addPadding(self._pageBar, 2, 2, 0, 0)

    self._workspace = create("Frame", {
        Name = "Workspace",
        Position = UDim2.fromOffset(16, 126),
        Size = UDim2.new(1, -32, 1, -142),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self._root,
    })

    self:_buildMinimizeDock()

    self:_createAmbientStars()
end

function App:_buildMinimizeDock()
    local rawOptions = self._config.Minimize
    local options = type(rawOptions) == "table" and rawOptions or {}
    local showTitle = options.ShowTitle ~= false
    local title = tostring(options.Title or self._config.Title or "YumeUI")
    local dockWidth = showTitle
        and math.clamp(textWidth(title, 12, Enum.Font.GothamBold) + 116, 176, 248)
        or 122

    self._miniEnabled = rawOptions ~= false and options.Enabled ~= false
    self._miniDraggable = options.Draggable ~= false
    self._miniBaseTransparency = 0.055

    self._miniDock = create("Frame", {
        Name = "YumeMinimizeDock",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = typeof(options.Position) == "UDim2"
            and options.Position
            or UDim2.new(0.5, 0, 0, 30),
        Size = UDim2.fromOffset(dockWidth, 48),
        BackgroundColor3 = self._theme.Background,
        BackgroundTransparency = self._miniBaseTransparency,
        BorderSizePixel = 0,
        Active = true,
        Visible = false,
        ZIndex = 90,
        Parent = self._screen,
    })
    addCorner(self._miniDock, 16)
    local dockStroke = addStroke(self._miniDock, self._theme.Accent, 0.08, 1.5)
    local dockStrokeGradient = makeGradient(dockStroke, self._theme.Accent, self._theme.Accent2, 0)
    table.insert(self._accentGradients, dockStrokeGradient)

    local shadow = create("Frame", {
        Position = UDim2.fromOffset(0, 6),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.52,
        BorderSizePixel = 0,
        ZIndex = 89,
        Parent = self._miniDock,
    })
    addCorner(shadow, 16)

    local tint = create("Frame", {
        Name = "Tint",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.9,
        BorderSizePixel = 0,
        ZIndex = 91,
        Parent = self._miniDock,
    })
    addCorner(tint, 16)
    local tintGradient = makeGradient(
        tint,
        self._theme.Accent,
        self._theme.Accent2,
        10,
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.72),
            NumberSequenceKeypoint.new(0.55, 0.94),
            NumberSequenceKeypoint.new(1, 0.8),
        })
    )
    table.insert(self._accentGradients, tintGradient)

    self._miniScale = create("UIScale", {
        Scale = 1,
        Parent = self._miniDock,
    })

    local grip = create("TextButton", {
        Name = "DragGrip",
        Position = UDim2.fromOffset(5, 5),
        Size = UDim2.fromOffset(32, 38),
        BackgroundColor3 = self._theme.SurfaceSoft,
        BackgroundTransparency = self._miniDraggable and 0.36 or 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Active = self._miniDraggable,
        ZIndex = 94,
        Parent = self._miniDock,
    })
    addCorner(grip, 11)

    if self._miniDraggable then
        for row = 0, 2 do
            for column = 0, 1 do
                local dot = create("Frame", {
                    Position = UDim2.fromOffset(11 + column * 7, 11 + row * 7),
                    Size = UDim2.fromOffset(3, 3),
                    BackgroundColor3 = self._theme.Muted,
                    BackgroundTransparency = 0.22,
                    BorderSizePixel = 0,
                    ZIndex = 95,
                    Parent = grip,
                })
                addCorner(dot, 9)
            end
        end
    end

    local divider = create("Frame", {
        Position = UDim2.fromOffset(42, 10),
        Size = UDim2.fromOffset(1, 28),
        BackgroundColor3 = self._theme.Stroke,
        BackgroundTransparency = 0.52,
        BorderSizePixel = 0,
        ZIndex = 93,
        Parent = self._miniDock,
    })
    divider.Visible = self._miniDraggable

    local restore = create("TextButton", {
        Name = "Restore",
        Position = UDim2.fromOffset(self._miniDraggable and 44 or 4, 4),
        Size = UDim2.new(1, self._miniDraggable and -48 or -8, 1, -8),
        BackgroundColor3 = self._theme.SurfaceSoft,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 94,
        Parent = self._miniDock,
    })
    addCorner(restore, 12)

    local logo = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 5, 0.5, 0),
        Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = self._theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 95,
        Parent = restore,
    })
    addCorner(logo, 10)
    local logoGradient = makeGradient(logo, self._theme.Accent, self._theme.Accent2, 45)
    table.insert(self._accentObjects, {Object = logo, Property = "BackgroundColor3", Slot = 1})
    table.insert(self._accentGradients, logoGradient)
    create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = self._config.LogoText or "夢",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        ZIndex = 96,
        Parent = logo,
    })

    if showTitle then
        self._miniTitle = create("TextLabel", {
            Position = UDim2.fromOffset(43, 5),
            Size = UDim2.new(1, -68, 0, 17),
            BackgroundTransparency = 1,
            Text = title,
            TextColor3 = self._theme.Text,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 95,
            Parent = restore,
        })
        create("TextLabel", {
            Position = UDim2.fromOffset(43, 22),
            Size = UDim2.new(1, -68, 0, 13),
            BackgroundTransparency = 1,
            Text = "点击恢复界面",
            TextColor3 = self._theme.Muted,
            TextSize = 8,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 95,
            Parent = restore,
        })
    end

    create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -5, 0.5, 0),
        Size = UDim2.fromOffset(18, 24),
        BackgroundTransparency = 1,
        Text = "›",
        TextColor3 = self._theme.Accent2,
        TextSize = 20,
        Font = Enum.Font.GothamBold,
        ZIndex = 95,
        Parent = restore,
    })

    self:_connect(restore.Activated, function()
        self:show()
    end)
    self:_connect(restore.MouseEnter, function()
        tween(restore, 0.14, {BackgroundTransparency = 0.72})
        tween(self._miniScale, 0.16, {Scale = 1.035}, Enum.EasingStyle.Back)
    end)
    self:_connect(restore.MouseLeave, function()
        tween(restore, 0.14, {BackgroundTransparency = 1})
        tween(self._miniScale, 0.16, {Scale = 1})
    end)

    if self._miniDraggable then
        self:_installMinimizeDockDrag(grip)
    end
end

function App:_installMinimizeDockDrag(grip)
    local dragging = false
    local moved = false
    local dragStart
    local startPosition

    self:_connect(grip.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPosition = self._miniDock.Position
            tween(grip, 0.12, {BackgroundTransparency = 0.12})
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude >= 4 then
                moved = true
            end
            self._miniDock.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        dragging = false
        tween(grip, 0.12, {BackgroundTransparency = 0.36})
        if not moved then
            return
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end
        local viewport = camera.ViewportSize
        local size = self._miniDock.AbsoluteSize
        local center = self._miniDock.AbsolutePosition + size / 2
        local halfWidth = size.X / 2
        local halfHeight = size.Y / 2
        local targetX = center.X < viewport.X / 2
            and halfWidth + 12
            or viewport.X - halfWidth - 12
        local targetY = math.clamp(center.Y, halfHeight + 12, viewport.Y - halfHeight - 12)
        tween(
            self._miniDock,
            0.28,
            {Position = UDim2.fromOffset(targetX, targetY)},
            Enum.EasingStyle.Back
        )
    end)
end

function App:_setMinimizeDockVisible(visible, instant)
    if not self._miniDock or not self._miniEnabled then
        return
    end
    if visible then
        self._miniDock.Visible = true
        self._miniDock.BackgroundTransparency = 0.5
        self._miniScale.Scale = 0.82
        if instant then
            self._miniDock.BackgroundTransparency = self._miniBaseTransparency
            self._miniScale.Scale = 1
        else
            tween(self._miniDock, 0.2, {BackgroundTransparency = self._miniBaseTransparency})
            tween(self._miniScale, 0.28, {Scale = 1}, Enum.EasingStyle.Back)
        end
        return
    end

    if instant then
        self._miniDock.Visible = false
        self._miniScale.Scale = 1
        return
    end
    local animation = tween(self._miniScale, 0.16, {Scale = 0.82})
    tween(self._miniDock, 0.16, {BackgroundTransparency = 0.5})
    if animation then
        animation.Completed:Connect(function()
            if self._visible and self._miniDock then
                self._miniDock.Visible = false
                self._miniScale.Scale = 1
            end
        end)
    end
end

function App:_createHeaderButton(symbol, rightOffset, callback)
    local button = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -rightOffset, 0.5, 0),
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = self._theme.SurfaceSoft,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = symbol,
        TextColor3 = self._theme.Muted,
        TextSize = 20,
        Font = Enum.Font.GothamMedium,
        Parent = self._header,
    })
    addCorner(button, 11)
    self:_connect(button.MouseEnter, function()
        tween(button, 0.16, {
            BackgroundTransparency = 0.05,
            TextColor3 = self._theme.Text,
        })
    end)
    self:_connect(button.MouseLeave, function()
        tween(button, 0.16, {
            BackgroundTransparency = 0.28,
            TextColor3 = self._theme.Muted,
        })
    end)
    self:_connect(button.Activated, callback)
    return button
end

function App:_createAmbientStars()
    local positions = {
        {0.03, 0.18, 7},
        {0.95, 0.22, 10},
        {0.88, 0.92, 7},
        {0.06, 0.86, 9},
        {0.74, 0.05, 6},
        {0.42, 0.96, 6},
    }
    for index, data in ipairs(positions) do
        local star = create("TextLabel", {
            Position = UDim2.fromScale(data[1], data[2]),
            Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1,
            Text = index % 2 == 0 and "✦" or "·",
            TextColor3 = index % 2 == 0 and self._theme.Accent2 or self._theme.Accent,
            TextTransparency = 0.58,
            TextSize = data[3] + 5,
            Font = Enum.Font.GothamBold,
            ZIndex = 0,
            Parent = self._root,
        })
        table.insert(self._accentObjects, {
            Object = star,
            Property = "TextColor3",
            Slot = index % 2 == 0 and 2 or 1,
        })
        local animation = TweenService:Create(
            star,
            TweenInfo.new(1.5 + index * 0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {
                TextTransparency = 0.18,
                Rotation = index % 2 == 0 and 18 or -18,
            }
        )
        animation:Play()
        self:_track(animation)
    end
end

function App:_buildModelStage()
    local theme = self._theme
    self._modelCard = create("Frame", {
        Name = "ModelStage",
        Size = UDim2.new(0, 278, 1, 0),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = self._workspace,
    })
    addCorner(self._modelCard, 22)
    addStroke(self._modelCard, theme.Stroke, 0.48, 1)

    local backdrop = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        Parent = self._modelCard,
    })
    makeGradient(
        backdrop,
        theme.Accent,
        theme.Accent2,
        132,
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.78),
            NumberSequenceKeypoint.new(0.52, 0.97),
            NumberSequenceKeypoint.new(1, 0.82),
        })
    )

    local haloOuter = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.49),
        Size = UDim2.fromOffset(230, 230),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self._modelCard,
    })
    addCorner(haloOuter, 999)
    local haloStroke = addStroke(haloOuter, theme.Accent2, 0.76, 2)
    table.insert(self._accentObjects, {Object = haloStroke, Property = "Color", Slot = 2})

    local haloInner = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.49),
        Size = UDim2.fromOffset(174, 174),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Rotation = 14,
        Parent = self._modelCard,
    })
    addCorner(haloInner, 999)
    local innerStroke = addStroke(haloInner, theme.Accent, 0.82, 1)
    table.insert(self._accentObjects, {Object = innerStroke, Property = "Color", Slot = 1})

    self._modelViewport = create("ViewportFrame", {
        Name = "CharacterViewport",
        Position = UDim2.fromOffset(12, 50),
        Size = UDim2.new(1, -24, 1, -112),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Ambient = Color3.fromRGB(175, 165, 210),
        LightColor = Color3.fromRGB(255, 238, 250),
        LightDirection = Vector3.new(-1, -0.7, -1),
        Active = true,
        Parent = self._modelCard,
    })
    self._modelWorld = create("WorldModel", {
        Name = "YumeWorld",
        Parent = self._modelViewport,
    })
    self._modelCamera = create("Camera", {
        Name = "YumeCamera",
        FieldOfView = 34,
        Parent = self._modelViewport,
    })
    self._modelViewport.CurrentCamera = self._modelCamera

    create("TextLabel", {
        Position = UDim2.fromOffset(16, 14),
        Size = UDim2.new(1, -32, 0, 16),
        BackgroundTransparency = 1,
        Text = "CHARACTER STAGE  /  3D",
        TextColor3 = theme.Muted,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self._modelCard,
    })

    self._modelPlaceholder = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.48),
        Size = UDim2.fromOffset(210, 58),
        BackgroundTransparency = 1,
        Text = "✦\n等待添加模型",
        TextColor3 = theme.Muted,
        TextTransparency = 0.12,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        Parent = self._modelCard,
    })

    local info = create("Frame", {
        Position = UDim2.new(0, 12, 1, -56),
        Size = UDim2.new(1, -24, 0, 44),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = 0.24,
        BorderSizePixel = 0,
        Parent = self._modelCard,
    })
    addCorner(info, 13)
    addStroke(info, theme.Stroke, 0.68, 1)
    self._modelName = create("TextLabel", {
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -58, 0, 17),
        BackgroundTransparency = 1,
        Text = "NO MODEL",
        TextColor3 = theme.Text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = info,
    })
    self._modelHint = create("TextLabel", {
        Position = UDim2.fromOffset(12, 23),
        Size = UDim2.new(1, -58, 0, 14),
        BackgroundTransparency = 1,
        Text = "拖动旋转 · 滚轮缩放",
        TextColor3 = theme.Muted,
        TextSize = 9,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = info,
    })
    local liveDot = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -20, 0.5, 0),
        Size = UDim2.fromOffset(9, 9),
        BackgroundColor3 = theme.Success,
        BorderSizePixel = 0,
        Parent = info,
    })
    addCorner(liveDot, 99)
    addStroke(liveDot, Color3.new(1, 1, 1), 0.5, 1)

    self._modelVisible = false
    self._modelCard.Visible = false
end

function App:_buildPageHost()
    self._pageHost = create("Frame", {
        Name = "PageHost",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = self._theme.Surface,
        BackgroundTransparency = 0.13,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = self._workspace,
    })
    addCorner(self._pageHost, 22)
    addStroke(self._pageHost, self._theme.Stroke, 0.54, 1)

    self._emptyState = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(260, 120),
        BackgroundTransparency = 1,
        Parent = self._pageHost,
    })
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
        Text = "✦",
        TextColor3 = self._theme.Accent,
        TextSize = 36,
        Font = Enum.Font.GothamBold,
        Parent = self._emptyState,
    })
    create("TextLabel", {
        Position = UDim2.fromOffset(0, 58),
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "还没有页面",
        TextColor3 = self._theme.Text,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        Parent = self._emptyState,
    })
    create("TextLabel", {
        Position = UDim2.fromOffset(0, 84),
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "请通过配套示例创建 page",
        TextColor3 = self._theme.Muted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        Parent = self._emptyState,
    })
    self:_updateModelLayout(true)
end

function App:_buildSearch()
    self._searchPanel = create("Frame", {
        Name = "SearchResults",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -92, 0, 72),
        Size = UDim2.fromOffset(430, 340),
        BackgroundColor3 = self._theme.Background,
        BackgroundTransparency = 0.025,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 30,
        Parent = self._root,
    })
    addCorner(self._searchPanel, 18)
    addStroke(self._searchPanel, self._theme.Stroke, 0.28, 1)

    create("TextLabel", {
        Position = UDim2.fromOffset(16, 12),
        Size = UDim2.new(1, -32, 0, 24),
        BackgroundTransparency = 1,
        Text = "快速搜索",
        TextColor3 = self._theme.Text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 31,
        Parent = self._searchPanel,
    })
    self._searchList = create("ScrollingFrame", {
        Position = UDim2.fromOffset(10, 44),
        Size = UDim2.new(1, -20, 1, -54),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = self._theme.Accent,
        ZIndex = 31,
        Parent = self._searchPanel,
    })
    self._searchLayout = create("UIListLayout", {
        Padding = UDim.new(0, 6),
        Parent = self._searchList,
    })
    addPadding(self._searchList, 2, 4, 2, 4)
    self:_track(setCanvasFromLayout(self._searchList, self._searchLayout, 8))

    self:_connect(self._searchBox:GetPropertyChangedSignal("Text"), function()
        self:_renderSearch(self._searchBox.Text)
    end)
    self:_connect(self._searchBox.Focused, function()
        self:_renderSearch(self._searchBox.Text)
    end)
end

function App:_buildNotifications()
    self._toastHost = create("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -20, 0, 20),
        Size = UDim2.fromOffset(320, 500),
        BackgroundTransparency = 1,
        ZIndex = 100,
        Parent = self._screen,
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self._toastHost,
    })
end

function App:_installWindowInput()
    local dragging = false
    local dragStart
    local startPosition

    self:_connect(self._header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if self._searchBox:IsFocused() then
                return
            end
            dragging = true
            dragStart = input.Position
            startPosition = self._root.Position
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local scale = math.max(self._scale.Scale, 0.01)
            self._root.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X / scale,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y / scale
            )
            self._shadow.Position = UDim2.new(
                self._root.Position.X.Scale,
                self._root.Position.X.Offset,
                self._root.Position.Y.Scale,
                self._root.Position.Y.Offset + 10
            )
        end
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    self:_connect(UserInputService.InputBegan, function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == self._toggleKey then
            self:toggle()
            return
        end
        if input.KeyCode == Enum.KeyCode.K
            and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            self:show()
            self._searchBox:CaptureFocus()
        end
    end)
end

function App:_installResponsiveScale()
    local function update()
        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end
        local viewport = camera.ViewportSize
        if viewport.X <= 0 or viewport.Y <= 0 then
            return
        end
        local marginX = UserInputService.TouchEnabled and 22 or 36
        local marginY = UserInputService.TouchEnabled and 26 or 38
        local scale = math.min(
            (viewport.X - marginX * 2) / self._baseSize.X,
            (viewport.Y - marginY * 2) / self._baseSize.Y,
            1
        )
        scale = math.clamp(scale, 0.34, 1)
        self._autoScale = scale
        self._scale.Scale = scale
        self._shadowScale.Scale = scale
        self._root.Position = UDim2.fromScale(0.5, 0.5)
        self._shadow.Position = UDim2.new(0.5, 0, 0.5, 10)
    end

    update()
    local camera = Workspace.CurrentCamera
    if camera then
        self:_connect(camera:GetPropertyChangedSignal("ViewportSize"), update)
    end
    self:_connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
        update()
    end)
end

function App:_installModelInput()
    local lastX = 0
    self:_connect(self._modelViewport.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            self._modelDragging = true
            lastX = input.Position.X
        end
    end)
    self:_connect(UserInputService.InputChanged, function(input)
        if self._modelDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position.X - lastX
            lastX = input.Position.X
            self._modelAngle = self._modelAngle + delta * 0.65
            self:_positionModel()
        elseif input.UserInputType == Enum.UserInputType.MouseWheel
            and self._modelViewport:IsDescendantOf(self._screen) then
            local mouse = UserInputService:GetMouseLocation()
            local point = self._modelViewport.AbsolutePosition
            local size = self._modelViewport.AbsoluteSize
            if mouse.X >= point.X and mouse.X <= point.X + size.X
                and mouse.Y >= point.Y and mouse.Y <= point.Y + size.Y then
                self._modelZoom = math.clamp((self._modelZoom or 1) + input.Position.Z * 0.08, 0.65, 1.55)
                self:_positionModelCamera()
            end
        end
    end)
    self:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            self._modelDragging = false
        end
    end)
    self:_connect(RunService.RenderStepped, function(deltaTime)
        if self._visible and self._modelVisible and self._modelObject
            and self._modelAutoRotate and not self._modelDragging then
            self._modelAngle = (self._modelAngle + deltaTime * self._modelRotationSpeed) % 360
            self:_positionModel()
        end
    end)
end

function App:_enableBlur(strength)
    local name = self._screenName .. "_Blur"
    local previous = Lighting:FindFirstChild(name)
    if previous then
        previous:Destroy()
    end
    self._blur = create("BlurEffect", {
        Name = name,
        Size = self._visible and math.clamp(strength, 0, 30) or 0,
        Parent = Lighting,
    })
    self._blurStrength = math.clamp(strength, 0, 30)
end

function App:_applyInitialModel(modelConfig)
    if modelConfig == nil or modelConfig == false then
        self:setModelVisible(false, true)
        return
    end

    if modelConfig == true then
        self:setModelVisible(true, true)
        return
    end

    if typeof(modelConfig) == "Instance" then
        self:setModel(modelConfig, {
            Name = modelConfig.Name,
        })
        return
    end

    if type(modelConfig) ~= "table" then
        self:setModelVisible(false, true)
        return
    end

    self._modelAutoRotate = modelConfig.AutoRotate ~= false
    self._modelRotationSpeed = tonumber(modelConfig.RotationSpeed) or 18
    self._modelZoom = math.clamp(tonumber(modelConfig.Zoom) or 1, 0.65, 1.55)
    self:setModelVisible(modelConfig.Enabled ~= false, true)

    local source = modelConfig.Instance or modelConfig.Model or modelConfig.AssetId
    if source ~= nil then
        local ok, message = self:setModel(source, modelConfig)
        if not ok then
            warn("[YumeUI Model] " .. tostring(message))
        end
    elseif modelConfig.Name then
        self._modelName.Text = tostring(modelConfig.Name)
    end
end

function App:_updateModelLayout(instant)
    if not self._pageHost then
        return
    end
    local modelShown = self._modelVisible == true
    self._modelCard.Visible = modelShown
    local targetPosition = modelShown and UDim2.fromOffset(294, 0) or UDim2.fromOffset(0, 0)
    local targetSize = modelShown and UDim2.new(1, -294, 1, 0) or UDim2.fromScale(1, 1)
    if instant then
        self._pageHost.Position = targetPosition
        self._pageHost.Size = targetSize
    else
        tween(self._pageHost, 0.28, {
            Position = targetPosition,
            Size = targetSize,
        })
    end
end

function App:setModelVisible(visible, instant)
    self._modelVisible = visible == true
    self:_updateModelLayout(instant == true)
    return self
end

function App:setModelAutoRotate(enabled, speed)
    self._modelAutoRotate = enabled ~= false
    if speed ~= nil then
        self._modelRotationSpeed = math.clamp(tonumber(speed) or 18, -120, 120)
    end
    return self
end

function App:_clearModelObject()
    if self._modelTrack then
        pcall(function()
            self._modelTrack:Stop(0)
        end)
        self._modelTrack = nil
    end
    if self._modelObject then
        self._modelObject:Destroy()
        self._modelObject = nil
    end
    self._modelBounds = nil
    self._modelPivotOffset = nil
end

function App:clearModel()
    self:_clearModelObject()
    self._modelName.Text = "NO MODEL"
    self._modelPlaceholder.Visible = true
    return self
end

function App:_resolveModelSource(source)
    if typeof(source) == "Instance" then
        return source
    end
    if type(source) == "number" or (type(source) == "string" and source:match("^%d+$")) then
        local assetId = tostring(source)
        local ok, objects = pcall(function()
            return game:GetObjects("rbxassetid://" .. assetId)
        end)
        if ok and objects and objects[1] then
            return objects[1], true
        end
        return nil, false, "无法载入模型 AssetId：" .. assetId
    end
    return nil, false, "模型必须是 Instance 或数字 AssetId"
end

function App:setModel(source, options)
    options = type(options) == "table" and options or {}
    local original, temporary, resolveError = self:_resolveModelSource(source)
    if not original then
        return false, resolveError
    end

    local oldArchivable = original.Archivable
    pcall(function()
        original.Archivable = true
    end)
    local clonedOk, clone = pcall(function()
        return original:Clone()
    end)
    pcall(function()
        original.Archivable = oldArchivable
    end)
    if temporary then
        original:Destroy()
    end
    if not clonedOk or not clone then
        return false, "模型无法被复制"
    end

    local displayModel
    if clone:IsA("Model") then
        displayModel = clone
    else
        displayModel = Instance.new("Model")
        displayModel.Name = clone.Name
        clone.Parent = displayModel
    end

    for _, descendant in ipairs(displayModel:GetDescendants()) do
        if descendant:IsA("BaseScript") then
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanQuery = false
            descendant.CanTouch = false
        elseif descendant:IsA("Humanoid") then
            descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end

    self:_clearModelObject()
    displayModel.Name = "DisplayedModel"
    displayModel.Parent = self._modelWorld
    self._modelObject = displayModel
    self._modelAngle = tonumber(options.StartAngle) or 0
    self._modelZoom = math.clamp(tonumber(options.Zoom) or self._modelZoom or 1, 0.65, 1.55)
    self._modelAutoRotate = options.AutoRotate ~= false
    self._modelRotationSpeed = tonumber(options.RotationSpeed) or self._modelRotationSpeed

    local pivot = displayModel:GetPivot()
    local boxCFrame, boxSize = displayModel:GetBoundingBox()
    if boxSize.Magnitude <= 0 then
        displayModel:Destroy()
        self._modelObject = nil
        return false, "模型中没有可显示的 BasePart"
    end
    self._modelBounds = boxSize
    self._modelPivotOffset = pivot:ToObjectSpace(boxCFrame):Inverse()
    self._modelName.Text = tostring(options.Name or original.Name or "CHARACTER")
    self._modelPlaceholder.Visible = false
    self:_positionModel()
    self:_positionModelCamera()
    self:setModelVisible(options.Enabled ~= false, true)

    if options.AnimationId then
        self:playModelAnimation(options.AnimationId)
    end
    return true, displayModel
end

function App:_positionModel()
    if not self._modelObject or not self._modelPivotOffset then
        return
    end
    local rotation = CFrame.Angles(0, math.rad(self._modelAngle), 0)
    pcall(function()
        self._modelObject:PivotTo(rotation * self._modelPivotOffset)
    end)
end

function App:_positionModelCamera()
    if not self._modelBounds then
        return
    end
    local size = self._modelBounds
    local verticalDistance = (size.Y * 0.5) / math.tan(math.rad(self._modelCamera.FieldOfView * 0.5))
    local horizontalDistance = math.max(size.X, size.Z) * 1.08
    local distance = math.max(verticalDistance, horizontalDistance, 2) * 1.24 / (self._modelZoom or 1)
    local target = Vector3.new(0, size.Y * 0.015, 0)
    self._modelCamera.CFrame = CFrame.lookAt(
        Vector3.new(0, size.Y * 0.06, distance),
        target
    )
end

function App:setModelZoom(zoom)
    self._modelZoom = math.clamp(tonumber(zoom) or 1, 0.65, 1.55)
    self:_positionModelCamera()
    return self
end

function App:playModelAnimation(animationId)
    if not self._modelObject then
        return false, "当前没有模型"
    end
    local animator = self._modelObject:FindFirstChildWhichIsA("Animator", true)
    if not animator then
        local humanoid = self._modelObject:FindFirstChildWhichIsA("Humanoid", true)
        local controller = self._modelObject:FindFirstChildWhichIsA("AnimationController", true)
        local host = humanoid or controller
        if host then
            animator = Instance.new("Animator")
            animator.Parent = host
        end
    end
    if not animator then
        return false, "模型没有 Humanoid 或 AnimationController"
    end

    local animation = Instance.new("Animation")
    animation.AnimationId = tostring(animationId):match("^rbxassetid://")
        and tostring(animationId)
        or "rbxassetid://" .. tostring(animationId)
    local ok, track = pcall(function()
        return animator:LoadAnimation(animation)
    end)
    animation:Destroy()
    if not ok or not track then
        return false, tostring(track)
    end
    if self._modelTrack then
        pcall(function()
            self._modelTrack:Stop(0.15)
        end)
    end
    self._modelTrack = track
    track.Looped = true
    track:Play(0.2)
    return true, track
end

function App:_registerSearch(page, title, description, frame)
    table.insert(self._searchItems, {
        Page = page,
        Title = tostring(title or "未命名功能"),
        Description = tostring(description or ""),
        Frame = frame,
    })
end

function App:_clearSearchRows()
    for _, child in ipairs(self._searchList:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
end

function App:_renderSearch(query)
    query = tostring(query or "")
    self:_clearSearchRows()
    local normalized = string.lower(query):gsub("^%s+", ""):gsub("%s+$", "")
    if normalized == "" then
        self._searchPanel.Visible = false
        return
    end

    self._searchPanel.Visible = true
    local matches = 0
    for _, item in ipairs(self._searchItems) do
        local haystack = string.lower(item.Title .. " " .. item.Description .. " " .. item.Page.Title)
        if string.find(haystack, normalized, 1, true) then
            matches = matches + 1
            if matches <= 12 then
                local row = create("TextButton", {
                    Size = UDim2.new(1, -6, 0, 54),
                    BackgroundColor3 = self._theme.SurfaceSoft,
                    BackgroundTransparency = 0.18,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Text = "",
                    ZIndex = 32,
                    Parent = self._searchList,
                })
                addCorner(row, 12)
                create("TextLabel", {
                    Position = UDim2.fromOffset(12, 7),
                    Size = UDim2.new(1, -82, 0, 18),
                    BackgroundTransparency = 1,
                    Text = item.Title,
                    TextColor3 = self._theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 33,
                    Parent = row,
                })
                create("TextLabel", {
                    Position = UDim2.fromOffset(12, 28),
                    Size = UDim2.new(1, -82, 0, 15),
                    BackgroundTransparency = 1,
                    Text = item.Description ~= "" and item.Description or item.Page.Title,
                    TextColor3 = self._theme.Muted,
                    TextSize = 10,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 33,
                    Parent = row,
                })
                create("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -12, 0.5, 0),
                    Size = UDim2.fromOffset(56, 24),
                    BackgroundTransparency = 1,
                    Text = item.Page.Title,
                    TextColor3 = self._theme.Accent2,
                    TextSize = 9,
                    Font = Enum.Font.GothamBold,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 33,
                    Parent = row,
                })
                self:_connect(row.Activated, function()
                    self:selectPage(item.Page.Id)
                    self._searchBox.Text = ""
                    self._searchBox:ReleaseFocus()
                    task.defer(function()
                        if item.Frame and item.Frame.Parent then
                            local scroller = item.Page.Scroller
                            local offset = item.Frame.AbsolutePosition.Y
                                - scroller.AbsolutePosition.Y
                                + scroller.CanvasPosition.Y
                                - 12
                            scroller.CanvasPosition = Vector2.new(0, math.max(offset, 0))
                            local original = item.Frame.BackgroundColor3
                            item.Frame.BackgroundColor3 = self._theme.Accent
                            tween(item.Frame, 0.55, {BackgroundColor3 = original})
                        end
                    end)
                end)
            end
        end
    end

    if matches == 0 then
        create("TextLabel", {
            Size = UDim2.new(1, -6, 0, 70),
            BackgroundTransparency = 1,
            Text = "没有找到相关功能\n换一个关键词试试",
            TextColor3 = self._theme.Muted,
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            ZIndex = 32,
            Parent = self._searchList,
        })
    end
end

function App:page(id, options)
    if type(id) == "table" then
        options = id
        id = options.Id or options.Title
    end
    options = type(options) == "table" and options or {}
    id = tostring(id or options.Title or (#self._pageOrder + 1))
    assert(not self._pages[id], "YumeUI page id already exists: " .. id)

    local page = setmetatable({
        App = self,
        Id = id,
        Title = tostring(options.Title or id),
        Icon = tostring(options.Icon or "✦"),
        Sections = {},
    }, Page)

    local buttonWidth = math.clamp(textWidth(page.Title, 12, Enum.Font.GothamMedium) + 50, 82, 180)
    page.NavButton = create("TextButton", {
        Name = "Page_" .. sanitize(id),
        Size = UDim2.fromOffset(buttonWidth, 36),
        BackgroundColor3 = self._theme.SurfaceSoft,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = page.Icon .. "  " .. page.Title,
        TextColor3 = self._theme.Muted,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        Parent = self._pageBar,
    })
    addCorner(page.NavButton, 12)
    page.NavStroke = addStroke(page.NavButton, self._theme.Stroke, 0.78, 1)

    page.Scroller = create("ScrollingFrame", {
        Name = "Content_" .. sanitize(id),
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.new(1, -16, 1, -16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = self._theme.Accent,
        Visible = false,
        Parent = self._pageHost,
    })
    page.Layout = create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page.Scroller,
    })
    addPadding(page.Scroller, 6, 8, 6, 10)
    self:_track(setCanvasFromLayout(page.Scroller, page.Layout, 18))

    self:_connect(page.NavButton.Activated, function()
        self:selectPage(id)
    end)
    self:_connect(page.NavButton.MouseEnter, function()
        if self._activePage ~= page then
            tween(page.NavButton, 0.16, {
                BackgroundTransparency = 0.2,
                TextColor3 = self._theme.Text,
            })
        end
    end)
    self:_connect(page.NavButton.MouseLeave, function()
        if self._activePage ~= page then
            tween(page.NavButton, 0.16, {
                BackgroundTransparency = 0.45,
                TextColor3 = self._theme.Muted,
            })
        end
    end)

    self._pages[id] = page
    table.insert(self._pageOrder, page)
    self._emptyState.Visible = false
    if not self._activePage then
        self:selectPage(id)
    end
    return page
end

function App:selectPage(id)
    local page = type(id) == "table" and id or self._pages[tostring(id)]
    if not page or self._activePage == page then
        return page
    end
    for _, candidate in ipairs(self._pageOrder) do
        local active = candidate == page
        candidate.Scroller.Visible = active
        tween(candidate.NavButton, 0.2, {
            BackgroundColor3 = active and self._theme.Accent or self._theme.SurfaceSoft,
            BackgroundTransparency = active and 0.08 or 0.45,
            TextColor3 = active and Color3.new(1, 1, 1) or self._theme.Muted,
        })
        candidate.NavStroke.Transparency = active and 0.28 or 0.78
        candidate.NavStroke.Color = active and self._theme.Accent2 or self._theme.Stroke
    end
    self._activePage = page
    return page
end

function Page:section(title, description)
    local section = setmetatable({
        App = self.App,
        Page = self,
        Title = tostring(title or "Section"),
    }, Section)

    section.Frame = create("Frame", {
        Name = "Section_" .. sanitize(section.Title),
        Size = UDim2.new(1, -2, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Scroller,
    })
    section.Header = create("Frame", {
        Size = UDim2.new(1, 0, 0, description and 47 or 32),
        BackgroundTransparency = 1,
        Parent = section.Frame,
    })
    create("TextLabel", {
        Position = UDim2.fromOffset(4, 2),
        Size = UDim2.new(1, -8, 0, 20),
        BackgroundTransparency = 1,
        Text = section.Title,
        TextColor3 = self.App._theme.Text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = section.Header,
    })
    if description then
        create("TextLabel", {
            Position = UDim2.fromOffset(4, 23),
            Size = UDim2.new(1, -8, 0, 17),
            BackgroundTransparency = 1,
            Text = tostring(description),
            TextColor3 = self.App._theme.Muted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = section.Header,
        })
    end
    section.List = create("Frame", {
        Position = UDim2.fromOffset(0, description and 47 or 32),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = section.Frame,
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = section.List,
    })
    table.insert(self.Sections, section)
    return section
end

function Section:_shell(options, height)
    local theme = self.App._theme
    local frame = create("Frame", {
        Name = "Control_" .. sanitize(options.Title),
        Size = UDim2.new(1, -2, 0, height or 62),
        BackgroundColor3 = theme.SurfaceSoft,
        BackgroundTransparency = 0.22,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = self.List,
    })
    addCorner(frame, 15)
    local stroke = addStroke(frame, theme.Stroke, 0.72, 1)

    local title = create("TextLabel", {
        Position = UDim2.fromOffset(14, options.Description and 10 or 0),
        Size = UDim2.new(1, -220, 0, options.Description and 20 or height or 62),
        BackgroundTransparency = 1,
        Text = tostring(options.Title or "Control"),
        TextColor3 = theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = frame,
    })
    local description
    if options.Description then
        description = create("TextLabel", {
            Position = UDim2.fromOffset(14, 31),
            Size = UDim2.new(1, -220, 0, 16),
            BackgroundTransparency = 1,
            Text = tostring(options.Description),
            TextColor3 = theme.Muted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = frame,
        })
    end

    local hover = create("TextButton", {
        Name = "Interaction",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4,
        Parent = frame,
    })
    self.App:_connect(hover.MouseEnter, function()
        tween(frame, 0.16, {BackgroundTransparency = 0.08})
        stroke.Transparency = 0.48
    end)
    self.App:_connect(hover.MouseLeave, function()
        tween(frame, 0.16, {BackgroundTransparency = 0.22})
        stroke.Transparency = 0.72
    end)
    self.App:_registerSearch(self.Page, options.Title, options.Description, frame)
    return frame, hover, title, description, stroke
end

function Section:paragraph(options, body)
    if type(options) ~= "table" then
        options = {
            Title = tostring(options or "说明"),
            Content = tostring(body or ""),
        }
    end
    local frame = create("Frame", {
        Name = "Paragraph_" .. sanitize(options.Title),
        Size = UDim2.new(1, -2, 0, 82),
        BackgroundColor3 = self.App._theme.SurfaceSoft,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        Parent = self.List,
    })
    addCorner(frame, 15)
    addStroke(frame, self.App._theme.Stroke, 0.74, 1)
    local marker = create("Frame", {
        Position = UDim2.fromOffset(10, 12),
        Size = UDim2.fromOffset(3, 58),
        BackgroundColor3 = self.App._theme.Accent,
        BorderSizePixel = 0,
        Parent = frame,
    })
    addCorner(marker, 6)
    table.insert(self.App._accentObjects, {Object = marker, Property = "BackgroundColor3", Slot = 1})
    create("TextLabel", {
        Position = UDim2.fromOffset(23, 11),
        Size = UDim2.new(1, -36, 0, 22),
        BackgroundTransparency = 1,
        Text = tostring(options.Title or "说明"),
        TextColor3 = self.App._theme.Text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame,
    })
    create("TextLabel", {
        Position = UDim2.fromOffset(23, 36),
        Size = UDim2.new(1, -36, 0, 34),
        BackgroundTransparency = 1,
        Text = tostring(options.Content or options.Description or ""),
        TextColor3 = self.App._theme.Muted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = frame,
    })
    self.App:_registerSearch(self.Page, options.Title, options.Content, frame)
    return frame
end

function Section:button(options, callback)
    options = normalizeControlOptions(options, callback)
    local frame, interaction = self:_shell(options, 60)
    local action = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(66, 32),
        BackgroundColor3 = self.App._theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = frame,
    })
    addCorner(action, 11)
    local actionGradient = makeGradient(action, self.App._theme.Accent, self.App._theme.Accent2, 12)
    table.insert(self.App._accentGradients, actionGradient)
    create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = tostring(options.ActionText or "运行") .. "  ›",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        ZIndex = 3,
        Parent = action,
    })
    local busy = false
    self.App:_connect(interaction.Activated, function()
        if busy or options.Disabled then
            return
        end
        busy = true
        tween(action, 0.08, {Size = UDim2.fromOffset(61, 29)})
        task.delay(0.09, function()
            if action.Parent then
                tween(action, 0.18, {Size = UDim2.fromOffset(66, 32)})
            end
        end)
        safeCall(options.Callback)
        task.delay(tonumber(options.Debounce) or 0.12, function()
            busy = false
        end)
    end)
    return {
        Frame = frame,
        Fire = function()
            safeCall(options.Callback)
        end,
    }
end

function Section:toggle(options, callback)
    options = normalizeControlOptions(options, callback)
    local frame, interaction = self:_shell(options, 60)
    local state = options.Default == true
    local switch = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(48, 27),
        BackgroundColor3 = state and self.App._theme.Accent or self.App._theme.Stroke,
        BackgroundTransparency = state and 0.04 or 0.42,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = frame,
    })
    addCorner(switch, 99)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = state and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.fromOffset(21, 21),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = switch,
    })
    addCorner(knob, 99)

    local handle = {}
    function handle:Set(value, silent)
        state = value == true
        tween(switch, 0.2, {
            BackgroundColor3 = state and self.App._theme.Accent or self.App._theme.Stroke,
            BackgroundTransparency = state and 0.04 or 0.42,
        })
        tween(knob, 0.2, {
            Position = state and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 14, 0.5, 0),
        })
        if not silent then
            safeCall(options.Callback, state)
        end
        return state
    end
    function handle:Get()
        return state
    end
    handle.Frame = frame
    handle.App = self.App

    self.App:_connect(interaction.Activated, function()
        handle:Set(not state)
    end)
    if options.FireOnLoad then
        safeCall(options.Callback, state)
    end
    return handle
end

function Section:divider(label)
    local frame = create("Frame", {
        Size = UDim2.new(1, -2, 0, label and 26 or 16),
        BackgroundTransparency = 1,
        Parent = self.List,
    })
    local line = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.new(1, -8, 0, 1),
        BackgroundColor3 = self.App._theme.Stroke,
        BackgroundTransparency = 0.58,
        BorderSizePixel = 0,
        Parent = frame,
    })
    if label then
        local text = tostring(label)
        local width = textWidth(text, 9, Enum.Font.GothamBold) + 20
        create("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(width, 20),
            BackgroundColor3 = self.App._theme.Surface,
            BorderSizePixel = 0,
            Text = string.upper(text),
            TextColor3 = self.App._theme.Muted,
            TextSize = 9,
            Font = Enum.Font.GothamBold,
            Parent = frame,
        })
    end
    return line
end

function Section:slider(options)
    options = type(options) == "table" and options or {}
    options.Title = options.Title or "Slider"
    local minimum = tonumber(options.Min) or 0
    local maximum = tonumber(options.Max) or 100
    if maximum <= minimum then
        maximum = minimum + 1
    end
    local step = math.max(tonumber(options.Step) or 1, 0.0001)
    local value = math.clamp(tonumber(options.Default) or minimum, minimum, maximum)
    local frame, interaction = self:_shell(options, 76)
    interaction.Size = UDim2.new(1, 0, 0, 54)

    local valueLabel = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 10),
        Size = UDim2.fromOffset(76, 20),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = self.App._theme.Accent2,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 3,
        Parent = frame,
    })
    local rail = create("Frame", {
        Position = UDim2.new(0, 14, 1, -18),
        Size = UDim2.new(1, -28, 0, 6),
        BackgroundColor3 = self.App._theme.Stroke,
        BackgroundTransparency = 0.54,
        BorderSizePixel = 0,
        Parent = frame,
    })
    addCorner(rail, 99)
    local fill = create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = self.App._theme.Accent,
        BorderSizePixel = 0,
        Parent = rail,
    })
    addCorner(fill, 99)
    local fillGradient = makeGradient(fill, self.App._theme.Accent, self.App._theme.Accent2, 0)
    table.insert(self.App._accentGradients, fillGradient)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(15, 15),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = rail,
    })
    addCorner(knob, 99)
    addStroke(knob, self.App._theme.Accent, 0.08, 2)
    local hitbox = create("TextButton", {
        Position = UDim2.new(0, -4, 0, -10),
        Size = UDim2.new(1, 8, 1, 20),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
        Parent = rail,
    })

    local dragging = false
    local handle = {Frame = frame}
    local function displayValue(number)
        local decimals = step < 1 and 2 or 0
        return string.format("%." .. decimals .. "f", number) .. tostring(options.Suffix or "")
    end
    function handle:Set(nextValue, silent)
        nextValue = math.clamp(tonumber(nextValue) or minimum, minimum, maximum)
        nextValue = math.floor(((nextValue - minimum) / step) + 0.5) * step + minimum
        nextValue = math.clamp(nextValue, minimum, maximum)
        value = nextValue
        local alpha = (value - minimum) / (maximum - minimum)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.fromScale(alpha, 0.5)
        valueLabel.Text = displayValue(value)
        if not silent then
            safeCall(options.Callback, value)
        end
        return value
    end
    function handle:Get()
        return value
    end
    local function updateFromX(x)
        local width = math.max(rail.AbsoluteSize.X, 1)
        local alpha = math.clamp((x - rail.AbsolutePosition.X) / width, 0, 1)
        handle:Set(minimum + (maximum - minimum) * alpha)
    end
    self.App:_connect(hitbox.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
            tween(knob, 0.12, {Size = UDim2.fromOffset(19, 19)})
        end
    end)
    self.App:_connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)
    self.App:_connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            tween(knob, 0.12, {Size = UDim2.fromOffset(15, 15)})
        end
    end)
    handle:Set(value, not options.FireOnLoad)
    return handle
end

function Section:input(options)
    options = type(options) == "table" and options or {}
    options.Title = options.Title or "Input"
    local frame, interaction = self:_shell(options, 62)
    interaction.Size = UDim2.new(0, 0, 0, 0)
    interaction.Visible = false
    local box = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(190, 36),
        BackgroundColor3 = self.App._theme.Background,
        BackgroundTransparency = 0.24,
        BorderSizePixel = 0,
        ClearTextOnFocus = options.ClearOnFocus == true,
        PlaceholderText = tostring(options.Placeholder or "输入内容…"),
        PlaceholderColor3 = self.App._theme.Muted,
        Text = tostring(options.Default or ""),
        TextColor3 = self.App._theme.Text,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5,
        Parent = frame,
    })
    addCorner(box, 11)
    local boxStroke = addStroke(box, self.App._theme.Stroke, 0.68, 1)
    addPadding(box, 11, 11, 0, 0)
    self.App:_connect(box.Focused, function()
        tween(box, 0.16, {BackgroundTransparency = 0.08})
        boxStroke.Color = self.App._theme.Accent
        boxStroke.Transparency = 0.25
    end)
    self.App:_connect(box.FocusLost, function(enterPressed)
        tween(box, 0.16, {BackgroundTransparency = 0.24})
        boxStroke.Color = self.App._theme.Stroke
        boxStroke.Transparency = 0.68
        safeCall(options.Callback, box.Text, enterPressed)
    end)
    if options.Live == true then
        self.App:_connect(box:GetPropertyChangedSignal("Text"), function()
            safeCall(options.Callback, box.Text, false)
        end)
    end
    return {
        Frame = frame,
        Object = box,
        Get = function()
            return box.Text
        end,
        Set = function(_, text, silent)
            box.Text = tostring(text or "")
            if not silent and not options.Live then
                safeCall(options.Callback, box.Text, false)
            end
        end,
    }
end

function Section:dropdown(options)
    options = type(options) == "table" and options or {}
    options.Title = options.Title or "Dropdown"
    local choices = type(options.Values) == "table" and options.Values or {}
    local value = options.Default or choices[1]
    local frame, interaction = self:_shell(options, 62)
    interaction.Size = UDim2.new(1, 0, 0, 62)

    local selector = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 13),
        Size = UDim2.fromOffset(176, 36),
        BackgroundColor3 = self.App._theme.Background,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = frame,
    })
    addCorner(selector, 11)
    addStroke(selector, self.App._theme.Stroke, 0.68, 1)
    local selectedText = create("TextLabel", {
        Position = UDim2.fromOffset(11, 0),
        Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        Text = tostring(value or "请选择"),
        TextColor3 = self.App._theme.Text,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
        Parent = selector,
    })
    local arrow = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 0),
        Size = UDim2.fromOffset(24, 36),
        BackgroundTransparency = 1,
        Text = "⌄",
        TextColor3 = self.App._theme.Muted,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        ZIndex = 3,
        Parent = selector,
    })
    local list = create("Frame", {
        Position = UDim2.new(0, 10, 0, 58),
        Size = UDim2.new(1, -20, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = frame,
    })
    local listLayout = create("UIListLayout", {
        Padding = UDim.new(0, 5),
        Parent = list,
    })
    local expanded = false
    local handle = {Frame = frame}

    local function setExpanded(nextExpanded)
        expanded = nextExpanded == true
        local listHeight = expanded and (#choices * 34 + math.max(#choices - 1, 0) * 5) or 0
        tween(frame, 0.24, {Size = UDim2.new(1, -2, 0, 62 + listHeight + (expanded and 10 or 0))})
        tween(list, 0.24, {Size = UDim2.new(1, -20, 0, listHeight)})
        tween(arrow, 0.2, {Rotation = expanded and 180 or 0})
    end
    function handle:Set(nextValue, silent)
        if not table.find(choices, nextValue) then
            return value
        end
        value = nextValue
        selectedText.Text = tostring(value)
        setExpanded(false)
        if not silent then
            safeCall(options.Callback, value)
        end
        return value
    end
    function handle:Get()
        return value
    end
    for _, choice in ipairs(choices) do
        local choiceValue = choice
        local row = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = self.App._theme.Background,
            BackgroundTransparency = 0.34,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "  " .. tostring(choiceValue),
            TextColor3 = self.App._theme.Muted,
            TextSize = 11,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = list,
        })
        addCorner(row, 10)
        self.App:_connect(row.Activated, function()
            handle:Set(choiceValue)
        end)
        self.App:_connect(row.MouseEnter, function()
            tween(row, 0.13, {
                BackgroundTransparency = 0.12,
                TextColor3 = self.App._theme.Text,
            })
        end)
        self.App:_connect(row.MouseLeave, function()
            tween(row, 0.13, {
                BackgroundTransparency = 0.34,
                TextColor3 = self.App._theme.Muted,
            })
        end)
    end
    self.App:_connect(interaction.Activated, function()
        setExpanded(not expanded)
    end)
    if options.FireOnLoad then
        safeCall(options.Callback, value)
    end
    return handle
end

function Section:keybind(options)
    options = type(options) == "table" and options or {}
    options.Title = options.Title or "Keybind"
    local current = resolveKeyCode(options.Default) or Enum.KeyCode.F
    local listening = false
    local frame, interaction = self:_shell(options, 60)
    local keyButton = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -13, 0.5, 0),
        Size = UDim2.fromOffset(82, 32),
        BackgroundColor3 = self.App._theme.Background,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Text = current.Name,
        TextColor3 = self.App._theme.Accent2,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        ZIndex = 3,
        Parent = frame,
    })
    addCorner(keyButton, 10)
    addStroke(keyButton, self.App._theme.Stroke, 0.64, 1)
    local handle = {Frame = frame}
    function handle:Set(key)
        local resolved = resolveKeyCode(key)
        if resolved then
            current = resolved
            keyButton.Text = current.Name
        end
        return current
    end
    function handle:Get()
        return current
    end
    self.App:_connect(interaction.Activated, function()
        listening = true
        keyButton.Text = "按下按键…"
        keyButton.TextColor3 = self.App._theme.Warning
    end)
    self.App:_connect(UserInputService.InputBegan, function(input, processed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end
        if listening then
            listening = false
            if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.Unknown then
                current = input.KeyCode
                safeCall(options.Changed, current)
            end
            keyButton.Text = current.Name
            keyButton.TextColor3 = self.App._theme.Accent2
            return
        end
        if not processed and input.KeyCode == current then
            safeCall(options.Callback, current)
        end
    end)
    return handle
end

function App:notify(options, content)
    if type(options) ~= "table" then
        options = {
            Title = tostring(options or "YumeUI"),
            Content = tostring(content or ""),
        }
    end
    if self._destroyed then
        return nil
    end
    local tone = options.Tone == "success" and self._theme.Success
        or options.Tone == "warning" and self._theme.Warning
        or options.Tone == "danger" and self._theme.Danger
        or self._theme.Accent
    local toast = create("Frame", {
        Size = UDim2.fromOffset(0, 76),
        BackgroundColor3 = self._theme.Background,
        BackgroundTransparency = 0.035,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 101,
        Parent = self._toastHost,
    })
    addCorner(toast, 16)
    addStroke(toast, tone, 0.36, 1)
    local stripe = create("Frame", {
        Size = UDim2.fromOffset(4, 76),
        BackgroundColor3 = tone,
        BorderSizePixel = 0,
        ZIndex = 102,
        Parent = toast,
    })
    addCorner(stripe, 6)
    create("TextLabel", {
        Position = UDim2.fromOffset(16, 11),
        Size = UDim2.new(1, -32, 0, 20),
        BackgroundTransparency = 1,
        Text = tostring(options.Title or "YumeUI"),
        TextColor3 = self._theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 102,
        Parent = toast,
    })
    create("TextLabel", {
        Position = UDim2.fromOffset(16, 35),
        Size = UDim2.new(1, -32, 0, 28),
        BackgroundTransparency = 1,
        Text = tostring(options.Content or ""),
        TextColor3 = self._theme.Muted,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 102,
        Parent = toast,
    })
    tween(toast, 0.3, {Size = UDim2.fromOffset(310, 76)}, Enum.EasingStyle.Back)
    task.delay(math.max(tonumber(options.Duration) or 3.5, 0.8), function()
        if not toast.Parent then
            return
        end
        local animation = tween(toast, 0.25, {
            Size = UDim2.fromOffset(0, 76),
            BackgroundTransparency = 1,
        })
        if animation then
            animation.Completed:Connect(function()
                if toast.Parent then
                    toast:Destroy()
                end
            end)
        end
    end)
    return toast
end

function App:setAccent(first, second)
    if typeof(first) ~= "Color3" then
        return self
    end
    second = typeof(second) == "Color3" and second or first:Lerp(Color3.new(1, 1, 1), 0.28)
    self._theme.Accent = first
    self._theme.Accent2 = second
    for _, item in ipairs(self._accentObjects) do
        if item.Object and item.Object.Parent then
            item.Object[item.Property] = item.Slot == 2 and second or first
        end
    end
    for _, gradient in ipairs(self._accentGradients) do
        if gradient and gradient.Parent then
            gradient.Color = ColorSequence.new(first, second)
        end
    end
    if self._activePage then
        self:selectPage(self._activePage)
        self._activePage.NavButton.BackgroundColor3 = first
        self._activePage.NavStroke.Color = second
    end
    return self
end

function App:setBlur(strength)
    strength = math.clamp(tonumber(strength) or 0, 0, 30)
    self._blurStrength = strength
    if not self._blur and strength > 0 then
        self:_enableBlur(strength)
    elseif self._blur then
        tween(self._blur, 0.2, {Size = self._visible and strength or 0})
    end
    return self
end

function App:show()
    if self._destroyed or self._visible then
        return self
    end
    self._visible = true
    self:_setMinimizeDockVisible(false, false)
    self._root.Visible = true
    self._shadow.Visible = true
    self._root.BackgroundTransparency = 1
    self._scale.Scale = math.max(self._scale.Scale * 0.94, 0.01)
    tween(self._root, 0.24, {BackgroundTransparency = 0.035})
    tween(self._scale, 0.3, {Scale = self._autoScale or self._scale.Scale / 0.94}, Enum.EasingStyle.Back)
    if self._blur then
        tween(self._blur, 0.22, {Size = self._blurStrength})
    end
    safeCall(self._config.OnOpen, self)
    return self
end

function App:hide()
    if self._destroyed or not self._visible then
        return self
    end
    self._visible = false
    self._searchBox:ReleaseFocus()
    self._searchPanel.Visible = false
    local targetScale = math.max((self._autoScale or self._scale.Scale) * 0.94, 0.01)
    tween(self._root, 0.2, {BackgroundTransparency = 1})
    local animation = tween(self._scale, 0.22, {Scale = targetScale})
    if self._blur then
        tween(self._blur, 0.2, {Size = 0})
    end
    if animation then
        animation.Completed:Connect(function()
            if not self._visible and self._root then
                self._root.Visible = false
                self._shadow.Visible = false
                self:_setMinimizeDockVisible(true, false)
            end
        end)
    end
    safeCall(self._config.OnClose, self)
    return self
end

function App:toggle()
    if self._visible then
        return self:hide()
    end
    return self:show()
end

function App:isVisible()
    return self._visible
end

function App:focusSearch(text)
    self:show()
    self._searchBox.Text = tostring(text or "")
    self._searchBox:CaptureFocus()
    return self
end

function App:destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    safeCall(self._config.OnDestroy, self)
    self:_clearModelObject()

    for index = #self._cleanup, 1, -1 do
        local item = self._cleanup[index]
        if typeof(item) == "RBXScriptConnection" then
            item:Disconnect()
        elseif typeof(item) == "Tween" then
            item:Cancel()
        elseif type(item) == "function" then
            pcall(item)
        end
    end
    table.clear(self._cleanup)
    if self._blur then
        self._blur:Destroy()
    end
    if self._screen then
        self._screen:Destroy()
    end
end

function App:getPage(id)
    return self._pages[tostring(id)]
end

function App:getModel()
    return self._modelObject
end

-- Readable aliases for teams that prefer PascalCase.
YumeUI.Mount = YumeUI.mount
App.Page = App.page
App.SelectPage = App.selectPage
App.Notify = App.notify
App.SetModel = App.setModel
App.ClearModel = App.clearModel
App.SetModelVisible = App.setModelVisible
App.SetModelAutoRotate = App.setModelAutoRotate
App.SetModelZoom = App.setModelZoom
App.PlayModelAnimation = App.playModelAnimation
App.SetAccent = App.setAccent
App.SetBlur = App.setBlur
App.Show = App.show
App.Hide = App.hide
App.Toggle = App.toggle
App.Destroy = App.destroy
Page.Section = Page.section
Section.Paragraph = Section.paragraph
Section.Button = Section.button
Section.Toggle = Section.toggle
Section.Slider = Section.slider
Section.Input = Section.input
Section.Dropdown = Section.dropdown
Section.Keybind = Section.keybind
Section.Divider = Section.divider

return YumeUI

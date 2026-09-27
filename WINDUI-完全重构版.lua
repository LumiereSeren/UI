-- PY Hub White Glass UI: independent Roblox/Luau implementation.
-- GUI pixels cannot read and convolve the live 3D framebuffer in a ScreenGui.
-- This renderer integrates translucent layers in ONE clipped rounded root.
-- Optional GlobalBlur affects the whole local 3D view; the matched example enables it.
-- Implements WindUI v1.6.62 public UI methods; internal Creator trees and external
-- license-provider SDKs are not copied. See the compatibility notes.
-- A loaded module does not create UI until Create/CreateWindow is called.

local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Tween = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local WindUI = {BuildVersion = "PY-WhiteGlass-Rewrite-4", Version = "1.6.62-compatible"}
local App = {}
App.__index = App
local Page = {}
Page.__index = Page

local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(46, 48, 53)
local MUTED = Color3.fromRGB(102, 106, 114)
local PEARL = Color3.fromRGB(247, 248, 250)
local SILVER = Color3.fromRGB(182, 186, 194)
local FONT = Enum.Font.Gotham
local BOLD = Enum.Font.GothamMedium
local ICONS = {
    house = "⌂", search = "⌕", palette = "◉", ["wand-sparkles"] = "✧",
    settings = "⚙", video = "▣", bell = "◈",
}
local function clamp(v, lo, hi) return math.clamp(tonumber(v) or lo, lo, hi) end
local function color(value, fallback) return typeof(value) == "Color3" and value or fallback end
local function accentInk(shade)
    return shade.R * 0.2126 + shade.G * 0.7152 + shade.B * 0.0722 > 0.62 and INK or shade
end
local function inst(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do object[key] = value end
    if WindUI._font and (not props or props.Font ~= Enum.Font.Code) and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
        if typeof(WindUI._font) == "EnumItem" then object.Font = WindUI._font
        elseif typeof(WindUI._font) == "Font" then object.FontFace = WindUI._font
        elseif type(WindUI._font) == "string" then pcall(function() object.FontFace = Font.new(WindUI._font) end) end
    end
    object.Parent = parent
    return object
end
local function corner(object, radius)
    return inst("UICorner", object, {CornerRadius = UDim.new(0, radius)})
end
local function stroke(object, shade, transparency, width)
    return inst("UIStroke", object, {
        Color = shade, Transparency = transparency, Thickness = width or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end
local function label(parent, text, size, shade, weight, props)
    local values = {
        Text = tostring(text or ""), TextSize = size, TextColor3 = shade,
        Font = weight or FONT, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }
    for key, value in pairs(props or {}) do values[key] = value end
    return inst("TextLabel", parent, values)
end
local function button(parent, text, props)
    local values = {
        Text = text or "", Font = FONT, TextSize = 15, TextColor3 = INK,
        BackgroundTransparency = 1, AutoButtonColor = false,
    }
    for key, value in pairs(props or {}) do values[key] = value end
    return inst("TextButton", parent, values)
end
local function tween(object, duration, props, style)
    local t = Tween:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end
local function safe(callback, ...)
    if type(callback) ~= "function" then return end
    local ok, err = pcall(callback, ...)
    if not ok then warn("[WhiteGlass] " .. tostring(err)) end
end
local function connect(app, signal, callback)
    local connection = signal:Connect(callback)
    table.insert(app._connections, connection)
    return connection
end
local function interactive(page, row)
    if page.App.KeyVerified == false or page.App._closed then return false end
    local control = page.App._controlsByRoot and page.App._controlsByRoot[row]
    local parent = page
    while parent do
        if parent.Locked or parent.Destroyed then return false end
        parent = parent.ParentContainer
    end
    return not page.App._destroyed and not (control and (control.Locked or control.Destroyed))
end
local function parentGui()
    local player = Players.LocalPlayer
    if player then return player:WaitForChild("PlayerGui") end
    return game:GetService("CoreGui")
end

function WindUI:Create(options)
    options = type(options) == "table" and options or {}
    local glass = type(options.Beauty) == "table" and options.Beauty or {}
    local app = setmetatable({
        Window = {}, Pages = {}, Flags = {}, _connections = {}, _events = {},
        _accent = color(glass.AccentColor, WHITE), _searchText = "", _closed = false,
        _destroyed = false, _bodyAlpha = clamp(glass.BodyTransparency or 0.68, 0.16, 0.82),
        _shadowAlpha = 0.95, _contentAlpha = 0.84, _accentBindings = {},
        _controlsByRoot = {}, AllElements = {}, PendingFlags = {},
        _mistEnabled = glass.CloudMist ~= false,
        _mistOpacity = clamp(glass.MistOpacity or 0.34, 0, 0.6),
        _mistSpread = clamp(glass.MistSpread or 1, 0.65, 1.35),
        _searchVisible = options.TopbarSearchEnabled ~= false,
        _searchWidth = clamp(options.TopbarSearchWidth or 145, 90, 190),
        _glassEnabled = glass.FrostedGlass ~= false,
        _blurSize = clamp(glass.BlurSize or 16, 0, 56),
        _globalBlur = glass.GlobalBlur == true,
        _motionEnabled = glass.MotionEnabled ~= false,
        _hoverEnabled = glass.HoverMotion ~= false,
        _theme = "WhiteGlass", _clockVisible = options.TopbarClock == true,
        _toggleKey = options.ToggleKey or Enum.KeyCode.RightControl,
        _searchHotkey = options.SearchHotkey or Enum.KeyCode.K,
        _searchCtrl = options.SearchRequiresControl ~= false,
    }, App)

    local gui = inst("ScreenGui", parentGui(), {
        Name = "PY_WhiteGlass_" .. tostring(math.floor(os.clock() * 1000)),
        ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 50,
    })
    app.Gui = gui
    -- The shadow has no white fill; the body itself is one rounded, clipped instance.
    local holder = inst("Frame", gui, {
        Name = "WindowHolder", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(580, 460),
        BackgroundTransparency = 1, ClipsDescendants = false,
    })
    app.Holder = holder
    local autoScale = inst("UIScale", holder, {Scale = 1})
    app.AutoScaleObject = autoScale
    local function fit()
        if options.AutoScale == false then autoScale.Scale = app._requestedScale or 1; return end
        local camera = workspace.CurrentCamera
        if camera then
            local size = camera.ViewportSize
            local width = holder.Size.X.Offset + holder.Size.X.Scale * size.X
            local height = holder.Size.Y.Offset + holder.Size.Y.Scale * size.Y
            autoScale.Scale = math.max(0.1, math.min(app._requestedScale or 1,
                (size.X - 24) / math.max(1, width), (size.Y - 36) / math.max(1, height)))
        end
    end
    app._fit = fit
    fit()
    connect(app, workspace:GetPropertyChangedSignal("CurrentCamera"), fit)
    if workspace.CurrentCamera then
        connect(app, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fit)
    end

    local shade = inst("Frame", holder, {
        Name = "SoftShadow", Position = UDim2.fromOffset(0, 8),
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(65, 67, 73),
        BackgroundTransparency = app._shadowAlpha, BorderSizePixel = 0, ZIndex = 1,
    })
    corner(shade, 17)
    local root = inst("CanvasGroup", holder, {
        Name = "GlassWindow", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = WHITE, BackgroundTransparency = 1,
        BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2,
    })
    corner(root, 16)
    local border = stroke(root, WHITE, 0.32, 1)
    local surface = inst("Frame", root, {
        Name = "GlassSurface", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = WHITE, BackgroundTransparency = app._bodyAlpha,
        BorderSizePixel = 0, ZIndex = 2,
    })
    local gradient = inst("UIGradient", surface, {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, WHITE),
            ColorSequenceKeypoint.new(1, PEARL),
        }), Rotation = 112,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.5, 0.07),
            NumberSequenceKeypoint.new(1, 0.02),
        }),
    })
    local rimLight = inst("Frame", root, {
        Name = "GlassRimLight", Position = UDim2.new(0.08, 0, 0, 1),
        Size = UDim2.new(0.84, 0, 0, 2), BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.24, BorderSizePixel = 0, ZIndex = 10,
    })
    inst("UIGradient", rimLight, {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.48, 0.12),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })
    -- CanvasGroup applies the UICorner to the composed descendants.
    local topbar = inst("Frame", root, {
        Name = "Topbar", Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.78,
        BorderSizePixel = 0, ZIndex = 3,
    })
    inst("Frame", topbar, {
        Name = "Hairline", Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.72, BorderSizePixel = 0,
    })
    local title = label(topbar, options.Title or "WindUI", 15, INK, BOLD, {
        Name = "Title", Position = UDim2.fromOffset(18, 7), Size = UDim2.fromOffset(134, 22),
    })
    local author = label(topbar, options.Author or "", 11, MUTED, FONT, {
        Name = "Author", Position = UDim2.fromOffset(18, 28), Size = UDim2.fromOffset(134, 16),
    })
    local searchBox = inst("TextBox", topbar, {
        Name = "Search", Position = UDim2.fromOffset(155, 11),
        Size = UDim2.fromOffset(app._searchWidth, 31), Text = "", ClearTextOnFocus = false,
        PlaceholderText = options.TopbarSearchPlaceholder or "搜索功能...",
        TextColor3 = INK, PlaceholderColor3 = MUTED, Font = FONT, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.61, BorderSizePixel = 0, Visible = app._searchVisible,
        ZIndex = 4,
    })
    corner(searchBox, 9)
    stroke(searchBox, WHITE, 0.66)
    inst("UIPadding", searchBox, {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 8)})
    local clock = label(topbar, "", 11, MUTED, FONT, {
        Position = UDim2.new(1, -198, 0, 12), Size = UDim2.fromOffset(88, 28),
        TextXAlignment = Enum.TextXAlignment.Right, Visible = app._clockVisible,
    })
    local minimize = button(topbar, "−", {
        Name = "Minimize", Position = UDim2.new(1, -94, 0, 7), Size = UDim2.fromOffset(29, 38),
        TextSize = 23, TextColor3 = MUTED, ZIndex = 4,
    })
    local recenter = button(topbar, "□", {
        Name = "Center", Position = UDim2.new(1, -63, 0, 7), Size = UDim2.fromOffset(29, 38),
        TextSize = 17, TextColor3 = MUTED, ZIndex = 4,
    })
    local close = button(topbar, "×", {
        Name = "Close", Position = UDim2.new(1, -32, 0, 7), Size = UDim2.fromOffset(29, 38),
        TextSize = 22, TextColor3 = MUTED, ZIndex = 4,
    })

    local sidebar = inst("Frame", root, {
        Name = "Sidebar", Position = UDim2.fromOffset(0, 52),
        Size = UDim2.new(0, 188, 1, -52), BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.85, BorderSizePixel = 0, ZIndex = 3,
    })
    local navScroll = inst("ScrollingFrame", sidebar, {
        Name = "Navigation", Position = UDim2.fromOffset(8, 13),
        Size = UDim2.new(1, -16, 1, -24), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 2,
        ScrollBarImageColor3 = SILVER, ScrollBarImageTransparency = 0.42,
        CanvasSize = UDim2.fromOffset(0, 0), ScrollingDirection = Enum.ScrollingDirection.Y,
    })
    local navLayout = inst("UIListLayout", navScroll, {
        Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder,
    })
    navScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    inst("UIPadding", navScroll, {PaddingBottom = UDim.new(0, 12)})
    local content = inst("Frame", root, {
        Name = "ContentLayer", Position = UDim2.fromOffset(199, 62),
        Size = UDim2.new(1, -211, 1, -76),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = app._contentAlpha, BorderSizePixel = 0, ZIndex = 3,
        ClipsDescendants = true,
    })
    corner(content, 12)
    local selectedBar = inst("Frame", sidebar, {
        Name = "SelectionEdge", Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(2, 34), BackgroundColor3 = app._accent,
        BackgroundTransparency = 0.12, BorderSizePixel = 0, Visible = false,
    })
    app.UI = {
        Root = root, Surface = surface, Shadow = shade, Border = border, Gradient = gradient,
        Topbar = topbar, Sidebar = sidebar, Content = content,
        NavScroll = navScroll, Search = searchBox, Title = title, Author = author,
        Clock = clock, SelectionEdge = selectedBar,
        Minimize = minimize, Center = recenter, Close = close,
    }

    local compact = inst("CanvasGroup", gui, {
        Name = "DynamicIsland", AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -52), Size = UDim2.fromOffset(106, 34),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.36, BorderSizePixel = 0,
        ClipsDescendants = true, Visible = false, ZIndex = 20,
    })
    corner(compact, 23)
    local islandStroke = stroke(compact, WHITE, 0.32, 1)
    local islandGlow = inst("Frame", compact, {
        Name = "TopGlint", Position = UDim2.new(0.13, 0, 0, 1),
        Size = UDim2.new(0.74, 0, 0, 1), BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.22, BorderSizePixel = 0, ZIndex = 21,
    })
    inst("UIGradient", islandGlow, {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.18),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })
    local islandDot = inst("Frame", compact, {
        Name = "AccentDot", Position = UDim2.new(0, 15, 0.5, -4),
        Size = UDim2.fromOffset(8, 8), BackgroundColor3 = app._accent,
        BorderSizePixel = 0, ZIndex = 22,
    })
    corner(islandDot, 4)
    stroke(islandDot, SILVER, 0.35)
    local islandTitle = label(compact, options.Title or "WindUI", 12, INK, BOLD, {
        Name = "IslandTitle", Position = UDim2.fromOffset(30, 8),
        Size = UDim2.new(1, -58, 0, 23), ZIndex = 22,
    })
    local islandArrow = label(compact, "⌃", 16, MUTED, FONT, {
        Position = UDim2.new(1, -27, 0, 7), Size = UDim2.fromOffset(16, 25),
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 22,
    })
    local compactButton = button(compact, "", {
        Name = "Restore", Size = UDim2.fromScale(1, 1), ZIndex = 23,
    })
    app.Compact = compact
    app.Island = {Stroke = islandStroke, Dot = islandDot, Title = islandTitle, Arrow = islandArrow}
    connect(app, compactButton.MouseButton1Click, function() app:Open() end)
    connect(app, compactButton.MouseEnter, function()
        if app._closed and app._motionEnabled then
            local size = app._islandSizeRest or UDim2.fromOffset(166, 42)
            tween(compact, 0.22, {Size = UDim2.fromOffset(size.X.Offset + 10, size.Y.Offset + 2), BackgroundTransparency = 0.22})
            tween(islandStroke, 0.22, {Transparency = 0.16})
            app:_sweep(compact, 0.83)
        end
    end)
    connect(app, compactButton.MouseLeave, function()
        if app._closed and app._motionEnabled then
            tween(compact, 0.24, {Size = app._islandSizeRest or UDim2.fromOffset(166, 42), BackgroundTransparency = 0.36})
            tween(islandStroke, 0.24, {Transparency = 0.32})
        end
    end)
    connect(app, minimize.MouseButton1Click, function() app:Close() end)
    connect(app, close.MouseButton1Click, function() app:Destroy() end)
    connect(app, recenter.MouseButton1Click, function() app:ToggleFullscreen() end)
    for _, action in ipairs({minimize, recenter, close}) do
        connect(app, action.MouseEnter, function()
            if app._motionEnabled then tween(action, 0.17, {TextColor3 = INK}) end
        end)
        connect(app, action.MouseLeave, function()
            if app._motionEnabled then tween(action, 0.2, {TextColor3 = MUTED}) end
        end)
    end

    -- Drag only from the title region; input inside search and controls remains untouched.
    local dragging, dragStart, startPosition = false, nil, nil
    connect(app, topbar.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if input.Position.X > title.AbsolutePosition.X + 140 then return end
        dragging, dragStart, startPosition = true, input.Position, holder.Position
    end)
    connect(app, Input.InputChanged, function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        holder.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end)
    connect(app, Input.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    connect(app, Input.InputBegan, function(input, processed)
        if processed or app._destroyed then return end
        if input.KeyCode == app._toggleKey then app:Toggle() end
        if input.KeyCode == app._searchHotkey then
            local ctrl = Input:IsKeyDown(Enum.KeyCode.LeftControl)
                or Input:IsKeyDown(Enum.KeyCode.RightControl)
            if not app._searchCtrl or ctrl then
                app:Open()
                searchBox.Visible = true
                searchBox:CaptureFocus()
            end
        end
    end)
    connect(app, searchBox:GetPropertyChangedSignal("Text"), function()
        app:Search(searchBox.Text)
    end)
    app._clockFormat = options.TopbarClockFormat or "%H:%M:%S"
    if app._clockVisible then app:SetClockVisible(true) end
    if app._globalBlur then app:SetFrostedGlass(true, {GlobalBlur = true, BlurSize = app._blurSize}) end
    app.Window.SetTitle = function(_, text)
        title.Text = tostring(text or "")
        islandTitle.Text = title.Text
    end
    app.Window.SetAuthor = function(_, text) author.Text = tostring(text or "") end
    app.Window.Open = function() app:Open() end
    app.Window.Close = function() app:Close() end
    app.Window.Toggle = function() app:Toggle() end
    app.Window.Destroy = function() app:Destroy() end
    app:SetCloudMist(app._mistEnabled)
    return app
end
WindUI.CreateApp = WindUI.Create

function App:_emit(event)
    for _, callback in ipairs(self._events[event] or {}) do safe(callback) end
end
function App:On(event, callback)
    if type(callback) ~= "function" then return self end
    self._events[event] = self._events[event] or {}
    table.insert(self._events[event], callback)
    return self
end
function App:_createMist()
    -- Eight reusable puffs, made only from feathered white GUI layers.
    -- The Gaussian profile softens the mist itself, not the live game scene.
    -- No textures, HTTP downloads, RenderStepped handlers or 3D parts are needed.
    local mist = inst("Frame", self.Holder, {
        Name = "CloudMist", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ClipsDescendants = false, Active = false, ZIndex = 0,
    })
    self.UI.Mist = mist
    self._mistPuffs, self._mistLayers, self._mistTweens = {}, {}, {}
    local layout = {
        {X = 0.13, Y = 0.01, W = 240, H = 120, DX = 12, DY = -6, T = 11, R = -7},
        {X = 0.64, Y = 0.00, W = 238, H = 108, DX = -9, DY = 5, T = 13, R = 4},
        {X = 0.99, Y = 0.19, W = 114, H = 194, DX = 6, DY = 11, T = 10, R = 6},
        {X = 1.00, Y = 0.71, W = 126, H = 218, DX = -5, DY = -9, T = 12, R = -5},
        {X = 0.82, Y = 1.00, W = 212, H = 116, DX = -12, DY = 5, T = 14, R = 5},
        {X = 0.29, Y = 0.99, W = 250, H = 124, DX = 10, DY = -4, T = 11, R = -4},
        {X = 0.01, Y = 0.80, W = 112, H = 182, DX = -5, DY = -11, T = 13, R = 5},
        {X = 0.00, Y = 0.33, W = 128, H = 212, DX = 6, DY = 9, T = 12, R = -6},
    }
    local feather = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.25, 0.18),
        NumberSequenceKeypoint.new(0.55, 0.04),
        NumberSequenceKeypoint.new(0.8, 0.22),
        NumberSequenceKeypoint.new(1, 1),
    })
    for index, spec in ipairs(layout) do
        local puff = inst("Frame", mist, {
            Name = "MistPuff" .. index, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(spec.X, spec.Y),
            Size = UDim2.fromOffset(spec.W, spec.H), Rotation = spec.R,
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ClipsDescendants = false, Active = false, ZIndex = 0,
        })
        table.insert(self._mistPuffs, {Root = puff, Width = spec.W, Height = spec.H})
        local previous = 0
        for ring = 1, 10 do
            local radius = 1 - (ring - 1) * 0.085
            local profile = math.exp(-4 * radius * radius)
            local layer = inst("Frame", puff, {
                Name = "Feather" .. ring, AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(radius, radius),
                BackgroundColor3 = WHITE, BackgroundTransparency = 1,
                BorderSizePixel = 0, Active = false, ZIndex = 0,
            })
            inst("UICorner", layer, {CornerRadius = UDim.new(0.5, 0)})
            inst("UIGradient", layer, {Transparency = feather, Rotation = index % 2 == 0 and 90 or 0})
            table.insert(self._mistLayers, {Root = layer, Profile = profile, Previous = previous})
            previous = profile
        end
        local drift = Tween:Create(puff,
            TweenInfo.new(spec.T, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                Position = UDim2.new(spec.X, spec.DX, spec.Y, spec.DY),
                Rotation = spec.R + (index % 2 == 0 and 4 or -4),
            })
        table.insert(self._mistTweens, drift)
    end
end
function App:_syncMist()
    if not self.UI.Mist then return end
    local visible = self._mistEnabled and self._mistOpacity > 0
        and not self._closed and not self._destroyed and self.Holder.Visible
    self.UI.Mist.Visible = visible
    local running = visible and self._motionEnabled
    if running ~= self._mistRunning then
        self._mistRunning = running
        for _, drift in ipairs(self._mistTweens) do
            if running then drift:Play() else drift:Pause() end
        end
    end
end
function App:SetCloudMist(enabled, options)
    if self._destroyed then return self end
    options = type(options) == "table" and options or {}
    self._mistEnabled = enabled == true
    if options.Opacity ~= nil then self._mistOpacity = clamp(options.Opacity, 0, 0.6) end
    if options.Spread ~= nil then self._mistSpread = clamp(options.Spread, 0.65, 1.35) end
    if self._mistEnabled and not self.UI.Mist then self:_createMist() end
    for _, layer in ipairs(self._mistLayers or {}) do
        local before = self._mistOpacity * layer.Previous
        local after = self._mistOpacity * layer.Profile
        layer.Root.BackgroundTransparency = 1 - (after - before) / (1 - before)
    end
    for _, puff in ipairs(self._mistPuffs or {}) do
        puff.Root.Size = UDim2.fromOffset(puff.Width * self._mistSpread, puff.Height * self._mistSpread)
    end
    self:_syncMist()
    return self
end
function App:_sweep(target, opacity)
    if not self._motionEnabled or self._destroyed or not target.Parent then return end
    self._sheens = self._sheens or {}
    local previous = self._sheens[target]
    if previous then previous:Destroy() end
    local band = inst("Frame", target, {
        Name = "WhiteSheen", Position = UDim2.new(0, -112, 0, 0),
        Size = UDim2.new(0, 76, 1, 0), Rotation = 12,
        BackgroundColor3 = WHITE, BackgroundTransparency = opacity or 0.9,
        BorderSizePixel = 0, ZIndex = target == self.Compact and 22 or 28,
    })
    inst("UIGradient", band, {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })
    self._sheens[target] = band
    tween(band, target == self.Compact and 0.52 or 0.72,
        {Position = UDim2.new(1, 112, 0, 0)}, Enum.EasingStyle.Quint)
    task.delay(0.76, function()
        if self._sheens and self._sheens[target] == band then
            self._sheens[target] = nil
        end
        if band.Parent then band:Destroy() end
    end)
end
function App:_stopWindowMotion()
    for _, field in ipairs({"_windowFade", "_windowMove", "_shadowFade", "_islandMove", "_islandFade", "_islandSize"}) do
        if self[field] then self[field]:Cancel(); self[field] = nil end
    end
end
function App:Open()
    if self._destroyed then return self end
    if not self._closed then return self end
    self._transitionToken = (self._transitionToken or 0) + 1
    local token = self._transitionToken
    self:_stopWindowMotion()
    self._closed = false
    self.Holder.Visible = true
    self._transitioning = self._motionEnabled
    if self._motionEnabled then
        local resting = self._restingPosition or self.Holder.Position
        self.Holder.Position = UDim2.new(resting.X.Scale, resting.X.Offset,
            resting.Y.Scale, resting.Y.Offset + 12)
        self.UI.Root.GroupTransparency = 1
        self.UI.Shadow.BackgroundTransparency = 1
        self._windowMove = tween(self.Holder, 0.37, {Position = resting}, Enum.EasingStyle.Quint)
        self._windowFade = tween(self.UI.Root, 0.34, {GroupTransparency = 0}, Enum.EasingStyle.Quint)
        self._shadowFade = tween(self.UI.Shadow, 0.38, {BackgroundTransparency = self._shadowAlpha})
        self._islandMove = tween(self.Compact, 0.3, {Position = UDim2.new(0.5, 0, 0, -52)}, Enum.EasingStyle.Quint)
        self._islandFade = tween(self.Compact, 0.24, {GroupTransparency = 1})
        task.delay(0.31, function()
            if not self._destroyed and self._transitionToken == token then
                self.Compact.Visible = false
                self.Compact.GroupTransparency = 0
            end
        end)
        task.delay(0.39, function()
            if not self._destroyed and self._transitionToken == token then
                self._transitioning = false
                self._restingPosition = nil
            end
        end)
        self:_sweep(self.UI.Root, 0.91)
    else
        self.Compact.Visible = false
        self.UI.Root.GroupTransparency = 0
    end
    self:_syncBlur()
    self:_syncMist()
    self:_emit("Open")
    return self
end
function App:Close()
    if self._destroyed then return self end
    if self._closed then return self end
    self._transitionToken = (self._transitionToken or 0) + 1
    local token = self._transitionToken
    local resting = self._transitioning and self._restingPosition or self.Holder.Position
    self:_stopWindowMotion()
    self._closed = true
    self._restingPosition = resting
    self._transitioning = self._motionEnabled
    self.Compact.Visible = self.IsOpenButtonEnabled ~= false
    self.Compact.BackgroundTransparency = 0.36
    self.Island.Stroke.Transparency = 0.32
    if self._motionEnabled then
        self.Compact.Position = UDim2.new(0.5, 0, 0, -52)
        self.Compact.Size = UDim2.fromOffset(106, 34)
        self.Compact.GroupTransparency = 1
        self._windowFade = tween(self.UI.Root, 0.23, {GroupTransparency = 1})
        self._shadowFade = tween(self.UI.Shadow, 0.23, {BackgroundTransparency = 1})
        self._windowMove = tween(self.Holder, 0.28, {
            Position = UDim2.new(resting.X.Scale, resting.X.Offset,
                resting.Y.Scale, resting.Y.Offset + 12),
        }, Enum.EasingStyle.Quint)
        self._islandMove = tween(self.Compact, 0.42, {
            Position = self._islandPosition or UDim2.new(0.5, 0, 0, 12),
        }, Enum.EasingStyle.Quint)
        self._islandSize = tween(self.Compact, 0.42, {
            Size = self._islandSizeRest or UDim2.fromOffset(166, 42),
        }, Enum.EasingStyle.Quint)
        self._islandFade = tween(self.Compact, 0.34, {GroupTransparency = 0})
        task.delay(0.28, function()
            if not self._destroyed and self._transitionToken == token then
                self.Holder.Visible = false
                self.Holder.Position = resting
                self.UI.Root.GroupTransparency = 0
                self._transitioning = false
            end
        end)
        task.delay(0.2, function()
            if not self._destroyed and self._transitionToken == token then
                self:_sweep(self.Compact, 0.81)
            end
        end)
    else
        self.Holder.Visible = false
        self.Compact.Position = self._islandPosition or UDim2.new(0.5, 0, 0, 12)
        self.Compact.Size = self._islandSizeRest or UDim2.fromOffset(166, 42)
        self.Compact.GroupTransparency = 0
    end
    self:_syncBlur()
    self:_syncMist()
    self:_emit("Close")
    return self
end
function App:Toggle()
    if self._closed then return self:Open() else return self:Close() end
end
function App:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self:_stopWindowMotion()
    for _, drift in ipairs(self._mistTweens or {}) do drift:Cancel(); drift:Destroy() end
    self._mistTweens, self._mistLayers, self._mistPuffs = {}, {}, {}
    self._mistRunning = false
    self._accentBindings = {}
    self._sheens = nil
    if self._blur then self._blur:Destroy(); self._blur = nil end
    for _, connection in ipairs(self._connections) do connection:Disconnect() end
    self._connections = {}
    self:_emit("Destroy")
    self.Gui:Destroy()
end
function App:Center()
    self:_stopWindowMotion()
    self._transitionToken = (self._transitionToken or 0) + 1
    self._transitioning = false
    self.Holder.Position = UDim2.fromScale(0.5, 0.5)
    self._restingPosition = self._closed and self.Holder.Position or nil
    self.Holder.Visible = not self._closed
    self.UI.Root.GroupTransparency = 0
    self.UI.Shadow.BackgroundTransparency = self._shadowAlpha
    self.Compact.Visible = self._closed and self.IsOpenButtonEnabled ~= false
    self.Compact.GroupTransparency = 0
    self.Compact.Position = self._islandPosition or UDim2.new(0.5, 0, 0, 12)
    self.Compact.Size = self._islandSizeRest or UDim2.fromOffset(166, 42)
    return self
end

function App:Page(options)
    options = type(options) == "table" and options or {Title = tostring(options or "页面")}
    local title = tostring(options.Title or "页面")
    local page = setmetatable({App = self, Title = title, Items = {}, Locked = false}, Page)
    local tab = button(self.UI.NavScroll, "", {
        Name = "Tab_" .. title, Size = UDim2.new(1, -4, 0, 42),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 1, Text = "", ZIndex = 5,
        LayoutOrder = #self.Pages + 1,
    })
    corner(tab, 9)
    local icon = label(tab, ICONS[options.Icon] or "◇", 16, MUTED, FONT, {
        Position = UDim2.fromOffset(12, 1), Size = UDim2.fromOffset(22, 40),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    local tabText = label(tab, title, 13, INK, FONT, {
        Position = UDim2.fromOffset(38, 2), Size = UDim2.new(1, -46, 1, -4),
    })
    page.Tab, page.TabText, page.TabIcon = tab, tabText, icon
    local scroll = inst("ScrollingFrame", self.UI.Content, {
        Name = "Page_" .. title, Position = UDim2.fromOffset(11, 12),
        Size = UDim2.new(1, -22, 1, -22), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = SILVER, ScrollBarImageTransparency = 0.35,
        CanvasSize = UDim2.fromOffset(0, 0), Visible = false, ZIndex = 4,
    })
    inst("UIPadding", scroll, {PaddingBottom = UDim.new(0, 18)})
    local layout = inst("UIListLayout", scroll, {
        Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder,
    })
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Active, scroll.ScrollingEnabled = true, true
    page.Scroll, page.Layout = scroll, layout
    table.insert(self.Pages, page)
    connect(self, tab.MouseButton1Click, function() page:Select() end)
    if #self.Pages == 1 then page:Select() end
    return page
end
function Page:Select()
    local app = self.App
    local changed = app.SelectedPage ~= self
    local theme = app._themeData or {}
    local activeText, idleText = color(theme.Text, INK), color(theme.Placeholder, MUTED)
    app.SelectedPage = self
    for _, page in ipairs(app.Pages) do
        local current = page == self
        page.Scroll.Visible = current
        if changed and app._motionEnabled then
            tween(page.Tab, 0.23, {BackgroundTransparency = current and 0.57 or 1})
            tween(page.TabText, 0.23, {TextColor3 = current and activeText or idleText})
            tween(page.TabIcon, 0.23, {TextColor3 = current and activeText or idleText})
        else
            page.Tab.BackgroundTransparency = current and 0.57 or 1
            page.TabText.TextColor3 = current and activeText or idleText
            page.TabIcon.TextColor3 = current and activeText or idleText
        end
        if not WindUI._font then page.TabText.Font = current and BOLD or FONT end
    end
    if changed then self.Scroll.CanvasPosition = Vector2.new(0, 0) end
    if changed and app._motionEnabled and not app._closed then
        app.UI.Content.BackgroundTransparency = math.min(1, app._contentAlpha + 0.06)
        tween(app.UI.Content, 0.3, {BackgroundTransparency = app._contentAlpha})
        app:_sweep(app.UI.Root, 0.94)
    end
    return self
end
function Page:_row(title, desc, height, clickable)
    local connectionStart = #self.App._connections
    local props = {
        Name = tostring(title), Size = UDim2.new(1, -5, 0, height or 58),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.78,
        BorderSizePixel = 0, ZIndex = 5,
        LayoutOrder = #self.Items + 1,
    }
    if clickable then props.AutoButtonColor = false; props.Text = "" end
    local row = inst(clickable and "TextButton" or "Frame", self.Scroll, props)
    corner(row, 9)
    if clickable then
        row.ClipsDescendants = true
        connect(self.App, row.MouseEnter, function()
            if self.App._hoverEnabled then tween(row, 0.18, {BackgroundTransparency = 0.60}) end
        end)
        connect(self.App, row.MouseLeave, function()
            if self.App._hoverEnabled then tween(row, 0.22, {BackgroundTransparency = 0.78}) end
        end)
        connect(self.App, row.MouseButton1Click, function()
            if not interactive(self, row) then return end
            if self.App._rippleEnabled then self.App:_ripple(row) end
            if self.App._motionEnabled then
                row.BackgroundTransparency = 0.50
                tween(row, 0.32, {BackgroundTransparency = 0.78})
            end
        end)
    end
    local titleLabel = label(row, title, 13, INK, BOLD, {
        Position = UDim2.fromOffset(12, desc and 8 or 0),
        Size = UDim2.new(1, -100, 0, desc and 23 or (height or 58)),
    })
    local description
    if desc then
        description = label(row, desc, 11, MUTED, FONT, {
            Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -96, 0, 19),
        })
    end
    if clickable then
        connect(self.App, row.MouseEnter, function()
            if not self.App._hoverEnabled then return end
            tween(titleLabel, 0.17, {Position = UDim2.fromOffset(15, desc and 8 or 0)})
            if description then tween(description, 0.17, {Position = UDim2.fromOffset(15, 30)}) end
        end)
        connect(self.App, row.MouseLeave, function()
            if not self.App._hoverEnabled then return end
            tween(titleLabel, 0.2, {Position = UDim2.fromOffset(12, desc and 8 or 0)})
            if description then tween(description, 0.2, {Position = UDim2.fromOffset(12, 30)}) end
        end)
    end
    local record = {Root = row, Title = tostring(title), Description = tostring(desc or ""),
        TitleLabel = titleLabel, DescriptionLabel = description, ConnectionStart = connectionStart}
    table.insert(self.Items, record)
    return row, titleLabel, description, record
end
function Page:Paragraph(title, description)
    local row, heading, subtitle = self:_row(title, description, 68)
    row.BackgroundTransparency = 1
    heading.TextSize = 14
    heading.Size = UDim2.new(1, -24, 0, 26)
    if subtitle then subtitle.Size = UDim2.new(1, -24, 0, 32); subtitle.TextWrapped = true end
    return row
end
function Page:Divider()
    local row = self:_row("", nil, 15)
    row.BackgroundTransparency = 1
    inst("Frame", row, {
        Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 1),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.52,
        BorderSizePixel = 0,
    })
    return row
end
function Page:Space(amount)
    local row = self:_row("", nil, clamp(amount or 1, 1, 8) * 12)
    row.BackgroundTransparency = 1
    return row
end
function Page:Button(title, callback, options)
    options = type(options) == "table" and options or {}
    local row = self:_row(title, options.Desc, 58, true)
    label(row, "›", 25, MUTED, FONT, {
        Position = UDim2.new(1, -32, 0, 0), Size = UDim2.fromOffset(23, 58),
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    connect(self.App, row.MouseButton1Click, function()
        if interactive(self, row) then safe(callback) end
    end)
    return row
end
function Page:DebouncedButton(title, delaySeconds, callback, options)
    local last = -math.huge
    return self:Button(title, function()
        local now = os.clock()
        if now - last < clamp(delaySeconds or 1, 0, 120) then return end
        last = now
        safe(callback)
    end, options)
end
function Page:Toggle(title, defaultValue, callback, options)
    options = type(options) == "table" and options or {}
    local row = self:_row(title, options.Desc, 58, true)
    local value = defaultValue == true
    local track = inst("Frame", row, {
        Name = "ToggleTrack",
        Position = UDim2.new(1, -62, 0.5, -12), Size = UDim2.fromOffset(46, 24),
        BackgroundColor3 = value and self.App._accent or SILVER,
        BackgroundTransparency = value and 0.12 or 0.5,
        BorderSizePixel = 0, ZIndex = 6,
    })
    corner(track, 12)
    stroke(track, WHITE, 0.62)
    local knob = inst("Frame", track, {
        Name = "ToggleKnob",
        Position = UDim2.fromOffset(value and 25 or 3, 3), Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 7,
    })
    corner(knob, 9)
    stroke(knob, SILVER, 0.50)
    local indicator = inst("Frame", knob, {
        Name = "OnIndicator", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4),
        BackgroundColor3 = MUTED, BackgroundTransparency = 0.26,
        BorderSizePixel = 0, ZIndex = 8, Visible = value,
    })
    corner(indicator, 2)
    local control = {Root = row}
    function control:Set(nextValue, fire)
        value = nextValue == true
        track.BackgroundColor3 = value and self.App._accent or SILVER
        track.BackgroundTransparency = value and 0.12 or 0.5
        indicator.Visible = value
        if self.App._motionEnabled then
            tween(knob, 0.18, {Position = UDim2.fromOffset(value and 25 or 3, 3)})
        else
            knob.Position = UDim2.fromOffset(value and 25 or 3, 3)
        end
        if options.Flag then self.App.Flags[options.Flag] = value end
        if fire ~= false then safe(callback, value) end
    end
    control.App = self.App
    table.insert(self.App._accentBindings, function()
        if track.Parent then track.BackgroundColor3 = value and self.App._accent or SILVER end
    end)
    function control:Get() return value end
    if options.Flag then self.App.Flags[options.Flag] = value end
    connect(self.App, row.MouseButton1Click, function()
        if interactive(self, row) then control:Set(not value) end
    end)
    return control
end
function Page:Slider(title, minimum, maximum, defaultValue, callback, options)
    options = type(options) == "table" and options or {}
    minimum = tonumber(minimum) or 0; maximum = math.max(minimum + 1, tonumber(maximum) or 100)
    local step = math.max(0.0001, tonumber(options.Step) or 1)
    local row = self:_row(title, options.Desc, 58)
    local value = clamp(defaultValue or minimum, minimum, maximum)
    local readout = label(row, "", 12, MUTED, FONT, {
        Position = UDim2.new(1, -145, 0, 9), Size = UDim2.fromOffset(35, 42),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local bar = button(row, "", {
        Position = UDim2.new(1, -100, 0.5, -8), Size = UDim2.fromOffset(88, 16),
        BackgroundTransparency = 1, ZIndex = 7,
    })
    local rail = inst("Frame", bar, {
        Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(88, 4),
        BackgroundColor3 = SILVER, BackgroundTransparency = 0.56, BorderSizePixel = 0,
    })
    corner(rail, 2)
    local fill = inst("Frame", rail, {
        Size = UDim2.fromScale(0, 1), BackgroundColor3 = self.App._accent,
        BorderSizePixel = 0,
    })
    corner(fill, 2)
    table.insert(self.App._accentBindings, function()
        if fill.Parent then fill.BackgroundColor3 = self.App._accent end
    end)
    local dot = inst("Frame", bar, {
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE,
        Position = UDim2.fromOffset(0, 1), BorderSizePixel = 0,
    })
    corner(dot, 7)
    stroke(dot, SILVER, 0.38)
    local control = {App = self.App, Root = row}
    function control:Set(nextValue, fire)
        value = minimum + math.floor((clamp(nextValue, minimum, maximum) - minimum) / step + 0.5) * step
        value = clamp(value, minimum, maximum)
        local fraction = (value - minimum) / (maximum - minimum)
        fill.Size = UDim2.fromScale(fraction, 1)
        dot.Position = UDim2.new(fraction, -7, 0, 1)
        readout.Text = tostring(value)
        if options.Flag then self.App.Flags[options.Flag] = value end
        if fire ~= false then safe(callback, value) end
    end
    function control:Get() return value end
    control:Set(value, false)
    function control:SetMin(nextMin)
        minimum = math.min(tonumber(nextMin) or minimum, maximum - step)
        control:Set(value, false)
        return minimum
    end
    function control:SetMax(nextMax)
        maximum = math.max(tonumber(nextMax) or maximum, minimum + step)
        control:Set(value, false)
        return maximum
    end
    local dragging = false
    local function adjust(x)
        if not interactive(self, row) then return end
        control:Set(minimum + (maximum - minimum) * clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1))
    end
    connect(self.App, bar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; adjust(input.Position.X)
        end
    end)
    connect(self.App, Input.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then adjust(input.Position.X) end
    end)
    connect(self.App, Input.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return control
end
function Page:Input(title, initial, callback, options)
    options = type(options) == "table" and options or {}
    local row = self:_row(title, options.Desc, 58)
    local edit = inst("TextBox", row, {
        Text = tostring(initial or ""), PlaceholderText = options.Placeholder or "请输入...",
        Position = UDim2.new(1, -152, 0.5, -17), Size = UDim2.fromOffset(140, 34),
        TextColor3 = INK, PlaceholderColor3 = MUTED,
        TextSize = 12, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.60, BorderSizePixel = 0, ZIndex = 6,
    })
    corner(edit, 8)
    inst("UIPadding", edit, {PaddingLeft = UDim.new(0, 8)})
    local control = {Root = row, TextBox = edit}
    function control:SetPlaceholder(text) edit.PlaceholderText = tostring(text or ""); return self end
    function control:Set(value, fire)
        edit.Text = tostring(value or "")
        if options.Flag then self.App.Flags[options.Flag] = edit.Text end
        if fire ~= false then safe(callback, edit.Text) end
    end
    control.App = self.App
    function control:Get() return edit.Text end
    connect(self.App, edit.FocusLost, function()
        if interactive(self, row) then control:Set(edit.Text) end
    end)
    return control
end
function App:SetSearchVisible(enabled)
    self._searchVisible = enabled == true
    self.UI.Search.Visible = self._searchVisible
    if self._layoutTopbar then self:_layoutTopbar() end
    return self
end
function App:SetSearchWidth(width)
    self._searchWidth = clamp(width, 90, 190)
    self.UI.Search.Size = UDim2.fromOffset(self._searchWidth, 31)
    if self._layoutTopbar then self:_layoutTopbar() end
    return self
end
function App:SetClockVisible(enabled)
    self._clockVisible = enabled == true
    self.UI.Clock.Visible = self._clockVisible
    self._clockToken = (self._clockToken or 0) + 1
    local token = self._clockToken
    local function tick()
        if self._destroyed or not self._clockVisible or self._clockToken ~= token then return end
        if not self._closed then self.UI.Clock.Text = os.date(self._clockFormat or "%H:%M:%S") end
        task.delay(1, tick)
    end
    if self._clockVisible then tick() end
    if self._layoutTopbar then self:_layoutTopbar() end
    return self
end
function App:SetAccentColor(shade)
    self._accent = color(shade, WHITE)
    self.UI.SelectionEdge.BackgroundColor3 = self._accent
    if self.Island then self.Island.Dot.BackgroundColor3 = self._accent end
    for _, update in ipairs(self._accentBindings) do update() end
    if self.SelectedPage then self.SelectedPage:Select() end
    return self
end
function App:SetWhiteGlassStyle(options)
    options = type(options) == "table" and options or {}
    self:SetTheme("WhiteGlass")
    self:SetAccentColor(options.AccentColor or self._accent)
    self:SetFrostedGlass(options.FrostedGlass ~= false, options)
    if options.CloudMist ~= nil or options.MistOpacity ~= nil or options.MistSpread ~= nil then
        self:SetCloudMist(options.CloudMist ~= false, {
            Opacity = options.MistOpacity, Spread = options.MistSpread,
        })
    end
    return self
end
function App:SetAnimeDarkStyle(options) return self:SetWhiteGlassStyle(options) end
function App:SetLayeredGlass(enabled, options)
    options = type(options) == "table" and options or {}
    self.UI.Sidebar.BackgroundTransparency = enabled and clamp(options.RegionTransparency or 0.85, 0, 1) or 1
    self.UI.Topbar.BackgroundTransparency = enabled and clamp(options.TopbarTransparency or 0.78, 0, 1) or 1
    self._contentAlpha = enabled and clamp(options.CardTransparency or 0.84, 0, 1) or 1
    self.UI.Content.BackgroundTransparency = self._contentAlpha
    return self
end
function App:SetGlassTransparency(value)
    self._bodyAlpha = clamp(value, 0.16, 0.82)
    self.UI.Surface.BackgroundTransparency = self._bodyAlpha
    return self
end
function App:SetBackgroundImage(image, transparency)
    if not self._backgroundImage then
        self._backgroundImage = inst("ImageLabel", self.UI.Root, {
            Name = "OptionalBackgroundImage", Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0.58, ZIndex = 2,
        })
    end
    local asset, err = WindUI:_resolveImage(image)
    if not asset then return false, err end
    self._backgroundImage.Image = asset
    self._backgroundImage.ImageTransparency = clamp(transparency or 0.58, 0, 1)
    return self
end
function App:SetBackgroundTransparency(value)
    if self._backgroundImage then
        self._backgroundImage.ImageTransparency = clamp(value, 0, 1)
    end
    return self
end
function App:SetGitHubBackground(url, transparency, forceRefresh)
    if type(url) ~= "string" or not url:match("^https://") then return false, "需要 HTTPS 图片链接" end
    local asset, err, path = WindUI:_resolveImage(url, forceRefresh)
    if not asset then return false, err end
    self._backgroundPath, self._backgroundURL = path, url
    self:SetBackgroundImage(asset, transparency)
    return true, asset
end
function App:RefreshGitHubBackground(url, transparency)
    return self:SetGitHubBackground(url or self._backgroundURL, transparency, true)
end
function App:ClearGitHubBackgroundCache()
    if self._backgroundPath and type(delfile) == "function" then
        pcall(delfile, self._backgroundPath)
    end
    if self._backgroundURL then WindUI._imageAssets[self._backgroundURL] = nil end
    self._backgroundPath = nil
    return self
end
function App:SetTitleColor(shade)
    self.UI.Title.TextColor3 = color(shade, INK)
    return self
end
function App:SetTopbarTint(shade, transparency)
    self.UI.Topbar.BackgroundColor3 = color(shade, WHITE)
    self.UI.Topbar.BackgroundTransparency = clamp(transparency, 0, 1)
    return self
end
function App:SetShadow(alpha, shade)
    self._shadowAlpha = clamp(alpha, 0, 1)
    self.UI.Shadow.BackgroundTransparency = self._shadowAlpha
    self.UI.Shadow.BackgroundColor3 = color(shade, Color3.fromRGB(65, 67, 73))
    return self
end
function App:SetUIFont(font)
    for _, descendant in ipairs(self.Gui:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
            if typeof(font) == "EnumItem" then
                descendant.Font = font
            elseif typeof(font) == "Font" then
                descendant.FontFace = font
            elseif type(font) == "string" then
                local ok, face = pcall(Font.new, font)
                if ok then descendant.FontFace = face end
            end
        end
    end
    return self
end
function App:SetStatus(text, shade)
    if not self._status then
        self._status = label(self.UI.Topbar, "", 11, INK, FONT, {
            Position = UDim2.new(1, -207, 0, 14), Size = UDim2.fromOffset(105, 25),
            TextXAlignment = Enum.TextXAlignment.Center,
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.3,
        })
        corner(self._status, 10)
    end
    self._status.Text = tostring(text or "")
    self._status.TextColor3 = color(shade, INK)
    self._status.Visible = true
    if self._layoutTopbar then self:_layoutTopbar() end
    return self
end
function App:ClearStatus()
    if self._status then self._status.Visible = false end
    if self._layoutTopbar then self:_layoutTopbar() end
    return self
end
function App:Pulse()
    self:_sweep(self.UI.Root, 0.88)
    tween(self.UI.Border, 0.25, {Transparency = 0.03})
    task.delay(0.28, function()
        if not self._destroyed then tween(self.UI.Border, 0.4, {Transparency = 0.32}) end
    end)
    return self
end
function App:_ripple(row)
    local mark = inst("Frame", row, {
        Name = "ClickRipple", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = self._accent, BackgroundTransparency = 0.77,
        BorderSizePixel = 0, ZIndex = 8,
    })
    corner(mark, 80)
    local animation = tween(mark, 0.28, {
        Size = UDim2.fromOffset(220, 220), BackgroundTransparency = 1,
    })
    local connection
    connection = animation.Completed:Connect(function()
        connection:Disconnect()
        if mark.Parent then mark:Destroy() end
    end)
end
function App:SetRippleEffect(enabled)
    self._rippleEnabled = enabled == true
    return self
end
function App:SetHoverMotion(enabled)
    self._hoverEnabled = enabled == true
    return self
end
function App:SetMotionEnabled(enabled)
    self._motionEnabled = enabled == true
    if not self._motionEnabled then
        self._transitionToken = (self._transitionToken or 0) + 1
        self:_stopWindowMotion()
        self.UI.Root.GroupTransparency = 0
        self.Holder.Position = self._restingPosition or self.Holder.Position
        self.Holder.Visible = not self._closed
        self.Compact.Visible = self._closed and self.IsOpenButtonEnabled ~= false
        self.Compact.GroupTransparency = 0
        self.Compact.Position = self._islandPosition or UDim2.new(0.5, 0, 0, 12)
        self.Compact.Size = self._islandSizeRest or UDim2.fromOffset(166, 42)
        self.UI.Shadow.BackgroundTransparency = self._shadowAlpha
        self._transitioning = false
        if not self._closed then self._restingPosition = nil end
    end
    self:_syncMist()
    return self
end
function App:SetAmbientGlow(enabled)
    self.UI.Border.Color = enabled and self._accent or WHITE
    self.UI.Border.Transparency = enabled and 0.05 or 0.32
    return self
end
function App:EnableRainbowAccent()
    if self._rainbow then return self end
    self._rainbow = true
    task.spawn(function()
        while self._rainbow and not self._destroyed do
            self:SetAccentColor(Color3.fromHSV((os.clock() * 0.08) % 1, 0.57, 0.95))
            task.wait(0.12)
        end
    end)
    return self
end
function App:DisableRainbowAccent(shade)
    self._rainbow = false
    if shade then self:SetAccentColor(shade) end
    return self
end

-- Optional HTTP images are downloaded once; Roblox asset IDs need no file APIs.
do
    WindUI._imageAssets = {}
    function WindUI:_resolveImage(source, forceRefresh)
        source = tostring(source or "")
        if source:match("^%d+$") then return "rbxassetid://" .. source end
        if not source:match("^https?://") then return source end
        if source:match("^http://") then return nil, "Image URLs must use HTTPS" end
        if not forceRefresh and self._imageAssets[source] then
            return self._imageAssets[source].Asset, nil, self._imageAssets[source].Path
        end
        local loader = getcustomasset or getsynasset
        if type(writefile) ~= "function" or type(loader) ~= "function" then
            return nil, "HTTP images require writefile and getcustomasset; use a Roblox asset ID here"
        end
        local pathOnly = source:match("^[^?]+") or source
        local extension = (pathOnly:match("%.([%a%d]+)$") or "png"):lower()
        if extension ~= "png" and extension ~= "jpg" and extension ~= "jpeg" and extension ~= "webp" then
            return nil, "Only PNG/JPG/JPEG/WebP images are supported"
        end
        local hash = 5381
        for i = 1, #source do hash = (hash * 33 + source:byte(i)) % 4294967296 end
        local folder = "PYHubGlassAssets"
        local path = folder .. "/" .. string.format("%08x", hash) .. "_" .. #source .. "." .. extension
        local ok, result = pcall(function()
            if type(makefolder) == "function" and (not isfolder or not isfolder(folder)) then makefolder(folder) end
            if forceRefresh or type(isfile) ~= "function" or not isfile(path) then
                local data = game:HttpGet(source)
                assert(type(data) == "string" and #data > 32, "Image download is empty")
                writefile(path, data)
            end
            return loader(path)
        end)
        if not ok then return nil, tostring(result) end
        self._imageAssets[source] = {Asset = result, Path = path}
        return result, nil, path
    end
    function WindUI:RegisterIconPack(icons)
        self._iconAssets = self._iconAssets or {}
        for name, asset in pairs(icons) do self._iconAssets[name] = asset end
        return self
    end
    function WindUI:_setIcon(target, icon, shade)
        local source = (self._iconAssets and self._iconAssets[icon]) or icon
        if type(source) == "string" and (source:match("^rbxasset") or source:match("^https://") or source:match("^%d+$")) then
            local asset, err = self:_resolveImage(source)
            if not asset then target.Text = "◇"; return false, err end
            target.Text = ""
            local image = target:FindFirstChild("CustomIcon") or inst("ImageLabel", target, {
                Name = "CustomIcon", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                ScaleType = Enum.ScaleType.Fit,
            })
            image.Image, image.ImageColor3 = asset, color(shade, WHITE)
        else
            local old = target:FindFirstChild("CustomIcon"); if old then old:Destroy() end
            target.Text = ICONS[icon] or (icon and "◇" or "")
        end
        return true
    end
end

-- Public WindUI 1.6.62 element API, implemented on the white-glass renderer.
do
    local rawPage = {}
    for _, name in ipairs({"Button", "Toggle", "Slider", "Input", "Paragraph", "Divider", "Space"}) do
        rawPage[name] = Page[name]
    end
    local function removeItem(list, item)
        for i = #list, 1, -1 do if list[i] == item then table.remove(list, i) end end
    end
    local function copy(value)
        if type(value) ~= "table" then return value end
        local result = {}
        for k, v in pairs(value) do result[k] = v end
        return result
    end
    local function descend(container, parent)
        while container do
            if container == parent then return true end
            container = container.ParentContainer
        end
        return false
    end
    local function decorate(page, kind, options, native, startConnections, startAccents)
        local app = page.App
        local isControl = type(native) == "table" and native.Root ~= nil
        local root = isControl and native.Root or native
        local control = isControl and native or {Root = root}
        local record = page.Items[#page.Items]
        control.__type, control.Type = kind, kind
        control.App, control.Window, control.ParentContainer = app, app, page
        control.Tab = page._tab or page
        control.Title, control.Desc = options.Title or kind, options.Desc
        control.ElementFrame, control.Locked, control.Destroyed = root, options.Locked == true, false
        control.Flag, control.Callback = options.Flag, options.Callback
        control.UIElements = control.UIElements or {}
        control.UIElements.Main = root
        control.UIElements.Title = record.TitleLabel
        control._record = record
        control._connections, control._accents = {}, {}
        for i = (startConnections or record.ConnectionStart or #app._connections) + 1, #app._connections do
            table.insert(control._connections, app._connections[i])
        end
        for i = (startAccents or #app._accentBindings) + 1, #app._accentBindings do
            table.insert(control._accents, app._accentBindings[i])
        end
        function control:_connect(signal, callback)
            local connection = signal:Connect(callback)
            table.insert(self._connections, connection)
            return connection
        end
        function control:SetTitle(text)
            if self.Destroyed then return self end
            self.Title, record.Title = tostring(text or ""), tostring(text or "")
            if record.TitleLabel then
                record.TitleLabel.Text = self.Title
                if app._bindText then app:_bindText(record.TitleLabel, "Text", self.Title) end
            end
            return self
        end
        function control:SetDesc(text)
            if self.Destroyed then return self end
            self.Desc, record.Description = tostring(text or ""), tostring(text or "")
            if not record.DescriptionLabel then
                record.DescriptionLabel = label(root, "", 11, MUTED, FONT, {
                    Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -100, 0, 20),
                })
            end
            record.DescriptionLabel.Text = self.Desc
            if record.TitleLabel then
                record.TitleLabel.Position = UDim2.fromOffset(12, 8)
                record.TitleLabel.Size = UDim2.new(1, -100, 0, 23)
            end
            if app._bindText then app:_bindText(record.DescriptionLabel, "Text", self.Desc) end
            return self
        end
        function control:Lock()
            self.Locked = true
            if record.TitleLabel then record.TitleLabel.TextTransparency = 0.45 end
            if self.Opened and self.Close then self:Close() end
            return self
        end
        function control:Unlock()
            self.Locked = false
            if record.TitleLabel then record.TitleLabel.TextTransparency = 0 end
            return self
        end
        function control:Highlight()
            if not self.Destroyed then
                root.BackgroundTransparency = 0.4
                if app._motionEnabled then tween(root, 0.6, {BackgroundTransparency = 0.78}) end
            end
            return self
        end
        function control:SetVisible(visible)
            self._userHidden = visible ~= true
            root.Visible = visible == true
            if page._relayout then page:_relayout() end
            return self
        end
        local nativeDestroy = control.Destroy
        function control:Destroy()
            if self.Destroyed then return end
            self.Destroyed = true
            if self.Close then self:Close() end
            local children = copy(self.Elements or {})
            for _, child in ipairs(children) do child:Destroy() end
            for _, c in ipairs(self._connections) do c:Disconnect(); removeItem(app._connections, c) end
            self._connections = {}
            for _, callback in ipairs(self._accents) do removeItem(app._accentBindings, callback) end
            if nativeDestroy then nativeDestroy(self) end
            root:Destroy()
            app._controlsByRoot[root] = nil
            removeItem(app.AllElements, self)
            removeItem(page.Elements, self)
            removeItem(page.Items, record)
            if self.Flag then
                if app.PendingFlags[self.Flag] == self then app.PendingFlags[self.Flag] = nil end
                if app.CurrentConfig and app.CurrentConfig.Elements[self.Flag] == self then
                    app.CurrentConfig.Elements[self.Flag] = nil
                end
            end
            if page._relayout then page:_relayout() end
        end
        app._controlsByRoot[root] = control
        page.Elements = page.Elements or {}
        table.insert(page.Elements, control)
        table.insert(app.AllElements, control)
        control.Index = #page.Elements
        if options.Flag then
            app.PendingFlags[options.Flag] = control
            if app.CurrentConfig then app.CurrentConfig:Register(options.Flag, control) end
        end
        setmetatable(control, {__index = function(_, key)
            local ok, value = pcall(function() return root[key] end)
            if not ok then return nil end
            if type(value) == "function" then return function(_, ...) return value(root, ...) end end
            return value
        end})
        if app._bindText then
            if record.TitleLabel then app:_bindText(record.TitleLabel, "Text", control.Title) end
            if record.DescriptionLabel then app:_bindText(record.DescriptionLabel, "Text", control.Desc or "") end
        end
        if control.Locked then control:Lock() end
        if app._paintNew then app:_paintNew(root) end
        if page._relayout then page:_relayout() end
        return control
    end
    local function flags(control, value)
        if control.Flag then control.App.Flags[control.Flag] = value end
        if control.__type == "Slider" then control.Value.Default = value else control.Value = value end
    end
    local function finish(page, kind, options, native, connections, accents)
        local control = decorate(page, kind, options, native, connections, accents)
        local set = rawget(control, "Set")
        if set then
            function control:Set(value, fire, ...)
                if self.Destroyed then return self end
                set(self, value, fire, ...)
                flags(self, self:Get())
                return self
            end
            flags(control, control:Get())
        end
        return control
    end
    local function optionsFor(title, callback, extra)
        if type(title) == "table" then return copy(title) end
        local options = copy(extra or {})
        options.Title, options.Callback = title, callback
        return options
    end
    function Page:Button(title, callback, extra)
        local options = optionsFor(title, callback, extra)
        local control
        local count, accents = #self.App._connections, #self.App._accentBindings
        local root = rawPage.Button(self, options.Title or "Button", function()
            if control and interactive(self, control.Root) then safe(control.Callback) end
        end, options)
        control = decorate(self, "Button", options, root, count, accents)
        return control
    end
    function Page:Toggle(title, value, callback, extra)
        local options = type(title) == "table" and copy(title) or optionsFor(title, callback, extra)
        if type(title) ~= "table" then options.Value = value end
        local control
        local count, accents = #self.App._connections, #self.App._accentBindings
        local native = rawPage.Toggle(self, options.Title or "Toggle", options.Value == true, function(v)
            if control then flags(control, v); safe(control.Callback, v) end
        end, options)
        control = finish(self, "Toggle", options, native, count, accents)
        if options.Type == "Checkbox" then
            local track = control.Root:FindFirstChild("ToggleTrack", true)
            if track then
                track.Size = UDim2.fromOffset(26, 24)
                track.Position = UDim2.new(1, -42, 0.5, -12)
                local knob = track:FindFirstChild("ToggleKnob")
                knob.Visible = false
                local check = label(track, "✓", 17, INK, BOLD, {
                    Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 9, Visible = control:Get(),
                })
                local set = control.Set
                function control:Set(nextValue, fire)
                    set(self, nextValue, fire)
                    check.Visible = self:Get()
                    return self
                end
                control:_connect(track:GetPropertyChangedSignal("BackgroundColor3"), function()
                    check.Visible = control:Get()
                end)
            end
        end
        return control
    end
    function Page:Slider(title, minimum, maximum, value, callback, extra)
        local options = type(title) == "table" and copy(title) or optionsFor(title, callback, extra)
        local range = type(title) == "table" and copy(options.Value or {})
            or {Min = minimum, Max = maximum, Default = value}
        range.Min, range.Max = tonumber(range.Min) or 0, tonumber(range.Max) or 100
        range.Default = tonumber(range.Default) or range.Min
        local control
        local count, accents = #self.App._connections, #self.App._accentBindings
        local native = rawPage.Slider(self, options.Title or "Slider", range.Min, range.Max, range.Default, function(v)
            if control then flags(control, v); safe(control.Callback, v) end
        end, options)
        native.Value = range
        control = finish(self, "Slider", options, native, count, accents)
        local setMin, setMax = control.SetMin, control.SetMax
        function control:SetMin(v) self.Value.Min = setMin(self, v); flags(self, self:Get()); return self end
        function control:SetMax(v) self.Value.Max = setMax(self, v); flags(self, self:Get()); return self end
        return control
    end
    function Page:Input(title, value, callback, extra)
        local options = type(title) == "table" and copy(title) or optionsFor(title, callback, extra)
        if type(title) ~= "table" then options.Value = value end
        local control
        local count, accents = #self.App._connections, #self.App._accentBindings
        local native = rawPage.Input(self, options.Title or "Input", options.Value or "", function(v)
            if control then flags(control, v); safe(control.Callback, v) end
        end, options)
        control = finish(self, "Input", options, native, count, accents)
        control.Placeholder = options.Placeholder or "请输入..."
        control.TextBox.ClearTextOnFocus = options.ClearTextOnFocus == true
        if options.Type == "Textarea" then
            control.Root.Size = UDim2.new(1, -5, 0, 176)
            control.TextBox.Position = UDim2.fromOffset(12, 55)
            control.TextBox.Size = UDim2.new(1, -24, 0, 109)
            control.TextBox.MultiLine = true
            control.TextBox.TextWrapped = true
            control.TextBox.TextYAlignment = Enum.TextYAlignment.Top
        end
        local setPlaceholder = control.SetPlaceholder
        function control:SetPlaceholder(text)
            self.Placeholder = tostring(text or "")
            setPlaceholder(self, self.Placeholder)
            return self
        end
        control._naturalHeight = control.Root.Size.Y.Offset
        if self._relayout then self:_relayout() end
        return control
    end
    function Page:Paragraph(title, desc)
        local options = type(title) == "table" and copy(title) or {Title = title, Desc = desc}
        local root = rawPage.Paragraph(self, options.Title or "Paragraph", options.Desc)
        local control = decorate(self, "Paragraph", options, root)
        local y = 68
        for _, spec in ipairs(options.Buttons or {}) do
            local action = button(root, spec.Title or "Button", {
                Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, 30),
                BackgroundColor3 = WHITE, BackgroundTransparency = 0.5,
            })
            corner(action, 8)
            control:_connect(action.MouseButton1Click, function()
                if interactive(self, root) then safe(spec.Callback) end
            end)
            y = y + 36
        end
        root.Size = UDim2.new(1, -5, 0, y)
        control._naturalHeight = y
        if self._relayout then self:_relayout() end
        return control
    end
    function Page:Divider(options)
        return decorate(self, "Divider", options or {}, rawPage.Divider(self))
    end
    function Page:Space(amount)
        local options = type(amount) == "table" and amount or {Columns = amount or 1}
        return decorate(self, "Space", options, rawPage.Space(self, options.Columns))
    end
    function Page:Keybind(title, value, callback, extra)
        local options = type(title) == "table" and copy(title) or optionsFor(title, callback, extra)
        if type(title) ~= "table" then options.Value = value end
        local row = self:_row(options.Title or "Keybind", options.Desc, 58, true)
        local control = decorate(self, "Keybind", options, row)
        control.Value = typeof(options.Value) == "EnumItem" and options.Value.Name or tostring(options.Value or "F")
        control.CanChange, control.Picking = options.CanChange ~= false, false
        local display = label(row, control.Value, 12, INK, FONT, {
            Position = UDim2.new(1, -69, 0.5, -16), Size = UDim2.fromOffset(55, 32),
            TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = WHITE, BackgroundTransparency = 0.6,
        })
        corner(display, 8)
        function control:Set(key)
            self.Value = typeof(key) == "EnumItem" and key.Name or tostring(key or "F")
            display.Text, self.Picking = self.Value, false
            flags(self, self.Value)
            return self
        end
        function control:Get() return self.Value end
        control:_connect(row.MouseButton1Click, function()
            if interactive(self, row) and control.CanChange then control.Picking = true; display.Text = "..." end
        end)
        control:_connect(Input.InputBegan, function(input, processed)
            if processed or not interactive(self, row) then return end
            if control.Picking then
                if input.KeyCode ~= Enum.KeyCode.Unknown then control:Set(input.KeyCode) end
            elseif input.KeyCode.Name == control.Value then safe(control.Callback, control.Value) end
        end)
        control:Set(control.Value)
        return control
    end
    function Page:Dropdown(title, values, value, callback, extra)
        local options = type(title) == "table" and copy(title) or optionsFor(title, callback, extra)
        if type(title) ~= "table" then options.Values, options.Value = values, value end
        local row = self:_row(options.Title or "Dropdown", options.Desc, 58, true)
        local control = decorate(self, "Dropdown", options, row)
        local app = self.App
        control.Values = copy(options.Values or {})
        control.Multi, control.AllowNone = options.Multi == true, options.AllowNone == true
        control.SearchBarEnabled, control.Opened = options.SearchBarEnabled == true, false
        control.Value = options.Value or (control.Multi and {} or control.Values[1])
        control.Tabs, control._lockedValues, control._menuConnections = {}, {}, {}
        local choice = label(row, "", 12, INK, FONT, {
            Position = UDim2.new(1, -124, 0.5, -17), Size = UDim2.fromOffset(110, 34),
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.58,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        corner(choice, 8)
        local function name(item) return tostring(type(item) == "table" and item.Title or item or "") end
        local function same(a, b) return name(a) == name(b) end
        local function selected(item)
            if not control.Multi then return same(control.Value, item) end
            for _, v in ipairs(control.Value) do if same(v, item) then return true end end
            return false
        end
        function control:Display()
            local names = {}
            if self.Multi then
                for _, v in ipairs(self.Value) do table.insert(names, name(v)) end
            elseif self.Value ~= nil then table.insert(names, name(self.Value)) end
            choice.Text = (#names == 0 and "--" or table.concat(names, ", ")) .. " ⌄"
            for _, item in ipairs(self.Tabs) do
                item.Selected = selected(item.Original)
                item.Root.BackgroundTransparency = item.Selected and 0.62 or 1
            end
            return self
        end
        function control:Get() return copy(self.Value) end
        function control:Select(nextValue, fire)
            if self.Multi then
                local result = {}
                for _, candidate in ipairs(type(nextValue) == "table" and nextValue or {}) do
                    for _, item in ipairs(self.Values) do
                        if same(candidate, item) and not (type(item) == "table" and item.Type == "Divider") then
                            local duplicate = false
                            for _, current in ipairs(result) do if same(current, item) then duplicate = true; break end end
                            if not duplicate then table.insert(result, item) end
                            break
                        end
                    end
                end
                self.Value = result
            else
                self.Value = nil
                for _, item in ipairs(self.Values) do
                    if same(nextValue, item) and not (type(item) == "table" and item.Type == "Divider") then
                        self.Value = item; break
                    end
                end
            end
            flags(self, self.Value)
            self:Display()
            if fire ~= false then safe(self.Callback, self:Get()) end
            return self
        end
        control.Set = control.Select
        function control:Close()
            self.Opened = false
            for _, c in ipairs(self._menuConnections) do c:Disconnect() end
            self._menuConnections = {}
            if self.Menu then
                if app._popup == self.Menu then app._popup = nil end
                if app._popupControl == self then app._popupControl = nil end
                self.Menu:Destroy(); self.Menu = nil
            end
            self.Tabs = {}
            return self
        end
        local function bind(signal, fn) table.insert(control._menuConnections, signal:Connect(fn)) end
        function control:Open()
            if self.Opened or not interactive(self.ParentContainer, row) then return self end
            if app._popupControl then app._popupControl:Close()
            elseif app._popup then app._popup:Destroy() end
            local scale = app.AutoScaleObject.Scale
            local offset = row.AbsolutePosition - app.UI.Root.AbsolutePosition
            local rootSize = app.UI.Root.AbsoluteSize
            local width = math.min(clamp(options.MenuWidth or 224, 150, 360), rootSize.X / scale - 20)
            local head = self.SearchBarEnabled and 40 or 0
            local height = math.min(#self.Values * 32 + head + 12, 236, rootSize.Y / scale - 20)
            local x = clamp(offset.X / scale + row.AbsoluteSize.X / scale - width, 8, rootSize.X / scale - width - 8)
            local y = offset.Y / scale + row.AbsoluteSize.Y / scale + 2
            if y + height > rootSize.Y / scale - 8 then y = math.max(8, offset.Y / scale - height - 2) end
            local menu = inst("CanvasGroup", app.UI.Root, {
                Name = "Dropdown", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
                BackgroundColor3 = WHITE, BackgroundTransparency = 0.2,
                BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 25,
            })
            corner(menu, 11); stroke(menu, WHITE, 0.23)
            self.Menu, self.Opened, app._popup, app._popupControl = menu, true, menu, self
            self.UIElements.Menu = menu
            local list = inst("ScrollingFrame", menu, {
                Position = UDim2.fromOffset(4, head + 4), Size = UDim2.new(1, -8, 1, -head - 8),
                CanvasSize = UDim2.fromOffset(0, #self.Values * 32), BackgroundTransparency = 1,
                BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = SILVER,
                ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 26,
            })
            local function filter(query)
                local yOffset = 0
                for _, item in ipairs(control.Tabs) do
                    local show = item.Name:lower():find(query:lower(), 1, true) ~= nil
                    item.Root.Visible = show
                    if show then item.Root.Position = UDim2.fromOffset(0, yOffset); yOffset = yOffset + item.Height end
                end
                list.CanvasSize = UDim2.fromOffset(0, yOffset + 4)
            end
            if self.SearchBarEnabled then
                local search = inst("TextBox", menu, {
                    Position = UDim2.fromOffset(8, 7), Size = UDim2.new(1, -16, 0, 28), Text = "",
                    PlaceholderText = "搜索选项...", TextColor3 = INK, PlaceholderColor3 = MUTED,
                    BackgroundColor3 = WHITE, BackgroundTransparency = 0.45, BorderSizePixel = 0,
                    ClearTextOnFocus = false, Font = FONT, TextSize = 12, ZIndex = 26,
                })
                corner(search, 7)
                bind(search:GetPropertyChangedSignal("Text"), function() filter(search.Text) end)
            end
            for _, item in ipairs(self.Values) do
                local divider = type(item) == "table" and item.Type == "Divider"
                local locked = self._lockedValues[name(item)] or (type(item) == "table" and item.Locked)
                local option = button(list, divider and "" or name(item), {
                    Size = UDim2.new(1, -5, 0, divider and 8 or 31),
                    BackgroundColor3 = SILVER, BackgroundTransparency = 1, TextSize = 12,
                    TextTransparency = locked and 0.55 or 0, ZIndex = 27,
                })
                corner(option, 6)
                if divider then
                    inst("Frame", option, {Size = UDim2.new(1, -8, 0, 1), Position = UDim2.fromOffset(4, 3),
                        BackgroundColor3 = SILVER, BackgroundTransparency = 0.5, BorderSizePixel = 0})
                end
                local record = {Name = name(item), Original = item, Root = option, Locked = locked, Height = divider and 8 or 32}
                table.insert(self.Tabs, record)
                bind(option.MouseButton1Click, function()
                    if record.Locked or divider then return end
                    if control.Multi then
                        local nextValues, found = {}, false
                        for _, v in ipairs(control.Value) do
                            if same(v, item) then found = true else table.insert(nextValues, v) end
                        end
                        if not found then table.insert(nextValues, item) end
                        if #nextValues > 0 or control.AllowNone then control:Select(nextValues) end
                    else
                        control:Select(item); control:Close()
                    end
                    if not control.Callback and type(item) == "table" then safe(item.Callback) end
                end)
            end
            filter(""); self:Display()
            if app._paintNew then app:_paintNew(menu) end
            return self
        end
        function control:Refresh(nextValues)
            local opened = self.Opened
            self:Close(); self.Values = copy(nextValues or {})
            self:Select(self.Value, false)
            if opened then self:Open() end
            return self
        end
        function control:LockValues(names)
            self._lockedValues = {}
            for _, n in ipairs(names or {}) do self._lockedValues[name(n)] = true end
            if self.Opened then self:Close(); self:Open() end
            return self
        end
        control.DropdownMenu = control
        control:_connect(row.MouseButton1Click, function()
            if control.Opened then control:Close() else control:Open() end
        end)
        control:Select(control.Value, false)
        return control
    end
    function Page:LockAll()
        for _, control in ipairs(self.App.AllElements) do
            if descend(control.ParentContainer, self) then control:Lock() end
        end
        return self
    end
    function Page:UnlockAll()
        self.Locked = false
        for _, control in ipairs(self.App.AllElements) do
            if descend(control.ParentContainer, self) then control:Unlock() end
        end
        return self
    end
    function Page:GetLocked()
        local result = {}
        for _, control in ipairs(self.App.AllElements) do
            if control.Locked and descend(control.ParentContainer, self) then table.insert(result, control) end
        end
        return result
    end
    function Page:GetUnlocked()
        local result = {}
        for _, control in ipairs(self.App.AllElements) do
            if not control.Locked and descend(control.ParentContainer, self) then table.insert(result, control) end
        end
        return result
    end
    function Page:ScrollToTheElement(index)
        local control = type(index) == "table" and index or (self.Elements or {})[index]
        if not control or control.Destroyed then return self end
        local page = self._tab or self
        local scale = self.App.AutoScaleObject.Scale
        local y = page.Scroll.CanvasPosition.Y + (control.Root.AbsolutePosition.Y - page.Scroll.AbsolutePosition.Y) / scale
        page.Scroll.CanvasPosition = Vector2.new(0, math.max(0, y - 8))
        control:Highlight()
        return self
    end
    function Page:UpdateAllElementShapes()
        for _, control in ipairs(self.Elements or {}) do
            local round = control.Root:FindFirstChildOfClass("UICorner")
            if round then round.CornerRadius = UDim.new(0, self.App.ElementsRadius or 9) end
        end
        return self
    end
    -- Used by additional controls/containers below, without depending on original WindUI code.
    Page._decorate = decorate
end

-- Composite controls share the same scrolling, lock and cleanup rules.
do
    local function container(page, options, group)
        local kind = group and "Group" or "Section"
        local header = group and 0 or 42
        local root = page:_row(options.Title or kind, nil, header, not group)
        root.ClipsDescendants = true
        if not options.Box or group then root.BackgroundTransparency = 1 end
        local object = Page._decorate(page, kind, options, root)
        local previousIndex = getmetatable(object).__index
        setmetatable(object, {__index = function(self, key) return Page[key] or previousIndex(self, key) end})
        object.ParentContainer, object._tab = page, page._tab or page
        object.Items, object.Elements, object.Opened = {}, {}, options.Opened == true or group
        object._naturalHeight = header
        local body = inst("Frame", root, {
            Name = "Children", Position = UDim2.fromOffset(0, header),
            Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
            Visible = object.Opened, BorderSizePixel = 0,
        })
        object.Scroll, object.UIElements.Container = body, body
        local layout = inst("UIListLayout", body, {
            FillDirection = group and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7),
        })
        object.Layout = layout
        local arrow
        if not group then
            arrow = label(root, "⌄", 15, MUTED, FONT, {
                Position = UDim2.new(1, -28, 0, 0), Size = UDim2.fromOffset(20, header), Visible = false,
            })
            object._record.TitleLabel.TextSize = options.TextSize or 14
            object._record.TitleLabel.TextTransparency = options.TextTransparency or 0.05
            object._record.TitleLabel.Size = UDim2.new(1, -40, 0, header)
            if options.TextXAlignment then object._record.TitleLabel.TextXAlignment = Enum.TextXAlignment[options.TextXAlignment] end
        else
            object._record.TitleLabel.Visible = false
        end
        function object:_relayout()
            if self.Destroyed then return end
            local visible, height = {}, 0
            for _, child in ipairs(self.Elements) do
                if not child.Destroyed and child.Root.Visible then table.insert(visible, child) end
            end
            local horizontal = group and #visible > 0 and body.AbsoluteSize.X / math.max(1, #visible) >= 155
            layout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
            for _, child in ipairs(visible) do
                local h = child._naturalHeight or child.Root.Size.Y.Offset
                child._naturalHeight = h
                if horizontal then
                    child.Root.Size = UDim2.new(1 / #visible, -7 * (#visible - 1) / #visible, 0, h)
                    height = math.max(height, h)
                else
                    child.Root.Size = UDim2.new(1, -4, 0, h)
                    height = height + h + 7
                end
            end
            if not horizontal then height = math.max(0, height - 7) end
            body.Size = UDim2.new(1, 0, 0, height)
            body.Visible = self.Opened
            self.Expandable = #visible > 0
            if arrow then arrow.Visible = self.Expandable; arrow.Rotation = self.Opened and 180 or 0 end
            local target = header + (self.Opened and height or 0)
            self._naturalHeight = target
            root.Size = UDim2.new(root.Size.X.Scale, root.Size.X.Offset, 0, target)
            if page._relayout then page:_relayout() end
        end
        function object:Open() self.Opened = true; self:_relayout(); return self end
        function object:Close() self.Opened = false; self:_relayout(); return self end
        function object:SetIcon(icon)
            self.Icon = icon
            if not self.IconLabel then
                self.IconLabel = label(root, "", 16, MUTED, FONT, {
                    Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(24, header),
                })
            end
            WindUI:_setIcon(self.IconLabel, icon)
            self._record.TitleLabel.Position = UDim2.fromOffset(icon and 38 or 12, 0)
            return self
        end
        if options.Icon then object:SetIcon(options.Icon) end
        if not group then object:_connect(root.MouseButton1Click, function()
            if interactive(page, root) then if object.Opened then object:Close() else object:Open() end end
        end) end
        object:_connect(body:GetPropertyChangedSignal("AbsoluteSize"), function() object:_relayout() end)
        object:_relayout()
        return object
    end
    function Page:Section(options)
        if type(options) ~= "table" then options = {Title = tostring(options or "Section")} end
        return container(self, options, false)
    end
    function Page:Group(options) return container(self, type(options) == "table" and options or {}, true) end
    function Page:Image(options)
        options = type(options) == "table" and options or {Image = options}
        local row = self:_row("", nil, 180)
        local control = Page._decorate(self, "Image", options, row)
        control._record.TitleLabel.Visible = false
        row.BackgroundTransparency = 1
        local clip = inst("CanvasGroup", row, {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            ClipsDescendants = true, BorderSizePixel = 0,
        })
        corner(clip, options.Radius or self.App.ElementsRadius or 9)
        local image = inst("ImageLabel", clip, {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Image = "", ScaleType = Enum.ScaleType.Fit,
        })
        control.Image, control.UIElements.Image = options.Image or "", image
        function control:SetImage(source)
            local asset, err = WindUI:_resolveImage(source)
            if not asset then safe(options.OnError, err); return false, err end
            self.Image, image.Image = source, asset
            return self
        end
        control:SetImage(options.Image or "")
        local ratio = tonumber(options.AspectRatio)
        if not ratio and type(options.AspectRatio) == "string" then
            local w, h = options.AspectRatio:match("(%d+):(%d+)")
            ratio = w and tonumber(w) / math.max(1, tonumber(h)) or nil
        end
        ratio = clamp(ratio or 16 / 9, 0.1, 10)
        local function resize()
            local width = row.AbsoluteSize.X / self.App.AutoScaleObject.Scale
            local height = math.max(30, width / ratio)
            if math.abs(row.Size.Y.Offset - height) > 0.5 then
                row.Size = UDim2.new(row.Size.X.Scale, row.Size.X.Offset, 0, height)
                control._naturalHeight = height
                if self._relayout then self:_relayout() end
            end
        end
        control:_connect(row:GetPropertyChangedSignal("AbsoluteSize"), resize)
        resize()
        return control
    end
    function Page:Code(options)
        options = type(options) == "table" and options or {Code = options}
        local row = self:_row(options.Title or "Code", nil, options.Height or 164)
        local control = Page._decorate(self, "Code", options, row)
        control._record.TitleLabel.Size = UDim2.new(1, -70, 0, 34)
        local code = inst("TextBox", row, {
            Name = "Source", Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 1, -49),
            Text = tostring(options.Code or ""), TextColor3 = INK, TextSize = 12, Font = Enum.Font.Code,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            TextEditable = false, MultiLine = true, ClearTextOnFocus = false, TextWrapped = true,
            BackgroundTransparency = 1,
        })
        control.Code, control.UIElements.Code = tostring(options.Code or ""), code
        function control:SetCode(text) self.Code = tostring(text or ""); code.Text = self.Code; return self end
        local copyButton = button(row, "复制", {
            Position = UDim2.new(1, -55, 0, 5), Size = UDim2.fromOffset(44, 27), TextSize = 11,
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.5,
        })
        corner(copyButton, 7)
        control:_connect(copyButton.MouseButton1Click, function()
            if not interactive(self, row) then return end
            local copier = setclipboard or toclipboard
            if type(copier) ~= "function" then
                self.App:Notify("无法直接复制", "当前环境未提供剪贴板；可以选择代码手动复制。", 4)
                return
            end
            local ok, err = pcall(copier, control.Code)
            if ok then safe(options.OnCopy) else self.App:Notify("复制失败", tostring(err), 4) end
        end)
        return control
    end
    function Page:Colorpicker(options, defaultColor, callback)
        options = type(options) == "table" and options or {Title = options, Default = defaultColor, Callback = callback}
        local row = self:_row(options.Title or "Colorpicker", options.Desc, 58, true)
        local control = Page._decorate(self, "Colorpicker", options, row)
        local app = self.App
        control.Default = color(options.Default, WHITE)
        control.Transparency = options.Transparency ~= nil and clamp(options.Transparency, 0, 1) or nil
        local swatch = inst("Frame", row, {
            Name = "ColorSwatch", Position = UDim2.new(1, -47, 0.5, -13), Size = UDim2.fromOffset(26, 26),
            BackgroundColor3 = control.Default, BackgroundTransparency = control.Transparency or 0,
            BorderSizePixel = 0, ZIndex = 7,
        })
        corner(swatch, 8); stroke(swatch, SILVER, 0.5)
        app._fixedColors = app._fixedColors or {}; app._fixedColors[swatch] = true
        control.UIElements.Colorpicker = swatch
        function control:Get() return self.Default end
        function control:Update(shade, alpha)
            self.Default = color(shade, self.Default)
            if alpha ~= nil then self.Transparency = clamp(alpha, 0, 1) end
            swatch.BackgroundColor3, swatch.BackgroundTransparency = self.Default, self.Transparency or 0
            if self.Flag then app.Flags[self.Flag] = self.Default end
            if self._refreshColor then self._refreshColor() end
            return self
        end
        control.Set = control.Update
        function control:Close()
            if self._colorConnections then for _, c in ipairs(self._colorConnections) do c:Disconnect() end end
            self._colorConnections, self._refreshColor = {}, nil
            if self.Menu then
                if app._popup == self.Menu then app._popup = nil end
                if app._popupControl == self then app._popupControl = nil end
                self.Menu:Destroy(); self.Menu = nil
            end
            self.Opened = false
            return self
        end
        function control:Open()
            if not interactive(self.ParentContainer, row) then return self end
            if app._popupControl then app._popupControl:Close() elseif app._popup then app._popup:Destroy() end
            local menu = inst("CanvasGroup", app.UI.Root, {
                Name = "Colorpicker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(304, self.Transparency ~= nil and 304 or 272),
                BackgroundColor3 = WHITE, BackgroundTransparency = 0.12,
                BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 25,
            })
            corner(menu, 14); stroke(menu, WHITE, 0.2)
            self.Menu, self.Opened, app._popup, app._popupControl = menu, true, menu, self
            self._colorConnections = {}
            local function bind(signal, fn) table.insert(self._colorConnections, signal:Connect(fn)) end
            label(menu, self.Title, 13, INK, BOLD, {Position = UDim2.fromOffset(14, 5), Size = UDim2.fromOffset(238, 28), ZIndex = 26})
            local close = button(menu, "×", {Position = UDim2.new(1, -32, 0, 3), Size = UDim2.fromOffset(27, 30), ZIndex = 26})
            bind(close.MouseButton1Click, function() self:Close() end)
            local hue, saturation, brightness = self.Default:ToHSV()
            local map = button(menu, "", {
                Position = UDim2.fromOffset(14, 39), Size = UDim2.fromOffset(241, 144),
                BackgroundColor3 = Color3.fromHSV(hue, 1, 1), BackgroundTransparency = 0, ZIndex = 26,
            })
            corner(map, 8)
            local white = inst("Frame", map, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 27})
            corner(white, 8); inst("UIGradient", white, {Transparency = NumberSequence.new(0, 1)})
            local black = inst("Frame", map, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 28})
            corner(black, 8); inst("UIGradient", black, {Rotation = 90, Transparency = NumberSequence.new(1, 0)})
            local cursor = inst("Frame", map, {Size = UDim2.fromOffset(9, 9), AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 29})
            corner(cursor, 5); stroke(cursor, WHITE, 0, 2)
            local hueBar = button(menu, "", {Position = UDim2.fromOffset(268, 39), Size = UDim2.fromOffset(19, 144),
                BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 26})
            corner(hueBar, 8)
            local stops = {}
            for i = 0, 6 do stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)) end
            inst("UIGradient", hueBar, {Rotation = 90, Color = ColorSequence.new(stops)})
            local hex = inst("TextBox", menu, {Position = UDim2.fromOffset(14, 194), Size = UDim2.fromOffset(128, 30),
                BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, BorderSizePixel = 0,
                Text = "", TextColor3 = INK, TextSize = 12, Font = FONT, ClearTextOnFocus = false, ZIndex = 26})
            corner(hex, 8)
            local rgb = label(menu, "", 11, MUTED, FONT, {Position = UDim2.fromOffset(150, 194), Size = UDim2.fromOffset(139, 30), ZIndex = 26})
            local done = button(menu, "完成", {Position = UDim2.new(1, -91, 1, -37), Size = UDim2.fromOffset(76, 28),
                BackgroundColor3 = WHITE, BackgroundTransparency = 0.2, ZIndex = 26})
            corner(done, 8); bind(done.MouseButton1Click, function() self:Close() end)
            local alphaBar, alphaText
            if self.Transparency ~= nil then
                alphaBar = button(menu, "", {Position = UDim2.fromOffset(14, 236), Size = UDim2.fromOffset(195, 9),
                    BackgroundColor3 = SILVER, BackgroundTransparency = 0.2, ZIndex = 26})
                corner(alphaBar, 5)
                alphaText = label(menu, "", 11, INK, FONT, {Position = UDim2.fromOffset(218, 228), Size = UDim2.fromOffset(70, 26), ZIndex = 26})
            end
            local function refresh()
                local h, s, v = self.Default:ToHSV()
                if v > 0 and s > 0 then hue = h end
                saturation, brightness = s, v
                map.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
                cursor.Position = UDim2.fromScale(saturation, 1 - brightness)
                hex.Text = "#" .. self.Default:ToHex()
                rgb.Text = string.format("%d, %d, %d", math.floor(self.Default.R * 255 + 0.5), math.floor(self.Default.G * 255 + 0.5), math.floor(self.Default.B * 255 + 0.5))
                if alphaText then alphaText.Text = string.format("%.0f%%", (self.Transparency or 0) * 100) end
            end
            self._refreshColor = refresh
            local function change(shade, alpha)
                self:Update(shade, alpha)
                safe(self.Callback, self.Default, self.Transparency)
            end
            bind(hex.FocusLost, function()
                local ok, result = pcall(Color3.fromHex, hex.Text:gsub("#", ""))
                if ok then change(result) else refresh() end
            end)
            local dragging
            local function adjust(input)
                if not dragging then return end
                local p, size = dragging.AbsolutePosition, dragging.AbsoluteSize
                local x = clamp((input.Position.X - p.X) / math.max(1, size.X), 0, 1)
                local y = clamp((input.Position.Y - p.Y) / math.max(1, size.Y), 0, 1)
                if dragging == map then saturation, brightness = x, 1 - y
                elseif dragging == hueBar then hue = y
                else change(self.Default, x); return end
                change(Color3.fromHSV(hue, saturation, brightness))
            end
            for _, target in ipairs(alphaBar and {map, hueBar, alphaBar} or {map, hueBar}) do
                bind(target.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = target; adjust(input)
                    end
                end)
            end
            bind(Input.InputChanged, function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then adjust(input) end
            end)
            bind(Input.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = nil end
            end)
            refresh()
            return self
        end
        control:_connect(row.MouseButton1Click, function() control:Open() end)
        control:Update(control.Default, control.Transparency)
        return control
    end
end

-- Theme, localization and configuration APIs.
do
    local function equalColor(a, b)
        return typeof(a) == "Color3" and typeof(b) == "Color3"
            and math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.002
    end
    WindUI.Themes = {
        WhiteGlass = {Name = "WhiteGlass", Accent = WHITE, Background = WHITE, Dialog = PEARL,
            Text = INK, Placeholder = MUTED, Button = WHITE, Icon = MUTED, Outline = WHITE,
            Toggle = WHITE, Slider = WHITE, Checkbox = WHITE},
        Light = {Name = "Light", Accent = WHITE, Background = Color3.fromRGB(234, 234, 238),
            Dialog = PEARL, Text = INK, Placeholder = MUTED, Button = WHITE, Icon = MUTED, Outline = WHITE},
        Dark = {Name = "Dark", Accent = Color3.fromRGB(40, 40, 45), Background = Color3.fromRGB(22, 22, 27),
            Dialog = Color3.fromRGB(35, 35, 41), Text = WHITE, Placeholder = Color3.fromRGB(170, 170, 180),
            Button = Color3.fromRGB(70, 70, 80), Icon = Color3.fromRGB(190, 190, 200), Outline = SILVER,
            Toggle = Color3.fromRGB(103, 191, 151), Slider = Color3.fromRGB(120, 170, 240)},
    }
    local seeds = {
        Rose = {218, 95, 150}, Plant = {77, 168, 112}, Red = {223, 88, 97},
        Indigo = {128, 126, 233}, Sky = {90, 182, 232}, Violet = {167, 123, 231},
        Amber = {221, 168, 82}, Emerald = {76, 186, 149}, Midnight = {122, 150, 203},
        Crimson = {199, 82, 113}, Monokai = {163, 196, 99}, MonokaiPro = {169, 220, 118},
        CottonCandy = {239, 156, 203}, Rainbow = {148, 135, 225},
    }
    for name, rgb in pairs(seeds) do
        local accent = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
        WindUI.Themes[name] = {Name = name, Accent = accent, Slider = accent, Toggle = accent,
            Background = Color3.fromRGB(rgb[1] * 0.13, rgb[2] * 0.13, rgb[3] * 0.13),
            Dialog = Color3.fromRGB(rgb[1] * 0.2, rgb[2] * 0.2, rgb[3] * 0.2),
            Text = WHITE, Placeholder = Color3.fromRGB(185, 185, 195),
            Icon = accent, Button = accent, Outline = accent}
    end
    WindUI.Theme, WindUI._windows, WindUI._themeCallbacks = WindUI.Themes.WhiteGlass, {}, {}
    function WindUI:AddTheme(theme)
        assert(type(theme) == "table" and type(theme.Name) == "string", "AddTheme needs a Name")
        self.Themes[theme.Name] = theme
        return theme
    end
    function WindUI:GetThemes() return self.Themes end
    function WindUI:GetCurrentTheme() return self.Theme.Name end
    function WindUI:OnThemeChange(callback)
        assert(type(callback) == "function", "OnThemeChange needs a callback")
        table.insert(self._themeCallbacks, callback)
        return self
    end
    function App:_paintNew(root)
        local theme = self._themeData or WindUI.Theme
        self._themeBindings = self._themeBindings or setmetatable({}, {__mode = "k"})
        local objects = root:GetDescendants(); table.insert(objects, 1, root)
        for _, object in ipairs(objects) do
            if not (self._fixedColors and self._fixedColors[object]) then
                local roles = self._themeBindings[object]
                if not roles then
                    roles = {}
                    if object:IsA("TextLabel") or object:IsA("TextBox") or object:IsA("TextButton") then
                        local text = object.TextColor3
                        if equalColor(text, INK) then roles.TextColor3 = "Text"
                        elseif equalColor(text, MUTED) then roles.TextColor3 = "Placeholder" end
                        if object:IsA("TextBox") then roles.PlaceholderColor3 = "Placeholder" end
                    end
                    if object:IsA("Frame") or object:IsA("CanvasGroup") or object:IsA("TextBox") or object:IsA("TextButton") then
                        if equalColor(object.BackgroundColor3, WHITE) then roles.BackgroundColor3 = "Background"
                        elseif equalColor(object.BackgroundColor3, PEARL) then roles.BackgroundColor3 = "Dialog" end
                    elseif object:IsA("UIStroke") and equalColor(object.Color, WHITE) then roles.Color = "Outline" end
                    self._themeBindings[object] = roles
                end
                for property, role in pairs(roles) do
                    object[property] = color(theme[role], WindUI.Themes.WhiteGlass[role])
                end
            end
        end
    end
    function App:SetTheme(name)
        local theme = type(name) == "table" and name or WindUI.Themes[name]
        if not theme then return nil, "Unknown theme: " .. tostring(name) end
        self._theme, self._themeData = theme.Name, theme
        self:_paintNew(self.UI.Root)
        self:_paintNew(self.Compact)
        self.UI.Surface.BackgroundColor3 = color(theme.Background, WHITE)
        self.UI.Gradient.Color = ColorSequence.new(WHITE)
        self.UI.Title.TextColor3, self.UI.Author.TextColor3 = color(theme.Text, INK), color(theme.Placeholder, MUTED)
        self.Island.Title.TextColor3 = color(theme.Text, INK)
        self:SetAccentColor(theme.Toggle or theme.Slider or theme.Accent or WHITE)
        WindUI.Theme = theme
        return theme
    end
    function WindUI:SetTheme(name)
        local theme = self.Themes[name]
        if not theme then return nil end
        self.Theme = theme
        for _, window in ipairs(self._windows) do if not window._destroyed then window:SetTheme(name) end end
        for _, callback in ipairs(self._themeCallbacks) do safe(callback, name) end
        return theme
    end
    function WindUI:SetFont(font)
        self._font = font
        for _, window in ipairs(self._windows) do if not window._destroyed then window:SetUIFont(font) end end
        return self
    end
    function WindUI:Localization(options)
        options = type(options) == "table" and options or {}
        self._localization = {Enabled = options.Enabled == true, Prefix = options.Prefix or "loc:",
            Translations = options.Translations or {}, DefaultLanguage = options.DefaultLanguage or "en"}
        self._language = options.DefaultLanguage or "en"
        for _, window in ipairs(self._windows) do if not window._destroyed then window:_updateLanguage() end end
        return self._localization
    end
    function WindUI:_translate(text)
        text = tostring(text or "")
        local loc = self._localization
        if not loc or not loc.Enabled or text:sub(1, #loc.Prefix) ~= loc.Prefix then return text end
        local key = text:sub(#loc.Prefix + 1)
        local language = loc.Translations[self._language] or {}
        local fallback = loc.Translations[loc.DefaultLanguage] or {}
        return tostring(language[key] or fallback[key] or ("[" .. key .. "]"))
    end
    function App:_bindText(object, property, source)
        self._languageBindings = self._languageBindings or setmetatable({}, {__mode = "k"})
        self._languageBindings[object] = self._languageBindings[object] or {}
        self._languageBindings[object][property] = tostring(source or "")
        object[property] = WindUI:_translate(source)
    end
    function App:_updateLanguage()
        for object, properties in pairs(self._languageBindings or {}) do
            if object.Parent then for property, source in pairs(properties) do object[property] = WindUI:_translate(source) end end
        end
    end
    function WindUI:SetLanguage(language)
        self._language = tostring(language)
        if not self._localization then return false end
        for _, window in ipairs(self._windows) do if not window._destroyed then window:_updateLanguage() end end
        return true
    end
    function WindUI:Gradient(stops, extra)
        local colors, alphas = {}, {}
        for key, value in pairs(stops) do
            local t = tonumber(key)
            if t then
                table.insert(colors, ColorSequenceKeypoint.new(clamp(t / 100, 0, 1), value.Color))
                table.insert(alphas, NumberSequenceKeypoint.new(clamp(t / 100, 0, 1), clamp(value.Transparency or 0, 0, 1)))
            end
        end
        table.sort(colors, function(a, b) return a.Time < b.Time end)
        table.sort(alphas, function(a, b) return a.Time < b.Time end)
        assert(#colors >= 2 and colors[1].Time == 0 and colors[#colors].Time == 1, "Gradient needs stops at 0 and 100")
        local result = {Color = ColorSequence.new(colors), Transparency = NumberSequence.new(alphas)}
        for key, value in pairs(extra or {}) do result[key] = value end
        return result
    end

    local HttpService = game:GetService("HttpService")
    local function segment(name)
        name = tostring(name or "Default"):gsub('[%z\1-\31\\/:*?"<>|]', "_")
        name = name:gsub("^%.+", "_"):gsub("%.+$", "_")
        assert(name ~= "", "Empty config name")
        return name
    end
    local function ensureFolders(path)
        if type(makefolder) ~= "function" then return end
        local current = ""
        for part in path:gmatch("[^/]+") do
            current = current == "" and part or current .. "/" .. part
            if not isfolder or not isfolder(current) then makefolder(current) end
        end
    end
    local function plain(value, visited)
        visited = visited or {}
        if typeof(value) == "Color3" then return {__color = value:ToHex()} end
        if typeof(value) == "EnumItem" then return value.Name end
        if type(value) == "table" then
            assert(not visited[value], "Config data cannot contain circular tables")
            visited[value] = true
            local result = {}
            for key, v in pairs(value) do
                if type(v) ~= "function" and typeof(v) ~= "Instance" then result[key] = plain(v, visited) end
            end
            visited[value] = nil
            return result
        end
        return value
    end
    local function configManager(app, folder)
        local manager = {Folder = folder, Path = "WindUI/" .. segment(folder) .. "/config/", Configs = {}, Parser = {}, _memory = {}}
        for _, kind in ipairs({"Toggle", "Input", "Keybind", "Slider", "Dropdown", "Colorpicker"}) do
            manager.Parser[kind] = {
                Save = function(control)
                    local v = control:Get()
                    if kind == "Colorpicker" then
                        return {__type = kind, value = v:ToHex(), transparency = control.Transparency}
                    end
                    if kind == "Dropdown" then
                        if control.Multi then
                            local result = {}
                            for _, item in ipairs(v) do result[#result + 1] = type(item) == "table" and item.Title or item end
                            v = result
                        elseif type(v) == "table" then v = v.Title end
                    end
                    return {__type = kind, value = plain(v)}
                end,
                Load = function(control, data)
                    if kind == "Colorpicker" then control:Update(Color3.fromHex(data.value), data.transparency)
                    elseif kind == "Dropdown" then control:Select(data.value)
                    else control:Set(data.value) end
                end,
            }
        end
        function manager:Init(window) return window and window.ConfigManager or self end
        function manager:_read(name)
            local path = self.Path .. segment(name) .. ".json"
            if type(readfile) == "function" and (not isfile or isfile(path)) then
                local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
                if ok and type(data) == "table" then return data end
                if not ok then return nil, tostring(data) end
            end
            return self._memory[name]
        end
        function manager:CreateConfig(name, autoLoad)
            name = segment(name)
            if self.Configs[name] then
                if autoLoad ~= nil then self.Configs[name].AutoLoad = autoLoad == true end
                self.Configs[name]:SetAsCurrent()
                return self.Configs[name]
            end
            local config = {Name = name, Path = self.Path .. name .. ".json", Elements = {},
                CustomData = {}, AutoLoad = autoLoad == true, Version = 1.2,
                Storage = type(writefile) == "function" and "File" or "Memory"}
            function config:SetAsCurrent() app:SetCurrentConfig(self); return self end
            function config:Register(flag, control)
                self.Elements[tostring(flag)] = control
                if self._pending and self._pending[tostring(flag)] then
                    task.defer(function()
                        if app._destroyed or control.Destroyed then return end
                        local data = self._pending[tostring(flag)]
                        if data and manager.Parser[data.__type] then
                            local ok, err = pcall(manager.Parser[data.__type].Load, control, data)
                            if ok then self._pending[tostring(flag)] = nil else warn("[WhiteGlass Config] " .. tostring(err)) end
                        end
                    end)
                end
                return self
            end
            function config:Set(key, value) self.CustomData[key] = value; return self end
            function config:Get(key) return self.CustomData[key] end
            function config:SetAutoLoad(enabled) self.AutoLoad = enabled == true; return self end
            function config:Save()
                for flag, control in pairs(app.PendingFlags) do self:Register(flag, control) end
                local data = {__version = self.Version, __elements = {}, __autoload = self.AutoLoad, __custom = plain(self.CustomData)}
                for flag, control in pairs(self.Elements) do
                    if not control.Destroyed and manager.Parser[control.__type] then
                        data.__elements[flag] = manager.Parser[control.__type].Save(control)
                    end
                end
                if type(writefile) == "function" then
                    local ok, err = pcall(function()
                        ensureFolders(manager.Path)
                        writefile(self.Path, HttpService:JSONEncode(data))
                    end)
                    if not ok then return false, tostring(err) end
                end
                manager._memory[name] = data
                return data, self.Storage
            end
            function config:Load()
                local data, err = manager:_read(name)
                if not data then return false, err or "Config does not exist" end
                local elements = data.__elements or data
                self.CustomData = data.__custom or {}
                self.AutoLoad = data.__autoload == true
                self._pending = {}
                for flag, entry in pairs(elements) do
                    if type(entry) == "table" and entry.__type then self._pending[flag] = entry end
                end
                self:SetAsCurrent()
                for flag, control in pairs(app.PendingFlags) do self:Register(flag, control) end
                for flag, control in pairs(self.Elements) do
                    local entry = self._pending[flag]
                    if entry and manager.Parser[entry.__type] and not control.Destroyed then
                        local ok, failure = pcall(manager.Parser[entry.__type].Load, control, entry)
                        if not ok then return false, "Config field " .. flag .. ": " .. tostring(failure) end
                        self._pending[flag] = nil
                    end
                end
                return self.CustomData
            end
            function config:Delete() return manager:DeleteConfig(name) end
            function config:GetData() return {elements = self.Elements, custom = self.CustomData, autoload = self.AutoLoad} end
            local stored = self:_read(name)
            if stored and autoLoad == nil then config.AutoLoad = stored.__autoload == true end
            self.Configs[name] = config
            config:SetAsCurrent()
            if stored and config.AutoLoad then
                task.defer(function()
                    if app._destroyed or self.Configs[name] ~= config then return end
                    local ok, err = config:Load()
                    if ok == false then warn("[WhiteGlass Config] AutoLoad: " .. tostring(err)) end
                end)
            end
            return config
        end
        manager.Config = manager.CreateConfig
        function manager:GetConfig(name) return self.Configs[name] end
        function manager:AllConfigs()
            local found, result = {}, {}
            for name in pairs(self.Configs) do found[name] = true end
            for name in pairs(self._memory) do found[name] = true end
            if type(listfiles) == "function" and (not isfolder or isfolder(self.Path)) then
                local ok, files = pcall(listfiles, self.Path)
                if ok then for _, path in ipairs(files) do
                    local name = path:match("([^/\\]+)%.json$"); if name then found[name] = true end
                end end
            end
            for name in pairs(found) do result[#result + 1] = name end
            table.sort(result)
            return result
        end
        function manager:GetAutoLoadConfigs()
            local result = {}
            for _, name in ipairs(self:AllConfigs()) do
                local current, data = self.Configs[name], self:_read(name)
                if (current and current.AutoLoad) or (not current and data and data.__autoload) then result[#result + 1] = name end
            end
            return result
        end
        function manager:DeleteConfig(name)
            name = segment(name)
            local path = self.Path .. name .. ".json"
            if type(isfile) == "function" and isfile(path) then
                if type(delfile) ~= "function" then return false, "delfile is unavailable" end
                local ok, err = pcall(delfile, path); if not ok then return false, tostring(err) end
            end
            self._memory[name], self.Configs[name] = nil, nil
            if app.CurrentConfig and app.CurrentConfig.Name == name then app.CurrentConfig = nil end
            return true
        end
        return manager
    end
    function App:SetCurrentConfig(config)
        self.CurrentConfig = config
        if config then for flag, control in pairs(self.PendingFlags) do config:Register(flag, control) end end
        return self
    end
    App._createConfigManager = configManager
end

-- Window, tab, notification and dialog APIs.
do
    local basePage, baseSelect = App.Page, Page.Select
    function App:Page(options)
        options = type(options) == "table" and options or {Title = tostring(options or "页面")}
        local page = basePage(self, options)
        page.__type, page.Index, page.Elements = "Tab", #self.Pages, {}
        page.Locked, page.Selected, page.Icon, page.Desc = options.Locked == true, self.SelectedPage == page, options.Icon, options.Desc
        self._navOrder = (self._navOrder or 0) + 100
        page.Tab.LayoutOrder = self._navOrder
        page.UIElements = {Main = page.Tab, ContainerFrame = page.Scroll}
        if self.ScrollBarEnabled == false then page.Scroll.ScrollBarThickness = 0 end
        if self.TabModule then self.TabModule.Containers[page.Index] = page.Scroll end
        page.ContainerFrame, page.ParentContainer, page._tab = page.Scroll, nil, page
        page.Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        WindUI:_setIcon(page.TabIcon, options.Icon, options.IconThemed and self._accent or WHITE)
        self:_bindText(page.TabText, "Text", page.Title)
        self:_paintNew(page.Tab)
        return page
    end
    App.Tab = App.Page
    function Page:Select()
        if self.Locked or self.Destroyed then return self end
        if self.App._popupControl then self.App._popupControl:Close() end
        local changed = self.App.SelectedPage ~= self
        baseSelect(self)
        self.App.CurrentTab = self.Index or 1
        for _, page in ipairs(self.App.Pages) do
            page.Selected = page == self
            local theme = self.App._themeData or WindUI.Theme
            page.TabText.TextColor3 = color(theme.Text, INK)
            page.TabIcon.TextColor3 = page.Selected and color(theme.Text, INK) or color(theme.Icon, MUTED)
        end
        if self.App.TabModule then
            self.App.TabModule.SelectedTab = self.Index
            if changed then safe(self.App.TabModule.OnChangeFunc, self.Index) end
        end
        return self
    end
    function App:SelectTab(index)
        local page = type(index) == "table" and index or self.Pages[index]
        if page then return page:Select() end
        return nil, "Tab does not exist"
    end
    function App:Section(options)
        options = type(options) == "table" and options or {Title = tostring(options or "Section")}
        self._navOrder = (self._navOrder or 0) + 100
        local header = button(self.UI.NavScroll, options.Title or "Section", {
            Size = UDim2.new(1, -4, 0, 34), TextSize = 11, TextColor3 = MUTED,
            TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = self._navOrder,
        })
        inst("UIPadding", header, {PaddingLeft = UDim.new(0, 12)})
        local section = {Title = options.Title or "Section", Icon = options.Icon, Opened = options.Opened == true, Tabs = {}, Root = header}
        local app = self
        function section:Tab(config)
            local page = app:Page(config)
            page._navSection = self
            table.insert(self.Tabs, page)
            page.Tab.Visible = self.Opened
            for i, tab in ipairs(self.Tabs) do tab.Tab.LayoutOrder = header.LayoutOrder + i end
            return page
        end
        function section:Open() self.Opened = true; for _, page in ipairs(self.Tabs) do page.Tab.Visible = true end; return self end
        function section:Close() self.Opened = false; for _, page in ipairs(self.Tabs) do page.Tab.Visible = false end; return self end
        connect(app, header.MouseButton1Click, function() if section.Opened then section:Close() else section:Open() end end)
        self:_bindText(header, "Text", section.Title)
        return section
    end
    function App:Divider()
        self._navOrder = (self._navOrder or 0) + 100
        local row = inst("Frame", self.UI.NavScroll, {
            Name = "SidebarDivider", Size = UDim2.new(1, -10, 0, 6), BackgroundTransparency = 1,
            LayoutOrder = self._navOrder,
        })
        inst("Frame", row, {Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -12, 0, 1),
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.65, BorderSizePixel = 0})
        return row
    end
    function App:SetToggleKey(key) self._toggleKey, self.ToggleKey = key, key; return self end
    function App:SetTitle(text)
        self.Title = tostring(text or "")
        self:_bindText(self.UI.Title, "Text", self.Title)
        self:_bindText(self.Island.Title, "Text", self.Title)
        return self
    end
    function App:SetAuthor(text) self.Author = tostring(text or ""); self:_bindText(self.UI.Author, "Text", self.Author); return self end
    function App:SetIconSize(size)
        self.IconSize = typeof(size) == "UDim2" and size.X.Offset or clamp(size, 8, 40)
        if self.UI.WindowIcon then
            self.UI.WindowIcon.Size = UDim2.fromOffset(self.IconSize, self.IconSize)
            self.UI.WindowIcon.Position = UDim2.fromOffset(14, 26 - self.IconSize / 2)
            local x = self.IconSize + 22
            self.UI.Title.Position = UDim2.fromOffset(x, self.UI.Title.Position.Y.Offset)
            self.UI.Author.Position = UDim2.fromOffset(x, self.UI.Author.Position.Y.Offset)
            self.UI.Title.Size = UDim2.new(0, math.max(24, 140 - x), self.UI.Title.Size.Y.Scale, self.UI.Title.Size.Y.Offset)
            self.UI.Author.Size = UDim2.new(0, math.max(24, 140 - x), self.UI.Author.Size.Y.Scale, self.UI.Author.Size.Y.Offset)
        end
        return self
    end
    App.SetBackgroundImageTransparency = App.SetBackgroundTransparency
    function App:SetBackgroundTransparency(value) return self:SetGlassTransparency(value) end
    App.OnOpen = function(self, fn) return self:On("Open", fn) end
    App.OnClose = function(self, fn) return self:On("Close", fn) end
    App.OnDestroy = function(self, fn) return self:On("Destroy", fn) end
    function App:ToggleTransparency(enabled)
        if enabled == nil then enabled = not self.Transparent end
        self.Transparent, WindUI.Transparent = enabled == true, enabled == true
        self:SetFrostedGlass(enabled == true)
        return self
    end
    function App:LockAll() for _, control in ipairs(self.AllElements) do control:Lock() end; return self end
    function App:UnlockAll() for _, control in ipairs(self.AllElements) do control:Unlock() end; return self end
    function App:GetLocked()
        local result = {}; for _, c in ipairs(self.AllElements) do if c.Locked then result[#result + 1] = c end end; return result
    end
    function App:GetUnlocked()
        local result = {}; for _, c in ipairs(self.AllElements) do if not c.Locked then result[#result + 1] = c end end; return result
    end
    function App:GetUIScale() return self.AutoScaleObject.Scale end
    function App:SetUIScale(scale)
        self._requestedScale = clamp(scale, 0.25, 2)
        self:_fit(); WindUI.UIScale = self:GetUIScale()
        return self
    end
    function App:SetToTheCenter() return self:Center() end
    function App:ToggleFullscreen()
        if not self.IsFullscreen then
            self._beforeFullscreen = {Size = self.Holder.Size, Position = self.Holder.Position}
            self.Holder.Size = UDim2.new(1, -36, 1, -80)
            self.Holder.Position = UDim2.new(0.5, 0, 0.5, 12)
        else
            self.Holder.Size = self._beforeFullscreen.Size
            self.Holder.Position = self._beforeFullscreen.Position
        end
        self.IsFullscreen = not self.IsFullscreen
        self.Size, self.Position = self.Holder.Size, self.Holder.Position
        self._restingPosition = self._closed and self.Holder.Position or nil
        self:_fit()
        return self
    end
    function App:IsResizable(enabled)
        self.Resizable, self.CanResize = enabled == true, enabled == true
        if not self._resizeHandle then
            local handle = button(self.UI.Root, "◢", {
                Name = "ResizeHandle", Position = UDim2.new(1, -22, 1, -22), Size = UDim2.fromOffset(20, 20),
                TextSize = 12, TextColor3 = MUTED, ZIndex = 12,
            })
            self._resizeHandle = handle
            local start, size
            connect(self, handle.InputBegan, function(input)
                if not self.CanResize or self.IsFullscreen then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    start, size = input.Position, self.Holder.Size
                end
            end)
            connect(self, Input.InputChanged, function(input)
                if not start or not self.CanResize then return end
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                    local delta = input.Position - start
                    local scale = self.AutoScaleObject.Scale
                    self.Holder.Size = UDim2.fromOffset(
                        clamp(size.X.Offset + delta.X * 2 / scale, self.MinSize.X, self.MaxSize.X),
                        clamp(size.Y.Offset + delta.Y * 2 / scale, self.MinSize.Y, self.MaxSize.Y))
                    self.Size = self.Holder.Size
                end
            end)
            connect(self, Input.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    start = nil; self:_fit()
                end
            end)
        end
        self._resizeHandle.Visible = self.CanResize
        return self
    end
    function App:CreateTopbarButton(name, icon, callback, order, themed, shade)
        local object = button(self.UI.Topbar, ICONS[icon] or "◇", {
            Name = tostring(name or "Action"), Size = UDim2.fromOffset(27, 32), TextSize = 16,
            TextColor3 = color(shade, MUTED), ZIndex = 5,
        })
        local entry = {Name = name, Object = object, Order = order or 0}
        table.insert(self.TopBarButtons, entry)
        entry.Custom = true
        WindUI:_setIcon(object, icon, shade or (themed and self._accent) or WHITE)
        self:_layoutTopbar()
        connect(self, object.MouseButton1Click, function() safe(callback) end)
        return object
    end
    function App:DisableTopbarButtons(names)
        for _, name in ipairs(names or {}) do
            for _, entry in ipairs(self.TopBarButtons) do if entry.Name == name then entry.Disabled = true end end
        end
        self:_layoutTopbar()
        return self
    end
    function App:_layoutTopbar()
        if not self.TopBarButtons then return end
        local width = self.UI.Root.AbsoluteSize.X / math.max(0.1, self.AutoScaleObject.Scale)
        local right = 7
        for _, name in ipairs({"Close", "Fullscreen", "Minimize"}) do
            for _, entry in ipairs(self.TopBarButtons) do
                if not entry.Custom and entry.Name == name then
                    entry.Object.Visible = not entry.Disabled
                    if not entry.Disabled then
                        entry.Object.Position = UDim2.new(1, -right - 27, 0, 8)
                        right = right + 31
                    end
                end
            end
        end
        local extra = {}
        for _, entry in ipairs(self.TopBarButtons) do if entry.Custom then extra[#extra + 1] = entry end end
        table.sort(extra, function(a, b) return a.Order < b.Order end)
        for _, entry in ipairs(extra) do
            entry.Object.Visible = not entry.Disabled and width - right > 205
            if entry.Object.Visible then entry.Object.Position = UDim2.new(1, -right - 27, 0, 10); right = right + 30 end
        end
        local function place(object, wanted, objectWidth)
            object.Visible = wanted and width - right - objectWidth > 242
            if object.Visible then
                right = right + objectWidth + 5
                object.Position = UDim2.new(1, -right, 0, 14)
                object.Size = UDim2.fromOffset(objectWidth, 25)
            end
        end
        place(self.UI.Clock, self._clockVisible, 78)
        if self._status then place(self._status, true, 98) end
        for _, tag in ipairs(self._tags or {}) do if tag.Parent then place(tag, true, 72) end end
        local room = width - right - 158
        self.UI.Search.Visible = self._searchVisible and room >= 60
        self.UI.Search.Size = UDim2.fromOffset(math.max(60, math.min(self._searchWidth, room)), 31)
    end
    function App:EditOpenButton(options) return self.OpenButtonMain:Edit(options) end
    function App:Tag(options)
        options = type(options) == "table" and options or {Title = options}
        local object = label(self.UI.Topbar, options.Title or "Tag", 11, INK, BOLD, {
            Position = UDim2.new(1, -206, 0, 14), Size = UDim2.fromOffset(100, 25),
            BackgroundColor3 = color(options.Color, WHITE), BackgroundTransparency = 0.2,
            TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
        })
        corner(object, options.Radius or 12)
        local tag = {Title = options.Title or "Tag", Color = options.Color, TagFrame = object}
        function tag:SetTitle(text) self.Title = tostring(text); object.Text = self.Title; return self end
        function tag:SetColor(shade)
            self.Color = shade
            if typeof(shade) == "Color3" then object.BackgroundColor3 = shade; object.TextColor3 = accentInk(shade)
            elseif type(shade) == "table" then
                local gradient = object:FindFirstChildOfClass("UIGradient") or inst("UIGradient", object)
                for key, value in pairs(shade) do gradient[key] = value end
            end
            return self
        end
        local app = self
        self._tags = self._tags or {}; table.insert(self._tags, object)
        function tag:Destroy()
            object:Destroy()
            for i = #app._tags, 1, -1 do if app._tags[i] == object then table.remove(app._tags, i) end end
            app:_layoutTopbar()
        end
        if options.Color then tag:SetColor(options.Color) end
        self:_layoutTopbar()
        return tag
    end
    function App:Dialog(options)
        options = type(options) == "table" and options or {Title = options}
        local width = clamp(options.Width or 330, 230, 520)
        local buttons = options.Buttons or {}
        local height = 150 + math.max(0, math.ceil(#buttons / 3) - 1) * 38
        local veil = inst("Frame", self.UI.Root, {
            Name = "DialogVeil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.58, BorderSizePixel = 0, ZIndex = 29, Visible = false, Active = true,
        })
        local frame = inst("CanvasGroup", veil, {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(width, height), BackgroundColor3 = WHITE, BackgroundTransparency = 0.16,
            BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 30,
        })
        corner(frame, 14); stroke(frame, WHITE, 0.2)
        label(frame, options.Title or "Dialog", 15, INK, BOLD, {
            Position = UDim2.fromOffset(17, 10), Size = UDim2.new(1, -34, 0, 29), ZIndex = 31})
        local body = label(frame, options.Content or "", 12, MUTED, FONT, {
            Position = UDim2.fromOffset(17, 45), Size = UDim2.new(1, -34, 0, 55),
            TextWrapped = true, TextTruncate = Enum.TextTruncate.None, ZIndex = 31,
        })
        local dialog = {UIElements = {Main = frame, Content = body}, Closed = true, _connections = {}}
        function dialog:Open() if not self.Destroyed then veil.Visible = true; self.Closed = false end; return self end
        function dialog:Close() if not self.Destroyed then veil.Visible = false; self.Closed = true end; return self end
        function dialog:Destroy()
            if self.Destroyed then return end
            self.Destroyed, self.Closed = true, true
            for _, connection in ipairs(self._connections) do connection:Disconnect() end
            veil:Destroy()
        end
        for i, spec in ipairs(buttons) do
            local column, line = (i - 1) % 3, math.floor((i - 1) / 3)
            local perRow = math.min(3, #buttons - line * 3)
            local b = button(frame, spec.Title or "Button", {
                Position = UDim2.new(column / perRow, 14, 0, 107 + line * 38),
                Size = UDim2.new(1 / perRow, -20, 0, 30), BackgroundColor3 = WHITE,
                BackgroundTransparency = spec.Variant == "Primary" and 0.08 or 0.48, TextSize = 12, ZIndex = 31,
            })
            corner(b, 8); stroke(b, SILVER, 0.64)
            dialog._connections[#dialog._connections + 1] = b.MouseButton1Click:Connect(function()
                local ok, result = true, nil
                if type(spec.Callback) == "function" then ok, result = pcall(spec.Callback, dialog) end
                if not ok then warn("[WhiteGlass Dialog] " .. tostring(result)) end
                if ok and result ~= false and not spec.KeepOpen then dialog:Close() end
            end)
        end
        self:_paintNew(frame)
        return dialog
    end
    function App:Confirm(title, description, accept, cancel)
        return self:Dialog({Title = title, Content = description, Buttons = {
            {Title = "取消", Callback = cancel}, {Title = "确定", Variant = "Primary", Callback = accept},
        }}):Open()
    end
    function App:_layoutToasts()
        local offset = 18
        for _, toast in ipairs(self._toasts or {}) do
            if not toast.Closed then
                toast.Root.AnchorPoint = Vector2.new(1, self._notificationsLower and 1 or 0)
                toast.Root.Position = self._notificationsLower and UDim2.new(1, -16, 1, -offset) or UDim2.new(1, -16, 0, offset)
                offset = offset + toast.Root.Size.Y.Offset + 9
            end
        end
    end
    function App:Notify(options, content, duration)
        if type(options) ~= "table" then options = {Title = options, Content = content, Duration = duration} end
        self._toasts = self._toasts or {}
        if #self._toasts >= 5 then self._toasts[1]:Close() end
        local root = inst("CanvasGroup", self.Gui, {
            Name = "Notification", Size = UDim2.fromOffset(276, #(options.Buttons or {}) > 0 and 114 or 80),
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, BorderSizePixel = 0,
            ClipsDescendants = true, ZIndex = 40,
        })
        corner(root, 12); stroke(root, WHITE, 0.25)
        local title = label(root, options.Title or "通知", 13, INK, BOLD, {
            Position = UDim2.fromOffset(13, 7), Size = UDim2.new(1, -44, 0, 25), ZIndex = 41})
        local description = label(root, options.Content or "", 11, MUTED, FONT, {
            Position = UDim2.fromOffset(13, 34), Size = UDim2.new(1, -26, 0, 37), TextWrapped = true, ZIndex = 41})
        local toast = {Root = root, Closed = false, Title = options.Title, Content = options.Content,
            UIElements = {Main = root}, _connections = {}}
        local app = self
        function toast:Close()
            if self.Closed then return end
            self.Closed = true
            for _, c in ipairs(self._connections) do c:Disconnect() end
            root:Destroy()
            for i = #app._toasts, 1, -1 do if app._toasts[i] == self then table.remove(app._toasts, i) end end
            app:_layoutToasts()
        end
        toast.Destroy = toast.Close
        function toast:SetTitle(text) self.Title = text; title.Text = tostring(text); return self end
        function toast:SetContent(text) self.Content = text; description.Text = tostring(text); return self end
        if options.CanClose ~= false then
            local close = button(root, "×", {Position = UDim2.new(1, -31, 0, 3), Size = UDim2.fromOffset(26, 30), ZIndex = 41})
            toast._connections[#toast._connections + 1] = close.MouseButton1Click:Connect(function() toast:Close() end)
        end
        local specs = options.Buttons or {}
        for index, spec in ipairs(specs) do
            local action = button(root, spec.Title or "Button", {
                Position = UDim2.new((index - 1) / #specs, 10, 0, 78), Size = UDim2.new(1 / #specs, -16, 0, 26),
                BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, TextSize = 11, ZIndex = 41,
            })
            corner(action, 7)
            toast._connections[#toast._connections + 1] = action.MouseButton1Click:Connect(function() safe(spec.Callback, toast) end)
        end
        self._toasts[#self._toasts + 1] = toast
        self:_paintNew(root); self:_layoutToasts()
        local lifetime = tonumber(options.Duration) or 4
        if lifetime > 0 then task.delay(clamp(lifetime, 1, 120), function() toast:Close() end) end
        return toast
    end
    function WindUI:_host()
        if self.Window and not self.Window._destroyed then return self.Window end
        if not self._notificationHost then
            local gui = inst("ScreenGui", self._parent or parentGui(), {
                Name = "WhiteGlassPopups", IgnoreGuiInset = true, ResetOnSpawn = false,
                DisplayOrder = 60, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            })
            self._notificationHost = setmetatable({Gui = gui, UI = {Root = gui}, _connections = {},
                _themeData = self.Theme, _notificationsLower = self._notificationsLower}, App)
        end
        return self._notificationHost
    end
    function WindUI:Notify(options) return self:_host():Notify(options) end
    function WindUI:Popup(options) return self:_host():Dialog(options):Open() end
    function WindUI:SetNotificationLower(enabled)
        self._notificationsLower = enabled == true
        local app = self:_host(); app._notificationsLower = self._notificationsLower; app:_layoutToasts()
        return self
    end
    function WindUI:SetParent(parent)
        self._parent = parent
        for _, app in ipairs(self._windows) do if not app._destroyed then app.Gui.Parent = parent end end
        if self._notificationHost then self._notificationHost.Gui.Parent = parent end
        return self
    end
    function WindUI:GetTransparency() return self.Window and self.Window.Transparent or false end
    function WindUI:GetWindowSize() return self.Window and self.Window.Holder.Size or UDim2.fromOffset(580, 460) end
end

-- Glass material: fBm microstructure -> separable Gaussian -> density mapping.
-- This filters the material texture, NOT captured game pixels. Scene blur is an
-- explicitly separate Roblox post-effect, affecting the complete local 3D view.
do
    local function noise(x, y)
        if math.noise then return math.noise(x, y, 3.71) end
        local n = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
        return (n - math.floor(n)) * 2 - 1
    end
    local function gaussian(values, width, height, radius, sigma)
        local kernel, sum = {}, 0
        for x = -radius, radius do
            local w = math.exp(-(x * x) / (2 * sigma * sigma))
            kernel[x], sum = w, sum + w
        end
        for x = -radius, radius do kernel[x] = kernel[x] / sum end
        local horizontal, output = {}, {}
        for y = 0, height - 1 do for x = 0, width - 1 do
            local v = 0
            for k = -radius, radius do v = v + values[y * width + ((x + k) % width) + 1] * kernel[k] end
            horizontal[y * width + x + 1] = v
        end end
        for y = 0, height - 1 do for x = 0, width - 1 do
            local v = 0
            for k = -radius, radius do v = v + horizontal[((y + k) % height) * width + x + 1] * kernel[k] end
            output[y * width + x + 1] = v
        end end
        return output
    end
    function App:_createFrostTexture()
        if self._textureAttempted or self._destroyed then return end
        self._textureAttempted = true
        local image
        local ok, failure = pcall(function()
            assert(buffer and Content and Content.fromObject, "EditableImage content API unavailable")
            local assets = game:GetService("AssetService")
            image = assets:CreateEditableImage({Size = Vector2.new(64, 64)})
            assert(image, "EditableImage budget or permission unavailable")
            local values = {}
            for y = 0, 63 do for x = 0, 63 do
                values[y * 64 + x + 1] = 0.5 + noise(x / 13, y / 13) * 0.28
                    + noise(x / 6.5, y / 6.5) * 0.14 + noise(x / 3.25, y / 3.25) * 0.07
            end end
            local blurred = gaussian(values, 64, 64, 4, 1.45)
            local pixels = buffer.create(64 * 64 * 4)
            for i, v in ipairs(blurred) do
                local micro = values[i] - v
                local density = clamp(0.04 + v * 0.09 + micro * 0.07, 0.025, 0.18)
                local alpha = 1 - math.exp(-density)
                local offset = (i - 1) * 4
                buffer.writeu8(pixels, offset, 255)
                buffer.writeu8(pixels, offset + 1, 255)
                buffer.writeu8(pixels, offset + 2, 255)
                buffer.writeu8(pixels, offset + 3, math.floor(alpha * 255 + 0.5))
            end
            image:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(64, 64), pixels)
            if self._destroyed then image:Destroy(); return end
            self._frostImage = image
            self.UI.FrostGrain.ImageContent = Content.fromObject(image)
            self.UI.FrostGrain.Visible = self._glassEnabled
            self._frostBackend = "EditableImage"
        end)
        if not ok then
            if image then image:Destroy() end
            self._frostBackend, self._frostFallbackReason = "Gradient", tostring(failure)
            self.UI.FrostGrain.Visible = false
        end
    end
    function App:_initGlass(options)
        options = options or {}
        local glaze = inst("Frame", self.UI.Surface, {
            Name = "FrostDensity", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.92, BorderSizePixel = 0,
        })
        inst("UIGradient", glaze, {Rotation = 112, Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.25, 0.6),
            NumberSequenceKeypoint.new(0.55, 0.94), NumberSequenceKeypoint.new(0.85, 0.5),
            NumberSequenceKeypoint.new(1, 0.12),
        })})
        local haze = inst("Frame", self.UI.Surface, {
            Name = "FrostDiffusion", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.94, BorderSizePixel = 0,
        })
        inst("UIGradient", haze, {Rotation = 20, Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.1),
            NumberSequenceKeypoint.new(0.64, 0.7), NumberSequenceKeypoint.new(1, 1),
        })})
        local grain = inst("ImageLabel", self.UI.Surface, {
            Name = "FrostMicrostructure", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            ImageColor3 = WHITE, ImageTransparency = 0.4, ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(96, 96), Visible = false,
        })
        local rim = inst("Frame", self.UI.Root, {
            Name = "InnerGlassRim", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6),
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10,
        })
        corner(rim, 13)
        local rimStroke = stroke(rim, WHITE, 0.82)
        inst("UIGradient", rimStroke, {Rotation = 118, Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.47, 0.85), NumberSequenceKeypoint.new(1, 0.3),
        })})
        self.UI.FrostDensity, self.UI.FrostDiffusion, self.UI.FrostGrain, self.UI.FrostRim = glaze, haze, grain, rimStroke
        self._fixedColors = self._fixedColors or {}
        for _, object in ipairs({glaze, haze, grain, rimStroke}) do self._fixedColors[object] = true end
        self._glassStrength = clamp(options.GlassStrength or 0.8, 0, 1)
        self._glassRoughness = clamp(options.GlassRoughness or 0.65, 0, 1)
        self._frostBackend = "Gradient"
        self:SetGlassStrength(self._glassStrength)
        if options.GlassTexture ~= false then
            task.defer(function() if not self._destroyed then self:_createFrostTexture() end end)
        end
    end
    function App:SetGlassStrength(strength)
        self._glassStrength = clamp(strength, 0, 1)
        if self.UI.FrostDensity then
            local opticalDepth = self._glassStrength * 0.16
            self.UI.FrostDensity.BackgroundTransparency = math.exp(-opticalDepth)
            self.UI.FrostDiffusion.BackgroundTransparency = 1 - 0.105 * self._glassStrength
            self.UI.FrostGrain.ImageTransparency = 1 - self._glassRoughness * (0.35 + self._glassStrength * 0.5)
            self.UI.FrostRim.Transparency = 0.96 - self._glassStrength * 0.3
            self.UI.Border.Transparency = 0.4 - self._glassStrength * 0.22
        end
        return self
    end
    function App:SetGlassRoughness(roughness)
        self._glassRoughness = clamp(roughness, 0, 1)
        return self:SetGlassStrength(self._glassStrength)
    end
    function App:GetGlassState()
        local algorithms = {"exponential density mapping", "directional edge falloff"}
        if self._frostBackend == "EditableImage" then
            algorithms[#algorithms + 1] = "fBm material noise"
            algorithms[#algorithms + 1] = "separable Gaussian texture filter"
        end
        if self._blur and self._blur.Enabled then algorithms[#algorithms + 1] = "native full-view Gaussian blur" end
        return {Strength = self._glassStrength, Roughness = self._glassRoughness,
            TextureBackend = self._frostBackend or "Gradient", TextureFallbackReason = self._frostFallbackReason,
            TextureResolution = self._frostBackend == "EditableImage" and 64 or 0, SceneBlur = self._globalBlur == true,
            SceneBlurEnabled = self._blur ~= nil and self._blur.Enabled == true,
            SceneBlurSize = self._blurSize, LocalSceneBlur = false, MistEnabled = self._mistEnabled,
            Algorithms = algorithms}
    end
    function App:_syncBlur()
        if self._blur then
            self._blur.Parent = workspace.CurrentCamera or Lighting
            self._blur.Enabled = not self._destroyed and not self._closed and self._globalBlur and self.Holder.Visible
        end
    end
    function App:SetFrostedGlass(enabled, options)
        options = type(options) == "table" and options or {}
        self._glassEnabled = enabled == true
        self._bodyAlpha = clamp(options.BodyTransparency or self._bodyAlpha, 0.16, 0.82)
        self.UI.Surface.BackgroundTransparency = self._glassEnabled and self._bodyAlpha or 0
        if options.GlobalBlur ~= nil then self._globalBlur = options.GlobalBlur == true end
        if not self._glassEnabled then self._globalBlur = false end
        self._blurSize = clamp(options.BlurSize or self._blurSize or 16, 0, 56)
        if self._globalBlur and not self._blur then
            self._blur = inst("BlurEffect", workspace.CurrentCamera or Lighting, {Name = "PYWhiteGlassBlur", Size = self._blurSize})
        elseif not self._globalBlur and self._blur then
            self._blur:Destroy(); self._blur = nil
        end
        if self._blur then self._blur.Size = self._blurSize end
        if self.UI.FrostDensity then
            self.UI.FrostDensity.Visible, self.UI.FrostDiffusion.Visible = self._glassEnabled, self._glassEnabled
            self.UI.FrostGrain.Visible = self._glassEnabled and self._frostBackend == "EditableImage"
        end
        if options.GlassStrength ~= nil then self:SetGlassStrength(options.GlassStrength) end
        if options.GlassRoughness ~= nil then self:SetGlassRoughness(options.GlassRoughness) end
        self:_syncBlur()
        return self
    end
    function WindUI:ToggleAcrylic(enabled)
        local app = self.Window
        if app then
            app.Acrylic = enabled == true
            app:SetFrostedGlass(true, {GlobalBlur = enabled == true, BlurSize = app._blurSize})
        end
        return self
    end
    -- Exposed pure filter for callers with their own image samples; no capture is performed.
    function WindUI:GaussianFilter(samples, width, height, sigma)
        assert(type(samples) == "table" and type(width) == "number" and type(height) == "number"
            and width % 1 == 0 and height % 1 == 0 and width >= 1 and height >= 1 and #samples == width * height, "Invalid image samples")
        assert(width * height <= 262144, "Use a downsampled image of at most 512x512")
        sigma = clamp(sigma or 1.45, 0.3, 4)
        return gaussian(samples, width, height, math.ceil(sigma * 2.5), sigma)
    end
end

-- Lifecycle and entry points. Loading this file alone never creates a window.
do
    local create = WindUI.Create
    local open, close, destroy = App.Open, App.Close, App.Destroy
    local function iconInto(target, icon, shade) return WindUI:_setIcon(target, icon, shade) end
    for name, glyph in pairs({
        ["arrow-up"] = "↑", ["arrow-down"] = "↓", ["chevron-right"] = "›", ["chevron-down"] = "⌄",
        check = "✓", x = "×", minus = "−", plus = "+", info = "ⓘ", code = "{ }",
        ["terminal"] = ">_", ["file-code"] = "{ }", ["sliders-horizontal"] = "≡",
        ["circle-check"] = "✓", ["refresh-cw"] = "↻", ["rotate-ccw"] = "↶",
        ["move"] = "✥", ["sparkles"] = "✧", ["eye"] = "◉", ["circle"] = "○",
        ["square"] = "□", ["folder"] = "▱", ["save"] = "▣", ["download"] = "↓",
    }) do ICONS[name] = glyph end
    function App:Search(query)
        query = tostring(query or ""):lower()
        self._searchText = query
        if self.UI.Search.Text:lower() ~= query then self.UI.Search.Text = query end
        local first
        for _, page in ipairs(self.Pages) do
            local matchedPage = WindUI:_translate(page.Title):lower():find(query, 1, true) ~= nil
            local any = false
            for _, control in ipairs(self.AllElements) do
                if control.Tab == page and not control.Destroyed then
                    local title = WindUI:_translate(control.Title):lower()
                    local desc = WindUI:_translate(control.Desc):lower()
                    local hit = query == "" or matchedPage or title:find(query, 1, true) ~= nil or desc:find(query, 1, true) ~= nil
                    local ancestor = control.ParentContainer
                    while not hit and ancestor and ancestor ~= page do
                        hit = WindUI:_translate(ancestor.Title):lower():find(query, 1, true) ~= nil
                        ancestor = ancestor.ParentContainer
                    end
                    hit = hit and not control._userHidden
                    control.Root.Visible = hit
                    if hit then any = true end
                end
            end
            if query ~= "" then
                for _, control in ipairs(self.AllElements) do
                    if control.Tab == page and control.Root.Visible then
                        local parent = control.ParentContainer
                        while parent and parent ~= page do
                            parent.Root.Visible = true
                            if parent._searchWasOpened == nil then parent._searchWasOpened = parent.Opened end
                            if parent.Open then parent:Open() end
                            parent = parent.ParentContainer
                        end
                    end
                end
            else
                for _, control in ipairs(self.AllElements) do
                    if control.Tab == page and control._searchWasOpened ~= nil then
                        if control._searchWasOpened then control:Open() else control:Close() end
                        control._searchWasOpened = nil
                    end
                end
            end
            if query ~= "" then page.Tab.Visible = any or matchedPage
            else page.Tab.Visible = not page._navSection or page._navSection.Opened end
            for _, control in ipairs(self.AllElements) do
                if control.Tab == page and control._relayout then control:_relayout() end
            end
            if page.Tab.Visible and not first and not page.Locked then first = page end
        end
        if query ~= "" and first then first:Select() end
        return self
    end
    function App:Open()
        self.Closed = false
        local result = open(self)
        self.Position = self.Holder.Position
        return result
    end
    function App:Close()
        self.Closed = true
        if self._popupControl then self._popupControl:Close() end
        local result = close(self)
        if self.IsOpenButtonEnabled == false then self.Compact.Visible = false end
        return result
    end
    function App:Destroy()
        if self._destroyed then return end
        self.Destroyed = true
        if self._popupControl then self._popupControl:Close() end
        while self._toasts and #self._toasts > 0 do self._toasts[1]:Close() end
        local controls = {}
        for _, control in ipairs(self.AllElements) do controls[#controls + 1] = control end
        for i = #controls, 1, -1 do controls[i]:Destroy() end
        if self._frostImage then self._frostImage:Destroy(); self._frostImage = nil end
        destroy(self)
        for i = #WindUI._windows, 1, -1 do if WindUI._windows[i] == self then table.remove(WindUI._windows, i) end end
        if WindUI.Window == self then WindUI.Window = nil end
    end
    WindUI.Services = {}
    function WindUI:RegisterKeyProvider(name, provider)
        assert(type(provider) == "table" and type(provider.New) == "function", "A provider needs New()")
        self.Services[name] = provider
        return self
    end
    function App:_keySystem(options)
        local keyConfig = options.KeySystem
        if type(keyConfig) ~= "table" then return end
        local app = self
        local validators = {}
        if keyConfig.KeyValidator then
            validators[#validators + 1] = keyConfig.KeyValidator
        elseif keyConfig.API then
            for _, spec in ipairs(keyConfig.API) do
                local provider = WindUI.Services[spec.Type]
                assert(provider, "KeySystem provider '" .. tostring(spec.Type) .. "' needs RegisterKeyProvider before CreateWindow")
                local args = {}
                for _, name in ipairs(provider.Args or {}) do args[#args + 1] = spec[name] end
                local instance = provider.New(table.unpack(args))
                validators[#validators + 1] = instance.Verify
            end
        else
            validators[#validators + 1] = function(key)
                if type(keyConfig.Key) == "table" then
                    for _, candidate in ipairs(keyConfig.Key) do if tostring(candidate) == key then return true end end
                    return false
                end
                return keyConfig.Key ~= nil and tostring(keyConfig.Key) == key
            end
        end
        local function verify(key)
            for _, validator in ipairs(validators) do
                local ok, result = pcall(validator, key)
                if ok and result == true then return true end
            end
            return false
        end
        local path = "WindUI/" .. tostring(app.Folder):gsub('[\\/:*?"<>|]', "_") .. "/saved-key.txt"
        if keyConfig.SaveKey and type(isfile) == "function" and type(readfile) == "function" and isfile(path) then
            local ok, value = pcall(readfile, path)
            if ok and verify(value) then app.KeyVerified = true; return end
        end
        app.KeyVerified = false
        local gate = inst("Frame", app.UI.Root, {
            Name = "KeySystem", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.08, BorderSizePixel = 0, Active = true, ZIndex = 70,
        })
        label(gate, keyConfig.Title or "输入访问密钥", 18, INK, BOLD, {
            Position = UDim2.new(0.5, -160, 0.5, -100), Size = UDim2.fromOffset(320, 38), ZIndex = 71})
        label(gate, keyConfig.Note or "", 12, MUTED, FONT, {
            Position = UDim2.new(0.5, -160, 0.5, -56), Size = UDim2.fromOffset(320, 36), TextWrapped = true, ZIndex = 71})
        local input = inst("TextBox", gate, {
            Position = UDim2.new(0.5, -160, 0.5, -10), Size = UDim2.fromOffset(320, 36),
            Text = "", PlaceholderText = "Key", ClearTextOnFocus = false, TextColor3 = INK,
            BackgroundColor3 = PEARL, BorderSizePixel = 0, Font = FONT, TextSize = 13, ZIndex = 71,
        })
        corner(input, 9)
        local action = button(gate, "验证", {Position = UDim2.new(0.5, -160, 0.5, 42), Size = UDim2.fromOffset(150, 34),
            BackgroundColor3 = PEARL, BackgroundTransparency = 0.1, ZIndex = 71})
        corner(action, 9)
        local copyLink = button(gate, "复制获取链接", {Position = UDim2.new(0.5, 10, 0.5, 42), Size = UDim2.fromOffset(150, 34), ZIndex = 71})
        connect(app, copyLink.MouseButton1Click, function()
            local copier = setclipboard or toclipboard
            local link = type(keyConfig.URL) == "table" and keyConfig.URL[1] or keyConfig.URL
            if type(copier) == "function" and link then copier(tostring(link)) end
        end)
        local busy = false
        connect(app, action.MouseButton1Click, function()
            if busy then return end
            busy, action.Text = true, "验证中..."
            local key = input.Text
            task.spawn(function()
                local accepted = verify(key)
                if app._destroyed then return end
                if accepted then
                    app.KeyVerified = true
                    if keyConfig.SaveKey and type(writefile) == "function" then
                        pcall(function()
                            if type(makefolder) == "function" then
                                if not isfolder or not isfolder("WindUI") then makefolder("WindUI") end
                                local folder = path:match("^(.*)/")
                                if not isfolder or not isfolder(folder) then makefolder(folder) end
                            end
                            writefile(path, key)
                        end)
                    end
                    gate:Destroy()
                else action.Text = "密钥无效，重试" end
                busy = false
            end)
        end)
    end
    function WindUI:Create(options)
        options = type(options) == "table" and options or {}
        if type(options.KeySystem) == "table" and options.KeySystem.API then
            for _, spec in ipairs(options.KeySystem.API) do
                assert(self.Services[spec.Type], "KeySystem provider '" .. tostring(spec.Type) .. "' needs RegisterKeyProvider before CreateWindow")
            end
        end
        local app = create(self, options)
        app.Window = app
        app.Title, app.Author, app.Folder = options.Title or "WindUI", options.Author or "", options.Folder or "WhiteGlass"
        app.Size, app.Position = app.Holder.Size, app.Holder.Position
        app.MinSize, app.MaxSize = options.MinSize or Vector2.new(420, 300), options.MaxSize or Vector2.new(1000, 800)
        app.SideBarWidth, app.ElementsRadius = options.SideBarWidth or 188, options.ElementsRadius or 9
        app.ScrollBarEnabled = options.ScrollBarEnabled ~= false
        app.Radius, app.UICorner, app.UIPadding = options.Radius or 16, options.Radius or 16, 12
        app.Transparent, app.Closed, app.Destroyed, app.IsFullscreen = options.Transparent ~= false, false, false, false
        app.IsOpenButtonEnabled, app._notificationsLower = true, self._notificationsLower == true
        app.PendingFlags, app.AllElements = app.PendingFlags or {}, app.AllElements or {}
        if options.Parent or self._parent then app.Gui.Parent = options.Parent or self._parent end
        if typeof(options.Size) == "UDim2" then app.Holder.Size = options.Size; app.Size = options.Size; app:_fit() end
        app.UI.Sidebar.Size = UDim2.new(0, app.SideBarWidth, 1, -52)
        app.UI.Content.Position = UDim2.fromOffset(app.SideBarWidth + 11, 62)
        app.UI.Content.Size = UDim2.new(1, -app.SideBarWidth - 23, 1, -76)
        local rootCorner = app.UI.Root:FindFirstChildOfClass("UICorner")
        if rootCorner then rootCorner.CornerRadius = UDim.new(0, app.Radius) end
        app.UI.NavScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        app.UIElements = {Main = app.Holder, Topbar = app.UI.Topbar, SideBar = app.UI.Sidebar,
            SideBarContainer = app.UI.NavScroll, MainBar = app.UI.Content, Background = app.UI.Surface}
        app.TopBarButtons = {
            {Name = "Minimize", Object = app.UI.Minimize}, {Name = "Fullscreen", Object = app.UI.Center},
            {Name = "Close", Object = app.UI.Close},
        }
        app.TabModule = {Tabs = app.Pages, Containers = {}, SelectedTab = nil, OnChangeFunc = nil}
        function app.TabModule:OnChange(callback) self.OnChangeFunc = callback; return self end
        function app.TabModule:SelectTab(index) return app:SelectTab(index) end
        function app.TabModule:New(config) return app:Tab(config) end
        app.OpenButtonMain = {Button = app.Compact, Enabled = true}
        function app.OpenButtonMain:SetIcon(icon)
            app.Island.Dot.Visible = icon == nil
            if not self.IconLabel then self.IconLabel = label(app.Compact, "", 13, MUTED, FONT, {
                Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(16, 22), ZIndex = 22}) end
            iconInto(self.IconLabel, icon)
            return self
        end
        function app.OpenButtonMain:Visible(visible)
            self.Enabled, app.IsOpenButtonEnabled = visible == true, visible == true
            app.Compact.Visible = app._closed and self.Enabled
            return self
        end
        function app.OpenButtonMain:Edit(config)
            config = config or {}
            if config.Title then app.Island.Title.Text = tostring(config.Title) end
            if config.Icon ~= nil then self:SetIcon(config.Icon) end
            if config.Enabled ~= nil then self.Enabled = config.Enabled == true; app.IsOpenButtonEnabled = self.Enabled end
            if config.Position then app._islandPosition = config.Position; app.Compact.Position = config.Position end
            if config.OnlyMobile then app.IsOpenButtonEnabled = Input.TouchEnabled end
            if config.Draggable ~= nil then app._islandDraggable = config.Draggable == true end
            if config.OnlyIcon ~= nil then
                app.Island.Title.Visible = not config.OnlyIcon
                app.Island.Arrow.Visible = not config.OnlyIcon
                app._islandSizeRest = UDim2.fromOffset(config.OnlyIcon and 44 or 166, 42)
                app.Compact.Size = app._islandSizeRest
            end
            if config.CornerRadius then app.Compact:FindFirstChildOfClass("UICorner").CornerRadius = config.CornerRadius end
            if config.StrokeThickness then app.Island.Stroke.Thickness = config.StrokeThickness end
            if typeof(config.Color) == "Color3" then app.Compact.BackgroundColor3 = config.Color end
            if app._closed then app.Compact.Visible = app.IsOpenButtonEnabled end
            return self
        end
        local islandDrag, islandStart, islandPosition
        connect(app, app.Compact.InputBegan, function(input)
            if app._islandDraggable and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                islandDrag, islandStart, islandPosition = true, input.Position, app.Compact.Position
            end
        end)
        connect(app, Input.InputChanged, function(input)
            if islandDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - islandStart
                app._islandPosition = UDim2.new(islandPosition.X.Scale, islandPosition.X.Offset + delta.X,
                    islandPosition.Y.Scale, islandPosition.Y.Offset + delta.Y)
                app.Compact.Position = app._islandPosition
            end
        end)
        connect(app, Input.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then islandDrag = false end
        end)
        app.User = {Enabled = false, Anonymous = false}
        local profile = label(app.UI.Sidebar, "", 11, MUTED, FONT, {
            Name = "UserProfile", Position = UDim2.new(0, 14, 1, -38), Size = UDim2.new(1, -28, 0, 30), Visible = false})
        function app.User:SetAnonymous(anonymous)
            self.Anonymous = anonymous ~= false
            local player = Players.LocalPlayer
            profile.Text = self.Anonymous and "Anonymous" or (player and (player.DisplayName or player.Name) or "Player")
            return self
        end
        function app.User:Enable() self.Enabled = true; profile.Visible = true; app.UI.NavScroll.Size = UDim2.new(1, -16, 1, -64); return self end
        function app.User:Disable() self.Enabled = false; profile.Visible = false; app.UI.NavScroll.Size = UDim2.new(1, -16, 1, -24); return self end
        app.User:SetAnonymous(type(options.User) == "table" and options.User.Anonymous == true or false)
        if type(options.User) == "table" and options.User.Enabled then app.User:Enable() end
        app.ConfigManager = app:_createConfigManager(app.Folder)
        self.ConfigManager, self.Window = app.ConfigManager, app
        self.ScreenGui, self.NotificationGui, self.DropdownGui, self.TooltipGui = app.Gui, app.Gui, app.Gui, app.Gui
        self.UIScaleObj, self.UIScale, self.Transparent = app.AutoScaleObject, app:GetUIScale(), app.Transparent
        table.insert(self._windows, app)
        local glass = type(options.Beauty) == "table" and options.Beauty or {}
        app:_initGlass(glass)
        app:SetTheme(options.Theme or "WhiteGlass")
        app:SetAccentColor(glass.AccentColor or (app._themeData and app._themeData.Toggle) or WHITE)
        app:SetFrostedGlass(glass.FrostedGlass ~= false, {
            GlobalBlur = glass.GlobalBlur ~= nil and glass.GlobalBlur or (glass.GlobalBlur == nil and options.Acrylic == true),
            BlurSize = glass.BlurSize or 16, BodyTransparency = glass.BodyTransparency or 0.64,
        })
        app.Acrylic = app._globalBlur
        app:SetTitle(app.Title); app:SetAuthor(app.Author)
        if options.Icon then
            app.UI.WindowIcon = label(app.UI.Topbar, "", 19, MUTED, FONT, {ZIndex = 5})
            iconInto(app.UI.WindowIcon, options.Icon, options.IconThemed and app._accent or WHITE)
            app:SetIconSize(options.IconSize or 22)
            app.OpenButtonMain:SetIcon(options.Icon)
        end
        if options.Transparent == false then app:ToggleTransparency(false) end
        if self._font then app:SetUIFont(self._font) end
        app:IsResizable(options.Resizable ~= false)
        if options.ShadowTransparency then app:SetShadow(options.ShadowTransparency) end
        if options.HidePanelBackground then app:SetLayeredGlass(false) end
        if options.TopbarSearchEnabled == nil and options.HideSearchBar ~= nil then app:SetSearchVisible(not options.HideSearchBar) end
        if options.OpenButton then app:EditOpenButton(options.OpenButton) end
        if options.ScrollBarEnabled == false then app.UI.NavScroll.ScrollBarThickness = 0 end
        if options.Background and type(options.Background) == "string" then app:SetBackgroundImage(options.Background, options.BackgroundImageTransparency) end
        if typeof(options.Background) == "Color3" then app.UI.Surface.BackgroundColor3 = options.Background end
        if type(options.Background) == "table" then
            for k, v in pairs(options.Background) do app.UI.Gradient[k] = v end
        end
        local viewportConnection
        local function cameraChanged()
            if viewportConnection then viewportConnection:Disconnect() end
            if workspace.CurrentCamera then
                viewportConnection = connect(app, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), function()
                    app:_fit(); app:_layoutTopbar()
                end)
            end
            app:_syncBlur(); app:_fit(); app:_layoutTopbar()
        end
        connect(app, workspace:GetPropertyChangedSignal("CurrentCamera"), cameraChanged)
        connect(app, app.Holder:GetPropertyChangedSignal("AbsoluteSize"), function() app:_layoutTopbar() end)
        cameraChanged()
        local ok, err = pcall(function() app:_keySystem(options) end)
        if not ok then app:Destroy(); error(err) end
        return app
    end
    WindUI.CreateWindow, WindUI.CreateApp = WindUI.Create, WindUI.Create
    -- Original Creator is internal; these common construction helpers are retained.
    WindUI.Creator = {
        New = function(class, properties, children)
            properties = properties or {}
            local p, values = properties.Parent, {}
            for k, v in pairs(properties) do if k ~= "Parent" and k ~= "ThemeTag" then values[k] = v end end
            local object = inst(class, p, values)
            for _, child in ipairs(children or {}) do child.Parent = object end
            return object
        end,
        Tween = function(object, duration, properties, style, direction)
            return Tween:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), properties)
        end,
        SafeCallback = safe,
        SanitizeFilename = function(name) return tostring(name):gsub('[\\/:*?"<>|]', "_") end,
    }
end

return WindUI

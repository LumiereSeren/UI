-- ================================================================
-- 终极 UI 库 (UILib)
-- 支持：多窗口、多标签、滑块、下拉菜单、颜色选择器、按键绑定、输入框
-- ================================================================
local UILib = {}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

function UILib:Init(config)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "UILibMain"
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- 高斯模糊背景
    local BlurView = Instance.new("ViewportFrame")
    BlurView.Size = UDim2.new(1,0,1,0)
    BlurView.BackgroundTransparency = 1
    BlurView.ZIndex = 0
    BlurView.Parent = ScreenGui

    local BlurCam = Instance.new("Camera")
    BlurCam.Parent = BlurView
    BlurView.CurrentCamera = BlurCam
    local BlurEffect = Instance.new("BlurEffect")
    BlurEffect.Size = 12
    BlurEffect.Parent = BlurCam

    game:GetService("RunService").RenderStepped:Connect(function()
        BlurCam.CFrame = Camera.CFrame
        BlurCam.FieldOfView = Camera.FieldOfView
    end)

    -- 主窗口
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 650, 0, 450)
    MainFrame.Position = UDim2.new(0.5, -325, 0.5, -225)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    MainFrame.BackgroundTransparency = 0.15
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    local MCorner = Instance.new("UICorner")
    MCorner.CornerRadius = UDim.new(0, 10)
    MCorner.Parent = MainFrame

    -- 拖拽功能
    local DragBar = Instance.new("Frame")
    DragBar.Size = UDim2.new(1,0,0,30)
    DragBar.BackgroundTransparency = 1
    DragBar.Parent = MainFrame
    
    local dragging, dragInput, dragStart, startPos
    DragBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    DragBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- 窗口标题
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0.3,0,1,0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = config.Title or "Ultimate UI"
    Title.TextColor3 = Color3.fromRGB(255,255,255)
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = DragBar

    -- 标签页容器
    local TabContainer = Instance.new("Frame")
    TabContainer.Size = UDim2.new(0, 160, 1, -30)
    TabContainer.Position = UDim2.new(0, 0, 0, 30)
    TabContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    TabContainer.BackgroundTransparency = 0.1
    TabContainer.Parent = MainFrame
    Instance.new("UICorner", TabContainer).CornerRadius = UDim.new(0, 5)

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.Padding = UDim.new(0, 5)
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.Parent = TabContainer

    -- 内容容器
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -170, 1, -30)
    ContentContainer.Position = UDim2.new(0, 170, 0, 30)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    self.CurrentWindow = MainFrame
    self.ContentContainer = ContentContainer
    self.Tabs = {}
    self.TabContainer = TabContainer
    
    return self
end

function UILib:AddTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 35)
    btn.Position = UDim2.new(0, 5, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.BackgroundTransparency = 0.5
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 14
    btn.Parent = self.TabContainer
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 4
    content.ScrollBarImageColor3 = Color3.fromRGB(80,80,80)
    content.Visible = false
    content.Parent = self.ContentContainer

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content

    btn.MouseButton1Click:Connect(function()
        for _, v in pairs(self.ContentContainer:GetChildren()) do v.Visible = false end
        content.Visible = true
        for _, v in pairs(self.TabContainer:GetChildren()) do 
            if v:IsA("TextButton") then v.BackgroundColor3 = Color3.fromRGB(40, 40, 40) end
        end
        btn.BackgroundColor3 = Color3.fromRGB(80, 180, 255)
    end)

    local tabData = {Content = content, Layout = layout}
    table.insert(self.Tabs, tabData)
    return tabData
end

function UILib:AddSection(tab, name)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, -10, 0, 0) -- 高度自适应
    section.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    section.BackgroundTransparency = 0.3
    section.Parent = tab.Content
    Instance.new("UICorner", section).CornerRadius = UDim.new(0, 6)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundTransparency = 1
    title.Text = name
    title.TextColor3 = Color3.fromRGB(150, 150, 150)
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = section

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 0)
    container.Position = UDim2.new(0, 5, 0, 25)
    container.BackgroundTransparency = 1
    container.Parent = section

    local clayout = Instance.new("UIListLayout")
    clayout.Padding = UDim.new(0, 5)
    clayout.SortOrder = Enum.SortOrder.LayoutOrder
    clayout.Parent = container

    -- 挂钩函数，方便更新高度
    local function updateSize()
        section.Size = UDim2.new(1, -10, 0, container.AbsoluteSize.Y + 30)
    end
    container:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSize)
    task.wait() updateSize()

    return container
end

-- 1. 开关 (Toggle)
function UILib:AddToggle(container, name, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 40, 0, 20)
    bg.Position = UDim2.new(1, -40, 0.5, -10)
    bg.BackgroundColor3 = default and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(50, 50, 50)
    bg.Parent = frame
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = default and UDim2.new(0, 22, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Parent = bg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = default
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            state = not state
            TweenService:Create(bg, TweenInfo.new(0.15), {BackgroundColor3 = state and Color3.fromRGB(0,180,255) or Color3.fromRGB(50,50,50)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {Position = state and UDim2.new(0,22,0.5,-8) or UDim2.new(0,2,0.5,-8)}):Play()
            if callback then callback(state) end
        end
    end)
end

-- 2. 按钮 (Button)
function UILib:AddButton(container, name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 14
    btn.Parent = container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
        task.wait(0.1)
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
        if callback then callback() end
    end)
end

-- 3. 滑块 (Slider)
function UILib:AddSlider(container, name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 35)
    frame.BackgroundTransparency = 1
    frame.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0.5, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0.3, 0, 0.5, 0)
    val.Position = UDim2.new(0.7, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = tostring(default)
    val.TextColor3 = Color3.fromRGB(180,180,180)
    val.TextSize = 14
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 4)
    bar.Position = UDim2.new(0, 0, 0.8, 0)
    bar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * pos)
        val.Text = tostring(value)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        if callback then callback(value) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- 4. 下拉菜单 (Dropdown)
function UILib:AddDropdown(container, name, list, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = container

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.Text = name .. ": " .. (default or "Select")
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 14
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local drop = Instance.new("Frame")
    drop.Size = UDim2.new(1, 0, 0, 0)
    drop.Position = UDim2.new(0, 0, 1, 0)
    drop.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    drop.ClipsDescendants = true
    drop.Parent = btn
    Instance.new("UICorner", drop).CornerRadius = UDim.new(0, 4)

    local dLayout = Instance.new("UIListLayout")
    dLayout.Padding = UDim.new(0, 2)
    dLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dLayout.Parent = drop

    local isOpen = false
    btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        TweenService:Create(drop, TweenInfo.new(0.2), {Size = isOpen and UDim2.new(1,0,0, list:GetChildren() and #list*25 + 5 or 20) or UDim2.new(1,0,0,0)}):Play()
    end)

    for _, opt in ipairs(list) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 25)
        optBtn.BackgroundTransparency = 1
        optBtn.Text = opt
        optBtn.TextColor3 = Color3.fromRGB(200,200,200)
        optBtn.TextSize = 13
        optBtn.Parent = drop

        optBtn.MouseButton1Click:Connect(function()
            btn.Text = name .. ": " .. opt
            isOpen = false
            TweenService:Create(drop, TweenInfo.new(0.2), {Size = UDim2.new(1,0,0,0)}):Play()
            if callback then callback(opt) end
        end)
    end
end

-- 5. 按键绑定 (Keybind)
function UILib:AddKeybind(container, name, defaultKey, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 80, 0, 25)
    btn.Position = UDim2.new(1, -80, 0.5, -12.5)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.Text = defaultKey.Name or defaultKey
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 13
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local binding = false
    btn.MouseButton1Click:Connect(function()
        binding = true
        btn.Text = "..."
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if binding then
            local keyName = input.KeyCode.Name
            if keyName == "Unknown" then return end
            btn.Text = keyName
            binding = false
            if callback then callback(input.KeyCode) end
        end
    end)
end

-- 6. 通知系统 (Notification)
local NotifyGui = Instance.new("ScreenGui")
NotifyGui.Name = "UILibNotif"
NotifyGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
local NotifyList = Instance.new("Frame")
NotifyList.Size = UDim2.new(0, 300, 1, 0)
NotifyList.Position = UDim2.new(1, -320, 0, 0)
NotifyList.BackgroundTransparency = 1
NotifyList.Parent = NotifyGui
local NotifyLayout = Instance.new("UIListLayout")
NotifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotifyLayout.Padding = UDim.new(0, 10)
NotifyLayout.Parent = NotifyList

function UILib:Notify(text, duration)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.1
    frame.Parent = NotifyList
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextSize = 14
    label.TextWrapped = true
    label.Parent = frame

    task.wait(duration or 3)
    TweenService:Create(frame, TweenInfo.new(0.5), {Size = UDim2.new(1, 0, 0, 0)}):Play()
    task.wait(0.5)
    frame:Destroy()
end

return UILib
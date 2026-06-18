-- ==========================================================================
-- 定制 UI 库 (StrictImageStyle)
-- 仅复刻原图“单面板、猫咪、二次元、绿条、开关”，无Tab页。
-- ==========================================================================
local CustomUILib = {}
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Camera = workspace.CurrentCamera

-- 1. 初始化背景
function CustomUILib:Init()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "CustomUIPanel"
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    ScreenGui.ResetOnSpawn = false

    -- 高斯模糊背景 (毛玻璃)
    local BlurView = Instance.new("ViewportFrame")
    BlurView.Size = UDim2.new(1, 0, 1, 0)
    BlurView.BackgroundTransparency = 1
    BlurView.ZIndex = 0
    BlurView.Parent = ScreenGui

    local BlurCam = Instance.new("Camera")
    BlurCam.Parent = BlurView
    BlurView.CurrentCamera = BlurCam
    Instance.new("BlurEffect", BlurCam).Size = 10

    RunService.RenderStepped:Connect(function()
        BlurCam.CFrame = Camera.CFrame
        BlurCam.FieldOfView = Camera.FieldOfView
    end)

    self.Gui = ScreenGui
    return self
end

-- 2. 创建主窗口（完全按照原图布局）
function CustomUILib:CreateWindow(config)
    -- 主面板 (半透明白灰色)
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 380, 0, 480)
    MainFrame.Position = UDim2.new(0.12, 0, 0.5, -240)
    MainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    MainFrame.BackgroundTransparency = 0.3
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = self.Gui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

    -- 【顶部绿色余额条】
    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 35)
    TopBar.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    TopBar.BackgroundTransparency = 0.4
    TopBar.Parent = MainFrame
    local TopText = Instance.new("TextLabel")
    TopText.Size = UDim2.new(1, 0, 1, 0)
    TopText.BackgroundTransparency = 1
    TopText.Text = "  " .. (config.Title or "20,000")
    TopText.TextColor3 = Color3.fromRGB(255, 255, 255)
    TopText.TextSize = 16
    TopText.TextXAlignment = Enum.TextXAlignment.Left
    TopText.Parent = TopBar

    -- 【左上角猫咪】(偏移到面板外，做出“趴在上面”的错觉)
    local CatImage = Instance.new("ImageLabel")
    CatImage.Size = UDim2.new(0, 80, 0, 80)
    CatImage.Position = UDim2.new(0.5, -190, 0.5, -275) -- 手动计算偏移
    CatImage.BackgroundTransparency = 1
    CatImage.Image = "rbxassetid://1234567890" -- 【重要：替换为你的猫咪ID】
    CatImage.ZIndex = 2
    CatImage.Parent = self.Gui

    -- 【右侧二次元人物】
    local CharImage = Instance.new("ImageLabel")
    CharImage.Size = UDim2.new(0, 120, 0, 200)
    CharImage.Position = UDim2.new(1, -130, 0.05, 0)
    CharImage.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    CharImage.BackgroundTransparency = 0.4
    CharImage.Image = "rbxassetid://9876543210" -- 【重要：替换为你的二次元人物ID】
    CharImage.Parent = MainFrame
    Instance.new("UICorner", CharImage).CornerRadius = UDim.new(0, 8)

    -- 【预留联动：二次元人物头上的ESP圈】
    local EspCircle = Instance.new("Frame")
    EspCircle.Size = UDim2.new(0, 40, 0, 40)
    EspCircle.Position = UDim2.new(0.5, -20, 0.08, 0)
    EspCircle.BackgroundTransparency = 1
    EspCircle.Visible = false
    EspCircle.Parent = CharImage
    local EspStroke = Instance.new("UIStroke")
    EspStroke.Color = Color3.fromRGB(255, 0, 0)
    EspStroke.Thickness = 2.5
    EspStroke.Parent = EspCircle
    Instance.new("UICorner", EspCircle).CornerRadius = UDim.new(1, 0)

    -- 【开关列表容器】(自动向下排列)
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(0.75, -10, 0.65, 0)
    ContentContainer.Position = UDim2.new(0, 10, 0.35, 0)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame
    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 6)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = ContentContainer

    -- --- 对外开放的 API 接口 ---
    local WindowAPI = {
        MainFrame = MainFrame,
        EspCircle = EspCircle,
        EspStroke = EspStroke,
        
        -- 生成纯开关组件
        CreateToggle = function(self, label, defaultState, callback)
            local Container = Instance.new("Frame")
            Container.Size = UDim2.new(1, 0, 0, 35)
            Container.BackgroundTransparency = 1
            Container.Parent = ContentContainer

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Size = UDim2.new(0, 180, 1, 0)
            TextLabel.BackgroundTransparency = 1
            TextLabel.Text = label
            TextLabel.TextColor3 = Color3.fromRGB(50, 50, 50) -- 文字使用深色
            TextLabel.TextSize = 14
            TextLabel.TextXAlignment = Enum.TextXAlignment.Left
            TextLabel.Parent = Container

            local SwitchBg = Instance.new("Frame")
            SwitchBg.Size = UDim2.new(0, 40, 0, 20)
            SwitchBg.Position = UDim2.new(1, -40, 0.5, -10)
            SwitchBg.BackgroundColor3 = defaultState and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(180, 180, 180)
            SwitchBg.Parent = Container
            Instance.new("UICorner", SwitchBg).CornerRadius = UDim.new(1, 0)

            local SwitchKnob = Instance.new("Frame")
            SwitchKnob.Size = UDim2.new(0, 16, 0, 16)
            SwitchKnob.Position = defaultState and UDim2.new(0, 22, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            SwitchKnob.BackgroundColor3 = defaultState and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(120, 120, 120)
            SwitchKnob.Parent = SwitchBg
            Instance.new("UICorner", SwitchKnob).CornerRadius = UDim.new(1, 0)

            local isOn = defaultState
            Container.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    isOn = not isOn
                    TweenService:Create(SwitchBg, TweenInfo.new(0.12), {
                        BackgroundColor3 = isOn and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(180, 180, 180)
                    }):Play()
                    TweenService:Create(SwitchKnob, TweenInfo.new(0.12), {
                        Position = isOn and UDim2.new(0, 22, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                        BackgroundColor3 = isOn and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(120, 120, 120)
                    }):Play()
                    if callback then callback(isOn) end
                end
            end)
        end,

        -- 外部控制人物圈显隐的方法
        SetEspVisible = function(self, visible)
            EspCircle.Visible = visible
        end,

        -- 外部控制人物圈颜色（自瞄锁定变绿）
        SetEspColor = function(self, color)
            EspStroke.Color = color
        end
    }

    return WindowAPI
end

-- 导出库
return CustomUILib

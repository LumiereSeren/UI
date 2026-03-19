local HoloLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/LumiereSeren/UI/refs/heads/main/ui%E5%BA%93"))()


local main = HoloLib.CreatePanel("完整功能演示", CFrame.new(-1.2, -0.2, -3.2), true)
main:SetVisible(true)


main:AddLabel("基础控件")
main:AddButton("点击测试", function() print("按钮点击") end)
main:AddToggle("开关测试", false, function(state) print("开关状态:", state) end)
main:AddSlider("数值测试", 0, 100, 50, function(v) print("滑块值:", v) end)
main:AddInput("输入框测试", function(t) print("输入:", t) end)


main:AddLabel("外部图片（可替换链接）")
main:AddImage("https://www.example.com/image.png", 150)  

main:AddLabel("外部视频（可替换链接）")
main:AddVideo("https://www.example.com/video.mp4", 200)   

main:AddLabel("外部音频（可替换链接）")
local music = main:AddAudio("https://www.example.com/music.mp3", false, true)
main:AddButton("播放音乐", function() music:Play() end)
main:AddButton("暂停音乐", function() music:Pause() end)


main:AddLabel("面板控制")
local sub = HoloLib.CreatePanel("子面板", CFrame.new(2.5, 0, -3.2), false)
sub:AddLabel("这是一个子面板")
sub:AddButton("关闭自己", function() sub:SetVisible(false) end)

main:AddButton("显示/隐藏子面板", function() sub:ToggleVisible() end)
main:AddButton("销毁当前面板", function() main:Destroy() end)
main:AddButton("销毁所有面板", HoloLib.DestroyAll)


local sep = Instance.new("Frame")
sep.Size = UDim2.new(1, -20, 0, 2)
sep.BackgroundColor3 = Color3.fromRGB(100,100,100)
sep.BackgroundTransparency = 0.5
Instance.new("UICorner", sep).CornerRadius = UDim.new(0,2)
main:AddElement(sep)

local customLabel = Instance.new("TextLabel")
customLabel.Size = UDim2.new(1,0,0,30)
customLabel.BackgroundTransparency = 1
customLabel.Text = "自定义样式"
customLabel.TextColor3 = Color3.fromRGB(255,200,100)
customLabel.TextSize = 16
customLabel.Font = Enum.Font.GothamBold
customLabel.TextXAlignment = Enum.TextXAlignment.Center
main:AddElement(customLabel)


getgenv().CleanHoloLib = HoloLib.DestroyAll
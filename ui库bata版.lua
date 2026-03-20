local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local function clamp(val, min, max) return math.max(min, math.min(max, val)) end
local request = (syn and syn.request) or (http and http.request) or http_request
local getasset = getcustomasset or getsynasset
local writefile = writefile
local readfile = readfile
local isfile = isfile
local isfolder = isfolder or function() return false end
local makefolder = makefolder or function() end
local listfiles = listfiles or function() return {} end

local CacheFolder = "HoloLibCache"
if request and getasset and writefile and not isfolder(CacheFolder) then pcall(makefolder, CacheFolder) end

local function downloadAsset(url, ext)
    if not request or not writefile then return nil end
    local success, res = pcall(function() return request({Url = url, Method = "GET"}) end)
    if success and res and res.StatusCode == 200 then
        local fileName = CacheFolder .. "/" .. HttpService:GenerateGUID(false) .. "." .. ext
        if pcall(writefile, fileName, res.Body) then
            return pcall(getasset, fileName) and getasset(fileName) or nil
        end
    end
    return nil
end

local function resolveMedia(input, ext)
    if type(input) ~= "string" then return ""
    if string.match(input, "^https?://") then return downloadAsset(input, ext) or "" end
    return input
end

local DefaultTheme = {
    GlassBG = Color3.fromRGB(25,25,28), GlassTransparency=0.35, Stroke=Color3.fromRGB(255,255,255), StrokeTransparency=0.88,
    Accent=Color3.fromRGB(10,132,255), ComponentBG=Color3.fromRGB(45,45,50), ComponentTransparency=0.4,
    TextPrimary=Color3.fromRGB(245,245,245), TextSecondary=Color3.fromRGB(150,150,155), Corner=UDim.new(0,16), ControlCorner=UDim.new(0,10)
}

local Panel = {}
Panel.__index = Panel

function Panel.new(title, offset, isMain, theme)
    local self = setmetatable({}, Panel)
    self.theme = theme or DefaultTheme
    self.title = title or "Holo Panel"
    self.isVisible = isMain or false
    self.isPinned = false
    self.pinnedPosition = Vector3.new()
    self.currentOffset = offset or CFrame.new(-1.2, -0.2, -3.2)
    self.connections = {}
    self.Part = Instance.new("Part")
    self.Part.Size = Vector3.new(3.2, 2.8, 0.01)
    self.Part.Anchored = true
    self.Part.CanCollide = false
    self.Part.Transparency = 1
    self.Part.Parent = Workspace
    table.insert(self.connections, self.Part)
    self.Surface = Instance.new("SurfaceGui")
    self.Surface.Adornee = self.Part
    self.Surface.Face = Enum.NormalId.Back
    self.Surface.AlwaysOnTop = true
    self.Surface.LightInfluence = 0
    self.Surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    self.Surface.PixelsPerStud = 100
    self.Surface.Enabled = self.isVisible
    self.Surface.Parent = CoreGui
    table.insert(self.connections, self.Surface)
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Size = UDim2.new(1,0,1,0)
    self.MainFrame.BackgroundColor3 = self.theme.GlassBG
    self.MainFrame.BackgroundTransparency = self.theme.GlassTransparency
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.Parent = self.Surface
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = self.theme.Corner
    uiCorner.Parent = self.MainFrame
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = self.theme.Stroke
    uiStroke.Transparency = self.theme.StrokeTransparency
    uiStroke.Thickness = 1.5
    uiStroke.Parent = self.MainFrame
    self.TopBar = Instance.new("Frame")
    self.TopBar.Size = UDim2.new(1,0,0,40)
    self.TopBar.BackgroundTransparency = 1
    self.TopBar.Parent = self.MainFrame
    self.DragBar = Instance.new("TextButton")
    self.DragBar.Size = UDim2.new(1,-50,1,0)
    self.DragBar.BackgroundTransparency = 1
    self.DragBar.Text = "  "..self.title
    self.DragBar.TextColor3 = self.theme.TextPrimary
    self.DragBar.Font = Enum.Font.GothamBold
    self.DragBar.TextSize = 16
    self.DragBar.TextXAlignment = Enum.TextXAlignment.Left
    self.DragBar.Parent = self.TopBar
    self.PinBtn = Instance.new("TextButton")
    self.PinBtn.Size = UDim2.new(0,30,0,30)
    self.PinBtn.Position = UDim2.new(1,-40,0,5)
    self.PinBtn.BackgroundColor3 = self.theme.ComponentBG
    self.PinBtn.BackgroundTransparency = self.theme.ComponentTransparency
    self.PinBtn.Text = "📍"
    self.PinBtn.TextSize = 16
    self.PinBtn.Parent = self.TopBar
    local pinCorner = Instance.new("UICorner")
    pinCorner.CornerRadius = UDim.new(1,0)
    pinCorner.Parent = self.PinBtn
    self.PinBtn.MouseButton1Click:Connect(function()
        self.isPinned = not self.isPinned
        if self.isPinned then
            self.pinnedPosition = self.Part.Position
            TweenService:Create(self.PinBtn, TweenInfo.new(0.3), {BackgroundColor3 = self.theme.Accent, BackgroundTransparency = 0}):Play()
            self.PinBtn.Text = "📌"
        else
            TweenService:Create(self.PinBtn, TweenInfo.new(0.3), {BackgroundColor3 = self.theme.ComponentBG, BackgroundTransparency = self.theme.ComponentTransparency}):Play()
            self.PinBtn.Text = "📍"
        end
    end)
    local isDragging, dragStart, dragOffset = false, Vector2.new(), CFrame.new()
    self.DragBar.InputBegan:Connect(function(input)
        if not self.isPinned and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isDragging = true; dragStart = input.Position; dragOffset = self.currentOffset
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            self.currentOffset = CFrame.new(clamp(dragOffset.X - delta.X*0.005, -6,6), clamp(dragOffset.Y - delta.Y*0.005, -3,4), dragOffset.Z)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDragging = false end
    end)
    self.Scroll = Instance.new("ScrollingFrame")
    self.Scroll.Size = UDim2.new(1,-30,1,-55)
    self.Scroll.Position = UDim2.new(0,15,0,40)
    self.Scroll.BackgroundTransparency = 1
    self.Scroll.ScrollBarThickness = 3
    self.Scroll.ScrollBarImageColor3 = self.theme.TextSecondary
    self.Scroll.CanvasSize = UDim2.new(0,0,0,0)
    self.Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.Scroll.Parent = self.MainFrame
    self.Layout = Instance.new("UIListLayout")
    self.Layout.Padding = UDim.new(0,12)
    self.Layout.SortOrder = Enum.SortOrder.LayoutOrder
    self.Layout.Parent = self.Scroll
    self.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local h = self.Layout.AbsoluteContentSize.Y + 60
        h = clamp(h, 280, 650)
        TweenService:Create(self.Part, TweenInfo.new(0.35), {Size = Vector3.new(3.2, h/100, 0.01)}):Play()
    end)
    self.followConn = RunService.RenderStepped:Connect(function(dt)
        if not self.isVisible then self.Part.CFrame = CFrame.new(0,-9999,0); return end
        if not self.isPinned then
            self.Part.CFrame = self.Part.CFrame:Lerp(Camera.CFrame * self.currentOffset, dt*15)
        else
            local targetRot = CFrame.lookAt(self.pinnedPosition, Camera.CFrame.Position) * CFrame.Angles(0, math.pi, 0)
            self.Part.CFrame = self.Part.CFrame:Lerp(targetRot, dt*10)
        end
    end)
    table.insert(self.connections, self.followConn)
    return self
end

function Panel:SetVisible(state) self.isVisible = state; self.Surface.Enabled = state; if state and self.isPinned then self.isPinned=false; self.PinBtn.Text="📍"; TweenService:Create(self.PinBtn, TweenInfo.new(0.3), {BackgroundColor3=self.theme.ComponentBG, BackgroundTransparency=self.theme.ComponentTransparency}):Play(); self.Part.CFrame = Camera.CFrame * self.currentOffset end end
function Panel:ToggleVisible() self:SetVisible(not self.isVisible) end
function Panel:Destroy() for _,obj in ipairs(self.connections) do if obj and obj.Destroy then pcall(function() obj:Destroy() end) elseif obj and obj.Disconnect then pcall(function() obj:Disconnect() end) end end; self.connections={} end
function Panel:AddElement(el) el.Parent = self.Scroll; return el end
function Panel:AddLabel(text) local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,20); lbl.BackgroundTransparency=1; lbl.Text=text; lbl.TextColor3=self.theme.TextSecondary; lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=self.Scroll; return lbl end
function Panel:AddButton(text, cb) local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,0,40); btn.BackgroundColor3=self.theme.ComponentBG; btn.BackgroundTransparency=self.theme.ComponentTransparency; btn.Text=text; btn.TextColor3=self.theme.TextPrimary; btn.Font=Enum.Font.GothamMedium; btn.TextSize=14; btn.Parent=self.Scroll; Instance.new("UICorner", btn).CornerRadius=self.theme.ControlCorner; btn.MouseButton1Click:Connect(function() TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3=self.theme.Accent}):Play(); pcall(cb); task.wait(0.1); TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3=self.theme.ComponentBG}):Play() end); return btn end
function Panel:AddToggle(text, def, cb) local state=def or false; local frm=Instance.new("TextButton"); frm.Size=UDim2.new(1,0,0,45); frm.BackgroundColor3=self.theme.ComponentBG; frm.BackgroundTransparency=self.theme.ComponentTransparency+0.2; frm.Text=""; frm.Parent=self.Scroll; Instance.new("UICorner", frm).CornerRadius=self.theme.ControlCorner; local title=Instance.new("TextLabel"); title.Size=UDim2.new(0.7,0,1,0); title.Position=UDim2.new(0,15,0,0); title.BackgroundTransparency=1; title.Text=text; title.TextColor3=self.theme.TextPrimary; title.Font=Enum.Font.GothamMedium; title.TextSize=14; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=frm; local capsule=Instance.new("Frame"); capsule.Size=UDim2.new(0,50,0,26); capsule.Position=UDim2.new(1,-65,0.5,-13); capsule.BackgroundColor3=state and self.theme.Accent or Color3.fromRGB(80,80,85); capsule.Parent=frm; Instance.new("UICorner", capsule).CornerRadius=UDim.new(1,0); local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,22,0,22); knob.Position=state and UDim2.new(1,-24,0.5,-11) or UDim2.new(0,2,0.5,-11); knob.BackgroundColor3=Color3.fromRGB(255,255,255); knob.Parent=capsule; Instance.new("UICorner", knob).CornerRadius=UDim.new(1,0); local function update() state=not state; local targetBg=state and self.theme.Accent or Color3.fromRGB(80,80,85); local targetPos=state and UDim2.new(1,-24,0.5,-11) or UDim2.new(0,2,0.5,-11); TweenService:Create(capsule, TweenInfo.new(0.25), {BackgroundColor3=targetBg}):Play(); TweenService:Create(knob, TweenInfo.new(0.25), {Position=targetPos}):Play(); pcall(cb, state) end; frm.MouseButton1Click:Connect(update); pcall(cb, state); return frm end
function Panel:AddSlider(text, min, max, def, cb) local val=clamp(def or min, min, max); local frm=Instance.new("Frame"); frm.Size=UDim2.new(1,0,0,55); frm.BackgroundColor3=self.theme.ComponentBG; frm.BackgroundTransparency=self.theme.ComponentTransparency+0.2; frm.Parent=self.Scroll; Instance.new("UICorner", frm).CornerRadius=self.theme.ControlCorner; local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-30,0,25); title.Position=UDim2.new(0,15,0,5); title.BackgroundTransparency=1; title.Text=text.." : "..tostring(val); title.TextColor3=self.theme.TextPrimary; title.Font=Enum.Font.GothamMedium; title.TextSize=13; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=frm; local track=Instance.new("TextButton"); track.Size=UDim2.new(1,-30,0,4); track.Position=UDim2.new(0,15,0,38); track.BackgroundColor3=Color3.fromRGB(80,80,85); track.Text=""; track.Parent=frm; Instance.new("UICorner", track).CornerRadius=UDim.new(1,0); local fill=Instance.new("Frame"); fill.Size=UDim2.new((val-min)/(max-min),0,1,0); fill.BackgroundColor3=self.theme.Accent; fill.Parent=track; Instance.new("UICorner", fill).CornerRadius=UDim.new(1,0); local thumb=Instance.new("Frame"); thumb.Size=UDim2.new(0,16,0,16); thumb.Position=UDim2.new(1,-8,0.5,-8); thumb.BackgroundColor3=Color3.fromRGB(255,255,255); thumb.Parent=fill; Instance.new("UICorner", thumb).CornerRadius=UDim.new(1,0); local dragging=false; local function upd(inp) local x=clamp(inp.Position.X-track.AbsolutePosition.X,0,track.AbsoluteSize.X); local per=x/track.AbsoluteSize.X; val=min+(max-min)*per; title.Text=text.." : "..string.format("%.1f",val); fill.Size=UDim2.new(per,0,1,0); pcall(cb, val) end; track.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=true; upd(inp) end end); UserInputService.InputChanged:Connect(function(inp) if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then upd(inp) end end); UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end end); pcall(cb, val); return frm end
function Panel:AddInput(placeholder, cb) local frm=Instance.new("Frame"); frm.Size=UDim2.new(1,0,0,40); frm.BackgroundColor3=self.theme.ComponentBG; frm.BackgroundTransparency=self.theme.ComponentTransparency+0.2; frm.Parent=self.Scroll; Instance.new("UICorner", frm).CornerRadius=self.theme.ControlCorner; local box=Instance.new("TextBox"); box.Size=UDim2.new(1,-20,1,0); box.Position=UDim2.new(0,10,0,0); box.BackgroundTransparency=1; box.PlaceholderText=placeholder; box.Text=""; box.TextColor3=self.theme.TextPrimary; box.PlaceholderColor3=self.theme.TextSecondary; box.Font=Enum.Font.GothamMedium; box.TextSize=13; box.TextXAlignment=Enum.TextXAlignment.Left; box.ClearTextOnFocus=false; box.Parent=frm; box.FocusLost:Connect(function(enter) if enter then pcall(cb, box.Text) end end); return box end
function Panel:AddImage(src, h) h=h or 180; local frm=Instance.new("Frame"); frm.Size=UDim2.new(1,0,0,h); frm.BackgroundTransparency=1; frm.ClipsDescendants=true; frm.Parent=self.Scroll; local img=Instance.new("ImageLabel"); img.Size=UDim2.new(1,0,1,0); img.BackgroundTransparency=1; img.ScaleType=Enum.ScaleType.Fit; img.Image=resolveMedia(src,"png"); img.Parent=frm; Instance.new("UICorner", img).CornerRadius=self.theme.ControlCorner; return img end
function Panel:AddVideo(src, h) h=h or 180; local frm=Instance.new("Frame"); frm.Size=UDim2.new(1,0,0,h); frm.BackgroundTransparency=1; frm.ClipsDescendants=true; frm.Parent=self.Scroll; local vid=Instance.new("VideoFrame"); vid.Size=UDim2.new(1,0,1,0); vid.BackgroundColor3=Color3.fromRGB(0,0,0); vid.Looped=true; vid.Playing=true; vid.Video=resolveMedia(src,"mp4"); vid.Parent=frm; Instance.new("UICorner", vid).CornerRadius=self.theme.ControlCorner; return vid end
function Panel:AddAudio(src, autoplay, loop) local snd=Instance.new("Sound"); snd.Volume=0.5; snd.Looped=loop or false; snd.SoundId=resolveMedia(src,"mp3"); snd.Parent=self.Surface; if autoplay then snd:Play() end; return snd end
function Panel:AddColorPicker(defaultColor, cb) local color=defaultColor or Color3.fromRGB(255,255,255); local frm=Instance.new("Frame"); frm.Size=UDim2.new(1,0,0,100); frm.BackgroundColor3=self.theme.ComponentBG; frm.BackgroundTransparency=self.theme.ComponentTransparency+0.2; frm.Parent=self.Scroll; Instance.new("UICorner", frm).CornerRadius=self.theme.ControlCorner; local preview=Instance.new("Frame"); preview.Size=UDim2.new(0,40,0,40); preview.Position=UDim2.new(0,5,0,5); preview.BackgroundColor3=color; preview.Parent=frm; Instance.new("UICorner", preview).CornerRadius=UDim.new(0,6); local rSlider=Panel.AddSlider(self,"R",0,255,color.R*255,function(v) color=Color3.fromRGB(v,color.G*255,color.B*255); preview.BackgroundColor3=color; pcall(cb,color) end); rSlider.Parent=frm; rSlider.Size=UDim2.new(1,-50,0,35); rSlider.Position=UDim2.new(0,50,0,5); local gSlider=Panel.AddSlider(self,"G",0,255,color.G*255,function(v) color=Color3.fromRGB(color.R*255,v,color.B*255); preview.BackgroundColor3=color; pcall(cb,color) end); gSlider.Parent=frm; gSlider.Size=UDim2.new(1,-50,0,35); gSlider.Position=UDim2.new(0,50,0,45); local bSlider=Panel.AddSlider(self,"B",0,255,color.B*255,function(v) color=Color3.fromRGB(color.R*255,color.G*255,v); preview.BackgroundColor3=color; pcall(cb,color) end); bSlider.Parent=frm; bSlider.Size=UDim2.new(1,-50,0,35); bSlider.Position=UDim2.new(0,50,0,85); return frm end
function Panel:AddDropdown(options, default, cb) local container=Instance.new("Frame"); container.Size=UDim2.new(1,0,0,40); container.BackgroundColor3=self.theme.ComponentBG; container.BackgroundTransparency=self.theme.ComponentTransparency+0.2; container.Parent=self.Scroll; Instance.new("UICorner", container).CornerRadius=self.theme.ControlCorner; local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.Text=default or options[1]; btn.TextColor3=self.theme.TextPrimary; btn.Font=Enum.Font.GothamMedium; btn.TextSize=14; btn.Parent=container; local list=Instance.new("Frame"); list.Size=UDim2.new(1,0,0,0); list.BackgroundColor3=self.theme.ComponentBG; list.BackgroundTransparency=0; list.ClipsDescendants=true; list.Parent=container; local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,2); layout.Parent=list; local function toggle() local h=layout.AbsoluteContentSize.Y; TweenService:Create(list, TweenInfo.new(0.2), {Size=UDim2.new(1,0,0,h)}):Play() end; btn.MouseButton1Click:Connect(toggle); for _,opt in ipairs(options) do local item=Instance.new("TextButton"); item.Size=UDim2.new(1,0,0,30); item.Text=opt; item.TextColor3=self.theme.TextPrimary; item.Font=Enum.Font.GothamMedium; item.TextSize=12; item.Parent=list; item.MouseButton1Click:Connect(function() btn.Text=opt; toggle(); pcall(cb, opt) end); end; return container end
function Panel:AddCheckbox(text, def, cb) local state=def or false; local frm=Instance.new("Frame"); frm.Size=UDim2.new(1,0,0,35); frm.BackgroundColor3=self.theme.ComponentBG; frm.BackgroundTransparency=self.theme.ComponentTransparency+0.2; frm.Parent=self.Scroll; Instance.new("UICorner", frm).CornerRadius=self.theme.ControlCorner; local check=Instance.new("Frame"); check.Size=UDim2.new(0,20,0,20); check.Position=UDim2.new(0,5,0.5,-10); check.BackgroundColor3=state and self.theme.Accent or Color3.fromRGB(80,80,85); check.Parent=frm; Instance.new("UICorner", check).CornerRadius=UDim.new(0,4); local label=Instance.new("TextLabel"); label.Size=UDim2.new(1,-30,1,0); label.Position=UDim2.new(0,30,0,0); label.BackgroundTransparency=1; label.Text=text; label.TextColor3=self.theme.TextPrimary; label.Font=Enum.Font.GothamMedium; label.TextSize=14; label.Parent=frm; local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Parent=frm; btn.MouseButton1Click:Connect(function() state=not state; check.BackgroundColor3=state and self.theme.Accent or Color3.fromRGB(80,80,85); pcall(cb, state) end); return frm end
function Panel:AddKeybind(defaultKey, cb) local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,0,35); btn.BackgroundColor3=self.theme.ComponentBG; btn.BackgroundTransparency=self.theme.ComponentTransparency+0.2; btn.Text=defaultKey or "未设置"; btn.TextColor3=self.theme.TextPrimary; btn.Font=Enum.Font.GothamMedium; btn.TextSize=14; btn.Parent=self.Scroll; Instance.new("UICorner", btn).CornerRadius=self.theme.ControlCorner; local listening=false; local conn; btn.MouseButton1Click:Connect(function() listening=true; btn.Text="按下任意键..."; if conn then conn:Disconnect() end; conn=UserInputService.InputBegan:Connect(function(inp,gp) if gp or not listening then return end; local k=inp.KeyCode.Name; btn.Text=k; listening=false; conn:Disconnect(); pcall(cb, k) end) end); return btn end
function Panel:AddProgressBar(width, height, max, val) local frm=Instance.new("Frame"); frm.Size=UDim2.new(0,width,0,height); frm.BackgroundColor3=Color3.fromRGB(80,80,85); frm.Parent=self.Scroll; Instance.new("UICorner", frm).CornerRadius=UDim.new(1,0); local fill=Instance.new("Frame"); fill.Size=UDim2.new(val/max,0,1,0); fill.BackgroundColor3=self.theme.Accent; fill.Parent=frm; Instance.new("UICorner", fill).CornerRadius=UDim.new(1,0); return {frame=frm, fill=fill, update=function(v) fill.Size=UDim2.new(v/max,0,1,0) end} end
function Panel:AddSeparator() local sep=Instance.new("Frame"); sep.Size=UDim2.new(1,-20,0,2); sep.BackgroundColor3=Color3.fromRGB(100,100,100); sep.BackgroundTransparency=0.5; sep.Parent=self.Scroll; Instance.new("UICorner", sep).CornerRadius=UDim.new(0,2); return sep end

local HoloLib = {_allPanels={}}

function HoloLib.CreatePanel(title, offset, isMain, theme) local p=Panel.new(title, offset, isMain, theme); table.insert(HoloLib._allPanels, p); return p end
function HoloLib.DestroyAll() for _,p in ipairs(HoloLib._allPanels) do p:Destroy() end; HoloLib._allPanels={} end
function HoloLib.SetGlobalTheme(theme) DefaultTheme=theme end

-- 扩展功能 (30+)
function HoloLib.SetWalkSpeed(speed) if Humanoid then Humanoid.WalkSpeed = speed end end
function HoloLib.SetJumpPower(power) if Humanoid then Humanoid.JumpPower = power end end
function HoloLib.SetGravity(gravity) Workspace.Gravity = gravity end
function HoloLib.ToggleGodMode(state) if state then Humanoid.MaxHealth = math.huge; Humanoid.Health = math.huge else Humanoid.MaxHealth = 100; Humanoid.Health = 100 end end
local flying, flySpeed, flyConn = false, 50, nil
function HoloLib.ToggleFly(state, speed) if speed then flySpeed = speed end; flying = state; if flying then if flyConn then flyConn:Disconnect() end; flyConn = RunService.Heartbeat:Connect(function() if not flying or not RootPart then return end; local d = Vector3.new((UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)-(UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0), (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0)-(UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0), (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)-(UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)); if d.Magnitude>0 then d=d.Unit; local newPos = RootPart.Position + (Camera.CFrame.LookVector*d.Z + Camera.CFrame.RightVector*d.X)*flySpeed + Vector3.new(0,d.Y,0)*flySpeed; RootPart.CFrame = CFrame.new(newPos) end end) else if flyConn then flyConn:Disconnect(); flyConn=nil end end end
local noclipConn = nil
function HoloLib.ToggleNoclip(state) if state then if noclipConn then noclipConn:Disconnect() end; noclipConn = RunService.Stepped:Connect(function() if Character then for _,p in pairs(Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end end) else if noclipConn then noclipConn:Disconnect(); noclipConn=nil end; if Character then for _,p in pairs(Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end end end
local infJumpConn = nil
function HoloLib.ToggleInfJump(state) if state then if not infJumpConn then infJumpConn = UserInputService.JumpRequest:Connect(function() if Humanoid and Humanoid.Health>0 then Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end end) end else if infJumpConn then infJumpConn:Disconnect(); infJumpConn=nil end end end
function HoloLib.SetFOV(fov) Camera.FieldOfView = fov end
function HoloLib.SetAmbientLight(r,g,b) Lighting.Ambient = Color3.fromRGB(r,g,b) end
function HoloLib.SetTimeOfDay(hour) Lighting.ClockTime = hour end
function HoloLib.KillAllNPCs() for _,v in pairs(Workspace:GetDescendants()) do if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(v) then v:FindFirstChildOfClass("Humanoid").Health = 0 end end end
function HoloLib.TeleportToPlayer(name) local p = Players:FindFirstChild(name); if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then RootPart.CFrame = p.Character.HumanoidRootPart.CFrame end end
function HoloLib.GetPlayerList() local list={}; for _,p in ipairs(Players:GetPlayers()) do table.insert(list, p.Name) end; return list end
function HoloLib.Notify(title, text, dur) StarterGui:SetCore("SendNotification", {Title=title, Text=text, Duration=dur or 3}) end
function HoloLib.TakeScreenshot() if not writefile then return nil end; local id=HttpService:GenerateGUID(false); local path=CacheFolder.."/screenshot_"..id..".png"; local suc,err=pcall(function() return saveplace(path) end); if suc then return getasset(path) else return nil end end
function HoloLib.GetServerId() return game.JobId end
function HoloLib.HopServer() local suc,res=pcall(function() return request({Url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=10"}) end); if suc and res and res.StatusCode==200 then local data=HttpService:JSONDecode(res.Body); if data and data.data and #data.data>0 then for _,s in ipairs(data.data) do if s.id~=game.JobId then TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id) break end end end end end
function HoloLib.ServerHop() HoloLib.HopServer() end
function HoloLib.GetCurrentServerPlayers() local list={}; for _,p in ipairs(Players:GetPlayers()) do table.insert(list, p.Name) end; return list end
function HoloLib.SetPlayerSize(scale) for _,p in pairs(Character:GetDescendants()) do if p:IsA("BasePart") then p.Size = p.Size * scale end end end
function HoloLib.SetPlayerTransparency(trans) for _,p in pairs(Character:GetDescendants()) do if p:IsA("BasePart") then p.Transparency = trans end end end
function HoloLib.SetPlayerColor(r,g,b) for _,p in pairs(Character:GetDescendants()) do if p:IsA("BasePart") then p.Color = Color3.fromRGB(r,g,b) end end end
function HoloLib.SetCameraDistance(dist) LocalPlayer.CameraMaxZoomDistance = dist end
function HoloLib.SetCameraMode(mode) if mode=="first" then LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson else LocalPlayer.CameraMode = Enum.CameraMode.Classic end end
function HoloLib.GetSystemTime() return os.date("%Y-%m-%d %H:%M:%S") end
function HoloLib.GetFPS() return workspace:GetRealPhysicsFPS() end
function HoloLib.GetPing() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end
function HoloLib.GetMemoryUsage() return game:GetService("Stats").Memory.StudioMemoryUsage:GetValue() end
function HoloLib.SaveConfig(configName, data) if not writefile then return false end; local path=CacheFolder.."/config_"..configName..".json"; local suc=pcall(writefile, path, HttpService:JSONEncode(data)); return suc end
function HoloLib.LoadConfig(configName) if not readfile or not isfile then return nil end; local path=CacheFolder.."/config_"..configName..".json"; if not isfile(path) then return nil end; local suc,res=pcall(function() return HttpService:JSONDecode(readfile(path)) end); return suc and res or nil end
function HoloLib.ListConfigs() if not listfiles then return {} end; local files=listfiles(CacheFolder); local configs={}; for _,f in ipairs(files) do if f:match("config_.*%.json") then table.insert(configs, f:match("config_(.*)%.json")) end end; return configs end
function HoloLib.DeleteConfig(configName) if not isfile then return false end; local path=CacheFolder.."/config_"..configName..".json"; if isfile(path) then return pcall(delfile, path) end; return false end
function HoloLib.CreateHotkey(key, action) local conn; conn=UserInputService.InputBegan:Connect(function(inp,gp) if gp then return end; if inp.KeyCode.Name==key then pcall(action) end end); return conn end
function HoloLib.RemoveHotkey(conn) if conn then conn:Disconnect() end end
function HoloLib.RunCommand(cmd) if type(cmd)=="string" then loadstring(cmd)() end end
function HoloLib.DoAfterDelay(delay, func) task.wait(delay); pcall(func) end
function HoloLib.RepeatEvery(interval, func) local conn; conn=RunService.Heartbeat:Connect(function(dt) local elapsed=0; while elapsed<interval do elapsed=elapsed+dt; end; pcall(func); elapsed=0 end); return conn end
function HoloLib.StopRepeat(conn) if conn then conn:Disconnect() end end
function HoloLib.GetCharacter() return Character end
function HoloLib.GetHumanoid() return Humanoid end
function HoloLib.GetRootPart() return RootPart end
function HoloLib.GetCamera() return Camera end
function HoloLib.GetWorkspace() return Workspace end
function HoloLib.GetLighting() return Lighting end
function HoloLib.GetPlayers() return Players end
function HoloLib.GetLocalPlayer() return LocalPlayer end
function HoloLib.IsLoaded() return Character and Humanoid and RootPart end
function HoloLib.WaitForCharacter() return LocalPlayer.CharacterAdded:Wait() end
function HoloLib.ResetCharacter() Humanoid.Health=0 end
function HoloLib.Revive() Humanoid.Health=Humanoid.MaxHealth end
function HoloLib.SetHealth(health) Humanoid.Health=health end
function HoloLib.SetMaxHealth(max) Humanoid.MaxHealth=max end
function HoloLib.GetHealth() return Humanoid.Health end
function HoloLib.GetMaxHealth() return Humanoid.MaxHealth end
function HoloLib.AddHealth(amount) Humanoid.Health=Humanoid.Health+amount end
function HoloLib.AddMaxHealth(amount) Humanoid.MaxHealth=Humanoid.MaxHealth+amount end
function HoloLib.SetWalkspeed(speed) Humanoid.WalkSpeed=speed end
function HoloLib.GetWalkspeed() return Humanoid.WalkSpeed end
function HoloLib.SetJumpPower(power) Humanoid.JumpPower=power end
function HoloLib.GetJumpPower() return Humanoid.JumpPower end
function HoloLib.SetGravity(gravity) Workspace.Gravity=gravity end
function HoloLib.GetGravity() return Workspace.Gravity end
function HoloLib.SetTime(hour) Lighting.ClockTime=hour end
function HoloLib.GetTime() return Lighting.ClockTime end
function HoloLib.SetFog(endVal) Lighting.FogEnd=endVal end
function HoloLib.SetFogStart(startVal) Lighting.FogStart=startVal end
function HoloLib.SetFogColor(r,g,b) Lighting.FogColor=Color3.fromRGB(r,g,b) end
function HoloLib.SetSkybox(up, down, left, right, front, back) local sky=Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky",Lighting); if up then sky.SkyboxUp=up end; if down then sky.SkyboxDn=down end; if left then sky.SkyboxLf=left end; if right then sky.SkyboxRt=right end; if front then sky.SkyboxFt=front end; if back then sky.SkyboxBk=back end end
function HoloLib.SetAmbient(r,g,b) Lighting.Ambient=Color3.fromRGB(r,g,b) end
function HoloLib.SetOutdoorAmbient(r,g,b) Lighting.OutdoorAmbient=Color3.fromRGB(r,g,b) end
function HoloLib.SetBrightness(brightness) Lighting.Brightness=brightness end
function HoloLib.SetShadowSoftness(softness) Lighting.ShadowSoftness=softness end
function HoloLib.SetTechnology(tech) Lighting.Technology=tech end
function HoloLib.SetExposureCompensation(comp) Lighting.ExposureCompensation=comp end
function HoloLib.SetGlobalShadows(state) Lighting.GlobalShadows=state end
function HoloLib.SetTerrainWater(enable) Workspace.Terrain.WaterWaveSize=enable and 10 or 0 end
function HoloLib.SetTerrainDecoration(enable) Workspace.Terrain.Decoration=enable end
function HoloLib.GetPlayerCount() return #Players:GetPlayers() end
function HoloLib.GetPlayerFromUserId(id) return Players:GetPlayerByUserId(id) end
function HoloLib.GetPlayerFromName(name) return Players:FindFirstChild(name) end
function HoloLib.IsPlayerOnline(name) return Players:FindFirstChild(name)~=nil end
function HoloLib.KickPlayer(name) local p=Players:FindFirstChild(name); if p then p:Kick() end end
function HoloLib.TeleportToPlace(placeId) TeleportService:Teleport(placeId) end
function HoloLib.TeleportToInstance(placeId, jobId) TeleportService:TeleportToPlaceInstance(placeId, jobId) end
function HoloLib.QueueTeleport(placeId) TeleportService:Teleport(placeId, LocalPlayer) end
function HoloLib.GetAssetIdFromUrl(url) local id=url:match("assetid=(%d+)"); return id and tonumber(id) or nil end
function HoloLib.GetMarketplaceInfo(assetId) local suc,res=pcall(function() return MarketplaceService:GetProductInfo(assetId) end); return suc and res or nil end
function HoloLib.PromptPurchase(assetId) MarketplaceService:PromptPurchase(LocalPlayer, assetId) end
function HoloLib.PromptGamepass(gamepassId) MarketplaceService:PromptGamePassPurchase(LocalPlayer, gamepassId) end
function HoloLib.GetRobux() local suc,res=pcall(function() return MarketplaceService:GetRobuxBalance() end); return suc and res or 0 end
function HoloLib.GetUserMembership() return LocalPlayer.MembershipType end
function HoloLib.GetUserAge() return LocalPlayer.AccountAge end
function HoloLib.GetUserId() return LocalPlayer.UserId end
function HoloLib.GetUserName() return LocalPlayer.Name end
function HoloLib.GetDisplayName() return LocalPlayer.DisplayName end
function HoloLib.SetDisplayName(name) LocalPlayer.DisplayName=name end
function HoloLib.SetCharacterAppearance(assetId) LocalPlayer.CharacterAppearance=assetId end
function HoloLib.GetCharacterAppearance() return LocalPlayer.CharacterAppearance end
function HoloLib.SetTeam(teamName) local t=Teams:FindFirstChild(teamName); if t then LocalPlayer.Team=t end end
function HoloLib.GetTeam() return LocalPlayer.Team end
function HoloLib.SetChatEnabled(state) local chat=TextService:FindFirstChild("Chat"); if chat then chat.Enabled=state end end
function HoloLib.GetChatEnabled() local chat=TextService:FindFirstChild("Chat"); return chat and chat.Enabled or false end
function HoloLib.SetGuiEnabled(guiName, state) local gui=CoreGui:FindFirstChild(guiName); if gui then gui.Enabled=state end end
function HoloLib.GetGuiEnabled(guiName) local gui=CoreGui:FindFirstChild(guiName); return gui and gui.Enabled or false end
function HoloLib.SetMouseIconVisible(state) UserInputService.MouseIconEnabled=state end
function HoloLib.GetMouseLocation() return UserInputService:GetMouseLocation() end
function HoloLib.IsKeyDown(key) return UserInputService:IsKeyDown(Enum.KeyCode[key]) end
function HoloLib.IsMouseButtonDown(button) return UserInputService:IsMouseButtonPressed(button) end
function HoloLib.GetScreenSize() return Camera.ViewportSize end
function HoloLib.GetWorldPointFromScreen(x,y) local ray=Camera:ScreenPointToRay(x,y); return ray.Origin+ray.Direction*100 end
function HoloLib.Raycast(origin, direction, ignore) local params=RaycastParams.new(); if ignore then params.FilterDescendantsInstances=ignore end; return Workspace:Raycast(origin, direction, params) end
function HoloLib.FindPartOnRay(origin, direction, ignore) local ray=Ray.new(origin, direction); return Workspace:FindPartOnRayWithIgnoreList(ray, ignore or {}) end
function HoloLib.GetPartsInRadius(center, radius) local parts={}; local region=Region3.new(center-Vector3.new(radius,radius,radius), center+Vector3.new(radius,radius,radius)); for _,p in ipairs(Workspace:FindPartsInRegion3(region, nil, 1000)) do table.insert(parts, p) end; return parts end
function HoloLib.GetNearestPart(center, radius, ignore) local nearest,dist=nil,math.huge; for _,p in ipairs(Workspace:GetDescendants()) do if p:IsA("BasePart") and p~=ignore then local d=(p.Position-center).Magnitude; if d<dist and d<radius then nearest=p; dist=d end end end; return nearest end
function HoloLib.GetNearestPlayer(center, radius) local nearest,dist=nil,math.huge; for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then local d=(p.Character.HumanoidRootPart.Position-center).Magnitude; if d<dist and d<radius then nearest=p; dist=d end end end; return nearest end
function HoloLib.GetDistanceBetween(pos1, pos2) return (pos1-pos2).Magnitude end
function HoloLib.Lerp(a,b,t) return a+(b-a)*t end
function HoloLib.ColorLerp(c1,c2,t) return Color3.new(c1.R+(c2.R-c1.R)*t, c1.G+(c2.G-c1.G)*t, c1.B+(c2.B-c1.B)*t) end
function HoloLib.StringToColor(str) local h=0; for i=1,#str do h=bit32.bxor(h,string.byte(str,i)) end; return Color3.fromHSV(h%360/360,0.8,0.8) end
function HoloLib.RandomColor() return Color3.fromHSV(math.random(),1,1) end
function HoloLib.FormatNumber(num) if num>=1e6 then return string.format("%.1fM", num/1e6) elseif num>=1e3 then return string.format("%.1fK", num/1e3) else return tostring(num) end end
function HoloLib.FormatTime(sec) local h=math.floor(sec/3600); local m=math.floor((sec%3600)/60); local s=math.floor(sec%60); return string.format("%02d:%02d:%02d", h,m,s) end
function HoloLib.TableToString(t) return HttpService:JSONEncode(t) end
function HoloLib.StringToTable(s) return HttpService:JSONDecode(s) end
function HoloLib.ShallowCopy(t) local r={}; for k,v in pairs(t) do r[k]=v end; return r end
function HoloLib.DeepCopy(t) local r={}; for k,v in pairs(t) do if type(v)=="table" then r[k]=HoloLib.DeepCopy(v) else r[k]=v end end; return r end
function HoloLib.MergeTables(t1,t2) for k,v in pairs(t2) do t1[k]=v end; return t1 end
function HoloLib.TableFind(t,val) for k,v in pairs(t) do if v==val then return k end end; return nil end
function HoloLib.TableContains(t,val) return HoloLib.TableFind(t,val)~=nil end
function HoloLib.TableRemoveValue(t,val) for k,v in pairs(t) do if v==val then table.remove(t,k); return true end end; return false end
function HoloLib.TableCount(t) local c=0; for _,_ in pairs(t) do c=c+1 end; return c end
function HoloLib.TableKeys(t) local keys={}; for k,_ in pairs(t) do table.insert(keys,k) end; return keys end
function HoloLib.TableValues(t) local vals={}; for _,v in pairs(t) do table.insert(vals,v) end; return vals end
function HoloLib.TableShuffle(t) for i=#t,2,-1 do local j=math.random(i); t[i],t[j]=t[j],t[i] end; return t end
function HoloLib.TableRandom(t) if #t==0 then return nil end; return t[math.random(#t)] end
function HoloLib.TableSort(t, comp) table.sort(t, comp); return t end

getgenv().CleanHoloLib = HoloLib.DestroyAll
return HoloLib
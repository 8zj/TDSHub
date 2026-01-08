local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local pGui = LocalPlayer:WaitForChild("PlayerGui")

local PickHubLibrary = {
    Config = {
        ANTIAFK = false,
        AutoDj = false,
        AutoCommander = false,
        TimeScale = false,
        AutoSkip = false,
        AntiLag = true,
        AutoPickups = false,
        SendWebhook = false
    },
    Flags = {} -- For internal UI state if needed
}

--// 1. Configuration System (Saves Positions & Settings)
local ConfigFileName = "PickHub_UI_Config.json"
local UIConfig = {
    Positions = {},
    Settings = PickHubLibrary.Config
}

local function LoadConfig()
    if isfile and isfile(ConfigFileName) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(ConfigFileName)) end)
        if success and decoded then
            -- Load Positions
            if decoded.Positions then UIConfig.Positions = decoded.Positions end
            -- Load Settings
            if decoded.Settings then 
                for k, v in pairs(decoded.Settings) do
                    PickHubLibrary.Config[k] = v
                end
                UIConfig.Settings = PickHubLibrary.Config
            end
        end
    end
end

local function SaveConfig()
    UIConfig.Settings = PickHubLibrary.Config
    if writefile then
        writefile(ConfigFileName, HttpService:JSONEncode(UIConfig))
    end
end

-- Load immediately
LoadConfig()

--// Cleanup previous temp UI
for _, ui in ipairs(pGui:GetChildren()) do
    if ui.Name == "PickHub_Temp_UI" then ui:Destroy() end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PickHub_Temp_UI"
ScreenGui.Parent = pGui
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false

--// 2. Draggable Logic
local function MakeDraggable(frame, id)
    local dragToggle, dragStart, startPos
    local dragInput

    -- Restore saved position if exists
    if UIConfig.Positions[id] then
        local saved = UIConfig.Positions[id]
        frame.Position = UDim2.new(saved.X.Scale, saved.X.Offset, saved.Y.Scale, saved.Y.Offset)
    end

    local function update(input)
        local delta = input.Position - dragStart
        local newPos = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
        frame.Position = newPos
    end

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragToggle = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragToggle = false
                    -- Save position on drag end
                    UIConfig.Positions[id] = {
                        X = {Scale = frame.Position.X.Scale, Offset = frame.Position.X.Offset},
                        Y = {Scale = frame.Position.Y.Scale, Offset = frame.Position.Y.Offset}
                    }
                    SaveConfig()
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragToggle then
            update(input)
        end
    end)
end

--// 3. UI Helper Functions (Polished Skeet Style)
local function createSkeetFrame(name, parent, size, anchor, pos)
    local Outline = Instance.new("Frame")
    Outline.Name = name
    Outline.Parent = parent
    Outline.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Outline.BorderSizePixel = 0
    Outline.AnchorPoint = anchor
    Outline.Position = pos
    Outline.Size = size

    -- Outer Glow / Stroke
    local OutStroke = Instance.new("UIStroke", Outline)
    OutStroke.Thickness = 1.5
    OutStroke.Color = Color3.fromRGB(25, 25, 25)

    local MainFrame = Instance.new("Frame")
    MainFrame.Parent = Outline
    MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0, 1, 0, 1)
    MainFrame.Size = UDim2.new(1, -2, 1, -2)

    local InnerFrame = Instance.new("Frame")
    InnerFrame.Parent = MainFrame
    InnerFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40) -- Lighter grey for depth
    InnerFrame.BorderSizePixel = 0
    InnerFrame.Position = UDim2.new(0, 2, 0, 2)
    InnerFrame.Size = UDim2.new(1, -4, 1, -4)

    local InnerFill = Instance.new("Frame")
    InnerFill.Parent = InnerFrame
    InnerFill.BackgroundColor3 = Color3.fromRGB(16, 16, 16) -- Dark main bg
    InnerFill.BorderSizePixel = 0
    InnerFill.Position = UDim2.new(0, 1, 0, 1)
    InnerFill.Size = UDim2.new(1, -2, 1, -2)

    -- Top Accent Line (Rainbow or Static Green)
    local Accent = Instance.new("Frame")
    Accent.Size = UDim2.new(1, 0, 0, 2)
    Accent.BackgroundColor3 = Color3.fromRGB(0, 255, 100) -- PickHub Green
    Accent.BorderSizePixel = 0
    Accent.Parent = InnerFill
    
    local AccentGrad = Instance.new("UIGradient", Accent)
    AccentGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 120)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 180, 255))
    }

    local function round(obj, radius)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, radius or 3)
        c.Parent = obj
    end
    round(Outline) round(MainFrame) round(InnerFrame) round(InnerFill)

    return Outline, InnerFill
end

--// 4. Create Components

-- [A] Info Bar (Username | Level | Time)
local Info_O, Info_F = createSkeetFrame("InfoBar", ScreenGui, UDim2.new(0, 400, 0, 32), Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -50))
MakeDraggable(Info_O, "InfoBar")

local InfoLabel = Instance.new("TextLabel", Info_F)
InfoLabel.Size = UDim2.new(1, 0, 1, 0)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Font = Enum.Font.Code
InfoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
InfoLabel.TextSize = 13
InfoLabel.RichText = true

-- [B] Main Window (Tabs: Logger | Settings)
local Main_O, Main_F = createSkeetFrame("MainWindow", ScreenGui, UDim2.new(0, 450, 0, 240), Vector2.new(0, 0.5), UDim2.new(0, 20, 0.5, 0))
MakeDraggable(Main_O, "MainWindow")

-- Title / Tab Area
local TabContainer = Instance.new("Frame", Main_F)
TabContainer.Size = UDim2.new(1, -10, 0, 25)
TabContainer.Position = UDim2.new(0, 5, 0, 5)
TabContainer.BackgroundTransparency = 1

local UIList = Instance.new("UIListLayout", TabContainer)
UIList.FillDirection = Enum.FillDirection.Horizontal
UIList.Padding = UDim.new(0, 5)

-- Content Area
local ContentContainer = Instance.new("Frame", Main_F)
ContentContainer.Size = UDim2.new(1, -10, 1, -40)
ContentContainer.Position = UDim2.new(0, 5, 0, 35)
ContentContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
ContentContainer.BorderSizePixel = 0

local ContentStroke = Instance.new("UIStroke", ContentContainer)
ContentStroke.Color = Color3.fromRGB(35, 35, 35)
ContentStroke.Thickness = 1

-- Tab Buttons
local activeTab = nil
local tabs = {}

local function SwitchTab(tabName)
    if activeTab == tabName then return end
    activeTab = tabName
    
    for name, data in pairs(tabs) do
        if name == tabName then
            data.Button.TextColor3 = Color3.fromRGB(0, 255, 100)
            data.Frame.Visible = true
        else
            data.Button.TextColor3 = Color3.fromRGB(150, 150, 150)
            data.Frame.Visible = false
        end
    end
end

local function CreateTab(name)
    local Btn = Instance.new("TextButton", TabContainer)
    Btn.Size = UDim2.new(0, 100, 1, 0)
    Btn.BackgroundTransparency = 1
    Btn.Text = name
    Btn.Font = Enum.Font.Code
    Btn.TextSize = 14
    Btn.TextColor3 = Color3.fromRGB(150, 150, 150)
    
    local Frame = Instance.new("Frame", ContentContainer)
    Frame.Size = UDim2.new(1, 0, 1, 0)
    Frame.BackgroundTransparency = 1
    Frame.Visible = false
    
    tabs[name] = {Button = Btn, Frame = Frame}
    
    Btn.MouseButton1Click:Connect(function()
        SwitchTab(name)
    end)
    
    return Frame
end

-- 1) Logger Tab
local LoggerFrame = CreateTab("Logger")
local LogScroll = Instance.new("ScrollingFrame", LoggerFrame) 
LogScroll.BackgroundTransparency = 1 
LogScroll.Size = UDim2.new(1, -10, 1, -10) 
LogScroll.Position = UDim2.new(0, 5, 0, 5)
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0) 
LogScroll.ScrollBarThickness = 2 
LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local LogList = Instance.new("UIListLayout", LogScroll) 
LogList.Padding = UDim.new(0, 3)

-- 2) Settings Tab
local SettingsFrame = CreateTab("Settings")
local SettingsList = Instance.new("UIListLayout", SettingsFrame)
SettingsList.Padding = UDim.new(0, 5)
SettingsList.HorizontalAlignment = Enum.HorizontalAlignment.Left

local SettingsScroll = Instance.new("ScrollingFrame", SettingsFrame)
SettingsScroll.BackgroundTransparency = 1
SettingsScroll.Size = UDim2.new(1, -10, 1, -10)
SettingsScroll.Position = UDim2.new(0, 5, 0, 5)
SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
SettingsScroll.ScrollBarThickness = 2
SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
SettingsList.Parent = SettingsScroll

local function CreateToggle(key, labelText)
    local Container = Instance.new("TextButton", SettingsScroll)
    Container.Size = UDim2.new(1, 0, 0, 24)
    Container.BackgroundTransparency = 1
    Container.Text = ""
    Container.AutoButtonColor = false

    local Checkbox = Instance.new("Frame", Container)
    Checkbox.Size = UDim2.new(0, 18, 0, 18)
    Checkbox.Position = UDim2.new(0, 2, 0, 3)
    Checkbox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    Checkbox.BorderSizePixel = 0
    Instance.new("UICorner", Checkbox).CornerRadius = UDim.new(0, 4)
    
    local CheckStroke = Instance.new("UIStroke", Checkbox)
    CheckStroke.Color = Color3.fromRGB(60, 60, 60)
    CheckStroke.Thickness = 1

    local CheckInner = Instance.new("Frame", Checkbox)
    CheckInner.Size = UDim2.new(1, -6, 1, -6)
    CheckInner.Position = UDim2.new(0, 3, 0, 3)
    CheckInner.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    CheckInner.BorderSizePixel = 0
    Instance.new("UICorner", CheckInner).CornerRadius = UDim.new(0, 2)
    CheckInner.Visible = PickHubLibrary.Config[key] or false

    local Label = Instance.new("TextLabel", Container)
    Label.Size = UDim2.new(1, -30, 1, 0)
    Label.Position = UDim2.new(0, 28, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.Font = Enum.Font.Code
    Label.TextSize = 13
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextXAlignment = Enum.TextXAlignment.Left

    Container.MouseButton1Click:Connect(function()
        PickHubLibrary.Config[key] = not PickHubLibrary.Config[key]
        CheckInner.Visible = PickHubLibrary.Config[key]
        SaveConfig() -- Auto-save on toggle
    end)
end

-- Create Toggles
CreateToggle("ANTIAFK", "Anti AFK")
CreateToggle("AutoDj", "Auto DJ")
CreateToggle("AutoCommander", "Auto Commander")
CreateToggle("TimeScale", "Timescale")
CreateToggle("AutoSkip", "Auto Skip")
CreateToggle("AntiLag", "Anti Lag")
CreateToggle("AutoPickups", "Auto Pickups")
CreateToggle("SendWebhook", "Send Webhook")

SwitchTab("Logger") -- Default Tab

-- [C] Toggle Button
local Toggle_O, Toggle_F = createSkeetFrame("ToggleBtn", ScreenGui, UDim2.new(0, 100, 0, 30), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 10))
MakeDraggable(Toggle_O, "ToggleBtn")

local ToggleBtn = Instance.new("TextButton", Toggle_F)
ToggleBtn.Size = UDim2.new(1, 0, 1, 0)
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Text = "Hide UI"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
ToggleBtn.Font = Enum.Font.Code
ToggleBtn.TextSize = 14

local function ToggleUI(forceState)
    local targetState
    if forceState ~= nil then
        targetState = forceState
    else
        targetState = not Main_O.Visible
    end
    
    Main_O.Visible = targetState
    Info_O.Visible = targetState
    
    if targetState then
        ToggleBtn.Text = "Hide UI"
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        ToggleBtn.Text = "Show UI"
        ToggleBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    ToggleUI()
end)

--// 5. Logic & Updates
local function format_number(n)
    return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local function get_time_elapsed()
    local t = Workspace.DistributedGameTime
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = math.floor(t % 60)
    if h > 0 then
        return string.format("%dh %dm %ds", h, m, s)
    else
        return string.format("%dm %ds", m, s)
    end
end

RunService.RenderStepped:Connect(function()
    local name = LocalPlayer.DisplayName or LocalPlayer.Name
    local level = LocalPlayer:FindFirstChild("Level") and LocalPlayer.Level.Value or 0
    local timeStr = get_time_elapsed()
    
    InfoLabel.Text = string.format(
        "<font color='#00ff78'>%s</font>  <font color='#666666'>|</font>  Level: <font color='#00bfff'>%s</font>  <font color='#666666'>|</font>  Time: <font color='#ffd700'>%s</font>",
        name, format_number(level), timeStr
    )
end)

--// 6. API Functions

function PickHubLibrary.Log(text, color)
    local ml = Instance.new("TextLabel", LogScroll) 
    ml.Size = UDim2.new(1, 0, 0, 0) 
    ml.AutomaticSize = Enum.AutomaticSize.Y
    ml.BackgroundTransparency = 1 
    ml.Font = Enum.Font.Code 
    ml.TextSize = 13 
    ml.TextColor3 = color or Color3.fromRGB(255, 255, 255) 
    ml.Text = "» " .. tostring(text)
    ml.TextXAlignment = Enum.TextXAlignment.Left 
    ml.TextWrapped = true
    task.defer(function() LogScroll.CanvasPosition = Vector2.new(0, LogScroll.AbsoluteCanvasSize.Y) end)
end

function PickHubLibrary.Toggle(state)
    ToggleUI(state)
end

function PickHubLibrary.Destroy()
    ScreenGui:Destroy()
end

PickHubLibrary.Log("UI Library Loaded Successfully", Color3.fromRGB(100, 255, 100))

return PickHubLibrary

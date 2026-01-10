local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

-- Determine parent (handle exploit environment vs studio)
local Player = Players.LocalPlayer
local Parent = (gethui and gethui()) or (game:GetService("CoreGui")) or (Player and Player:WaitForChild("PlayerGui"))
local IsMobile = UserInputService.TouchEnabled

if not Parent then
    warn("Could not find a valid parent for the UI.")
    return
end

-- Cleanup existing
for _, child in ipairs(Parent:GetChildren()) do
    if child.Name == "LoaderPreview" or child.Name == "MainHub" or child.Name == "HubToggle" or child.Name == "TDSGui" then
        child:Destroy()
    end
end

-- Configuration
local Config = {
    Colors = {
        Tint = Color3.fromRGB(0, 0, 0),         -- Dark Dimmer (Black)
        CardBackground = Color3.fromRGB(20, 20, 25), -- Card Background (slightly darker)
        Accent = Color3.fromRGB(255, 60, 140),   -- Hot Pink (Default)
        Text = Color3.fromRGB(255, 255, 255),
        SubText = Color3.fromRGB(255, 255, 255)  -- Brighter SubText
    },
    Duration = 3, -- Normal load duration
    TintTransparency = 0.4,
    CardTransparency = 0.1
}

-- Theme System
local ThemeObjects = {}
local function RegisterTheme(obj, prop)
    table.insert(ThemeObjects, {Object = obj, Property = prop})
    return obj
end

-- Shared Snow Function
local function SpawnSnow(container)
    local active = true
    task.spawn(function()
        while active and container.Parent do
            task.wait(0.05)
            if not container.Parent then break end

            local size = math.random(3, 7)
            local startX = math.random(0, container.AbsoluteSize.X)
            local duration = math.random(30, 60) / 10
            
            local particle = Instance.new("Frame")
            particle.Name = "Snow"
            particle.Size = UDim2.new(0, size, 0, size)
            particle.Position = UDim2.new(0, startX, 0, -10)
            particle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            particle.BackgroundTransparency = math.random(20, 60) / 100
            particle.BorderSizePixel = 0
            particle.Parent = container
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = particle
            
            local tween = TweenService:Create(particle, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                Position = UDim2.new(0, startX, 1, 10),
                BackgroundTransparency = 1
            })
            
            tween:Play()
            tween.Completed:Connect(function()
                particle:Destroy()
            end)
        end
    end)
    return function() active = false end
end

-- Create UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LoaderPreview"
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = Parent

-- 1. Full Screen Tinted Background
local BackgroundTint = Instance.new("Frame")
BackgroundTint.Name = "BackgroundTint"
BackgroundTint.Size = UDim2.new(1, 0, 1, 0)
BackgroundTint.BackgroundColor3 = Config.Colors.Tint
BackgroundTint.BackgroundTransparency = 1
BackgroundTint.BorderSizePixel = 0
BackgroundTint.Parent = ScreenGui

-- Particle Container (Snow)
local ParticleContainer = Instance.new("Frame")
ParticleContainer.Name = "Particles"
ParticleContainer.Size = UDim2.new(1, 0, 1, 0)
ParticleContainer.BackgroundTransparency = 1
ParticleContainer.ClipsDescendants = true
ParticleContainer.Parent = BackgroundTint

-- 2. The "Card" in the Middle
local MainCard = Instance.new("Frame")
MainCard.Name = "MainCard"
MainCard.Size = IsMobile and UDim2.new(0.8, 0, 0.25, 0) or UDim2.new(0, 400, 0, 180)
MainCard.AnchorPoint = Vector2.new(0.5, 0.5)
MainCard.Position = UDim2.new(0.5, 0, 0.5, 0)
MainCard.BackgroundColor3 = Config.Colors.CardBackground
MainCard.BackgroundTransparency = 1
MainCard.BorderSizePixel = 0
MainCard.Parent = ScreenGui

local CardCorner = Instance.new("UICorner")
CardCorner.CornerRadius = UDim.new(0, 12)
CardCorner.Parent = MainCard

local CardStroke = Instance.new("UIStroke")
CardStroke.Color = Config.Colors.Accent
CardStroke.Thickness = 1
CardStroke.Transparency = 1
CardStroke.Parent = MainCard
RegisterTheme(CardStroke, "Color")

-- Title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 50)
Title.BackgroundTransparency = 1
Title.TextTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = "BOOSTERS HUB"
Title.TextColor3 = Config.Colors.Text
Title.TextSize = 32
Title.Position = UDim2.new(0, 0, 0.15, 0)
Title.Parent = MainCard

-- Subtitle/Status
local Status = Instance.new("TextLabel")
Status.Name = "Status"
Status.Size = UDim2.new(1, 0, 0, 30)
Status.BackgroundTransparency = 1
Status.TextTransparency = 1
Status.Font = Enum.Font.Gotham
Status.Text = "Initializing..."
Status.TextColor3 = Config.Colors.SubText
Status.TextSize = 16
Status.Position = UDim2.new(0, 0, 0.4, 0)
Status.Parent = MainCard

-- Loading Bar
local BarBackground = Instance.new("Frame")
BarBackground.Name = "BarBackground"
BarBackground.Size = UDim2.new(0.8, 0, 0, 8)
BarBackground.AnchorPoint = Vector2.new(0.5, 0)
BarBackground.Position = UDim2.new(0.5, 0, 0.65, 0)
BarBackground.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
BarBackground.BackgroundTransparency = 1
BarBackground.BorderSizePixel = 0
BarBackground.Parent = MainCard

local BarCorner = Instance.new("UICorner")
BarCorner.CornerRadius = UDim.new(1, 0)
BarCorner.Parent = BarBackground

local BarFill = Instance.new("Frame")
BarFill.Name = "BarFill"
BarFill.Size = UDim2.new(0, 0, 1, 0)
BarFill.BackgroundColor3 = Config.Colors.Accent
BarFill.BackgroundTransparency = 1
BarFill.BorderSizePixel = 0
BarFill.Parent = BarBackground
RegisterTheme(BarFill, "BackgroundColor3")

local FillCorner = Instance.new("UICorner")
FillCorner.CornerRadius = UDim.new(1, 0)
FillCorner.Parent = BarFill

local Glow = Instance.new("ImageLabel")
Glow.Name = "Glow"
Glow.BackgroundTransparency = 1
Glow.Image = "rbxassetid://7912133858"
Glow.ImageColor3 = Config.Colors.Accent
Glow.ImageTransparency = 1
Glow.Size = UDim2.new(1, 20, 1, 20)
Glow.Position = UDim2.new(0, -10, 0, -10)
Glow.ScaleType = Enum.ScaleType.Slice
Glow.SliceCenter = Rect.new(100, 100, 100, 100)
Glow.SliceScale = 0.5
Glow.Parent = BarFill
RegisterTheme(Glow, "ImageColor3")

-- Animation Logic
local function animate()
    SpawnSnow(ParticleContainer)

    TweenService:Create(BackgroundTint, TweenInfo.new(0.5), {BackgroundTransparency = Config.TintTransparency}):Play()
    TweenService:Create(MainCard, TweenInfo.new(0.5), {BackgroundTransparency = Config.CardTransparency}):Play()
    TweenService:Create(CardStroke, TweenInfo.new(0.5), {Transparency = 0.8}):Play()
    
    task.wait(0.2)
    
    TweenService:Create(Title, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
    TweenService:Create(Status, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
    TweenService:Create(BarBackground, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
    TweenService:Create(BarFill, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
    TweenService:Create(Glow, TweenInfo.new(0.5), {ImageTransparency = 0.5}):Play()
    
    -- Loading Steps
    local steps = {
        {text = "Checking whitelist...", progress = 0.3, wait = 0.5},
        {text = "Downloading assets...", progress = 0.6, wait = 0.8},
        {text = "Injecting scripts...", progress = 0.85, wait = 0.6},
        {text = "Finalizing...", progress = 1, wait = 0.5}
    }
    
    for _, step in ipairs(steps) do
        Status.Text = step.text
        TweenService:Create(BarFill, TweenInfo.new(step.wait, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(step.progress, 0, 1, 0)}):Play()
        task.wait(step.wait)
    end
    
    Status.Text = "Ready!"
    task.wait(0.5)
    
    -- Fade Out
    local fadeInfo = TweenInfo.new(0.5)
    TweenService:Create(Title, fadeInfo, {TextTransparency = 1}):Play()
    TweenService:Create(Status, fadeInfo, {TextTransparency = 1}):Play()
    TweenService:Create(BarBackground, fadeInfo, {BackgroundTransparency = 1}):Play()
    TweenService:Create(BarFill, fadeInfo, {BackgroundTransparency = 1}):Play()
    TweenService:Create(Glow, fadeInfo, {ImageTransparency = 1}):Play()
    TweenService:Create(MainCard, fadeInfo, {BackgroundTransparency = 1}):Play()
    TweenService:Create(CardStroke, fadeInfo, {Transparency = 1}):Play()
    
    task.wait(0.3)
    TweenService:Create(BackgroundTint, fadeInfo, {BackgroundTransparency = 1}):Play()
    
    task.wait(0.5)
    ScreenGui:Destroy()
end

-- task.spawn(animate)

----------------------------------------------------------------------------------
-- MAIN HUB IMPLEMENTATION
----------------------------------------------------------------------------------

-- task.spawn(function()
    -- task.wait(3.5) -- Wait for loading to finish

    local FileName = "ADS_Config.json"
    local Settings = {
        AutoDJ = false, AutoChain = false, AutoSkip = false,
        AntiLag = false, AutoPickups = false, AntiAFK = false, Timescale = 0,
        ClaimRewards = false, SendWebhook = false,
        WebhookURL = "",
        -- New Settings
        ThemeR = 255, ThemeG = 60, ThemeB = 140,
        LoggerExternal = false
    }


    local function InitializeSettings()
        local loaderConfig = getgenv().PickHubBooster or getgenv().PickHubLOL or {}
        
        -- Load from file first to get saved preferences
        if isfile and isfile(FileName) then
            pcall(function()
                local decoded = HttpService:JSONDecode(readfile(FileName))
                for k, v in pairs(decoded) do 
                    if Settings[k] ~= nil then 
                        Settings[k] = v 
                    end 
                end
            end)
        end

        -- Sync with Loader Config (PickHubBooster)
        if loaderConfig then
            -- Ensure critical keys exist in loader config (if missing)
            loaderConfig.AutoSkip = loaderConfig.AutoSkip or false
            loaderConfig.AntiLag = loaderConfig.AntiLag or false
            loaderConfig.AutoPickups = loaderConfig.AutoPickups or false
            loaderConfig.SendWebhook = loaderConfig.SendWebhook or false
            loaderConfig.Webhook = loaderConfig.Webhook or ""
            loaderConfig.ANTIAFK = loaderConfig.ANTIAFK or false

            -- Sync UI Settings FROM Loader Config
            if loaderConfig.AutoSkip ~= nil then Settings.AutoSkip = loaderConfig.AutoSkip end
            if loaderConfig.AntiLag ~= nil then Settings.AntiLag = loaderConfig.AntiLag end
            if loaderConfig.AutoPickups ~= nil then Settings.AutoPickups = loaderConfig.AutoPickups end
            if loaderConfig.SendWebhook ~= nil then Settings.SendWebhook = loaderConfig.SendWebhook end
            if loaderConfig.Webhook ~= nil then Settings.WebhookURL = loaderConfig.Webhook end
            if loaderConfig.ANTIAFK ~= nil then Settings.AntiAFK = loaderConfig.ANTIAFK end
        end

    end

    InitializeSettings()

    -- Apply saved theme
    Config.Colors.Accent = Color3.fromRGB(Settings.ThemeR, Settings.ThemeG, Settings.ThemeB)

    local function SaveSettings()
        if writefile then writefile(FileName, HttpService:JSONEncode(Settings)) end
    end

    local function UpdateLoaderConfig(key, value)
        local loaderConfig = getgenv().PickHubBooster or getgenv().PickHubLOL
        if not loaderConfig then return end

        local keyMap = {
            WebhookURL = "Webhook",
            AntiAFK = "ANTIAFK",
            Timescale = "TimeScale"
        }
        
        local targetKey = keyMap[key] or key
        loaderConfig[targetKey] = value
    end

    local HubGui = Instance.new("ScreenGui")
    HubGui.Name = "MainHub"
    HubGui.IgnoreGuiInset = true
    HubGui.Enabled = false -- Hidden initially, shown after animation
    HubGui.Parent = Parent

    -- Toggle Button
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Name = "ToggleUI"
    ToggleBtn.Size = IsMobile and UDim2.new(0, 140, 0, 40) or UDim2.new(0, 100, 0, 30)
    ToggleBtn.AnchorPoint = Vector2.new(0.5, 0)
    ToggleBtn.Position = UDim2.new(0.5, 0, 0, 10)
    ToggleBtn.BackgroundColor3 = Config.Colors.CardBackground
    ToggleBtn.BackgroundTransparency = 0.2
    ToggleBtn.Text = "Toggle UI"
    ToggleBtn.TextColor3 = Config.Colors.Text
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.TextSize = 14
    ToggleBtn.Parent = HubGui
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 8)
    ToggleCorner.Parent = ToggleBtn
    
    local ToggleStroke = Instance.new("UIStroke")
    ToggleStroke.Color = Config.Colors.Accent
    ToggleStroke.Thickness = 1
    ToggleStroke.Parent = ToggleBtn
    RegisterTheme(ToggleStroke, "Color")

    -- Background & Snow
    local HubBackground = Instance.new("Frame")
    HubBackground.Name = "HubBackground"
    HubBackground.Size = UDim2.new(1, 0, 1, 0)
    HubBackground.BackgroundColor3 = Config.Colors.Tint
    HubBackground.BackgroundTransparency = Config.TintTransparency
    HubBackground.BorderSizePixel = 0
    HubBackground.Parent = HubGui

    local HubParticles = Instance.new("Frame")
    HubParticles.Name = "Particles"
    HubParticles.Size = UDim2.new(1, 0, 1, 0)
    HubParticles.BackgroundTransparency = 1
    HubParticles.ClipsDescendants = true
    HubParticles.Parent = HubBackground
    SpawnSnow(HubParticles)

    -- Main Window
    local Window = Instance.new("Frame")
    Window.Name = "Window"
    Window.AnchorPoint = Vector2.new(0.5, 0.5)
    Window.Position = UDim2.new(0.5, 0, 0.5, 0)
    Window.Size = IsMobile and UDim2.new(0.85, 0, 0.6, 0) or UDim2.new(0, 550, 0, 380) -- Slightly taller for footer
    Window.BackgroundColor3 = Config.Colors.CardBackground
    Window.BackgroundTransparency = Config.CardTransparency
    Window.BorderSizePixel = 0
    Window.Active = true
    Window.Draggable = true
    Window.ClipsDescendants = true
    Window.ZIndex = 2
    Window.Parent = HubGui

    local WinCorner = Instance.new("UICorner")
    WinCorner.CornerRadius = UDim.new(0, 10)
    WinCorner.Parent = Window

    local WinStroke = Instance.new("UIStroke")
    WinStroke.Color = Config.Colors.Accent
    WinStroke.Thickness = 1
    WinStroke.Transparency = 0.5
    WinStroke.Parent = Window
    RegisterTheme(WinStroke, "Color")

    -- Window Title
    local WinTitle = Instance.new("TextLabel")
    WinTitle.Size = UDim2.new(1, -20, 0, 40)
    WinTitle.Position = UDim2.new(0, 20, 0, 0)
    WinTitle.BackgroundTransparency = 1
    local hexColor = string.format("#%02x%02x%02x", Settings.ThemeR, Settings.ThemeG, Settings.ThemeB)
    WinTitle.Text = "[ Auto-Strat ] <font color=\"" .. hexColor .. "\">Boosters</font>"
    WinTitle.RichText = true
    WinTitle.TextColor3 = Config.Colors.Text
    WinTitle.TextXAlignment = Enum.TextXAlignment.Left
    WinTitle.Font = Enum.Font.GothamBold
    WinTitle.TextSize = 18
    WinTitle.TextTransparency = 0
    WinTitle.ZIndex = 3
    WinTitle.Parent = Window

    local Separator = Instance.new("Frame")
    Separator.Size = UDim2.new(1, 0, 0, 1)
    Separator.Position = UDim2.new(0, 0, 0, 40)
    Separator.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    Separator.BorderSizePixel = 0
    Separator.ZIndex = 3
    Separator.Parent = Window

    -- Footer (Legacy Support)
    local Footer = Instance.new("Frame")
    Footer.Size = UDim2.new(1, 0, 0, 30)
    Footer.Position = UDim2.new(0, 0, 1, -30)
    Footer.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    Footer.BackgroundTransparency = 0.5
    Footer.BorderSizePixel = 0
    Footer.ZIndex = 3
    Footer.Parent = Window
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(0.5, -10, 1, 0)
    StatusLabel.Position = UDim2.new(0, 10, 0, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "● <font color='#00ff96'>Idle</font>"
    StatusLabel.TextColor3 = Config.Colors.SubText
    StatusLabel.RichText = true
    StatusLabel.Font = Enum.Font.GothamMedium
    StatusLabel.TextSize = 12
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.ZIndex = 4
    StatusLabel.Parent = Footer
    
    local TimeLabel = Instance.new("TextLabel")
    TimeLabel.Size = UDim2.new(0.5, -10, 1, 0)
    TimeLabel.Position = UDim2.new(0.5, 0, 0, 0)
    TimeLabel.BackgroundTransparency = 1
    TimeLabel.Text = "TIME: 00:00:00"
    TimeLabel.TextColor3 = Config.Colors.SubText
    TimeLabel.Font = Enum.Font.GothamBold
    TimeLabel.TextSize = 11
    TimeLabel.TextXAlignment = Enum.TextXAlignment.Right
    TimeLabel.ZIndex = 4
    TimeLabel.Parent = Footer
    
    -- Session Timer
    local session_start = tick()
    task.spawn(function()
        while task.wait(1) do
            if not Window.Parent then break end
            local elapsed = tick() - session_start
            local h, m, s = math.floor(elapsed / 3600), math.floor((elapsed % 3600) / 60), math.floor(elapsed % 60)
            TimeLabel.Text = string.format("TIME: %02d:%02d:%02d", h, m, s)
        end
    end)

    -- Tab Container
    local TabContainer = Instance.new("Frame")
    TabContainer.Name = "Tabs"
    TabContainer.Size = UDim2.new(0, 120, 1, -71) -- Adjusted for header + footer
    TabContainer.Position = UDim2.new(0, 0, 0, 41)
    TabContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    TabContainer.BackgroundTransparency = 0.5
    TabContainer.BorderSizePixel = 0
    TabContainer.ZIndex = 10
    TabContainer.Parent = Window

    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0, 10)
    TabCorner.Parent = TabContainer

    local TabListLayout = Instance.new("UIListLayout")
    TabListLayout.Parent = TabContainer
    TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabListLayout.Padding = UDim.new(0, 5)
    TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local TabPadding = Instance.new("UIPadding")
    TabPadding.PaddingTop = UDim.new(0, 10)
    TabPadding.Parent = TabContainer

    -- Content Area
    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "Content"
    ContentArea.Size = UDim2.new(1, -130, 1, -81) -- Adjusted for header + footer
    ContentArea.Position = UDim2.new(0, 130, 0, 46)
    ContentArea.BackgroundTransparency = 1
    ContentArea.ZIndex = 2
    ContentArea.Parent = Window

    -- Notification Container
    local NotificationContainer = Instance.new("Frame")
    NotificationContainer.Name = "Notifications"
    NotificationContainer.Size = UDim2.new(0, 200, 1, 0)
    NotificationContainer.Position = UDim2.new(1, 20, 0, 0)
    NotificationContainer.BackgroundTransparency = 1
    NotificationContainer.Parent = Window

    local function Notify(text)
        local Notif = Instance.new("TextLabel")
        Notif.Size = UDim2.new(1, 0, 0, 30)
        Notif.BackgroundColor3 = Config.Colors.CardBackground
        Notif.TextColor3 = Config.Colors.Text
        Notif.Text = text
        Notif.Font = Enum.Font.Gotham
        Notif.TextSize = 14
        Notif.BackgroundTransparency = 0.2
        Notif.TextTransparency = 0
        Notif.ZIndex = 20
        Notif.Parent = NotificationContainer
        
        local nc = Instance.new("UICorner")
        nc.CornerRadius = UDim.new(0, 4)
        nc.Parent = Notif
        
        local ns = Instance.new("UIStroke")
        ns.Color = Config.Colors.Accent
        ns.Parent = Notif
        RegisterTheme(ns, "Color") -- Register notification stroke
        
        task.delay(3, function()
            TweenService:Create(Notif, TweenInfo.new(0.5), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
            task.wait(0.5)
            Notif:Destroy()
        end)
    end

    -- Toggle Logic
    local isVisible = true
    ToggleBtn.MouseButton1Click:Connect(function()
        isVisible = not isVisible
        HubBackground.Visible = isVisible
        Window.Visible = isVisible
        ToggleBtn.Text = isVisible and "Toggle UI" or "Show UI"
    end)

    -- Pages
    local WelcomePage = Instance.new("Frame")
    WelcomePage.Name = "Welcome"
    WelcomePage.Size = UDim2.new(1, 0, 1, 0)
    WelcomePage.BackgroundTransparency = 1
    WelcomePage.Visible = true
    WelcomePage.Parent = ContentArea

    local AvatarContainer = Instance.new("Frame")
    AvatarContainer.Size = UDim2.new(0, 110, 0, 110)
    AvatarContainer.Position = UDim2.new(0.5, -55, 0.15, 0)
    AvatarContainer.BackgroundTransparency = 1
    AvatarContainer.Parent = WelcomePage

    local Avatar = Instance.new("ImageLabel")
    Avatar.Size = UDim2.new(1, -4, 1, -4)
    Avatar.Position = UDim2.new(0, 2, 0, 2)
    Avatar.BackgroundTransparency = 1
    Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. Player.UserId .. "&w=150&h=150"
    Avatar.ImageColor3 = Color3.fromRGB(255, 255, 255)
    Avatar.ImageTransparency = 0
    Avatar.Parent = AvatarContainer

    local AvatarCorner = Instance.new("UICorner")
    AvatarCorner.CornerRadius = UDim.new(1, 0)
    AvatarCorner.Parent = Avatar
    
    local AvatarStroke = Instance.new("UIStroke")
    AvatarStroke.Color = Config.Colors.Accent
    AvatarStroke.Thickness = 2
    AvatarStroke.Parent = Avatar
    RegisterTheme(AvatarStroke, "Color")

    local WelcomeTitle = Instance.new("TextLabel")
    WelcomeTitle.Size = UDim2.new(1, 0, 0, 30)
    WelcomeTitle.Position = UDim2.new(0, 0, 0.55, 0)
    WelcomeTitle.BackgroundTransparency = 1
    WelcomeTitle.Text = "Welcome, " .. Player.Name
    WelcomeTitle.TextColor3 = Config.Colors.Text
    WelcomeTitle.Font = Enum.Font.GothamBold
    WelcomeTitle.TextSize = 22
    WelcomeTitle.TextXAlignment = Enum.TextXAlignment.Center
    WelcomeTitle.TextTransparency = 0
    WelcomeTitle.ZIndex = 5
    WelcomeTitle.Parent = WelcomePage

    local WelcomeSub = Instance.new("TextLabel")
    WelcomeSub.Size = UDim2.new(1, 0, 0, 20)
    WelcomeSub.Position = UDim2.new(0, 0, 0.55, 30)
    WelcomeSub.BackgroundTransparency = 1
    WelcomeSub.Text = "to PickHub [ <font color=\"" .. hexColor .. "\">Boosters</font> ]"
    WelcomeSub.RichText = true
    WelcomeSub.TextColor3 = Config.Colors.Text
    WelcomeSub.Font = Enum.Font.Gotham
    WelcomeSub.TextSize = 16
    WelcomeSub.TextXAlignment = Enum.TextXAlignment.Center
    WelcomeSub.TextTransparency = 0
    WelcomeSub.ZIndex = 5
    WelcomeSub.Parent = WelcomePage

    local LoggerPage = Instance.new("ScrollingFrame")
    LoggerPage.Name = "Logger"
    LoggerPage.Size = UDim2.new(1, 0, 1, 0)
    LoggerPage.BackgroundTransparency = 1
    LoggerPage.ScrollBarThickness = 4
    LoggerPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
    LoggerPage.CanvasSize = UDim2.new(0,0,0,0)
    LoggerPage.Visible = false
    LoggerPage.Parent = ContentArea
    
    -- Logger External Support
    local LoggerStroke = Instance.new("UIStroke")
    LoggerStroke.Color = Config.Colors.Accent
    LoggerStroke.Thickness = 1
    LoggerStroke.Transparency = 1 -- Initially hidden
    LoggerStroke.Parent = LoggerPage
    RegisterTheme(LoggerStroke, "Color")

    local LogLayout = Instance.new("UIListLayout")
    LogLayout.Parent = LoggerPage
    LogLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local function Log(msg, color)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color or Config.Colors.SubText
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = msg
        lbl.RichText = true
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 13
        lbl.TextTransparency = 0
        lbl.ZIndex = 5
        lbl.Parent = LoggerPage
        
        task.delay(0.05, function()
            LoggerPage.CanvasPosition = Vector2.new(0, LoggerPage.AbsoluteCanvasSize.Y)
        end)
    end

    -- Legacy Shared Export
    shared.AutoStratGUI = {
        Console = LoggerPage,
        Status = function(new_status)
            StatusLabel.Text = "● <font color='#00ff96'>" .. tostring(new_status) .. "</font>"
        end
    }

    -- Auto-Detect Game State
    task.spawn(function()
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
        local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

        while task.wait(1) do
            if PlayerGui:FindFirstChild("GameGui") then
                StatusLabel.Text = "● <font color='#00ff96'>In Game</font>"
            elseif PlayerGui:FindFirstChild("LobbyGui") then
                StatusLabel.Text = "● <font color='#00ff96'>In Lobby</font>"
            end
        end
    end)

    local ConfigPage = Instance.new("ScrollingFrame")
    ConfigPage.Name = "Config"
    ConfigPage.Size = UDim2.new(1, 0, 1, 0)
    ConfigPage.BackgroundTransparency = 1
    ConfigPage.ScrollBarThickness = 4
    ConfigPage.Visible = false
    ConfigPage.Parent = ContentArea

    local ConfigLayout = Instance.new("UIListLayout")
    ConfigLayout.Padding = UDim.new(0, 5)
    ConfigLayout.Parent = ConfigPage
    
    local SettingsPage = Instance.new("ScrollingFrame")
    SettingsPage.Name = "Settings"
    SettingsPage.Size = UDim2.new(1, 0, 1, 0)
    SettingsPage.BackgroundTransparency = 1
    SettingsPage.ScrollBarThickness = 4
    SettingsPage.Visible = false
    SettingsPage.Parent = ContentArea
    
    local SettingsLayout = Instance.new("UIListLayout")
    SettingsLayout.Padding = UDim.new(0, 5)
    SettingsLayout.Parent = SettingsPage

    -- Global Active Tab Tracker
    local ActiveTabButton = nil
    local ActiveTabStroke = nil

    local function CreateTabBtn(name, page)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        btn.BackgroundTransparency = 0
        btn.Text = name
        btn.TextColor3 = Config.Colors.Text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.TextTransparency = 0
        btn.ZIndex = 11
        btn.Parent = TabContainer
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(60, 60, 60)
        stroke.Thickness = 1
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = btn

        btn.MouseButton1Click:Connect(function()
            for _, c in pairs(ContentArea:GetChildren()) do
                if c:IsA("GuiObject") then c.Visible = false end
            end
            page.Visible = true
            
            -- Reset all tabs
            for _, child in pairs(TabContainer:GetChildren()) do
                if child:IsA("TextButton") and child:FindFirstChild("UIStroke") then
                    child.UIStroke.Color = Color3.fromRGB(60, 60, 60)
                    child.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
                end
            end
            
            -- Set Active
            stroke.Color = Config.Colors.Accent
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
            
            ActiveTabButton = btn
            ActiveTabStroke = stroke
        end)
    end

    CreateTabBtn("Welcome", WelcomePage)
    CreateTabBtn("Logger", LoggerPage)
    CreateTabBtn("Settings", SettingsPage)
    CreateTabBtn("Config", ConfigPage) -- Re-added as requested "Main menu has a settings tab" (and implying restore config)
    
    -- Function to update theme dynamically
    local function UpdateTheme()
        local c = Color3.fromRGB(Settings.ThemeR, Settings.ThemeG, Settings.ThemeB)
        Config.Colors.Accent = c
        
        for _, item in ipairs(ThemeObjects) do
            if item.Object and item.Object.Parent then
                item.Object[item.Property] = c
            end
        end
        
        -- Update RichText strings
        local h = string.format("#%02x%02x%02x", Settings.ThemeR, Settings.ThemeG, Settings.ThemeB)
        WinTitle.Text = "[ Auto-Strat ] <font color=\"" .. h .. "\">Boosters</font>"
        WelcomeSub.Text = "to PickHub [ <font color=\"" .. h .. "\">Boosters</font> ]"
        
        -- Update Active Tab
        if ActiveTabStroke then
            ActiveTabStroke.Color = c
        end
        
        SaveSettings()
    end
    
    -- Create Toggle Helper
    local function CreateToggle(name, configKey, parent)
        parent = parent or ConfigPage
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 35)
        frame.BackgroundTransparency = 1
        frame.BackgroundColor3 = Color3.new(0,0,0)
        frame.Parent = parent
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Config.Colors.Text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextTransparency = 0
        label.ZIndex = 5
        label.Parent = frame
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 24, 0, 24)
        btn.AnchorPoint = Vector2.new(1, 0.5)
        btn.Position = UDim2.new(1, -10, 0.5, 0)
        btn.BackgroundColor3 = Settings[configKey] and Config.Colors.Accent or Color3.fromRGB(60,60,60)
        btn.Text = ""
        btn.ZIndex = 5
        btn.Parent = frame
        
        -- Register for theme updates
        table.insert(ThemeObjects, {
            Object = btn, 
            Property = "BackgroundColor3",
            -- Only update if it's active
            Update = function(color)
                if Settings[configKey] then
                    btn.BackgroundColor3 = color
                end
            end
        })
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            Settings[configKey] = not Settings[configKey]
            UpdateLoaderConfig(configKey, Settings[configKey]) 
            btn.BackgroundColor3 = Settings[configKey] and Config.Colors.Accent or Color3.fromRGB(60,60,60)
            SaveSettings()
            Notify(name .. (Settings[configKey] and " Enabled" or " Disabled"))
        end)
    end
    
    -- Logger Mode Helper
    local function SetLoggerMode(external)
        if external then
            LoggerPage.Parent = HubGui
            LoggerPage.Size = UDim2.new(0, 320, 0, 220)
            LoggerPage.Position = UDim2.new(1, -340, 1, -240)
            LoggerPage.BackgroundTransparency = 0.2
            LoggerPage.BackgroundColor3 = Config.Colors.CardBackground
            LoggerStroke.Transparency = 0
            LoggerPage.Visible = true
        else
            LoggerPage.Parent = ContentArea
            LoggerPage.Size = UDim2.new(1, 0, 1, 0)
            LoggerPage.Position = UDim2.new(0, 0, 0, 0)
            LoggerPage.BackgroundTransparency = 1
            LoggerStroke.Transparency = 1
            LoggerPage.Visible = false
        end
        Settings.LoggerExternal = external
        SaveSettings()
    end
    
    -- Settings Page Content
    
    -- Section: Theme
    local ThemeHeader = Instance.new("TextLabel")
    ThemeHeader.Size = UDim2.new(1, 0, 0, 30)
    ThemeHeader.BackgroundTransparency = 1
    ThemeHeader.Text = "Theme Settings (RGB)"
    ThemeHeader.TextColor3 = Config.Colors.SubText
    ThemeHeader.Font = Enum.Font.GothamBold
    ThemeHeader.TextSize = 16
    ThemeHeader.Parent = SettingsPage

    local function CreateSlider(name, min, max, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.BackgroundTransparency = 1
        frame.Parent = SettingsPage

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Config.Colors.Text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.Position = UDim2.new(0, 10, 0, 0)
        label.Parent = frame

        local sliderBg = Instance.new("Frame")
        sliderBg.Size = UDim2.new(0.9, 0, 0, 6)
        sliderBg.Position = UDim2.new(0.05, 0, 0, 30)
        sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = frame
        
        local sliderCorner = Instance.new("UICorner")
        sliderCorner.CornerRadius = UDim.new(1, 0)
        sliderCorner.Parent = sliderBg

        local sliderFill = Instance.new("Frame")
        sliderFill.Size = UDim2.new((default - min)/(max - min), 0, 1, 0)
        sliderFill.BackgroundColor3 = Config.Colors.Accent
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderBg
        RegisterTheme(sliderFill, "BackgroundColor3")

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = sliderFill

        local trigger = Instance.new("TextButton")
        trigger.Size = UDim2.new(1, 0, 1, 0)
        trigger.BackgroundTransparency = 1
        trigger.Text = ""
        trigger.Parent = sliderBg
        
        local valLabel = Instance.new("TextLabel")
        valLabel.Size = UDim2.new(0, 50, 0, 20)
        valLabel.Position = UDim2.new(1, -60, 0, -25)
        valLabel.BackgroundTransparency = 1
        valLabel.Text = tostring(default)
        valLabel.TextColor3 = Config.Colors.SubText
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        valLabel.Font = Enum.Font.Gotham
        valLabel.TextSize = 12
        valLabel.Parent = frame

        local isDragging = false
        
        local function Update(input)
            local pos = input.Position.X
            local rPos = pos - sliderBg.AbsolutePosition.X
            local pct = math.clamp(rPos / sliderBg.AbsoluteSize.X, 0, 1)
            sliderFill.Size = UDim2.new(pct, 0, 1, 0)
            local value = math.floor(min + (max - min) * pct)
            valLabel.Text = tostring(value)
            callback(value)
        end

        trigger.MouseButton1Down:Connect(function()
            isDragging = true
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                isDragging = false
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                Update(input)
            end
        end)
    end

    CreateSlider("Red", 0, 255, Settings.ThemeR, function(v)
        Settings.ThemeR = v
        UpdateTheme()
    end)
    
    CreateSlider("Green", 0, 255, Settings.ThemeG, function(v)
        Settings.ThemeG = v
        UpdateTheme()
    end)
    
    CreateSlider("Blue", 0, 255, Settings.ThemeB, function(v)
        Settings.ThemeB = v
        UpdateTheme()
    end)

    -- Section: UI Options
    local UIHeader = Instance.new("TextLabel")
    UIHeader.Size = UDim2.new(1, 0, 0, 30)
    UIHeader.BackgroundTransparency = 1
    UIHeader.Text = "UI Options"
    UIHeader.TextColor3 = Config.Colors.SubText
    UIHeader.Font = Enum.Font.GothamBold
    UIHeader.TextSize = 16
    UIHeader.Parent = SettingsPage

    -- External Logger Toggle
    local LoggerToggleFrame = Instance.new("Frame")
    LoggerToggleFrame.Size = UDim2.new(1, 0, 0, 35)
    LoggerToggleFrame.BackgroundTransparency = 1
    LoggerToggleFrame.BackgroundColor3 = Color3.new(0,0,0)
    LoggerToggleFrame.Parent = SettingsPage
    
    local lgLabel = Instance.new("TextLabel")
    lgLabel.Size = UDim2.new(0.7, 0, 1, 0)
    lgLabel.Position = UDim2.new(0, 10, 0, 0)
    lgLabel.BackgroundTransparency = 1
    lgLabel.Text = "External Logger (Bottom Right)"
    lgLabel.TextColor3 = Config.Colors.Text
    lgLabel.TextXAlignment = Enum.TextXAlignment.Left
    lgLabel.Font = Enum.Font.Gotham
    lgLabel.TextSize = 14
    lgLabel.Parent = LoggerToggleFrame
    
    local lgBtn = Instance.new("TextButton")
    lgBtn.Size = UDim2.new(0, 24, 0, 24)
    lgBtn.AnchorPoint = Vector2.new(1, 0.5)
    lgBtn.Position = UDim2.new(1, -10, 0.5, 0)
    lgBtn.BackgroundColor3 = Settings.LoggerExternal and Config.Colors.Accent or Color3.fromRGB(60,60,60)
    lgBtn.Text = ""
    lgBtn.Parent = LoggerToggleFrame
    
    local lgCorner = Instance.new("UICorner")
    lgCorner.CornerRadius = UDim.new(0, 4)
    lgCorner.Parent = lgBtn
    
    lgBtn.MouseButton1Click:Connect(function()
        local newState = not Settings.LoggerExternal
        SetLoggerMode(newState)
        lgBtn.BackgroundColor3 = newState and Config.Colors.Accent or Color3.fromRGB(60,60,60)
    end)
    
    -- Apply initial logger mode
    if Settings.LoggerExternal then
        SetLoggerMode(true)
    end


    local function CreateNumberInput(name, configKey)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 35)
        frame.BackgroundTransparency = 1
        frame.BackgroundColor3 = Color3.new(0,0,0)
        frame.Parent = ConfigPage
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Config.Colors.Text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextTransparency = 0
        label.ZIndex = 5
        label.Parent = frame
        
        local input = Instance.new("TextBox")
        input.Size = UDim2.new(0, 80, 0, 24)
        input.AnchorPoint = Vector2.new(1, 0.5)
        input.Position = UDim2.new(1, -10, 0.5, 0)
        input.BackgroundColor3 = Color3.fromRGB(40,40,40)
        input.Text = tostring(Settings[configKey] or 0)
        input.TextColor3 = Config.Colors.Text
        input.TextTransparency = 0
        input.ZIndex = 5
        input.Parent = frame
        
        local inputCorner = Instance.new("UICorner")
        inputCorner.CornerRadius = UDim.new(0, 4)
        inputCorner.Parent = input
        
        input.FocusLost:Connect(function()
            local num = tonumber(input.Text)
            if num then
                Settings[configKey] = num
                UpdateLoaderConfig(configKey, num) -- Update Global Config
                SaveSettings()
                Notify(name .. " Set to " .. num)
                Log("Set " .. name .. " to " .. num)
            else
                input.Text = tostring(Settings[configKey] or 0)
            end
        end)
    end

    local function CreateTextInput(name, configKey, placeholder)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 35)
        frame.BackgroundTransparency = 1
        frame.BackgroundColor3 = Color3.new(0,0,0)
        frame.Parent = ConfigPage
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.4, 0, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Config.Colors.Text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextTransparency = 0
        label.ZIndex = 5
        label.Parent = frame
        
        local input = Instance.new("TextBox")
        input.Size = UDim2.new(0, 200, 0, 24)
        input.AnchorPoint = Vector2.new(1, 0.5)
        input.Position = UDim2.new(1, -10, 0.5, 0)
        input.BackgroundColor3 = Color3.fromRGB(40,40,40)
        input.Text = Settings[configKey] or ""
        input.PlaceholderText = placeholder or "..."
        input.TextColor3 = Config.Colors.Text
        input.TextTransparency = 0
        input.ZIndex = 5
        input.ClipsDescendants = true
        input.Parent = frame
        
        local inputCorner = Instance.new("UICorner")
        inputCorner.CornerRadius = UDim.new(0, 4)
        inputCorner.Parent = input
        
        input.FocusLost:Connect(function()
            Settings[configKey] = input.Text
            UpdateLoaderConfig(configKey, input.Text) -- Update Global Config
            SaveSettings()
            Notify(name .. " Updated")
            Log("Updated " .. name)
        end)
    end

    CreateToggle("Auto-DJ", "AutoDJ")
    CreateToggle("Auto-Chain", "AutoChain")
    CreateToggle("Auto-Skip", "AutoSkip")
    CreateToggle("Anti-Lag", "AntiLag")
    CreateToggle("Auto Pickups", "AutoPickups")
    CreateToggle("Anti-AFK", "AntiAFK")
    CreateToggle("Claim Rewards", "ClaimRewards")
    CreateToggle("Send Webhook", "SendWebhook")
    CreateNumberInput("Timescale (0 = Off)", "Timescale")
    CreateTextInput("Webhook URL", "WebhookURL", "Paste Webhook URL...")

    Log("Main Hub Loaded Successfully.")
    Log("Welcome, " .. Player.Name)
-- end)

-- Start Animation and Show Hub
task.spawn(function()
    animate()
    HubGui.Enabled = true
end)

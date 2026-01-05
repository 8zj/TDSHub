local Logger = {}
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local CoreGui = game:GetService("CoreGui")

-- // UI Creation
local function create_ui()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SkeetLogger"
    -- Try to parent to CoreGui for security/visibility, fallback to PlayerGui
    pcall(function() ScreenGui.Parent = CoreGui end)
    if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 500, 0, 350)
    MainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    MainFrame.BorderSizePixel = 1
    MainFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    -- Gamesense Gradient Top Bar
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 2)
    TopBar.Position = UDim2.new(0, 0, 0, 0)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local UIGradient = Instance.new("UIGradient")
    UIGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 175, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0))
    })
    UIGradient.Parent = TopBar

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Text = "TDS Script V3 - Console"
    Title.Size = UDim2.new(1, -20, 0, 25)
    Title.Position = UDim2.new(0, 10, 0, 5)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = Color3.fromRGB(220, 220, 220)
    Title.Font = Enum.Font.Code
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = MainFrame

    -- Inner Container (Console Output)
    local ConsoleFrame = Instance.new("ScrollingFrame")
    ConsoleFrame.Name = "ConsoleFrame"
    ConsoleFrame.Size = UDim2.new(1, -20, 1, -40)
    ConsoleFrame.Position = UDim2.new(0, 10, 0, 35)
    ConsoleFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    ConsoleFrame.BorderColor3 = Color3.fromRGB(35, 35, 35)
    ConsoleFrame.ScrollBarThickness = 4
    ConsoleFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    ConsoleFrame.Parent = MainFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 2)
    UIListLayout.Parent = ConsoleFrame

    return ScreenGui, ConsoleFrame
end

local ScreenGui, ConsoleFrame = create_ui()

-- // Logging Logic
local logs = {}
local MAX_LOGS = 100

function Logger.Log(text, color_name)
    local colors = {
        red = Color3.fromRGB(255, 80, 80),
        green = Color3.fromRGB(100, 255, 100),
        blue = Color3.fromRGB(80, 150, 255),
        yellow = Color3.fromRGB(255, 220, 80),
        white = Color3.fromRGB(220, 220, 220),
        gray = Color3.fromRGB(150, 150, 150)
    }

    local color = colors[color_name] or colors.white
    local timestamp = os.date("%H:%M:%S")
    
    local Label = Instance.new("TextLabel")
    Label.Text = string.format("[%s] %s", timestamp, text)
    Label.TextColor3 = color
    Label.Font = Enum.Font.Code
    Label.TextSize = 13
    Label.Size = UDim2.new(1, 0, 0, 0)
    Label.AutomaticSize = Enum.AutomaticSize.Y
    Label.BackgroundTransparency = 1
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextWrapped = true
    Label.Parent = ConsoleFrame

    table.insert(logs, Label)
    if #logs > MAX_LOGS then
        logs[1]:Destroy()
        table.remove(logs, 1)
    end

    -- Auto scroll
    ConsoleFrame.CanvasPosition = Vector2.new(0, ConsoleFrame.AbsoluteCanvasSize.Y)
end

function Logger.Print(text)
    Logger.Log(text, "white")
end

function Logger.Warn(text)
    Logger.Log(text, "yellow")
end

function Logger.Error(text)
    Logger.Log(text, "red")
end

function Logger.Success(text)
    Logger.Log(text, "green")
end

return Logger

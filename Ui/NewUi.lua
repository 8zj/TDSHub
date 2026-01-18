-- PickHub UI Library
-- Simple logging system for Hub.lua

local PickHubUI = {}

local COLORS = {
    green = Color3.fromRGB(0, 255, 0),
    red = Color3.fromRGB(255, 0, 0),
    yellow = Color3.fromRGB(255, 255, 0),
    blue = Color3.fromRGB(0, 120, 255),
    white = Color3.fromRGB(255, 255, 255),
    orange = Color3.fromRGB(255, 165, 0),
    purple = Color3.fromRGB(128, 0, 128)
}

local function get_env_table()
    if getenv then
        return getenv()
    end
    if getgenv then
        return getgenv()
    end
    return _G
end

local function resolve_color(color)
    if typeof(color) == "Color3" then
        return color
    end
    if typeof(color) == "string" then
        return COLORS[color] or COLORS.white
    end
    return COLORS.white
end

-- Create the UI
function PickHubUI:CreateUI()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Cleanup existing UI
    for _, ui in ipairs(PlayerGui:GetChildren()) do
        if ui.Name == "PickHub_Console" then ui:Destroy() end
    end
    
    -- Main Console
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PickHub_Console"
    ScreenGui.Parent = PlayerGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false
    
    -- Console Frame
    local ConsoleFrame = Instance.new("Frame")
    ConsoleFrame.Name = "ConsoleFrame"
    ConsoleFrame.Parent = ScreenGui
    ConsoleFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    ConsoleFrame.BorderSizePixel = 0
    ConsoleFrame.Position = UDim2.new(0.02, 0, 0.02, 0)
    ConsoleFrame.Size = UDim2.new(0.3, 0, 0.4, 0)
    
    -- Stroke
    local stroke = Instance.new("UIStroke")
    stroke.Parent = ConsoleFrame
    stroke.Color = Color3.fromRGB(50, 50, 50)
    stroke.Thickness = 2
    
    -- Title
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Parent = ConsoleFrame
    Title.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    Title.BorderSizePixel = 0
    Title.Size = UDim2.new(1, 0, 0, 25)
    Title.Font = Enum.Font.Code
    Title.Text = "PickHub Console"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 14
    
    -- Scroll Frame
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Name = "ScrollFrame"
    ScrollFrame.Parent = ConsoleFrame
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.Position = UDim2.new(0, 5, 0, 30)
    ScrollFrame.Size = UDim2.new(1, -10, 1, -35)
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    local Layout = Instance.new("UIListLayout", ScrollFrame)
    Layout.Padding = UDim.new(0, 5)
    
    -- Make draggable
    local dragging = false
    local dragInput, dragStart, startPos
    
    Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = ConsoleFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    Title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            ConsoleFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    self.ScrollFrame = ScrollFrame
    return ScreenGui
end

function PickHubUI:log(text, color)
    if not self.ScrollFrame then
        self:CreateUI()
    end
    
    local color3 = resolve_color(color)
    
    local logLabel = Instance.new("TextLabel")
    logLabel.Name = "Log"
    logLabel.Parent = self.ScrollFrame
    logLabel.BackgroundTransparency = 1
    logLabel.Size = UDim2.new(1, 0, 0, 20)
    logLabel.Font = Enum.Font.Code
    logLabel.Text = "[PickHub] " .. text
    logLabel.TextColor3 = color3
    logLabel.TextSize = 12
    logLabel.TextXAlignment = Enum.TextXAlignment.Left
    logLabel.TextWrapped = true
    logLabel.AutomaticSize = Enum.AutomaticSize.Y
    
    -- Auto-scroll to bottom
    task.wait()
    self.ScrollFrame.CanvasPosition = Vector2.new(0, self.ScrollFrame.CanvasSize.Y.Offset)
    
    print("[PickHub] " .. text)
end

function PickHubUI:logs(text, colorName)
    self:log(text, colorName)
end

function PickHubUI:Init()
    self:CreateUI()
    self:log("Console initialized", "green")
    return self
end

local env = get_env_table()
env.PickHubUI = PickHubUI:Init()

local function global_log(text, color)
    PickHubUI:log(text, color)
end

local function global_logs(text, color)
    PickHubUI:logs(text, color)
end

env.Log = global_log
env.log = global_log
env.Logs = global_logs
env.logs = global_logs

_G.Log = global_log
_G.log = global_log
_G.Logs = global_logs
_G.logs = global_logs

return PickHubUI

-- PickHub UI Library
-- Refactored to match Rec.lua style (Skeet-like)

local PickHubUI = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
    if getenv then return getenv() end
    if getgenv then return getgenv() end
    return _G
end

local function resolve_color(color)
    if typeof(color) == "Color3" then return color end
    if typeof(color) == "string" then return COLORS[color] or COLORS.white end
    return COLORS.white
end

-- // UI Creation Helpers // --
local function create_stroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Parent = parent
    stroke.Color = color or Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return stroke
end

local function create_gradient(parent)
    local gradient = Instance.new("UIGradient")
    gradient.Parent = parent
    gradient.Rotation = 0 

    -- Animate Gradient (Smooth Cycle)
    task.spawn(function()
        local t = 0
        while gradient.Parent do
            t = t + 0.002
            if t > 1 then t = t - 1 end
            
            local colors = {}
            for i = 0, 10 do
                local pos = i / 10
                local hue = (t + pos * 0.5) % 1
                table.insert(colors, ColorSequenceKeypoint.new(pos, Color3.fromHSV(hue, 0.85, 1)))
            end
            
            gradient.Color = ColorSequence.new(colors)
            task.wait(0.016)
        end
    end)
    return gradient
end

-- // Data Fetching // --
local function fetch_game_data()
    local current_mode = "Unknown"
    local current_map = "Unknown"
    local tower_list = {}
    
    local state_folder = ReplicatedStorage:FindFirstChild("State")
    if state_folder then
        if state_folder:FindFirstChild("Difficulty") then
            current_mode = state_folder.Difficulty.Value
        end
        if state_folder:FindFirstChild("Map") then
            current_map = state_folder.Map.Value
        end
    end

    local state_replicators = ReplicatedStorage:FindFirstChild("StateReplicators")
    if state_replicators then
        for _, folder in ipairs(state_replicators:GetChildren()) do
            if folder.Name == "PlayerReplicator" and folder:GetAttribute("UserId") == Players.LocalPlayer.UserId then
                local equipped = folder:GetAttribute("EquippedTowers")
                if type(equipped) == "string" then
                    local cleaned_json = equipped:match("%[.*%]") 
                    local success, tower_table = pcall(function()
                        return HttpService:JSONDecode(cleaned_json)
                    end)
                    if success and type(tower_table) == "table" then
                        tower_list = tower_table
                    end
                end
            end
        end
    end
    
    return current_mode, current_map, tower_list
end

function PickHubUI:CreateUI()
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    -- Cleanup existing UI
    for _, ui in ipairs(PlayerGui:GetChildren()) do
        if ui.Name == "PickHub_UI" then ui:Destroy() end
    end

    local screen_gui = Instance.new("ScreenGui")
    screen_gui.Name = "PickHub_UI"
    screen_gui.ResetOnSpawn = false
    screen_gui.Parent = PlayerGui
    self.ScreenGui = screen_gui

    -- // Loading Screen // --
    local loading_bg = Instance.new("Frame", screen_gui)
    loading_bg.Name = "loading_bg"
    loading_bg.Size = UDim2.new(1, 0, 1, 0)
    loading_bg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    loading_bg.BackgroundTransparency = 0.2
    loading_bg.BorderSizePixel = 0

    local loading_frame = Instance.new("Frame", loading_bg)
    loading_frame.Name = "loading_frame"
    loading_frame.Size = UDim2.new(0, 300, 0, 100)
    loading_frame.Position = UDim2.new(0.5, -150, 0.5, -50)
    loading_frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    loading_frame.BorderSizePixel = 0
    create_stroke(loading_frame, Color3.fromRGB(45, 45, 45), 1)

    local loading_title = Instance.new("TextLabel", loading_frame)
    loading_title.Size = UDim2.new(1, 0, 0, 30)
    loading_title.Position = UDim2.new(0, 0, 0, 10)
    loading_title.BackgroundTransparency = 1
    loading_title.Text = "INITIALIZING PICKHUB"
    loading_title.TextColor3 = Color3.fromRGB(255, 255, 255)
    loading_title.Font = Enum.Font.GothamBold
    loading_title.TextSize = 16

    local loading_status = Instance.new("TextLabel", loading_frame)
    loading_status.Size = UDim2.new(1, 0, 0, 20)
    loading_status.Position = UDim2.new(0, 0, 0, 40)
    loading_status.BackgroundTransparency = 1
    loading_status.Text = "Waiting..."
    loading_status.TextColor3 = Color3.fromRGB(180, 180, 180)
    loading_status.Font = Enum.Font.Code
    loading_status.TextSize = 12

    local progress_bg = Instance.new("Frame", loading_frame)
    progress_bg.Size = UDim2.new(0.8, 0, 0, 4)
    progress_bg.Position = UDim2.new(0.1, 0, 0.75, 0)
    progress_bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    progress_bg.BorderSizePixel = 0
    Instance.new("UICorner", progress_bg).CornerRadius = UDim.new(1, 0)

    local progress_bar = Instance.new("Frame", progress_bg)
    progress_bar.Size = UDim2.new(0, 0, 1, 0)
    progress_bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    progress_bar.BorderSizePixel = 0
    Instance.new("UICorner", progress_bar).CornerRadius = UDim.new(1, 0)
    create_gradient(progress_bar)

    -- // Main Window // --
    local main_frame = Instance.new("Frame", screen_gui)
    main_frame.Name = "main_frame"
    main_frame.Size = UDim2.new(0, 450, 0, 300)
    main_frame.Position = UDim2.new(0.5, -225, 0.4, -150)
    main_frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    main_frame.Visible = false -- Hidden initially
    main_frame.Active = true
    main_frame.Draggable = true
    create_stroke(main_frame, Color3.fromRGB(45, 45, 45), 1)

    -- Accent Bar
    local top_bar = Instance.new("Frame", main_frame)
    top_bar.Size = UDim2.new(1, 0, 0, 2)
    top_bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    top_bar.BorderSizePixel = 0
    create_gradient(top_bar)

    -- Title
    local title_label = Instance.new("TextLabel", main_frame)
    title_label.Size = UDim2.new(1, -10, 0, 25)
    title_label.Position = UDim2.new(0, 10, 0, 5)
    title_label.Text = "PICKHUB v2"
    title_label.TextColor3 = Color3.fromRGB(255, 255, 255)
    title_label.BackgroundTransparency = 1
    title_label.Font = Enum.Font.Code
    title_label.TextSize = 14
    title_label.TextXAlignment = Enum.TextXAlignment.Left

    -- Close Button
    local close_btn = Instance.new("TextButton", main_frame)
    close_btn.Size = UDim2.new(0, 20, 0, 20)
    close_btn.Position = UDim2.new(1, -25, 0, 5)
    close_btn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    close_btn.Text = "X"
    close_btn.TextColor3 = Color3.fromRGB(150, 150, 150)
    close_btn.Font = Enum.Font.Code
    close_btn.TextSize = 14
    close_btn.BorderSizePixel = 0
    close_btn.MouseButton1Click:Connect(function()
        screen_gui:Destroy()
    end)

    -- Content Container
    local content_container = Instance.new("Frame", main_frame)
    content_container.Size = UDim2.new(1, -20, 1, -40)
    content_container.Position = UDim2.new(0, 10, 0, 30)
    content_container.BackgroundTransparency = 1

    -- Left Panel (Info)
    local left_panel = Instance.new("Frame", content_container)
    left_panel.Size = UDim2.new(0.4, -5, 1, 0)
    left_panel.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    create_stroke(left_panel, Color3.fromRGB(40, 40, 40), 1)

    -- Game Info Display
    local info_frame = Instance.new("Frame", left_panel)
    info_frame.Size = UDim2.new(1, -10, 1, -10) -- Fill left panel
    info_frame.Position = UDim2.new(0, 5, 0, 5)
    info_frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    create_stroke(info_frame, Color3.fromRGB(50, 50, 50), 1)

    local function create_info_label(parent, text, y_pos)
        local label = Instance.new("TextLabel", parent)
        label.Size = UDim2.new(1, -10, 0, 15)
        label.Position = UDim2.new(0, 5, 0, y_pos)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(150, 150, 150)
        label.Font = Enum.Font.Code
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        return label
    end

    local map_label = create_info_label(info_frame, "Map: Waiting...", 5)
    local mode_label = create_info_label(info_frame, "Mode: Waiting...", 25)
    local loadout_header = create_info_label(info_frame, "Loadout:", 50)
    loadout_header.TextColor3 = Color3.fromRGB(200, 200, 200)

    local loadout_list = Instance.new("TextLabel", info_frame)
    loadout_list.Size = UDim2.new(1, -10, 0, 80)
    loadout_list.Position = UDim2.new(0, 5, 0, 65)
    loadout_list.BackgroundTransparency = 1
    loadout_list.Text = "...\n...\n...\n...\n..."
    loadout_list.TextColor3 = Color3.fromRGB(150, 150, 150)
    loadout_list.Font = Enum.Font.Code
    loadout_list.TextSize = 11
    loadout_list.TextXAlignment = Enum.TextXAlignment.Left
    loadout_list.TextYAlignment = Enum.TextYAlignment.Top

    -- Right Panel (Logs)
    local right_panel = Instance.new("Frame", content_container)
    right_panel.Size = UDim2.new(0.6, -5, 1, 0)
    right_panel.Position = UDim2.new(0.4, 5, 0, 0)
    right_panel.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    create_stroke(right_panel, Color3.fromRGB(40, 40, 40), 1)

    local log_header = Instance.new("TextLabel", right_panel)
    log_header.Size = UDim2.new(1, -10, 0, 20)
    log_header.Position = UDim2.new(0, 5, 0, 5)
    log_header.BackgroundTransparency = 1
    log_header.Text = "EVENT LOG"
    log_header.TextColor3 = Color3.fromRGB(180, 180, 180)
    log_header.Font = Enum.Font.Code
    log_header.TextSize = 12
    log_header.TextXAlignment = Enum.TextXAlignment.Left

    local log_box = Instance.new("ScrollingFrame", right_panel)
    log_box.Size = UDim2.new(1, -10, 1, -30)
    log_box.Position = UDim2.new(0, 5, 0, 25)
    log_box.BackgroundTransparency = 1
    log_box.ScrollBarThickness = 2
    log_box.ScrollBarImageColor3 = Color3.fromRGB(100, 255, 100)
    
    local log_layout = Instance.new("UIListLayout", log_box)
    log_layout.Padding = UDim.new(0, 2)
    
    self.LogBox = log_box
    self.LogLayout = log_layout

    -- Update Info Helper
    local function update_ui_info()
        local mode, map, towers = fetch_game_data()
        map_label.Text = "Map: " .. map
        mode_label.Text = "Mode: " .. mode
        
        local loadout_text = ""
        for i = 1, 5 do
            local t = towers[i] or "Empty"
            loadout_text = loadout_text .. i .. ". " .. t .. "\n"
        end
        loadout_list.Text = loadout_text
    end

    -- Initialization Sequence
    task.spawn(function()
        local function set_progress(pct, text)
            loading_status.Text = text
            TweenService:Create(progress_bar, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(pct, 0, 1, 0)
            }):Play()
        end

        set_progress(0, "Initializing PickHub...")
        task.wait(0.5)
        
        set_progress(0.4, "Loading Config...")
        task.wait(0.6)
        
        set_progress(0.7, "Scanning Game Data...")
        update_ui_info()
        task.wait(0.6)
        
        set_progress(1, "Ready!")
        task.wait(0.5)
        
        -- Fade out loading
        local tween_info = TweenInfo.new(0.5)
        TweenService:Create(loading_bg, tween_info, {BackgroundTransparency = 1}):Play()
        TweenService:Create(loading_frame, tween_info, {BackgroundTransparency = 1}):Play()
        TweenService:Create(loading_title, tween_info, {TextTransparency = 1}):Play()
        TweenService:Create(loading_status, tween_info, {TextTransparency = 1}):Play()
        TweenService:Create(progress_bg, tween_info, {BackgroundTransparency = 1}):Play()
        TweenService:Create(progress_bar, tween_info, {BackgroundTransparency = 1}):Play()
        
        task.wait(0.5)
        loading_bg.Visible = false
        
        -- Show Main UI
        main_frame.Visible = true
        main_frame.Size = UDim2.new(0, 450, 0, 0) -- Start collapsed
        TweenService:Create(main_frame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 450, 0, 300)
        }):Play()
    end)
end

function PickHubUI:log(text, color)
    if not self.ScreenGui then
        self:CreateUI()
    end
    
    local color3 = resolve_color(color)
    local log_item = Instance.new("TextLabel", self.LogBox)
    log_item.Size = UDim2.new(1, 0, 0, 14)
    log_item.BackgroundTransparency = 1
    log_item.TextColor3 = color3
    log_item.Text = "> " .. text
    log_item.Font = Enum.Font.Code
    log_item.TextSize = 10
    log_item.TextXAlignment = Enum.TextXAlignment.Left
    
    if self.LogLayout then
        self.LogBox.CanvasSize = UDim2.new(0, 0, 0, self.LogLayout.AbsoluteContentSize.Y)
        self.LogBox.CanvasPosition = Vector2.new(0, self.LogBox.CanvasSize.Y.Offset)
    end
    
    print("[PickHub] " .. text)
end

function PickHubUI:logs(text, colorName)
    self:log(text, colorName)
end

function PickHubUI:Init()
    self:CreateUI()
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

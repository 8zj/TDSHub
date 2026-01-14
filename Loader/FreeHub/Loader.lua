local Config = getgenv().PickHubLOL or {
    AutoStrat = true,
    autoskip = false,
    AntiLag = true,
    AutoPickups = false,
    SendWebhook = false,
    Webhook = "",
    Loadout = {},
    Mode = "",
    GameInfo = {""},
    TimeScale = false
}

-- Handle case sensitivity for autoskip if needed
if Config.AutoSkip == nil and Config.autoskip ~= nil then
    Config.AutoSkip = Config.autoskip
end

-- Ensure Config has defaults if keys are missing
Config.AutoSkip = Config.AutoSkip or false
Config.AutoPickups = Config.AutoPickups or false
Config.AntiLag = Config.AntiLag or false
Config.SendWebhook = Config.SendWebhook or false
Config.Webhook = Config.Webhook or ""


repeat 
    task.wait() 
until game:IsLoaded()

local player = game:GetService("Players").LocalPlayer
local pGui = player:WaitForChild("PlayerGui")

local function isFullyLoaded()
    local hud = pGui:FindFirstChild("GameGui") or pGui:FindFirstChild("LobbyGui")
    if hud and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        return true
    end
    return false
end

if not isFullyLoaded() then
    repeat 
        task.wait(10) 
    until isFullyLoaded()
end

task.wait(1)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local pGui = LocalPlayer:WaitForChild("PlayerGui")

--// Cleanup
for _, ui in ipairs(pGui:GetChildren()) do
    if ui.Name == "PickHub_Main_UI" then ui:Destroy() end
end

local function createSkeetFrame(name, parent, size, anchor, pos)
    local Outline = Instance.new("Frame")
    Outline.Name = name
    Outline.Parent = parent
    Outline.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Outline.BorderSizePixel = 0
    Outline.AnchorPoint = anchor
    Outline.Position = pos
    Outline.Size = size

    local MainFrame = Instance.new("Frame")
    MainFrame.Parent = Outline
    MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0, 1, 0, 1)
    MainFrame.Size = UDim2.new(1, -2, 1, -2)

    local InnerFrame = Instance.new("Frame")
    InnerFrame.Parent = MainFrame
    InnerFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80) 
    InnerFrame.BorderSizePixel = 0
    InnerFrame.Position = UDim2.new(0, 2, 0, 2)
    InnerFrame.Size = UDim2.new(1, -4, 1, -4)

    local InnerFill = Instance.new("Frame")
    InnerFill.Parent = InnerFrame
    InnerFill.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    InnerFill.BorderSizePixel = 0
    InnerFill.Position = UDim2.new(0, 1, 0, 1)
    InnerFill.Size = UDim2.new(1, -2, 1, -2)

    local L1 = Instance.new("Frame")
    L1.Size = UDim2.new(1, 0, 0, 1)
    L1.BorderSizePixel = 0
    L1.Parent = InnerFill

    local L2 = Instance.new("Frame")
    L2.Position = UDim2.new(0, 0, 0, 1)
    L2.Size = UDim2.new(1, 0, 0, 1)
    L2.BorderSizePixel = 0
    L2.Parent = InnerFill

    local function round(obj)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 3)
        c.Parent = obj
    end
    round(Outline) round(MainFrame) round(InnerFrame) round(InnerFill)

    return Outline, InnerFill, L1, L2
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PickHub_Main_UI"
ScreenGui.Parent = pGui
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false

--// TOP WATERMARK
local WM_O, WM_F, WM_L1, WM_L2 = createSkeetFrame("Watermark", ScreenGui, UDim2.new(0, 320, 0, 30), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 40))
local WM_Label = Instance.new("TextLabel", WM_F)
WM_Label.BackgroundTransparency = 1 WM_Label.Size = UDim2.new(1, 0, 1, 0)
WM_Label.Font = Enum.Font.Code WM_Label.TextColor3 = Color3.fromRGB(255, 255, 255) WM_Label.TextSize = 14 WM_Label.TextXAlignment = Enum.TextXAlignment.Center

--// BOTTOM HUD (Clean Layout)
local HUD_O, HUD_F, HUD_L1, HUD_L2 = createSkeetFrame("BottomHUD", ScreenGui, UDim2.new(0, 580, 0, 34), Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -130))
local HUD_Label = Instance.new("TextLabel", HUD_F)
HUD_Label.BackgroundTransparency = 1 HUD_Label.Position = UDim2.new(0, 45, 0, 0) HUD_Label.Size = UDim2.new(1, -55, 1, 0)
HUD_Label.Font = Enum.Font.Code HUD_Label.TextColor3 = Color3.fromRGB(255, 255, 255) HUD_Label.TextSize = 13 HUD_Label.TextXAlignment = Enum.TextXAlignment.Left

local PlayerIcon = Instance.new("ImageLabel", HUD_F)
PlayerIcon.BackgroundTransparency = 1 PlayerIcon.Position = UDim2.new(0, 10, 0.5, -11) PlayerIcon.Size = UDim2.new(0, 22, 0, 22)
PlayerIcon.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
Instance.new("UICorner", PlayerIcon).CornerRadius = UDim.new(1, 0)

--// CONSOLE (PickLogger Center)
local Console_O, Console_F, Console_L1, Console_L2 = createSkeetFrame("Console", ScreenGui, UDim2.new(0, 450, 0, 250), Vector2.new(1, 1), UDim2.new(1, -20, 1, -20))
local PickLabel = Instance.new("TextLabel", Console_F) 
PickLabel.Size = UDim2.new(1, 0, 0, 30) PickLabel.Position = UDim2.new(0, 0, 0, 8)
PickLabel.BackgroundTransparency = 1 PickLabel.Font = Enum.Font.Code PickLabel.TextSize = 18 PickLabel.TextXAlignment = Enum.TextXAlignment.Center
PickLabel.Text = "PickLogger"
local PickGrad = Instance.new("UIGradient", PickLabel)
local PickStroke = Instance.new("UIStroke", PickLabel)
PickStroke.Thickness = 1 PickStroke.Color = Color3.fromRGB(255,255,255) PickStroke.Transparency = 0.5

local LogScroll = Instance.new("ScrollingFrame", Console_F) LogScroll.BackgroundTransparency = 1 LogScroll.Position = UDim2.new(0, 12, 0, 40) LogScroll.Size = UDim2.new(1, -24, 1, -50) LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0) LogScroll.ScrollBarThickness = 1 LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local LogList = Instance.new("UIListLayout", LogScroll) LogList.Padding = UDim.new(0, 4)

_G.Log = function(text, color)
    local ml = Instance.new("TextLabel", LogScroll) 
    ml.Size = UDim2.new(1, 0, 0, 18) ml.BackgroundTransparency = 1 
    ml.Font = Enum.Font.Code ml.TextSize = 13 
    ml.TextColor3 = color or Color3.fromRGB(255, 255, 255) 
    ml.Text = "»  " .. tostring(text) -- Clean arrow indicator instead of timestamp
    ml.TextXAlignment = Enum.TextXAlignment.Left 
    ml.TextWrapped = true
    task.defer(function() LogScroll.CanvasPosition = Vector2.new(0, LogScroll.AbsoluteCanvasSize.Y) end)
end

--// Logic functions
local lastIteration, frameCount, fps = tick(), 0, 0
local function updateFPS()
    frameCount = frameCount + 1
    if tick() - lastIteration >= 1 then
        fps = frameCount
        frameCount = 0
        lastIteration = tick()
    end
    return fps
end

local function get_wave()
    local s, v = pcall(function() return pGui:WaitForChild("ReactGameTopGameDisplay", 2).Frame.wave.container.value.Text:match("^(%d+)") end)
    return s and v or "0"
end

local function countZombies()
    local folder = workspace:FindFirstChild("NPCs")
    if not folder then return 0 end
    local c = 0
    for _, z in ipairs(folder:GetChildren()) do
        if z:IsA("Model") and z.Name ~= "Red" and z.Name ~= "Blue" then c = c + 1 end
    end
    return c
end

local function get_gametype()
    return pGui:FindFirstChild("LobbyGui") and "Lobby" or (pGui:FindFirstChild("GameGui") and "Game" or "Menu")
end

local customText = "PickHub [ Auto Strat ]"
local curWM = ""

RunService.RenderStepped:Connect(function()
    local t = tick()
    local glow = (math.sin(t * 6) + 1) / 2
    local shiny = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)), 
        ColorSequenceKeypoint.new(glow, Color3.fromRGB(255, 255, 255)), 
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 0))
    })
    
    WM_L1.BackgroundColor3 = Color3.fromRGB(0, 255, 0) WM_L2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    HUD_L1.BackgroundColor3 = Color3.fromRGB(0, 255, 0) HUD_L2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Console_L1.BackgroundColor3 = Color3.fromRGB(0, 255, 0) Console_L2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    
    PickGrad.Color = shiny
    WM_Label.Text = curWM
    local devider = "  ┃  "
    HUD_Label.Text = string.format("%s%s%s%sWave: %s%sZombies: %d%sFPS: %d", 
        LocalPlayer.Name, devider, get_gametype(), devider, get_wave(), devider, countZombies(), devider, updateFPS())
end)

task.spawn(function()
    while true do
        for i = 1, #customText do curWM = string.sub(customText, 1, i) task.wait(0.08) end
        task.wait(3)
        for i = #customText, 0, -1 do curWM = string.sub(customText, 1, i) task.wait(0.04) end
    end
end)


local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local spawnCount = 0 -- Keeps track of total zombies spawned

local function createESP(target)
    if target:FindFirstChild("adasadadda") then return end
    
    spawnCount = spawnCount + 1
    local currentNumber = spawnCount

    --// Clean Outline Effect
    local highlight = Instance.new("Highlight")
    highlight.Name = "adasadadda"
    highlight.Parent = target
    highlight.Adornee = target
    highlight.FillTransparency = 1 
    highlight.OutlineTransparency = 0 
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    --// Billboard for Name
    local bgui = Instance.new("BillboardGui")
    bgui.Name = "asdasdasdasdaas"
    bgui.Parent = target
    bgui.AlwaysOnTop = true
    bgui.Size = UDim2.new(0, 200, 0, 30)
    bgui.ExtentsOffset = Vector3.new(0, 1.2, 0) -- Adjusted height to sit right above head
    bgui.MaxDistance = 400

    local nameLabel = Instance.new("TextLabel", bgui)
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Font = Enum.Font.Code
    nameLabel.TextSize = 14
    -- Format: [ Name ] [ #Count ]
    nameLabel.Text = string.format("[ %s ] [ %d ]", target.Name, currentNumber)
    nameLabel.RichText = true
    
    --// Dual Color UIStroke
    local stroke = Instance.new("UIStroke", nameLabel)
    stroke.Thickness = 2
    local gradient = Instance.new("UIGradient", stroke)

    --// Rainbow Animation Connection
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not target or not target.Parent then
            connection:Disconnect()
            return
        end
        
        local hue = (tick() % 4) / 4 -- Rainbow cycle speed
        local rainbowColor = Color3.fromHSV(hue, 0.7, 1)
        
        highlight.OutlineColor = rainbowColor
        
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, rainbowColor),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
        })
    end)

    --// Cleanup logic
    task.spawn(function()
        local humanoid = target:FindFirstChildOfClass("Humanoid")
        while target and target.Parent do
            if humanoid and humanoid.Health <= 0 then break end
            task.wait(1)
        end
        if connection then connection:Disconnect() end
        highlight:Destroy()
        bgui:Destroy()
    end)
end

--// Scan for Zombies
task.spawn(function()
    while true do
        local npcFolder = workspace:FindFirstChild("NPCs")
        if npcFolder then
            for _, zombie in ipairs(npcFolder:GetChildren()) do
                if zombie:IsA("Model") and not zombie:FindFirstChild("PickHub_ESP_Highlight") then
                    if zombie:FindFirstChild("HumanoidRootPart") then
                        createESP(zombie)
                    end
                end
            end
        end
        task.wait()
    end
end)
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

--// 1. Setup UI (Locked at Bottom-Left of HUD)
if CoreGui:FindFirstChild("PickHub_SkeetList") then 
    CoreGui.PickHub_SkeetList:Destroy() 
end

local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "PickHub_SkeetList"

local function CreateSkeetWindow(title, size, position)
    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Size = size
    MainFrame.Position = position 
    MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    MainFrame.BorderSizePixel = 0
    
    local Outline = Instance.new("UIStroke", MainFrame)
    Outline.Color = Color3.fromRGB(0, 0, 0)
    Outline.Thickness = 2
    
    local InnerBorder = Instance.new("Frame", MainFrame)
    InnerBorder.Size = UDim2.new(1, -4, 1, -4)
    InnerBorder.Position = UDim2.new(0, 2, 0, 2)
    InnerBorder.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    InnerBorder.BorderSizePixel = 0
    
    local ContentFill = Instance.new("Frame", InnerBorder)
    ContentFill.Size = UDim2.new(1, -2, 1, -2)
    ContentFill.Position = UDim2.new(0, 1, 0, 1)
    ContentFill.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    ContentFill.BorderSizePixel = 0

    local GreenLine = Instance.new("Frame", ContentFill)
    GreenLine.Size = UDim2.new(1, 0, 0, 1)
    GreenLine.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    
    local WhiteLine = Instance.new("Frame", ContentFill)
    WhiteLine.Size = UDim2.new(1, 0, 0, 1)
    WhiteLine.Position = UDim2.new(0, 0, 0, 1)
    WhiteLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

    local Title = Instance.new("TextLabel", ContentFill)
    Title.Size = UDim2.new(1, 0, 0, 28)
    Title.BackgroundTransparency = 1
    Title.Text = title
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.Code
    Title.TextSize = 13
    local TitleGrad = Instance.new("UIGradient", Title)

    local ListContainer = Instance.new("Frame", ContentFill)
    ListContainer.Name = "Container"
    ListContainer.Size = UDim2.new(1, -20, 1, -35)
    ListContainer.Position = UDim2.new(0.5, 0, 0, 32)
    ListContainer.AnchorPoint = Vector2.new(0.5, 0)
    ListContainer.BackgroundTransparency = 1
    
    local Layout = Instance.new("UIListLayout", ListContainer)
    Layout.Padding = UDim.new(0, 6)

    RunService.RenderStepped:Connect(function()
        local t = tick()
        local glow = (math.sin(t * 5) + 1) / 2
        TitleGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)), 
            ColorSequenceKeypoint.new(glow, Color3.fromRGB(255, 255, 255)), 
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 0))
        })
    end)

    return ListContainer
end

local SkeetList = CreateSkeetWindow("LOADOUT", UDim2.new(0, 190, 0, 160), UDim2.new(0.5, -492, 1, -244))

--// 2. Function to Refresh UI Labels
local function UpdateUI(towerTable)
    SkeetList:ClearAllChildren()
    Instance.new("UIListLayout", SkeetList).Padding = UDim.new(0, 6)
    
    for i = 1, 5 do
        local name = towerTable[i] or "None"
        local Label = Instance.new("TextLabel", SkeetList)
        Label.Size = UDim2.new(1, 0, 0, 18)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.RichText = true
        Label.Text = string.format("<Font color='#FFFFFF'>[ %d ] %s</Font>", i, name)
        Label.Font = Enum.Font.Code
        Label.TextSize = 12
        Label.TextXAlignment = Enum.TextXAlignment.Left
    end
end




_G.Log("Loadded { PickHub }", Color3.fromRGB(200, 255, 200))

local function identify_game_state()
    local players = game:GetService("Players")
    local temp_player = players.LocalPlayer or players.PlayerAdded:Wait()
    local temp_gui = temp_player:WaitForChild("PlayerGui")
    
    while true do
        if temp_gui:FindFirstChild("LobbyGui") then
            return "LOBBY"
        elseif temp_gui:FindFirstChild("GameGui") then
            return "GAME"
        end
        task.wait(1)
    end
end

local game_state = identify_game_state()

local send_request = request or http_request or httprequest
    or GetDevice and GetDevice().request

if not send_request then 
    warn("failure: no http function") 
    return 
end

-- // services & main refs
local replicated_storage = game:GetService("ReplicatedStorage")
local remote_func = replicated_storage:WaitForChild("RemoteFunction")
local remote_event = replicated_storage:WaitForChild("RemoteEvent")
local players_service = game:GetService("Players")
local local_player = players_service.LocalPlayer or players_service.PlayerAdded:Wait()
local player_gui = local_player:WaitForChild("PlayerGui")

local back_to_lobby_running = false
local auto_pickups_running = false
local auto_skip_running = false
local anti_lag_running = false

-- // icon item ids ill add more soon arghh
local ItemNames = {
    ["17447507910"] = "Timescale Ticket(s)",
    ["17438486690"] = "Range Flag(s)",
    ["17438486138"] = "Damage Flag(s)",
    ["17438487774"] = "Cooldown Flag(s)",
    ["17429537022"] = "Blizzard(s)",
    ["17448596749"] = "Napalm Strike(s)",
    ["18493073533"] = "Spin Ticket(s)",
    ["17429548305"] = "Supply Drop(s)",
    ["18443277308"] = "Low Grade Consumable Crate(s)",
    ["136180382135048"] = "Santa Radio(s)",
    ["18443277106"] = "Mid Grade Consumable Crate(s)",
    ["18443277591"] = "High Grade Consumable Crate(s)",
    ["132155797622156"] = "Christmas Tree(s)",
    ["124065875200929"] = "Fruit Cake(s)",
    ["17429541513"] = "Barricade(s)",
    ["110415073436604"] = "Holy Hand Grenade(s)",
    ["139414922355803"] = "Present Clusters(s)"
}

-- // tower management core
local TDS = {
    placed_towers = {},
    active_strat = true
}

local upgrade_history = {}

-- // shared for addons
shared.TDS_Table = TDS

-- // currency tracking
local start_coins, current_total_coins, start_gems, current_total_gems = 0, 0, 0, 0
if game_state == "GAME" then
    pcall(function()
        repeat task.wait(1) until local_player:FindFirstChild("Coins")
        _G.Log("Current Coins: $" .. local_player.Coins.Value, Color3.fromRGB(253, 253, 253))
        start_coins = local_player.Coins.Value
        current_total_coins = start_coins
        start_gems = local_player.Gems.Value
        current_total_gems = start_gems
    end)
end

-- // check if remote returned valid
local function check_res_ok(data)
    if data == true then return true end
    if type(data) == "table" and data.Success == true then return true end

    local success, is_model = pcall(function()
        return data and data:IsA("Model")
    end)
    
    if success and is_model then return true end
    if type(data) == "userdata" then return true end

    return false
end

-- // scrap ui for match data
local function get_all_rewards()
    local results = {
        Coins = 0, 
        Gems = 0, 
        XP = 0, 
        Wave = 0,
        Level = 0,
        Time = "00:00",
        Status = "UNKNOWN",
        Others = {} 
    }
    
    local ui_root = player_gui:FindFirstChild("ReactGameNewRewards")
    local main_frame = ui_root and ui_root:FindFirstChild("Frame")
    local game_over = main_frame and main_frame:FindFirstChild("gameOver")
    local rewards_screen = game_over and game_over:FindFirstChild("RewardsScreen")
    
    local game_stats = rewards_screen and rewards_screen:FindFirstChild("gameStats")
    local stats_list = game_stats and game_stats:FindFirstChild("stats")
    
    if stats_list then
        for _, frame in ipairs(stats_list:GetChildren()) do
            local l1 = frame:FindFirstChild("textLabel")
            local l2 = frame:FindFirstChild("textLabel2")
            if l1 and l2 and l1.Text:find("Time Completed:") then
                results.Time = l2.Text
                break
            end
        end
    end

    local top_banner = rewards_screen and rewards_screen:FindFirstChild("RewardBanner")
    if top_banner and top_banner:FindFirstChild("textLabel") then
        local txt = top_banner.textLabel.Text:upper()
        results.Status = txt:find("TRIUMPH") and "WIN" or (txt:find("LOST") and "LOSS" or "UNKNOWN")
    end

    local level_value = local_player.Level
    if level_value then
        results.Level = level_value.Value or 0
    end

    local label = player_gui:WaitForChild("ReactGameTopGameDisplay").Frame.wave.container.value
    local wave_num = label.Text:match("^(%d+)")

    if wave_num then
        results.Wave = tonumber(wave_num) or 0
    end

    local section_rewards = rewards_screen and rewards_screen:FindFirstChild("RewardsSection")
    if section_rewards then
        for _, item in ipairs(section_rewards:GetChildren()) do
            if tonumber(item.Name) then 
                local icon_id = "0"
                local img = item:FindFirstChildWhichIsA("ImageLabel", true)
                if img then icon_id = img.Image:match("%d+") or "0" end

                for _, child in ipairs(item:GetDescendants()) do
                    if child:IsA("TextLabel") then
                        local text = child.Text
                        local amt = tonumber(text:match("(%d+)")) or 0
                        
                        if text:find("Coins") then
                            results.Coins = amt
                        elseif text:find("Gems") then
                            results.Gems = amt
                        elseif text:find("XP") then
                            results.XP = amt
                        elseif text:lower():find("x%d+") then 
                            local displayName = ItemNames[icon_id] or "Unknown Item (" .. icon_id .. ")"
                            table.insert(results.Others, {Amount = text:match("x%d+"), Name = displayName})
                        end
                    end
                end
            end
        end
    end
    
    return results
end

-- // lobby / teleporting
local function send_to_lobby()
    task.wait(1)
    local lobby_remote = game.ReplicatedStorage.Network.Teleport["RE:backToLobby"]
    lobby_remote:FireServer()
end

local function handle_post_match()
    local ui_root
    repeat
        task.wait(1)

        local root = player_gui:FindFirstChild("ReactGameNewRewards")
        local frame = root and root:FindFirstChild("Frame")
        local gameOver = frame and frame:FindFirstChild("gameOver")
        local rewards_screen = gameOver and gameOver:FindFirstChild("RewardsScreen")
        ui_root = rewards_screen and rewards_screen:FindFirstChild("RewardsSection")
    until ui_root

    if not ui_root then return send_to_lobby() end

    if not Config.SendWebhook then
        send_to_lobby()
        return
    end

    local match = get_all_rewards()

    current_total_coins += match.Coins
    current_total_gems += match.Gems

    local bonus_string = ""
    if #match.Others > 0 then
        for _, res in ipairs(match.Others) do
            bonus_string = bonus_string .. "🎁 **" .. res.Amount .. " " .. res.Name .. "**\n"
        end
    else
        bonus_string = "_No bonus rewards found._"
    end

    local post_data = {
        username = "ASE | Auto-Strat Engine",
        embeds = {{
            title = (match.Status == "WIN" and "🏆 Match Victory" or "💀 Match Defeat"),
            color = (match.Status == "WIN" and 5763719 or 15158332), -- Green / Red
            description = "**Match Completed**\n" ..
                "**Status:** `" .. match.Status .. "` • **Time:** `" .. match.Time .. "`\n" ..
                "**Wave:** `" .. match.Wave .. "` • **Level:** `" .. match.Level .. "`",
                
            fields = {
                {
                    name = "📈 Match Rewards",
                    value = "```ini\n" ..
                            "[ Coins: +" .. match.Coins .. " ]\n" ..
                            "[ Gems:  +" .. match.Gems .. "  ]\n" ..
                            "[ XP:    +" .. match.XP .. "    ]```",
                    inline = true
                },
                {
                    name = "🎁 Bonus Loot",
                    value = bonus_string,
                    inline = true
                },
                {
                    name = "� Session Total",
                    value = "```bash\n" ..
                            "Coins: " .. current_total_coins .. "\n" ..
                            "Gems:  " .. current_total_gems .. "```",
                    inline = false
                }
            },
            footer = { text = "ASE • Automated Strategy Execution" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    pcall(function()
        send_request({
            Url = Config.Webhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode(post_data)
        })
    end)

    task.wait(1.5)

    send_to_lobby()
end

local function log_match_start()
    if not Config.SendWebhook then return end
    if type(Config.Webhook) ~= "string" or Config.Webhook == "" then return end
    if Config.Webhook:find("YOUR%-WEBHOOK") then return end
    
    local start_payload = {
        username = "ASE | Auto-Strat Engine",
        embeds = {{
            title = "✅ Engine Initialized",
            description = "**Auto-Strat Engine** has successfully hooked into the match.",
            color = 5763719, -- Clean Green/Blue
            fields = {
                {
                    name = "👤 Operator",
                    value = "`" .. local_player.Name .. "`",
                    inline = true
                },
                {
                    name = "🎒 Resources",
                    value = "🪙 **" .. tostring(start_coins) .. "** Coins\n💎 **" .. tostring(start_gems) .. "** Gems",
                    inline = true
                },
                {
                    name = "📊 Status",
                    value = "```diff\n+ Active & Executing\n```",
                    inline = false
                }
            },
            footer = { text = "ASE • Automated Strategy Execution" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    pcall(function()
        send_request({
            Url = Config.Webhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode(start_payload)
        })
    end)
end

-- // voting & map selection
local function run_vote_skip()
    while true do
        local success = pcall(function()
            remote_func:InvokeServer("Voting", "Skip")
        end)
        if success then 
            _G.Log("Vote Skip", Color3.fromRGB(160, 220, 100))
            break 
        end
        task.wait(0.2)
    end
end

local function match_ready_up()
    local player_gui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
    local ui_overrides = player_gui:WaitForChild("ReactOverridesVote", 30)
    local main_frame = ui_overrides and ui_overrides:WaitForChild("Frame", 30)
    
    if not main_frame then
        return
    end

    local vote_ready = nil

    _G.Log("Waiting for match ready vote...", Color3.fromRGB(255, 255, 255))

    while not vote_ready do
        local vote_node = main_frame:FindFirstChild("votes")
        
        if vote_node then
            local container = vote_node:FindFirstChild("container")
            if container then
                local ready = container:FindFirstChild("ready")
                if ready then
                    vote_ready = ready
                end
            end
        end
        
        if not vote_ready then
            task.wait(0.5) 
        end
    end

    repeat task.wait(0.1) until vote_ready.Visible == true

    _G.Log("Match ready detected, skipping...", Color3.fromRGB(160, 220, 100))
    run_vote_skip()
    log_match_start()
end

local function cast_map_vote(map_id, pos_vec)
    local target_map = map_id or "Simplicity"
    local target_pos = pos_vec or Vector3.new(0,0,0)
    _G.Log("Voting for map: " .. tostring(target_map), Color3.fromRGB(100, 200, 255))
    remote_event:FireServer("LobbyVoting", "Vote", target_map, target_pos)
end

local function lobby_ready_up()
    pcall(function()
        _G.Log("Sending Lobby Ready signal", Color3.fromRGB(160, 220, 100))
        remote_event:FireServer("LobbyVoting", "Ready")
    end)
end

local function select_map_override(map_id)
    _G.Log("Overriding map selection: " .. tostring(map_id), Color3.fromRGB(180, 100, 255))
    remote_func:InvokeServer("LobbyVoting", "Override", map_id)
    task.wait(3)
    cast_map_vote(map_id, Vector3.new(12.59, 10.64, 52.01))
    task.wait(1)
    lobby_ready_up()
    match_ready_up()
end

local function cast_modifier_vote(mods_table)
    local bulk_modifiers = replicated_storage:WaitForChild("Network"):WaitForChild("Modifiers"):WaitForChild("RF:BulkVoteModifiers")
    local selected_mods = mods_table or {
        HiddenEnemies = true, Glass = true, ExplodingEnemies = true,
        Limitation = true, Committed = true, HealthyEnemies = true,
        SpeedyEnemies = true, Quarantine = true, Fog = true,
        FlyingEnemies = true, Broke = true, Jailed = true, Inflation = true
    }

    pcall(function()
        _G.Log("Picking Modifiers "..selected_mods, Color3.fromRGB(100, 200, 255))
        bulk_modifiers:InvokeServer(selected_mods)
    end)
end

-- // timescale logic
local function set_game_timescale(target_val)
    local speed_list = {0, 0.5, 1, 1.5, 2}

    local target_idx
    for i, v in ipairs(speed_list) do
        if v == target_val then
            target_idx = i
            break
        end
    end
    if not target_idx then return end

    local speed_label = game.Players.LocalPlayer.PlayerGui.ReactUniversalHotbar.Frame.timescale.Speed

    local current_val = tonumber(speed_label.Text:match("x([%d%.]+)"))
    if not current_val then return end

    local current_idx
    for i, v in ipairs(speed_list) do
        if v == current_val then
            current_idx = i
            break
        end
    end
    if not current_idx then return end

    local diff = target_idx - current_idx
    if diff < 0 then
        diff = #speed_list + diff
    end

    if diff > 0 then
        _G.Log("Adjusting Timescale to x" .. tostring(target_val), Color3.fromRGB(100, 200, 255))
        for _ = 1, diff do
            replicated_storage.RemoteFunction:InvokeServer(
                "TicketsManager",
                "CycleTimeScale"
            )
            task.wait(0.5)
        end
        _G.Log("Timescale set successfully", Color3.fromRGB(160, 220, 100))
    end
end

local function unlock_speed_tickets()
    if local_player.TimescaleTickets.Value >= 1 then
        if game.Players.LocalPlayer.PlayerGui.ReactUniversalHotbar.Frame.timescale.Lock.Visible then
            _G.Log("Unlocking Timescale with ticket", Color3.fromRGB(255, 255, 255))
            replicated_storage.RemoteFunction:InvokeServer('TicketsManager', 'UnlockTimeScale')
        end
    else
        _G.Log("Failed to unlock: No tickets left", Color3.fromRGB(255, 80, 80))
        warn("no tickets left")
    end
end

local function trigger_restart()
    _G.Log("Game Over detected, waiting for Rewards Screen", Color3.fromRGB(255, 255, 255))
    local ui_root = player_gui:WaitForChild("ReactGameNewRewards")
    local found_section = false

    repeat
        task.wait(0.3)
        local f = ui_root:FindFirstChild("Frame")
        local g = f and f:FindFirstChild("gameOver")
        local s = g and g:FindFirstChild("RewardsScreen")
        if s and s:FindFirstChild("RewardsSection") then
            found_section = true
        end
    until found_section

    _G.Log("Rewards loaded, restarting in 3 seconds", Color3.fromRGB(160, 220, 100))
    task.wait(3)
    run_vote_skip()
end

local function get_current_wave()
    local label = player_gui:WaitForChild("ReactGameTopGameDisplay").Frame.wave.container.value
    local wave_num = label.Text:match("^(%d+)")
    local final_wave = tonumber(wave_num) or 0
    return final_wave
end

local function do_place_tower(t_name, t_pos)
    while true do
        local ok, res = pcall(function()
            return remote_func:InvokeServer("Troops", "Pl\208\176ce", {
                Rotation = CFrame.new(),
                Position = t_pos
            }, t_name)
        end)

        if ok and check_res_ok(res) then 
            _G.Log("Placed: " .. t_name, Color3.fromRGB(160, 220, 100))
            return true 
        end
        task.wait(0.25)
    end
end

local function do_upgrade_tower(t_obj, path_id)
    while true do
        local ok, res = pcall(function()
            return remote_func:InvokeServer("Troops", "Upgrade", "Set", {
                Troop = t_obj,
                Path = path_id
            })
        end)
        if ok and check_res_ok(res) then 
            _G.Log("Upgraded " .. t_obj.Name, Color3.fromRGB(160, 220, 100))
            return true 
        end
        
        task.wait(0.25)
    end
end

local function do_sell_tower(t_obj)
    local tower_name = (t_obj and t_obj:FindFirstChild("HumanoidRootPart")) and t_obj.Name or "Tower"
    
    while true do
        local ok, res = pcall(function()
            return remote_func:InvokeServer("Troops", "Sell", { Troop = t_obj })
        end)
        
        if ok and check_res_ok(res) then 
            _G.Log("Sold Tower: " .. tower_name, Color3.fromRGB(255, 100, 100))
            return true 
        end
        
        task.wait(0.25)
    end
end

local function do_set_option(t_obj, opt_name, opt_val, req_wave)
    if req_wave then
        repeat task.wait(0.3) until get_current_wave() >= req_wave
    end

    while true do
        local ok, res = pcall(function()
            return remote_func:InvokeServer("Troops", "Option", "Set", {
                Troop = t_obj,
                Name = opt_name,
                Value = opt_val
            })
        end)
        
        if ok and check_res_ok(res) then 
            _G.Log("Setting " .. opt_name .. " to " .. tostring(opt_val), Color3.fromRGB(100, 200, 255))
            return true 
        end
        
        task.wait(0.25)
    end
end

local function do_activate_ability(t_obj, ab_name, ab_data, is_looping)
    if type(ab_data) == "boolean" then
        is_looping = ab_data
        ab_data = nil
    end

    ab_data = type(ab_data) == "table" and ab_data or nil

    local positions
    if ab_data and type(ab_data.towerPosition) == "table" then
        positions = ab_data.towerPosition
    end

    local clone_idx = ab_data and ab_data.towerToClone
    local target_idx = ab_data and ab_data.towerTarget

    local function attempt()
        while true do
            local ok, res = pcall(function()
                local data

                if ab_data then
                    data = table.clone(ab_data)

                    -- 🎯 RANDOMIZE HERE (every attempt)
                    if positions and #positions > 0 then
                        data.towerPosition = positions[math.random(#positions)]
                    end

                    if type(clone_idx) == "number" then
                        data.towerToClone = TDS.placed_towers[clone_idx]
                    end

                    if type(target_idx) == "number" then
                        data.towerTarget = TDS.placed_towers[target_idx]
                    end
                end

                return remote_func:InvokeServer(
                    "Troops",
                    "Abilities",
                    "Activate",
                    {
                        Troop = t_obj,
                        Name = ab_name,
                        Data = data
                    }
                )
            end)

            if ok and check_res_ok(res) then
                return true
            end

            task.wait(0.25)
        end
    end

    if is_looping then
        local active = true
        task.spawn(function()
            while active do
                attempt()
                task.wait(1)
            end
        end)
        return function() active = false end
    end

    return attempt()
end

-- // public api
-- lobby
function TDS:Mode(difficulty)
    if game_state ~= "LOBBY" then 
        return false 
    end

    local lobby_hud = player_gui:WaitForChild("ReactLobbyHud", 30)
    local frame = lobby_hud and lobby_hud:WaitForChild("Frame", 30)
    local match_making = frame and frame:WaitForChild("matchmaking", 30)

    if match_making then
        local remote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunction")
        local success = false
        local res
        _G.Log("Selecting Mode: " .. tostring(difficulty), Color3.fromRGB(100, 200, 255))
        repeat
            local ok, result = pcall(function()
                if difficulty == "Hardcore" then
                    return remote:InvokeServer("Multiplayer", "v2:start", {
                        mode = "hardcore",
                        count = 1
                    })
                elseif difficulty == "Pizza Party" then
                    return remote:InvokeServer("Multiplayer", "v2:start", {
                        mode = "halloween",
                        count = 1
                    })
                elseif difficulty == "Polluted" then
                    return remote:InvokeServer("Multiplayer", "v2:start", {
                        mode = "polluted",
                        count = 1
                    })
                else
                    return remote:InvokeServer("Multiplayer", "v2:start", {
                        difficulty = difficulty,
                        mode = "survival",
                        count = 1
                    })
                end
            end)

            if ok and check_res_ok(result) then
                _G.Log("Successfully joined matchmaking: " .. tostring(difficulty), Color3.fromRGB(160, 220, 100))
                success = true
                res = result
            else
                task.wait(0.5) 
            end
        until success
    end

    return true
end

function TDS:Loadout(...)
    local towers = {...}
    Config.CurrentLoadout = towers
    UpdateUI(towers)
    
    if game_state ~= "LOBBY" then return false end

    local remote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunction")

    for _, tower_name in ipairs(towers) do
        if tower_name and tower_name ~= "" then
            local success = false
            repeat
                local ok = pcall(function()
                    remote:InvokeServer("Inventory", "Equip", "tower", tower_name)
                end)
                if ok then
                    success = true
                else
                    task.wait(0.2)
                end
            until success
            task.wait(0.4)
        end
    end
    return true
end

function TDS:Addons()
    if game_state ~= "GAME" then
        return false
    end
    local url = "https://api.junkie-development.de/api/v1/luascripts/public/57fe397f76043ce06afad24f07528c9f93e97730930242f57134d0b60a2d250b/download"
    local success, code = pcall(game.HttpGet, game, url)

    if not success then
        return false
    end

    loadstring(code)()

    while not TDS.Equip do
        task.wait(0.1)
    end

    return true
end

-- ingame
function TDS:TeleportToLobby()
    send_to_lobby()
end

function TDS:VoteSkip(req_wave)
    if req_wave then
        repeat task.wait(0.5) until get_current_wave() >= req_wave
    end
    run_vote_skip()
end

function TDS:GameInfo(name, list)
    list = list or {}
    if game_state ~= "GAME" then return false end

    local vote_gui = player_gui:WaitForChild("ReactGameIntermission", 30)

    if vote_gui and vote_gui.Enabled and vote_gui:WaitForChild("Frame", 5) then
        cast_modifier_vote(list)
        select_map_override(name)
    end
end

function TDS:UnlockTimeScale()
    unlock_speed_tickets()
end

function TDS:TimeScale(val)
    set_game_timescale(val)
end

function TDS:StartGame()
    lobby_ready_up()
end

function TDS:Ready()
    if game_state ~= "GAME" then
        return false 
    end
    match_ready_up()
end

function TDS:GetWave()
    return get_current_wave()
end

function TDS:RestartGame()
    trigger_restart()
end

function TDS:Place(t_name, px, py, pz)
    if game_state ~= "GAME" then
        return false 
    end
    
    local existing = {}
    for _, child in ipairs(workspace.Towers:GetChildren()) do
        for _, sub_child in ipairs(child:GetChildren()) do
            if sub_child.Name == "Owner" and sub_child.Value == local_player.UserId then
                existing[child] = true
                break
            end
        end
    end

    do_place_tower(t_name, Vector3.new(px, py, pz))
    

    local new_t
    repeat
        for _, child in ipairs(workspace.Towers:GetChildren()) do
            if not existing[child] then
                for _, sub_child in ipairs(child:GetChildren()) do
                    if sub_child.Name == "Owner" and sub_child.Value == local_player.UserId then
                        new_t = child
                        break
                    end
                end
            end
            if new_t then break end
        end
        task.wait(0.05)
    until new_t

    table.insert(self.placed_towers, new_t)
    return #self.placed_towers
end

function TDS:Upgrade(idx, p_id)
    local t = self.placed_towers[idx]
    if t then
        do_upgrade_tower(t, p_id or 1)
        upgrade_history[idx] = (upgrade_history[idx] or 0) + 1
    end
end

function TDS:SetTarget(idx, target_type, req_wave)
    if req_wave then
        repeat task.wait(0.5) until get_current_wave() >= req_wave
    end

    local t = self.placed_towers[idx]
    if not t then return end

    pcall(function()
        remote_func:InvokeServer("Troops", "Target", "Set", {
            Troop = t,
            Target = target_type
        })
    end)
end

function TDS:Sell(idx, req_wave)
    if req_wave then
        repeat task.wait(0.5) until get_current_wave() >= req_wave
    end
    local t = self.placed_towers[idx]
    if t and do_sell_tower(t) then
        table.remove(self.placed_towers, idx)
        return true
    end
    return false
end

function TDS:SellAll(req_wave)
    if req_wave then
        repeat task.wait(0.5) until get_current_wave() >= req_wave
    end

    local towers_copy = {unpack(self.placed_towers)}
    for idx, t in ipairs(towers_copy) do
        if do_sell_tower(t) then
            for i, orig_t in ipairs(self.placed_towers) do
                if orig_t == t then
                    table.remove(self.placed_towers, i)
                    break
                end
            end
        end
    end

    return true
end

function TDS:Ability(idx, name, data, loop)
    local t = self.placed_towers[idx]
    if not t then return false end
    return do_activate_ability(t, name, data, loop)
end

function TDS:AutoChain(...)
    local tower_indices = {...}
    if #tower_indices == 0 then return end

    local running = true

    task.spawn(function()
        local i = 1
        while running do
            local idx = tower_indices[i]
            local tower = TDS.placed_towers[idx]

            if tower then
                do_activate_ability(tower, "Call Of Arms")
            end

            local hotbar = player_gui.ReactUniversalHotbar.Frame
            local timescale = hotbar:FindFirstChild("timescale")

            if timescale then
                if timescale:FindFirstChild("Lock") then
                    task.wait(10.5)
                else
                    task.wait(5.5)
                end
            else
                task.wait(10.5)
            end

            i += 1
            if i > #tower_indices then
                i = 1
            end
        end
    end)

    return function()
        running = false
    end
end

function TDS:SetOption(idx, name, val, req_wave)
    local t = self.placed_towers[idx]
    if t then
        return do_set_option(t, name, val, req_wave)
    end
    return false
end

-- // misc utility
local function is_void_charm(obj)
    return math.abs(obj.Position.Y) > 999999
end

local function get_root()
    local char = local_player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function start_auto_pickups()
    if auto_pickups_running or not Config.AutoPickups then return end
    auto_pickups_running = true

    task.spawn(function()
        while Config.AutoPickups do
            local folder = workspace:FindFirstChild("Pickups")
            local hrp = get_root()

            if folder and hrp then
                for _, item in ipairs(folder:GetChildren()) do
                    if not Config.AutoPickups then break end

                    if item:IsA("MeshPart") and (item.Name == "SnowCharm" or item.Name == "Lorebook") then
                        if not is_void_charm(item) then
                            local old_pos = hrp.CFrame
                            hrp.CFrame = item.CFrame * CFrame.new(0, 3, 0)
                            task.wait(0.2)
                            hrp.CFrame = old_pos
                            task.wait(0.3)
                        end
                    end
                end
            end

            task.wait(1)
        end

        auto_pickups_running = false
    end)
end

local function start_auto_skip()
    if auto_skip_running or not Config.AutoSkip then return end
    auto_skip_running = true

    task.spawn(function()
        while Config.AutoSkip do
            local skip_visible =
                player_gui:FindFirstChild("ReactOverridesVote")
                and player_gui.ReactOverridesVote:FindFirstChild("Frame")
                and player_gui.ReactOverridesVote.Frame:FindFirstChild("votes")
                and player_gui.ReactOverridesVote.Frame.votes:FindFirstChild("vote")

            if skip_visible and skip_visible.Position == UDim2.new(0.5, 0, 0.5, 0) then
                run_vote_skip()
            end

            task.wait(1)
        end

        auto_skip_running = false
    end)
end

local function start_back_to_lobby()
    if back_to_lobby_running then return end
    back_to_lobby_running = true

    task.spawn(function()
        while true do
            pcall(function()
                handle_post_match()
            end)
            task.wait(5)
        end
        back_to_lobby_running = false
    end)
end

local function start_anti_lag()
    if anti_lag_running then return end
    anti_lag_running = true

    task.spawn(function()
        while Config.AntiLag do
            local towers_folder = workspace:FindFirstChild("Towers")
            local client_units = workspace:FindFirstChild("ClientUnits")
            local enemies = workspace:FindFirstChild("NPCs")

            if towers_folder then
                for _, tower in ipairs(towers_folder:GetChildren()) do
                    local anims = tower:FindFirstChild("Animations")
                    local weapon = tower:FindFirstChild("Weapon")
                    local projectiles = tower:FindFirstChild("Projectiles")
                    
                    if anims then anims:Destroy() end
                    if projectiles then projectiles:Destroy() end
                    if weapon then weapon:Destroy() end
                end
            end
            if client_units then
                for _, unit in ipairs(client_units:GetChildren()) do
                    unit:Destroy()
                end
            end
            if enemies then
                for _, npc in ipairs(enemies:GetChildren()) do
                    npc:Destroy()
                end
            end
            task.wait(0.5)
        end
        anti_lag_running = false
    end)
end

local function start_anti_afk()
    local Players = game:GetService("Players")
    local GC = getconnections and getconnections or get_signal_cons

    if GC then
        for i, v in pairs(GC(Players.LocalPlayer.Idled)) do
            if v.Disable then
                v:Disable()
            elseif v.Disconnect then
                v:Disconnect()
            end
        end
    else
        Players.LocalPlayer.Idled:Connect(function()
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end

    local ANTIAFK = Players.LocalPlayer.Idled:Connect(function()
        local VirtualUser = game:GetService("VirtualUser")
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end

local function start_rejoin_on_disconnect()
    task.spawn(function()
        game.Players.PlayerRemoving:connect(function (plr)
            if plr == game.Players.LocalPlayer then
                game:GetService('TeleportService'):Teleport(3260590327, plr)
            end
        end)
    end)
end

start_back_to_lobby()
start_auto_skip()
start_auto_pickups()
start_anti_lag()
start_anti_afk()
start_rejoin_on_disconnect()


-- // Execute Configuration
if Config.Loadout then
    TDS:Loadout(unpack(Config.Loadout))
end

if Config.Mode then
    TDS:Mode(Config.Mode)
end

if Config.GameInfo then
    TDS:GameInfo(unpack(Config.GameInfo))
end

if Config.TimeScale then
    TDS:UnlockTimeScale()
    TDS:TimeScale(Config.TimeScale)
end

-- // Load Macro
if Config.macroURL then
    task.spawn(function()
        local success, macro_code = pcall(game.HttpGet, game, Config.macroURL)
        if success then
            -- Expose TDS to the macro environment
            getgenv().TDS = TDS 
            local func, err = loadstring(macro_code)
            if func then
                func()
            else
                warn("Failed to compile macro: " .. tostring(err))
            end
        else
            warn("Failed to load macro from URL: " .. tostring(Config.macroURL))
        end
    end)
end

return TDS

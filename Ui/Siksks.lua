if not game:IsLoaded() then game.Loaded:Wait() end

-- // services & main refs
local user_input_service = game:GetService("UserInputService")
local virtual_user = game:GetService("VirtualUser")
local run_service = game:GetService("RunService")
local teleport_service = game:GetService("TeleportService")
local marketplace_service = game:GetService("MarketplaceService")
local replicated_storage = game:GetService("ReplicatedStorage")
local http_service = game:GetService("HttpService")
local remote_func = replicated_storage:WaitForChild("RemoteFunction")
local remote_event = replicated_storage:WaitForChild("RemoteEvent")
local players_service = game:GetService("Players")
local local_player = players_service.LocalPlayer or players_service.PlayerAdded:Wait()
local mouse = local_player:GetMouse()
local player_gui = local_player:WaitForChild("PlayerGui")
local file_name = "ADS_Config.json"

task.spawn(function()
    local function disable_idled()
        if type(getconnections) ~= "function" then
            return
        end
        local success, connections = pcall(getconnections, local_player.Idled)
        if success and type(connections) == "table" then
            for _, v in pairs(connections) do
                if v and v.Disable then
                    v:Disable()
                end
            end
        end
    end
        
    disable_idled()
end)

task.spawn(function()
    local_player.Idled:Connect(function()
        virtual_user:CaptureController()
        virtual_user:ClickButton2(Vector2.new(0, 0))
    end)
end)

task.spawn(function()
    local core_gui = game:GetService("CoreGui")
    local overlay = core_gui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")

    overlay.ChildAdded:Connect(function(child)
        if child.Name == 'ErrorPrompt' then
            while true do
                teleport_service:Teleport(3260590327)
                task.wait(5)
            end
        end
    end)
end)

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

local function start_anti_afk()
    task.spawn(function()
        local lobby_timer = 0
        while game_state == "LOBBY" do 
            task.wait(1)
            lobby_timer = lobby_timer + 1
            if lobby_timer >= 600 then
                teleport_service:Teleport(3260590327)
                break 
            end
        end
    end)
end

start_anti_afk()

local send_request = request or http_request or httprequest
    or GetDevice and GetDevice().request

if not send_request then 
    warn("failure: no http function") 
    return 
end

local back_to_lobby_running = false
local auto_pickups_running = false
local auto_skip_running = false
local auto_claim_rewards = false
local anti_lag_running = false
local auto_chain_running = false
local auto_dj_running = false
local auto_mercenary_base_running = false
local auto_military_base_running = false
local sell_farms_running = false

local max_path_distance = 300 -- default
local mil_marker = nil
local merc_marker = nil

_G.record_strat = false
local spawned_towers = {}
local current_equipped_towers = {"None"}
local tower_count = 0

local stack_enabled = false
local selected_tower = nil
local stack_sphere = nil

local All_Modifiers = {
    "HiddenEnemies", "Glass", "ExplodingEnemies", "Limitation", 
    "Committed", "HealthyEnemies", "Fog", "FlyingEnemies", 
    "Broke", "SpeedyEnemies", "Quarantine", "JailedTowers", "Inflation"
}

local default_settings = {
    PathVisuals = false,
    MilitaryPath = false,
    MercenaryPath = false,
    AutoSkip = false,
    AutoChain = false,
    AutoDJ = false,
    AutoRejoin = true,
    SellFarms = false,
    AutoMercenary = false,
    AutoMilitary = false,
    Frost = false,
    Fallen = false,
    Easy = false,
    AntiLag = false,
    Disable3DRendering = false,
    AutoPickups = false,
    ClaimRewards = false,
    SendWebhook = false,
    NoRecoil = false,
    SellFarmsWave = 1,
    WebhookURL = "",
    MacroURL = "",
    Loadout = {},
    Map = "Grass Isle",
    Gamemode = "Molten",
    Cooldown = 0.01,
    Multiply = 60,
    Modifiers = {}
}

if type(getgenv().PickHubLOL) == "table" then
    for k, v in pairs(getgenv().PickHubLOL) do
        if default_settings[k] ~= nil then
            default_settings[k] = v
        end
    end
end

local last_state = {}

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
TDS = {
    placed_towers = {},
    active_strat = true,
    matchmaking_map = {
        ["Hardcore"] = "hardcore",
        ["Pizza Party"] = "halloween",
        ["Badlands"] = "badlands",
        ["Polluted"] = "polluted"
    }
}

local upgrade_history = {}

-- // shared for addons
shared.TDS_Table = TDS

-- // load & save
local function save_settings()
    local data_to_save = {}
    for key, _ in pairs(default_settings) do
        data_to_save[key] = _G[key]
    end
    writefile(file_name, http_service:JSONEncode(data_to_save))
end

local function load_settings()
    if isfile(file_name) then
        local success, data = pcall(function()
            return http_service:JSONDecode(readfile(file_name))
        end)
        
        if success and type(data) == "table" then
            for key, default_val in pairs(default_settings) do
                if data[key] ~= nil then
                    _G[key] = data[key]
                else
                    _G[key] = default_val
                end
            end
            return
        end
    end
    
    for key, value in pairs(default_settings) do
        _G[key] = value
    end
    save_settings()
end

local function set_setting(name, value)
    if default_settings[name] ~= nil then
        _G[name] = value
        save_settings()
    end
end

getgenv().TDS = TDS
getgenv().set_setting = set_setting

local function apply_3d_rendering()
    if _G.Disable3DRendering then
        game:GetService("RunService"):Set3dRenderingEnabled(false)
    else
        run_service:Set3dRenderingEnabled(true)
    end
end

load_settings()

-- // Force override settings from getgenv().PickHubLOL (Session Config)
if type(getgenv().PickHubLOL) == "table" then
    for k, v in pairs(getgenv().PickHubLOL) do
        if default_settings[k] ~= nil then
            _G[k] = v
        end
    end
end

apply_3d_rendering()

-- // for calculating path
local function find_path()
    local map_folder = workspace:FindFirstChild("Map")
    if not map_folder then return nil end
    local paths_folder = map_folder:FindFirstChild("Paths")
    if not paths_folder then return nil end
    local path_folder = paths_folder:GetChildren()[1]
    if not path_folder then return nil end
    
    local path_nodes = {}
    for _, node in ipairs(path_folder:GetChildren()) do
        if node:IsA("BasePart") then
            table.insert(path_nodes, node)
        end
    end
    
    table.sort(path_nodes, function(a, b)
        local num_a = tonumber(a.Name:match("%d+"))
        local num_b = tonumber(b.Name:match("%d+"))
        if num_a and num_b then return num_a < num_b end
        return a.Name < b.Name
    end)
    
    return path_nodes
end

local function total_length(path_nodes)
    local total_length = 0
    for i = 1, #path_nodes - 1 do
        total_length = total_length + (path_nodes[i + 1].Position - path_nodes[i].Position).Magnitude
    end
    return total_length
end

local MercenarySlider
local MilitarySlider

local function calc_length()
    local map = workspace:FindFirstChild("Map")
    
    if game_state == "GAME" and map then
        local path_nodes = find_path()
        
        if path_nodes and #path_nodes > 0 then
            max_path_distance = total_length(path_nodes)
            
            if MercenarySlider then
                MercenarySlider:SetMax(max_path_distance) 
            end
            
            if MilitarySlider then
                MilitarySlider:SetMax(max_path_distance)
            end
            return true
        end
    end
    return false
end

local function get_point_at_distance(path_nodes, distance)
    if not path_nodes or #path_nodes < 2 then return nil end
    
    local current_dist = 0
    for i = 1, #path_nodes - 1 do
        local start_pos = path_nodes[i].Position
        local end_pos = path_nodes[i+1].Position
        local segment_len = (end_pos - start_pos).Magnitude
        
        if current_dist + segment_len >= distance then
            local remaining = distance - current_dist
            local direction = (end_pos - start_pos).Unit
            return start_pos + (direction * remaining)
        end
        current_dist = current_dist + segment_len
    end
    return path_nodes[#path_nodes].Position
end

local function update_path_visuals()
    if not _G.PathVisuals then
        if mil_marker then 
            mil_marker:Destroy() 
            mil_marker = nil 
        end
        if merc_marker then 
            merc_marker:Destroy() 
            merc_marker = nil 
        end
        return
    end

    local path_nodes = find_path()
    if not path_nodes then return end

    if not mil_marker then
        mil_marker = Instance.new("Part")
        mil_marker.Name = "MilVisual"
        mil_marker.Shape = Enum.PartType.Cylinder
        mil_marker.Size = Vector3.new(0.3, 3, 3)
        mil_marker.Color = Color3.fromRGB(0, 255, 0)
        mil_marker.Material = Enum.Material.Plastic
        mil_marker.Anchored = true
        mil_marker.CanCollide = false
        mil_marker.Orientation = Vector3.new(0, 0, 90)
        mil_marker.Parent = workspace
    end

    if not merc_marker then
        merc_marker = mil_marker:Clone()
        merc_marker.Name = "MercVisual"
        merc_marker.Color = Color3.fromRGB(255, 0, 0)
        merc_marker.Parent = workspace
    end

    local mil_pos = get_point_at_distance(path_nodes, _G.MilitaryPath or 0)
    local merc_pos = get_point_at_distance(path_nodes, _G.MercenaryPath or 0)

    if mil_pos then
        mil_marker.Position = mil_pos + Vector3.new(0, 0.2, 0)
        mil_marker.Transparency = 0.7
    end
    if merc_pos then
        merc_marker.Position = merc_pos + Vector3.new(0, 0.2, 0)
        merc_marker.Transparency = 0.7
    end
end

local function record_action(command_str)
    if not _G.record_strat then return end
    if appendfile then
        appendfile("Strat.txt", command_str .. "\n")
    end
end

function TDS:Addons()
    local url = "https://api.jnkie.com/api/v1/luascripts/public/57fe397f76043ce06afad24f07528c9f93e97730930242f57134d0b60a2d250b/download"
    local success, code = pcall(game.HttpGet, game, url)

    if not success then
        return false
    end

    loadstring(code)()

    while not (TDS.MultiMode and TDS.Multiplayer) do
        task.wait(0.1)
    end

    local original_equip = TDS.Equip
    TDS.Equip = function(...)
        if game_state == "GAME" then
            return original_equip(...)
        end
    end

    return true
end

local function normalize_macro_url(url)
    if type(url) ~= "string" then
        return ""
    end

    local cleaned = url:gsub("^%s+", ""):gsub("%s+$", "")
    cleaned = cleaned:gsub("^['\"`]+", ""):gsub("['\"`]+$", "")
    cleaned = cleaned:gsub("%s", "")
    return cleaned
end

getgenv().macro = function(url)
    local cleaned_url = normalize_macro_url(url)
    if cleaned_url == "" then
        warn("Failed to fetch macro from URL:", "empty or invalid MacroURL")
        return
    end

    local success, response = pcall(function()
        return game:HttpGet(cleaned_url)
    end)

    if success then
        local macro_code = response
        local success_call, result = pcall(loadstring(macro_code))
        if not success_call then
            warn("Macro execution failed:", result)
        end
    else
        warn("Failed to fetch macro from URL:", response)
    end
end

-- Auto-execute MacroURL if set
if _G.MacroURL and _G.MacroURL ~= "" then
    task.spawn(function()
        task.wait(1) -- Short delay to ensure initialization
        local cleaned_url = normalize_macro_url(_G.MacroURL)
        if cleaned_url ~= "" then
            _G.MacroURL = cleaned_url
            getgenv().macro(cleaned_url)
        end
    end)
end

local function get_equipped_towers()
    local towers = {}
    local state_replicators = replicated_storage:FindFirstChild("StateReplicators")

    if state_replicators then
        for _, folder in ipairs(state_replicators:GetChildren()) do
            if folder.Name == "PlayerReplicator" and folder:GetAttribute("UserId") == local_player.UserId then
                local equipped = folder:GetAttribute("EquippedTowers")
                if type(equipped) == "string" then
                    local cleaned_json = equipped:match("%[.*%]") 
                    local success, tower_table = pcall(function()
                        return http_service:JSONDecode(cleaned_json)
                    end)

                    if success and type(tower_table) == "table" then
                        for i = 1, 5 do
                            if tower_table[i] then
                                table.insert(towers, tower_table[i])
                            end
                        end
                    end
                end
            end
        end
    end
    return #towers > 0 and towers or {"None"}
end
    Create("UICorner", {Parent = ToggleBtn, CornerRadius = UDim.new(1, 0)}) -- Circle
    local ToggleStroke = Create("UIStroke", {Parent = ToggleBtn, Color = self.Theme.Outline, Thickness = 1.5, Transparency = 0.5})
    
    local ToggleIcon = Create("ImageLabel", {
        Parent = ToggleBtn,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(0.5, -12, 0.5, -12),
        Image = "rbxassetid://6034509993", -- Logo
        ImageColor3 = self.Theme.Accent,
        ZIndex = 10002
    })
    Library:Register(ToggleIcon, "ImageColor3", "Accent")

    ToggleBtn.MouseButton1Click:Connect(function()
        Library.Open = not Library.Open
        MainFrame.Visible = Library.Open
        -- Simple bounce effect
        TweenService:Create(ToggleBtn, TweenInfo.new(0.1), {Size = UDim2.new(0, 45, 0, 45)}):Play()
        task.wait(0.1)
        TweenService:Create(ToggleBtn, TweenInfo.new(0.1), {Size = UDim2.new(0, 50, 0, 50)}):Play()
    end)

    -- // SIDEBAR // --
    local Sidebar = Create("Frame", {
        Parent = MainFrame,
        BackgroundColor3 = self.Theme.Sidebar,
        BackgroundTransparency = 0.05, -- Glass effect
        Size = UDim2.new(0, 125, 1, 0), -- Slightly Wider for Text
        ZIndex = 2
    })
    Library:Register(Sidebar, "BackgroundColor3", "Sidebar")
    Create("UICorner", {Parent = Sidebar, CornerRadius = UDim.new(0, 12)})
    
    -- Sidebar Gradient
    local SideGradient = Create("UIGradient", {
        Parent = Sidebar,
        Rotation = 45,
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
            ColorSequenceKeypoint.new(1, Color3.new(0.9,0.9,0.9))
        },
        Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 0.1)
        }
    })

    -- Title Area
    local TitleArea = Create("Frame", {
        Parent = Sidebar,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 45) -- Reduced Height
    })
    local AppIcon = Create("ImageLabel", {
        Parent = TitleArea,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 10),
        Size = UDim2.new(0, 20, 0, 20), -- Smaller Icon
        Image = "rbxassetid://6034509993",
        ImageColor3 = self.Theme.Accent
    })
    Library:Register(AppIcon, "ImageColor3", "Accent")
    
    local AppTitle = Create("TextLabel", {
        Parent = TitleArea,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 38, 0, 0),
        Size = UDim2.new(1, -38, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = "Autostrat",
        TextColor3 = self.Theme.Text,
        TextSize = 13, -- Smaller Text
        TextXAlignment = Enum.TextXAlignment.Left
    })
    Library:Register(AppTitle, "TextColor3", "Text")

    -- Tab Container
    local TabContainer = Create("ScrollingFrame", {
        Parent = Sidebar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 45),
        Size = UDim2.new(1, 0, 1, -95), -- Adjusted for new height
        CanvasSize = UDim2.new(0,0,0,0),
        ScrollBarThickness = 2
    })
    Create("UIListLayout", {Parent = TabContainer, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)})
    Create("UIPadding", {Parent = TabContainer, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)})

    -- User Profile (Bottom)
    local ProfileArea = Create("Frame", {
        Parent = Sidebar,
        BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 0.8,
        Position = UDim2.new(0, 5, 1, -45),
        Size = UDim2.new(1, -10, 0, 40) -- Compact Profile
    })
    Create("UICorner", {Parent = ProfileArea, CornerRadius = UDim.new(0, 8)})
    
    local Avatar = Create("ImageLabel", {
        Parent = ProfileArea,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 4, 0, 4),
        Size = UDim2.new(0, 32, 0, 32), -- Smaller Avatar
        Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    })
    Create("UICorner", {Parent = Avatar, CornerRadius = UDim.new(1, 0)})
    
    local Username = Create("TextLabel", {
        Parent = ProfileArea,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 40, 0, 4),
        Size = UDim2.new(1, -45, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = LocalPlayer.Name,
        TextColor3 = self.Theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClipsDescendants = true
    })
    Library:Register(Username, "TextColor3", "Text")
    
    local UserRank = Create("TextLabel", {
        Parent = ProfileArea,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 40, 0, 20),
        Size = UDim2.new(1, -45, 0, 12),
        Font = Enum.Font.Gotham,
        Text = "Premium",
        TextColor3 = self.Theme.Accent,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    Library:Register(UserRank, "TextColor3", "Accent")
    
    -- Rank Gradient
    local RankGradient = Create("UIGradient", {
        Parent = UserRank,
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.new(0.7,0.7,0.7)),
            ColorSequenceKeypoint.new(0.5, Color3.new(1,1,1)), -- Shine
            ColorSequenceKeypoint.new(1, Color3.new(0.7,0.7,0.7))
        },
        Rotation = 45
    })
    
    task.spawn(function()
        while UserRank.Parent do
            TweenService:Create(RankGradient, TweenInfo.new(2, Enum.EasingStyle.Linear), {Rotation = RankGradient.Rotation + 360}):Play()
            task.wait(2)
        end
    end)

    -- Content Container
    local ContentContainer = Create("Frame", {
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 125, 0, 0), -- Adjusted for Sidebar
        Size = UDim2.new(1, -125, 1, 0),
        ClipsDescendants = true
    })

    self.TabContainer = TabContainer
    self.ContentContainer = ContentContainer
    self.Tabs = {}

    -- Loading Logic (Moved)
    task.spawn(function()
        -- 1. Blur In
        TweenService:Create(WorldBlur, TweenInfo.new(2), {Size = 24}):Play()
        
        -- 2. Fade Elements In
        task.wait(0.5)
        TweenService:Create(MainLogo, TweenInfo.new(1.5), {ImageTransparency = 0}):Play()
        TweenService:Create(Ring, TweenInfo.new(1.5), {ImageTransparency = 0.8}):Play()
        TweenService:Create(Title, TweenInfo.new(1.5), {TextTransparency = 0}):Play()
        
        -- 3. Animation Loop (Pulse)
        local spin = TweenService:Create(Ring, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360})
        spin:Play()
        
        local pulse = TweenService:Create(MainLogo, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.new(0.9, 0, 0.9, 0)})
        pulse:Play()
        
        task.wait(3.5) -- Fake loading time
        
        -- 4. Exit
        spin:Cancel()
        pulse:Cancel()
        
        TweenService:Create(LoadingScreen, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()
        TweenService:Create(MainLogo, TweenInfo.new(0.5), {ImageTransparency = 1, Size = UDim2.new(2, 0, 2, 0)}):Play()
        TweenService:Create(Ring, TweenInfo.new(0.5), {ImageTransparency = 1, Size = UDim2.new(0, 0, 0, 0)}):Play()
        TweenService:Create(Title, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
        TweenService:Create(WorldBlur, TweenInfo.new(1.5), {Size = 0}):Play()
        
        task.wait(1.5)
        LoadingScreen.Visible = false
        WorldBlur:Destroy()
        
        -- Show Menu
        MainFrame.Visible = true
    end)

    return self
end

function Library:CreateTab(name, iconId)
    local TabButton = Create("TextButton", {
        Parent = self.TabContainer,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 32), -- Compact Height
        Text = "",
        AutoButtonColor = false
    })
    Create("UICorner", {Parent = TabButton, CornerRadius = UDim.new(0, 6)})

    local Icon = Create("ImageLabel", {
        Parent = TabButton,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0.5, -8),
        Size = UDim2.new(0, 16, 0, 16), -- Smaller Icon
        Image = iconId,
        ImageColor3 = self.Theme.TextDim
    })
    Library:Register(Icon, "ImageColor3", "TextDim")
    
    local Title = Create("TextLabel", {
        Parent = TabButton,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 32, 0, 0),
        Size = UDim2.new(1, -32, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = name,
        TextColor3 = self.Theme.TextDim,
        TextSize = 11, -- Smaller Text
        TextXAlignment = Enum.TextXAlignment.Left
    })
    Library:Register(Title, "TextColor3", "TextDim")

    -- Active Indicator (Glow)
    local Indicator = Create("Frame", {
        Parent = TabButton,
        BackgroundColor3 = self.Theme.Accent,
        Position = UDim2.new(0, 0, 0.5, -6),
        Size = UDim2.new(0, 2, 0, 12),
        Transparency = 1
    })
    Library:Register(Indicator, "BackgroundColor3", "Accent")
    Create("UICorner", {Parent = Indicator, CornerRadius = UDim.new(0, 2)})

    local Page = Create("ScrollingFrame", {
        Parent = self.ContentContainer,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0,0,0,0),
        ScrollBarThickness = 3,
        Visible = false
    })
    Create("UIListLayout", {Parent = Page, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)})
    Create("UIPadding", {Parent = Page, PaddingTop = UDim.new(0, 25), PaddingLeft = UDim.new(0, 25), PaddingRight = UDim.new(0, 25), PaddingBottom = UDim.new(0, 25)})

    -- Interaction
    TabButton.MouseEnter:Connect(function()
        if Page.Visible then return end
        TweenService:Create(TabButton, TweenInfo.new(0.3), {BackgroundTransparency = 0.95, BackgroundColor3 = Library.Theme.Text}):Play()
    end)
    TabButton.MouseLeave:Connect(function()
        if Page.Visible then return end
        TweenService:Create(TabButton, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    end)
    
    TabButton.MouseButton1Click:Connect(function()
        Library:Ripple(TabButton)
        for _, t in pairs(self.Tabs) do
            t.Page.Visible = false
            TweenService:Create(t.Title, TweenInfo.new(0.2), {TextColor3 = self.Theme.TextDim}):Play()
            TweenService:Create(t.Icon, TweenInfo.new(0.2), {ImageColor3 = self.Theme.TextDim}):Play()
            TweenService:Create(t.Button, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
            TweenService:Create(t.Indicator, TweenInfo.new(0.2), {Transparency = 1}):Play()
        end
        Page.Visible = true
        TweenService:Create(Title, TweenInfo.new(0.2), {TextColor3 = self.Theme.Text}):Play()
        TweenService:Create(Icon, TweenInfo.new(0.2), {ImageColor3 = self.Theme.Accent}):Play()
        TweenService:Create(TabButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.9, BackgroundColor3 = self.Theme.Accent}):Play()
        TweenService:Create(Indicator, TweenInfo.new(0.2), {Transparency = 0}):Play()
    end)

    if #self.Tabs == 0 then
        Page.Visible = true
        Title.TextColor3 = self.Theme.Text
        Icon.ImageColor3 = self.Theme.Accent
        TabButton.BackgroundTransparency = 0.9
        TabButton.BackgroundColor3 = self.Theme.Accent
        Indicator.Transparency = 0
    end

    table.insert(self.Tabs, {Button = TabButton, Page = Page, Title = Title, Icon = Icon, Indicator = Indicator})

    local Tab = {}
    
    function Tab:CreateSection(text)
        local Section = Create("TextLabel", {
            Parent = Page,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 30),
            Font = Enum.Font.GothamBold,
            Text = string.upper(text),
            TextColor3 = Library.Theme.TextDim,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        Library:Register(Section, "TextColor3", "TextDim")
    end

    function Tab:CreateInfo(label, value)
        local Frame = Create("Frame", {
            Parent = Page,
            BackgroundColor3 = Library.Theme.Element,
            Size = UDim2.new(1, 0, 0, 42)
        })
        Library:Register(Frame, "BackgroundColor3", "Element")
        Create("UICorner", {Parent = Frame, CornerRadius = UDim.new(0, 6)})
        
        local L = Create("TextLabel", {
            Parent = Frame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 15, 0, 0),
            Size = UDim2.new(0.4, 0, 1, 0),
            Font = Enum.Font.Gotham,
            Text = label,
            TextColor3 = Library.Theme.TextDim,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        Library:Register(L, "TextColor3", "TextDim")

        local V = Create("TextLabel", {
            Parent = Frame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.4, 0, 0, 0),
            Size = UDim2.new(0.6, -15, 1, 0),
            Font = Enum.Font.GothamBold,
            Text = value,
            TextColor3 = Library.Theme.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd
        })
        Library:Register(V, "TextColor3", "Text")
    end

    function Tab:CreateButton(text, callback)
        local Btn = Create("TextButton", {
            Parent = Page,
            BackgroundColor3 = Library.Theme.Element,
            Size = UDim2.new(1, 0, 0, 42),
            AutoButtonColor = false,
            Font = Enum.Font.GothamMedium,
            Text = text,
            TextColor3 = Library.Theme.Text,
            TextSize = 14
        })
        Library:Register(Btn, "BackgroundColor3", "Element")
        Library:Register(Btn, "TextColor3", "Text")
        Create("UICorner", {Parent = Btn, CornerRadius = UDim.new(0, 6)})
        
        local Stroke = Create("UIStroke", {
            Parent = Btn,
            Color = Library.Theme.Accent,
            Thickness = 1,
            Transparency = 1
        })
        Library:Register(Stroke, "Color", "Accent")

        Btn.MouseEnter:Connect(function()
            TweenService:Create(Stroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
            TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 45, 50)}):Play()
        end)
        Btn.MouseLeave:Connect(function()
            TweenService:Create(Stroke, TweenInfo.new(0.2), {Transparency = 1}):Play()
            TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Element}):Play()
        end)
        
        Btn.MouseButton1Click:Connect(function()
            Library:Ripple(Btn)
            callback()
            TweenService:Create(Btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -4, 0, 38)}):Play()
            task.wait(0.1)
            TweenService:Create(Btn, TweenInfo.new(0.1), {Size = UDim2.new(1, 0, 0, 42)}):Play()
        end)
    end
    
    function Tab:CreateToggle(text, configKey, callback)
        local enabled = Config.Data.Toggles[configKey] or false
        
        local Frame = Create("TextButton", {
            Parent = Page,
            BackgroundColor3 = Library.Theme.Element,
            Size = UDim2.new(1, 0, 0, 42),
            AutoButtonColor = false,
            Text = ""
        })
        Library:Register(Frame, "BackgroundColor3", "Element")
        Create("UICorner", {Parent = Frame, CornerRadius = UDim.new(0, 6)})
        
        local Label = Create("TextLabel", {
            Parent = Frame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 15, 0, 0),
            Size = UDim2.new(0.7, 0, 1, 0),
            Font = Enum.Font.Gotham,
            Text = text,
            TextColor3 = Library.Theme.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        Library:Register(Label, "TextColor3", "Text")
        
        local Checkbox = Create("Frame", {
            Parent = Frame,
            BackgroundColor3 = enabled and Library.Theme.Accent or Color3.fromRGB(50,50,55),
            Position = UDim2.new(1, -35, 0.5, -10),
            Size = UDim2.new(0, 20, 0, 20)
        })
        Library:Register(Checkbox, "BackgroundColor3", enabled and "Accent" or "Element") -- Dynamic update handled manually below
        Create("UICorner", {Parent = Checkbox, CornerRadius = UDim.new(0, 4)})
        
        local CheckIcon = Create("ImageLabel", {
            Parent = Checkbox,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Image = "rbxassetid://6031094667",
            ImageTransparency = enabled and 0 or 1
        })
        
        local function Update()
            if enabled then
                TweenService:Create(Checkbox, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Accent}):Play()
                TweenService:Create(CheckIcon, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()
            else
                TweenService:Create(Checkbox, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50,50,55)}):Play()
                TweenService:Create(CheckIcon, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
            end
        end
        
        Frame.MouseButton1Click:Connect(function()
            enabled = not enabled
            Config.Data.Toggles[configKey] = enabled
            Update()
            callback(enabled)
            Library:Ripple(Frame)
        end)
    end
    
    function Tab:CreateColorPicker(text, themeKey)
        local Frame = Create("Frame", {
            Parent = Page,
            BackgroundColor3 = Library.Theme.Element,
            Size = UDim2.new(1, 0, 0, 85)
        })
        Library:Register(Frame, "BackgroundColor3", "Element")
        Create("UICorner", {Parent = Frame, CornerRadius = UDim.new(0, 6)})
        
        local Label = Create("TextLabel", {
            Parent = Frame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 15, 0, 10),
            Size = UDim2.new(1, 0, 0, 20),
            Font = Enum.Font.Gotham,
            Text = text,
            TextColor3 = Library.Theme.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        Library:Register(Label, "TextColor3", "Text")
        
        local Preview = Create("Frame", {
            Parent = Frame,
            BackgroundColor3 = Library.Theme[themeKey],
            Position = UDim2.new(1, -45, 0, 10),
            Size = UDim2.new(0, 30, 0, 20)
        })
        Create("UICorner", {Parent = Preview, CornerRadius = UDim.new(0, 4)})
        
        -- Simplified HSV Slider (Just Hue for space, can be expanded)
        local Slider = Create("Frame", {
            Parent = Frame,
            Position = UDim2.new(0, 15, 0, 45),
            Size = UDim2.new(1, -30, 0, 10),
            BackgroundColor3 = Color3.new(1,1,1)
        })
        Create("UICorner", {Parent = Slider, CornerRadius = UDim.new(1, 0)})
        Create("UIGradient", {
            Parent = Slider,
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromHSV(0,1,1)),
                ColorSequenceKeypoint.new(0.2, Color3.fromHSV(0.2,1,1)),
                ColorSequenceKeypoint.new(0.4, Color3.fromHSV(0.4,1,1)),
                ColorSequenceKeypoint.new(0.6, Color3.fromHSV(0.6,1,1)),
                ColorSequenceKeypoint.new(0.8, Color3.fromHSV(0.8,1,1)),
                ColorSequenceKeypoint.new(1, Color3.fromHSV(1,1,1))
            }
        })
        
        local Knob = Create("Frame", {
            Parent = Slider,
            BackgroundColor3 = Color3.new(1,1,1),
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(0, 0, 0.5, -7)
        })
        Create("UICorner", {Parent = Knob, CornerRadius = UDim.new(1, 0)})
        
        local Input = Create("TextButton", {Parent = Slider, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = ""})
        
        local dragging = false
        local H, S, V = Library.Theme[themeKey]:ToHSV()
        
        local function Update(input)
            local pos = math.clamp((input.Position.X - Slider.AbsolutePosition.X) / Slider.AbsoluteSize.X, 0, 1)
            Knob.Position = UDim2.new(pos, -7, 0.5, -7)
            H = pos
            local newColor = Color3.fromHSV(H, 1, 1)
            Library.Theme[themeKey] = newColor
            Preview.BackgroundColor3 = newColor
            Library:UpdateTheme(Library.Theme)
        end
        
        Input.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true Update(i) end end)
        UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then Update(i) end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    end
    
    function Tab:CreateSlider(text, min, max, default, callback)
        local value = default or min
        
        local Frame = Create("Frame", {
            Parent = Page,
            BackgroundColor3 = Library.Theme.Element,
            Size = UDim2.new(1, 0, 0, 60)
        })
        Library:Register(Frame, "BackgroundColor3", "Element")
        Create("UICorner", {Parent = Frame, CornerRadius = UDim.new(0, 6)})
        
        local Label = Create("TextLabel", {
            Parent = Frame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 15, 0, 10),
            Size = UDim2.new(1, -30, 0, 20),
            Font = Enum.Font.Gotham,
            Text = text,
            TextColor3 = Library.Theme.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        Library:Register(Label, "TextColor3", "Text")
        
        local ValueLabel = Create("TextLabel", {
            Parent = Frame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 15, 0, 10),
            Size = UDim2.new(1, -30, 0, 20),
            Font = Enum.Font.GothamBold,
            Text = tostring(value),
            TextColor3 = Library.Theme.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Right
        })
        Library:Register(ValueLabel, "TextColor3", "Text")
        
        local SliderBar = Create("Frame", {
            Parent = Frame,
            BackgroundColor3 = Color3.fromRGB(50, 50, 55),
            Position = UDim2.new(0, 15, 0, 40),
            Size = UDim2.new(1, -30, 0, 6)
        })
        Create("UICorner", {Parent = SliderBar, CornerRadius = UDim.new(1, 0)})
        
        local Fill = Create("Frame", {
            Parent = SliderBar,
            BackgroundColor3 = Library.Theme.Accent,
            Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        })
        Library:Register(Fill, "BackgroundColor3", "Accent")
        Create("UICorner", {Parent = Fill, CornerRadius = UDim.new(1, 0)})
        
        local Trigger = Create("TextButton", {
            Parent = SliderBar,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = ""
        })
        
        local dragging = false
        
        local function Update(input)
            local pos = math.clamp((input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
            local newVal = math.floor(min + ((max - min) * pos))
            
            value = newVal
            ValueLabel.Text = tostring(value)
            Fill.Size = UDim2.new(pos, 0, 1, 0)
            callback(value)
        end
        
        Trigger.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                Update(input)
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                Update(input)
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        
        return {
            SetMax = function(self, newMax)
                max = newMax
                local pos = (value - min) / (max - min)
                Fill.Size = UDim2.new(math.clamp(pos, 0, 1), 0, 1, 0)
            end
        }
    end

    function Tab:CreateDropdown(text, options, default, multi, callback)
        local expanded = false
        local selection = default or (multi and {} or options[1])
        
        local Frame = Create("Frame", {
            Parent = Page,
            BackgroundColor3 = Library.Theme.Element,
            Size = UDim2.new(1, 0, 0, 42),
            ClipsDescendants = true
        })
        Library:Register(Frame, "BackgroundColor3", "Element")
        Create("UICorner", {Parent = Frame, CornerRadius = UDim.new(0, 6)})
        
        local Trigger = Create("TextButton", {
            Parent = Frame,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = ""
        })
        
        local Label = Create("TextLabel", {
            Parent = Frame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 15, 0, 11),
            Size = UDim2.new(1, -45, 0, 20),
            Font = Enum.Font.Gotham,
            Text = text .. ": " .. (type(selection) == "table" and table.concat(selection, ", ") or tostring(selection)),
            TextColor3 = Library.Theme.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        })
        Library:Register(Label, "TextColor3", "Text")
        
        local Arrow = Create("ImageLabel", {
            Parent = Frame,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -30, 0, 11),
            Size = UDim2.new(0, 20, 0, 20),
            Image = "rbxassetid://6031091004",
            ImageColor3 = Library.Theme.TextDim,
            Rotation = 0
        })
        Library:Register(Arrow, "ImageColor3", "TextDim")
        
        local Container = Create("Frame", {
            Parent = Frame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 42),
            Size = UDim2.new(1, 0, 0, 0)
        })
        
        local List = Create("UIListLayout", {
            Parent = Container,
            SortOrder = Enum.SortOrder.LayoutOrder
        })
        
        local function Refresh()
            for _, v in pairs(Container:GetChildren()) do
                if v:IsA("TextButton") then v:Destroy() end
            end
            
            local totalHeight = 0
            
            for _, opt in ipairs(options) do
                local Button = Create("TextButton", {
                    Parent = Container,
                    BackgroundColor3 = Library.Theme.Element,
                    Size = UDim2.new(1, 0, 0, 32),
                    Font = Enum.Font.Gotham,
                    Text = "  " .. tostring(opt),
                    TextColor3 = Library.Theme.TextDim,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false
                })
                Library:Register(Button, "BackgroundColor3", "Element")
                Library:Register(Button, "TextColor3", "TextDim")
                
                local isSelected = false
                if multi and type(selection) == "table" then
                    for _, s in ipairs(selection) do if s == opt then isSelected = true break end end
                else
                    isSelected = (selection == opt)
                end
                
                if isSelected then
                    Button.TextColor3 = Library.Theme.Accent
                    Library:Register(Button, "TextColor3", "Accent")
                end
                
                Button.MouseButton1Click:Connect(function()
                    if multi and type(selection) == "table" then
                        local found = false
                        for i, s in ipairs(selection) do
                            if s == opt then
                                table.remove(selection, i)
                                found = true
                                break
                            end
                        end
                        if not found then table.insert(selection, opt) end
                        Label.Text = text .. ": " .. table.concat(selection, ", ")
                        callback(selection)
                    else
                        selection = opt
                        Label.Text = text .. ": " .. tostring(selection)
                        expanded = false
                        TweenService:Create(Frame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 42)}):Play()
                        TweenService:Create(Arrow, TweenInfo.new(0.3), {Rotation = 0}):Play()
                        callback(selection)
                    end
                    Refresh()
                end)
                
                totalHeight = totalHeight + 32
            end
            
            Container.Size = UDim2.new(1, 0, 0, totalHeight)
            if expanded then
                Frame.Size = UDim2.new(1, 0, 0, 42 + totalHeight)
            end
        end
        
        Trigger.MouseButton1Click:Connect(function()
            expanded = not expanded
            Refresh()
            if expanded then
                TweenService:Create(Frame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 42 + Container.Size.Y.Offset)}):Play()
                TweenService:Create(Arrow, TweenInfo.new(0.3), {Rotation = 180}):Play()
            else
                TweenService:Create(Frame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 42)}):Play()
                TweenService:Create(Arrow, TweenInfo.new(0.3), {Rotation = 0}):Play()
            end
        end)
        
        return {
            Clear = function() options = {} Refresh() end,
            Add = function(self, val) table.insert(options, val) Refresh() end,
            SetOptions = function(self, newOpts) options = newOpts Refresh() end
        }
    end

    function Tab:CreateInput(placeholder, default, callback)
        if type(default) == "function" then
            callback = default
            default = ""
        end

        local Frame = Create("Frame", {
            Parent = Page,
            BackgroundColor3 = Library.Theme.Element,
            Size = UDim2.new(1, 0, 0, 42)
        })
        Library:Register(Frame, "BackgroundColor3", "Element")
        Create("UICorner", {Parent = Frame, CornerRadius = UDim.new(0, 6)})
        
        local Box = Create("TextBox", {
            Parent = Frame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 15, 0, 0),
            Size = UDim2.new(1, -30, 1, 0),
            Font = Enum.Font.Gotham,
            PlaceholderText = placeholder,
            Text = default or "",
            TextColor3 = Library.Theme.Text,
            PlaceholderColor3 = Library.Theme.TextDim,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false
        })
        Library:Register(Box, "TextColor3", "Text")
        
        Box.FocusLost:Connect(function()
            callback(Box.Text)
        end)
    end

    function Tab:CreateConsole()
        -- Reduce padding for this specific page to maximize space
        local Padding = Page:FindFirstChildOfClass("UIPadding")
        if Padding then
            Padding.PaddingTop = UDim.new(0, 10)
            Padding.PaddingBottom = UDim.new(0, 10)
            Padding.PaddingLeft = UDim.new(0, 10)
            Padding.PaddingRight = UDim.new(0, 10)
        end
        
        local ConsoleFrame = Create("Frame", {
            Parent = Page,
            BackgroundColor3 = Color3.fromRGB(15, 15, 20),
            Size = UDim2.new(1, 0, 1, 0), -- Fill full space
            ClipsDescendants = true
        })
        Create("UICorner", {Parent = ConsoleFrame, CornerRadius = UDim.new(0, 6)})
        Create("UIStroke", {Parent = ConsoleFrame, Color = Library.Theme.Outline, Thickness = 1})
        
        local Scroll = Create("ScrollingFrame", {
            Parent = ConsoleFrame,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -10, 1, -10),
            Position = UDim2.new(0, 5, 0, 5),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 2
        })
        local List = Create("UIListLayout", {
            Parent = Scroll,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 4)
        })
        
        List:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Scroll.CanvasSize = UDim2.new(0, 0, 0, List.AbsoluteContentSize.Y)
            Scroll.CanvasPosition = Vector2.new(0, List.AbsoluteContentSize.Y) -- Auto scroll
        end)
        
        local function Log(text, color)
            local timestamp = os.date("%X")
            
            local Label = Create("TextLabel", {
                Parent = Scroll,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14), -- Reduced height
                Font = Enum.Font.Code,
                Text = string.format("[%s] %s", timestamp, text),
                TextColor3 = color or Library.Theme.Text,
                TextSize = 11, -- Smaller Text
                TextXAlignment = Enum.TextXAlignment.Left,
                RichText = true,
                TextWrapped = false, -- Don't wrap lines
                ClipsDescendants = true -- Let it go off screen
            })
            
            -- Color timestamp differently if possible, but simple RichText works
            Label.Text = string.format("<font color='#888888'>[%s]</font> %s", timestamp, text)
        end
        
        return Log
    end
    
    return Tab
end

--[[ AUTOSTRAT ENGINE IMPLEMENTATION ]]
local Window = Library:CreateWindow("Autostrat Engine")
local Home = Window:CreateTab("Dashboard", "rbxassetid://6034509993")

local Log = Home:CreateConsole()
getgenv().Log = Log
getgenv().logs = Log
Log("Autostrat Engine V4 Initialized", Color3.fromRGB(0, 255, 100))
Log("Waiting for user input...", Color3.fromRGB(200, 200, 200))

-- ACCOUNT TAB
local Account = Window:CreateTab("Account", "rbxassetid://6034509993")
Account:CreateSection("User Profile")
Account:CreateInfo("Username", LocalPlayer.Name)
Account:CreateInfo("User ID", tostring(LocalPlayer.UserId))

local hwid = "Hidden"
pcall(function()
    if gethwid then hwid = gethwid() end
end)
Account:CreateInfo("HWID", hwid)

-- SUPPORT TAB
local Support = Window:CreateTab("Support", "rbxassetid://6034509993")
Support:CreateSection("Community")
Support:CreateButton("Join Discord Server", function()
    setclipboard("https://discord.gg/tsFxZ4aRVa")
    Library:Notify("Discord", "Invite link copied to clipboard!", 3)
end)

Support:CreateSection("Contact Support")
local supportMessage = ""
Support:CreateInput("Type your issue here...", function(text)
    supportMessage = text
end)

Support:CreateButton("Send to Support", function()
    if supportMessage == "" then
        Library:Notify("Error", "Please type a message first.", 3)
        return
    end
    
    local WebhookURL = "https://discord.com/api/webhooks/1464334567572901930/52Z-ZmoXlkJcwHDnmh9Y6eHpCwOXfN8dP0he9WVtTw9yXrY-tX-j8fNhrlOLbutrdgSZ" -- PUT YOUR WEBHOOK URL HERE
    
    if WebhookURL == "" then
        Library:Notify("Error", "Webhook URL not configured in script.", 4)
        return
    end

    local executor = (identifyexecutor and identifyexecutor()) or "Unknown"

    local data = {
        embeds = {{
            title = "📨 New Support Ticket",
            url = "https://www.roblox.com/users/" .. LocalPlayer.UserId .. "/profile",
            description = ">>> " .. supportMessage,
            color = 39423,
            fields = {
                {
                    name = "👤 User Information",
                    value = string.format("**Display:** %s\n**Username:** %s\n**ID:** [%s](https://www.roblox.com/users/%s/profile)", LocalPlayer.DisplayName, LocalPlayer.Name, LocalPlayer.UserId, LocalPlayer.UserId),
                    inline = true
                },
                {
                    name = "💻 System Details",
                    value = string.format("**Executor:** %s\n**HWID:** ||%s||", executor, hwid or "Hidden"),
                    inline = true
                },
                {
                    name = "🎮 Session Info",
                    value = string.format("**Place ID:** %s\n**Job ID:** `%s`", game.PlaceId, game.JobId),
                    inline = false
                }
            },
            footer = {
                text = "Autostrat Engine • " .. os.date("%Y-%m-%d %H:%M:%S")
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    
    local success, err = pcall(function()
        local http = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        if http then
            http({
                Url = WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = game:GetService("HttpService"):JSONEncode(data)
            })
        end
    end)
    
    if success then
         Library:Notify("Success", "Support request sent!", 3)
    else
         Library:Notify("Error", "Failed to send request.", 3)
    end
end)

-- SETTINGS TAB
local Settings = Window:CreateTab("Settings", "rbxassetid://6031280882")
Settings:CreateSection("Appearance")
Settings:CreateColorPicker("Accent Color", "Accent")
Settings:CreateColorPicker("Background Color", "Background")
Settings:CreateSection("Data")
Settings:CreateButton("Save Configuration", function()
    Config:Save()
    Library:Notify("Config", "Configuration saved.", 2)
end)

Library:Notify("Welcome", "Autostrat Engine V4 loaded.", 4)

local Autostrat = Window:CreateTab("Autostrat", "rbxassetid://3926305904")
Autostrat:CreateSection("Main")

Autostrat:CreateToggle("Auto Rejoin", "AutoRejoin", function(v)
    set_setting("AutoRejoin", v)
end)

Autostrat:CreateToggle("Auto Skip Waves", "AutoSkip", function(v)
    set_setting("AutoSkip", v)
end)

Autostrat:CreateToggle("Auto Chain", "AutoChain", function(v)
    set_setting("AutoChain", v)
end)

Autostrat:CreateToggle("Auto DJ Booth", "AutoDJ", function(v)
    set_setting("AutoDJ", v)
end)

Autostrat:CreateDropdown("Modifiers:", All_Modifiers, _G.Modifiers, true, function(choice)
    set_setting("Modifiers", choice)
end)

Autostrat:CreateSection("Farm")
Autostrat:CreateToggle("Sell Farms", "SellFarms", function(v)
    set_setting("SellFarms", v)
end)

Autostrat:CreateTextbox("Wave:", tostring(_G.SellFarmsWave), function(text)
    local number = tonumber(text)
    if number then
        set_setting("SellFarmsWave", number)
    else
        Library:Notify("ADS", "Invalid number entered!", 3)
    end
end)

Autostrat:CreateSection("Abilities")
Autostrat:CreateToggle("Enable Path Distance Marker", "PathVisuals", function(v)
    set_setting("PathVisuals", v)
end)

Autostrat:CreateToggle("Auto Mercenary Base", "AutoMercenary", function(v)
    set_setting("AutoMercenary", v)
end)

MercenarySlider = Autostrat:CreateSlider("Path Distance", 0, 300, _G.MercenaryPath, function(val)
    set_setting("MercenaryPath", val)
end)

Autostrat:CreateToggle("Auto Military Base", "AutoMilitary", function(v)
    set_setting("AutoMilitary", v)
end)

MilitarySlider = Autostrat:CreateSlider("Path Distance", 0, 300, _G.MilitaryPath, function(val)
    set_setting("MilitaryPath", val)
end)

task.spawn(function()
    while true do
        local success = calc_length()
        if success then break end
        task.wait(3)
    end
end)

Window:Line()

local Main = Window:CreateTab("Main", "rbxassetid://3926307971")
Main:CreateSection("Tower Options")
local TowerDropdown = Main:CreateDropdown("Tower:", current_equipped_towers, current_equipped_towers[1], function(choice)
    selected_tower = choice
end)

local function refresh_dropdown()
    local new_towers = get_equipped_towers()
    if table.concat(new_towers, ",") ~= table.concat(current_equipped_towers, ",") then
        TowerDropdown:Clear() 
        
        for _, tower_name in ipairs(new_towers) do
            TowerDropdown:Add(tower_name)
        end
        
        current_equipped_towers = new_towers
    end
end

task.spawn(function()
    while task.wait(2) do
        refresh_dropdown()
    end
end)

Main:CreateToggle("Stack Tower", "StackTower", function(v)
    set_setting("StackTower", v)
    if v then
        Library:Notify("ADS", "Make sure not to equip the tower, only select it and then place where you want to!", 5)
    end
end)

Main:CreateButton("Upgrade Selected", function()
    if selected_tower then
        for _, v in pairs(workspace.Towers:GetChildren()) do
            if v:FindFirstChild("TowerReplicator") and v.TowerReplicator:GetAttribute("Name") == selected_tower and v.TowerReplicator:GetAttribute("OwnerId") == local_player.UserId then
                remote_func:InvokeServer("Troops", "Upgrade", "Set", {Troop = v})
            end
        end
        Library:Notify("ADS", "Attempted to upgrade all the selected towers!", 3)
    end
end)

Main:CreateButton("Sell Selected", function()
    if selected_tower then
        for _, v in pairs(workspace.Towers:GetChildren()) do
            if v:FindFirstChild("TowerReplicator") and v.TowerReplicator:GetAttribute("Name") == selected_tower and v.TowerReplicator:GetAttribute("OwnerId") == local_player.UserId then
                remote_func:InvokeServer("Troops", "Sell", {Troop = v})
            end
        end
        Library:Notify("ADS", "Attempted to sell all the selected towers!", 3)
    end
end)

Main:CreateButton("Upgrade All", function()
    for _, v in pairs(workspace.Towers:GetChildren()) do
        if v:FindFirstChild("Owner") and v.Owner.Value == local_player.UserId then
            remote_func:InvokeServer("Troops", "Upgrade", "Set", {Troop = v})
        end
    end
    Library:Notify("ADS", "Attempted to upgrade all the towers!", 3)
end)

Main:CreateButton("Sell All", function()
    for _, v in pairs(workspace.Towers:GetChildren()) do
        if v:FindFirstChild("Owner") and v.Owner.Value == local_player.UserId then
            remote_func:InvokeServer("Troops", "Sell", {Troop = v})
        end
    end
    Library:Notify("ADS", "Attempted to sell all the towers!", 3)
end)
run_service.RenderStepped:Connect(function()
    if get_setting("StackTower") then
        if not stack_sphere then
            stack_sphere = Instance.new("Part")
            stack_sphere.Shape = Enum.PartType.Ball
            stack_sphere.Size = Vector3.new(1.5, 1.5, 1.5)
            stack_sphere.Color = Color3.fromRGB(0, 255, 0)
            stack_sphere.Transparency = 0.5
            stack_sphere.Anchored = true
            stack_sphere.CanCollide = false
            stack_sphere.Material = Enum.Material.Neon
            stack_sphere.Parent = workspace
            mouse.TargetFilter = stack_sphere
        end
        local hit = mouse.Hit
        if hit then stack_sphere.Position = hit.Position end
    elseif stack_sphere then
        stack_sphere:Destroy()
        stack_sphere = nil
    end

    update_path_visuals()
end)

mouse.Button1Down:Connect(function()
    if get_setting("StackTower") and stack_sphere and selected_tower then
        local pos = stack_sphere.Position
        local newpos = Vector3.new(pos.X, pos.Y + 25, pos.Z)
        remote_func:InvokeServer("Troops", "Place", {Rotation = CFrame.new(), Position = newpos}, selected_tower)
    end
end)

-- // currency tracking
local start_coins, current_total_coins, start_gems, current_total_gems = 0, 0, 0, 0
if game_state == "GAME" then
    pcall(function()
        repeat task.wait(1) until local_player:FindFirstChild("Coins")
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

-- // rejoining
local function rejoin_match()
    local remote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunction")
    local success = false
    local res

    repeat
        local state_folder = replicated_storage:FindFirstChild("State")
        local current_mode = state_folder and state_folder.Difficulty.Value

        if current_mode then
            local ok, result = pcall(function()
                local payload

                if current_mode == "PizzaParty" then
                    payload = {
                        mode = "halloween",
                        count = 1
                    }
                elseif current_mode == "Hardcore" then
                    payload = {
                        mode = "hardcore",
                        count = 1
                    }
                elseif current_mode == "PollutedWasteland" then
                    payload = {
                        mode = "polluted",
                        count = 1
                    }
                elseif current_mode == "Badlands" then
                    payload = {
                        mode = "badlands",
                        count = 1
                    }
                else
                    payload = {
                        difficulty = current_mode,
                        mode = "survival",
                        count = 1
                    }
                end

                return remote:InvokeServer("Multiplayer", "v2:start", payload)
            end)

            if ok and check_res_ok(result) then
                success = true
                res = result
            else
                task.wait(0.5) 
            end
        else
            task.wait(1)
        end
    until success
    
    return res
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

    if not ui_root then return rejoin_match() end
    if not _G.AutoRejoin then return end

    if not _G.SendWebhook then
        rejoin_match()
        return
    end

    task.wait(1)
    
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
        username = "TDS AutoStrat",
        embeds = {{
            title = (match.Status == "WIN" and "🏆 TRIUMPH" or "💀 DEFEAT"),
            color = (match.Status == "WIN" and 0x2ecc71 or 0xe74c3c),
            description =
                "### 📋 Match Overview\n" ..
                "> **Status:** `" .. match.Status .. "`\n" ..
                "> **Time:** `" .. match.Time .. "`\n" ..
                "> **Current Level:** `" .. match.Level .. "`\n" ..
                "> **Wave:** `" .. match.Wave .. "`\n",
                
            fields = {
                {
                    name = "✨ Rewards",
                    value = "```ansi\n" ..
                            "[2;33mCoins:[0m +" .. match.Coins .. "\n" ..
                            "[2;34mGems: [0m +" .. match.Gems .. "\n" ..
                            "[2;32mXP:   [0m +" .. match.XP .. "```",
                    inline = false
                },
                {
                    name = "🎁 Bonus Items",
                    value = bonus_string,
                    inline = true
                },
                {
                    name = "📊 Session Totals",
                    value = "```py\n# Total Amount\nCoins: " .. current_total_coins .. "\nGems:  " .. current_total_gems .. "```",
                    inline = true
                }
            },
            footer = { text = "Logged for " .. local_player.Name .. " • TDS AutoStrat" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    pcall(function()
        send_request({
            Url = _G.WebhookURL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode(post_data)
        })
    end)

    task.wait(1.5)

    rejoin_match()
end

-- // voting & map selection
local function run_vote_skip()
    while true do
        local success = pcall(function()
            remote_func:InvokeServer("Voting", "Skip")
        end)
        if success then break end
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

    run_vote_skip()
end

local function cast_map_vote(map_id, pos_vec)
    local target_map = map_id or "Simplicity"
    local target_pos = pos_vec or Vector3.new(0,0,0)
    remote_event:FireServer("LobbyVoting", "Vote", target_map, target_pos)
    Logger:Log("Cast map vote: " .. target_map)
end

local function lobby_ready_up()
    pcall(function()
        remote_event:FireServer("LobbyVoting", "Ready")
        Logger:Log("Lobby ready up sent")
    end)
end

local function select_map_override(map_id, ...)
    local args = {...}

    if args[#args] == "vip" then
        remote_func:InvokeServer("LobbyVoting", "Override", map_id)
    end

    task.wait(3)
    cast_map_vote(map_id, Vector3.new(12.59, 10.64, 52.01))
    task.wait(1)
    lobby_ready_up()
    match_ready_up()
end

local function cast_modifier_vote(mods_table)
    local bulk_modifiers = replicated_storage:WaitForChild("Network"):WaitForChild("Modifiers"):WaitForChild("RF:BulkVoteModifiers")
    
    local selected_mods = {}

    if mods_table and #mods_table > 0 then
        for _, modName in ipairs(mods_table) do
            selected_mods[modName] = true
        end
    end

    pcall(function()
        bulk_modifiers:InvokeServer(selected_mods)
        Logger:Log("Successfully casted modifier votes.")
    end)
end

local function is_map_available(name)
    for _, g in ipairs(workspace:GetDescendants()) do
        if g:IsA("SurfaceGui") and g.Name == "MapDisplay" then
            local t = g:FindFirstChild("Title")
            if t and t.Text == name then return true end
        end
    end

    repeat
        remote_event:FireServer("LobbyVoting", "Veto")
        wait(1)

        local found = false
        for _, g in ipairs(workspace:GetDescendants()) do
            if g:IsA("SurfaceGui") and g.Name == "MapDisplay" then
                local t = g:FindFirstChild("Title")
                if t and t.Text == name then
                    found = true
                    break
                end
            end
        end

        local total_player = #players_service:GetChildren()
        local veto_text = player_gui:WaitForChild("ReactGameIntermission"):WaitForChild("Frame"):WaitForChild("buttons"):WaitForChild("veto"):WaitForChild("value").Text
        
    until found or veto_text == "Veto ("..total_player.."/"..total_player..")"

    for _, g in ipairs(workspace:GetDescendants()) do
        if g:IsA("SurfaceGui") and g.Name == "MapDisplay" then
            local t = g:FindFirstChild("Title")
            if t and t.Text == name then return true end
        end
    end

    return false
end

-- // timescale logic
local function set_game_timescale(target_val)
    if game_state ~= "GAME" then 
        return false 
    end

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

    for _ = 1, diff do
        replicated_storage.RemoteFunction:InvokeServer(
            "TicketsManager",
            "CycleTimeScale"
        )
        task.wait(0.5)
    end
end

local function unlock_speed_tickets()
    if game_state ~= "GAME" then 
        return false 
    end

    if local_player.TimescaleTickets.Value >= 1 then
        if game.Players.LocalPlayer.PlayerGui.ReactUniversalHotbar.Frame.timescale.Lock.Visible then
            replicated_storage.RemoteFunction:InvokeServer('TicketsManager', 'UnlockTimeScale')
            Logger:Log("Unlocked timescale tickets")
        end
    else
        Logger:Log("No timescale tickets left")
    end
end

-- // ingame control
local function trigger_restart()
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

    task.wait(3)
    run_vote_skip()
end

local function get_current_wave()
    local label

    repeat
        task.wait(0.5)
        label = player_gui:FindFirstChild("ReactGameTopGameDisplay", true) 
            and player_gui.ReactGameTopGameDisplay.Frame.wave.container:FindFirstChild("value")
    until label ~= nil

    local text = label.Text
    local wave_num = text:match("(%d+)")

    return tonumber(wave_num) or 0
end

local function do_place_tower(t_name, t_pos)
    Logger:Log("Placing tower: " .. t_name)
    while true do
        local ok, res = pcall(function()
            return remote_func:InvokeServer("Troops", "Pl\208\176ce", {
                Rotation = CFrame.new(),
                Position = t_pos
            }, t_name)
        end)

        if ok and check_res_ok(res) then return true end
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
        if ok and check_res_ok(res) then return true end
        task.wait(0.25)
    end
end

local function do_sell_tower(t_obj)
    while true do
        local ok, res = pcall(function()
            return remote_func:InvokeServer("Troops", "Sell", { Troop = t_obj })
        end)
        if ok and check_res_ok(res) then return true end
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
        if ok and check_res_ok(res) then return true end
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
        repeat
            local ok, result = pcall(function()
                local mode = TDS.matchmaking_map[difficulty]

                local payload

                if mode then
                    payload = {
                        mode = mode,
                        count = 1
                    }
                else
                    payload = {
                        difficulty = difficulty,
                        mode = "survival",
                        count = 1
                    }
                end

                return remote:InvokeServer("Multiplayer", "v2:start", payload)
            end)

            if ok and check_res_ok(result) then
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
    if game_state ~= "GAME" and game_state ~= "LOBBY" then
        return
    end

    local towers = {...}
    local remote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunction")
    local state_replicators = replicated_storage:FindFirstChild("StateReplicators")
    
    local currently_equipped = {}

    if state_replicators then
        for _, folder in ipairs(state_replicators:GetChildren()) do
            if folder.Name == "PlayerReplicator" and folder:GetAttribute("UserId") == local_player.UserId then
                local equipped_attr = folder:GetAttribute("EquippedTowers")
                if type(equipped_attr) == "string" then
                    local cleaned_json = equipped_attr:match("%[.*%]") 
                    local decode_success, decoded = pcall(function()
                        return http_service:JSONDecode(cleaned_json)
                    end)

                    if decode_success and type(decoded) == "table" then
                        currently_equipped = decoded
                    end
                end
            end
        end
    end

    for _, current_tower in ipairs(currently_equipped) do
        if current_tower ~= "None" then
            local unequip_done = false
            repeat
                local ok = pcall(function()
                    remote:InvokeServer("Inventory", "Unequip", "tower", current_tower)
                    task.wait(0.3)
                end)
                if ok then unequip_done = true else task.wait(0.2) end
            until unequip_done
        end
    end

    task.wait(0.5)

    for _, tower_name in ipairs(towers) do
        if tower_name and tower_name ~= "" then
            local equip_success = false
            repeat
                local ok = pcall(function()
                    remote:InvokeServer("Inventory", "Equip", "tower", tower_name)
                    Logger:Log("Equipped tower: " .. tower_name)
                    task.wait(0.3)
                end)
                if ok then equip_success = true else task.wait(0.2) end
            until equip_success
        end
    end

    task.wait(0.5)
    return true
end

-- ingame
function TDS:VoteSkip(start_wave, end_wave)
    task.spawn(function()
        local current_wave = get_current_wave()
        start_wave = start_wave or (current_wave > 0 and current_wave or 1)
        end_wave = end_wave or start_wave

        for wave = start_wave, end_wave do
            while get_current_wave() < wave do
                task.wait(1)
            end

            local skip_done = false
            while not skip_done do
                local vote_ui = player_gui:FindFirstChild("ReactOverridesVote")
                local vote_button = vote_ui 
                    and vote_ui:FindFirstChild("Frame") 
                    and vote_ui.Frame:FindFirstChild("votes") 
                    and vote_ui.Frame.votes:FindFirstChild("vote", true)

                if vote_button and vote_button.Position == UDim2.new(0.5, 0, 0.5, 0) then
                    run_vote_skip()
                    skip_done = true
                    Logger:Log("Voted to skip wave " .. wave)
                else
                    if get_current_wave() > wave then
                        break 
                    end
                    task.wait(0.5)
                end
            end
        end
    end)
end

function TDS:GameInfo(name, list)
    if game_state ~= "GAME" then return false end

    local vote_gui = player_gui:WaitForChild("ReactGameIntermission", 30)
    if not (vote_gui and vote_gui.Enabled and vote_gui:WaitForChild("Frame", 5)) then return end

    local modifiers = (list and #list > 0) and list or _G.Modifiers
    
    cast_modifier_vote(modifiers)

    if marketplace_service:UserOwnsGamePassAsync(local_player.UserId, 10518590) then
        select_map_override(name, "vip")
        Logger:Log("Selected map: " .. name)
        repeat task.wait(1) until player_gui:FindFirstChild("ReactUniversalHotbar")
        return true 
    elseif is_map_available(name) then
        select_map_override(name)
        repeat task.wait(1) until player_gui:FindFirstChild("ReactUniversalHotbar")
        return true
    else
        Logger:Log("Map '" .. name .. "' not available, rejoining...")
        teleport_service:Teleport(3260590327, local_player)
        repeat task.wait(9999) until false
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

function TDS:Place(t_name, px, py, pz, ...)
    local args = {...}
    local stack = false

    if args[#args] == "stack" or args[#args] == true then
        py = py+20
    end
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
        Logger:Log("Upgrading tower index: " .. idx)
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
        Logger:Log("Set target for tower index " .. idx .. " to " .. target_type)
    end)
end

function TDS:Sell(idx, req_wave)
    if req_wave then
        repeat task.wait(0.5) until get_current_wave() >= req_wave
    end
    local t = self.placed_towers[idx]
    if t and do_sell_tower(t) then
        return true
    end
    return false
end

function TDS:SellAll(req_wave)
    task.spawn(function()
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
    end)
end

function TDS:Ability(idx, name, data, loop)
    local t = self.placed_towers[idx]
    if not t then return false end
    Logger:Log("Activating ability '" .. name .. "' for tower index: " .. idx)
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
        Logger:Log("Setting option '" .. name .. "' for tower index: " .. idx)
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
    if auto_pickups_running or not _G.AutoPickups then return end
    auto_pickups_running = true

    task.spawn(function()
        while _G.AutoPickups do
            local folder = workspace:FindFirstChild("Pickups")
            local hrp = get_root()

            if folder and hrp then
                for _, item in ipairs(folder:GetChildren()) do
                    if not _G.AutoPickups then break end

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
    if auto_skip_running or not _G.AutoSkip then return end
    auto_skip_running = true

    task.spawn(function()
        while _G.AutoSkip do
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

local function start_claim_rewards()
    if auto_claim_rewards or not _G.ClaimRewards or game_state ~= "LOBBY" then 
        return 
    end
    
    auto_claim_rewards = true

    local player = game:GetService("Players").LocalPlayer
    local network = game:GetService("ReplicatedStorage"):WaitForChild("Network")
        
    local spin_tickets = player:WaitForChild("SpinTickets", 15)
    
    if spin_tickets and spin_tickets.Value > 0 then
        local ticket_count = spin_tickets.Value
        
        local daily_spin = network:WaitForChild("DailySpin", 5)
        local redeem_remote = daily_spin and daily_spin:WaitForChild("RF:RedeemSpin", 5)
    
        if redeem_remote then
            for i = 1, ticket_count do
                redeem_remote:InvokeServer()
                task.wait(0.5)
            end
        end
    end

    for i = 1, 6 do
        local args = { i }
        network:WaitForChild("PlaytimeRewards"):WaitForChild("RF:ClaimReward"):InvokeServer(unpack(args))
        task.wait(0.5)
    end
    
    game:GetService("ReplicatedStorage").Network.DailySpin["RF:RedeemReward"]:InvokeServer()
    auto_claim_rewards = false
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

    local settings = settings().Rendering
    local original_quality = settings.QualityLevel
    settings.QualityLevel = Enum.QualityLevel.Level01

    task.spawn(function()
        while _G.AntiLag do
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

local function start_auto_chain()
    if auto_chain_running or not _G.AutoChain then return end
    auto_chain_running = true

    task.spawn(function()
        local idx = 1

        while _G.AutoChain do
            local commander = {}
            local towers_folder = workspace:FindFirstChild("Towers")

            if towers_folder then
                for _, towers in ipairs(towers_folder:GetDescendants()) do
                    if towers:IsA("Folder") and towers.Name == "TowerReplicator"
                    and towers:GetAttribute("Name") == "Commander"
                    and towers:GetAttribute("OwnerId") == game.Players.LocalPlayer.UserId
                    and (towers:GetAttribute("Upgrade") or 0) >= 2 then
                        commander[#commander + 1] = towers.Parent
                    end
                end
            end

            if #commander >= 3 then
                if idx > #commander then idx = 1 end

                local current_commander = commander[idx]
                local replicator = current_commander:FindFirstChild("TowerReplicator")
                local upgrade_level = replicator and replicator:GetAttribute("Upgrade") or 0

                if upgrade_level >= 4 then
                    remote_func:InvokeServer(
                        "Troops",
                        "Abilities",
                        "Activate",
                        { Troop = current_commander, Name = "Support Caravan", Data = {} }
                    )
                    task.wait(0.1) 
                end

                local response = remote_func:InvokeServer(
                    "Troops",
                    "Abilities",
                    "Activate",
                    { Troop = current_commander, Name = "Call Of Arms", Data = {} }
                )

                if response then
                    idx += 1

                    local hotbar = player_gui:FindFirstChild("ReactUniversalHotbar")
                    local timescale_frame = hotbar and hotbar.Frame:FindFirstChild("timescale")
                    
                    if timescale_frame and timescale_frame.Visible then
                        if timescale_frame:FindFirstChild("Lock") then
                            task.wait(10.3)
                        else
                            task.wait(5.25)
                        end
                    else
                        task.wait(10.3)
                    end
                else
                    task.wait(0.5)
                end
            else
                task.wait(1)
            end
        end

        auto_chain_running = false
    end)
end

local function start_auto_dj_booth()
    if auto_dj_running or not _G.AutoDJ then return end
    auto_dj_running = true

    task.spawn(function()
        while _G.AutoDJ do
            local towers_folder = workspace:FindFirstChild("Towers")

            if towers_folder then
                for _, towers in ipairs(towers_folder:GetDescendants()) do
                    if towers:IsA("Folder") and towers.Name == "TowerReplicator"
                    and towers:GetAttribute("Name") == "DJ Booth"
                    and towers:GetAttribute("OwnerId") == game.Players.LocalPlayer.UserId
                    and (towers:GetAttribute("Upgrade") or 0) >= 3 then
                        DJ = towers.Parent
                    end
                end
            end

            if DJ then
                remote_func:InvokeServer(
                    "Troops",
                    "Abilities",
                    "Activate",
                    { Troop = DJ, Name = "Drop The Beat", Data = {} }
                )
            end

            task.wait(1)
        end

        auto_dj_running = false
    end)
end

local function start_auto_mercenary()
    if not _G.AutoMercenary and not _G.AutoMilitary then return end
        
    if auto_mercenary_base_running then return end
    auto_mercenary_base_running = true

    task.spawn(function()
        while _G.AutoMercenary do
            local towers_folder = workspace:FindFirstChild("Towers")

            if towers_folder then
                for _, towers in ipairs(towers_folder:GetDescendants()) do
                    if towers:IsA("Folder") and towers.Name == "TowerReplicator"
                    and towers:GetAttribute("Name") == "Mercenary Base"
                    and towers:GetAttribute("OwnerId") == game.Players.LocalPlayer.UserId
                    and (towers:GetAttribute("Upgrade") or 0) >= 5 then
                        
                        remote_func:InvokeServer(
                            "Troops",
                            "Abilities",
                            "Activate",
                            { 
                                Troop = towers.Parent, 
                                Name = "Air-Drop", 
                                Data = {
                                    pathName = 1, 
                                    directionCFrame = CFrame.new(), 
                                    dist = _G.MercenaryPath or 195
                                } 
                            }
                        )

                        task.wait(0.5)
                        
                        if not _G.AutoMercenary then break end
                    end
                end
            end

            task.wait(0.5)
        end

        auto_mercenary_base_running = false
    end)
end

local function start_auto_military()
    if not _G.AutoMilitary then return end
        
    if auto_military_base_running then return end
    auto_military_base_running = true

    task.spawn(function()
        while _G.AutoMilitary do
            local towers_folder = workspace:FindFirstChild("Towers")
            if towers_folder then
                for _, towers in ipairs(towers_folder:GetDescendants()) do
                    if towers:IsA("Folder") and towers.Name == "TowerReplicator"
                    and towers:GetAttribute("Name") == "Military Base"
                    and towers:GetAttribute("OwnerId") == game.Players.LocalPlayer.UserId
                    and (towers:GetAttribute("Upgrade") or 0) >= 4 then
                        
                        remote_func:InvokeServer(
                            "Troops",
                            "Abilities",
                            "Activate",
                            { 
                                Troop = towers.Parent, 
                                Name = "Airstrike", 
                                Data = {
                                    pathName = 1, 
                                    pointToEnd = CFrame.new(), 
                                    dist = _G.MilitaryPath or 195
                                } 
                            }
                        )

                        task.wait(0.5)
                        
                        if not _G.AutoMilitary then break end
                    end
                end
            end

            task.wait(0.5)
        end
        
        auto_military_base_running = false
    end)
end

local function start_sell_farm()
    if sell_farms_running or not _G.SellFarms then return end
    sell_farms_running = true

    if game_state ~= "GAME" then 
        return false 
    end

    task.spawn(function()
        while _G.SellFarms do
            local current_wave = get_current_wave()
            if _G.SellFarmsWave and current_wave < _G.SellFarmsWave then
                task.wait(1)
                continue
            end

            local towers_folder = workspace:FindFirstChild("Towers")
            if towers_folder then
                for _, replicator in ipairs(towers_folder:GetDescendants()) do
                    if replicator:IsA("Folder") and replicator.Name == "TowerReplicator" then
                        local is_farm = replicator:GetAttribute("Name") == "Farm"
                        local is_mine = replicator:GetAttribute("OwnerId") == game.Players.LocalPlayer.UserId

                        if is_farm and is_mine then
                            local tower_model = replicator.Parent
                            remote_func:InvokeServer("Troops", "Sell", { Troop = tower_model })
                            
                            task.wait(0.2)
                        end
                    end
                end
            end

            task.wait(1)
        end
        sell_farms_running = false
    end)
end

local function check_and_equip_loadout()
    if game_state ~= "LOBBY" or not _G.Loadout or #_G.Loadout == 0 then return end
    
    local current = get_equipped_towers()
    local target = _G.Loadout
    
    local match = true
    if #current ~= #target then
        match = false
    else
        for _, t in ipairs(target) do
            local found = false
            for _, c in ipairs(current) do
                if c == t then found = true break end
            end
            if not found then match = false break end
        end
    end
    
    if not match then
        TDS:Loadout(unpack(target))
    end
end

local last_join_attempt = 0
local function check_and_join_game()
    if game_state ~= "LOBBY" or not _G.Gamemode or _G.Gamemode == "" then return end
    
    if _G.Loadout and #_G.Loadout > 0 then
        local current = get_equipped_towers()
        local target = _G.Loadout
        if #current ~= #target then return end
    end

    if tick() - last_join_attempt > 10 then
        last_join_attempt = tick()
        TDS:Mode(_G.Gamemode)
    end
end

task.spawn(function()
    while true do
        check_and_equip_loadout()
        check_and_join_game()
        
        if game_state == "GAME" and _G.Map and _G.Map ~= "" then
             TDS:GameInfo(_G.Map, _G.Modifiers)
        end

        if _G.AutoPickups and not auto_pickups_running then
            start_auto_pickups()
        end
        
        if _G.AutoSkip and not auto_skip_running then
            start_auto_skip()
        end

        if _G.AutoChain and not auto_chain_running then
            start_auto_chain()
        end

        if _G.AutoDJ and not auto_dj_running then
            start_auto_dj_booth()
        end

        if _G.AutoMercenary and not auto_mercenary_base_running then
            start_auto_mercenary()
        end

        if _G.AutoMilitary and not auto_military_base_running then
            start_auto_military()
        end

        if _G.SellFarms and not sell_farms_running then
            start_sell_farm()
        end
        
        if _G.AntiLag and not anti_lag_running then
            start_anti_lag()
        end

        if _G.AutoRejoin and not back_to_lobby_running then
            start_back_to_lobby()
        end
        
        task.wait(1)
    end
end)

if _G.ClaimRewards and not auto_claim_rewards then
    start_claim_rewards()
end

return TDS
return Library

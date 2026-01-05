local PlayerHandler = {}

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

PlayerHandler.Services = {
    Players = Players,
    TeleportService = TeleportService,
    MarketplaceService = MarketplaceService,
    ReplicatedStorage = ReplicatedStorage,
    HttpService = HttpService,
    RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunction", 10),
    RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent", 10)
}

function PlayerHandler.GetLocalPlayer()
    return Players.LocalPlayer or Players.PlayerAdded:Wait()
end

function PlayerHandler.IdentifyGameState()
    if not game:IsLoaded() then game.Loaded:Wait() end
    
    local player = PlayerHandler.GetLocalPlayer()
    local player_gui = player:WaitForChild("PlayerGui")
    
    -- Timeout after 60 seconds to avoid infinite loop
    local start_time = tick()
    while tick() - start_time < 60 do
        if player_gui:FindFirstChild("LobbyGui") then
            return "LOBBY"
        elseif player_gui:FindFirstChild("GameGui") then
            return "GAME"
        end
        task.wait(1)
    end
    
    return "UNKNOWN"
end

return PlayerHandler

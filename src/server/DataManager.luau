--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SaveDataStore = DataStoreService:GetDataStore("GrowUpLeBron_v1")
local DataManager = {}
local sessionData: { [Player]: any } = {}

-- Helper function to clone the default stats table so players don't share references
local function cloneTable(t: any): any
    if type(t) ~= "table" then return t end
    local clone = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            clone[k] = cloneTable(v)
        else
            clone[k] = v
        end
    end
    return clone
end

-- Load player data
local function loadData(player: Player)
    local userId = player.UserId
    local dataKey = "Player_" .. userId
    
    local success, data = pcall(function()
        return SaveDataStore:GetAsync(dataKey)
    end)
    
    local loadedData
    if success and data then
        loadedData = data
        -- Re-verify that any new config fields are populated (backwards compatibility)
        local defaultStats = Config.StartingStats
        for key, defaultValue in pairs(defaultStats) do
            if loadedData[key] == nil then
                loadedData[key] = cloneTable(defaultValue)
            elseif type(defaultValue) == "table" then
                for subKey, subValue in pairs(defaultValue) do
                    if loadedData[key][subKey] == nil then
                        loadedData[key][subKey] = subValue
                    end
                end
            end
        end
    else
        loadedData = cloneTable(Config.StartingStats)
        if not success then
            warn("Failed to load data for player " .. player.Name .. ". Loading default stats.")
        end
    end
    
    sessionData[player] = loadedData
    
    -- Sync loaded data to Player attributes for easy client replication
    player:SetAttribute("Cash", loadedData.Cash)
    player:SetAttribute("Rebirths", loadedData.Rebirths)
    player:SetAttribute("HoopUpgradeLevel", loadedData.HoopUpgradeLevel)
    if loadedData.OwnedShooters then
        for tier, count in pairs(loadedData.OwnedShooters) do
            player:SetAttribute("Shooter_" .. tier, count)
        end
    end
    
    -- Setup Roblox Leaderstats (top right leaderboard)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
    
    local cashVal = Instance.new("IntValue")
    cashVal.Name = "Cash"
    cashVal.Value = loadedData.Cash
    cashVal.Parent = leaderstats
    
    local rebirthsVal = Instance.new("IntValue")
    rebirthsVal.Name = "Rebirths"
    rebirthsVal.Value = loadedData.Rebirths
    rebirthsVal.Parent = leaderstats
end

-- Save player data
local function saveData(player: Player)
    local data = sessionData[player]
    if not data then return end
    
    local userId = player.UserId
    local dataKey = "Player_" .. userId
    
    local success, err = pcall(function()
        SaveDataStore:SetAsync(dataKey, data)
    end)
    
    if not success then
        warn("Failed to save data for player " .. player.Name .. ": " .. tostring(err))
    else
        print("Successfully saved data for " .. player.Name)
    end
end

-- Initial player join listener
function DataManager.Initialize()
    Players.PlayerAdded:Connect(loadData)
    Players.PlayerRemoving:Connect(function(player)
        saveData(player)
        sessionData[player] = nil
    end)
    
    -- Bind to close to save data when server shuts down
    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do
            saveData(player)
        end
    end)
end

-- Data Accessors
function DataManager.Get(player: Player): any?
    return sessionData[player]
end

-- Sets a top-level stat value
function DataManager.Set(player: Player, key: string, value: any)
    local data = sessionData[player]
    if not data then return end
    
    data[key] = value
    
    -- Sync primitive values to Player attributes
    if type(value) ~= "table" then
        player:SetAttribute(key, value)
    elseif key == "OwnedShooters" then
        for tier, count in pairs(value) do
            player:SetAttribute("Shooter_" .. tier, count)
        end
    end
    
    -- Keep leaderstats in sync if they match
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local valObj = leaderstats:FindFirstChild(key)
        if valObj and (valObj:IsA("IntValue") or valObj:IsA("NumberValue") or valObj:IsA("StringValue")) then
            (valObj :: any).Value = value
        end
    end
end

-- Updates a shooter owned count
function DataManager.AddShooter(player: Player, tier: string, count: number)
    local data = sessionData[player]
    if not data then return end
    
    if data.OwnedShooters and data.OwnedShooters[tier] ~= nil then
        local newCount = data.OwnedShooters[tier] + count
        data.OwnedShooters[tier] = newCount
        player:SetAttribute("Shooter_" .. tier, newCount)
    end
end

-- Appends a shooter position coordinate to the player profile
function DataManager.AddShooterPosition(player: Player, id: string, tier: string, relativePos: Vector3)
    local data = sessionData[player]
    if not data or not data.ShooterPositions then return end
    
    table.insert(data.ShooterPositions, {
        Id = id,
        Tier = tier,
        Pos = {relativePos.X, relativePos.Y, relativePos.Z}
    })
end

-- Updates an existing shooter's persistent coordinates
function DataManager.UpdateShooterPosition(player: Player, id: string, relativePos: Vector3)
    local data = sessionData[player]
    if not data or not data.ShooterPositions then return end
    
    for _, item in ipairs(data.ShooterPositions) do
        if item.Id == id then
            item.Pos = {relativePos.X, relativePos.Y, relativePos.Z}
            break
        end
    end
end

return DataManager

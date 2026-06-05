--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local ShooterManager = require(script.Parent:WaitForChild("ShooterManager"))

local ShopManager = {}

-- Buy upgrade handler
local function handleBuyUpgrade(player: Player, upgradeType: string, upgradeName: string): (boolean, string)
    local data = DataManager.Get(player)
    if not data then return false, "No player data found" end
    
    local currentCash = data.Cash or 0
    
    if upgradeType == "Shooter" then
        local currentOwned = data.OwnedShooters and data.OwnedShooters[upgradeName]
        if not currentOwned then return false, "Invalid shooter tier" end
        
        local cost = Config.GetShooterCost(upgradeName, currentOwned)
        if currentCash >= cost then
            local id = game:GetService("HttpService"):GenerateGUID(false)
            local existingCount = #data.ShooterPositions
            
            local offsetMultiplierX = (existingCount % 3) - 1
            local offsetMultiplierZ = math.floor(existingCount / 3)
            local relativePos = Vector3.new(
                offsetMultiplierX * 12,
                2.0,
                15 - (offsetMultiplierZ * 15)
            )
            
            DataManager.Set(player, "Cash", currentCash - cost)
            DataManager.AddShooter(player, upgradeName, 1)
            DataManager.AddShooterPosition(player, id, upgradeName, relativePos)
            
            -- Spawn only the new shooter dynamically (keeps others in place!)
            ShooterManager.SpawnSingleShooter(player, upgradeName, id, relativePos)
            return true, "Successfully bought " .. upgradeName
        else
            return false, "Not enough Cash!"
        end
        
    elseif upgradeType == "Hoop" then
        local currentLevel = data.HoopUpgradeLevel or 1
        local nextLevel = currentLevel + 1
        local nextHoopConfig = Config.Hoops[nextLevel]
        
        if not nextHoopConfig then
            return false, "Hoop is already at max level!"
        end
        
        local cost = nextHoopConfig.Cost
        if currentCash >= cost then
            DataManager.Set(player, "Cash", currentCash - cost)
            DataManager.Set(player, "HoopUpgradeLevel", nextLevel)
            return true, "Successfully upgraded hoop to " .. nextHoopConfig.Name
        else
            return false, "Not enough Cash!"
        end
    end
    
    return false, "Invalid upgrade type"
end

-- Rebirth handler
local function handleRebirthRequest(player: Player): (boolean, string)
    local data = DataManager.Get(player)
    if not data then return false, "No player data found" end
    
    local currentRebirths = data.Rebirths or 0
    local cost = Config.GetRebirthCost(currentRebirths)
    local currentCash = data.Cash or 0
    
    if currentCash >= cost then
        -- Perform Rebirth
        DataManager.Set(player, "Rebirths", currentRebirths + 1)
        DataManager.Set(player, "Cash", 0)
        DataManager.Set(player, "HoopUpgradeLevel", 1)
        
        -- Reset shooters
        local resetShooters = cloneTable(Config.StartingStats.OwnedShooters)
        DataManager.Set(player, "OwnedShooters", resetShooters)
        DataManager.Set(player, "ShooterPositions", {})
        
        -- Respawn shooters (which clears and resets to empty/rookie)
        ShooterManager.SpawnShootersForPlayer(player)
        
        return true, "Successfully rebirthed!"
    else
        return false, "Not enough Cash to rebirth!"
    end
end

-- Helper to clone tables safely
function cloneTable(t: any): any
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

function ShopManager.Initialize()
    task.spawn(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
        
        local buyUpgrade = remotes:WaitForChild("BuyUpgrade") :: RemoteFunction
        local rebirthRequest = remotes:WaitForChild("RebirthRequest") :: RemoteFunction
        
        buyUpgrade.OnServerInvoke = handleBuyUpgrade
        rebirthRequest.OnServerInvoke = handleRebirthRequest
    end)
    
    print("[Server] ShopManager Initialized!")
end

return ShopManager

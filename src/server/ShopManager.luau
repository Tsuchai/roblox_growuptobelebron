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
        -- Count existing from attributes so scaling cost works
        local currentOwned = player:GetAttribute("Shooter_" .. upgradeName) or 0
        if currentOwned == nil then return false, "Invalid shooter tier" end
        
        local cost = Config.GetShooterCost(upgradeName, currentOwned)
        if currentCash >= cost then
            local stats = Config.RollShooterStats(upgradeName)
            local id = game:GetService("HttpService"):GenerateGUID(false)
            
            local shooterData = {
                Id = id,
                Tier = upgradeName,
                Attribute = stats.Attribute,
                BaseYield = stats.BaseYield,
                Cooldown = stats.Cooldown
            }
            
            local existingCount = data.ShooterPositions and #data.ShooterPositions or 0
            
            local offsetMultiplierX = (existingCount % 3) - 1
            local offsetMultiplierZ = math.floor(existingCount / 3)
            local relativePos = Vector3.new(
                offsetMultiplierX * 12,
                2.0,
                15 - (offsetMultiplierZ * 15)
            )
            
            DataManager.Set(player, "Cash", currentCash - cost)
            DataManager.AddShooterToInventory(player, shooterData)

            if existingCount < (Config.MaxActiveShooters or 5) then
                DataManager.AddShooterPosition(player, id, upgradeName, relativePos)
                -- Spawn only the new shooter dynamically (keeps others in place!)
                ShooterManager.SpawnSingleShooter(player, upgradeName, id, relativePos)
                return true, "Successfully bought and equipped " .. upgradeName
            else
                return true, "Successfully bought " .. upgradeName .. " (Added to Inventory)"
            end
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
            -- Hoop multiplier changed — recalculate the accurate passive rate display
            ShooterManager.RecalculatePassiveRate(player)
            return true, "Successfully upgraded hoop to " .. nextHoopConfig.Name
        else
            return false, "Not enough Cash!"
        end
        
    elseif upgradeType == "PlayerUpgrade" then
        local currentLevel = data.PlayerUpgradeLevel or 1
        local nextCfg = Config.PlayerUpgrades[currentLevel + 1]

        if not nextCfg then
            return false, "Player upgrade already maxed!"
        end

        if currentCash >= nextCfg.Cost then
            DataManager.Set(player, "Cash", currentCash - nextCfg.Cost)
            DataManager.Set(player, "PlayerUpgradeLevel", currentLevel + 1)
            return true, "Upgraded to " .. nextCfg.Name
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
        DataManager.Set(player, "ShooterInventory", {})
        DataManager.Set(player, "ShooterPositions", {})
        
        -- Reset attributes for UI sync
        local orderedTiers = {"Rookie", "College", "Pro", "AllStar", "LeBron"}
        for _, tier in ipairs(orderedTiers) do
            player:SetAttribute("Shooter_" .. tier, 0)
        end
        
        -- Respawn shooters (which clears and resets to empty/rookie)
        ShooterManager.SpawnShootersForPlayer(player)

        -- Notify the client to reset milestone tracking for the new rebirth
        local remotes = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
        local rebirthNotify = remotes and remotes:FindFirstChild("RebirthNotify") :: RemoteEvent?
        if rebirthNotify then
            rebirthNotify:FireClient(player)
        end

        return true, "Successfully rebirthed!"
    else
        return false, "Not enough Cash to rebirth!"
    end
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

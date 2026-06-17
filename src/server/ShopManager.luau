--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")

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
        
        local existingInventoryCount = data.ShooterInventory and #data.ShooterInventory or 0
        if existingInventoryCount >= (Config.MaxInventorySize or 30) then
            return false, "Inventory is full! Merge, Trade, or delete players first."
        end
        
        local cost = Config.GetShooterCost(upgradeName, currentOwned)
        if currentCash >= cost then
            local stats = Config.RollShooterStats(upgradeName)
            local id = game:GetService("HttpService"):GenerateGUID(false)
            
            local shooterData = {
                Id = id,
                Tier = upgradeName,
                Attribute = stats.Attribute,
                BaseYield = stats.BaseYield,
                Cooldown = stats.Cooldown,
                Stars = stats.Stars or 1,
                XP = stats.XP or 0
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
        
    elseif upgradeType == "Roll" then
        local rollConfig = Config.Rolls[upgradeName]
        if not rollConfig then return false, "Invalid roll type" end
        
        if rollConfig.IsLimitedTime then
            local draftActive = ReplicatedStorage:FindFirstChild("DraftActive")
            if not draftActive or not draftActive.Value then
                return false, "This draft is not currently active!"
            end
        end
        
        local existingInventoryCount = data.ShooterInventory and #data.ShooterInventory or 0
        if existingInventoryCount >= (Config.MaxInventorySize or 30) then
            return false, "Inventory is full! Merge or delete players first."
        end
        
        local cost = rollConfig.Cost
        if currentCash >= cost then
            DataManager.Set(player, "Cash", currentCash - cost)
            
            -- Standard / Premium Roll Logic
            if upgradeName ~= "SpecialDraft" then
                local r = math.random()
                local cumulative = 0
                local rolledTier = "Rookie"
                for tier, chance in pairs(rollConfig.Chances) do
                    cumulative += chance
                    if r <= cumulative then
                        rolledTier = tier
                        break
                    end
                end
                
                local stats = Config.RollShooterStats(rolledTier)
                local id = HttpService:GenerateGUID(false)
                
                local shooterData = {
                    Id = id, Tier = rolledTier, Attribute = stats.Attribute,
                    BaseYield = stats.BaseYield, Cooldown = stats.Cooldown,
                    Stars = stats.Stars or 1, XP = stats.XP or 0
                }
                
                local existingCount = data.ShooterPositions and #data.ShooterPositions or 0
                DataManager.AddShooterToInventory(player, shooterData)
                
                if existingCount < (Config.MaxActiveShooters or 5) then
                    local offsetMultiplierX = (existingCount % 3) - 1
                    local offsetMultiplierZ = math.floor(existingCount / 3)
                    local relativePos = Vector3.new(offsetMultiplierX * 12, 2.0, 15 - (offsetMultiplierZ * 15))
                    DataManager.AddShooterPosition(player, id, rolledTier, relativePos)
                    ShooterManager.SpawnSingleShooter(player, rolledTier, id, relativePos)
                end
                
                return true, rolledTier
            else
                -- Special Draft Logic: Generates a 5-pick board
                local draftBoard = {}
                -- Make pick 1 highly likely to be amazing
                for i = 1, 5 do
                    local r = math.random()
                    local rolledTier = "Pro"
                    if i == 1 then
                        if r < 0.5 then rolledTier = "LeBron" else rolledTier = "AllStar" end
                    elseif i == 2 then
                        if r < 0.2 then rolledTier = "LeBron" elseif r < 0.6 then rolledTier = "AllStar" else rolledTier = "Pro" end
                    else
                        local cum = 0
                        for tier, chance in pairs(rollConfig.Chances) do
                            cum += chance
                            if r <= cum then rolledTier = tier; break end
                        end
                    end
                    
                    local stats = Config.RollShooterStats(rolledTier)
                    table.insert(draftBoard, {
                        Id = HttpService:GenerateGUID(false),
                        Tier = rolledTier, Attribute = stats.Attribute,
                        BaseYield = stats.BaseYield, Cooldown = stats.Cooldown,
                        Stars = stats.Stars or 1, XP = stats.XP or 0
                    })
                end
                
                -- Give the player a random starting pick (weighted towards worse picks, e.g., 3, 4, or 5)
                local pickRng = math.random()
                local userPick = 5
                if pickRng < 0.1 then userPick = 2 elseif pickRng < 0.3 then userPick = 3 elseif pickRng < 0.6 then userPick = 4 end
                
                -- Award their assigned pick
                DataManager.AddShooterToInventory(player, draftBoard[userPick])
                
                -- Save active draft state for Trade Ups
                DataManager.Set(player, "ActiveDraft", {
                    Board = draftBoard,
                    CurrentPick = userPick
                })
                
                -- Return complex object instead of string string
                return true, HttpService:JSONEncode({ Type = "DraftBoard", Board = draftBoard, UserPick = userPick })
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
    elseif upgradeType == "Merge" then
        local targetTier = upgradeName
        local orderedTiers = {"Rookie", "College", "Pro", "AllStar", "LeBron"}
        
        -- Find the next tier
        local nextTier = nil
        for i, tier in ipairs(orderedTiers) do
            if tier == targetTier and i < #orderedTiers then
                nextTier = orderedTiers[i + 1]
                break
            end
        end
        
        if not nextTier then return false, "Cannot merge " .. targetTier .. " any further!" end
        
        -- Find unequipped shooters of the target tier
        local unequippedIds = {}
        if data.ShooterInventory then
            -- Build a lookup of equipped IDs
            local equippedIds = {}
            if data.ShooterPositions then
                for _, posItem in ipairs(data.ShooterPositions) do
                    equippedIds[posItem.Id] = true
                end
            end
            
            for _, item in ipairs(data.ShooterInventory) do
                if item.Tier == targetTier and not equippedIds[item.Id] then
                    table.insert(unequippedIds, item.Id)
                end
            end
        end
        
        local requiredCount = Config.MergeRequiredCount or 3
        if #unequippedIds < requiredCount then
            return false, "Not enough unequipped " .. targetTier .. "s to merge! Need " .. requiredCount .. "."
        end
        
        -- Consume the required amount
        for i = 1, requiredCount do
            DataManager.RemoveShooterFromInventory(player, unequippedIds[i])
        end
        
        -- Grant the upgraded shooter
        local stats = Config.RollShooterStats(nextTier)
        local id = game:GetService("HttpService"):GenerateGUID(false)
        
        local shooterData = {
            Id = id,
            Tier = nextTier,
            Attribute = stats.Attribute,
            BaseYield = stats.BaseYield,
            Cooldown = stats.Cooldown,
            Stars = stats.Stars or 1,
            XP = stats.XP or 0
        }
        
        DataManager.AddShooterToInventory(player, shooterData)
        return true, "Successfully merged into 1 " .. Config.Shooters[nextTier].DisplayName .. "!"
        
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
    -- Handle Robux Purchases for the Draft "Trade Up"
    MarketplaceService.ProcessReceipt = function(receiptInfo)
        local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
        if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
        
        if receiptInfo.ProductId == Config.Monetization.TradeUpProductId then
            local data = DataManager.Get(player)
            if data and data.ActiveDraft then
                local draftState = data.ActiveDraft
                if draftState.CurrentPick > 1 then
                    -- Move up 1 slot
                    draftState.CurrentPick = draftState.CurrentPick - 1
                    local newPlayerAward = draftState.Board[draftState.CurrentPick]
                    
                    -- Award the new player
                    DataManager.AddShooterToInventory(player, newPlayerAward)
                    
                    -- Notify Client
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    local draftUpdateEvent = remotes and remotes:FindFirstChild("DraftUpdate")
                    if draftUpdateEvent then
                        draftUpdateEvent:FireClient(player, draftState.CurrentPick, newPlayerAward)
                    end
                    
                    return Enum.ProductPurchaseDecision.PurchaseGranted
                end
            end
        end
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    task.spawn(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
        
        -- Create the DraftUpdate remote event if it doesn't exist
        local draftUpdateEvent = Instance.new("RemoteEvent")
        draftUpdateEvent.Name = "DraftUpdate"
        draftUpdateEvent.Parent = remotes

        local buyUpgrade = remotes:WaitForChild("BuyUpgrade") :: RemoteFunction
        local rebirthRequest = remotes:WaitForChild("RebirthRequest") :: RemoteFunction
        
        buyUpgrade.OnServerInvoke = handleBuyUpgrade
        rebirthRequest.OnServerInvoke = handleRebirthRequest
    end)
    
    local draftActive = Instance.new("BoolValue")
    draftActive.Name = "DraftActive"
    draftActive.Value = false
    draftActive.Parent = ReplicatedStorage

    local draftTimeLeft = Instance.new("IntValue")
    draftTimeLeft.Name = "DraftTimeLeft"
    draftTimeLeft.Value = 300
    draftTimeLeft.Parent = ReplicatedStorage

    local DRAFT_INTERVAL = 300 -- 5 minutes
    local DRAFT_DURATION = 60  -- 1 minute

    task.spawn(function()
        while true do
            local currentEpoch = os.time()
            local timeWithinInterval = currentEpoch % DRAFT_INTERVAL
            
            if timeWithinInterval < DRAFT_DURATION then
                -- Active Window (e.g. 7:00:00 to 7:00:59)
                if not draftActive.Value then
                    draftActive.Value = true
                    print("[Event] Special Draft has started globally!")
                end
                draftTimeLeft.Value = DRAFT_DURATION - timeWithinInterval
            else
                -- Waiting Window (e.g. 7:01:00 to 7:04:59)
                if draftActive.Value then
                    draftActive.Value = false
                    print("[Event] Special Draft has ended.")
                end
                draftTimeLeft.Value = DRAFT_INTERVAL - timeWithinInterval
            end
            
            task.wait(1)
        end
    end)
    
    print("[Server] ShopManager Initialized!")
end

return ShopManager

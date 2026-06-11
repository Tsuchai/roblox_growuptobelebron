--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local PlotManager = require(script.Parent:WaitForChild("PlotManager"))

local NetworkManager = {}
local remotesFolder: Folder

-- Click cooldown cache
local lastShotTimes: { [Player]: number } = {}

-- Helper to safely create remotes on startup
local function setupRemotes()
    local existingFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if existingFolder then
        remotesFolder = existingFolder :: Folder
    else
        local newFolder = Instance.new("Folder")
        newFolder.Name = "Remotes"
        newFolder.Parent = ReplicatedStorage
        remotesFolder = newFolder
    end
    
    local function getOrCreateRemoteEvent(name: string): RemoteEvent
        local existingEvent = remotesFolder:FindFirstChild(name)
        if existingEvent then
            return existingEvent :: RemoteEvent
        end
        local newEvent = Instance.new("RemoteEvent")
        newEvent.Name = name
        newEvent.Parent = remotesFolder
        return newEvent
    end
    
    local function getOrCreateRemoteFunction(name: string): RemoteFunction
        local existingFunc = remotesFolder:FindFirstChild(name)
        if existingFunc then
            return existingFunc :: RemoteFunction
        end
        local newFunc = Instance.new("RemoteFunction")
        newFunc.Name = name
        newFunc.Parent = remotesFolder
        return newFunc
    end
    
    getOrCreateRemoteEvent("ShootRequest")
    getOrCreateRemoteEvent("MoveShooter")
    getOrCreateRemoteEvent("RenderShot")
    getOrCreateRemoteEvent("OfflineEarnings")
    getOrCreateRemoteEvent("RebirthNotify")
    getOrCreateRemoteFunction("BuyUpgrade")
    getOrCreateRemoteFunction("RebirthRequest")
    getOrCreateRemoteFunction("EquipShooter")
    getOrCreateRemoteFunction("UnequipShooter")
end

-- Active click shooting handler
local function handleShootRequest(player: Player)
    local now = os.clock()
    local lastTime = lastShotTimes[player] or 0
    if now - lastTime < Config.PlayerShot.Cooldown then
        return -- Clicked too fast (throttling/exploit protection)
    end
    lastShotTimes[player] = now
    
    -- Get player plot and character
    local plot = PlotManager.GetPlotForPlayer(player)
    local char = player.Character
    if not plot or not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hoop = plot:FindFirstChild("Hoop")
    local rim = hoop and hoop:FindFirstChild("Rim") :: BasePart?
    if not root or not rim then return end
    
    local origin = root.Position
    local target = rim.Position
    
    -- Calculate distance to hoop
    local distance = (origin - target).Magnitude
    
    -- Determine distance zone
    local shotStats = Config.GetShotStats(distance, nil)
    local accuracy = shotStats.Accuracy
    local multiplier = shotStats.Multiplier
    
    -- Roll for shot make/miss
    local isMake = math.random() <= accuracy
    
    if isMake then
        -- Retrieve stats
        local playerData = DataManager.Get(player)
        if not playerData then return end
        
        local hoopLevel = playerData.HoopUpgradeLevel or 1
        local hoopConfig = Config.Hoops[hoopLevel]
        local hoopMultiplier = hoopConfig and hoopConfig.Multiplier or 1
        
        local rebirths = playerData.Rebirths or 0
        local rebirthMultiplier = 1 + (rebirths * Config.Rebirth.MultiplierPerRebirth)
        
        -- Calculate cash earned
        -- Formula: (BaseYield + passiveRate * PassiveScaleFactor) * zoneMult * hoopMult * rebirthMult * upgradeMult
        local passiveRate = DataManager.GetPassiveRate(player)
        local passiveBonus = passiveRate * Config.PlayerShot.PassiveScaleFactor
        local upgradeLevel = playerData.PlayerUpgradeLevel or 1
        local upgradeCfg = Config.PlayerUpgrades[upgradeLevel]
        local upgradeMult = upgradeCfg and upgradeCfg.Multiplier or 1
        local cashEarned = math.floor(
            (Config.PlayerShot.BaseYield + passiveBonus) * multiplier * hoopMultiplier * rebirthMultiplier * upgradeMult
        )
        
        local currentCash = playerData.Cash or 0
        DataManager.Set(player, "Cash", currentCash + cashEarned)
    end
    
    -- Fire to all clients to render the shot trajectory and splash/rim bounce
    local renderEvent = remotesFolder:FindFirstChild("RenderShot") :: RemoteEvent
    if renderEvent then
        renderEvent:FireAllClients(player.UserId, origin, target, isMake)
    end
end

function NetworkManager.Initialize()
    setupRemotes()
    
    local shootRequest = remotesFolder:FindFirstChild("ShootRequest") :: RemoteEvent
    shootRequest.OnServerEvent:Connect(handleShootRequest)
    
    -- Setup cleanups
    Players.PlayerRemoving:Connect(function(player)
        lastShotTimes[player] = nil
    end)
    
    print("[Server] NetworkManager Initialized!")
end

return NetworkManager

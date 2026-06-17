--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ProfileStore = require(script.Parent:WaitForChild("ProfileStore"))

local DataManager = {}

-- ─── ProfileStore Setup ───────────────────────────────────────────────────────
-- Template mirrors Config.StartingStats so Reconcile() fills in any new fields
-- added in future updates without losing existing player data.
local PlayerStore = ProfileStore.New("GrowUpLeBron_v1", {
    Cash             = Config.StartingStats.Cash,
    Rebirths         = Config.StartingStats.Rebirths,
    HoopUpgradeLevel = Config.StartingStats.HoopUpgradeLevel,
    LogoutTime       = Config.StartingStats.LogoutTime,
    PlayerUpgradeLevel = 1,
    ShooterInventory = {}, -- { Id, Tier, Attribute, BaseYield, Cooldown }
    ShooterPositions = {}, -- { Id, Tier, Pos = {x, y, z} }
})

-- Active profile objects keyed by Player
local profiles: { [Player]: any } = {}

-- ─── Passive Rate Helper ──────────────────────────────────────────────────────
-- Calculates cash/sec a player passively earns from their shooters,
-- accounting for hoop multiplier and rebirth multiplier.
-- Used both for offline earnings and by NetworkManager for the manual shot bonus.
local function calculatePassiveRate(data: any): number
    local rate = 0
    if not data.ShooterPositions then return 0 end
    
    local rimRelativePos = Vector3.new(0, 2.5, -31)

    for _, item in ipairs(data.ShooterPositions) do
        local tier = item.Tier
        local posArray = item.Pos
        if tier and posArray and #posArray == 3 then
            local pos = Vector3.new(posArray[1], posArray[2], posArray[3])
            local distance = (pos - rimRelativePos).Magnitude
            local cfg = Config.Shooters[tier]
            if cfg then
                local shotStats = Config.GetShotStats(distance, cfg.Attribute)
                rate += (cfg.BaseYield * shotStats.Multiplier * shotStats.Accuracy) / cfg.Cooldown
            end
        end
    end

    local hoopLevel = data.HoopUpgradeLevel or 1
    local hoopCfg = Config.Hoops[hoopLevel]
    if hoopCfg then
        rate *= hoopCfg.Multiplier
    end

    local rebirths = data.Rebirths or 0
    rate *= (1 + Config.Rebirth.MultiplierPerRebirth * rebirths)

    return rate
end

-- ─── Attribute Sync ───────────────────────────────────────────────────────────
-- Syncs all persistent primitive values to Player attributes so the client
-- can read them without RemoteFunctions.
local function syncAllAttributes(player: Player, data: any)
    player:SetAttribute("Cash",               data.Cash or 0)
    player:SetAttribute("Rebirths",           data.Rebirths or 0)
    player:SetAttribute("HoopUpgradeLevel",   data.HoopUpgradeLevel or 1)
    player:SetAttribute("PlayerUpgradeLevel", data.PlayerUpgradeLevel or 1)
    
    local counts = { Rookie=0, College=0, Pro=0, AllStar=0, LeBron=0 }
    if data.ShooterInventory then
        for _, shooter in ipairs(data.ShooterInventory) do
            counts[shooter.Tier] = (counts[shooter.Tier] or 0) + 1
        end
    end
    for tier, count in pairs(counts) do
        player:SetAttribute("Shooter_" .. tier, count)
    end
end

-- ─── Leaderstats Setup ───────────────────────────────────────────────────────
local function setupLeaderstats(player: Player, data: any)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local cashVal = Instance.new("IntValue")
    cashVal.Name = "Cash"
    cashVal.Value = data.Cash or 0
    cashVal.Parent = leaderstats

    local rebirthsVal = Instance.new("IntValue")
    rebirthsVal.Name = "Rebirths"
    rebirthsVal.Value = data.Rebirths or 0
    rebirthsVal.Parent = leaderstats
end

-- ─── Player Join ─────────────────────────────────────────────────────────────
local function onPlayerAdded(player: Player)
    local profile = PlayerStore:StartSessionAsync(
        "Player_" .. player.UserId,
        {
            -- Cancel the load if the player has already left (race condition protection)
            Cancel = function()
                return player.Parent == nil
            end,
        }
    )

    if profile == nil then
        -- Session couldn't start (player left during load, or DataStore issue)
        player:Kick("Data failed to load. Please rejoin.")
        return
    end

    -- If the player left while the profile was loading, end the session immediately
    if player.Parent == nil then
        profile:EndSession()
        return
    end

    -- Fill in any missing keys introduced in newer versions of the game
    profile:Reconcile()

    -- Associate the UserId for GDPR compliance
    profile:AddUserId(player.UserId)

    -- If session is ended externally (server shutdown, session steal), kick the player
    -- so their data isn't silently lost.
    profile.OnSessionEnd:Connect(function()
        profiles[player] = nil
        player:Kick("Your session was ended. Please rejoin.")
    end)

    profiles[player] = profile
    local data = profile.Data

    -- ── Data Migration (Generic OwnedShooters -> Unique ShooterInventory) ──
    if data.OwnedShooters then
        data.ShooterInventory = data.ShooterInventory or {}
        
        -- First, migrate the ones already placed on the court (to preserve their IDs)
        if data.ShooterPositions then
            for _, item in ipairs(data.ShooterPositions) do
                local tier = item.Tier
                if data.OwnedShooters[tier] and data.OwnedShooters[tier] > 0 then
                    data.OwnedShooters[tier] = data.OwnedShooters[tier] - 1
                    local stats = Config.RollShooterStats(tier)
                    table.insert(data.ShooterInventory, {
                        Id = item.Id,
                        Tier = tier,
                        Attribute = stats.Attribute,
                        BaseYield = stats.BaseYield,
                        Cooldown = stats.Cooldown,
                        Stars = stats.Stars or 1,
                        XP = stats.XP or 0
                    })
                end
            end
        end
        
        -- Next, migrate any remaining owned shooters not on the court
        for tier, count in pairs(data.OwnedShooters) do
            for i = 1, count do
                local stats = Config.RollShooterStats(tier)
                local id = game:GetService("HttpService"):GenerateGUID(false)
                table.insert(data.ShooterInventory, {
                    Id = id,
                    Tier = tier,
                    Attribute = stats.Attribute,
                    BaseYield = stats.BaseYield,
                    Cooldown = stats.Cooldown,
                    Stars = stats.Stars or 1,
                    XP = stats.XP or 0
                })
            end
        end
        
        -- Remove old data structure so migration doesn't run again
        data.OwnedShooters = nil
    end

    -- ── Offline Earnings ──────────────────────────────────────────────────────
    local offlineCash = 0
    local timeAway = 0
    if data.LogoutTime and data.LogoutTime > 0 then
        timeAway = math.max(0, os.time() - data.LogoutTime)
        if timeAway > 5 then -- Lowered from 60 for easier testing
            local passiveRate = calculatePassiveRate(data)
            offlineCash = math.floor(passiveRate * timeAway)
            data.Cash += offlineCash
        end
    end
    data.LogoutTime = 0 -- Reset until next logout

    -- ── Sync to client ────────────────────────────────────────────────────────
    syncAllAttributes(player, data)
    setupLeaderstats(player, data)

    -- Fire offline earnings notification once the client UI is ready
    if offlineCash > 0 then
        task.spawn(function()
            local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
            local offlineEvent = remotes:WaitForChild("OfflineEarnings") :: RemoteEvent
            if not player.Character then
                player.CharacterAdded:Wait()
            end
            task.wait(2)
            offlineEvent:FireClient(player, offlineCash, timeAway)
        end)
    end
end

-- ─── Player Leave ─────────────────────────────────────────────────────────────
local function onPlayerRemoving(player: Player)
    local profile = profiles[player]
    if profile then
        -- Stamp logout time so offline earnings calculate correctly next session
        profile.Data.LogoutTime = os.time()
        profile:EndSession() -- ProfileStore handles the final save automatically
        profiles[player] = nil
    end
end

-- ─── Public API ───────────────────────────────────────────────────────────────

function DataManager.Initialize()
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    
    game:BindToClose(function()
        for player, profile in pairs(profiles) do
            if profile.Data then
                profile.Data.LogoutTime = os.time()
            end
        end
    end)
    
    -- Note: BindToClose is handled internally by ProfileStore (it saves all
    -- active profiles on shutdown automatically).
    print("[Server] DataManager Initialized (ProfileStore)")
end

-- Returns the raw data table for a player's active session, or nil if not loaded.
function DataManager.Get(player: Player): any?
    local profile = profiles[player]
    return profile and profile.Data or nil
end

-- Sets a top-level key in the player's data and syncs it to attributes/leaderstats.
function DataManager.Set(player: Player, key: string, value: any)
    local profile = profiles[player]
    if not profile then return end

    local data = profile.Data
    data[key] = value

    -- Sync primitive values to Player attributes
    if type(value) ~= "table" then
        player:SetAttribute(key, value)
    elseif key == "OwnedShooters" then
        for tier, count in pairs(value) do
            player:SetAttribute("Shooter_" .. tier, count)
        end
    end

    -- Keep leaderstats in sync
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local valObj = leaderstats:FindFirstChild(key)
        if valObj and (valObj:IsA("IntValue") or valObj:IsA("NumberValue") or valObj:IsA("StringValue")) then
            (valObj :: any).Value = value
        end
    end
end

-- Adds a newly rolled shooter to the player's inventory
function DataManager.AddShooterToInventory(player: Player, shooterData: any)
    local profile = profiles[player]
    if not profile then return end
    
    local data = profile.Data
    data.ShooterInventory = data.ShooterInventory or {}
    table.insert(data.ShooterInventory, shooterData)
    
    -- Update client count attribute
    local tier = shooterData.Tier
    local currentCount = player:GetAttribute("Shooter_" .. tier) or 0
    player:SetAttribute("Shooter_" .. tier, currentCount + 1)
end

-- Gets a specific shooter from the inventory by ID
function DataManager.GetShooterFromInventory(player: Player, id: string): any?
    local profile = profiles[player]
    if not profile then return nil end
    local data = profile.Data
    if not data.ShooterInventory then return nil end
    
    for _, item in ipairs(data.ShooterInventory) do
        if item.Id == id then
            return item
        end
    end
    return nil
end

-- Removes a specific shooter from the inventory by ID
function DataManager.RemoveShooterFromInventory(player: Player, id: string)
    local profile = profiles[player]
    if not profile then return false end
    local data = profile.Data
    if not data.ShooterInventory then return false end
    
    for i, item in ipairs(data.ShooterInventory) do
        if item.Id == id then
            local tier = item.Tier
            table.remove(data.ShooterInventory, i)
            
            -- Update client count attribute
            local currentCount = player:GetAttribute("Shooter_" .. tier) or 0
            if currentCount > 0 then
                player:SetAttribute("Shooter_" .. tier, currentCount - 1)
            end
            
            -- Also remove from active positions if they were somehow equipped
            DataManager.RemoveShooterPosition(player, id)
            return true
        end
    end
    return false
end

-- Appends a new shooter position entry to the player's ShooterPositions list.
function DataManager.AddShooterPosition(player: Player, id: string, tier: string, relativePos: Vector3)
    local profile = profiles[player]
    if not profile then return end
    local data = profile.Data
    if not data.ShooterPositions then return end
    table.insert(data.ShooterPositions, {
        Id   = id,
        Tier = tier,
        Pos  = { relativePos.X, relativePos.Y, relativePos.Z },
    })
end

-- Updates the stored position of an existing shooter by its Id.
function DataManager.UpdateShooterPosition(player: Player, id: string, relativePos: Vector3)
    local profile = profiles[player]
    if not profile then return end
    local data = profile.Data
    if not data.ShooterPositions then return end
    for _, item in ipairs(data.ShooterPositions) do
        if item.Id == id then
            item.Pos = { relativePos.X, relativePos.Y, relativePos.Z }
            break
        end
    end
end

-- Removes a shooter position entry from the player's ShooterPositions list by its Id.
function DataManager.RemoveShooterPosition(player: Player, id: string)
    local profile = profiles[player]
    if not profile then return end
    local data = profile.Data
    if not data.ShooterPositions then return end
    for i, item in ipairs(data.ShooterPositions) do
        if item.Id == id then
            table.remove(data.ShooterPositions, i)
            break
        end
    end
end

-- Returns the cash/sec a player passively earns (public wrapper for calculatePassiveRate).
-- Used by NetworkManager to factor passive income into the manual shot reward.
function DataManager.GetPassiveRate(player: Player): number
    local profile = profiles[player]
    if not profile then return 0 end
    return calculatePassiveRate(profile.Data)
end

return DataManager

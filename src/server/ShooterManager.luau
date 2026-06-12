--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local PlotManager = require(script.Parent:WaitForChild("PlotManager"))

local ShooterManager = {}
local activeShooterLoops: { [Instance]: thread } = {}

-- Visual styling colors for shooter jerseys
local JERSEY_COLORS = {
    Rookie = Color3.fromRGB(0, 150, 255),    -- Blue
    College = Color3.fromRGB(0, 200, 100),   -- Green
    Pro = Color3.fromRGB(255, 50, 50),       -- Red
    AllStar = Color3.fromRGB(180, 50, 255),   -- Purple
    LeBron = Color3.fromRGB(255, 215, 0)      -- Gold
}

-- Procedural generator for a blocky basketball shooter character
local function createShooterModel(tier: string, owner: Player, id: string): Model
    local shooter = Config.Shooters[tier]
    local displayName = shooter and shooter.DisplayName or "Shooter"
    
    local shooterData = DataManager.GetShooterFromInventory(owner, id)
    local attributeName = shooterData and shooterData.Attribute or "Slasher"
    
    local model = Instance.new("Model")
    model.Name = tier .. "_" .. owner.Name
    
    -- Root Part (Torso)
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 3, 1.2)
    torso.Color = JERSEY_COLORS[tier] or Color3.new(1, 1, 1)
    torso.Material = Enum.Material.SmoothPlastic
    torso.Anchored = true
    torso.CanCollide = true
    torso.Parent = model
    model.PrimaryPart = torso
    
    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.2, 1.2, 1.2)
    head.Shape = Enum.PartType.Ball
    head.Color = Color3.fromRGB(224, 172, 105) -- Peach skin tone
    head.Material = Enum.Material.SmoothPlastic
    head.Position = torso.Position + Vector3.new(0, 2.1, 0)
    head.Anchored = false
    head.CanCollide = false
    head.Parent = model
    
    local weldHead = Instance.new("WeldConstraint")
    weldHead.Part0 = torso
    weldHead.Part1 = head
    weldHead.Parent = torso
    
    -- Face Decal (happy face)
    local face = Instance.new("Decal")
    face.Texture = "rbxassetid://16125749110" -- Standard Roblox smile template
    face.Face = Enum.NormalId.Front
    face.Parent = head

    -- Visual hair or headband (simple band)
    local headband = Instance.new("Part")
    headband.Name = "Headband"
    headband.Size = Vector3.new(1.3, 0.3, 1.3)
    headband.Color = Color3.fromRGB(255, 255, 255)
    headband.Position = head.Position + Vector3.new(0, 0.4, 0)
    headband.Anchored = false
    headband.CanCollide = false
    headband.Parent = model
    
    local weldBand = Instance.new("WeldConstraint")
    weldBand.Part0 = head
    weldBand.Part1 = headband
    weldBand.Parent = head
    
    -- Humanoid (provides name tag and standard physics state)
    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
    humanoid.Parent = model
    
    -- Customize Name Tag
    model.Name = displayName .. "\n(" .. attributeName .. ")"
    
    -- Tag model with attributes to identify it on the client
    model:SetAttribute("ShooterTier", tier)
    model:SetAttribute("OwnerUserId", owner.UserId)
    model:SetAttribute("ShooterId", id)
    
    return model
end

-- Calculation helper for a shooter's make-chance and cash payout
local function calculateShot(player: Player, shooterModel: Model): (boolean, number, string, number)
    local tier = shooterModel:GetAttribute("ShooterTier") :: string
    local plot = PlotManager.GetPlotForPlayer(player)
    local root = shooterModel.PrimaryPart
    if not plot or not root or not tier then return false, 0, "Paint", 0.5 end
    
    local hoop = plot:FindFirstChild("Hoop")
    local rim = hoop and hoop:FindFirstChild("Rim") :: BasePart?
    if not rim then return false, 0, "Paint", 0.5 end
    
    -- Calculate distance to hoop
    local distance = (root.Position - rim.Position).Magnitude
    
    local id = shooterModel:GetAttribute("ShooterId") :: string
    local shooterData = DataManager.GetShooterFromInventory(player, id)
    local attrName = shooterData and shooterData.Attribute or "Slasher"
    
    local shotStats = Config.GetShotStats(distance, attrName)
    local finalAccuracy = shotStats.Accuracy
    local finalMultiplier = shotStats.Multiplier
    local zoneName = shotStats.Name
    
    -- Roll make/miss
    local isMake = math.random() <= finalAccuracy
    
    -- Calculate Cash
    local yield = 0
    if isMake then
        local playerData = DataManager.Get(player)
        if playerData then
            local baseYield = shooterData and shooterData.BaseYield or (Config.Shooters[tier] and Config.Shooters[tier].BaseYield or 0)
            local hoopLevel = playerData.HoopUpgradeLevel or 1
            local hoopMultiplier = Config.Hoops[hoopLevel] and Config.Hoops[hoopLevel].Multiplier or 1
            local rebirths = playerData.Rebirths or 0
            local rebirthMultiplier = 1 + (rebirths * Config.Rebirth.MultiplierPerRebirth)
            
            yield = math.floor(baseYield * finalMultiplier * hoopMultiplier * rebirthMultiplier)
        end
    end
    
    return isMake, yield, zoneName, finalAccuracy
end

-- The autonomous firing loop for an individual shooter model
local function startShootingLoop(player: Player, shooterModel: Model)
    local id = shooterModel:GetAttribute("ShooterId") :: string
    local shooterData = DataManager.GetShooterFromInventory(player, id)
    local cooldown = shooterData and shooterData.Cooldown or 5
    
    local thread = task.spawn(function()
        while shooterModel.Parent ~= nil do
            task.wait(cooldown)
            
            -- Skip shooting cycle if currently being placed by player
            if shooterModel:GetAttribute("IsPlacing") == true then
                continue
            end
            
            local plot = PlotManager.GetPlotForPlayer(player)
            if not plot then break end
            
            local root = shooterModel.PrimaryPart
            local hoop = plot:FindFirstChild("Hoop")
            local rim = hoop and hoop:FindFirstChild("Rim") :: BasePart?
            
            if root and rim then
                -- Perform math check
                local isMake, cashEarned, zoneName, accuracy = calculateShot(player, shooterModel)
                
                -- Visual jump shoot animation (simple server-side jump)
                task.spawn(function()
                    local originalCFrame = root.CFrame
                    for i = 1, 5 do
                        root.CFrame = originalCFrame + Vector3.new(0, i * 0.4, 0)
                        task.wait(0.05)
                    end
                    for i = 5, 0, -1 do
                        root.CFrame = originalCFrame + Vector3.new(0, i * 0.4, 0)
                        task.wait(0.05)
                    end
                    root.CFrame = originalCFrame
                end)
                
                -- Replicate projectile shot
                local remotes = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
                local renderEvent = remotes and remotes:FindFirstChild("RenderShot") :: RemoteEvent?
                if renderEvent then
                    renderEvent:FireAllClients(shooterModel.Name, root.Position + Vector3.new(0, 2.5, 0), rim.Position, isMake)
                end
                
                -- Add payout
                if isMake and cashEarned > 0 then
                    local data = DataManager.Get(player)
                    if data then
                        DataManager.Set(player, "Cash", (data.Cash or 0) + cashEarned)
                    end
                end
            end
        end
    end)
    
    activeShooterLoops[shooterModel] = thread
end

-- Spawns all owned shooters for a player onto their plot
function ShooterManager.SpawnShootersForPlayer(player: Player)
    local plot = PlotManager.GetPlotForPlayer(player)
    local data = DataManager.Get(player)
    if not plot or not data then return end
    
    local shootersFolder = plot:FindFirstChild("Shooters") :: Folder
    if not shootersFolder then return end
    
    -- Clear any existing shooter models first
    shootersFolder:ClearAllChildren()
    
    local plotCenter = plot:GetAttribute("CenterPosition") :: Vector3
    
    -- Backwards Compatibility & Data Migration
    local positions = data.ShooterPositions
    if not positions or #positions == 0 then
        positions = {}
        local count = 0
        for tier, amt in pairs(data.OwnedShooters or {}) do
            for i = 1, amt do
                local id = game:GetService("HttpService"):GenerateGUID(false)
                local offsetMultiplierX = (count % 3) - 1
                local offsetMultiplierZ = math.floor(count / 3)
                local relativePos = Vector3.new(
                    offsetMultiplierX * 12,
                    2.0,
                    15 - (offsetMultiplierZ * 15)
                )
                table.insert(positions, {
                    Id = id,
                    Tier = tier,
                    Pos = {relativePos.X, relativePos.Y, relativePos.Z}
                })
                count = count + 1
            end
        end
        DataManager.Set(player, "ShooterPositions", positions)
    end
    
    -- Spawn each shooter at its specific saved relative position
    for _, item in ipairs(positions) do
        local id = item.Id
        local tier = item.Tier
        local posData = item.Pos
        local relativePos = Vector3.new(posData[1], posData[2], posData[3])
        local spawnPos = plotCenter + relativePos
        
        local model = createShooterModel(tier, player, id)
        model:PivotTo(CFrame.new(spawnPos, plotCenter + Vector3.new(0, 2.5, -31))) -- Face the hoop
        model.Parent = shootersFolder
        
        startShootingLoop(player, model)
    end

    -- Recalculate the displayed passive rate now that all shooters are in place
    ShooterManager.RecalculatePassiveRate(player)
end

-- Spawns a single shooter dynamically (e.g. when bought) to avoid resetting others
function ShooterManager.SpawnSingleShooter(player: Player, tier: string, id: string, relativePos: Vector3)
    local plot = PlotManager.GetPlotForPlayer(player)
    if not plot then return end
    
    local shootersFolder = plot:FindFirstChild("Shooters") :: Folder
    if not shootersFolder then return end
    
    local plotCenter = plot:GetAttribute("CenterPosition") :: Vector3
    local spawnPos = plotCenter + relativePos
    
    local model = createShooterModel(tier, player, id)
    model:PivotTo(CFrame.new(spawnPos, plotCenter + Vector3.new(0, 2.5, -31)))
    model.Parent = shootersFolder
    
    startShootingLoop(player, model)
    print("Spawned new " .. tier .. " with ID " .. id .. " for " .. player.Name)

    -- Recalculate passive rate to reflect the new shooter
    ShooterManager.RecalculatePassiveRate(player)
end

-- Server listener for moving shooters
local function handleMoveShooter(player: Player, shooterModel: Model, commandOrPosition: any)
    local plot = PlotManager.GetPlotForPlayer(player)
    if not plot or not shooterModel or not shooterModel:IsDescendantOf(plot) then
        return -- Safety check: only let player move their own shooters
    end
    
    if type(commandOrPosition) == "string" then
        if commandOrPosition == "Start" then
            shooterModel:SetAttribute("IsPlacing", true)
        elseif commandOrPosition == "Cancel" then
            shooterModel:SetAttribute("IsPlacing", false)
        end
        return
    end
    
    if typeof(commandOrPosition) == "Vector3" then
        local root = shooterModel.PrimaryPart
        if not root then return end
        
        shooterModel:SetAttribute("IsPlacing", false)
        
        -- Bounds check: Make sure position is within court boundaries
        local plotCenter = plot:GetAttribute("CenterPosition") :: Vector3
        local relativePos = commandOrPosition - plotCenter
        
        -- Limit coordinates to the size of the court (40 wide, 60 long) with margin
        local clampedX = math.clamp(relativePos.X, -18, 18)
        local clampedZ = math.clamp(relativePos.Z, -33, 23)
        
        local finalPos = plotCenter + Vector3.new(clampedX, 2.5, clampedZ)
        
        -- Save coordinates back to persistent DataStore profile
        local id = shooterModel:GetAttribute("ShooterId")
        if id then
            DataManager.UpdateShooterPosition(player, id, Vector3.new(clampedX, 2.5, clampedZ))
        end
        
        -- Orient towards the hoop
        local hoop = plot:FindFirstChild("Hoop")
        local rim = hoop and hoop:FindFirstChild("Rim") :: BasePart?
        local lookTarget = rim and rim.Position or (plotCenter + Vector3.new(0, 2.5, -31))
        
        root.CFrame = CFrame.new(finalPos, Vector3.new(lookTarget.X, finalPos.Y, lookTarget.Z))

        -- Zone may have changed after moving — recalculate the accurate passive rate
        ShooterManager.RecalculatePassiveRate(player)
    end
end

-- Calculates each shooter's expected cash/sec based on its actual zone, attribute bonus,
-- hoop multiplier, and rebirth multiplier, then syncs the total to the PassiveRate
-- player attribute for the client HUD and active bonus label.
function ShooterManager.RecalculatePassiveRate(player: Player)
    local plot = PlotManager.GetPlotForPlayer(player)
    local data = DataManager.Get(player)
    if not plot or not data then
        player:SetAttribute("PassiveRate", 0)
        return
    end

    local shootersFolder = plot:FindFirstChild("Shooters") :: Folder?
    local hoop = plot:FindFirstChild("Hoop")
    local rim = hoop and hoop:FindFirstChild("Rim") :: BasePart?
    if not shootersFolder or not rim then
        player:SetAttribute("PassiveRate", 0)
        return
    end

    local totalRate = 0

    for _, shooterModel in ipairs(shootersFolder:GetChildren()) do
        if not shooterModel:IsA("Model") then continue end
        local tier = shooterModel:GetAttribute("ShooterTier") :: string?
        if not tier then continue end

        local id = shooterModel:GetAttribute("ShooterId") :: string?
        if not id then continue end
        local shooterData = DataManager.GetShooterFromInventory(player, id)
        if not shooterData then continue end

        local root = shooterModel.PrimaryPart
        if not root then continue end

        local distance = (root.Position - rim.Position).Magnitude
        local shotStats = Config.GetShotStats(distance, shooterData.Attribute)
        
        -- Expected cash/sec = (BaseYield × zoneMult × accuracy) / cooldown
        totalRate += (shooterData.BaseYield * shotStats.Multiplier * shotStats.Accuracy) / shooterData.Cooldown
    end

    -- Apply hoop multiplier
    local hoopLevel = data.HoopUpgradeLevel or 1
    local hoopCfg = Config.Hoops[hoopLevel]
    if hoopCfg then totalRate *= hoopCfg.Multiplier end

    -- Apply rebirth multiplier
    local rebirths = data.Rebirths or 0
    totalRate *= (1 + Config.Rebirth.MultiplierPerRebirth * rebirths)

    player:SetAttribute("PassiveRate", totalRate)
end

-- Equips a shooter from inventory by its unique ID
local function handleEquipShooter(player: Player, id: string): (boolean, string)
    local data = DataManager.Get(player)
    if not data then return false, "No player data" end
    
    local maxActive = Config.MaxActiveShooters or 5
    if #data.ShooterPositions >= maxActive then
        return false, "Court is full! Max " .. maxActive .. " shooters."
    end
    
    local shooterData = nil
    if data.ShooterInventory then
        for _, item in ipairs(data.ShooterInventory) do
            if item.Id == id then
                shooterData = item
                break
            end
        end
    end
    
    if not shooterData then
        return false, "Shooter not found in your inventory!"
    end
    
    for _, posItem in ipairs(data.ShooterPositions) do
        if posItem.Id == id then
            return false, "This shooter is already on the court!"
        end
    end
    
    local existingCount = #data.ShooterPositions
    local tier = shooterData.Tier
    
    local offsetMultiplierX = (existingCount % 3) - 1
    local offsetMultiplierZ = math.floor(existingCount / 3)
    local relativePos = Vector3.new(
        offsetMultiplierX * 12,
        2.0,
        15 - (offsetMultiplierZ * 15)
    )
    
    DataManager.AddShooterPosition(player, id, tier, relativePos)
    ShooterManager.SpawnSingleShooter(player, tier, id, relativePos)
    
    return true, "Equipped " .. tier
end

local function handleUnequipShooter(player: Player, id: string): (boolean, string)
    local data = DataManager.Get(player)
    if not data then return false, "No player data" end
    
    local foundTier = nil
    for _, item in ipairs(data.ShooterPositions) do
        if item.Id == id then
            foundTier = item.Tier
            break
        end
    end
    
    if not foundTier then
        return false, "Shooter not found on court."
    end
    
    DataManager.RemoveShooterPosition(player, id)
    
    local plot = PlotManager.GetPlotForPlayer(player)
    if plot then
        local shootersFolder = plot:FindFirstChild("Shooters") :: Folder
        if shootersFolder then
            for _, child in ipairs(shootersFolder:GetChildren()) do
                if child:GetAttribute("ShooterId") == id then
                    if activeShooterLoops[child] then
                        task.cancel(activeShooterLoops[child])
                        activeShooterLoops[child] = nil
                    end
                    child:Destroy()
                    break
                end
            end
        end
    end
    
    ShooterManager.RecalculatePassiveRate(player)
    
    return true, "Unequipped shooter."
end

function ShooterManager.Initialize()
    -- Connect MoveShooter remote event
    task.spawn(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
        local moveEvent = remotes:WaitForChild("MoveShooter") :: RemoteEvent
        local equipFunc = remotes:WaitForChild("EquipShooter") :: RemoteFunction
        local unequipFunc = remotes:WaitForChild("UnequipShooter") :: RemoteFunction
        
        moveEvent.OnServerEvent:Connect(function(player, shooterModel, commandOrPosition)
            if typeof(shooterModel) == "Instance" and shooterModel:IsA("Model") then
                handleMoveShooter(player, shooterModel, commandOrPosition)
            end
        end)
        
        equipFunc.OnServerInvoke = handleEquipShooter
        unequipFunc.OnServerInvoke = handleUnequipShooter
    end)
    
    -- Automatically spawn shooters when data loads
    Players.PlayerAdded:Connect(function(player)
        -- Wait for player data to load
        while player.Parent and not DataManager.Get(player) do
            task.wait(0.1)
        end
        if player.Parent then
            ShooterManager.SpawnShootersForPlayer(player)
        end
    end)
    
    -- Cleanup routines
    Players.PlayerRemoving:Connect(function(player)
        for model, _ in pairs(activeShooterLoops) do
            if model:GetAttribute("OwnerUserId") == player.UserId then
                if activeShooterLoops[model] then
                    task.cancel(activeShooterLoops[model])
                    activeShooterLoops[model] = nil
                end
            end
        end
    end)
    
    print("[Server] ShooterManager Initialized!")
end

return ShooterManager

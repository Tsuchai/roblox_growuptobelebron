--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PlotManager = {}
local plotsFolder: Folder
local plots: { [number]: Folder } = {}
local playerAssignments: { [Player]: Folder } = {}

-- Define the layout of a plot relative to its center coordinate
local PLOT_SIZE = Vector3.new(60, 0.5, 80)
local PLOT_SPACING = 80
local PLOT_Y_OFFSET = 0.5

-- Visual properties for colors (basketball themed)
local COURT_COLOR = Color3.fromRGB(211, 109, 57) -- basketball orange
local FLOOR_COLOR = Color3.fromRGB(45, 45, 48) -- dark background
local BORDER_COLOR = Color3.fromRGB(230, 230, 230) -- white court lines

-- Procedural helper to build a basketball hoop on the plot
local function buildHoop(plotFolder: Folder, center: Vector3)
    local hoopModel = Instance.new("Model")
    hoopModel.Name = "Hoop"
    hoopModel.Parent = plotFolder
    
    -- 1. Support Pole
    local pole = Instance.new("Part")
    pole.Name = "Pole"
    pole.Size = Vector3.new(1.5, 15, 1.5)
    pole.Position = center + Vector3.new(0, 7.5, -35)
    pole.Material = Enum.Material.Metal
    pole.Color = Color3.fromRGB(100, 100, 100)
    pole.Anchored = true
    pole.CanCollide = true
    pole.Parent = hoopModel
    
    -- 2. Backboard
    local backboard = Instance.new("Part")
    backboard.Name = "Backboard"
    backboard.Size = Vector3.new(12, 8, 0.5)
    backboard.Position = center + Vector3.new(0, 14, -34)
    backboard.Material = Enum.Material.Glass
    backboard.Color = Color3.fromRGB(240, 240, 240)
    backboard.Transparency = 0.3
    backboard.Anchored = true
    backboard.CanCollide = true
    backboard.Parent = hoopModel
    
    -- Backboard Outline (visual)
    local outline = Instance.new("Part")
    outline.Name = "Outline"
    outline.Size = Vector3.new(12.4, 0.5, 0.7)
    outline.Position = center + Vector3.new(0, 18, -34)
    outline.Material = Enum.Material.SmoothPlastic
    outline.Color = Color3.fromRGB(255, 0, 0)
    outline.Anchored = true
    outline.CanCollide = false
    outline.Parent = hoopModel
    
    -- 3. Rim (Target for shots)
    local rim = Instance.new("Part")
    rim.Name = "Rim"
    rim.Size = Vector3.new(4, 0.4, 4)
    rim.Position = center + Vector3.new(0, 11, -31)
    rim.Shape = Enum.PartType.Cylinder
    rim.Rotation = Vector3.new(90, 0, 0)
    rim.Material = Enum.Material.Metal
    rim.Color = Color3.fromRGB(255, 100, 0) -- Orange rim
    rim.Anchored = true
    rim.CanCollide = false
    rim.Parent = hoopModel
    
    -- Store the hoop's scoring coordinates explicitly on the model for easy access
    local scoringZone = Instance.new("Part")
    scoringZone.Name = "ScoringZone"
    scoringZone.Size = Vector3.new(3, 1, 3)
    scoringZone.Position = rim.Position
    scoringZone.Transparency = 1
    scoringZone.Anchored = true
    scoringZone.CanCollide = false
    scoringZone.Parent = hoopModel
end

-- Procedural helper to build a basketball court
local function createPhysicalPlot(index: number, center: Vector3): Folder
    local plotFolder = Instance.new("Folder")
    plotFolder.Name = "Plot" .. index
    plotFolder.Parent = plotsFolder
    
    -- Base Floor
    local floor = Instance.new("Part")
    floor.Name = "Floor"
    floor.Size = PLOT_SIZE
    floor.Position = center + Vector3.new(0, PLOT_Y_OFFSET / 2, 0)
    floor.Color = FLOOR_COLOR
    floor.Material = Enum.Material.SmoothPlastic
    floor.Anchored = true
    floor.CanCollide = true
    floor.Parent = plotFolder
    
    -- Main Basketball Court area
    local court = Instance.new("Part")
    court.Name = "Court"
    court.Size = Vector3.new(40, 0.1, 60)
    court.Position = center + Vector3.new(0, PLOT_Y_OFFSET + 0.05, -5)
    court.Color = COURT_COLOR
    court.Material = Enum.Material.Wood
    court.Anchored = true
    court.CanCollide = true
    court.Parent = plotFolder
    
    -- Paint Zone Visual (15 studs from rim)
    local paintVisual = Instance.new("Part")
    paintVisual.Name = "PaintVisual"
    paintVisual.Size = Vector3.new(16, 0.05, 16.7)
    paintVisual.Position = center + Vector3.new(0, PLOT_Y_OFFSET + 0.1, -26.65)
    paintVisual.Color = Color3.fromRGB(180, 50, 50) -- Dark red
    paintVisual.Material = Enum.Material.Wood
    paintVisual.Anchored = true
    paintVisual.CanCollide = false
    paintVisual.CanQuery = false
    paintVisual.Parent = plotFolder
    
    -- 3-Point Line Visual (30 studs from rim)
    local threePtLine = Instance.new("Part")
    threePtLine.Name = "ThreePointLine"
    threePtLine.Size = Vector3.new(40.2, 0.06, 0.5)
    threePtLine.Position = center + Vector3.new(0, PLOT_Y_OFFSET + 0.11, -2.1)
    threePtLine.Color = BORDER_COLOR
    threePtLine.Material = Enum.Material.SmoothPlastic
    threePtLine.Anchored = true
    threePtLine.CanCollide = false
    threePtLine.CanQuery = false
    threePtLine.Parent = plotFolder
    
    -- Spawner for the player
    local spawnLocation = Instance.new("SpawnLocation")
    spawnLocation.Name = "Spawn"
    spawnLocation.Size = Vector3.new(6, 1, 6)
    spawnLocation.Position = center + Vector3.new(0, PLOT_Y_OFFSET + 0.5, 30)
    spawnLocation.Color = Color3.fromRGB(0, 255, 100)
    spawnLocation.Material = Enum.Material.Neon
    spawnLocation.Anchored = true
    spawnLocation.CanCollide = true
    spawnLocation.Duration = 0
    spawnLocation.Enabled = false -- Managed manually by script
    spawnLocation.Parent = plotFolder
    
    -- Owner Sign Billboard
    local signPost = Instance.new("Part")
    signPost.Name = "SignPost"
    signPost.Size = Vector3.new(1, 6, 1)
    signPost.Position = center + Vector3.new(-25, 3, 35)
    signPost.Color = Color3.fromRGB(80, 80, 80)
    signPost.Anchored = true
    signPost.CanCollide = true
    signPost.Parent = plotFolder
    
    local signBoard = Instance.new("Part")
    signBoard.Name = "SignBoard"
    signBoard.Size = Vector3.new(6, 3, 0.5)
    signBoard.Position = center + Vector3.new(-25, 6, 35)
    signBoard.Color = Color3.fromRGB(50, 50, 50)
    signBoard.Anchored = true
    signBoard.CanCollide = true
    signBoard.Parent = plotFolder
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(1, 0, 1, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = signBoard
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextScaled = true
    textLabel.Text = "Unclaimed Plot"
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Parent = billboardGui
    
    -- Build the basket hoop
    buildHoop(plotFolder, center)
    
    -- Folder to keep hired shooters
    local shootersFolder = Instance.new("Folder")
    shootersFolder.Name = "Shooters"
    shootersFolder.Parent = plotFolder
    
    -- Custom Attributes to track state
    plotFolder:SetAttribute("OwnerId", 0) -- 0 means unclaimed
    plotFolder:SetAttribute("Index", index)
    plotFolder:SetAttribute("CenterPosition", center)
    
    return plotFolder
end

-- Initialize plot system on server start
function PlotManager.Initialize()
    plotsFolder = Instance.new("Folder")
    plotsFolder.Name = "Plots"
    plotsFolder.Parent = Workspace
    
    -- Create 4 plots in a row
    for i = 1, 4 do
        local xPos = (i - 2.5) * PLOT_SPACING -- Centers the plots nicely
        local center = Vector3.new(xPos, 0, 0)
        plots[i] = createPhysicalPlot(i, center)
    end
    
    -- Listen to player events
    Players.PlayerAdded:Connect(function(player)
        PlotManager.ClaimPlot(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        PlotManager.ReleasePlot(player)
    end)
end

-- Assigns an empty plot to a player
function PlotManager.ClaimPlot(player: Player): Folder?
    -- Check if player already has a plot
    if playerAssignments[player] then
        return playerAssignments[player]
    end
    
    -- Find unclaimed plot
    for i = 1, #plots do
        local plot = plots[i]
        if plot:GetAttribute("OwnerId") == 0 then
            plot:SetAttribute("OwnerId", player.UserId)
            playerAssignments[player] = plot
            
            -- Update Sign Board Text
            local signPost = plot:FindFirstChild("SignBoard")
            if signPost then
                local billboard = signPost:FindFirstChildOfClass("BillboardGui")
                local label = billboard and billboard:FindFirstChildOfClass("TextLabel")
                if label then
                    label.Text = player.Name .. "'s Court"
                    label.TextColor3 = Color3.fromRGB(0, 255, 100)
                end
            end
            
            -- Teleport player character when it spawns
            player.CharacterAdded:Connect(function(char)
                local root = char:WaitForChild("HumanoidRootPart") :: BasePart
                local spawnPart = plot:FindFirstChild("Spawn") :: BasePart
                if root and spawnPart then
                    task.wait(0.1) -- yield slightly to prevent physics glitch
                    root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
                end
            end)
            
            -- If character already exists (e.g. joined late), teleport immediately
            if player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
                local spawnPart = plot:FindFirstChild("Spawn") :: BasePart
                if root and spawnPart then
                    root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
                end
            end
            
            print(player.Name .. " claimed Plot " .. i)
            return plot
        end
    end
    
    warn("No available plots for player: " .. player.Name)
    return nil
end

-- Releases a plot and resets its visuals
function PlotManager.ReleasePlot(player: Player)
    local plot = playerAssignments[player]
    if not plot then return end
    
    plot:SetAttribute("OwnerId", 0)
    playerAssignments[player] = nil
    
    -- Reset Sign Board Text
    local signPost = plot:FindFirstChild("SignBoard")
    if signPost then
        local billboard = signPost:FindFirstChildOfClass("BillboardGui")
        local label = billboard and billboard:FindFirstChildOfClass("TextLabel")
        if label then
            label.Text = "Unclaimed Plot"
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
    
    -- Clear shooters
    local shootersFolder = plot:FindFirstChild("Shooters")
    if shootersFolder then
        shootersFolder:ClearAllChildren()
    end
    
    print("Plot " .. plot:GetAttribute("Index") .. " released by " .. player.Name)
end

-- Getter functions
function PlotManager.GetPlotForPlayer(player: Player): Folder?
    return playerAssignments[player]
end

return PlotManager

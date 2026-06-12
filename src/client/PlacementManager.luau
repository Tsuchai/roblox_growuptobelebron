--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlacementManager = {}
local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- State variables
local selectedShooter: Model? = nil
local originalCFrame: CFrame? = nil
local isPlacing = false
local placementConnection: RBXScriptConnection? = nil
local moveEvent: RemoteEvent

-- Helper: Raycast from mouse to the 3D world
local function getMouseTarget(): (Vector3?, BasePart?)
    local mousePos = UserInputService:GetMouseLocation()
    local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    -- Exclude player character and selected shooter from blockages
    local filterList = {localPlayer.Character}
    if selectedShooter then
        table.insert(filterList, selectedShooter)
    end
    raycastParams.FilterDescendantsInstances = filterList
    
    local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 200, raycastParams)
    if result then
        return result.Position, result.Instance :: BasePart
    end
    return nil, nil
end

-- Stop placement and reset positions
function PlacementManager.CancelPlacement()
    if not selectedShooter or not isPlacing then return end
    
    isPlacing = false
    if placementConnection then
        placementConnection:Disconnect()
        placementConnection = nil
    end
    
    -- Tell server we cancelled
    moveEvent:FireServer(selectedShooter, "Cancel")
    
    -- Reset to original position
    local root = selectedShooter.PrimaryPart
    if root and originalCFrame then
        root.CFrame = originalCFrame
        -- Make it solid again
        for _, child in ipairs(selectedShooter:GetChildren()) do
            if child:IsA("BasePart") then
                child.Transparency = (child.Name == "Headband" or child.Name == "Torso") and 0 or child.Transparency
            end
        end
    end
    
    -- Remove status text
    local post = selectedShooter:FindFirstChild("PlacementSign")
    if post then post:Destroy() end
    
    selectedShooter = nil
    originalCFrame = nil
    print("[Placement] Placement cancelled.")
end

-- Confirm placement and send to server
local function confirmPlacement(position: Vector3)
    if not selectedShooter or not isPlacing then return end
    
    isPlacing = false
    if placementConnection then
        placementConnection:Disconnect()
        placementConnection = nil
    end
    
    -- Send position request to server
    moveEvent:FireServer(selectedShooter, position)
    
    -- Remove status text
    local post = selectedShooter:FindFirstChild("PlacementSign")
    if post then post:Destroy() end
    
    -- Restore transparency
    for _, child in ipairs(selectedShooter:GetChildren()) do
        if child:IsA("BasePart") then
            child.Transparency = (child.Name == "Headband" or child.Name == "Torso") and 0 or child.Transparency
        end
    end
    
    selectedShooter = nil
    originalCFrame = nil
    print("[Placement] Placement confirmed.")
end

-- Start placement dragging loop
local function startPlacement(model: Model)
    selectedShooter = model
    originalCFrame = model.PrimaryPart and model.PrimaryPart.CFrame
    isPlacing = true
    
    -- Tell server we are starting placement (pauses shooting loop)
    moveEvent:FireServer(model, "Start")
    
    -- Semi-transparent look for placement
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") then
            child.Transparency = 0.5
        end
    end
    
    -- Create temporary billboard instructions above player
    local post = Instance.new("Part")
    post.Name = "PlacementSign"
    post.Size = Vector3.new(0.1, 0.1, 0.1)
    post.Transparency = 1
    post.Anchored = true
    post.CanCollide = false
    post.Parent = model
    
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(8, 0, 2, 0)
    billboard.StudsOffset = Vector3.new(0, 4.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = post
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.FredokaOne
    label.TextScaled = true
    label.Text = "Relocating...\nClick Court to Place\nRight-Click to Cancel\nPress R to Unequip"
    label.TextColor3 = Color3.fromRGB(255, 255, 100)
    label.Parent = billboard
    
    -- Track mouse on every frame
    placementConnection = RunService.RenderStepped:Connect(function()
        if not selectedShooter or not selectedShooter.PrimaryPart then return end
        
        post.Position = selectedShooter.PrimaryPart.Position
        
        local targetPos, targetPart = getMouseTarget()
        if targetPos and targetPart then
            -- Verify we are aiming at the floor/court
            if targetPart.Name == "Court" or targetPart.Name == "Floor" then
                -- Snap shooter to floor position
                local root = selectedShooter.PrimaryPart
                
                -- Orient towards the hoop of this plot
                local plot = model.Parent and model.Parent.Parent
                local hoop = plot and plot:FindFirstChild("Hoop")
                local rim = hoop and hoop:FindFirstChild("Rim") :: BasePart?
                local lookTarget = rim and rim.Position or Vector3.new(targetPos.X, 2.5, targetPos.Z - 10)
                
                local plotCenter = plot and plot:GetAttribute("CenterPosition") :: Vector3?
                local finalX, finalZ = targetPos.X, targetPos.Z
                
                if plotCenter then
                    local relX = targetPos.X - plotCenter.X
                    local relZ = targetPos.Z - plotCenter.Z
                    local clampedX = math.clamp(relX, -18, 18)
                    local clampedZ = math.clamp(relZ, -33, 23)
                    finalX = plotCenter.X + clampedX
                    finalZ = plotCenter.Z + clampedZ
                end
                
                root.CFrame = CFrame.new(
                    Vector3.new(finalX, targetPos.Y + 2.0, finalZ),
                    Vector3.new(lookTarget.X, targetPos.Y + 2.0, lookTarget.Z)
                )
            end
        end
    end)
end

function PlacementManager.Initialize()
    local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
    moveEvent = remotes:WaitForChild("MoveShooter") :: RemoteEvent
    
    -- Click handler
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if isPlacing then
                -- If placing, confirm placement on click
                local targetPos, targetPart = getMouseTarget()
                if targetPos and targetPart and (targetPart.Name == "Court" or targetPart.Name == "Floor") then
                    confirmPlacement(targetPos)
                end
            else
                -- If not placing, click to select shooter
                local _, targetPart = getMouseTarget()
                if targetPart then
                    local model = targetPart.Parent
                    if model and model:IsA("Model") and model:GetAttribute("OwnerUserId") == localPlayer.UserId then
                        startPlacement(model)
                    end
                end
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            -- Cancel on Right Click
            if isPlacing then
                PlacementManager.CancelPlacement()
            end
        elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.R then
            if isPlacing and selectedShooter then
                local id = selectedShooter:GetAttribute("ShooterId")
                if id then
                    local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
                    local unequipFunc = remotes:WaitForChild("UnequipShooter") :: RemoteFunction
                    
                    isPlacing = false
                    if placementConnection then
                        placementConnection:Disconnect()
                        placementConnection = nil
                    end
                    
                    local post = selectedShooter:FindFirstChild("PlacementSign")
                    if post then post:Destroy() end
                    
                    -- Invoke server to unequip
                    task.spawn(function()
                        unequipFunc:InvokeServer(id)
                    end)
                    
                    selectedShooter = nil
                    originalCFrame = nil
                end
            end
        end
    end)
end

return PlacementManager

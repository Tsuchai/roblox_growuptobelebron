--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local TeamUI = {}
local localPlayer = Players.LocalPlayer

-- UI References
local screenGui: ScreenGui
local teamFrame: Frame
local rosterContainer: Frame
local benchContainer: ScrollingFrame
local toggleButton: TextButton

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local equipShooter = remotes:WaitForChild("EquipShooter") :: RemoteFunction
local unequipShooter = remotes:WaitForChild("UnequipShooter") :: RemoteFunction
local getRoster = remotes:WaitForChild("GetRoster") :: RemoteFunction

local activeSlotUIs = {}

-- Refreshes the Team UI
local function refreshTeamUI()
    if not teamFrame or not teamFrame.Visible then return end
    
    task.spawn(function()
        local inventory, positions = getRoster:InvokeServer()
        if not inventory or not positions then return end
        
        -- Build equipped lookup
        local equippedIds = {}
        for _, posItem in ipairs(positions) do
            equippedIds[posItem.Id] = true
        end
        
        -- Update Active Roster Slots (Top)
        for i = 1, Config.MaxActiveShooters or 5 do
            local slot = activeSlotUIs[i]
            if not slot then continue end
            
            local posItem = positions[i]
            if posItem then
                -- Find specific stats
                local shooterData = nil
                for _, item in ipairs(inventory) do
                    if item.Id == posItem.Id then
                        shooterData = item
                        break
                    end
                end
                
                local tierName = shooterData and shooterData.Tier or posItem.Tier
                local attr = shooterData and shooterData.Attribute or "Slasher"
                local yield = shooterData and shooterData.BaseYield or 0
                
                local cfg = Config.Shooters[tierName]
                local displayName = cfg and cfg.DisplayName or tierName
                
                slot.NameLabel.Text = displayName .. "\n(" .. attr .. ")"
                slot.StatusLabel.Text = "$" .. yield .. "/shot - Click to Unequip"
                slot.Button.BackgroundColor3 = Color3.fromRGB(40, 60, 100) -- Active blue
                slot.ShooterId = posItem.Id
            else
                slot.NameLabel.Text = "Empty Slot"
                slot.StatusLabel.Text = ""
                slot.Button.BackgroundColor3 = Color3.fromRGB(30, 30, 35) -- Empty dark
                slot.ShooterId = nil
            end
        end
        
        -- Clear old Bench
        for _, child in ipairs(benchContainer:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        
        -- Build Bench Cards (Bottom) for unequipped shooters
        local unequippedCount = 0
        for _, item in ipairs(inventory) do
            if equippedIds[item.Id] then continue end
            unequippedCount += 1
            
            local cfg = Config.Shooters[item.Tier]
            local displayName = cfg and cfg.DisplayName or item.Tier
            
            local card = Instance.new("Frame")
            card.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            card.Size = UDim2.new(0, 225, 0, 80)
            card.Parent = benchContainer
            Instance.new("UICorner", card).CornerRadius = UDim.new(0.1, 0)
            
            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.6, 0, 0.4, 0)
            nameLbl.Position = UDim2.new(0.05, 0, 0.1, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Font = Enum.Font.SourceSansBold
            nameLbl.Text = displayName
            nameLbl.TextColor3 = Color3.new(1, 1, 1)
            nameLbl.TextScaled = true
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = card
            
            local statsLbl = Instance.new("TextLabel")
            statsLbl.Size = UDim2.new(0.65, 0, 0.4, 0)
            statsLbl.Position = UDim2.new(0.05, 0, 0.50, 0)
            statsLbl.BackgroundTransparency = 1
            statsLbl.Font = Enum.Font.SourceSans
            statsLbl.Text = "$" .. item.BaseYield .. " | " .. string.format("%.1f", item.Cooldown) .. "s\n(" .. item.Attribute .. ")"
            statsLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
            statsLbl.TextScaled = true
            statsLbl.TextXAlignment = Enum.TextXAlignment.Left
            statsLbl.Parent = card
            
            local equipBtn = Instance.new("TextButton")
            equipBtn.Size = UDim2.new(0, 65, 0, 36)
            equipBtn.Position = UDim2.new(0.68, 0, 0.25, 0)
            equipBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            equipBtn.Font = Enum.Font.FredokaOne
            equipBtn.Text = "EQUIP"
            equipBtn.TextColor3 = Color3.new(1, 1, 1)
            equipBtn.TextSize = 14
            equipBtn.Parent = card
            Instance.new("UICorner", equipBtn).CornerRadius = UDim.new(0.2, 0)
            
            equipBtn.MouseButton1Click:Connect(function()
                equipBtn.Text = "..."
                local success, msg = equipShooter:InvokeServer(item.Id)
                if success then refreshTeamUI() else equipBtn.Text = "EQUIP" end
            end)
        end
        
        -- Resize scroll canvas based on items
        local rows = math.ceil(unequippedCount / 2)
        benchContainer.CanvasSize = UDim2.new(0, 0, 0, rows * 90)
    end)
end

-- Programmatic UI Construction
local function buildTeamUI(playerGui: PlayerGui)
    screenGui = playerGui:WaitForChild("LeBronShop") :: ScreenGui
    if not screenGui then return end
    
    -- Toggle Button (Below Shop Button)
    toggleButton = Instance.new("TextButton")
    toggleButton.Name = "TeamToggleButton"
    toggleButton.Size = UDim2.new(0, 120, 0, 50)
    toggleButton.Position = UDim2.new(0, 20, 0.5, 35) -- Below shop
    toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    toggleButton.Font = Enum.Font.FredokaOne
    toggleButton.Text = "ROSTER"
    toggleButton.TextColor3 = Color3.new(1, 1, 1)
    toggleButton.TextSize = 22
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = screenGui
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0.3, 0)
    btnCorner.Parent = toggleButton
    
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(0, 150, 255)
    btnStroke.Thickness = 2
    btnStroke.Parent = toggleButton
    
    -- Main Team Frame
    teamFrame = Instance.new("Frame")
    teamFrame.Name = "TeamFrame"
    teamFrame.Size = UDim2.new(0, 500, 0, 480)
    teamFrame.Position = UDim2.new(0.5, -250, 0.5, -240)
    teamFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    teamFrame.BackgroundTransparency = 0.15
    teamFrame.BorderSizePixel = 0
    teamFrame.Visible = false
    teamFrame.Parent = screenGui
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0.05, 0)
    frameCorner.Parent = teamFrame
    
    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(0, 150, 255)
    frameStroke.Thickness = 3
    frameStroke.Parent = teamFrame
    
    -- Header
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundTransparency = 1
    header.Font = Enum.Font.FredokaOne
    header.Text = "Team Roster"
    header.TextColor3 = Color3.fromRGB(255, 255, 255)
    header.TextSize = 24
    header.Parent = teamFrame
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 20
    closeBtn.Parent = teamFrame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.5, 0)
    
    -- Active Roster Section
    local rosterLabel = Instance.new("TextLabel")
    rosterLabel.Size = UDim2.new(1, -20, 0, 20)
    rosterLabel.Position = UDim2.new(0, 10, 0, 45)
    rosterLabel.BackgroundTransparency = 1
    rosterLabel.Font = Enum.Font.SourceSansBold
    rosterLabel.Text = "On Court (Max " .. (Config.MaxActiveShooters or 5) .. ")"
    rosterLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    rosterLabel.TextSize = 16
    rosterLabel.TextXAlignment = Enum.TextXAlignment.Left
    rosterLabel.Parent = teamFrame
    
    rosterContainer = Instance.new("Frame")
    rosterContainer.Size = UDim2.new(1, -20, 0, 80)
    rosterContainer.Position = UDim2.new(0, 10, 0, 70)
    rosterContainer.BackgroundTransparency = 1
    rosterContainer.Parent = teamFrame
    
    local rosterLayout = Instance.new("UIListLayout")
    rosterLayout.FillDirection = Enum.FillDirection.Horizontal
    rosterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    rosterLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rosterLayout.Padding = UDim.new(0, 10)
    rosterLayout.Parent = rosterContainer
    
    for i = 1, Config.MaxActiveShooters or 5 do
        local slot = Instance.new("TextButton")
        slot.Size = UDim2.new(0, 85, 1, 0)
        slot.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        slot.Text = ""
        slot.LayoutOrder = i
        slot.Parent = rosterContainer
        Instance.new("UICorner", slot).CornerRadius = UDim.new(0.1, 0)
        
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, 0, 0.6, 0)
        nameLbl.Position = UDim2.new(0, 0, 0.05, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.SourceSansBold
        nameLbl.Text = "Empty Slot"
        nameLbl.TextColor3 = Color3.new(1, 1, 1)
        nameLbl.TextScaled = true
        nameLbl.Parent = slot
        
        local statusLbl = Instance.new("TextLabel")
        statusLbl.Size = UDim2.new(1, 0, 0.3, 0)
        statusLbl.Position = UDim2.new(0, 0, 0.65, 0)
        statusLbl.BackgroundTransparency = 1
        statusLbl.Font = Enum.Font.SourceSans
        statusLbl.Text = ""
        statusLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
        statusLbl.TextScaled = true
        statusLbl.Parent = slot
        
        activeSlotUIs[i] = {
            Button = slot,
            NameLabel = nameLbl,
            StatusLabel = statusLbl,
            ShooterId = nil
        }
        
        -- Unequip handler
        slot.MouseButton1Click:Connect(function()
            local id = activeSlotUIs[i].ShooterId
            if id then
                local success = unequipShooter:InvokeServer(id)
                if success then refreshTeamUI() end
            end
        end)
    end
    
    -- Bench Section
    local benchLabel = Instance.new("TextLabel")
    benchLabel.Size = UDim2.new(1, -20, 0, 20)
    benchLabel.Position = UDim2.new(0, 10, 0, 160)
    benchLabel.BackgroundTransparency = 1
    benchLabel.Font = Enum.Font.SourceSansBold
    benchLabel.Text = "Bench (Inventory)"
    benchLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    benchLabel.TextSize = 16
    benchLabel.TextXAlignment = Enum.TextXAlignment.Left
    benchLabel.Parent = teamFrame
    
    benchContainer = Instance.new("ScrollingFrame")
    benchContainer.Size = UDim2.new(1, -20, 1, -190)
    benchContainer.Position = UDim2.new(0, 10, 0, 180)
    benchContainer.BackgroundTransparency = 1
    benchContainer.BorderSizePixel = 0
    benchContainer.ScrollBarThickness = 6
    benchContainer.CanvasSize = UDim2.new(0, 0, 0, 500)
    benchContainer.Parent = teamFrame
    
    local benchLayout = Instance.new("UIGridLayout")
    benchLayout.CellSize = UDim2.new(0, 225, 0, 80)
    benchLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    benchLayout.SortOrder = Enum.SortOrder.LayoutOrder
    benchLayout.Parent = benchContainer
    
    -- Toggle Button Logic
    local open = false
    toggleButton.MouseButton1Click:Connect(function()
        open = not open
        teamFrame.Visible = open
        if open then
            refreshTeamUI()
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        open = false
        teamFrame.Visible = false
    end)
end

function TeamUI.Initialize()
    local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
    buildTeamUI(playerGui)
    
    -- Auto refresh on attribute change if open
    localPlayer.AttributeChanged:Connect(function(attr)
        if string.match(attr, "^Shooter_") and teamFrame and teamFrame.Visible then
            refreshTeamUI()
        end
    end)
    
    -- Also refresh if models are added/removed to workspace (if team frame is open)
    Workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("Model") and desc:GetAttribute("OwnerUserId") == localPlayer.UserId then
            if teamFrame and teamFrame.Visible then refreshTeamUI() end
        end
    end)
    Workspace.DescendantRemoving:Connect(function(desc)
        if desc:IsA("Model") and desc:GetAttribute("OwnerUserId") == localPlayer.UserId then
            if teamFrame and teamFrame.Visible then refreshTeamUI() end
        end
    end)
    
    print("[Client] TeamUI Initialized!")
end

return TeamUI

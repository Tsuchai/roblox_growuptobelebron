--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FormatNumber = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatNumber"))

local ShopUI = {}
local localPlayer = Players.LocalPlayer

-- UI References
local screenGui: ScreenGui
local shopFrame: Frame
local scrollingFrame: ScrollingFrame
local toggleButton: TextButton

-- Cache for dynamically updating cards
local shooterCards: { [string]: { CostLabel: TextLabel, OwnedLabel: TextLabel, BuyBtn: TextButton } } = {}
local hoopCard: { CostLabel: TextLabel, TitleLabel: TextLabel, BuyBtn: TextButton } = {}
local rebirthCard: { CostLabel: TextLabel, TitleLabel: TextLabel, BuyBtn: TextButton } = {}
local playerUpgradeCard: { CostLabel: TextLabel, TitleLabel: TextLabel, BuyBtn: TextButton } = {}

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local buyUpgrade = remotes:WaitForChild("BuyUpgrade") :: RemoteFunction
local rebirthRequest = remotes:WaitForChild("RebirthRequest") :: RemoteFunction


-- Refreshes all prices and availability in the Shop
local function refreshShop()
    local cash = localPlayer:GetAttribute("Cash") or 0
    local rebirths = localPlayer:GetAttribute("Rebirths") or 0
    local hoopLevel = localPlayer:GetAttribute("HoopUpgradeLevel") or 1
    local playerUpgradeLevel = localPlayer:GetAttribute("PlayerUpgradeLevel") or 1
    
    -- 1. Update Shooter Cards
    for tier, card in pairs(shooterCards) do
        local owned = localPlayer:GetAttribute("Shooter_" .. tier) or 0
        local cost = Config.GetShooterCost(tier, owned)
        
        card.OwnedLabel.Text = "Owned: " .. owned
        card.CostLabel.Text = "$" .. FormatNumber.format(cost)
        
        if cash >= cost then
            card.BuyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80) -- Green
            card.BuyBtn.Text = "BUY"
            card.BuyBtn.Active = true
        else
            card.BuyBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40) -- Dark Red
            card.BuyBtn.Text = "LOCK"
            card.BuyBtn.Active = false
        end
    end
    
    -- 2. Update Hoop Card
    local nextLevel = hoopLevel + 1
    local nextHoopConfig = Config.Hoops[nextLevel]
    if nextHoopConfig then
        hoopCard.TitleLabel.Text = "Upgrade Hoop (" .. nextHoopConfig.Name .. ")"
        hoopCard.CostLabel.Text = "$" .. FormatNumber.format(nextHoopConfig.Cost)
        
        if cash >= nextHoopConfig.Cost then
            hoopCard.BuyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            hoopCard.BuyBtn.Text = "UPGRADE"
            hoopCard.BuyBtn.Active = true
        else
            hoopCard.BuyBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
            hoopCard.BuyBtn.Text = "LOCK"
            hoopCard.BuyBtn.Active = false
        end
    else
        local currentHoop = Config.Hoops[hoopLevel]
        hoopCard.TitleLabel.Text = "Hoop Maxed (" .. (currentHoop and currentHoop.Name or "Max") .. ")"
        hoopCard.CostLabel.Text = "MAX"
        hoopCard.BuyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        hoopCard.BuyBtn.Text = "MAX"
        hoopCard.BuyBtn.Active = false
    end
    
    -- 3. Update Player Upgrade Card
    local nextUpgradeCfg = Config.PlayerUpgrades[playerUpgradeLevel + 1]
    if nextUpgradeCfg then
        local currentUpgradeName = Config.PlayerUpgrades[playerUpgradeLevel].Name
        playerUpgradeCard.TitleLabel.Text = "Player Upgrade (" .. currentUpgradeName .. " → " .. nextUpgradeCfg.Name .. ")"
        playerUpgradeCard.CostLabel.Text = "$" .. FormatNumber.format(nextUpgradeCfg.Cost)

        if cash >= nextUpgradeCfg.Cost then
            playerUpgradeCard.BuyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            playerUpgradeCard.BuyBtn.Text = "UPGRADE"
            playerUpgradeCard.BuyBtn.Active = true
        else
            playerUpgradeCard.BuyBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
            playerUpgradeCard.BuyBtn.Text = "LOCK"
            playerUpgradeCard.BuyBtn.Active = false
        end
    else
        local maxName = Config.PlayerUpgrades[playerUpgradeLevel] and Config.PlayerUpgrades[playerUpgradeLevel].Name or "Max"
        playerUpgradeCard.TitleLabel.Text = "Player Upgrade (" .. maxName .. " - MAX)"
        playerUpgradeCard.CostLabel.Text = "MAX"
        playerUpgradeCard.BuyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        playerUpgradeCard.BuyBtn.Text = "MAX"
        playerUpgradeCard.BuyBtn.Active = false
    end

    -- 4. Update Rebirth Card
    local rebirthCost = Config.GetRebirthCost(rebirths)
    rebirthCard.TitleLabel.Text = "Rebirth (" .. rebirths .. ")"
    rebirthCard.CostLabel.Text = "$" .. FormatNumber.format(rebirthCost)
    
    if cash >= rebirthCost then
        rebirthCard.BuyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
        rebirthCard.BuyBtn.Text = "REBIRTH"
        rebirthCard.BuyBtn.Active = true
    else
        rebirthCard.BuyBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        rebirthCard.BuyBtn.Text = "LOCK"
        rebirthCard.BuyBtn.Active = false
    end
end

-- Programmatic UI Construction helper
local function buildShopUI(playerGui: PlayerGui)
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LeBronShop"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- 1. Shop Toggle Button (Left edge)
    toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(0, 120, 0, 50)
    toggleButton.Position = UDim2.new(0, 20, 0.5, -25)
    toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    toggleButton.Font = Enum.Font.FredokaOne
    toggleButton.Text = "SHOP"
    toggleButton.TextColor3 = Color3.new(1, 1, 1)
    toggleButton.TextSize = 22
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = screenGui
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0.3, 0)
    btnCorner.Parent = toggleButton
    
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(255, 110, 0) -- Basketball Orange
    btnStroke.Thickness = 2
    btnStroke.Parent = toggleButton
    
    -- 2. Main Shop Frame
    shopFrame = Instance.new("Frame")
    shopFrame.Name = "ShopFrame"
    shopFrame.Size = UDim2.new(0, 500, 0, 420)
    shopFrame.Position = UDim2.new(0.5, -250, 0.5, -210)
    shopFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    shopFrame.BackgroundTransparency = 0.15 -- Glassmorphism
    shopFrame.BorderSizePixel = 0
    shopFrame.Visible = false
    shopFrame.Parent = screenGui
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0.05, 0)
    frameCorner.Parent = shopFrame
    
    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(255, 110, 0)
    frameStroke.Thickness = 3
    frameStroke.Parent = shopFrame
    
    -- Header Label
    local header = Instance.new("TextLabel")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundTransparency = 1
    header.Font = Enum.Font.FredokaOne
    header.Text = "LeShop - Hire Shooters & Upgrades"
    header.TextColor3 = Color3.fromRGB(255, 255, 255)
    header.TextSize = 24
    header.Parent = shopFrame
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 20
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = shopFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0.5, 0) -- Circle
    closeCorner.Parent = closeBtn
    
    -- Scrolling Frame for shop item list
    scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Name = "List"
    scrollingFrame.Size = UDim2.new(1, -20, 1, -70)
    scrollingFrame.Position = UDim2.new(0, 10, 0, 60)
    scrollingFrame.BackgroundTransparency = 1
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 600)
    scrollingFrame.ScrollBarThickness = 8
    scrollingFrame.Parent = shopFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrollingFrame
    
    -- 3. Populate Items
    local layoutOrder = 1
    
    -- Helper to build an item card row
    local function createItemCard(title: string, desc: string, isShooter: boolean, shooterTier: string?): Frame
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -10, 0, 70)
        card.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        card.BorderSizePixel = 0
        card.LayoutOrder = layoutOrder
        layoutOrder = layoutOrder + 1
        card.Parent = scrollingFrame
        
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0.15, 0)
        cardCorner.Parent = card
        
        -- Title
        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(0.6, 0, 0.5, 0)
        titleLbl.Position = UDim2.new(0.03, 0, 0.1, 0)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.SourceSansBold
        titleLbl.Text = title
        titleLbl.TextColor3 = Color3.new(1, 1, 1)
        titleLbl.TextSize = 20
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = card
        
        -- Description
        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(0.6, 0, 0.4, 0)
        descLbl.Position = UDim2.new(0.03, 0, 0.55, 0)
        descLbl.BackgroundTransparency = 1
        descLbl.Font = Enum.Font.SourceSans
        descLbl.Text = desc
        descLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
        descLbl.TextSize = 14
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.Parent = card
        
        -- Cost Label
        local costLbl = Instance.new("TextLabel")
        costLbl.Size = UDim2.new(0.2, 0, 0.5, 0)
        costLbl.Position = UDim2.new(0.55, 0, 0.25, 0)
        costLbl.BackgroundTransparency = 1
        costLbl.Font = Enum.Font.FredokaOne
        costLbl.Text = "$0"
        costLbl.TextColor3 = Color3.fromRGB(255, 180, 0)
        costLbl.TextSize = 18
        costLbl.TextXAlignment = Enum.TextXAlignment.Right
        costLbl.Parent = card
        
        -- Buy Button
        local buyBtn = Instance.new("TextButton")
        buyBtn.Size = UDim2.new(0, 90, 0, 40)
        buyBtn.Position = UDim2.new(0.78, 0, 0.2, 0)
        buyBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        buyBtn.Font = Enum.Font.FredokaOne
        buyBtn.Text = "BUY"
        buyBtn.TextColor3 = Color3.new(1, 1, 1)
        buyBtn.TextSize = 16
        buyBtn.BorderSizePixel = 0
        buyBtn.Parent = card
        
        local buyCorner = Instance.new("UICorner")
        buyCorner.CornerRadius = UDim.new(0.25, 0)
        buyCorner.Parent = buyBtn
        
        -- Owned Label (Shooter only)
        local ownedLbl = Instance.new("TextLabel")
        ownedLbl.Size = UDim2.new(0.2, 0, 0.3, 0)
        ownedLbl.Position = UDim2.new(0.78, 0, 0.7, 0)
        ownedLbl.BackgroundTransparency = 1
        ownedLbl.Font = Enum.Font.SourceSansBold
        ownedLbl.Text = "Owned: 0"
        ownedLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        ownedLbl.TextSize = 11
        ownedLbl.Parent = card
        
        if not isShooter then
            ownedLbl.Visible = false
        end
        
        -- Wire up purchase click animations and server invocations
        buyBtn.MouseButton1Click:Connect(function()
            if isShooter and shooterTier then
                local success, msg = buyUpgrade:InvokeServer("Shooter", shooterTier)
                if success then
                    refreshShop()
                end
            elseif title == "Upgrade Hoop" then
                local success, msg = buyUpgrade:InvokeServer("Hoop", "")
                if success then
                    refreshShop()
                end
            elseif title == "Player Upgrade" then
                local success, msg = buyUpgrade:InvokeServer("PlayerUpgrade", "")
                if success then
                    refreshShop()
                end
            elseif title == "Rebirth" then
                local success, msg = rebirthRequest:InvokeServer()
                if success then
                    refreshShop()
                end
            end
        end)
        
        -- Cache elements
        if isShooter and shooterTier then
            shooterCards[shooterTier] = {
                CostLabel = costLbl,
                OwnedLabel = ownedLbl,
                BuyBtn = buyBtn
            }
        elseif title == "Upgrade Hoop" then
            hoopCard = {
                CostLabel = costLbl,
                TitleLabel = titleLbl,
                BuyBtn = buyBtn
            }
        elseif title == "Player Upgrade" then
            playerUpgradeCard = {
                CostLabel = costLbl,
                TitleLabel = titleLbl,
                BuyBtn = buyBtn
            }
        elseif title == "Rebirth" then
            rebirthCard = {
                CostLabel = costLbl,
                TitleLabel = titleLbl,
                BuyBtn = buyBtn
            }
        end
        
        return card
    end
    
    -- Build Shooter Cards
    -- Tiers in order of pricing config
    local orderedTiers = {"Rookie", "College", "Pro", "AllStar", "LeBron"}
    for _, tier in ipairs(orderedTiers) do
        local shooter = Config.Shooters[tier]
        if shooter then
            local desc = "+" .. shooter.BaseYield .. " Cash, " .. shooter.Cooldown .. "s Cooldown (" .. shooter.Attribute .. ")"
            createItemCard(shooter.DisplayName, desc, true, tier)
        end
    end
    
    -- Build Hoop Upgrade Card
    createItemCard("Upgrade Hoop", "Upgrade your hoop rim to multiply all points earned", false, nil)

    -- Build Player Upgrade Card
    createItemCard("Player Upgrade", "Boost your manual shot — scales with your passive roster!", false, nil)

    -- Build Rebirth Card
    createItemCard("Rebirth", "Reset cash/shooters for permanent +50% earnings!", false, nil)
    
    -- Toggle Button Click handlers (with scale tween)
    local open = false
    toggleButton.MouseButton1Click:Connect(function()
        open = not open
        shopFrame.Visible = open
        if open then
            refreshShop()
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        open = false
        shopFrame.Visible = false
    end)
end

function ShopUI.Initialize()
    local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
    buildShopUI(playerGui)
    
    -- Listen to local player attribute changes to refresh UI prices in real time
    localPlayer.AttributeChanged:Connect(function(attributeName)
        if attributeName == "Cash" or attributeName == "Rebirths" or attributeName == "HoopUpgradeLevel"
            or attributeName == "PlayerUpgradeLevel" or string.match(attributeName, "^Shooter_") then
            if shopFrame.Visible then
                refreshShop()
            end
        end
    end)
    
    print("[Client] ShopUI Initialized!")
end

return ShopUI

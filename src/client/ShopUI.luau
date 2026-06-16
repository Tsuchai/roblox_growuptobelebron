--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FormatNumber = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatNumber"))

local ShopUI = {}
local localPlayer = Players.LocalPlayer

local function formatTime(seconds: number): string
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%02d:%02d", m, s)
end

-- UI References
local screenGui: ScreenGui
local shopFrame: Frame
local scrollingFrame: ScrollingFrame
local toggleButton: TextButton

local rollCards: { [string]: { CostLabel: TextLabel, TitleLabel: TextLabel, BuyBtn: TextButton } } = {}
local hoopCard: { CostLabel: TextLabel, TitleLabel: TextLabel, BuyBtn: TextButton } = {} :: any
local rebirthCard: { CostLabel: TextLabel, TitleLabel: TextLabel, BuyBtn: TextButton } = {} :: any
local playerUpgradeCard: { CostLabel: TextLabel, TitleLabel: TextLabel, BuyBtn: TextButton } = {} :: any

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
    
    local draftActiveObj = ReplicatedStorage:FindFirstChild("DraftActive")
    local isDraftActive = draftActiveObj and draftActiveObj.Value or false
    local timeLeftObj = ReplicatedStorage:FindFirstChild("DraftTimeLeft")
    
    -- 1. Update Roll Cards
    for rollType, card in pairs(rollCards) do
        local rConfig = Config.Rolls[rollType]
        local cost = rConfig.Cost
        card.CostLabel.Text = "$" .. FormatNumber.format(cost)
        
        if rConfig.IsLimitedTime and not isDraftActive then
            card.BuyBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
            card.BuyBtn.Active = false
            card.BuyBtn.Text = "WAIT " .. formatTime(timeLeftObj and timeLeftObj.Value or 0)
        else
            if cash >= cost then
                card.BuyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80) -- Green
                if rConfig.IsLimitedTime then
                    card.BuyBtn.Text = "DRAFT " .. formatTime(timeLeftObj and timeLeftObj.Value or 0)
                else
                    card.BuyBtn.Text = "ROLL"
                end
                card.BuyBtn.Active = true
            else
                card.BuyBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40) -- Dark Red
                card.BuyBtn.Text = "LOCK"
                card.BuyBtn.Active = false
            end
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

-- Flashy Spin Animation
local function playSpinAnimation(rolledTier: string)
    shopFrame.Visible = false -- Hide shop during roll
    
    local spinFrame = Instance.new("Frame")
    spinFrame.Size = UDim2.new(1, 0, 1, 0)
    spinFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    spinFrame.BackgroundTransparency = 0.5
    spinFrame.BorderSizePixel = 0
    spinFrame.Parent = screenGui
    
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 0, 0, 0) -- Starts tiny
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    card.Parent = spinFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.1, 0)
    corner.Parent = card
    
    local textLbl = Instance.new("TextLabel")
    textLbl.Size = UDim2.new(1, 0, 1, 0)
    textLbl.BackgroundTransparency = 1
    textLbl.Font = Enum.Font.FredokaOne
    textLbl.Text = "?"
    textLbl.TextColor3 = Color3.new(1, 1, 1)
    textLbl.TextScaled = true
    textLbl.Parent = card
    
    -- Pop in
    local t1 = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 200, 0, 300)})
    t1:Play()
    t1.Completed:Wait()
    
    -- Flashing spin phase
    local tiers = {"Rookie", "College", "Pro", "AllStar", "LeBron"}
    local colors = {Color3.fromRGB(120,120,120), Color3.new(0,1,0), Color3.new(0,0,1), Color3.new(1,0,1), Color3.new(1,0.8,0)}
    
    for i = 1, 20 do
        local randomIdx = math.random(1, #tiers)
        textLbl.Text = Config.Shooters[tiers[randomIdx]].DisplayName
        card.BackgroundColor3 = colors[randomIdx]
        
        -- Slow down the tick as it reaches the end
        local waitTime = 0.05 + (i * 0.01)
        task.wait(waitTime)
    end
    
    -- Final Result Reveal
    local finalColor = Color3.fromRGB(120, 120, 120) -- Grey for Rookie
    if rolledTier == "LeBron" then finalColor = Color3.fromRGB(255, 215, 0)
    elseif rolledTier == "AllStar" then finalColor = Color3.fromRGB(200, 0, 255)
    elseif rolledTier == "Pro" then finalColor = Color3.fromRGB(0, 100, 255)
    elseif rolledTier == "College" then finalColor = Color3.fromRGB(0, 200, 50) end
    
    card.BackgroundColor3 = finalColor
    textLbl.Text = Config.Shooters[rolledTier].DisplayName
    
    -- Dramatic pump
    local t2 = TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 250, 0, 375)})
    t2:Play()
    t2.Completed:Wait()
    local t3 = TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 200, 0, 300)})
    t3:Play()
    t3.Completed:Wait()
    
    task.wait(1.5)
    
    -- Fade out
    local t4 = TweenService:Create(spinFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1})
    local t5 = TweenService:Create(card, TweenInfo.new(0.5), {BackgroundTransparency = 1})
    local t6 = TweenService:Create(textLbl, TweenInfo.new(0.5), {TextTransparency = 1})
    t4:Play() t5:Play() t6:Play()
    t4.Completed:Wait()
    
    spinFrame:Destroy()
end

-- Draft Board Cinematic UI
local currentDraftBoardUI: Frame? = nil
local currentPickIndicator: TextLabel? = nil
local stealBtns: {TextButton} = {}

local function updateDraftBoard(newPick: number, newAwardedPlayer: any)
    if not currentDraftBoardUI then return end
    
    -- Animate the highlight moving up
    if currentPickIndicator then
        local targetSlot = currentDraftBoardUI:FindFirstChild("Slot" .. newPick)
        if targetSlot and targetSlot:IsA("Frame") then
            local t = TweenService:Create(currentPickIndicator, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetSlot.Position - UDim2.new(0, 0, 0, 30)})
            t:Play()
            currentPickIndicator.Text = "NEW PICK!"
            currentPickIndicator.TextColor3 = Color3.fromRGB(0, 255, 100)
            task.wait(1)
            currentPickIndicator.Text = "YOUR PICK"
            currentPickIndicator.TextColor3 = Color3.fromRGB(255, 255, 100)
        end
    end
    
    -- Hide any steal buttons that are now behind or equal to our new pick
    for _, btn in ipairs(stealBtns) do
        local slotIndex = tonumber(btn.Name:match("%d+"))
        if slotIndex and slotIndex >= newPick then
            btn.Visible = false
        end
    end
end

local function playDraftBoardAnimation(board: any, userPick: number)
    shopFrame.Visible = false
    
    local draftFrame = Instance.new("Frame")
    draftFrame.Size = UDim2.new(1, 0, 1, 0)
    draftFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    draftFrame.BackgroundTransparency = 0.2
    draftFrame.BorderSizePixel = 0
    draftFrame.Parent = screenGui
    currentDraftBoardUI = draftFrame
    
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 100)
    header.Position = UDim2.new(0, 0, 0, 50)
    header.BackgroundTransparency = 1
    header.Font = Enum.Font.FredokaOne
    header.Text = "DRAFT BOARD"
    header.TextColor3 = Color3.fromRGB(255, 215, 0)
    header.TextSize = 50
    header.Parent = draftFrame
    
    -- Create 5 slots
    local slotWidth = 150
    local spacing = 20
    local totalWidth = (slotWidth * 5) + (spacing * 4)
    local startX = 0.5
    
    for i = 1, 5 do
        local slot = Instance.new("Frame")
        slot.Name = "Slot" .. i
        slot.Size = UDim2.new(0, slotWidth, 0, 220)
        local offsetX = ((i - 1) * (slotWidth + spacing)) - (totalWidth / 2) + (slotWidth / 2)
        slot.Position = UDim2.new(0.5, offsetX, 0.5, 0)
        slot.AnchorPoint = Vector2.new(0.5, 0.5)
        slot.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        slot.Parent = draftFrame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.1, 0)
        corner.Parent = slot
        
        local numLbl = Instance.new("TextLabel")
        numLbl.Size = UDim2.new(1, 0, 0, 30)
        numLbl.BackgroundTransparency = 1
        numLbl.Font = Enum.Font.SourceSansBold
        numLbl.Text = "#" .. i
        numLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        numLbl.TextSize = 20
        numLbl.Parent = slot
        
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -10, 1, -40)
        nameLbl.Position = UDim2.new(0, 5, 0, 30)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.FredokaOne
        nameLbl.Text = "?"
        nameLbl.TextColor3 = Color3.new(1, 1, 1)
        nameLbl.TextScaled = true
        nameLbl.Parent = slot
        
        -- Reveal animation
        task.wait(0.3)
        local playerInfo = board[i]
        local finalColor = Color3.fromRGB(120, 120, 120)
        if playerInfo.Tier == "LeBron" then finalColor = Color3.fromRGB(255, 215, 0)
        elseif playerInfo.Tier == "AllStar" then finalColor = Color3.fromRGB(200, 0, 255)
        elseif playerInfo.Tier == "Pro" then finalColor = Color3.fromRGB(0, 100, 255)
        elseif playerInfo.Tier == "College" then finalColor = Color3.fromRGB(0, 200, 50) end
        
        slot.BackgroundColor3 = finalColor
        nameLbl.Text = Config.Shooters[playerInfo.Tier].DisplayName .. "\n(" .. playerInfo.Attribute .. ")"
        
        local bump = TweenService:Create(slot, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, slotWidth + 20, 0, 240)})
        bump:Play()
        bump.Completed:Wait()
        TweenService:Create(slot, TweenInfo.new(0.1), {Size = UDim2.new(0, slotWidth, 0, 220)}):Play()
    end
    
    task.wait(0.5)
    
    -- Highlight user pick
    local userSlot = draftFrame:FindFirstChild("Slot" .. userPick) :: Frame
    currentPickIndicator = Instance.new("TextLabel")
    currentPickIndicator.Size = UDim2.new(0, 200, 0, 40)
    currentPickIndicator.Position = userSlot.Position - UDim2.new(0, 0, 0, 30)
    currentPickIndicator.AnchorPoint = Vector2.new(0.5, 1)
    currentPickIndicator.BackgroundTransparency = 1
    currentPickIndicator.Font = Enum.Font.FredokaOne
    currentPickIndicator.Text = "YOUR PICK"
    currentPickIndicator.TextColor3 = Color3.fromRGB(255, 255, 100)
    currentPickIndicator.TextSize = 24
    currentPickIndicator.Parent = draftFrame
    
    local pulse = TweenService:Create(currentPickIndicator, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {TextSize = 28})
    pulse:Play()
    
    -- Steal buttons for every pick above the user
    stealBtns = {}
    for i = 1, 4 do
        if i < userPick then
            local targetSlot = draftFrame:FindFirstChild("Slot" .. i) :: Frame
            local stealBtn = Instance.new("TextButton")
            stealBtn.Name = "StealBtn" .. i
            stealBtn.Size = UDim2.new(0, 140, 0, 50)
            stealBtn.Position = targetSlot.Position + UDim2.new(0, 0, 0, 80)
            stealBtn.AnchorPoint = Vector2.new(0.5, 0)
            stealBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
            stealBtn.Font = Enum.Font.FredokaOne
            
            local productInfo = Config.Monetization.StealPickProducts[i]
            stealBtn.Text = "STEAL PICK\n(" .. productInfo.DisplayPrice .. " R$)"
            stealBtn.TextColor3 = Color3.new(1, 1, 1)
            stealBtn.TextSize = 16
            stealBtn.Parent = draftFrame
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0.2, 0)
            btnCorner.Parent = stealBtn
            
            stealBtn.MouseButton1Click:Connect(function()
                if productInfo.Id ~= 0 then
                    MarketplaceService:PromptProductPurchase(localPlayer, productInfo.Id)
                else
                    warn("Developer has not set up the Product ID for Steal Pick #" .. i)
                end
            end)
            
            table.insert(stealBtns, stealBtn)
        end
    end
    
    -- Close button
    local closeDraftBtn = Instance.new("TextButton")
    closeDraftBtn.Size = UDim2.new(0, 200, 0, 50)
    closeDraftBtn.Position = UDim2.new(0.5, -100, 1, -100)
    closeDraftBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeDraftBtn.Font = Enum.Font.FredokaOne
    closeDraftBtn.Text = "CLAIM & EXIT"
    closeDraftBtn.TextColor3 = Color3.new(1, 1, 1)
    closeDraftBtn.TextSize = 20
    closeDraftBtn.Parent = draftFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0.3, 0)
    closeCorner.Parent = closeDraftBtn
    
    closeDraftBtn.MouseButton1Click:Connect(function()
        draftFrame:Destroy()
        currentDraftBoardUI = nil
        currentPickIndicator = nil
        stealBtns = {}
    end)
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
    local function createItemCard(title: string, desc: string, isRoll: boolean, rollType: string?): Frame
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
        buyBtn.Text = isRoll and "ROLL" or "BUY"
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
        
        if isRoll then
            ownedLbl.Visible = false
        end
        
        buyBtn.MouseButton1Click:Connect(function()
            if isRoll and rollType then
                -- Disable button to prevent double-click during animation
                buyBtn.Active = false
                buyBtn.Text = "..."
                local success, rolledTierOrMsg = buyUpgrade:InvokeServer("Roll", rollType)
                if success and rolledTierOrMsg then
                    if string.sub(rolledTierOrMsg, 1, 1) == "{" then
                        local draftData = HttpService:JSONDecode(rolledTierOrMsg)
                        if draftData.Type == "DraftBoard" then
                            playDraftBoardAnimation(draftData.Board, draftData.UserPick)
                        end
                    else
                        playSpinAnimation(rolledTierOrMsg)
                    end
                else
                    warn(rolledTierOrMsg)
                end
                refreshShop()
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
        if isRoll and rollType then
            rollCards[rollType] = {
                CostLabel = costLbl,
                TitleLabel = titleLbl,
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
    
    -- Build Roll Cards
    for rollType, rConfig in pairs(Config.Rolls) do
        local desc = rConfig.IsLimitedTime 
            and "A rare draft! Higher chances for high-tier shooters. Only available for 60 seconds!"
            or "Roll for a chance to win higher tier players! (Higher chance in Premium)"
        createItemCard(rConfig.Name, desc, true, rollType)
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
    
    local draftTimeLeft = ReplicatedStorage:WaitForChild("DraftTimeLeft", 5) :: IntValue?
    if draftTimeLeft then
        draftTimeLeft.Changed:Connect(function()
            if shopFrame.Visible then
                refreshShop()
            end
        end)
    end
    
    local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
    local draftUpdateEvent = remotes:WaitForChild("DraftUpdate") :: RemoteEvent
    draftUpdateEvent.OnClientEvent:Connect(function(newPick, newPlayerInfo)
        updateDraftBoard(newPick, newPlayerInfo)
    end)
    
    print("[Client] ShopUI Initialized!")
end

return ShopUI

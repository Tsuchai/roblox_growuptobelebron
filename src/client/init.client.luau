--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local VisualManager = require(script:WaitForChild("VisualManager"))
local PlacementManager = require(script:WaitForChild("PlacementManager"))
local ShopUI = require(script:WaitForChild("ShopUI"))
local TeamUI = require(script:WaitForChild("TeamUI"))
local MilestoneUI = require(script:WaitForChild("MilestoneUI"))
local FormatNumber = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatNumber"))

print("[Client] Initializing Grow Up to be LeBron...")

-- 1. Initialize Managers & UIs
VisualManager.Initialize()
PlacementManager.Initialize()
ShopUI.Initialize()
TeamUI.Initialize()
MilestoneUI.Initialize()

-- 2. Setup Remotes reference
local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local shootRequest = remotes:WaitForChild("ShootRequest") :: RemoteEvent

-- 3. Programmatically Build a Premium HUD ScreenGui
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LeBronHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Shoot Button (Bottom Center)
local shootButton = Instance.new("TextButton")
shootButton.Name = "ShootButton"
shootButton.Size = UDim2.new(0, 200, 0, 80)
shootButton.Position = UDim2.new(0.5, -100, 0.85, -40)
shootButton.BackgroundColor3 = Color3.fromRGB(255, 110, 0) -- Basketball Orange
shootButton.BorderSizePixel = 0
shootButton.Text = "" -- Content handled by child TextLabels
shootButton.AutoButtonColor = false -- We'll customize the animation ourselves!
shootButton.Parent = screenGui

-- UI Corner for rounded look
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0.3, 0)
uiCorner.Parent = shootButton

-- Main "SHOOT!" label inside the button
local shootMainLabel = Instance.new("TextLabel")
shootMainLabel.Size = UDim2.new(1, 0, 1, 0)
shootMainLabel.Position = UDim2.new(0, 0, 0, 0)
shootMainLabel.BackgroundTransparency = 1
shootMainLabel.Font = Enum.Font.FredokaOne
shootMainLabel.Text = "SHOOT!"
shootMainLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
shootMainLabel.TextSize = 26
shootMainLabel.Parent = shootButton

-- Cash Display (top-center HUD)
local cashFrame = Instance.new("Frame")
cashFrame.Name = "CashDisplay"
cashFrame.Size = UDim2.new(0, 240, 0, 64)
cashFrame.Position = UDim2.new(0.5, -120, 0, 16)
cashFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
cashFrame.BackgroundTransparency = 0.15
cashFrame.BorderSizePixel = 0
cashFrame.Parent = screenGui

local cashFrameCorner = Instance.new("UICorner")
cashFrameCorner.CornerRadius = UDim.new(0, 14)
cashFrameCorner.Parent = cashFrame

local cashFrameStroke = Instance.new("UIStroke")
cashFrameStroke.Color = Color3.fromRGB(255, 110, 0)
cashFrameStroke.Thickness = 2
cashFrameStroke.Parent = cashFrame

-- Cash amount label
local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLabel"
cashLabel.Size = UDim2.new(1, -12, 0, 36)
cashLabel.Position = UDim2.new(0, 6, 0, 4)
cashLabel.BackgroundTransparency = 1
cashLabel.Font = Enum.Font.FredokaOne
cashLabel.Text = "$0"
cashLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
cashLabel.TextSize = 26
cashLabel.TextXAlignment = Enum.TextXAlignment.Center
cashLabel.Parent = cashFrame

-- $/sec rate label
local rateLabel = Instance.new("TextLabel")
rateLabel.Name = "RateLabel"
rateLabel.Size = UDim2.new(1, -12, 0, 20)
rateLabel.Position = UDim2.new(0, 6, 0, 40)
rateLabel.BackgroundTransparency = 1
rateLabel.Font = Enum.Font.Gotham
rateLabel.Text = "$0/sec"
rateLabel.TextColor3 = Color3.fromRGB(160, 200, 120)
rateLabel.TextSize = 13
rateLabel.TextXAlignment = Enum.TextXAlignment.Center
rateLabel.Parent = cashFrame

-- UI Stroke for premium outline
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(255, 255, 255)
uiStroke.Thickness = 3
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
uiStroke.Parent = shootButton

-- Hover and Press animations using TweenService
local TweenService = game:GetService("TweenService")
local hoverTween = TweenService:Create(shootButton, TweenInfo.new(0.15), {
    BackgroundColor3 = Color3.fromRGB(255, 130, 30),
    Size = UDim2.new(0, 210, 0, 84),
    Position = UDim2.new(0.5, -105, 0.85, -42)
})

local leaveTween = TweenService:Create(shootButton, TweenInfo.new(0.15), {
    BackgroundColor3 = Color3.fromRGB(255, 110, 0),
    Size = UDim2.new(0, 200, 0, 80),
    Position = UDim2.new(0.5, -100, 0.85, -40)
})

local pressTween = TweenService:Create(shootButton, TweenInfo.new(0.05), {
    Size = UDim2.new(0, 190, 0, 76),
    Position = UDim2.new(0.5, -95, 0.85, -38),
    BackgroundColor3 = Color3.fromRGB(200, 80, 0)
})

shootButton.MouseEnter:Connect(function()
    hoverTween:Play()
end)

shootButton.MouseLeave:Connect(function()
    leaveTween:Play()
end)

shootButton.MouseButton1Down:Connect(function()
    pressTween:Play()
end)

shootButton.MouseButton1Up:Connect(function()
    hoverTween:Play()
end)

-- Fire shot request on click
shootButton.MouseButton1Click:Connect(function()
    shootRequest:FireServer()
end)

-- Live cash display update
local function updateCashDisplay()
    local cash = localPlayer:GetAttribute("Cash") or 0
    cashLabel.Text = "$" .. FormatNumber.format(cash)
end

-- Live $/sec rate update (reads accurate rate calculated by the server)
local function updateRateDisplay()
    local passiveRate = localPlayer:GetAttribute("PassiveRate") or 0
    rateLabel.Text = "$" .. FormatNumber.format(passiveRate) .. "/sec"
end

-- Update cash immediately and on any attribute change
updateCashDisplay()
localPlayer.AttributeChanged:Connect(function(attr)
    if attr == "Cash" then
        updateCashDisplay()
    end
    if attr == "PassiveRate" or attr == "PlayerUpgradeLevel" then
        updateRateDisplay()
    end
end)

-- Poll $/sec once per second (handles initial load + passive changes)
task.spawn(function()
    while true do
        updateRateDisplay()
        task.wait(1)
    end
end)

-- (Milestone logic moved to MilestoneUI.luau)

-- 4. Welcome Back Screen (shown when returning after offline earnings accrued)
local offlineEvent = remotes:WaitForChild("OfflineEarnings") :: RemoteEvent

-- Use shared FormatNumber module for all number/time formatting

local welcomeGui = Instance.new("ScreenGui")
welcomeGui.Name = "WelcomeBackGui"
welcomeGui.ResetOnSpawn = false
welcomeGui.DisplayOrder = 100 -- Render on top of everything
welcomeGui.Enabled = false
welcomeGui.Parent = playerGui

-- Dark overlay
local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.BorderSizePixel = 0
overlay.Parent = welcomeGui

-- Main card (centered)
local card = Instance.new("Frame")
card.Name = "WelcomeCard"
card.Size = UDim2.new(0, 420, 0, 320)
card.Position = UDim2.new(0.5, -210, 0.5, -160)
card.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
card.BorderSizePixel = 0
card.Parent = welcomeGui

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 20)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(255, 110, 0)
cardStroke.Thickness = 2.5
cardStroke.Parent = card

-- Basketball emoji label
local ballLabel = Instance.new("TextLabel")
ballLabel.Size = UDim2.new(1, 0, 0, 56)
ballLabel.Position = UDim2.new(0, 0, 0, 18)
ballLabel.BackgroundTransparency = 1
ballLabel.Text = "🏀"
ballLabel.TextSize = 48
ballLabel.Font = Enum.Font.GothamBold
ballLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ballLabel.Parent = card

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 0, 36)
titleLabel.Position = UDim2.new(0, 20, 0, 78)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Welcome Back!"
titleLabel.TextSize = 28
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.Parent = card

-- "You were away for..." label
local awayLabel = Instance.new("TextLabel")
awayLabel.Size = UDim2.new(1, -40, 0, 28)
awayLabel.Position = UDim2.new(0, 20, 0, 120)
awayLabel.BackgroundTransparency = 1
awayLabel.Text = "You were away for ..."
awayLabel.TextSize = 18
awayLabel.Font = Enum.Font.Gotham
awayLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
awayLabel.TextXAlignment = Enum.TextXAlignment.Center
awayLabel.Parent = card

-- Earned amount (big, orange, rolling)
local earnedLabel = Instance.new("TextLabel")
earnedLabel.Size = UDim2.new(1, -40, 0, 60)
earnedLabel.Position = UDim2.new(0, 20, 0, 158)
earnedLabel.BackgroundTransparency = 1
earnedLabel.Text = "+$0"
earnedLabel.TextSize = 44
earnedLabel.Font = Enum.Font.FredokaOne
earnedLabel.TextColor3 = Color3.fromRGB(255, 160, 30)
earnedLabel.TextXAlignment = Enum.TextXAlignment.Center
earnedLabel.Parent = card

-- "LET'S BALL" dismiss button
local ballBtn = Instance.new("TextButton")
ballBtn.Size = UDim2.new(0, 220, 0, 54)
ballBtn.Position = UDim2.new(0.5, -110, 1, -76)
ballBtn.BackgroundColor3 = Color3.fromRGB(255, 110, 0)
ballBtn.BorderSizePixel = 0
ballBtn.Text = "LET'S BALL!"
ballBtn.TextSize = 22
ballBtn.Font = Enum.Font.FredokaOne
ballBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ballBtn.AutoButtonColor = false
ballBtn.Parent = card

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0.4, 0)
btnCorner.Parent = ballBtn

-- Button hover/press tweens
local btnHover = TweenService:Create(ballBtn, TweenInfo.new(0.12), {
    BackgroundColor3 = Color3.fromRGB(255, 140, 30)
})
local btnLeave = TweenService:Create(ballBtn, TweenInfo.new(0.12), {
    BackgroundColor3 = Color3.fromRGB(255, 110, 0)
})
ballBtn.MouseEnter:Connect(function() btnHover:Play() end)
ballBtn.MouseLeave:Connect(function() btnLeave:Play() end)

-- Dismiss handler
ballBtn.MouseButton1Click:Connect(function()
    local hideTween = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 380, 0, 0),
        Position = UDim2.new(0.5, -190, 0.5, 0)
    })
    hideTween:Play()
    hideTween.Completed:Connect(function()
        welcomeGui.Enabled = false
    end)
end)

-- Listen for offline earnings from server
offlineEvent.OnClientEvent:Connect(function(offlineCash: number, timeAway: number)
    awayLabel.Text = string.format("You were away for %s", FormatNumber.formatTime(timeAway))

    -- Start card off-screen below, slide up into position
    card.Position = UDim2.new(0.5, -210, 1.2, 0)
    card.Size = UDim2.new(0, 420, 0, 320)
    earnedLabel.Text = "+$0"
    welcomeGui.Enabled = true

    local slideIn = TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -210, 0.5, -160)
    })
    slideIn:Play()

    -- Rolling number animation over 1.5 seconds
    local duration = 1.5
    local startTime = tick()
    local RunService = game:GetService("RunService")
    local conn: RBXScriptConnection
    conn = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        local t = math.min(elapsed / duration, 1)
        -- Ease-out cubic
        t = 1 - (1 - t) ^ 3
        local displayed = math.floor(offlineCash * t)
        earnedLabel.Text = "+$" .. FormatNumber.format(displayed)
        if elapsed >= duration then
            earnedLabel.Text = "+$" .. FormatNumber.format(offlineCash)
            conn:Disconnect()
        end
    end)
end)

print("[Client] HUD loaded successfully!")

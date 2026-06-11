--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FormatNumber = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatNumber"))
local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local shootRequest = remotes:WaitForChild("ShootRequest") :: RemoteEvent

local HUD = {}

function HUD.Initialize()
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

    shootButton.MouseEnter:Connect(function() hoverTween:Play() end)
    shootButton.MouseLeave:Connect(function() leaveTween:Play() end)
    shootButton.MouseButton1Down:Connect(function() pressTween:Play() end)
    shootButton.MouseButton1Up:Connect(function() hoverTween:Play() end)

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

    print("[Client] HUD Initialized!")
end

return HUD

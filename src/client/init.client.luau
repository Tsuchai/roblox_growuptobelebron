--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local VisualManager = require(script:WaitForChild("VisualManager"))
local PlacementManager = require(script:WaitForChild("PlacementManager"))
local ShopUI = require(script:WaitForChild("ShopUI"))

print("[Client] Initializing Grow Up to be LeBron...")

-- 1. Initialize Managers & UIs
VisualManager.Initialize()
PlacementManager.Initialize()
ShopUI.Initialize()

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
shootButton.Font = Enum.Font.FredokaOne
shootButton.Text = "SHOOT!"
shootButton.TextColor3 = Color3.fromRGB(255, 255, 255)
shootButton.TextSize = 28
shootButton.AutoButtonColor = false -- We'll customize the animation ourselves!
shootButton.Parent = screenGui

-- UI Corner for rounded look
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0.3, 0)
uiCorner.Parent = shootButton

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

print("[Client] HUD loaded successfully!")

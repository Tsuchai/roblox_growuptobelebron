--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local FormatNumber = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatNumber"))
local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local offlineEvent = remotes:WaitForChild("OfflineEarnings") :: RemoteEvent

local OfflineUI = {}

function OfflineUI.Initialize()
    local localPlayer = Players.LocalPlayer
    local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

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

    print("[Client] OfflineUI Initialized!")
end

return OfflineUI

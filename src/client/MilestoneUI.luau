--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FormatNumber = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatNumber"))
local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local rebirthNotify = remotes:WaitForChild("RebirthNotify") :: RemoteEvent

local MilestoneUI = {}

local MILESTONES = {1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000}
local MILESTONE_LABELS: {[number]: string} = {
    [1000]       = "$1K Reached! 🔥",
    [10000]      = "$10K Reached! 💪",
    [100000]     = "$100K Reached! ⭐",
    [1000000]    = "$1M Reached! 🏆",
    [10000000]   = "$10M Reached! 💸",
    [100000000]  = "$100M Reached! 👑",
    [1000000000] = "$1B LEBRON MODE! 🐐",
}

function MilestoneUI.Initialize()
    local localPlayer = Players.LocalPlayer
    local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
    local screenGui = playerGui:WaitForChild("LeBronHUD") :: ScreenGui
    
    local triggeredMilestones: {[number]: boolean} = {}
    
    local function showMilestoneBanner(amount: number)
        local labelText = MILESTONE_LABELS[amount] or ("$" .. FormatNumber.format(amount) .. " reached!")

        local banner = Instance.new("Frame")
        banner.Name = "MilestoneBanner"
        banner.Size = UDim2.new(0, 380, 0, 56)
        banner.Position = UDim2.new(0.5, -190, 0, -70) -- starts hidden above the screen
        banner.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
        banner.BorderSizePixel = 0
        banner.ZIndex = 10
        banner.Parent = screenGui

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 12)
        bCorner.Parent = banner

        local bStroke = Instance.new("UIStroke")
        bStroke.Color = Color3.fromRGB(255, 180, 0)
        bStroke.Thickness = 2
        bStroke.Parent = banner

        local bLabel = Instance.new("TextLabel")
        bLabel.Size = UDim2.new(1, -16, 1, 0)
        bLabel.Position = UDim2.new(0, 8, 0, 0)
        bLabel.BackgroundTransparency = 1
        bLabel.Font = Enum.Font.FredokaOne
        bLabel.Text = labelText
        bLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
        bLabel.TextSize = 22
        bLabel.TextXAlignment = Enum.TextXAlignment.Center
        bLabel.ZIndex = 11
        bLabel.Parent = banner

        -- Slide down from above into view (just below the cash HUD)
        local slideIn = TweenService:Create(banner,
            TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, -190, 0, 90)
            })
        slideIn:Play()

        -- Auto-dismiss after 2.5 seconds
        task.delay(2.5, function()
            local slideOut = TweenService:Create(banner,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(0.5, -190, 0, -70)
                })
            slideOut:Play()
            slideOut.Completed:Connect(function()
                banner:Destroy()
            end)
        end)
    end

    local firstCashLoad = true

    -- Pre-fill triggered milestones on join so they don't all trigger at once
    local function initMilestones()
        local initialCash = localPlayer:GetAttribute("Cash") or 0
        for _, threshold in ipairs(MILESTONES) do
            if initialCash >= threshold then
                triggeredMilestones[threshold] = true
            end
        end
    end
    initMilestones()

    -- Check milestones whenever Cash changes
    localPlayer.AttributeChanged:Connect(function(attr)
        if attr ~= "Cash" then return end
        local cash = localPlayer:GetAttribute("Cash") or 0
        
        if firstCashLoad then
            firstCashLoad = false
            -- Instead of triggering, just quietly initialize the milestones
            for _, threshold in ipairs(MILESTONES) do
                if cash >= threshold then
                    triggeredMilestones[threshold] = true
                end
            end
            return
        end
        
        for _, threshold in ipairs(MILESTONES) do
            if cash >= threshold and not triggeredMilestones[threshold] then
                triggeredMilestones[threshold] = true
                showMilestoneBanner(threshold)
            end
        end
    end)

    -- Reset milestones on each rebirth so the climb back up feels rewarding every time
    rebirthNotify.OnClientEvent:Connect(function()
        triggeredMilestones = {}
    end)
    
    print("[Client] MilestoneUI Initialized!")
end

return MilestoneUI

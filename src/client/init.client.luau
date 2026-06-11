--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualManager = require(script:WaitForChild("VisualManager"))
local PlacementManager = require(script:WaitForChild("PlacementManager"))
local ShopUI = require(script:WaitForChild("ShopUI"))
local TeamUI = require(script:WaitForChild("TeamUI"))
local MilestoneUI = require(script:WaitForChild("MilestoneUI"))
local HUD = require(script:WaitForChild("HUD"))
local OfflineUI = require(script:WaitForChild("OfflineUI"))

print("[Client] Initializing Grow Up to be LeBron...")

-- Initialize all client-side managers and UI modules
VisualManager.Initialize()
PlacementManager.Initialize()
ShopUI.Initialize()
TeamUI.Initialize()
HUD.Initialize()
MilestoneUI.Initialize()
OfflineUI.Initialize()

print("[Client] All Modules Successfully Initialized!")

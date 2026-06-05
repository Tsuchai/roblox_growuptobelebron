--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(script:WaitForChild("DataManager"))
local PlotManager = require(script:WaitForChild("PlotManager"))
local NetworkManager = require(script:WaitForChild("NetworkManager"))
local ShooterManager = require(script:WaitForChild("ShooterManager"))
local ShopManager = require(script:WaitForChild("ShopManager"))

print("[Server] Initializing Grow Up to be LeBron...")

-- Initialize central managers
DataManager.Initialize()
PlotManager.Initialize()
NetworkManager.Initialize()
ShooterManager.Initialize()
ShopManager.Initialize()

print("[Server] Game loaded successfully!")

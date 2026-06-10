--!strict
local Config = {}

-- Leaderstat default stats for new players
Config.StartingStats = {
    Cash = 0,
    Rebirths = 0,
    HoopUpgradeLevel = 1,
    LogoutTime = 0, -- os.time() stamped on logout; used for offline earnings calculation
    PlayerUpgradeLevel = 1, -- which PlayerUpgrades tier the player has purchased
    OwnedShooters = {
        Rookie = 0,
        College = 0,
        Pro = 0,
        AllStar = 0,
        LeBron = 0
    },
    ShooterPositions = {} -- elements: { Id = string, Tier = string, Pos = {number, number, number} }
}

-- Maximum number of shooters a player can place on the court
Config.MaxActiveShooters = 5


-- Distance Zones Configuration
-- Distance measured in Studs from the Hoop Rim center
Config.DistanceZones = {
    Paint = {
        MaxDistance = 15,
        Multiplier = 1.0,
        BaseAccuracy = 0.95, -- 95% make chance
        Name = "Paint"
    },
    MidRange = {
        MaxDistance = 30,
        Multiplier = 1.5,
        BaseAccuracy = 0.70, -- 70% make chance
        Name = "Mid-Range"
    },
    ThreePoint = {
        MaxDistance = 9999, -- anything past mid-range
        Multiplier = 3.0,
        BaseAccuracy = 0.45, -- 45% make chance
        Name = "3-Point Line"
    }
}

-- Shooter Attributes / Tags
-- These modify the stats of a shooter based on where they are placed
Config.Attributes = {
    Slasher = {
        DisplayName = "Slasher",
        PaintAccuracyBonus = 0.05, -- +5% accuracy in the paint
        PaintMultiplier = 1.5,     -- 1.5x score multiplier in the paint
    },
    MidRangeDeadeye = {
        DisplayName = "Mid-Range Deadeye",
        MidRangeAccuracyBonus = 0.15,
        MidRangeMultiplier = 1.5,
    },
    LimitlessRange = {
        DisplayName = "Limitless Range",
        ThreePointAccuracyBonus = 0.25, -- +25% accuracy from 3pt line
        ThreePointMultiplier = 2.0,    -- 2.0x score multiplier from 3pt line
    }
}

-- Shooter Tiers Configuration
-- Cooldown: seconds between shots
-- BaseYield: base cash earned per shot
-- Cost: price to purchase the first one (scales with current count)
-- CostScaleFactor: how much the price multiplies per already owned shooter of this tier
Config.Shooters = {
    Rookie = {
        DisplayName = "Rookie",
        Cooldown = 5.0,
        BaseYield = 10,
        BaseCost = 50,
        CostScaleFactor = 1.3,
        Attribute = "Slasher" -- Good in paint
    },
    College = {
        DisplayName = "College Player",
        Cooldown = 4.0,
        BaseYield = 40,
        BaseCost = 250,
        CostScaleFactor = 1.35,
        Attribute = "MidRangeDeadeye" -- Good at mid-range
    },
    Pro = {
        DisplayName = "Pro Player",
        Cooldown = 3.0,
        BaseYield = 150,
        BaseCost = 1200,
        CostScaleFactor = 1.4,
        Attribute = "LimitlessRange" -- Good at 3pt line
    },
    AllStar = {
        DisplayName = "All-Star Player",
        Cooldown = 2.0,
        BaseYield = 600,
        BaseCost = 6000,
        CostScaleFactor = 1.45,
        Attribute = "LimitlessRange"
    },
    LeBron = {
        DisplayName = "LeBron James",
        Cooldown = 1.5,
        BaseYield = 2500,
        BaseCost = 30000,
        CostScaleFactor = 1.5,
        Attribute = "LimitlessRange" -- Excellent everywhere
    }
}

-- Hoop Upgrades Configuration
-- Multiplier: multiplies all shot earnings
Config.Hoops = {
    [1] = { Name = "Wooden Hoop", Multiplier = 1, Cost = 0 },
    [2] = { Name = "Chain Net Hoop", Multiplier = 1.5, Cost = 150 },
    [3] = { Name = "Glass Backboard Hoop", Multiplier = 3, Cost = 750 },
    [4] = { Name = "Pro Rim Hoop", Multiplier = 7, Cost = 3500 },
    [5] = { Name = "Golden Hoop", Multiplier = 20, Cost = 15000 },
    [6] = { Name = "Diamond LeBron Rim", Multiplier = 100, Cost = 100000 }
}

-- Rebirth configuration
Config.Rebirth = {
    BaseCost = 50000,
    CostScaleFactor = 2.5, -- Cost = BaseCost * (CostScaleFactor ^ Rebirths)
    MultiplierPerRebirth = 0.5, -- +50% earnings per rebirth (e.g. 1 rebirth = 1.5x, 2 rebirths = 2x)
}

-- Active Player Click Configs
Config.PlayerShot = {
    Cooldown = 0.5, -- limit clicks to 2 per second max to avoid spam
    BaseYield = 5,
    -- Each manual shot also awards this many seconds' worth of passive NPC income on top of BaseYield.
    -- Tune this single value in Config to change how rewarding active play feels.
    PassiveScaleFactor = 0.5,
}

-- Helper function to determine which distance zone a shooter is in
function Config.GetDistanceZone(distance: number): any
    if distance <= Config.DistanceZones.Paint.MaxDistance then
        return Config.DistanceZones.Paint
    elseif distance <= Config.DistanceZones.MidRange.MaxDistance then
        return Config.DistanceZones.MidRange
    else
        return Config.DistanceZones.ThreePoint
    end
end

-- Helper functions for scaling
function Config.GetShooterCost(tier: string, currentOwned: number): number
    local shooter = Config.Shooters[tier]
    if not shooter then return math.huge end
    return math.floor(shooter.BaseCost * (shooter.CostScaleFactor ^ currentOwned))
end

function Config.GetRebirthCost(currentRebirths: number): number
    return math.floor(Config.Rebirth.BaseCost * (Config.Rebirth.CostScaleFactor ^ currentRebirths))
end

-- Player-specific shot multiplier upgrades (separate from hoop / rebirth)
-- Linear 5-level placeholder; to be reworked into a grid-based system in Phase 2.
Config.PlayerUpgrades = {
    [1] = { Name = "Raw Talent",        Multiplier = 1,  Cost = 0     },
    [2] = { Name = "Practice Regimen",  Multiplier = 2,  Cost = 500   },
    [3] = { Name = "Shooting Coach",    Multiplier = 4,  Cost = 3000  },
    [4] = { Name = "All-Star Training", Multiplier = 8,  Cost = 15000 },
    [5] = { Name = "LeBron Mode",       Multiplier = 20, Cost = 75000 },
}

-- Returns the cost to purchase the next player upgrade level.
-- Returns math.huge if already maxed (no next level exists).
function Config.GetPlayerUpgradeCost(currentLevel: number): number
    local next = Config.PlayerUpgrades[currentLevel + 1]
    return next and next.Cost or math.huge
end

return Config

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


-- Dynamic Shot Formula Constants
Config.ShotScaling = {
    MaxDistance = 60, -- roughly corner-to-corner on the half court
    BaseAccuracyClose = 0.95,
    BaseAccuracyFar = 0.35,
    BaseMultiplierClose = 1.0,
    BaseMultiplierFar = 4.0,
}

-- Shooter Attributes now use dynamic curves instead of discrete zones
Config.Attributes = {
    Slasher = {
        DisplayName = "Slasher",
        PeakDistance = 0,     -- Peaks at 0 studs (right under hoop)
        Falloff = 20,         -- Bonus falls off to 0 after 20 studs
        MaxAccuracyBonus = 0.10,
        MaxMultiplierBonus = 0.5,
    },
    MidRangeDeadeye = {
        DisplayName = "Mid-Range Deadeye",
        PeakDistance = 25,    -- Peaks around 25 studs
        Falloff = 15,         -- Bonus falls off 15 studs away from peak
        MaxAccuracyBonus = 0.15,
        MaxMultiplierBonus = 0.8,
    },
    LimitlessRange = {
        DisplayName = "Limitless Range",
        PeakDistance = 50,    -- Peaks at 50 studs (deep 3)
        Falloff = 30,         -- Starts applying 30 studs before peak (at 20 studs)
        MaxAccuracyBonus = 0.25,
        MaxMultiplierBonus = 2.0,
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
        AttributeChances = {
            Slasher = 0.80,
            MidRangeDeadeye = 0.15,
            LimitlessRange = 0.05
        }
    },
    College = {
        DisplayName = "College Player",
        Cooldown = 4.0,
        BaseYield = 40,
        BaseCost = 250,
        CostScaleFactor = 1.35,
        AttributeChances = {
            Slasher = 0.30,
            MidRangeDeadeye = 0.60,
            LimitlessRange = 0.10
        }
    },
    Pro = {
        DisplayName = "Pro Player",
        Cooldown = 3.0,
        BaseYield = 150,
        BaseCost = 1200,
        CostScaleFactor = 1.4,
        AttributeChances = {
            Slasher = 0.15,
            MidRangeDeadeye = 0.35,
            LimitlessRange = 0.50
        }
    },
    AllStar = {
        DisplayName = "All-Star Player",
        Cooldown = 2.0,
        BaseYield = 600,
        BaseCost = 6000,
        CostScaleFactor = 1.45,
        AttributeChances = {
            Slasher = 0.10,
            MidRangeDeadeye = 0.20,
            LimitlessRange = 0.70
        }
    },
    LeBron = {
        DisplayName = "LeBron James",
        Cooldown = 1.5,
        BaseYield = 2500,
        BaseCost = 30000,
        CostScaleFactor = 1.5,
        AttributeChances = {
            Slasher = 0.0,
            MidRangeDeadeye = 0.0,
            LimitlessRange = 1.0
        }
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

-- Returns the dynamically calculated accuracy and multiplier for a given distance and optional attribute
function Config.GetShotStats(distance: number, attributeName: string?): { Accuracy: number, Multiplier: number, Name: string }
    -- Base linear scaling
    local t = math.clamp(distance / Config.ShotScaling.MaxDistance, 0, 1)
    
    local baseAccuracy = Config.ShotScaling.BaseAccuracyClose + (Config.ShotScaling.BaseAccuracyFar - Config.ShotScaling.BaseAccuracyClose) * t
    local baseMultiplier = Config.ShotScaling.BaseMultiplierClose + (Config.ShotScaling.BaseMultiplierFar - Config.ShotScaling.BaseMultiplierClose) * t
    
    local finalAccuracy = baseAccuracy
    local finalMultiplier = baseMultiplier
    
    -- Apply dynamic attribute curves
    if attributeName and Config.Attributes[attributeName] then
        local attr = Config.Attributes[attributeName]
        local distFromPeak = math.abs(distance - attr.PeakDistance)
        
        -- Linear falloff from peak
        local bonusT = math.clamp(1 - (distFromPeak / attr.Falloff), 0, 1)
        
        finalAccuracy += attr.MaxAccuracyBonus * bonusT
        finalMultiplier += attr.MaxMultiplierBonus * bonusT
    end
    
    -- Determine a dynamic name for flavor
    local zoneName = "Paint"
    if distance > 30 then zoneName = "3-Point"
    elseif distance > 15 then zoneName = "Mid-Range" end
    
    return {
        Accuracy = math.clamp(finalAccuracy, 0, 1),
        Multiplier = finalMultiplier,
        Name = zoneName
    }
end

-- Rolls stats for a newly purchased shooter, applying +/- 10% randomness
function Config.RollShooterStats(tier: string): { Attribute: string, BaseYield: number, Cooldown: number }
    local shooter = Config.Shooters[tier]
    if not shooter then return { Attribute = "Slasher", BaseYield = 0, Cooldown = 1 } end
    
    -- Select Attribute based on chances
    local roll = math.random()
    local cumulative = 0
    local selectedAttribute = "Slasher"
    
    for attr, chance in pairs(shooter.AttributeChances) do
        cumulative += chance
        if roll <= cumulative then
            selectedAttribute = attr
            break
        end
    end
    
    -- Randomize stats +/- 10%
    local yieldVariance = 0.9 + (math.random() * 0.2)
    local cooldownVariance = 0.9 + (math.random() * 0.2)
    
    local finalYield = math.max(1, math.floor(shooter.BaseYield * yieldVariance))
    local finalCooldown = math.max(0.1, shooter.Cooldown * cooldownVariance)
    
    return {
        Attribute = selectedAttribute,
        BaseYield = finalYield,
        Cooldown = finalCooldown
    }
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

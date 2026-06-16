--!strict
local Lighting = game:GetService("Lighting")

local LightingManager = {}

function LightingManager.Initialize()
    -- Base Lighting Settings for a soft, vibrant low-poly look
    Lighting.Ambient = Color3.fromRGB(120, 140, 170)
    Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 160)
    Lighting.Brightness = 2.5
    Lighting.GlobalShadows = true
    Lighting.ClockTime = 14 -- Nice afternoon sun
    Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 220)
    Lighting.ColorShift_Bottom = Color3.fromRGB(160, 180, 200)
    Lighting.EnvironmentDiffuseScale = 0.5
    Lighting.EnvironmentSpecularScale = 0.2
    Lighting.ShadowSoftness = 0.8
    Lighting.GeographicLatitude = 41.73

    -- Color Correction for vibrant pastel colors
    local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not colorCorrection then
        colorCorrection = Instance.new("ColorCorrectionEffect")
        colorCorrection.Parent = Lighting
    end
    colorCorrection.Brightness = 0.05
    colorCorrection.Contrast = 0.15
    colorCorrection.Saturation = 0.4
    colorCorrection.TintColor = Color3.fromRGB(255, 245, 235)

    -- Bloom to give light surfaces a soft glow
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Parent = Lighting
    end
    bloom.Intensity = 0.2
    bloom.Size = 20
    bloom.Threshold = 2

    -- Sun Rays to make the sky feel alive
    local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
    if not sunRays then
        sunRays = Instance.new("SunRaysEffect")
        sunRays.Parent = Lighting
    end
    sunRays.Intensity = 0.05
    sunRays.Spread = 0.5

    -- Depth of Field for a subtle tilt-shift/miniature effect (makes the plot look toy-like)
    local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
    if not dof then
        dof = Instance.new("DepthOfFieldEffect")
        dof.Parent = Lighting
    end
    dof.FarIntensity = 0.15
    dof.FocusDistance = 25
    dof.InFocusRadius = 40
    dof.NearIntensity = 0
    
    print("[Client] LightingManager Initialized - Vibrant low-poly aesthetic applied!")
end

return LightingManager

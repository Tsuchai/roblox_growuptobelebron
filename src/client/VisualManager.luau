--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local VisualManager = {}

-- Audio Assets (Roblox standard library IDs)
local SWISH_SOUND_ID = "rbxassetid://12544690"       -- Net swish
local CLANK_SOUND_ID = "rbxassetid://9116541004"     -- Metal Clang 17
local BOUNCE_SOUND_ID = "rbxassetid://377958030"     -- Basketball bounce

-- Helper to play a sound locally at a position
local function playSoundAtPosition(soundId: string, position: Vector3, volume: number?)
    local tempPart = Instance.new("Part")
    tempPart.Size = Vector3.new(1, 1, 1)
    tempPart.Position = position
    tempPart.Transparency = 1
    tempPart.Anchored = true
    tempPart.CanCollide = false
    tempPart.Parent = Workspace
    
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume or 0.8
    sound.Parent = tempPart
    sound:Play()
    
    sound.Ended:Connect(function()
        tempPart:Destroy()
    end)
end

-- Helper to calculate a quadratic Bezier point
local function getBezierPoint(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
    return (1 - t)^2 * p0 + 2 * (1 - t) * t * p1 + t^2 * p2
end

-- Displays a floating 3D text showing +Cash or +Score above the hoop
local function spawnScoringText(position: Vector3, isMake: boolean)
    local textModel = Instance.new("Part")
    textModel.Size = Vector3.new(4, 2, 1)
    textModel.Position = position + Vector3.new(0, 3, 0)
    textModel.Transparency = 1
    textModel.Anchored = true
    textModel.CanCollide = false
    textModel.Parent = Workspace
    
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(4, 0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = textModel
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.FredokaOne
    label.TextScaled = true
    
    if isMake then
        label.Text = "SWISH! +Score"
        label.TextColor3 = Color3.fromRGB(0, 255, 100) -- Green
    else
        label.Text = "MISS!"
        label.TextColor3 = Color3.fromRGB(255, 50, 50) -- Red
    end
    label.Parent = billboard
    
    -- Animate the text floating upwards and fading out
    local targetPos = textModel.Position + Vector3.new(0, 4, 0)
    local tweenInfo = TweenInfo.new(1.0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    
    local posTween = TweenService:Create(textModel, tweenInfo, { Position = targetPos })
    local fadeTween = TweenService:Create(label, tweenInfo, { TextTransparency = 1 })
    
    posTween:Play()
    fadeTween:Play()
    
    posTween.Completed:Connect(function()
        textModel:Destroy()
    end)
end

-- Spawns particle flash inside the net
local function spawnMakeParticles(position: Vector3)
    local particles = Instance.new("Attachment")
    particles.Position = position
    particles.Parent = Workspace.Terrain
    
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)), -- Gold sparks
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
    })
    emitter.Size = NumberSequence.new(0.2, 0.6)
    emitter.Lifetime = NumberRange.new(0.5, 0.8)
    emitter.Rate = 50
    emitter.Speed = NumberRange.new(5, 10)
    emitter.SpreadAngle = Vector2.new(45, 45)
    emitter.Parent = particles
    
    task.wait(0.2)
    emitter.Enabled = false
    task.wait(1.0)
    particles:Destroy()
end

-- Core shot renderer
function VisualManager.RenderShot(shooterName: string, origin: Vector3, target: Vector3, isMake: boolean)
    -- 1. Create a local basketball part
    local ball = Instance.new("Part")
    ball.Name = "LocalBasketball"
    ball.Size = Vector3.new(1.2, 1.2, 1.2)
    ball.Shape = Enum.PartType.Ball
    ball.Color = Color3.fromRGB(220, 90, 30) -- Classic basketball orange
    ball.Material = Enum.Material.CorrodedMetal -- Nice textured leather look
    ball.Anchored = true
    ball.CanCollide = false
    ball.Parent = Workspace
    
    -- 2. Setup Bezier curve control points
    local startPos = origin
    local endPos = target
    
    if not isMake then
        -- Miss path: target is offset slightly to hit the rim edge
        local angle = math.random() * math.pi * 2
        local rimOffset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 2.0 -- Rim radius is ~2
        endPos = target + rimOffset + Vector3.new(0, 0.2, 0)
    end
    
    local distance = (startPos - endPos).Magnitude
    -- Height of arc is proportional to shot distance
    local arcHeight = (distance * 0.35) + 4
    local controlPos = (startPos + endPos) / 2 + Vector3.new(0, arcHeight, 0)
    
    -- 3. Run Bezier animation loop
    local duration = 0.8 -- Travel time in seconds
    local elapsed = 0
    
    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        local t = math.clamp(elapsed / duration, 0, 1)
        
        -- Update ball position
        ball.Position = getBezierPoint(startPos, controlPos, endPos, t)
        
        -- Rotate ball during flight (spin effect)
        ball.Rotation = ball.Rotation + Vector3.new(10, 5, 0)
        
        if t >= 1 then
            connection:Disconnect()
            
            -- Ball reached the target hoop position
            if isMake then
                playSoundAtPosition(SWISH_SOUND_ID, target, 0.8)
                spawnMakeParticles(target)
                spawnScoringText(target, true)
                
                -- Let the ball fall cleanly down through the net
                local fallTarget = target - Vector3.new(0, 4, 0)
                local fallTween = TweenService:Create(ball, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = fallTarget,
                    Transparency = 1
                })
                fallTween:Play()
                fallTween.Completed:Connect(function()
                    ball:Destroy()
                end)
            else
                playSoundAtPosition(CLANK_SOUND_ID, endPos, 0.9)
                spawnScoringText(target, false)
                
                -- Animate ball bouncing off the rim
                local bounceTarget = endPos + Vector3.new(math.random(-10, 10), -10, math.random(-10, 10))
                local bounceControl = endPos + Vector3.new(math.random(-5, 5), 8, math.random(-5, 5))
                
                local bounceElapsed = 0
                local bounceDuration = 0.6
                local bounceConnection
                
                bounceConnection = RunService.Heartbeat:Connect(function(bDt)
                    bounceElapsed = bounceElapsed + bDt
                    local bT = math.clamp(bounceElapsed / bounceDuration, 0, 1)
                    
                    ball.Position = getBezierPoint(endPos, bounceControl, bounceTarget, bT)
                    
                    if bT >= 1 then
                        bounceConnection:Disconnect()
                        playSoundAtPosition(BOUNCE_SOUND_ID, bounceTarget, 0.5)
                        ball:Destroy()
                    end
                end)
            end
        end
    end)
end

function VisualManager.Initialize()
    local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
    local renderEvent = remotes:WaitForChild("RenderShot") :: RemoteEvent
    
    -- Listen to server-side shot requests
    renderEvent.OnClientEvent:Connect(function(shooterName, origin, target, isMake)
        if typeof(origin) == "Vector3" and typeof(target) == "Vector3" then
            VisualManager.RenderShot(tostring(shooterName), origin, target, isMake)
        end
    end)
    
    print("[Client] VisualManager Initialized!")
end

return VisualManager

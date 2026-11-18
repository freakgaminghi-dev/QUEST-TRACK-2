-- ButtonEffects v2  (LocalScript)
-- WHERE: StarterPlayer > StarterPlayerScripts  ->  LocalScript  ->  name it "ButtonEffects"
-- PLACE: BOTH the Lobby and the Game place
--
-- Makes EVERY button (ImageButton and TextButton) POP the moment you press it:
--   * POP:      jumps big right away, then wobbles back like jelly
--   * FLASH:    a quick white flash on the button
--   * RING:     a ring bursts out from the button
--   * RIPPLE:   a circle wave spreads from where you pressed
--   * SPARKLES: little gold diamonds fly out
--   * WIGGLE:   a tiny shake
--   * SOUND:    a pop/click sound
--   * HOVER:    grows bigger when the mouse is on it (PC), evenly in every direction from its center
-- It finds buttons by itself, also ones that other scripts make later. Your buttons still work the same.
--
-- To turn effects OFF for one button: select it in Studio, add an Attribute called NoEffects
-- (type: boolean) and tick it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------- CONFIG ----------------
local POP_SCALE           = 1.25    -- how big it jumps when pressed (1 = no pop)
local POP_UP_TIME         = 0.08    -- seconds to jump big
local POP_BACK_TIME       = 0.6     -- seconds to wobble back
local HOVER_SCALE         = 1.12    -- size when the mouse is on the button (1 = no change, 1.12 = 12% bigger)
local HOVER_TIME          = 0.18    -- seconds to grow when the mouse goes on it
local CENTER_GROW         = true    -- true = buttons grow from their CENTER in every direction (not just down-right)

local FLASH               = true    -- quick white flash on the button
local FLASH_TRANSPARENCY  = 0.4     -- how strong the flash is (0 = solid white, 1 = invisible)

local RING                = true    -- a ring bursts out from the button
local RING_COLOR          = Color3.fromRGB(255, 255, 255)
local RING_THICKNESS      = 3       -- pixels
local RING_SIZE           = 1.5     -- how big the ring gets (x the button size)

local RIPPLE              = true    -- circle wave from where you pressed
local RIPPLE_COLOR        = Color3.fromRGB(255, 255, 255)
local RIPPLE_TRANSPARENCY = 0.5
local RIPPLE_SIZE         = 1.8     -- x the button width
local RIPPLE_TIME         = 0.45

local SPARKLES            = true    -- little diamonds fly out
local SPARKLE_COUNT       = 10
local SPARKLE_COLOR       = Color3.fromRGB(255, 230, 120) -- gold
local SPARKLE_SIZE        = 8       -- pixels
local SPARKLE_DISTANCE    = 60      -- how far they fly (pixels)

local WIGGLE_DEGREES      = 5       -- tiny shake (0 = no shake)

local CLICK_SOUND_ID      = "rbxasset://sounds/button.wav" -- pop sound ("" = no sound). You can use "rbxassetid://12345"
local CLICK_VOLUME        = 0.5
local HOVER_SOUND_ID      = ""      -- sound when the mouse goes on a button ("" = none)
local HOVER_VOLUME        = 0.25
----------------------------------------

local rng = Random.new()

local function makeSound(id, volume)
    if id == "" then return nil end
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = volume
    s.Parent = script
    return s
end
local clickSound = makeSound(CLICK_SOUND_ID, CLICK_VOLUME)
local hoverSound = makeSound(HOVER_SOUND_ID, HOVER_VOLUME)

local function playSound(s)
    if s then SoundService:PlayLocalSound(s) end
end

-- the UIScale on the button (shared with UIScaler, which stores the screen size in "Base")
local function getScale(button)
    local s = button:FindFirstChildOfClass("UIScale")
    if not s then
        s = Instance.new("UIScale")
        s.Name = "AutoScale"
        s:SetAttribute("Base", 1)
        s.Parent = button
    end
    if s:GetAttribute("Base") == nil then s:SetAttribute("Base", s.Scale) end
    return s
end

local function tweenScale(button, mult, time, style)
    local s = getScale(button)
    local base = s:GetAttribute("Base") or 1
    local tween = TweenService:Create(s, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Scale = base * mult,
    })
    tween:Play()
    return tween
end

-- an effect frame that UIScaler leaves alone
local function effectFrame(button, name, zOffset)
    local f = Instance.new("Frame")
    f.Name = name
    f:SetAttribute("NoAutoScale", true)
    f.BorderSizePixel = 0
    f.ZIndex = button.ZIndex + zOffset
    return f
end

-- where on the button you pressed (0..1), or the middle if we can't tell
local function pressSpot(button, input)
    local ap, as = button.AbsolutePosition, button.AbsoluteSize
    if input and as.X > 0 and as.Y > 0 then
        local rx = (input.Position.X - ap.X) / as.X
        local ry = (input.Position.Y - ap.Y) / as.Y
        if rx >= 0 and rx <= 1 and ry >= 0 and ry <= 1 then return rx, ry end
    end
    return 0.5, 0.5
end

local function flash(button)
    local f = effectFrame(button, "PressFlash", 4)
    f.Size = UDim2.fromScale(1, 1)
    f.BackgroundColor3 = Color3.new(1, 1, 1)
    f.BackgroundTransparency = FLASH_TRANSPARENCY
    local corner = button:FindFirstChildOfClass("UICorner")
    if corner then corner:Clone().Parent = f end -- same rounded corners as the button
    f.Parent = button
    TweenService:Create(f, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1,
    }):Play()
    Debris:AddItem(f, 0.3)
end

local function ring(button)
    local r = effectFrame(button, "PressRing", 3)
    r.AnchorPoint = Vector2.new(0.5, 0.5)
    r.Position = UDim2.fromScale(0.5, 0.5)
    r.Size = UDim2.fromScale(1, 1)
    r.BackgroundTransparency = 1
    local corner = button:FindFirstChildOfClass("UICorner")
    if corner then corner:Clone().Parent = r end
    local stroke = Instance.new("UIStroke")
    stroke.Color = RING_COLOR
    stroke.Thickness = RING_THICKNESS
    stroke.Transparency = 0
    stroke.Parent = r
    r.Parent = button
    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(r, info, { Size = UDim2.fromScale(RING_SIZE, RING_SIZE) }):Play()
    TweenService:Create(stroke, info, { Transparency = 1, Thickness = 0 }):Play()
    Debris:AddItem(r, 0.4)
end

local function ripple(button, rx, ry)
    local r = effectFrame(button, "PressRipple", 5)
    r.AnchorPoint = Vector2.new(0.5, 0.5)
    r.Position = UDim2.fromScale(rx, ry)
    r.Size = UDim2.fromScale(0, 0)
    r.BackgroundColor3 = RIPPLE_COLOR
    r.BackgroundTransparency = RIPPLE_TRANSPARENCY
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0) -- makes it a circle
    corner.Parent = r
    local ratio = Instance.new("UIAspectRatioConstraint")
    ratio.AspectRatio = 1
    ratio.Parent = r
    r.Parent = button
    TweenService:Create(r, TweenInfo.new(RIPPLE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(RIPPLE_SIZE, RIPPLE_SIZE),
        BackgroundTransparency = 1,
    }):Play()
    Debris:AddItem(r, RIPPLE_TIME + 0.05)
end

local function sparkles(button, rx, ry)
    for i = 1, SPARKLE_COUNT do
        local s = effectFrame(button, "PressSparkle", 6)
        s.AnchorPoint = Vector2.new(0.5, 0.5)
        s.Position = UDim2.fromScale(rx, ry)
        s.Size = UDim2.fromOffset(SPARKLE_SIZE, SPARKLE_SIZE)
        s.Rotation = 45 -- a diamond
        s.BackgroundColor3 = SPARKLE_COLOR
        s.Parent = button

        local angle = (i / SPARKLE_COUNT) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
        local dist = SPARKLE_DISTANCE * rng:NextNumber(0.6, 1.2)
        local time = rng:NextNumber(0.35, 0.55)
        TweenService:Create(s, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(rx, math.cos(angle) * dist, ry, math.sin(angle) * dist),
            Size = UDim2.fromOffset(0, 0),
            Rotation = 225,
            BackgroundTransparency = 1,
        }):Play()
        Debris:AddItem(s, time + 0.05)
    end
end

-- moves the button's AnchorPoint to its middle (without moving the button), so it grows evenly in every direction
local function centerAnchor(button)
    if not CENTER_GROW then return end
    if button.Parent and button.Parent:FindFirstChildWhichIsA("UIGridStyleLayout") then return end -- a layout places it
    local a = button.AnchorPoint
    if a.X == 0.5 and a.Y == 0.5 then return end
    local s, p = button.Size, button.Position
    local scale = button:FindFirstChildOfClass("UIScale")
    local f = scale and (scale:GetAttribute("Base") or scale.Scale) or 1
    local dx, dy = (0.5 - a.X) * f, (0.5 - a.Y) * f
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.Position = UDim2.new(
        p.X.Scale + s.X.Scale * dx, p.X.Offset + s.X.Offset * dx,
        p.Y.Scale + s.Y.Scale * dy, p.Y.Offset + s.Y.Offset * dy)
end

local hooked = setmetatable({}, { __mode = "k" })

local function hook(button)
    if hooked[button] or not button.Parent or button:GetAttribute("NoEffects") then return end
    hooked[button] = true
    centerAnchor(button)

    local hovering = false
    local baseRotation = button.Rotation
    -- buttons with a list/grid layout inside would move our effects around, so skip the extra effects there
    local canDecorate = button:FindFirstChildWhichIsA("UIGridStyleLayout") == nil

    button.MouseEnter:Connect(function()
        hovering = true
        tweenScale(button, HOVER_SCALE, HOVER_TIME, Enum.EasingStyle.Back) -- grows with a little bounce
        playSound(hoverSound)
    end)

    button.MouseLeave:Connect(function()
        hovering = false
        tweenScale(button, 1, 0.15)
    end)

    -- THE POP: happens the moment you press
    button.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
        if not button.Active or not button.Visible then return end

        -- jump big, then wobble back like jelly
        local up = tweenScale(button, POP_SCALE, POP_UP_TIME)
        up.Completed:Once(function(state)
            if state == Enum.PlaybackState.Completed then
                tweenScale(button, hovering and HOVER_SCALE or 1, POP_BACK_TIME, Enum.EasingStyle.Elastic)
            end
        end)

        -- tiny shake
        if WIGGLE_DEGREES > 0 then
            button.Rotation = baseRotation
            local side = rng:NextInteger(0, 1) == 0 and -1 or 1
            TweenService:Create(button, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true), {
                Rotation = baseRotation + WIGGLE_DEGREES * side,
            }):Play()
        end

        if canDecorate then
            local rx, ry = pressSpot(button, input)
            if FLASH then flash(button) end
            if RING then ring(button) end
            if RIPPLE then ripple(button, rx, ry) end
            if SPARKLES then sparkles(button, rx, ry) end
        end

        playSound(clickSound)
    end)

    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then hovering = false end -- phones have no hover
    end)
end

for _, d in ipairs(playerGui:GetDescendants()) do
    if d:IsA("GuiButton") then hook(d) end
end
playerGui.DescendantAdded:Connect(function(d)
    if d:IsA("GuiButton") then task.defer(hook, d) end
end)

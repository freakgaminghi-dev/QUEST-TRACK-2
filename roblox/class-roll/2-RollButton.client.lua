-- RollButton v2  (LocalScript)
-- WHERE: INSIDE your own roll ImageButton  (StarterGui > your ScreenGui > your ImageButton > this LocalScript)
-- PLACE: LOBBY (or wherever you want to roll)
--
-- Press your button = spend Bounty and roll a random class into your EQUIPPED slot (ClassSystem decides it).
-- The class names spin faster-to-slower like a slot machine, then a big "YOU GOT" panel pops up in the
-- middle of the screen with your new class in its rarity colour (Legendary flashes rainbow!).
-- All text uses the Press Start 2P pixel font.
--
-- THE TEXT: put a TextLabel named "ClassText" anywhere in the same ScreenGui to show the spinning names.
-- If there isn't one, this script makes one above the middle of the screen by itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local button = script.Parent

---------------- CONFIG ----------------
local FONT_FACE      = Font.new("rbxasset://fonts/families/PressStart2P.json") -- Press Start 2P (pixel font)
local LABEL_NAME     = "ClassText"     -- name of the TextLabel that shows the roll
local ROLL_TIME      = 2.2             -- seconds the names spin before showing your class
local PRICE_TEXT     = "ROLL\n%d Bounty" -- text on the button (%d = the price)
local SHOW_PRICE     = true            -- false = don't put text on your button
local IDLE_TEXT      = "Class: %s"     -- text when not rolling (%s = your class)
local NO_CLASS_TEXT  = "No class yet!"
local ERROR_COLOR    = Color3.fromRGB(255, 80, 80)
local TEXT_COLOR     = Color3.fromRGB(255, 255, 255)
local MESSAGE_TIME   = 2.5             -- seconds an error stays before going back to "Class: ..."

-- the big result panel when the roll ends
local SHOW_REVEAL    = true            -- false = no big panel
local REVEAL_TITLE   = "YOU GOT"       -- small text on top of the panel
local REVEAL_TIME    = 3               -- seconds the panel stays
local REVEAL_BG      = Color3.fromRGB(20, 20, 30) -- panel colour
----------------------------------------

if not button:IsA("GuiButton") then
    warn("[RollButton] This script must be INSIDE an ImageButton (or TextButton)")
    return
end

local remote = ReplicatedStorage:WaitForChild("RollClass", 10)
if not remote then
    warn("[RollButton] ClassSystem isn't running - put the ClassSystem script in ServerScriptService")
    return
end

local classes = {}
local okList, decoded = pcall(function()
    return HttpService:JSONDecode(remote:GetAttribute("ClassList") or "[]")
end)
if okList and type(decoded) == "table" then classes = decoded end

local function colorOf(name)
    for _, c in ipairs(classes) do
        if c.name == name then return Color3.fromHex(c.color) end
    end
    return TEXT_COLOR
end

local function newText(parent, name)
    local t = Instance.new("TextLabel")
    t.Name = name
    t.BackgroundTransparency = 1
    t.TextScaled = true
    t.FontFace = FONT_FACE
    t.TextStrokeTransparency = 0
    t.TextColor3 = TEXT_COLOR
    t.Parent = parent
    return t
end

---------------- THE TEXT LABEL ----------------
local screenGui = button:FindFirstAncestorOfClass("ScreenGui")
local label = screenGui and screenGui:FindFirstChild(LABEL_NAME, true)
if label and label:IsA("TextLabel") then
    label.FontFace = FONT_FACE -- your own label gets the pixel font too
elseif screenGui then
    label = newText(screenGui, LABEL_NAME)
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(0.5, 0.2)
    label.Size = UDim2.fromScale(0.45, 0.08)
end

local popScale = label and Instance.new("UIScale")
if popScale then
    popScale.Name = "RollPop"
    popScale.Parent = label
end

-- price text on the button
if SHOW_PRICE then
    local price = newText(button, "RollPrice")
    price.AnchorPoint = Vector2.new(0.5, 1)
    price.Position = UDim2.fromScale(0.5, 0.95)
    price.Size = UDim2.fromScale(0.9, 0.35)
    price.TextColor3 = Color3.fromRGB(255, 205, 50)
    price.ZIndex = button.ZIndex + 1
    price.Text = string.format(PRICE_TEXT, remote:GetAttribute("RollCost") or 0)
end
-------------------------------------------------

local rolling = false
local showingMessage = false

local function showIdle()
    if not label or rolling or showingMessage then return end
    local cls = player:GetAttribute("Class")
    if cls then
        label.Text = string.format(IDLE_TEXT, cls)
        label.TextColor3 = colorOf(cls)
    else
        label.Text = NO_CLASS_TEXT
        label.TextColor3 = TEXT_COLOR
    end
end
showIdle()
player:GetAttributeChangedSignal("Class"):Connect(showIdle)

local function pop(size, time)
    if not popScale then return end
    popScale.Scale = size
    TweenService:Create(popScale, TweenInfo.new(time, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function message(text, color)
    if not label then return end
    showingMessage = true
    label.Text = text
    label.TextColor3 = color
    task.delay(MESSAGE_TIME, function()
        showingMessage = false
        showIdle()
    end)
end

---------------- THE BIG "YOU GOT" PANEL ----------------
local function showReveal(className, rarity)
    if not SHOW_REVEAL or not screenGui then return end
    local old = screenGui:FindFirstChild("ClassReveal")
    if old then old:Destroy() end
    local color = colorOf(className)

    local panel = Instance.new("Frame")
    panel.Name = "ClassReveal"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.45)
    panel.Size = UDim2.fromScale(0.5, 0.3)
    panel.BackgroundColor3 = REVEAL_BG
    panel.BackgroundTransparency = 0.15
    panel.ZIndex = 50
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.08, 0)
    corner.Parent = panel
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 4
    stroke.Parent = panel
    local shape = Instance.new("UIAspectRatioConstraint")
    shape.AspectRatio = 2.4
    shape.Parent = panel

    local title = newText(panel, "Title")
    title.Text = REVEAL_TITLE
    title.Position = UDim2.fromScale(0.1, 0.1)
    title.Size = UDim2.fromScale(0.8, 0.16)
    title.ZIndex = 51

    local name = newText(panel, "ClassName")
    name.Text = className
    name.TextColor3 = color
    name.Position = UDim2.fromScale(0.05, 0.32)
    name.Size = UDim2.fromScale(0.9, 0.36)
    name.ZIndex = 51

    local rarityText = newText(panel, "Rarity")
    rarityText.Text = rarity or ""
    rarityText.TextColor3 = color
    rarityText.Position = UDim2.fromScale(0.2, 0.74)
    rarityText.Size = UDim2.fromScale(0.6, 0.14)
    rarityText.ZIndex = 51

    local scale = Instance.new("UIScale")
    scale.Scale = 0
    scale.Parent = panel
    panel.Parent = screenGui
    TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

    -- Legendary: rainbow colours
    local start = os.clock()
    if rarity == "Legendary" then
        task.spawn(function()
            while panel.Parent and os.clock() - start < REVEAL_TIME do
                local c = Color3.fromHSV((os.clock() * 0.8) % 1, 0.8, 1)
                name.TextColor3 = c
                stroke.Color = c
                task.wait()
            end
        end)
    end

    -- fade away
    task.delay(REVEAL_TIME, function()
        if not panel.Parent then return end
        local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        TweenService:Create(scale, info, { Scale = 0 }):Play()
        task.wait(0.45)
        if panel.Parent then panel:Destroy() end
    end)
end
----------------------------------------------------------

---------------- PRESS ----------------
button.Activated:Connect(function()
    if rolling then return end
    rolling = true

    local ok, success, className, info = pcall(function()
        return remote:InvokeServer()
    end)
    if not ok or not success then
        rolling = false
        local text = (not ok) and "Try again" or (info == "Not enough Bounty" and "Not enough Bounty!" or (info or "Can't roll"))
        message(text, ERROR_COLOR)
        pop(1.2, 0.4)
        return
    end

    -- slot machine: spin random names, starting fast and slowing down
    if label and #classes > 0 then
        local start = os.clock()
        local delayTime = 0.04
        local last
        while os.clock() - start < ROLL_TIME do
            local c
            repeat c = classes[math.random(1, #classes)] until #classes == 1 or c.name ~= last
            last = c.name
            label.Text = c.name
            label.TextColor3 = Color3.fromHex(c.color)
            pop(1.08, 0.15)
            task.wait(delayTime)
            delayTime *= 1.12
        end
    end

    -- the real result
    rolling = false
    if label then
        label.Text = className .. "!"
        label.TextColor3 = colorOf(className)
        local big = info == "Legendary" and 1.8 or (info == "Epic" and 1.6 or 1.4)
        pop(big, 0.8)
        showingMessage = true
        task.delay(REVEAL_TIME, function()
            showingMessage = false
            showIdle()
        end)
    end
    showReveal(className, info)
end)
---------------------------------------

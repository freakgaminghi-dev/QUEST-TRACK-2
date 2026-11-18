-- UIScaler v2  (LocalScript)
-- WHERE: StarterPlayer > StarterPlayerScripts  ->  LocalScript  ->  name it "UIScaler"
-- PLACE: BOTH the Lobby and the Game place
--
-- Makes ALL your UI fit every screen: phone, tablet, PC and big TVs.
-- How it works:
--   * Things sized in PIXELS (offset) get shrunk/grown to match the player's screen.
--   * Pixel positions are turned into screen-% so buttons stay in the same spot on every screen.
--   * Buttons and images sized in SCREEN-% keep their SHAPE (no more squished or stretched buttons).
--   * Small screens (phones) get a little extra size so fingers can hit the buttons.
--   * It also works on UI that other scripts make later, and when the window is resized / phone rotated.
--
-- To make the script IGNORE something: select the ScreenGui or object in Studio,
-- add an Attribute called NoAutoScale (type: boolean) and tick it.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------- CONFIG ----------------
local DESIGN_SIZE   = Vector2.new(1366, 768) -- the screen size you built your UI on in Studio (width, height)
local MIN_SCALE     = 0.55                    -- never shrink UI smaller than this (keeps buttons tappable)
local MAX_SCALE     = 1.5                     -- never grow UI bigger than this (big monitors / TVs)
local PHONE_BOOST   = 1.2                     -- extra size on phones so fingers can hit buttons (1 = none)
local PHONE_HEIGHT  = 500                     -- screens shorter than this (pixels) count as a phone
local FIX_POSITIONS = true                    -- true = pixel positions become screen-% so things stay in place
local LOCK_SHAPE    = true                    -- true = buttons/images sized in screen-% keep their shape
local SKIP_GUIS     = { }                     -- ScreenGui names to leave alone, like { "Dead", "END" }
local DEBUG_PRINTS  = false                   -- true = prints what it does in the Output window
----------------------------------------

-- these keep their shape when LOCK_SHAPE is on
local SHAPE_CLASSES = { ImageButton = true, TextButton = true, ImageLabel = true }

local skipNames = {}
for _, name in ipairs(SKIP_GUIS) do skipNames[name] = true end

local scales = setmetatable({}, { __mode = "k" }) -- every UIScale this script controls

-- how big the UI should be on this screen (1 = same as in Studio)
local function getFactor()
    local camera = workspace.CurrentCamera
    local vp = camera and camera.ViewportSize or DESIGN_SIZE
    if vp.X < 2 or vp.Y < 2 then return 1 end
    local f = math.min(vp.X / DESIGN_SIZE.X, vp.Y / DESIGN_SIZE.Y)
    local isPhone = math.min(vp.X, vp.Y) < PHONE_HEIGHT
        or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and math.min(vp.X, vp.Y) < 900)
    if isPhone then f *= PHONE_BOOST end
    return math.clamp(f, MIN_SCALE, MAX_SCALE)
end

local function isSkipped(inst)
    return inst:GetAttribute("NoAutoScale") == true
end

-- sized only in pixels? (both Scale parts are 0)
local function isPixelSized(obj)
    local s = obj.Size
    return s.X.Scale == 0 and s.Y.Scale == 0 and (s.X.Offset > 0 or s.Y.Offset > 0)
end

-- sized only in screen-%? (both Scale parts used)
local function isPercentSized(obj)
    local s = obj.Size
    return s.X.Scale > 0 and s.Y.Scale > 0
end

local function inLayout(obj)
    return obj.Parent ~= nil and obj.Parent:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

-- the size something had on your Studio screen
local function designSizeOf(inst)
    if not inst or inst == playerGui then return DESIGN_SIZE end
    if inst:IsA("ScreenGui") then return DESIGN_SIZE end
    if inst:IsA("GuiObject") then
        local p = designSizeOf(inst.Parent)
        return Vector2.new(inst.Size.X.Scale * p.X + inst.Size.X.Offset, inst.Size.Y.Scale * p.Y + inst.Size.Y.Offset)
    end
    return designSizeOf(inst.Parent) -- Folders etc. don't change the size
end

local function addScale(obj)
    local s = obj:FindFirstChildOfClass("UIScale")
    if not s then
        s = Instance.new("UIScale")
        s.Name = "AutoScale"
        s.Parent = obj
    end
    local f = getFactor()
    s:SetAttribute("Base", f) -- ButtonEffects reads this so its pop animation keeps the right size
    s.Scale = f
    scales[s] = true
end

-- keeps a screen-% button/image the same shape it had in Studio
local function lockShape(obj, design)
    if not LOCK_SHAPE or not SHAPE_CLASSES[obj.ClassName] then return end
    if obj.Size.X.Scale >= 0.9 or obj.Size.Y.Scale >= 0.9 then return end -- full-screen things should stretch
    if design.X <= 0 or design.Y <= 0 or inLayout(obj) then return end
    if obj:FindFirstChildOfClass("UIAspectRatioConstraint") then return end -- you already set one
    local c = Instance.new("UIAspectRatioConstraint")
    c.Name = "AutoShape"
    c.AspectRatio = design.X / design.Y
    c.Parent = obj
end

local count = 0

-- scales one object (and looks inside it if needed)
local function process(obj, parentDesign)
    if isSkipped(obj) then return end
    if obj:IsA("GuiObject") then
        if obj:GetAttribute("AutoScaled") then return end
        obj:SetAttribute("AutoScaled", true)

        if isPixelSized(obj) then
            if FIX_POSITIONS and not inLayout(obj) and parentDesign.X > 0 and parentDesign.Y > 0 then
                local p = obj.Position
                obj.Position = UDim2.new(
                    p.X.Scale + p.X.Offset / parentDesign.X, 0,
                    p.Y.Scale + p.Y.Offset / parentDesign.Y, 0)
            end
            addScale(obj)
            obj:SetAttribute("AutoScaleCovers", true) -- everything inside is covered by this UIScale
            count += 1
            return
        end

        -- sized in screen-% (it already fits): keep its shape, then check what's inside
        local myDesign = Vector2.new(
            obj.Size.X.Scale * parentDesign.X + obj.Size.X.Offset,
            obj.Size.Y.Scale * parentDesign.Y + obj.Size.Y.Offset)
        if isPercentSized(obj) then lockShape(obj, myDesign) end
        for _, child in ipairs(obj:GetChildren()) do
            process(child, myDesign)
        end
    elseif obj:IsA("Folder") then
        for _, child in ipairs(obj:GetChildren()) do
            process(child, parentDesign)
        end
    end
end

local function processGui(gui)
    if not gui:IsA("ScreenGui") or skipNames[gui.Name] or isSkipped(gui) then return end
    if gui:GetAttribute("AutoScaleWatched") then return end
    gui:SetAttribute("AutoScaleWatched", true)

    for _, child in ipairs(gui:GetChildren()) do
        process(child, DESIGN_SIZE)
    end

    -- UI that scripts add later
    gui.DescendantAdded:Connect(function(d)
        if not d:IsA("GuiObject") then return end
        task.defer(function()
            if not d.Parent or isSkipped(d) or d:GetAttribute("AutoScaled") then return end
            local a = d.Parent
            while a and a ~= gui do
                if a:GetAttribute("AutoScaleCovers") or isSkipped(a) then return end -- already covered
                a = a.Parent
            end
            process(d, designSizeOf(d.Parent))
        end)
    end)

    if DEBUG_PRINTS then print("[UIScaler] " .. gui.Name .. " done, scaled so far: " .. count) end
end

for _, gui in ipairs(playerGui:GetChildren()) do
    processGui(gui)
end
playerGui.ChildAdded:Connect(function(gui)
    task.defer(processGui, gui)
end)

-- the screen changed size (window resized, phone rotated) - waits a moment so it doesn't flicker
local refreshQueued = false
local function refresh()
    if refreshQueued then return end
    refreshQueued = true
    task.delay(0.1, function()
        refreshQueued = false
        local f = getFactor()
        for s in pairs(scales) do
            if s.Parent then
                s:SetAttribute("Base", f)
                s.Scale = f
            end
        end
        if DEBUG_PRINTS then print("[UIScaler] screen scale = " .. string.format("%.2f", f)) end
    end)
end

local cameraConn
local function watchCamera()
    if cameraConn then cameraConn:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then
        cameraConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
    end
    refresh()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

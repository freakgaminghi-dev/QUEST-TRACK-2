-- ClassSlots  (LocalScript)  -- ONE script that runs ALL your slot buttons
-- WHERE: INSIDE the ScreenGui that has your Slot1, Slot2 and Slot3 buttons
--        (StarterGui > your ScreenGui > this LocalScript)
-- PLACE: LOBBY
--
-- It finds the buttons named Slot1, Slot2, Slot3 by itself (they can be inside Frames too).
--   * Only ONE slot is EQUIPPED at a time (gold "EQUIPPED" text). Click a slot to equip it.
--   * Rolling changes ONLY the equipped slot. That slot flashes "NEW!" when it gets a new class.
--   * Locked slots are dark and say LOCKED. Buy them with the BuySlotButton.
-- DELETE the old "SlotButton" scripts inside your slot buttons - this script replaces them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local container = script.Parent

---------------- CONFIG ----------------
local SLOT_NAMES      = { "Slot1", "Slot2", "Slot3" }  -- names of your slot buttons, in order
local SLOT_TEXT       = "Slot %d"                      -- top text for a normal slot (%d = slot number)
local EQUIPPED_TEXT   = "EQUIPPED"                     -- top text for the equipped slot
local LOCKED_TEXT     = "LOCKED"                       -- top text for a slot you haven't bought
local NEW_TEXT        = "NEW!"                         -- flashes on a slot when it gets a new class
local EMPTY_TEXT      = "Empty"                        -- bottom text when the slot has no class
local NORMAL_COLOR    = Color3.fromRGB(220, 220, 225)  -- top text colour
local EQUIPPED_COLOR  = Color3.fromRGB(255, 205, 50)   -- top text colour when equipped (gold)
local LOCKED_COLOR    = Color3.fromRGB(150, 150, 150)  -- top text colour when locked
local LOCKED_DARKEN   = Color3.fromRGB(100, 100, 100)  -- locked button pictures get this dark
local ERROR_COLOR     = Color3.fromRGB(255, 80, 80)
local FONT_FACE       = Font.new("rbxasset://fonts/families/PressStart2P.json") -- Press Start 2P (pixel font)
local MESSAGE_TIME    = 1.5                            -- seconds a message like "NEW!" stays
----------------------------------------

local remote = ReplicatedStorage:WaitForChild("RollClass", 10)
if not remote then
    warn("[ClassSlots] ClassSystem isn't running - put the ClassSystem script in ServerScriptService")
    return
end
if (remote:GetAttribute("Version") or 1) < 3 then
    warn("[ClassSlots] Your ClassSystem script is an OLD version! Replace it with the newest one (in BOTH places)."
        .. " The old one turns every slot click into a roll.")
end

local classColors = {}
pcall(function()
    for _, c in ipairs(HttpService:JSONDecode(remote:GetAttribute("ClassList") or "[]")) do
        classColors[c.name] = Color3.fromHex(c.color)
    end
end)

---------------- FIND THE BUTTONS ----------------
local function makeText(button, name, posY, height)
    local old = button:FindFirstChild(name)
    if old then old:Destroy() end
    local label = Instance.new("TextLabel")
    label.Name = name
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, posY, 0)
    label.Size = UDim2.new(0.9, 0, height, 0)
    label.BackgroundTransparency = 1
    label.FontFace = FONT_FACE
    label.TextScaled = true
    label.TextStrokeTransparency = 0
    label.ZIndex = button.ZIndex + 1
    label.Parent = button
    return label
end

local slots = {} -- [number] = { button, top, bottom, normalColor, showingMessage }
for i, name in ipairs(SLOT_NAMES) do
    local button = container:FindFirstChild(name, true)
    if not button or not button:IsA("GuiButton") then
        warn("[ClassSlots] Can't find a button named \"" .. name .. "\" in " .. container:GetFullName())
    else
        -- the old per-button script would fight with this one
        for _, d in ipairs(button:GetDescendants()) do
            if d:IsA("LocalScript") and d.Name == "SlotButton" then
                warn("[ClassSlots] Delete the old SlotButton script inside " .. name .. " (this script replaces it)")
                d.Disabled = true
            end
        end
        for _, old in ipairs({ "SlotStatus", "SlotClass" }) do -- labels the old script made
            local o = button:FindFirstChild(old)
            if o then o:Destroy() end
        end
        slots[i] = {
            button = button,
            top = makeText(button, "SlotTop", 0.05, 0.25),
            bottom = makeText(button, "SlotBottom", 0.65, 0.3),
            normalColor = button:IsA("ImageButton") and button.ImageColor3 or nil,
            showingMessage = false,
        }
    end
end
---------------------------------------------------

local function slotData()
    local ok, list = pcall(function()
        return HttpService:JSONDecode(player:GetAttribute("ClassSlotData") or "[]")
    end)
    return (ok and type(list) == "table") and list or {}
end

local lastNames = slotData()

local function refresh()
    local count = player:GetAttribute("ClassSlots") or 1
    local equipped = player:GetAttribute("ClassEquipped") or 1
    local names = slotData()

    for i, s in pairs(slots) do
        local owned = i <= count
        if s.normalColor then
            s.button.ImageColor3 = owned and s.normalColor or LOCKED_DARKEN
        end
        if not s.showingMessage then
            if not owned then
                s.top.Text = LOCKED_TEXT
                s.top.TextColor3 = LOCKED_COLOR
            elseif i == equipped then
                s.top.Text = EQUIPPED_TEXT
                s.top.TextColor3 = EQUIPPED_COLOR
            else
                s.top.Text = string.format(SLOT_TEXT, i)
                s.top.TextColor3 = NORMAL_COLOR
            end
        end
        local name = owned and names[i] or ""
        if owned and name ~= "" then
            s.bottom.Text = name
            s.bottom.TextColor3 = classColors[name] or NORMAL_COLOR
        else
            s.bottom.Text = owned and EMPTY_TEXT or ""
            s.bottom.TextColor3 = LOCKED_COLOR
        end
    end
end

local function flashMessage(i, text, color)
    local s = slots[i]
    if not s then return end
    s.showingMessage = true
    s.top.Text = text
    s.top.TextColor3 = color
    task.delay(MESSAGE_TIME, function()
        s.showingMessage = false
        refresh()
    end)
end

-- a slot got a new class: flash "NEW!" on just that slot
player:GetAttributeChangedSignal("ClassSlotData"):Connect(function()
    local names = slotData()
    for i in pairs(slots) do
        if names[i] and names[i] ~= "" and names[i] ~= lastNames[i] then
            flashMessage(i, NEW_TEXT, EQUIPPED_COLOR)
        end
    end
    lastNames = names
    refresh()
end)
player:GetAttributeChangedSignal("ClassSlots"):Connect(refresh)
player:GetAttributeChangedSignal("ClassEquipped"):Connect(refresh)
refresh()

---------------- CLICKS ----------------
local busy = false
for i, s in pairs(slots) do
    s.button.Activated:Connect(function()
        if busy then return end
        local count = player:GetAttribute("ClassSlots") or 1
        if i > count then
            flashMessage(i, "Buy it first", ERROR_COLOR)
            return
        end
        if i == (player:GetAttribute("ClassEquipped") or 1) then return end -- already equipped

        busy = true
        local ok, success, _, message = pcall(function()
            return remote:InvokeServer("equip", i)
        end)
        busy = false
        if not ok then
            flashMessage(i, "Try again", ERROR_COLOR)
        elseif not success then
            flashMessage(i, message or "Can't", ERROR_COLOR)
        end
    end)
end
----------------------------------------

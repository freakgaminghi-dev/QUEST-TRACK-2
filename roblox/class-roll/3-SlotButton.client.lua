-- SlotButton  (LocalScript)
-- WHERE: INSIDE one of your slot ImageButtons  (StarterGui > your ScreenGui > your slot ImageButton > this LocalScript)
-- PLACE: LOBBY
--
-- Make one ImageButton for EACH slot and NAME them Slot1, Slot2, Slot3. Put this script in each one.
-- The script reads the slot number from the button's NAME by itself (Slot2 = slot 2), so you can copy the
-- same script into every button without changing anything.
-- The button shows:  top = "EQUIPPED" / "Slot 2" / "LOCKED",  bottom = the class in that slot (in its rarity colour).
-- Click it = equip that slot. Your next roll goes into the EQUIPPED slot.
-- Locked slots are darker. Buy them with the BuySlotButton.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local button = script.Parent

---------------- CONFIG ----------------
local SLOT_NUMBER     = 0                              -- 0 = automatic (uses the number in the button's name: Slot1, Slot2, Slot3)
local SLOT_TEXT       = "Slot %d"                      -- top text for a normal slot (%d = slot number)
local EQUIPPED_TEXT   = "EQUIPPED"                     -- top text for the equipped slot
local LOCKED_TEXT     = "LOCKED"                       -- top text for a slot you haven't bought
local EMPTY_TEXT      = "Empty"                        -- bottom text when the slot has no class
local NORMAL_COLOR    = Color3.fromRGB(220, 220, 225)  -- top text colour
local EQUIPPED_COLOR  = Color3.fromRGB(255, 205, 50)   -- top text colour when equipped (gold)
local LOCKED_COLOR    = Color3.fromRGB(150, 150, 150)  -- top text colour when locked
local LOCKED_DARKEN   = Color3.fromRGB(100, 100, 100)  -- the button picture gets this dark when locked
local ERROR_COLOR     = Color3.fromRGB(255, 80, 80)
local FONT            = Enum.Font.FredokaOne
local MESSAGE_TIME    = 1.5                            -- seconds a message like "Buy it first" stays
----------------------------------------

if not button:IsA("GuiButton") then
    warn("[SlotButton] This script must be INSIDE an ImageButton (or TextButton)")
    return
end

-- find out which slot this button is: from the button's name (Slot1, Slot2, Slot3)
if SLOT_NUMBER == 0 then
    SLOT_NUMBER = tonumber(string.match(button.Name, "%d+")) or 0
end
if SLOT_NUMBER < 1 then
    warn("[SlotButton] Can't tell which slot \"" .. button.Name .. "\" is - name the button Slot1, Slot2 or Slot3")
    return
end

-- two buttons for the same slot would show the same class (and look like they all changed)
_G.ClassSlotButtons = _G.ClassSlotButtons or {}
local other = _G.ClassSlotButtons[SLOT_NUMBER]
if other and other ~= button and other.Parent then
    warn("[SlotButton] \"" .. button:GetFullName() .. "\" and \"" .. other:GetFullName()
        .. "\" are BOTH slot " .. SLOT_NUMBER .. " - rename one of them (Slot1, Slot2, Slot3)")
end
_G.ClassSlotButtons[SLOT_NUMBER] = button

local remote = ReplicatedStorage:WaitForChild("RollClass", 10)
if not remote then
    warn("[SlotButton] ClassSystem isn't running - put the ClassSystem script in ServerScriptService")
    return
end

local classColors = {}
pcall(function()
    for _, c in ipairs(HttpService:JSONDecode(remote:GetAttribute("ClassList") or "[]")) do
        classColors[c.name] = Color3.fromHex(c.color)
    end
end)

---------------- TEXT ON THE BUTTON ----------------
local function makeText(name, posY, height)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, posY, 0)
    label.Size = UDim2.new(0.9, 0, height, 0)
    label.BackgroundTransparency = 1
    label.Font = FONT
    label.TextScaled = true
    label.TextStrokeTransparency = 0
    label.ZIndex = button.ZIndex + 1
    label.Parent = button
    return label
end
local topText = makeText("SlotStatus", 0.05, 0.25)
local bottomText = makeText("SlotClass", 0.65, 0.3)

local normalImageColor = button:IsA("ImageButton") and button.ImageColor3 or nil
----------------------------------------------------

local showingMessage = false

local function slotData()
    local ok, slots = pcall(function()
        return HttpService:JSONDecode(player:GetAttribute("ClassSlotData") or "[]")
    end)
    return ok and slots or {}
end

local function refresh()
    local count = player:GetAttribute("ClassSlots") or 1
    local equipped = player:GetAttribute("ClassEquipped") or 1
    local owned = SLOT_NUMBER <= count

    if normalImageColor then
        button.ImageColor3 = owned and normalImageColor or LOCKED_DARKEN
    end

    if not showingMessage then
        if not owned then
            topText.Text = LOCKED_TEXT
            topText.TextColor3 = LOCKED_COLOR
        elseif SLOT_NUMBER == equipped then
            topText.Text = EQUIPPED_TEXT
            topText.TextColor3 = EQUIPPED_COLOR
        else
            topText.Text = string.format(SLOT_TEXT, SLOT_NUMBER)
            topText.TextColor3 = NORMAL_COLOR
        end
    end

    local name = owned and slotData()[SLOT_NUMBER] or ""
    if owned and name ~= "" then
        bottomText.Text = name
        bottomText.TextColor3 = classColors[name] or NORMAL_COLOR
    else
        bottomText.Text = owned and EMPTY_TEXT or ""
        bottomText.TextColor3 = LOCKED_COLOR
    end
end

local function flashMessage(text, color)
    showingMessage = true
    topText.Text = text
    topText.TextColor3 = color
    task.delay(MESSAGE_TIME, function()
        showingMessage = false
        refresh()
    end)
end

refresh()
for _, attr in ipairs({ "ClassSlots", "ClassEquipped", "ClassSlotData" }) do
    player:GetAttributeChangedSignal(attr):Connect(refresh)
end

---------------- CLICK ----------------
local busy = false
button.Activated:Connect(function()
    if busy then return end
    local count = player:GetAttribute("ClassSlots") or 1
    if SLOT_NUMBER > count then
        flashMessage("Buy it first", ERROR_COLOR)
        return
    end
    if SLOT_NUMBER == (player:GetAttribute("ClassEquipped") or 1) then return end -- already equipped

    busy = true
    local ok, success, _, message = pcall(function()
        return remote:InvokeServer("equip", SLOT_NUMBER)
    end)
    busy = false
    if not ok then
        flashMessage("Try again", ERROR_COLOR)
    elseif not success then
        flashMessage(message or "Can't", ERROR_COLOR)
    end
end)
---------------------------------------

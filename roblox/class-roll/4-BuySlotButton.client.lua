-- BuySlotButton  (LocalScript)
-- WHERE: INSIDE your "buy slot" ImageButton  (StarterGui > your ScreenGui > your ImageButton > this LocalScript)
-- PLACE: LOBBY
--
-- Press it = buy your next class slot with Bounty (ClassSystem checks the price on the server).
-- The button shows which slot you're buying and how much it costs, or "MAX SLOTS" when you have them all.
-- The prices are set in ClassSystem (SLOT_PRICES).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local button = script.Parent

---------------- CONFIG ----------------
local BUY_TEXT      = "Buy Slot %d"        -- top text (%d = the slot you're buying)
local PRICE_TEXT    = "%d Bounty"          -- bottom text (%d = the price)
local MAX_TEXT      = "MAX SLOTS"          -- when you have every slot
local TOP_COLOR     = Color3.fromRGB(255, 255, 255)
local PRICE_COLOR   = Color3.fromRGB(255, 205, 50)   -- gold
local GOOD_COLOR    = Color3.fromRGB(90, 230, 110)   -- "Slot 2 unlocked!"
local ERROR_COLOR   = Color3.fromRGB(255, 80, 80)    -- "Not enough Bounty"
local FONT_FACE     = Font.new("rbxasset://fonts/families/PressStart2P.json") -- Press Start 2P (pixel font)
local MESSAGE_TIME  = 1.8                            -- seconds a message stays
----------------------------------------

if not button:IsA("GuiButton") then
    warn("[BuySlotButton] This script must be INSIDE an ImageButton (or TextButton)")
    return
end

local remote = ReplicatedStorage:WaitForChild("RollClass", 10)
if not remote then
    warn("[BuySlotButton] ClassSystem isn't running - put the ClassSystem script in ServerScriptService")
    return
end

local prices = {}
pcall(function()
    prices = HttpService:JSONDecode(remote:GetAttribute("SlotPrices") or "[]")
end)
local maxSlots = remote:GetAttribute("MaxSlots") or #prices

---------------- TEXT ON THE BUTTON ----------------
local function makeText(name, posY, height, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, posY, 0)
    label.Size = UDim2.new(0.9, 0, height, 0)
    label.BackgroundTransparency = 1
    label.FontFace = FONT_FACE
    label.TextScaled = true
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.ZIndex = button.ZIndex + 1
    label.Parent = button
    return label
end
local topText = makeText("BuyText", 0.08, 0.35, TOP_COLOR)
local priceText = makeText("BuyPrice", 0.58, 0.3, PRICE_COLOR)
----------------------------------------------------

local showingMessage = false

local function refresh()
    if showingMessage then return end
    local count = player:GetAttribute("ClassSlots") or 1
    local nextSlot = count + 1
    if nextSlot > maxSlots or not prices[nextSlot] then
        topText.Text = MAX_TEXT
        topText.TextColor3 = GOOD_COLOR
        priceText.Text = ""
    else
        topText.Text = string.format(BUY_TEXT, nextSlot)
        topText.TextColor3 = TOP_COLOR
        priceText.Text = string.format(PRICE_TEXT, prices[nextSlot])
        priceText.TextColor3 = PRICE_COLOR
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
player:GetAttributeChangedSignal("ClassSlots"):Connect(refresh)

---------------- CLICK ----------------
local busy = false
button.Activated:Connect(function()
    if busy then return end
    local count = player:GetAttribute("ClassSlots") or 1
    if count >= maxSlots then
        flashMessage(MAX_TEXT, GOOD_COLOR)
        return
    end

    busy = true
    local ok, success, _, message = pcall(function()
        return remote:InvokeServer("buy")
    end)
    busy = false

    if not ok then
        flashMessage("Try again", ERROR_COLOR)
    elseif success then
        flashMessage(message or "Unlocked!", GOOD_COLOR)
    else
        flashMessage(message == "Not enough Bounty" and "Not enough!" or (message or "Can't buy"), ERROR_COLOR)
    end
end)
---------------------------------------

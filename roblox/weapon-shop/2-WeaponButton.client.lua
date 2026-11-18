-- WeaponButton  (LocalScript)
-- WHERE: INSIDE your own ImageButton  (StarterGui > your ScreenGui > your ImageButton > this LocalScript)
-- PLACE: LOBBY only
--
-- Put this inside an ImageButton you made. Your picture stays as it is;
-- the script only adds two lines of text on top: LOCKED / OWNED at the top, the price at the bottom.
-- Click while locked = buy the weapon with Bounty (the WeaponShop script handles the purchase).
-- Once bought, the player gets the weapon every time they go into the game.
-- One button = one weapon. For another weapon, copy the whole button and change WEAPON_NAME.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local button = script.Parent -- the ImageButton this script is inside

---------------- CONFIG ----------------
local WEAPON_NAME   = "Sword"      -- must match the Tool name in ServerStorage > WEAPONS AND the list in WeaponShop
local SHOW_TEXT     = true         -- false = no text on your button at all (just your picture)
local PRICE_TEXT    = "%d Bounty"  -- the price line (%d = the price)
local LOCKED_TAG    = "LOCKED"     -- top text before buying
local OWNED_TAG     = "OWNED"      -- top text after buying
local LOCKED_COLOR  = Color3.fromRGB(220, 220, 225) -- top text colour while locked (light grey)
local OWNED_COLOR   = Color3.fromRGB(90, 230, 110)  -- top text colour once bought (green)
local PRICE_COLOR   = Color3.fromRGB(255, 205, 50)  -- price text colour (gold)
local ERROR_COLOR   = Color3.fromRGB(255, 80, 80)   -- colour for "Not enough" etc. (red)
local FONT          = Enum.Font.FredokaOne          -- text font
local MESSAGE_TIME  = 1.5                           -- seconds a message like "Not enough" stays
----------------------------------------

if not button:IsA("GuiButton") then
	warn("[WeaponButton] This script must be INSIDE an ImageButton (or TextButton)")
	return
end

local remote = ReplicatedStorage:WaitForChild("BuyWeapon", 10)
if not remote then
	warn("[WeaponButton] WeaponShop isn't running - put the WeaponShop script in ServerScriptService")
	return
end

---------------- TEXT ON THE BUTTON ----------------
local function makeText(name, posY, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, posY, 0)
	label.Size = UDim2.new(0.9, 0, 0.2, 0)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.ZIndex = button.ZIndex + 1
	label.Visible = SHOW_TEXT
	label.Parent = button
	return label
end

local statusText = makeText("Status", 0.05, LOCKED_COLOR) -- top line
local priceText = makeText("Price", 0.75, PRICE_COLOR)    -- bottom line
----------------------------------------------------

local showingMessage = false

local function isOwned()
	return player:GetAttribute("OwnsWeapon_" .. WEAPON_NAME) == true
end

local function refresh()
	local owned = isOwned()
	statusText.Text = owned and OWNED_TAG or LOCKED_TAG
	statusText.TextColor3 = owned and OWNED_COLOR or LOCKED_COLOR

	if showingMessage then return end
	local price = remote:GetAttribute("Price_" .. WEAPON_NAME)
	priceText.Text = price and string.format(PRICE_TEXT, price) or "..."
	priceText.TextColor3 = PRICE_COLOR
end

-- shows a short message where the price is, then puts the price back
local function flashMessage(text, isError)
	showingMessage = true
	priceText.Text = text
	priceText.TextColor3 = isError and ERROR_COLOR or OWNED_COLOR
	task.delay(MESSAGE_TIME, function()
		showingMessage = false
		refresh()
	end)
end

refresh()
player:GetAttributeChangedSignal("OwnsWeapon_" .. WEAPON_NAME):Connect(refresh)
remote:GetAttributeChangedSignal("Price_" .. WEAPON_NAME):Connect(refresh)

-- warn if the name doesn't match anything in WeaponShop
task.delay(5, function()
	if not remote:GetAttribute("Price_" .. WEAPON_NAME) then
		warn("[WeaponButton] \"" .. WEAPON_NAME .. "\" has no price - check it matches the WEAPONS list in WeaponShop")
	end
end)

---------------- CLICK ----------------
local busy = false
button.MouseButton1Click:Connect(function()
	if isOwned() then
		flashMessage("You own it!", false)
		return
	end
	if busy then return end
	busy = true
	local ok, success, message = pcall(function()
		return remote:InvokeServer(WEAPON_NAME)
	end)
	busy = false

	if not ok then
		flashMessage("Try again", true)
	elseif success then
		flashMessage("Bought!", false)
	else
		flashMessage(message == "Not enough Bounty" and "Not enough" or (message or "Can't buy"), true)
	end
end)
----------------------------------------

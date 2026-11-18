-- WeaponButtons  (LocalScript)
-- WHERE: StarterPlayer > StarterPlayerScripts  ->  LocalScript  ->  name it "WeaponButtons"
-- PLACE: LOBBY only
--
-- Makes the shop buttons BY ITSELF - you don't need to build any GUI.
-- One button appears for every weapon in the WEAPONS list in the WeaponShop script.
-- Click a button = buy that weapon with Bounty. After that it says OWNED,
-- and the player gets the weapon every time they go into the game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

---------------- CONFIG ----------------
local BUTTON_WIDTH  = 170                              -- width of each button (pixels)
local BUTTON_HEIGHT = 60                               -- height of each button (pixels)
local POSITION      = UDim2.new(1, -20, 0.5, 0)        -- where the buttons sit (right side, middle of screen)
local GAP           = 8                                -- space between buttons (pixels)
local BUTTON_COLOR  = Color3.fromRGB(35, 35, 45)       -- button background colour
local PRICE_COLOR   = Color3.fromRGB(255, 205, 50)     -- text colour before buying (gold)
local OWNED_COLOR   = Color3.fromRGB(90, 230, 110)     -- text colour once bought (green)
local ERROR_COLOR   = Color3.fromRGB(255, 80, 80)      -- text colour for "Not enough" etc. (red)
local FONT          = Enum.Font.FredokaOne             -- text font
local MESSAGE_TIME  = 1.5                              -- seconds a message like "Not enough" stays
----------------------------------------

local remote = ReplicatedStorage:WaitForChild("BuyWeapon", 10)
if not remote then
	warn("[WeaponButtons] WeaponShop isn't running - put the WeaponShop script in ServerScriptService")
	return
end

---------------- THE SCREEN GUI ----------------
local gui = Instance.new("ScreenGui")
gui.Name = "WeaponShopGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local holder = Instance.new("Frame")
holder.Name = "Buttons"
holder.AnchorPoint = Vector2.new(1, 0.5)
holder.Position = POSITION
holder.Size = UDim2.fromOffset(BUTTON_WIDTH, 0)
holder.AutomaticSize = Enum.AutomaticSize.Y
holder.BackgroundTransparency = 1
holder.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, GAP)
layout.SortOrder = Enum.SortOrder.Name
layout.Parent = holder
------------------------------------------------

---------------- ONE BUTTON ----------------
local made = {} -- weapon name -> true once its button exists

local function makeButton(weaponName)
	if made[weaponName] then return end
	made[weaponName] = true

	local button = Instance.new("TextButton")
	button.Name = weaponName
	button.Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.BackgroundColor3 = BUTTON_COLOR
	button.Font = FONT
	button.TextScaled = true
	button.TextStrokeTransparency = 0
	button.Parent = holder
	Instance.new("UICorner").Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = button

	local showingMessage = false

	local function isOwned()
		return player:GetAttribute("OwnsWeapon_" .. weaponName) == true
	end

	local function refresh()
		if showingMessage then return end
		if isOwned() then
			button.Text = weaponName .. "\nOWNED"
			button.TextColor3 = OWNED_COLOR
		else
			local price = remote:GetAttribute("Price_" .. weaponName)
			button.Text = weaponName .. "\n" .. tostring(price or "...") .. " Bounty"
			button.TextColor3 = PRICE_COLOR
		end
	end

	-- shows a short message on the button, then goes back to normal
	local function flashMessage(text, isError)
		showingMessage = true
		button.Text = weaponName .. "\n" .. text
		button.TextColor3 = isError and ERROR_COLOR or OWNED_COLOR
		task.delay(MESSAGE_TIME, function()
			showingMessage = false
			refresh()
		end)
	end

	refresh()
	player:GetAttributeChangedSignal("OwnsWeapon_" .. weaponName):Connect(refresh)
	remote:GetAttributeChangedSignal("Price_" .. weaponName):Connect(refresh)

	local busy = false
	button.MouseButton1Click:Connect(function()
		if isOwned() then
			flashMessage("You own it!", false)
			return
		end
		if busy then return end
		busy = true
		local ok, success, message = pcall(function()
			return remote:InvokeServer(weaponName)
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
end
--------------------------------------------

---------------- MAKE A BUTTON FOR EVERY WEAPON ----------------
-- WeaponShop puts "Price_<weapon>" on the BuyWeapon remote for each weapon it sells
for attributeName in pairs(remote:GetAttributes()) do
	local weaponName = string.match(attributeName, "^Price_(.+)$")
	if weaponName then makeButton(weaponName) end
end
remote.AttributeChanged:Connect(function(attributeName)
	local weaponName = string.match(attributeName, "^Price_(.+)$")
	if weaponName then makeButton(weaponName) end
end)
-----------------------------------------------------------------

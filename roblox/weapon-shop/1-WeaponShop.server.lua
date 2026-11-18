-- WeaponShop  (Script)
-- WHERE: ServerScriptService  ->  Script  ->  name it "WeaponShop"
-- PLACE: BOTH the Lobby and the Game place (same script in each)
--
-- Lobby: the weapon buttons buy a weapon for Bounty (needs BountyStat for _G.SpendBounty).
-- Bought weapons are owned FOREVER (saved in a DataStore both places share).
-- Game place: every time an owner spawns (joining AND after dying) they get the weapon in their backpack.
-- The weapon Tools live in ServerStorage > Folder "WEAPONS" (in the GAME place, where they're handed out).
--
-- Studio testing: Home > Game Settings > Security > turn ON "Enable Studio Access to API Services",
-- and the place must be published, or DataStores won't work in a play test.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

---------------- CONFIG ----------------
-- every weapon that can be bought: ["Tool name in the WEAPONS folder"] = price in Bounty
-- (a button for each one appears in the lobby by itself)
local WEAPONS = {
	["Sword"] = 1,
	-- ["Bat"] = 5,   <- add more weapons like this
}
local FOLDER_NAME    = "WEAPONS"          -- folder in ServerStorage that holds the weapon Tools
local LOBBY_PLACE_ID = 111308120214966    -- weapons are only handed out OUTSIDE the lobby
local GIVE_IN_LOBBY  = false              -- true = owners also get their weapons in the lobby
local STORE_NAME     = "Weapons_v1"       -- changing this name wipes everyone's bought weapons
local RETRIES        = 3                  -- how many times to retry loading/saving
local DEBUG_PRINTS   = true               -- true = prints what it's doing in Output

-- TESTING (only does anything in a Studio play test; the real game is always "normal")
--   "normal"   = works like the real game
--   "locked"   = every weapon starts LOCKED each test and buying isn't saved
--   "unlocked" = you own every weapon for free (handy to test getting the weapon in the game place)
local STUDIO_MODE = "normal"
----------------------------------------

local testMode = RunService:IsStudio() and STUDIO_MODE or "normal"
if testMode ~= "normal" then
	print("[WeaponShop] Studio test mode: " .. testMode)
end

local isLobby = game.PlaceId == LOBBY_PLACE_ID
local giveWeaponsHere = GIVE_IN_LOBBY or not isLobby

local store = DataStoreService:GetDataStore(STORE_NAME)

-- the buttons talk to us through this; prices are stored on it so buttons can show them
local remote = ReplicatedStorage:FindFirstChild("BuyWeapon")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "BuyWeapon"
	remote.Parent = ReplicatedStorage
end
for name, price in pairs(WEAPONS) do
	remote:SetAttribute("Price_" .. name, price)
end

local folder = ServerStorage:FindFirstChild(FOLDER_NAME)
if giveWeaponsHere and not folder then
	warn("[WeaponShop] No folder called \"" .. FOLDER_NAME .. "\" in ServerStorage - put your weapon Tools in it")
end

local owned = {}   -- player -> { [weaponName] = true }
local loaded = {}  -- player -> true once their weapons were read
local dirty = {}   -- player -> true when there's something not saved yet
local buying = {}  -- player -> true while a purchase is being handled

local function withRetries(fn)
	local ok, result
	for attempt = 1, RETRIES do
		ok, result = pcall(fn)
		if ok then return true, result end
		task.wait(attempt)
	end
	return false, result
end

---------------- GIVING THE WEAPON ----------------
local function hasTool(player, name)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	return (backpack and backpack:FindFirstChild(name)) or (character and character:FindFirstChild(name))
end

local function giveWeapons(player)
	if not giveWeaponsHere or not folder or not owned[player] then return end
	local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then return end
	for name in pairs(owned[player]) do
		if not hasTool(player, name) then
			local template = folder:FindFirstChild(name)
			if template and template:IsA("Tool") then
				template:Clone().Parent = backpack
			elseif DEBUG_PRINTS then
				warn("[WeaponShop] No Tool called \"" .. name .. "\" in ServerStorage > " .. FOLDER_NAME)
			end
		end
	end
end

local function onCharacterAdded(player)
	-- a short wait so other scripts that restore tools on respawn go first (no doubles)
	task.wait(0.5)
	if player.Parent then
		giveWeapons(player)
	end
end
---------------------------------------------------

---------------- LOAD / SAVE ----------------
local function markOwned(player, name)
	owned[player][name] = true
	player:SetAttribute("OwnsWeapon_" .. name, true)
end

local function load(player)
	owned[player] = owned[player] or {}

	if testMode == "locked" then
		loaded[player] = true
	elseif testMode == "unlocked" then
		for name in pairs(WEAPONS) do markOwned(player, name) end
		loaded[player] = true
	else
		local ok, data = withRetries(function()
			return store:GetAsync("Player_" .. player.UserId)
		end)
		if ok then
			if type(data) == "table" then
				for _, name in ipairs(data) do
					markOwned(player, tostring(name))
				end
			end
			loaded[player] = true
			if DEBUG_PRINTS then print("[WeaponShop] loaded weapons for " .. player.Name) end
		else
			warn("[WeaponShop] Couldn't load " .. player.Name .. "'s weapons: " .. tostring(data))
		end
	end

	-- give the weapons to the character that's already there (if any)
	if player.Character then
		task.spawn(giveWeapons, player)
	end
end

local function save(player)
	if testMode ~= "normal" then return true end -- Studio test: never touch the real saved data
	if not loaded[player] or not dirty[player] then return true end
	local mine = {}
	for name in pairs(owned[player] or {}) do
		table.insert(mine, name)
	end
	local ok, err = withRetries(function()
		return store:UpdateAsync("Player_" .. player.UserId, function(old)
			-- merge with what's stored so nothing bought in the other place gets lost
			local set = {}
			if type(old) == "table" then
				for _, name in ipairs(old) do set[tostring(name)] = true end
			end
			for _, name in ipairs(mine) do set[name] = true end
			local list = {}
			for name in pairs(set) do table.insert(list, name) end
			return list
		end)
	end)
	if ok then
		dirty[player] = nil
		if DEBUG_PRINTS then print("[WeaponShop] saved weapons for " .. player.Name) end
		return true
	end
	warn("[WeaponShop] Couldn't save " .. player.Name .. "'s weapons, will try again: " .. tostring(err))
	return false
end
----------------------------------------------

---------------- BUYING ----------------
remote.OnServerInvoke = function(player, name)
	name = tostring(name or "")
	local price = WEAPONS[name]
	if not price then
		return false, "Not for sale"
	end
	if not loaded[player] then
		return false, "Loading..."
	end
	if owned[player][name] then
		return true, "Owned"
	end
	if buying[player] then
		return false, "Wait..."
	end
	if not _G.SpendBounty then
		warn("[WeaponShop] _G.SpendBounty not found - is BountyStat in ServerScriptService?")
		return false, "Shop offline"
	end

	buying[player] = true
	if not _G.SpendBounty(player, price) then
		buying[player] = nil
		return false, "Not enough Bounty"
	end

	markOwned(player, name)
	dirty[player] = true
	if DEBUG_PRINTS then print("[WeaponShop] " .. player.Name .. " bought " .. name .. " for " .. price .. " Bounty") end
	task.spawn(save, player) -- save right away so it's never lost
	task.spawn(giveWeapons, player) -- only does anything where weapons are handed out
	buying[player] = nil
	return true, "Bought!"
end
----------------------------------------

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	load(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	owned[player] = nil
	loaded[player] = nil
	dirty[player] = nil
	buying[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

-- retry any save that failed
while true do
	task.wait(30)
	for _, player in ipairs(Players:GetPlayers()) do
		if dirty[player] then
			task.spawn(save, player)
		end
	end
end

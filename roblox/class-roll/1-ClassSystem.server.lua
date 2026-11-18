-- ClassSystem v2 (with SLOTS)  (Script)
-- WHERE: ServerScriptService  ->  Script  ->  name it "ClassSystem"
-- PLACE: BOTH the Lobby and the Game place (same script in each)
--
-- Roll a RANDOM class with Bounty. Rarer classes are harder to get but stronger.
-- SLOTS: everyone starts with 1 class slot and can BUY more with Bounty.
--   * Each slot holds one class. Click a slot to EQUIP it (only the equipped class is used).
--   * Rolling puts the new class in your EQUIPPED slot (it replaces what was in that slot).
--   * Buying a slot equips the new empty slot, so your next roll fills it.
-- Everything is SAVED (both places share it).
-- In the GAME place your equipped class changes your health / speed / jump, puts your class name
-- over your head and gives rare classes a sparkle aura.
-- ACCESSORIES: you wear the accessories of your equipped class (lobby AND game). Put them in a Folder in
-- ServerStorage called "ClassAccessories" (or "Accessorys" / "Accessories"). Inside it, either:
--   * a Folder named like the class (Runner, Ninja, ...) with the Accessories inside, or
--   * an Accessory named exactly like the class.
-- Needs BountyStat in ServerScriptService (for _G.SpendBounty).
--
-- Studio testing: Home > Game Settings > Security > turn ON "Enable Studio Access to API Services".

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

---------------- CONFIG ----------------
local ROLL_COST = 25 -- Bounty for one roll

-- SLOTS: the price of each slot in Bounty. Slot 1 is free (everyone has it).
-- The number of prices = the most slots you can have (3 prices = 3 slots).
local SLOT_PRICES = { 0, 100, 250 }

-- every class you can roll:
--   chance = how likely (they're compared to each other, they don't have to add up to 100)
--   health = extra max health, speed / jump = multiplier (1 = normal, 1.2 = 20% more)
local CLASSES = {
    { name = "Runner",     rarity = "Common",    chance = 28, health = 0,   speed = 1.08, jump = 1.0  },
    { name = "Brute",      rarity = "Common",    chance = 22, health = 25,  speed = 1.0,  jump = 1.0  },
    { name = "Jumper",     rarity = "Uncommon",  chance = 15, health = 0,   speed = 1.05, jump = 1.3  },
    { name = "Tank",       rarity = "Uncommon",  chance = 13, health = 60,  speed = 0.95, jump = 1.0  },
    { name = "Ninja",      rarity = "Rare",      chance = 15, health = 10,  speed = 1.15, jump = 1.2  },
    { name = "Juggernaut", rarity = "Epic",      chance = 6,  health = 150, speed = 1.05, jump = 1.05 },
    { name = "Phantom",    rarity = "Legendary", chance = 1,  health = 75,  speed = 1.25, jump = 1.4  },
}

-- colour of each rarity (used for the title, the aura and the roll text)
local RARITY_COLORS = {
    Common    = Color3.fromRGB(200, 200, 200), -- grey
    Uncommon  = Color3.fromRGB(90, 220, 90),   -- green
    Rare      = Color3.fromRGB(70, 150, 255),  -- blue
    Epic      = Color3.fromRGB(180, 80, 255),  -- purple
    Legendary = Color3.fromRGB(255, 200, 40),  -- gold
}
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local AURA_FROM      = "Rare"             -- this rarity and better get a sparkle aura
local SHOW_TITLE     = true               -- class name over your head in the game place
local TITLE_FONT     = "rbxasset://fonts/families/PressStart2P.json" -- font of the name over your head (Press Start 2P)

-- ACCESSORIES for each class
local ACCESSORY_FOLDERS    = { "ClassAccessories", "Accessorys", "Accessories", "ClassAccessorys" } -- folder names it looks for (ServerStorage or ReplicatedStorage)
local ACCESSORIES_IN_LOBBY = true         -- true = you also wear your class accessories in the lobby
local LOBBY_PLACE_ID = 111308120214966    -- classes only change your stats OUTSIDE the lobby
local APPLY_IN_LOBBY = false              -- true = stats/title/aura in the lobby too
local APPLY_DELAY    = 1.5                -- seconds after spawning (so LevelSystem sets health/speed first)
local ACTION_COOLDOWN = 1                 -- seconds between rolls / slot buys (stops spam clicking)
local STORE_NAME     = "Classes_v1"       -- changing this name wipes everyone's classes
local RETRIES        = 3                  -- how many times to retry loading/saving
local DEBUG_PRINTS   = true               -- true = prints what it does in Output

-- TESTING (only does anything in a Studio play test; the real game is always "normal")
--   "normal" = works like the real game
--   "free"   = rolling and slots cost 0 Bounty and nothing is saved
local STUDIO_MODE = "normal"
----------------------------------------

local MAX_SLOTS = #SLOT_PRICES
local testMode = RunService:IsStudio() and STUDIO_MODE or "normal"
if testMode ~= "normal" then print("[ClassSystem] Studio test mode: " .. testMode) end

local isLobby = game.PlaceId == LOBBY_PLACE_ID
local applyHere = APPLY_IN_LOBBY or not isLobby
local accessoriesHere = applyHere or ACCESSORIES_IN_LOBBY

-- find the accessories folder
local accessoryFolder
for _, parent in ipairs({ ServerStorage, ReplicatedStorage }) do
    for _, folderName in ipairs(ACCESSORY_FOLDERS) do
        accessoryFolder = accessoryFolder or parent:FindFirstChild(folderName)
    end
end
if accessoriesHere and not accessoryFolder then
    warn("[ClassSystem] No accessories folder found. Put a Folder called \"ClassAccessories\" in ServerStorage"
        .. " (in this place) with a folder or Accessory for each class.")
elseif accessoryFolder and DEBUG_PRINTS then
    print("[ClassSystem] using accessories from " .. accessoryFolder:GetFullName())
end
local store = DataStoreService:GetDataStore(STORE_NAME)

local byName = {}
for _, c in ipairs(CLASSES) do byName[c.name] = c end

local rarityRank = {}
for i, r in ipairs(RARITY_ORDER) do rarityRank[r] = i end

-- the buttons talk to us through this; the class list and prices are stored on it for the buttons
local remote = ReplicatedStorage:FindFirstChild("RollClass")
if not remote then
    remote = Instance.new("RemoteFunction")
    remote.Name = "RollClass"
    remote.Parent = ReplicatedStorage
end
local list = {}
for _, c in ipairs(CLASSES) do
    table.insert(list, { name = c.name, rarity = c.rarity, color = (RARITY_COLORS[c.rarity] or Color3.new(1, 1, 1)):ToHex() })
end
local shownPrices = {}
for i, p in ipairs(SLOT_PRICES) do shownPrices[i] = testMode == "free" and 0 or p end
remote:SetAttribute("ClassList", HttpService:JSONEncode(list))
remote:SetAttribute("RollCost", testMode == "free" and 0 or ROLL_COST)
remote:SetAttribute("SlotPrices", HttpService:JSONEncode(shownPrices))
remote:SetAttribute("MaxSlots", MAX_SLOTS)
remote:SetAttribute("Version", 3) -- the slot buttons check this to make sure this new version is running

-- player -> { slots = {"Ninja", "", ...}, count = 2, equipped = 1 }   ("" = empty slot)
local data = {}
local loaded = {}     -- player -> true once their classes were read
local dirty = {}      -- player -> true when there's something not saved yet
local lastAction = {} -- player -> time of their last roll / buy

local function withRetries(fn)
    local ok, result
    for attempt = 1, RETRIES do
        ok, result = pcall(fn)
        if ok then return true, result end
        task.wait(attempt)
    end
    return false, result
end

local function newData()
    return { slots = { "" }, count = 1, equipped = 1 }
end

-- the class in the equipped slot (or nil)
local function equippedClass(player)
    local d = data[player]
    if not d then return nil end
    local name = d.slots[d.equipped]
    return byName[name or ""]
end

-- tells the buttons (on the player's screen) what the player has
local function refresh(player)
    local d = data[player]
    if not d then return end
    for i = 1, d.count do d.slots[i] = d.slots[i] or "" end
    local cls = equippedClass(player)
    player:SetAttribute("Class", cls and cls.name or nil)
    player:SetAttribute("ClassRarity", cls and cls.rarity or nil)
    player:SetAttribute("ClassSlots", d.count)
    player:SetAttribute("ClassEquipped", d.equipped)
    player:SetAttribute("ClassSlotData", HttpService:JSONEncode(d.slots))
end

-- prints what is in every slot, like:  Slot1 = Ninja, Slot2 = Runner, Slot3 = Empty  |  EQUIPPED: Slot2
local function describe(player)
    local d = data[player]
    if not d then return "(no data)" end
    local parts = {}
    for i = 1, d.count do
        local name = d.slots[i]
        table.insert(parts, "Slot" .. i .. " = " .. ((name and name ~= "") and name or "Empty"))
    end
    return table.concat(parts, ", ") .. "  |  EQUIPPED: Slot" .. d.equipped
end

-- other scripts can ask: _G.GetClass(player) -> "Ninja" (or nil)
_G.GetClass = function(player)
    local cls = equippedClass(player)
    return cls and cls.name or nil
end

---------------- ROLLING ----------------
local function rollClass()
    local total = 0
    for _, c in ipairs(CLASSES) do total += c.chance end
    local pick = math.random() * total
    for _, c in ipairs(CLASSES) do
        pick -= c.chance
        if pick <= 0 then return c end
    end
    return CLASSES[1]
end
-----------------------------------------

---------------- APPLYING THE CLASS ----------------
local function addLooks(character, cls)
    local color = RARITY_COLORS[cls.rarity] or Color3.new(1, 1, 1)
    for _, name in ipairs({ "ClassTitle", "ClassAura" }) do
        local old = character:FindFirstChild(name, true)
        if old then old:Destroy() end
    end

    local head = character:FindFirstChild("Head")
    if SHOW_TITLE and head then
        local gui = Instance.new("BillboardGui")
        gui.Name = "ClassTitle"
        gui.Size = UDim2.new(5, 0, 1, 0)
        gui.StudsOffset = Vector3.new(0, 2.6, 0)
        gui.MaxDistance = 80
        gui.Adornee = head
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text = cls.name
        label.TextColor3 = color
        label.TextStrokeTransparency = 0
        label.TextScaled = true
        label.FontFace = Font.new(TITLE_FONT)
        label.Parent = gui
        gui.Parent = head
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if root and (rarityRank[cls.rarity] or 0) >= (rarityRank[AURA_FROM] or 99) then
        local aura = Instance.new("ParticleEmitter")
        aura.Name = "ClassAura"
        aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        aura.Color = ColorSequence.new(color)
        aura.LightEmission = 1
        aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
        aura.Lifetime = NumberRange.new(0.8, 1.4)
        aura.Speed = NumberRange.new(1, 3)
        aura.SpreadAngle = Vector2.new(180, 180)
        aura.Rate = cls.rarity == "Legendary" and 18 or 7
        aura.Parent = root
    end
end

-- the accessories that belong to a class (a folder named like the class, or an Accessory named like it)
local function accessoriesFor(className)
    local found = {}
    if not accessoryFolder then return found end
    for _, child in ipairs(accessoryFolder:GetChildren()) do
        if string.lower(child.Name) == string.lower(className) then
            if child:IsA("Accessory") then
                table.insert(found, child)
            else
                for _, d in ipairs(child:GetDescendants()) do
                    if d:IsA("Accessory") then table.insert(found, d) end
                end
            end
        end
    end
    return found
end

-- takes off the old class accessories and puts on the ones for this class (cls = nil just takes them off)
local function putOnAccessories(character, cls)
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    for _, a in ipairs(character:GetChildren()) do
        if a:IsA("Accessory") and a:GetAttribute("ClassAccessory") then a:Destroy() end
    end
    if not cls then return end
    local list = accessoriesFor(cls.name)
    if #list == 0 and DEBUG_PRINTS and accessoryFolder then
        print("[ClassSystem] no accessories for " .. cls.name .. " in " .. accessoryFolder:GetFullName())
    end
    for _, accessory in ipairs(list) do
        local copy = accessory:Clone()
        copy:SetAttribute("ClassAccessory", true) -- so we know which ones to take off later
        local ok, err = pcall(function() hum:AddAccessory(copy) end)
        if not ok then
            warn("[ClassSystem] couldn't put on " .. accessory.Name .. ": " .. tostring(err))
            copy:Destroy()
        end
    end
end

local function applyClass(player, character)
    if not applyHere and not accessoriesHere then return end
    local hum = character:WaitForChild("Humanoid", 10)
    if not hum then return end
    task.wait(APPLY_DELAY) -- other scripts (like LevelSystem) set health/speed first, then we add on top
    if not character.Parent or hum.Health <= 0 or player.Character ~= character then return end
    local cls = equippedClass(player)
    if accessoriesHere then putOnAccessories(character, cls) end
    if not applyHere or not cls then return end
    if character:GetAttribute("ClassApplied") then return end
    character:SetAttribute("ClassApplied", true)
    character:SetAttribute("Class", cls.name)

    if cls.health and cls.health ~= 0 then
        hum.MaxHealth += cls.health
        hum.Health = hum.MaxHealth
    end
    if cls.speed and cls.speed ~= 1 then
        hum.WalkSpeed *= cls.speed
    end
    if cls.jump and cls.jump ~= 1 then
        if hum.UseJumpPower then
            hum.JumpPower *= cls.jump
        else
            hum.JumpHeight *= cls.jump
        end
    end
    addLooks(character, cls)
    if DEBUG_PRINTS then print("[ClassSystem] " .. player.Name .. " plays as " .. cls.name) end
end
-----------------------------------------------------

---------------- LOAD / SAVE ----------------
local function load(player)
    if testMode == "free" then
        data[player] = newData()
        loaded[player] = true
        refresh(player)
        return
    end
    local ok, saved = withRetries(function()
        return store:GetAsync("Player_" .. player.UserId)
    end)
    if not ok then
        warn("[ClassSystem] Couldn't load " .. player.Name .. "'s classes: " .. tostring(saved))
        return
    end

    local d = newData()
    if type(saved) == "string" then
        -- old save from before slots: put that class in slot 1
        if byName[saved] then d.slots[1] = saved end
    elseif type(saved) == "table" then
        d.count = math.clamp(tonumber(saved.count) or 1, 1, MAX_SLOTS)
        d.equipped = math.clamp(tonumber(saved.equipped) or 1, 1, d.count)
        d.slots = {}
        for i = 1, d.count do
            local name = type(saved.slots) == "table" and saved.slots[i] or ""
            d.slots[i] = byName[name or ""] and name or ""
        end
    end
    data[player] = d
    loaded[player] = true
    refresh(player)
    if DEBUG_PRINTS then print("[ClassSystem] loaded " .. player.Name .. ": " .. describe(player)) end
end

local function save(player)
    if testMode ~= "normal" then return true end -- Studio test: never touch the real saved data
    if not loaded[player] or not dirty[player] or not data[player] then return true end
    local d = data[player]
    local copy = { slots = table.clone(d.slots), count = d.count, equipped = d.equipped }
    local ok, err = withRetries(function()
        return store:UpdateAsync("Player_" .. player.UserId, function(old)
            -- never lose a slot that was bought in the other place
            if type(old) == "table" and tonumber(old.count) and tonumber(old.count) > copy.count then
                for i = copy.count + 1, math.min(tonumber(old.count), MAX_SLOTS) do
                    copy.slots[i] = type(old.slots) == "table" and old.slots[i] or ""
                end
                copy.count = math.min(tonumber(old.count), MAX_SLOTS)
            end
            return copy
        end)
    end)
    if ok then
        dirty[player] = nil
        if DEBUG_PRINTS then print("[ClassSystem] saved " .. player.Name) end
        return true
    end
    warn("[ClassSystem] Couldn't save " .. player.Name .. "'s classes, will try again: " .. tostring(err))
    return false
end

local function changed(player)
    dirty[player] = true
    refresh(player)
    -- swap the accessories right away when you equip another slot or roll a new class
    if accessoriesHere and player.Character then
        task.spawn(putOnAccessories, player.Character, equippedClass(player))
    end
    task.spawn(save, player) -- save right away so it's never lost
end
----------------------------------------------

local function spend(player, cost)
    if testMode == "free" or cost <= 0 then return true end
    if not _G.SpendBounty then
        warn("[ClassSystem] _G.SpendBounty not found - is BountyStat in ServerScriptService?")
        return false, "Shop offline"
    end
    if not _G.SpendBounty(player, cost) then return false, "Not enough Bounty" end
    return true
end

---------------- THE BUTTONS ----------------
-- RollButton:     InvokeServer()  or ("roll")        -> success, className, rarity-or-message
-- BuySlotButton:  InvokeServer("buy")                -> success, newSlotNumber, message
-- SlotButton:     InvokeServer("equip", slotNumber)  -> success, slotNumber, message
remote.OnServerInvoke = function(player, action, arg)
    action = action or "roll"
    local d = data[player]
    if not loaded[player] or not d then return false, nil, "Loading..." end

    if action == "equip" then
        local slot = math.floor(tonumber(arg) or 0)
        if slot < 1 or slot > d.count then return false, nil, "Locked" end
        d.equipped = slot
        changed(player)
        if DEBUG_PRINTS then print("[ClassSystem] " .. player.Name .. " equipped Slot" .. slot .. "  ->  " .. describe(player)) end
        return true, slot, "Equipped"
    end

    local now = os.clock()
    if now - (lastAction[player] or -1e9) < ACTION_COOLDOWN then return false, nil, "Wait..." end
    lastAction[player] = now

    if action == "buy" then
        local nextSlot = d.count + 1
        local price = SLOT_PRICES[nextSlot]
        if not price then return false, nil, "Max slots" end
        local ok, msg = spend(player, price)
        if not ok then return false, nil, msg end
        d.count = nextSlot
        d.slots[nextSlot] = ""
        d.equipped = nextSlot -- select the new slot so the next roll fills it
        changed(player)
        if DEBUG_PRINTS then print("[ClassSystem] " .. player.Name .. " bought Slot" .. nextSlot .. "  ->  " .. describe(player)) end
        return true, nextSlot, "Slot " .. nextSlot .. " unlocked!"
    end

    if action == "roll" then
        local ok, msg = spend(player, ROLL_COST)
        if not ok then return false, nil, msg end
        local cls = rollClass()
        d.slots[d.equipped] = cls.name -- ONLY the equipped slot changes, the other slots are not touched
        changed(player)
        if DEBUG_PRINTS then
            print("[ClassSystem] " .. player.Name .. " rolled " .. cls.name .. " (" .. cls.rarity .. ") into Slot"
                .. d.equipped .. "  ->  " .. describe(player))
        end
        return true, cls.name, cls.rarity
    end

    return false, nil, "Unknown"
end
----------------------------------------------

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(character)
        applyClass(player, character)
    end)
    load(player)
    if player.Character then task.spawn(applyClass, player, player.Character) end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
    save(player)
    data[player] = nil
    loaded[player] = nil
    dirty[player] = nil
    lastAction[player] = nil
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
        if dirty[player] then task.spawn(save, player) end
    end
end

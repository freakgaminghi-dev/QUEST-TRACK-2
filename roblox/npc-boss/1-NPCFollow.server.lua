-- NPCFollow v7 ULTRA BOSS (Script)
-- WHERE: INSIDE the NPC model in ServerStorage  ->  Script  ->  name it "NPCFollow"
-- PLACE: GAME place
--
-- 2000 HP boss, slower than you but hits HARD. Big hits ragdoll you. 500 Bounty to everyone when it dies.
--
-- ATTACKS (each one can be turned off / tuned in the CONFIG):
--   MELEE        3-hit combo with glowing slashes. The 3rd hit launches you.
--   FLURRY       FAST but little damage: 8 quick jabs while it dashes at you.
--   HEAVY SMASH  Jumps, glows RED, then crashes down. Cracks the ground. Huge damage.
--   ENERGY BALL  Long range: charges a purple ball and throws it where you're running.
--   BARRAGE      Long range: 5 balls float over its head, then fire in a fan.
--   GUARD        DEFENCE: a shield bubble blocks most damage, then explodes outward.
--   METEOR RAIN  DODGE IT: red circles appear under you - get out before the meteors land!
--   SHOCK RINGS  DODGE IT: 3 rings of energy roll outward - JUMP over them!
--   DEATH LASER  OP (from phase 2): charges, then sweeps a giant laser across the area. Hide or jump!
--   GROUND SLAM  (from phase 2) red circle on the ground, then a shockwave.
--
-- Still in: easy jukes (ankle breaks), contact hits, lunge, roar at phase change, flanking,
-- dodging, bleeding, health phases (it gets stronger at 60% and 30% health), dollar reward.
--
-- Gun / weapon scripts can credit damage by setting either:
--   humanoid.creator (ObjectValue -> Player)   -- the classic Roblox tag
--   npc:SetAttribute("LastAttacker", player.UserId)
-- and can tag headshots with npc:SetAttribute("LastHit", "Head").

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

---------------- CONFIG ----------------
local CFG = {
    -- BOSS HEALTH
    MAX_HEALTH            = 2000,      -- the NPC's health

    -- SPECIAL ATTACKS (laser, meteors, rings, barrage) wait at least this long after each other
    SPECIAL_GAP           = 4,

    -- SHOW ATTACK AREAS (for testing): every attack flashes a see-through shape where it can hit you
    SHOW_ATTACK_AREAS     = true,      -- false = hide them (turn off before publishing!)
    AREA_COLOR            = Color3.fromRGB(255, 0, 0),    -- colour of attack areas
    CONTACT_AREA_COLOR    = Color3.fromRGB(255, 220, 0),  -- colour of the "touching it hurts" box
    AREA_TRANSPARENCY     = 0.75,      -- 0 = solid, 1 = invisible

    -- MELEE: 3-hit combo
    ATTACK_DAMAGE         = 60,        -- damage per hit
    ATTACK_RANGE          = 20,        -- starts a swing when this close
    ATTACK_BOX            = Vector3.new(14, 8, 13), -- hitbox in front of it: width, height, depth
    ATTACK_BOX_BACK       = 2,         -- studs the box extends behind its root
    ATTACK_BOX_DEBUG      = false,     -- true = flashes the hitbox so you can tune the size
    ATTACK_COOLDOWN       = 0.75,
    WINDUP_TIME           = 0.35,
    RECOVERY_TIME         = 0.25,
    COMBO_HITS            = 3,
    COMBO_RESET           = 2.5,
    FINISHER_MULT         = 1.5,
    FINISHER_KNOCKBACK    = 45,
    SLASH_COLOR           = Color3.fromRGB(255, 80, 60),  -- colour of the slash effect

    -- FLURRY: fast but little damage
    FLURRY_ENABLED        = true,
    FLURRY_RANGE          = 10,        -- does it when you are this close
    FLURRY_COOLDOWN       = 6,
    FLURRY_HITS           = 8,         -- number of jabs
    FLURRY_INTERVAL       = 0.09,      -- seconds between jabs
    FLURRY_DAMAGE         = 6,         -- damage per jab
    FLURRY_DASH           = 28,        -- little dash forward on every jab
    FLURRY_BOX            = Vector3.new(8, 7, 9),
    FLURRY_COLOR          = Color3.fromRGB(255, 240, 120),

    -- HEAVY SMASH: jumps, glows red, crashes down
    HEAVY_ENABLED         = true,
    HEAVY_RANGE           = 9,         -- does it when you are this close
    HEAVY_COOLDOWN        = 7,
    HEAVY_WINDUP          = 1.0,       -- seconds it glows red before hitting (your warning)
    HEAVY_JUMP            = 45,        -- how high it jumps before crashing down
    HEAVY_DAMAGE          = 90,
    HEAVY_BOX             = Vector3.new(16, 10, 14),
    HEAVY_FLING_MULT      = 1.6,       -- launches you this much harder than other hits
    HEAVY_RECOVERY        = 0.6,
    HEAVY_GLOW_COLOR      = Color3.fromRGB(255, 30, 30),

    -- ENERGY BALL: long range
    RANGED_ENABLED        = true,
    RANGED_MIN_RANGE      = 22,        -- only throws when you are at least this far away
    RANGED_MAX_RANGE      = 90,        -- and no further than this
    RANGED_NEEDS_SIGHT    = true,      -- true = long range attacks only if it can see you
    RANGED_COOLDOWN       = 5,
    RANGED_WINDUP         = 0.8,       -- seconds it charges the ball (your warning)
    RANGED_DAMAGE         = 35,
    RANGED_SPEED          = 80,        -- studs per second
    RANGED_HIT_RADIUS     = 4,
    RANGED_MAX_TRAVEL     = 150,
    RANGED_BALL_SIZE      = 2.5,
    RANGED_COLOR          = Color3.fromRGB(170, 60, 255), -- purple
    RANGED_RAGDOLL        = true,

    -- BARRAGE: 5 balls in a fan (long range special)
    BARRAGE_ENABLED       = true,
    BARRAGE_COOLDOWN      = 10,
    BARRAGE_COUNT         = 5,
    BARRAGE_WINDUP        = 0.7,
    BARRAGE_INTERVAL      = 0.08,      -- seconds between each ball firing
    BARRAGE_SPREAD        = 40,        -- degrees of the fan
    BARRAGE_DAMAGE        = 15,        -- per ball
    BARRAGE_SPEED         = 95,
    BARRAGE_HIT_RADIUS    = 3,
    BARRAGE_BALL_SIZE     = 1.4,
    BARRAGE_COLOR         = Color3.fromRGB(80, 200, 255), -- light blue

    -- GUARD (defence): shield bubble, then it explodes outward
    GUARD_ENABLED         = true,
    GUARD_CHANCE          = 0.3,       -- chance to raise the shield when it gets hit
    GUARD_COOLDOWN        = 12,
    GUARD_TIME            = 2.5,       -- seconds the shield stays up
    GUARD_BLOCK           = 0.85,      -- 0.85 = blocks 85% of damage
    GUARD_PUSH_RADIUS     = 16,        -- the explosion at the end
    GUARD_PUSH_DAMAGE     = 20,
    GUARD_COLOR           = Color3.fromRGB(90, 230, 255),

    -- METEOR RAIN (dodge it!): red circles under players, then meteors land there
    METEOR_ENABLED        = true,
    METEOR_RANGE          = 90,        -- targets players within this distance
    METEOR_COOLDOWN       = 15,
    METEOR_PER_PLAYER     = 3,         -- meteors aimed at each player
    METEOR_SPREAD         = 12,        -- the extra meteors land this far around you
    METEOR_STAGGER        = 0.25,      -- seconds between each meteor starting
    METEOR_WARN           = 1.4,       -- seconds the red circle shows before impact (your warning)
    METEOR_RADIUS         = 8,         -- size of the blast
    METEOR_DAMAGE         = 45,
    METEOR_SIZE           = 5,

    -- SHOCK RINGS (dodge it!): jump over the rings
    RINGS_ENABLED         = true,
    RINGS_COOLDOWN        = 12,
    RINGS_COUNT           = 3,         -- number of rings
    RINGS_GAP             = 0.7,       -- seconds between rings
    RINGS_WINDUP          = 1.0,       -- jumps and glows orange first (your warning)
    RINGS_JUMP            = 70,        -- how high it jumps
    RINGS_SPEED           = 30,        -- how fast the rings grow (studs per second)
    RINGS_MAX_RADIUS      = 45,        -- how far the rings go
    RINGS_HEIGHT          = 2.5,       -- how tall the rings look
    RINGS_THICKNESS       = 2.5,       -- how thick the hit zone is
    RINGS_JUMP_CLEARANCE  = 5,         -- you must be this high (root above ground) to jump over
    RINGS_DAMAGE          = 35,
    RINGS_COLOR           = Color3.fromRGB(255, 150, 40), -- orange

    -- DEATH LASER (OP): sweeps a giant beam across the area
    LASER_ENABLED         = true,
    LASER_MIN_PHASE       = 2,         -- 1 = from the start, 2 = below 60% health, 3 = below 30%
    LASER_COOLDOWN        = 20,
    LASER_RANGE           = 80,
    LASER_CHARGE          = 1.2,       -- seconds it charges (your warning)
    LASER_SWEEP           = 120,       -- degrees the beam sweeps
    LASER_SWEEP_TIME      = 2.0,       -- seconds the sweep takes
    LASER_WIDTH           = 3,
    LASER_DAMAGE          = 20,        -- damage every LASER_TICK seconds while you are in the beam
    LASER_TICK            = 0.3,
    LASER_COLOR           = Color3.fromRGB(255, 40, 120), -- hot pink

    -- GROUND SLAM (from phase 2, or when 2+ players are close)
    SLAM_ENABLED          = true,
    SLAM_RADIUS           = 20,
    SLAM_TRIGGER_RANGE    = 10,
    SLAM_MIN_PHASE        = 2,
    SLAM_COOLDOWN         = 8,
    SLAM_WINDUP           = 0.9,
    SLAM_DAMAGE           = 50,
    SLAM_KNOCKBACK        = 60,
    SLAM_JUMP_CLEARANCE   = 3.5,

    -- CONTACT DAMAGE: bumping into it hurts
    CONTACT_ENABLED       = true,
    CONTACT_DAMAGE        = 25,
    CONTACT_COOLDOWN      = 1.2,       -- per player
    CONTACT_PADDING       = 0.4,       -- studs of extra reach around its body

    -- FLING / RAGDOLL: big hits launch players and make them go limp
    FLING_ENABLED         = true,
    FLING_SPEED           = 100,       -- sideways launch speed
    FLING_UP              = 65,        -- upward launch speed
    FLING_ON_CONTACT      = true,      -- touching it = instant hit + launch
    FLING_ON_FINISHER     = true,      -- the 3rd hit of its combo launches you
    FLING_ON_SLAM         = true,      -- the ground slam launches you
    RAGDOLL_ENABLED       = true,      -- true = body goes limp (false = just knocked down stiff)
    RAGDOLL_TIME          = 2.5,       -- seconds the player stays ragdolled
    RAGDOLL_SPIN          = 14,        -- how fast the body spins while flying (0 = no spin)

    -- SPEED: slower than the player (80-90% of their speed)
    SPEED_ROLLS = {
        { name = "Slow", weight = 100, min = 0.80, max = 0.90 },
    },
    MATCH_PLAYER_SPEED    = true,
    SPEED_BONUS           = 0,         -- extra speed on top
    BASE_SPEED            = nil,       -- nil = the WalkSpeed the NPC already has
    MAX_SPEED             = math.huge,
    SPRINT_ENABLED        = true,
    SPRINT_MULT           = 1.3,       -- sprint speed (x the player's speed)
    SPRINT_DURATION       = 3,
    SPRINT_COOLDOWN       = 12,
    SPRINT_MIN_DISTANCE   = 12,
    SPRINT_START_READY    = true,
    RAGE_ENABLED          = false,
    RAGE_PER_SECOND       = 1,
    RAGE_MAX_BONUS        = 20,
    RAGE_RESET_DIST       = 6,

    -- SKILL: makes it smarter, never faster or harder hitting. 0 = clumsy, 1 = expert
    SKILL                 = 10.0,
    INTERCEPT_ENABLED     = true,
    LEAD_SWING            = true,
    TIMING_JITTER         = 0.3,
    FEINT_CHANCE          = 0.3,
    FEINT_PAUSE           = 0.3,
    ORBIT_ENABLED         = true,
    ORBIT_SPEED_MULT      = 0.8,
    READ_ATTACKS          = true,
    READ_ATTACK_CHANCE    = 0.45,
    READ_ATTACK_RANGE     = 30,
    READ_ATTACK_COOLDOWN  = 2.5,
    LEARN_ENABLED         = true,
    LEARN_ANKLE_RESIST    = 1.0,       -- 1.0 = it never gets harder to juke
    LEARN_MIN_ANKLE_CHANCE= 0.2,
    JUKE_MEMORY           = 6,

    -- Movement / awareness
    GHOST_MODE            = true,      -- true = glides through walls, false = walks (uses pathfinding)
    GHOST_STAY_GROUNDED   = true,
    AGGRO_RANGE           = math.huge,
    REQUIRE_LINE_OF_SIGHT = false,
    LOSE_AGGRO_TIME       = 4,
    SEARCH_TIME           = 5,
    STOP_DISTANCE         = 4.5,
    TICK                  = 0.1,
    USE_PATHFINDING       = true,
    PATH_RECOMPUTE        = 0.6,
    JUMP_WHEN_STUCK       = true,
    PATROL_ENABLED        = true,
    PATROL_RADIUS         = 30,
    PATROL_SPEED_MULT     = 0.5,

    -- "Real player" feel
    REACTION_TIME         = 0.1,
    PREDICT_MOVEMENT      = true,
    PREDICT_TIME          = 0.4,
    WOBBLE                = 2.5,
    PACE_VARIATION        = 0.03,
    GHOST_ACCEL           = 9,
    GHOST_BRAKE           = 5,
    GHOST_TURN            = 12,
    GHOST_SLOW_RADIUS     = 5,
    GHOST_JUMP_POWER      = 50,
    GHOST_LUNGE_HOP       = 28,
    GHOST_STEP_UP         = 4,
    GHOST_CLIMB_HEIGHT    = 5,
    GHOST_CLIMB_SPEED     = 25,
    MIMIC_JUMPS           = true,
    MIMIC_JUMP_RANGE      = 35,
    MIMIC_JUMP_CHANCE     = 0.6,
    MIMIC_JUMP_COOLDOWN   = 1.2,

    -- ANKLE BREAK: change direction hard while it's close and it trips
    ANKLE_ENABLED         = true,
    ANKLE_WINDOW          = 0.7,
    ANKLE_MIN_ANGLE       = 70,
    ANKLE_MIN_SPEED       = 6,
    ANKLE_MIN_NPC_SPEED   = 3,
    ANKLE_MIN_DIST        = 2,
    ANKLE_RANGE           = 24,
    ANKLE_CHANCE          = 0.95,
    ANKLE_COOLDOWN        = 2.5,
    ANKLE_STUMBLE_TIME    = 1.8,
    ANKLE_DAMAGE          = 10,
    ANKLE_BIG_FX          = true,
    ANKLE_HOP             = 22,

    -- Lunge
    LUNGE_ENABLED         = true,
    LUNGE_RANGE           = 18,
    LUNGE_COOLDOWN        = 3,
    LUNGE_POWER           = 60,
    LUNGE_DASH_MULT       = 3,
    LUNGE_DASH_TIME       = 0.4,
    LUNGE_DAMAGE_MULT     = 2,

    -- Phase change roar
    ROAR_RADIUS           = 18,
    ROAR_KNOCKBACK        = 70,
    ROAR_TIME             = 0.8,

    -- Flanking
    FLANK_ENABLED         = true,
    FLANK_RANGE           = 28,
    FLANK_OFFSET          = 8,

    -- Targeting
    THREAT_PER_DAMAGE     = 1,
    THREAT_WEIGHT         = 0.5,
    THREAT_DECAY          = 0.05,
    LOW_HEALTH_PREFERENCE = 20,
    STICKY_BONUS          = 15,
    SWITCH_COOLDOWN       = 3,

    -- Defense
    STAGGER_ENABLED       = true,
    STAGGER_DAMAGE_PCT    = 0.12,
    STAGGER_HEADSHOT      = true,
    STAGGER_TIME          = 0.6,
    STAGGER_COOLDOWN      = 5,
    DODGE_ENABLED         = true,
    DODGE_CHANCE          = 3,
    DODGE_COOLDOWN        = 2,
    DODGE_SPEED           = 40,
    DODGE_TIME            = 0.22,
    REGEN_PCT_PER_SEC     = 0.02,
    REGEN_DELAY           = 8,

    -- Getting hit
    BLEED_ENABLED         = true,
    BLEED_PARTICLES       = 14,
    BLEED_DRIP_TIME       = 1,
    BLEED_COLOR           = Color3.fromRGB(150, 0, 0),
    HEADSHOT_ENABLED      = false,
    HEADSHOT_MULT         = 1.5,
    HEADSHOT_WINDOW       = 0.2,

    -- Scaling / rewards / cleanup
    HEALTH_PER_EXTRA_PLAYER  = 0,      -- 0 = always exactly MAX_HEALTH (0.15 = +15% health per extra player)
    BOUNTY_REWARD_PER_PLAYER = 500,    -- Bounty EVERY player in the server gets when it dies
    DOLLAR_REWARD_PER_PLAYER = 7,
    TOP_DAMAGE_BONUS         = 10,
    CORPSE_TIME              = 5,
    HEALTHBAR_ENABLED        = false,  -- plain health bar over the head (no name)
    HEALTHBAR_DISTANCE       = 150,

    -- Animations (R6)
    IDLE_ANIM_ID    = "rbxassetid://120195917452393",
    RUN_ANIM_ID     = "rbxassetid://82089536191905",
    ATTACK_ANIM_ID  = "rbxassetid://129967390",
    LUNGE_ANIM_ID   = "rbxassetid://112301431130497",
    SLAM_ANIM_ID    = "",
    STAGGER_ANIM_ID = "",
    ANKLE_ANIM_ID   = "",
    RANGED_ANIM_ID  = "",   -- optional throw animation
    HEAVY_ANIM_ID   = "",   -- optional smash animation ("" = uses the attack animation)
    RUN_ANIM_SPEED_MULT   = 5,
    RUN_ANIM_NORMAL_SPEED = 16,

    -- Sounds (leave "" for none)
    SOUNDS = {
        windup = "",
        hit    = "",
        slam   = "",
        roar   = "",
        ankle  = "",
        sprint = "",
        ranged = "",   -- when it throws a ball
        heavy  = "",   -- when the heavy smash lands
        laser  = "",   -- when the laser fires
        meteor = "",   -- when a meteor lands
        guard  = "",   -- when the shield goes up
        rings  = "",   -- when a ring is sent out
    },
}

-- Health phases (phases only go up). It gets faster, stronger and quicker to attack.
local PHASES = {
    { threshold = 1.0, speedMult = 1.0,  damageMult = 1.0,  cooldownMult = 1.0,  barColor = Color3.fromRGB(80, 200, 80) },
    { threshold = 0.6, speedMult = 1.05, damageMult = 1.25, cooldownMult = 0.85, barColor = Color3.fromRGB(230, 170, 40) },
    { threshold = 0.3, speedMult = 1.1,  damageMult = 1.5,  cooldownMult = 0.7,  barColor = Color3.fromRGB(220, 50, 50) },
}
----------------------------------------

-- skill level 0..1 (smarter, never faster or harder-hitting)
local SK = math.clamp(CFG.SKILL, 0, 1)

local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local root = npc:WaitForChild("HumanoidRootPart")
local head = npc:FindFirstChild("Head")
local torso = npc:FindFirstChild("Torso") or root

pcall(function() root:SetNetworkOwner(nil) end)

local rng = Random.new()
local noiseSeed = rng:NextNumber(1, 1000) + 0.37
local spawnPos = root.Position

-- hide Roblox's default overhead name/health display
humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

-- boss health
if CFG.MAX_HEALTH and CFG.MAX_HEALTH > 0 then
    humanoid.MaxHealth = CFG.MAX_HEALTH
    humanoid.Health = CFG.MAX_HEALTH
end

-- scale health with the number of players
if CFG.HEALTH_PER_EXTRA_PLAYER > 0 then
    local extra = math.max(#Players:GetPlayers() - 1, 0)
    humanoid.MaxHealth *= 1 + extra * CFG.HEALTH_PER_EXTRA_PLAYER
    humanoid.Health = humanoid.MaxHealth
end

task.wait(0.5) -- let other scripts set WalkSpeed first
local baseSpeed = CFG.BASE_SPEED or humanoid.WalkSpeed

-- root-to-ground distance for this rig
local FEET_OFFSET = root.Size.Y / 2 + humanoid.HipHeight
if humanoid.RigType == Enum.HumanoidRigType.R6 then
    local leg = npc:FindFirstChild("Left Leg")
    FEET_OFFSET += leg and leg.Size.Y or 2
end

---------------- SPEED ROLL ----------------
local function rollSpeed()
    local total = 0
    for _, r in ipairs(CFG.SPEED_ROLLS) do total += r.weight end
    local pick = rng:NextNumber(0, total)
    for _, r in ipairs(CFG.SPEED_ROLLS) do
        pick -= r.weight
        if pick <= 0 then return r.name, rng:NextNumber(r.min, r.max) end
    end
    return "Even", 1
end
local speedRollName, speedFactor = rollSpeed()
npc:SetAttribute("SpeedRoll", speedRollName)
npc:SetAttribute("SpeedFactor", math.floor(speedFactor * 100) / 100)

---------------- STATE ----------------
local state = "Idle"
local function setState(s)
    if s ~= state then
        state = s
        npc:SetAttribute("State", s)
    end
end

local phaseIndex = 1
local busy = false
local actionToken = 0
local dead = false
local staggeredUntil = 0
-- when each attack was last used (kept in ONE table: Roblox only allows 200 local variables per script)
-- specials start part-way through their cooldown so the fight doesn't open with all of them at once
local function startCooldown(cd) return os.clock() - cd * rng:NextNumber(0.2, 0.6) end
local T = {
    lastStagger = -1e9, lastAttack = -1e9, lastLunge = -1e9, lastSlam = -1e9, lastDodge = -1e9,
    lastAttackEnd = -1e9, lastAnkle = -1e9, lastMimic = -1e9,
    lastRanged = -1e9, lastHeavy = -1e9, lastFlurry = -1e9, lastGuard = -1e9,
    lastBarrage = startCooldown(CFG.BARRAGE_COOLDOWN),
    lastMeteor  = startCooldown(CFG.METEOR_COOLDOWN),
    lastRings   = startCooldown(CFG.RINGS_COOLDOWN),
    lastLaser   = startCooldown(CFG.LASER_COOLDOWN),
    lastSpecial = os.clock(),
}
local guardUntil  = 0

local comboIndex = 0
local lungeHitUntil = 0
local lastDamagedAt = -1e9
local threat, damageBy, lastSeen = {}, {}, {}
local currentPlayer, currentRoot, lastKnownPos, lostSince = nil, nil, nil, nil
local lastSwitch = 0
local burst = nil
local jukeHeat, lastJukeT = 0, -1e9   -- how much the player has been juking recently (0..1)
local ankleChanceNow = CFG.ANKLE_CHANCE
local facePlayer = false
local orbitSide, orbitSwitchAt = 1, 0
local lastRead = -1e9
local sprintUntil = 0
local sprintReadyAt = CFG.SPRINT_START_READY and 0 or (os.clock() + CFG.SPRINT_COOLDOWN)

-- ghost-mode physics state
local ghostTarget, ghostSpeed = nil, 0
local gVel = Vector3.zero
local vy = 0
local grounded = false
local tilt = 0
local roll = 0
local lookAtPos = nil
local yawLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
yawLook = yawLook.Magnitude > 0.01 and yawLook.Unit or Vector3.new(0, 0, -1)

Players.PlayerRemoving:Connect(function(plr)
    threat[plr], lastSeen[plr] = nil, nil
end)

---------------- HELPERS ----------------
local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
end

local function flatUnit(v)
    local f = flat(v)
    if f.Magnitude < 0.001 then return Vector3.zero end
    return f.Unit
end

-- the way the NPC is facing (flat)
local function lookDir()
    local d = flatUnit(CFG.GHOST_MODE and yawLook or root.CFrame.LookVector)
    if d.Magnitude == 0 then d = Vector3.new(0, 0, -1) end
    return d
end

-- rotate a flat direction around the up axis
local function rotateFlat(v, angle)
    local cs, sn = math.cos(angle), math.sin(angle)
    return Vector3.new(v.X * cs - v.Z * sn, v.Y, v.X * sn + v.Z * cs)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { npc }

-- raycast settings that only hit the map (not the NPC, other NPCs or players)
local function worldParams(extra)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { npc }
    local npcFolder = workspace:FindFirstChild("NPCs")
    if npcFolder then table.insert(ignore, npcFolder) end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then table.insert(ignore, p.Character) end
    end
    if extra then table.insert(ignore, extra) end
    params.FilterDescendantsInstances = ignore
    return params
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true

-- y the NPC's root should have to stand on the ground below (x, z), starting the ray at fromY
local function groundRootY(x, z, fromY)
    local excludes = { npc }
    groundParams.FilterDescendantsInstances = excludes
    local origin = Vector3.new(x, fromY, z)
    for _ = 1, 4 do
        local res = workspace:Raycast(origin, Vector3.new(0, -120, 0), groundParams)
        if not res then return nil end
        local model = res.Instance:FindFirstAncestorOfClass("Model")
        if model and model:FindFirstChildOfClass("Humanoid") then
            table.insert(excludes, model) -- don't stand on players / other NPCs
            groundParams.FilterDescendantsInstances = excludes
        else
            return res.Position.Y + FEET_OFFSET
        end
    end
    return nil
end

local function canSee(targetRoot)
    local origin = (head or root).Position
    local result = workspace:Raycast(origin, targetRoot.Position - origin, rayParams)
    return result == nil or result.Instance:IsDescendantOf(targetRoot.Parent)
end

local function isClear(goal)
    local result = workspace:Raycast(root.Position, goal - root.Position, rayParams)
    if not result then return true end
    local model = result.Instance:FindFirstAncestorOfClass("Model")
    return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
end

local function groundPoint()
    local result = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), rayParams)
    return result and result.Position or (root.Position - Vector3.new(0, FEET_OFFSET, 0))
end

-- the ground under any position (ignores players and NPCs)
local function groundAt(pos)
    local res = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -120, 0), worldParams())
    return res and res.Position or (pos - Vector3.new(0, 3, 0))
end

local function playSound(id)
    if not id or id == "" then return end
    local s = Instance.new("Sound")
    s.SoundId = id
    s.RollOffMaxDistance = 120
    s.Parent = root
    s:Play()
    Debris:AddItem(s, 5)
end

local function faceToward(pos)
    local look = flatUnit(pos - root.Position)
    if look.Magnitude == 0 then return end
    if CFG.GHOST_MODE then
        yawLook = look -- the ghost loop applies it
    else
        root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
    end
end

---------------- EFFECTS ----------------
-- a glowing effect part that nothing can touch or hit
local function fxPart(size, cf, color, material, transparency, shape)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
    if shape then p.Shape = shape end
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material or Enum.Material.Neon
    p.Transparency = transparency or 0
    p.Parent = workspace
    return p
end

local function fadeOut(p, time, grow)
    local goal = { Transparency = 1 }
    if grow then goal.Size = p.Size * grow end
    TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
    Debris:AddItem(p, time + 0.1)
end

-- a burst of glowing sparks
local function sparks(pos, color, count)
    local holder = fxPart(Vector3.new(1, 1, 1), CFrame.new(pos), color, nil, 1)
    local e = Instance.new("ParticleEmitter")
    e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    e.Color = ColorSequence.new(color)
    e.LightEmission = 1
    e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
    e.Lifetime = NumberRange.new(0.3, 0.6)
    e.Speed = NumberRange.new(20, 40)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Rate = 0
    e.Parent = holder
    e:Emit(count or 25)
    Debris:AddItem(holder, 1)
end

-- a glowing slash in front of the NPC
local function slashFx(color, width)
    local base = CFrame.lookAt(root.Position, root.Position + lookDir())
    local cf = base * CFrame.new(0, 0.5, -4) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-50, 50)))
    local p = fxPart(Vector3.new(width, 0.25, 1.2), cf, color, nil, 0.1)
    fadeOut(p, 0.25, 1.4)
end

-- dark cracks in the ground around a point
local function cracks(center, count)
    for i = 1, count do
        local ang = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
        local len = rng:NextNumber(5, 11)
        local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
        local mid = center + dir * (len / 2 + 1) + Vector3.new(0, 0.12, 0)
        local p = fxPart(Vector3.new(rng:NextNumber(0.4, 0.9), 0.2, len), CFrame.lookAt(mid, mid + dir),
            Color3.fromRGB(35, 30, 30), Enum.Material.Slate, 0)
        Debris:AddItem(p, 4)
        task.delay(1.5, function()
            if p.Parent then fadeOut(p, 1) end
        end)
    end
end

local function makeGlow(color, transparency)
    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.FillTransparency = transparency or 0.4
    hl.OutlineColor = color
    hl.DepthMode = Enum.HighlightDepthMode.Occluded
    hl.Parent = npc
    Debris:AddItem(hl, 10)
    return hl
end

---------------- ANIMATIONS ----------------
local animateScript = npc:FindFirstChild("Animate")
if animateScript then animateScript:Destroy() end

local animator = humanoid:FindFirstChildOfClass("Animator")
if not animator then
    animator = Instance.new("Animator")
    animator.Parent = humanoid
end
for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
    track:Stop(0)
end

local function loadAnim(id, looped, priority)
    if not id or id == "" then return nil end
    local anim = Instance.new("Animation")
    anim.AnimationId = id
    local track = animator:LoadAnimation(anim)
    track.Looped = looped
    track.Priority = priority
    return track
end

local idleTrack    = loadAnim(CFG.IDLE_ANIM_ID, true, Enum.AnimationPriority.Idle)
local runTrack     = loadAnim(CFG.RUN_ANIM_ID, true, Enum.AnimationPriority.Movement)
local attackTrack  = loadAnim(CFG.ATTACK_ANIM_ID, false, Enum.AnimationPriority.Action)
local lungeTrack   = loadAnim(CFG.LUNGE_ANIM_ID, false, Enum.AnimationPriority.Action)
local slamTrack    = loadAnim(CFG.SLAM_ANIM_ID, false, Enum.AnimationPriority.Action)
local staggerTrack = loadAnim(CFG.STAGGER_ANIM_ID, false, Enum.AnimationPriority.Action2)
local ankleTrack   = loadAnim(CFG.ANKLE_ANIM_ID, false, Enum.AnimationPriority.Action2)
local rangedTrack  = loadAnim(CFG.RANGED_ANIM_ID, false, Enum.AnimationPriority.Action)
local heavyTrack   = loadAnim(CFG.HEAVY_ANIM_ID, false, Enum.AnimationPriority.Action)

local isRunning = false
local function setRunning(running, speed)
    if running ~= isRunning then
        isRunning = running
        if running then
            if idleTrack then idleTrack:Stop(0.2) end
            if runTrack then runTrack:Play(0.2) end
        else
            if runTrack then runTrack:Stop(0.2) end
            if idleTrack then idleTrack:Play(0.2) end
        end
    end
    if running and runTrack then
        local rate = (speed / CFG.RUN_ANIM_NORMAL_SPEED) * CFG.RUN_ANIM_SPEED_MULT
        runTrack:AdjustSpeed(math.clamp(rate, 1, 6))
    end
end
if idleTrack then idleTrack:Play() end

---------------- OPTIONAL HEALTH BAR (no name) ----------------
local barFill
if CFG.HEALTHBAR_ENABLED and head then
    local gui = Instance.new("BillboardGui")
    gui.Name = "NPCBar"
    gui.Size = UDim2.fromOffset(110, 10)
    gui.StudsOffset = Vector3.new(0, 2.6, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = CFG.HEALTHBAR_DISTANCE
    gui.Adornee = head
    gui.Parent = head

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    bg.BorderSizePixel = 0
    bg.Parent = gui

    barFill = Instance.new("Frame")
    barFill.Size = UDim2.fromScale(1, 1)
    barFill.BorderSizePixel = 0
    barFill.BackgroundColor3 = PHASES[1].barColor
    barFill.Parent = bg
end

local function updateBar()
    if not barFill then return end
    barFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
    barFill.BackgroundColor3 = PHASES[phaseIndex].barColor
end

---------------- MOVEMENT ----------------
local path = PathfindingService:CreatePath({
    AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = false,
})
local waypoints, wpIndex, pathGoal, lastPathTime = nil, 1, nil, -1e9

local function walkTo(goal)
    if not CFG.USE_PATHFINDING or isClear(goal) then
        waypoints = nil
        humanoid:MoveTo(goal)
        return
    end
    local now = os.clock()
    if not pathGoal or now - lastPathTime >= CFG.PATH_RECOMPUTE or (goal - pathGoal).Magnitude > 8 then
        lastPathTime, pathGoal = now, goal
        local ok = pcall(function() path:ComputeAsync(root.Position, goal) end)
        if ok and path.Status == Enum.PathStatus.Success then
            waypoints = path:GetWaypoints()
            wpIndex = 2
        else
            waypoints = nil
        end
    end
    local wp = waypoints and waypoints[wpIndex]
    if wp and flat(wp.Position - root.Position).Magnitude < 4 then
        wpIndex += 1
        wp = waypoints[wpIndex]
    end
    if wp then
        humanoid:MoveTo(wp.Position)
        if wp.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
    else
        humanoid:MoveTo(goal)
    end
end

local function moveTo(pos, speed)
    if CFG.GHOST_MODE then
        ghostTarget, ghostSpeed = pos, speed
    else
        walkTo(pos)
    end
end

local function stopMoving()
    ghostTarget = nil
    if not CFG.GHOST_MODE then humanoid:MoveTo(root.Position) end
end

local function jumpNow(power)
    if CFG.GHOST_MODE then
        if grounded and CFG.GHOST_STAY_GROUNDED then
            vy = power or CFG.GHOST_JUMP_POWER
            grounded = false
        end
    else
        humanoid.Jump = true
    end
end

-- walking mode: hop over low obstacles in front of it like a player would
local function hopObstacle(goal)
    local dir = flatUnit(goal - root.Position)
    if dir.Magnitude == 0 or humanoid.FloorMaterial == Enum.Material.Air then return end
    local res = workspace:Raycast(root.Position - Vector3.new(0, FEET_OFFSET - 1, 0), dir * 3.5, rayParams)
    if res then
        local model = res.Instance:FindFirstAncestorOfClass("Model")
        if not (model and Players:GetPlayerFromCharacter(model)) then
            humanoid.Jump = true
        end
    end
end

local function doBurst(dir, speed, duration, keepFacing, hop)
    if CFG.GHOST_MODE then
        local d = CFG.GHOST_STAY_GROUNDED and flatUnit(dir) or dir.Unit
        if d.Magnitude == 0 then return end
        burst = { dir = d, speed = speed, untilT = os.clock() + duration, keepFacing = keepFacing }
        if hop and grounded and CFG.GHOST_STAY_GROUNDED then
            vy = hop
            grounded = false
        end
    else
        root.AssemblyLinearVelocity = dir * speed + Vector3.new(0, 6, 0)
    end
end

local function teleportBehind(targetRoot)
    local behind = (targetRoot.CFrame * CFrame.new(0, 0, 6)).Position
    npc:PivotTo(CFrame.lookAt(behind, targetRoot.Position))
end

---------------- RAGDOLL ----------------
-- makes a player's body go limp: joints become loose ball sockets, then it puts them back.
-- (the NPC's corpse is kept around long enough that players always get back up)
local ragdolledUntil = {} -- character -> time they get back up

local function ragdoll(char, hum, duration)
    if not char or not hum then return end
    local untilT = os.clock() + duration
    if ragdolledUntil[char] then
        ragdolledUntil[char] = math.max(ragdolledUntil[char], untilT) -- already limp: just stay down longer
        return
    end
    ragdolledUntil[char] = untilT

    local oldRequiresNeck = hum.RequiresNeck
    hum.RequiresNeck = false -- loose neck must not kill them
    hum.PlatformStand = true
    hum.AutoRotate = false

    local motors, made = {}, {}
    local hrp = char:FindFirstChild("HumanoidRootPart")
    for _, m in ipairs(char:GetDescendants()) do
        if m:IsA("Motor6D") and m.Enabled and m.Part0 and m.Part1
            and m.Name ~= "RootJoint" and m.Name ~= "Root"
            and not m:FindFirstAncestorOfClass("Tool") then
            local a0 = Instance.new("Attachment")
            a0.Name = "RagdollA0"
            a0.CFrame = m.C0
            a0.Parent = m.Part0
            local a1 = Instance.new("Attachment")
            a1.Name = "RagdollA1"
            a1.CFrame = m.C1
            a1.Parent = m.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Name = "RagdollSocket"
            socket.Attachment0 = a0
            socket.Attachment1 = a1
            socket.LimitsEnabled = true
            socket.TwistLimitsEnabled = true
            socket.UpperAngle = 70
            socket.TwistLowerAngle = -45
            socket.TwistUpperAngle = 45
            socket.Parent = m.Part0

            -- an invisible box on each limb so arms and legs land on the floor instead of sinking in
            local col = Instance.new("Part")
            col.Name = "RagdollCollider"
            col.Size = m.Part1.Size * 0.8
            col.CFrame = m.Part1.CFrame
            col.Transparency = 1
            col.CanCollide = true
            col.CanQuery = false
            col.CanTouch = false
            col.Massless = true
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = m.Part1
            weld.Part1 = col
            weld.Parent = col
            local nc = Instance.new("NoCollisionConstraint")
            nc.Part0 = col
            nc.Part1 = m.Part0
            nc.Parent = col
            if hrp then
                local nc2 = Instance.new("NoCollisionConstraint")
                nc2.Part0 = col
                nc2.Part1 = hrp
                nc2.Parent = col
            end
            col.Parent = char

            m.Enabled = false
            table.insert(motors, m)
            table.insert(made, a0)
            table.insert(made, a1)
            table.insert(made, socket)
            table.insert(made, col)
            -- safety: these get removed even if something goes wrong
            for _, inst in ipairs({ a0, a1, socket, col }) do
                Debris:AddItem(inst, duration + 15)
            end
        end
    end

    task.spawn(function()
        while char.Parent and ragdolledUntil[char] and os.clock() < ragdolledUntil[char] do
            task.wait(0.1)
        end
        ragdolledUntil[char] = nil
        for _, inst in ipairs(made) do
            if inst.Parent then inst:Destroy() end
        end
        if char.Parent and hum.Parent and hum.Health > 0 then
            for _, m in ipairs(motors) do
                if m.Parent then m.Enabled = true end
            end
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum.RequiresNeck = oldRequiresNeck
        end
    end)
end

---------------- DAMAGE ----------------
-- launches a player away from the NPC and ragdolls them. A server-made LinearVelocity replicates to the
-- player's own client, so it works even though players are network-owned by their client.
local function flingPlayer(hum, r, dir, power)
    if not CFG.FLING_ENABLED then return end
    if hum.Parent and hum.Parent:FindFirstChildOfClass("ForceField") then return end -- spawn protection
    power = power or 1
    local away = flatUnit(dir)
    if away.Magnitude == 0 then away = lookDir() end
    local vel = away * CFG.FLING_SPEED * power + Vector3.new(0, CFG.FLING_UP * power, 0)

    if CFG.RAGDOLL_ENABLED then
        ragdoll(hum.Parent, hum, CFG.RAGDOLL_TIME * (power > 1 and 1.3 or 1))
    else
        hum.PlatformStand = true -- knocked down: they cannot just walk out of the launch
        task.delay(CFG.RAGDOLL_TIME, function()
            if hum.Parent then hum.PlatformStand = false end
        end)
    end

    local att = Instance.new("Attachment")
    att.Name = "FlingAttachment"
    att.Parent = r
    local lv = Instance.new("LinearVelocity")
    lv.Attachment0 = att
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.VectorVelocity = vel
    lv.MaxForce = math.huge
    lv.Parent = r
    Debris:AddItem(lv, 0.25)

    -- spin the body while it flies
    if CFG.RAGDOLL_SPIN > 0 then
        local av = Instance.new("AngularVelocity")
        av.Attachment0 = att
        av.RelativeTo = Enum.ActuatorRelativeTo.World
        av.AngularVelocity = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1)).Unit * CFG.RAGDOLL_SPIN * power
        av.MaxTorque = math.huge
        av.Parent = r
        Debris:AddItem(av, 0.25)
    end
    Debris:AddItem(att, 0.3)
    pcall(function() r.AssemblyLinearVelocity = vel end)
end

local function damagePlayer(hum, r, amount, dir, knock, fling, flingPower)
    hum:TakeDamage(amount) -- respects spawn ForceFields
    if fling then
        flingPlayer(hum, r, dir, flingPower)
    elseif knock and knock > 0 and dir.Magnitude > 0.01 then
        pcall(function()
            r:ApplyImpulse((dir.Unit + Vector3.new(0, 0.35, 0)) * knock * r.AssemblyMass)
        end)
    end
end

local function eachLivePlayer(fn)
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local r = char and char:FindFirstChild("HumanoidRootPart")
        if hum and r and hum.Health > 0 then fn(plr, hum, r) end
    end
end

local function makeDisc(position, radius, color, transparency)
    local disc = Instance.new("Part")
    disc.Shape = Enum.PartType.Cylinder
    disc.Anchored = true
    disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.CastShadow = false, false, false, false
    disc.Material = Enum.Material.Neon
    disc.Color = color
    disc.Transparency = transparency
    disc.Size = Vector3.new(0.25, radius * 2, radius * 2)
    disc.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
    disc.Parent = workspace
    return disc
end

---------------- SHOW ATTACK AREAS ----------------
-- a see-through box where an attack hits (only when SHOW_ATTACK_AREAS is on)
local function showBox(cf, size, time, color)
    if not CFG.SHOW_ATTACK_AREAS then return end
    local p = fxPart(size, cf, color or CFG.AREA_COLOR, nil, CFG.AREA_TRANSPARENCY)
    p.Name = "AttackArea"
    Debris:AddItem(p, time)
end

-- a see-through circle on the ground where an attack hits
local function showCircle(center, radius, time)
    if not CFG.SHOW_ATTACK_AREAS then return end
    local d = makeDisc(center, radius, CFG.AREA_COLOR, CFG.AREA_TRANSPARENCY)
    d.Name = "AttackArea"
    Debris:AddItem(d, time)
end
---------------------------------------------------

local function shockwaveEffect(position, radius, color)
    local ring = makeDisc(position, radius * 0.4, color or Color3.fromRGB(255, 200, 120), 0.2)
    TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.25, radius * 2.2, radius * 2.2),
        Transparency = 1,
    }):Play()
    Debris:AddItem(ring, 0.5)
end

local function shockwaveHit(radius, damage, knock, fling)
    showCircle(groundPoint(), radius, 0.4)
    eachLivePlayer(function(_, hum, r)
        local offset = flat(r.Position - root.Position)
        local jumpedOver = (r.Position.Y - root.Position.Y) > CFG.SLAM_JUMP_CLEARANCE
        if offset.Magnitude <= radius and not jumpedOver then
            damagePlayer(hum, r, damage, offset, knock, fling)
        end
    end)
end

-- the attack box: everything inside a box in front of the NPC gets hit
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { npc }

local function meleeHitbox(damage, knock, fling, boxSize, flingPower)
    local look = lookDir()
    local box = boxSize or CFG.ATTACK_BOX
    local base = CFrame.lookAt(root.Position, root.Position + look)
    local cf = base * CFrame.new(0, 0, -(box.Z / 2 - CFG.ATTACK_BOX_BACK))

    if CFG.ATTACK_BOX_DEBUG or CFG.SHOW_ATTACK_AREAS then
        local p = fxPart(box, cf, CFG.AREA_COLOR, nil, CFG.AREA_TRANSPARENCY)
        p.Name = "AttackArea"
        Debris:AddItem(p, 0.3)
    end

    local hitPlayers, hitAny = {}, false
    for _, part in ipairs(workspace:GetPartBoundsInBox(cf, box, overlap)) do
        local model = part:FindFirstAncestorOfClass("Model")
        local plr = model and Players:GetPlayerFromCharacter(model)
        if plr and not hitPlayers[plr] then
            hitPlayers[plr] = true
            local hum = model:FindFirstChildOfClass("Humanoid")
            local r = model:FindFirstChild("HumanoidRootPart")
            if hum and r and hum.Health > 0 then
                damagePlayer(hum, r, damage, flat(r.Position - root.Position), knock, fling, flingPower)
                hitAny = true
            end
        end
    end
    return hitAny
end

local function phaseDamage(amount)
    return amount * PHASES[phaseIndex].damageMult
end

---------------- ACTIONS ----------------
-- waits out a wind-up while tracking the player (with a lead for skilled NPCs). false = cancelled
local function windupWait(token, duration, targetRoot, trackFrac)
    local start = os.clock()
    while os.clock() - start < duration do
        if token ~= actionToken then return false end
        local elapsed = os.clock() - start
        if targetRoot and targetRoot.Parent and elapsed < duration * trackFrac then
            local aim = targetRoot.Position
            if CFG.LEAD_SWING then
                aim += flat(targetRoot.AssemblyLinearVelocity) * (duration - elapsed) * SK
            end
            faceToward(aim)
        end
        task.wait()
    end
    return token == actionToken
end

-- MELEE: 3-hit combo with slashes
local function doMelee(targetRoot)
    busy = true
    local token = actionToken
    local now = os.clock()
    T.lastAttack = now
    if now - T.lastAttackEnd > CFG.COMBO_RESET then
        comboIndex = 1
    else
        comboIndex = comboIndex % CFG.COMBO_HITS + 1
    end
    local finisher = comboIndex == CFG.COMBO_HITS
    local windup = CFG.WINDUP_TIME * (finisher and 1.4 or 1)
    windup *= 1 + rng:NextNumber(-CFG.TIMING_JITTER, CFG.TIMING_JITTER) -- unpredictable timing
    local trackFrac = 0.6 + 0.25 * SK

    setState("Attack")
    playSound(CFG.SOUNDS.windup)
    if attackTrack then attackTrack:Play(0.05) end

    -- feint: starts a swing, pulls it back, pauses, then really swings (punishes early dodges)
    if not finisher and rng:NextNumber() < CFG.FEINT_CHANCE * SK then
        if not windupWait(token, windup * 0.7, targetRoot, 1) then return end
        if attackTrack then attackTrack:Stop(0.1) end
        if not windupWait(token, CFG.FEINT_PAUSE, targetRoot, 1) then return end
        windup *= 0.75
        if attackTrack then attackTrack:Play(0.05) end
    end

    if not windupWait(token, windup, targetRoot, trackFrac) then return end

    local mult = finisher and CFG.FINISHER_MULT or 1
    if os.clock() < lungeHitUntil then
        mult *= CFG.LUNGE_DAMAGE_MULT
        lungeHitUntil = 0
    end
    slashFx(CFG.SLASH_COLOR, finisher and 12 or 8)
    local landed = meleeHitbox(phaseDamage(CFG.ATTACK_DAMAGE) * mult, finisher and CFG.FINISHER_KNOCKBACK or 0, finisher and CFG.FLING_ON_FINISHER)
    if landed then
        playSound(CFG.SOUNDS.hit)
        if finisher then sparks(root.Position + lookDir() * 4, CFG.SLASH_COLOR, 30) end
    else
        -- whiffed: skilled fighters chain a follow-up swing quicker
        T.lastAttack = os.clock() - CFG.ATTACK_COOLDOWN * 0.7 * SK
    end
    T.lastAttackEnd = os.clock()

    task.wait(CFG.RECOVERY_TIME)
    if token == actionToken then busy = false end
end

-- FLURRY: lots of fast jabs, little damage each
local function doFlurry(targetRoot)
    busy = true
    local token = actionToken
    T.lastFlurry = os.clock()
    setState("Flurry")
    playSound(CFG.SOUNDS.windup)

    for _ = 1, CFG.FLURRY_HITS do
        if token ~= actionToken or dead then return end
        if targetRoot.Parent then faceToward(targetRoot.Position) end
        if attackTrack then
            attackTrack:Play(0.02)
            attackTrack:AdjustSpeed(3)
        end
        doBurst(lookDir(), CFG.FLURRY_DASH, CFG.FLURRY_INTERVAL * 0.8, true)
        slashFx(CFG.FLURRY_COLOR, 5)
        if meleeHitbox(phaseDamage(CFG.FLURRY_DAMAGE), 0, false, CFG.FLURRY_BOX) then
            playSound(CFG.SOUNDS.hit)
            sparks(root.Position + lookDir() * 3, CFG.FLURRY_COLOR, 8)
        end
        task.wait(CFG.FLURRY_INTERVAL)
    end
    T.lastAttackEnd = os.clock()

    task.wait(CFG.RECOVERY_TIME)
    if token == actionToken then busy = false end
end

-- HEAVY SMASH: jumps, glows red (warning), crashes down and cracks the ground
local function doHeavy(targetRoot)
    busy = true
    local token = actionToken
    T.lastHeavy = os.clock()
    setState("Heavy")
    playSound(CFG.SOUNDS.windup)

    local glow = makeGlow(CFG.HEAVY_GLOW_COLOR, 0.4)
    local track = heavyTrack or attackTrack
    if track then track:Play(0.05) end
    jumpNow(CFG.HEAVY_JUMP)

    local ok = windupWait(token, CFG.HEAVY_WINDUP, targetRoot, 0.7)
    glow:Destroy()
    if not ok then return end

    local ground = groundPoint()
    local landed = meleeHitbox(phaseDamage(CFG.HEAVY_DAMAGE), 0, true, CFG.HEAVY_BOX, CFG.HEAVY_FLING_MULT)
    shockwaveEffect(ground, 12, CFG.HEAVY_GLOW_COLOR)
    cracks(ground, 10)
    sparks(ground + Vector3.new(0, 1, 0), CFG.HEAVY_GLOW_COLOR, 40)
    if landed then playSound(CFG.SOUNDS.heavy) end
    T.lastAttackEnd = os.clock()

    task.wait(CFG.HEAVY_RECOVERY)
    if token == actionToken then busy = false end
end

-- a flying ball: hits the first player it passes, or stops at a wall
local function flyBall(ball, pos, dir, damage, speed, hitRadius, maxTravel, color, doRagdoll)
    local params = worldParams(ball)
    local traveled = 0

    -- see-through bubble around the ball = how close it has to pass to hit you
    local area
    if CFG.SHOW_ATTACK_AREAS then
        local d = hitRadius * 2
        area = fxPart(Vector3.new(d, d, d), CFrame.new(pos), CFG.AREA_COLOR, nil, CFG.AREA_TRANSPARENCY, Enum.PartType.Ball)
        area.Name = "AttackArea"
        Debris:AddItem(area, 10)
    end
    while traveled < maxTravel and ball.Parent do
        local dt = math.min(RunService.Heartbeat:Wait(), 0.1)
        local step = dir * speed * dt
        local wall = workspace:Raycast(pos, step, params)
        local nextPos = wall and wall.Position or (pos + step)

        local hit = false
        local seg = nextPos - pos
        eachLivePlayer(function(_, hum, r)
            if hit then return end
            local t = 0
            if seg.Magnitude > 0.001 then
                t = math.clamp((r.Position - pos):Dot(seg) / seg:Dot(seg), 0, 1)
            end
            local closest = pos + seg * t
            if (r.Position - closest).Magnitude <= hitRadius then
                hit = true
                damagePlayer(hum, r, damage, dir, 0, doRagdoll)
            end
        end)

        pos = nextPos
        ball.CFrame = CFrame.new(pos)
        if area then area.CFrame = CFrame.new(pos) end
        traveled += seg.Magnitude
        if hit or wall then break end
    end

    shockwaveEffect(pos - Vector3.new(0, 1, 0), 6, color)
    sparks(pos, color, 20)
    if ball.Parent then ball:Destroy() end
    if area then area:Destroy() end
end

-- ENERGY BALL: charges a growing ball, then throws it where you're running
local function doRanged(targetRoot)
    busy = true
    local token = actionToken
    T.lastRanged = os.clock()
    setState("Ranged")
    if rangedTrack then rangedTrack:Play(0.1) end
    playSound(CFG.SOUNDS.windup)

    local function holdPos() return root.Position + Vector3.new(0, 2.5, 0) + lookDir() * 2.5 end
    local ball = fxPart(Vector3.new(0.5, 0.5, 0.5), CFrame.new(holdPos()), CFG.RANGED_COLOR, nil, 0, Enum.PartType.Ball)
    ball.Name = "BossBall"
    local light = Instance.new("PointLight")
    light.Color = CFG.RANGED_COLOR
    light.Range = 12
    light.Brightness = 3
    light.Parent = ball
    Debris:AddItem(ball, 10)

    local start = os.clock()
    while os.clock() - start < CFG.RANGED_WINDUP do
        if token ~= actionToken or dead or not targetRoot.Parent then
            ball:Destroy()
            if token == actionToken then busy = false end
            return
        end
        faceToward(targetRoot.Position)
        local s = 0.5 + (CFG.RANGED_BALL_SIZE - 0.5) * ((os.clock() - start) / CFG.RANGED_WINDUP)
        ball.Size = Vector3.new(s, s, s)
        ball.CFrame = CFrame.new(holdPos())
        task.wait()
    end

    local from = ball.Position
    local travelTime = (targetRoot.Position - from).Magnitude / math.max(CFG.RANGED_SPEED, 1)
    local aim = targetRoot.Position + flat(targetRoot.AssemblyLinearVelocity) * travelTime * SK
    local dir = aim - from
    if dir.Magnitude < 0.1 then
        ball:Destroy()
        if token == actionToken then busy = false end
        return
    end
    playSound(CFG.SOUNDS.ranged)
    task.spawn(flyBall, ball, from, dir.Unit, phaseDamage(CFG.RANGED_DAMAGE), CFG.RANGED_SPEED,
        CFG.RANGED_HIT_RADIUS, CFG.RANGED_MAX_TRAVEL, CFG.RANGED_COLOR, CFG.RANGED_RAGDOLL)

    task.wait(CFG.RECOVERY_TIME)
    if token == actionToken then busy = false end
end

-- BARRAGE: balls float in an arc over its head, then fire one after another in a fan
local function doBarrage(targetRoot)
    busy = true
    local token = actionToken
    T.lastBarrage = os.clock()
    T.lastSpecial = T.lastBarrage
    setState("Barrage")
    playSound(CFG.SOUNDS.windup)

    local n = CFG.BARRAGE_COUNT
    local function frac(i) return n > 1 and (i - 1) / (n - 1) or 0.5 end
    local function orbPos(i)
        local ang = math.rad(-60 + 120 * frac(i))
        local look = lookDir()
        local right = Vector3.new(-look.Z, 0, look.X)
        return root.Position + Vector3.new(0, 3 + math.cos(ang) * 2.5, 0) + right * math.sin(ang) * 4
    end

    local orbs = {}
    for i = 1, n do
        local s = CFG.BARRAGE_BALL_SIZE
        orbs[i] = fxPart(Vector3.new(s, s, s), CFrame.new(orbPos(i)), CFG.BARRAGE_COLOR, nil, 0, Enum.PartType.Ball)
        Debris:AddItem(orbs[i], 10)
    end

    local start = os.clock()
    while os.clock() - start < CFG.BARRAGE_WINDUP do
        if token ~= actionToken or dead or not targetRoot.Parent then
            for _, b in ipairs(orbs) do b:Destroy() end
            if token == actionToken then busy = false end
            return
        end
        faceToward(targetRoot.Position)
        for i, b in ipairs(orbs) do b.CFrame = CFrame.new(orbPos(i)) end
        task.wait()
    end

    local damage = phaseDamage(CFG.BARRAGE_DAMAGE)
    for i, b in ipairs(orbs) do
        local to = targetRoot.Parent and (targetRoot.Position - b.Position) or lookDir()
        if to.Magnitude < 0.1 then to = lookDir() end
        local spread = math.rad(-CFG.BARRAGE_SPREAD / 2 + CFG.BARRAGE_SPREAD * frac(i))
        local dir = rotateFlat(to, spread).Unit
        playSound(CFG.SOUNDS.ranged)
        task.spawn(flyBall, b, b.Position, dir, damage, CFG.BARRAGE_SPEED, CFG.BARRAGE_HIT_RADIUS,
            CFG.RANGED_MAX_TRAVEL, CFG.BARRAGE_COLOR, false)
        task.wait(CFG.BARRAGE_INTERVAL)
    end

    task.wait(CFG.RECOVERY_TIME)
    if token == actionToken then busy = false end
end

-- GUARD (defence): a shield bubble blocks most damage, then explodes outward
local function doGuard()
    actionToken += 1 -- stops whatever it was doing
    busy = true
    burst = nil
    local token = actionToken
    T.lastGuard = os.clock()
    guardUntil = T.lastGuard + CFG.GUARD_TIME
    setState("Guard")
    playSound(CFG.SOUNDS.guard)

    local _, size = npc:GetBoundingBox()
    local s = math.max(size.X, size.Y, size.Z) * 1.2
    local bubble = fxPart(Vector3.new(s, s, s), root.CFrame, CFG.GUARD_COLOR, Enum.Material.ForceField, 0.2, Enum.PartType.Ball)
    Debris:AddItem(bubble, CFG.GUARD_TIME + 2)
    sparks(root.Position, CFG.GUARD_COLOR, 25)

    while os.clock() < guardUntil and not dead do
        bubble.CFrame = root.CFrame
        task.wait()
    end
    guardUntil = 0
    bubble:Destroy()
    if dead then return end

    -- the shield explodes
    local ground = groundPoint()
    shockwaveEffect(ground, CFG.GUARD_PUSH_RADIUS, CFG.GUARD_COLOR)
    sparks(root.Position, CFG.GUARD_COLOR, 40)
    shockwaveHit(CFG.GUARD_PUSH_RADIUS, phaseDamage(CFG.GUARD_PUSH_DAMAGE), 0, true)

    task.wait(0.3)
    if token == actionToken then busy = false end
end

-- one meteor: red warning circle, then it falls and explodes
local function meteorStrike(spot, damage)
    local R = CFG.METEOR_RADIUS
    local warnOuter = makeDisc(spot, R, Color3.fromRGB(255, 60, 20), 0.7)
    local warnInner = makeDisc(spot, 0.3, Color3.fromRGB(255, 120, 20), 0.4)
    Debris:AddItem(warnOuter, CFG.METEOR_WARN + 1)
    Debris:AddItem(warnInner, CFG.METEOR_WARN + 1)
    TweenService:Create(warnInner, TweenInfo.new(CFG.METEOR_WARN, Enum.EasingStyle.Linear), {
        Size = Vector3.new(0.25, R * 2, R * 2),
    }):Play()

    local fallTime = math.min(0.5, CFG.METEOR_WARN)
    task.wait(CFG.METEOR_WARN - fallTime)

    local startPos = spot + Vector3.new(rng:NextNumber(-20, 20), 80, rng:NextNumber(-20, 20))
    local ms = CFG.METEOR_SIZE
    local rock = fxPart(Vector3.new(ms, ms, ms), CFrame.new(startPos), Color3.fromRGB(255, 110, 30), nil, 0, Enum.PartType.Ball)
    local fire = Instance.new("Fire")
    fire.Size = 10
    fire.Heat = 20
    fire.Parent = rock
    Debris:AddItem(rock, fallTime + 1)
    TweenService:Create(rock, TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        CFrame = CFrame.new(spot),
    }):Play()
    task.wait(fallTime)

    rock:Destroy()
    warnOuter:Destroy()
    warnInner:Destroy()
    playSound(CFG.SOUNDS.meteor)
    shockwaveEffect(spot, R * 1.3, Color3.fromRGB(255, 120, 30))
    sparks(spot + Vector3.new(0, 2, 0), Color3.fromRGB(255, 140, 40), 35)
    cracks(spot, 6)
    showCircle(spot, R, 0.4)
    eachLivePlayer(function(_, hum, r)
        local off = r.Position - spot
        if flat(off).Magnitude <= R and off.Y < 10 then
            damagePlayer(hum, r, damage, flat(off), 0, true, 1.2)
        end
    end)
end

-- METEOR RAIN: red circles under every nearby player - move out before they land!
local function doMeteors()
    busy = true
    local token = actionToken
    T.lastMeteor = os.clock()
    T.lastSpecial = T.lastMeteor
    setState("Meteors")
    playSound(CFG.SOUNDS.roar)

    local glow = makeGlow(Color3.fromRGB(255, 110, 30), 0.5)
    Debris:AddItem(glow, 1)

    local spots = {}
    eachLivePlayer(function(_, _, r)
        if (r.Position - root.Position).Magnitude <= CFG.METEOR_RANGE then
            for i = 1, CFG.METEOR_PER_PLAYER do
                local offset
                if i == 1 then
                    offset = flat(r.AssemblyLinearVelocity) * 0.5 -- the first one lands where you are going
                else
                    offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * CFG.METEOR_SPREAD
                end
                table.insert(spots, groundAt(r.Position + offset))
            end
        end
    end)

    local damage = phaseDamage(CFG.METEOR_DAMAGE)
    for i, spot in ipairs(spots) do
        task.delay((i - 1) * CFG.METEOR_STAGGER, meteorStrike, spot, damage)
    end

    task.wait(0.8)
    if glow.Parent then glow:Destroy() end
    if token == actionToken then busy = false end
end

-- one ring of energy rolling outward - jump over it!
local function ringWave(center, damage)
    local N = 28
    local segs = {}
    for i = 1, N do
        segs[i] = fxPart(Vector3.new(1, CFG.RINGS_HEIGHT, 0.8), CFrame.new(center), CFG.RINGS_COLOR, nil, 0.15)
        Debris:AddItem(segs[i], 8)
    end

    local hit = {}
    local r = 2
    while r < CFG.RINGS_MAX_RADIUS do
        local dt = math.min(RunService.Heartbeat:Wait(), 0.1)
        r += CFG.RINGS_SPEED * dt
        local segLen = 2 * math.pi * r / N * 1.08
        for i, s in ipairs(segs) do
            local a = (i / N) * math.pi * 2
            local p = center + Vector3.new(math.cos(a) * r, CFG.RINGS_HEIGHT / 2, math.sin(a) * r)
            s.Size = Vector3.new(segLen, CFG.RINGS_HEIGHT, 0.8)
            s.CFrame = CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z))
            s.Transparency = 0.15 + 0.7 * (r / CFG.RINGS_MAX_RADIUS)
        end
        eachLivePlayer(function(plr, hum, pr)
            if hit[plr] then return end
            local d = flat(pr.Position - center).Magnitude
            local height = pr.Position.Y - center.Y
            if math.abs(d - r) <= CFG.RINGS_THICKNESS and height < CFG.RINGS_JUMP_CLEARANCE then
                hit[plr] = true
                damagePlayer(hum, pr, damage, flat(pr.Position - center), 0, true, 0.9)
            end
        end)
    end
    for _, s in ipairs(segs) do s:Destroy() end
end

-- SHOCK RINGS: jumps, glows orange, slams and sends out rings you have to jump over
local function doRings()
    busy = true
    local token = actionToken
    T.lastRings = os.clock()
    T.lastSpecial = T.lastRings
    setState("Rings")
    playSound(CFG.SOUNDS.windup)

    local glow = makeGlow(CFG.RINGS_COLOR, 0.35)
    jumpNow(CFG.RINGS_JUMP)
    local ok = windupWait(token, CFG.RINGS_WINDUP, nil, 0)
    glow:Destroy()
    if not ok then return end

    local center = groundPoint()
    cracks(center, 8)
    local damage = phaseDamage(CFG.RINGS_DAMAGE)
    for i = 1, CFG.RINGS_COUNT do
        playSound(CFG.SOUNDS.rings)
        shockwaveEffect(center, 8, CFG.RINGS_COLOR)
        sparks(center + Vector3.new(0, 1, 0), CFG.RINGS_COLOR, 20)
        task.spawn(ringWave, center, damage)
        if i < CFG.RINGS_COUNT then task.wait(CFG.RINGS_GAP) end
    end

    task.wait(0.3)
    if token == actionToken then busy = false end
end

-- DEATH LASER (OP): charges, then sweeps a giant beam across the area. Walls block it.
local function doLaser(targetRoot)
    busy = true
    local token = actionToken
    T.lastLaser = os.clock()
    T.lastSpecial = T.lastLaser
    setState("Laser")
    playSound(CFG.SOUNDS.windup)

    local color = CFG.LASER_COLOR
    local glow = makeGlow(color, 0.3)
    local function eyePos() return (head or root).Position + lookDir() * 1.5 end
    local eye = fxPart(Vector3.new(0.5, 0.5, 0.5), CFrame.new(eyePos()), color, nil, 0, Enum.PartType.Ball)
    Debris:AddItem(eye, CFG.LASER_CHARGE + CFG.LASER_SWEEP_TIME + 2)

    -- charge up
    local start = os.clock()
    while os.clock() - start < CFG.LASER_CHARGE do
        if token ~= actionToken or dead or not targetRoot.Parent then
            eye:Destroy()
            glow:Destroy()
            if token == actionToken then busy = false end
            return
        end
        faceToward(targetRoot.Position)
        local s = 0.5 + 2.5 * ((os.clock() - start) / CFG.LASER_CHARGE)
        eye.Size = Vector3.new(s, s, s)
        eye.CFrame = CFrame.new(eyePos())
        if rng:NextNumber() < 0.15 then sparks(eyePos(), color, 4) end
        task.wait()
    end

    -- aim at the player, then sweep from one side to the other
    local toT = targetRoot.Position - eyePos()
    local baseDir = flatUnit(toT)
    if baseDir.Magnitude == 0 then baseDir = lookDir() end
    local pitch = math.atan2(toT.Y, math.max(flat(toT).Magnitude, 0.1))
    local sweep = math.rad(CFG.LASER_SWEEP)
    local side = rng:NextInteger(0, 1) == 0 and -1 or 1
    local w = CFG.LASER_WIDTH

    local beam = fxPart(Vector3.new(w, w, 1), CFrame.new(eyePos()), color, nil, 0.15)
    local core = fxPart(Vector3.new(w * 0.4, w * 0.4, 1), CFrame.new(eyePos()), Color3.new(1, 1, 1), nil, 0)
    Debris:AddItem(beam, CFG.LASER_SWEEP_TIME + 2)
    Debris:AddItem(core, CFG.LASER_SWEEP_TIME + 2)
    playSound(CFG.SOUNDS.laser)

    -- see-through tube around the beam = the real hit zone (a bit wider than the beam you see)
    local hitW = w + 4
    local area
    if CFG.SHOW_ATTACK_AREAS then
        area = fxPart(Vector3.new(hitW, hitW, 1), CFrame.new(eyePos()), CFG.AREA_COLOR, nil, CFG.AREA_TRANSPARENCY)
        area.Name = "AttackArea"
        Debris:AddItem(area, CFG.LASER_SWEEP_TIME + 2)
    end

    local params = worldParams()
    local lastHit = {}
    local damage = phaseDamage(CFG.LASER_DAMAGE)
    local t0 = os.clock()
    while os.clock() - t0 < CFG.LASER_SWEEP_TIME do
        if token ~= actionToken or dead then break end
        local f = (os.clock() - t0) / CFG.LASER_SWEEP_TIME
        local h = rotateFlat(baseDir, side * (-sweep / 2 + sweep * f))
        local dir = (h * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)).Unit
        faceToward(root.Position + h)

        local origin = (head or root).Position + h * 1.5
        local res = workspace:Raycast(origin, dir * CFG.LASER_RANGE, params)
        local len = res and (res.Position - origin).Magnitude or CFG.LASER_RANGE
        local cf = CFrame.lookAt(origin, origin + dir) * CFrame.new(0, 0, -len / 2)
        beam.Size = Vector3.new(w, w, len)
        beam.CFrame = cf
        core.Size = Vector3.new(w * 0.4, w * 0.4, len)
        core.CFrame = cf
        if area then
            area.Size = Vector3.new(hitW, hitW, len)
            area.CFrame = cf
        end
        eye.CFrame = CFrame.new(origin)
        if res and rng:NextNumber() < 0.3 then sparks(res.Position, color, 6) end

        local now = os.clock()
        eachLivePlayer(function(plr, hum, r)
            if now - (lastHit[plr] or -1e9) < CFG.LASER_TICK then return end
            local rel = r.Position - origin
            local along = math.clamp(rel:Dot(dir), 0, len)
            if (r.Position - (origin + dir * along)).Magnitude <= w / 2 + 2 then
                lastHit[plr] = now
                damagePlayer(hum, r, damage, h, 0, true, 0.7)
                sparks(r.Position, color, 15)
            end
        end)
        task.wait()
    end

    beam:Destroy()
    core:Destroy()
    if area then area:Destroy() end
    eye:Destroy()
    glow:Destroy()
    task.wait(0.4)
    if token == actionToken then busy = false end
end

-- GROUND SLAM
local function doSlam()
    busy = true
    local token = actionToken
    T.lastSlam = os.clock()
    setState("Slam")

    local center = groundPoint()
    local outer = makeDisc(center, CFG.SLAM_RADIUS, Color3.fromRGB(255, 40, 40), 0.8)
    local inner = makeDisc(center, 0.5, Color3.fromRGB(255, 40, 40), 0.45)
    TweenService:Create(inner, TweenInfo.new(CFG.SLAM_WINDUP, Enum.EasingStyle.Linear), {
        Size = Vector3.new(0.25, CFG.SLAM_RADIUS * 2, CFG.SLAM_RADIUS * 2),
    }):Play()
    if slamTrack then slamTrack:Play(0.1) end
    playSound(CFG.SOUNDS.windup)

    local start = os.clock()
    while os.clock() - start < CFG.SLAM_WINDUP do
        if token ~= actionToken then
            outer:Destroy()
            inner:Destroy()
            return
        end
        task.wait()
    end
    outer:Destroy()
    inner:Destroy()
    if token ~= actionToken then return end

    shockwaveEffect(center, CFG.SLAM_RADIUS)
    cracks(center, 8)
    playSound(CFG.SOUNDS.slam)
    shockwaveHit(CFG.SLAM_RADIUS, phaseDamage(CFG.SLAM_DAMAGE), CFG.SLAM_KNOCKBACK, CFG.FLING_ON_SLAM)

    task.wait(CFG.RECOVERY_TIME + 0.3)
    if token == actionToken then busy = false end
end

local function doLunge(targetRoot, speed)
    T.lastLunge = os.clock()
    lungeHitUntil = T.lastLunge + 1.2
    if lungeTrack then lungeTrack:Play(0.1) end
    local aim = targetRoot.Position + flat(targetRoot.AssemblyLinearVelocity) * CFG.LUNGE_DASH_TIME * 0.8 * SK
    local toTarget = aim - root.Position
    if CFG.GHOST_MODE then
        if toTarget.Magnitude > 0.1 then
            doBurst(toTarget, speed * CFG.LUNGE_DASH_MULT, CFG.LUNGE_DASH_TIME, false, CFG.GHOST_LUNGE_HOP)
        end
    else
        local f = flatUnit(toTarget)
        if f.Magnitude > 0 then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            root.AssemblyLinearVelocity = f * CFG.LUNGE_POWER + Vector3.new(0, CFG.LUNGE_POWER * 0.35, 0)
        end
    end
end

local function stagger()
    T.lastStagger = os.clock()
    actionToken += 1
    busy = false
    burst = nil
    ghostTarget = nil
    staggeredUntil = T.lastStagger + CFG.STAGGER_TIME
    if staggerTrack then staggerTrack:Play(0.05) end
end

-- ghost mode: pop up, slam face-first into the ground, tumble, lie there, then get back up
local function ghostTrip(total)
    local fall, rise = 0.25, 0.4
    local maxTilt = -math.rad(90)
    local rollDir = rng:NextInteger(0, 1) == 0 and -1 or 1
    gVel += flat(yawLook) * 10 -- slides forward on its face
    if CFG.GHOST_STAY_GROUNDED and grounded then
        vy = CFG.ANKLE_HOP
        grounded = false
    end
    local t0 = os.clock()
    while not dead do
        local e = os.clock() - t0
        if e >= total then break end
        local frac
        if e < fall then
            frac = e / fall
        elseif e > total - rise then
            frac = 1 - (e - (total - rise)) / rise
        else
            frac = 1
        end
        tilt = maxTilt * frac
        roll = rollDir * 0.6 * frac
        task.wait()
    end
    tilt, roll = 0, 0
end

-- the juke moment: costs the NPC health and makes it BIG (highlight, dust, ground ring - no text)
local function ankleFx(plr, stumble)
    if CFG.ANKLE_DAMAGE > 0 and humanoid.Health > 0 then
        npc:SetAttribute("LastAttacker", plr.UserId) -- credit the juke
        humanoid:TakeDamage(CFG.ANKLE_DAMAGE)
    end
    if not CFG.ANKLE_BIG_FX then return end

    -- yellow glow that shows through walls while it is down
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255, 220, 60)
    hl.FillTransparency = 0.45
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = npc
    Debris:AddItem(hl, stumble)

    -- ground ring + dust cloud when it hits the floor
    task.delay(0.25, function()
        local ground = groundPoint()
        shockwaveEffect(ground, 9)
        local puff = fxPart(Vector3.new(1, 1, 1), CFrame.new(ground + Vector3.new(0, 0.5, 0)), Color3.new(1, 1, 1), nil, 1)
        local e = Instance.new("ParticleEmitter")
        e.Texture = "rbxasset://textures/particles/smoke_main.dds"
        e.Color = ColorSequence.new(Color3.fromRGB(190, 175, 150))
        e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
        e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
        e.Lifetime = NumberRange.new(0.7, 1.2)
        e.Speed = NumberRange.new(12, 24)
        e.SpreadAngle = Vector2.new(180, 180)
        e.Acceleration = Vector3.new(0, 4, 0)
        e.Drag = 3
        e.Rate = 0
        e.Parent = puff
        e:Emit(40)
        Debris:AddItem(puff, 2)
    end)
end

local function ankleBreak(plr)
    local now = os.clock()
    T.lastAnkle = now
    actionToken += 1 -- cancels whatever it was doing
    busy = false
    burst = nil
    ghostTarget = nil
    local stumble = CFG.ANKLE_STUMBLE_TIME
    staggeredUntil = now + stumble
    if CFG.LEARN_ENABLED then
        ankleChanceNow = math.max(CFG.LEARN_MIN_ANKLE_CHANCE, ankleChanceNow * CFG.LEARN_ANKLE_RESIST)
    end
    npc:SetAttribute("AnkleBrokenBy", plr.UserId)
    npc:SetAttribute("AnkleBreaks", (npc:GetAttribute("AnkleBreaks") or 0) + 1)
    playSound(CFG.SOUNDS.ankle)
    if ankleTrack then ankleTrack:Play(0.05) end
    ankleFx(plr, stumble)

    if CFG.GHOST_MODE then
        task.spawn(ghostTrip, stumble)
    else
        humanoid.PlatformStand = true
        pcall(function()
            root:ApplyImpulse(flatUnit(root.CFrame.LookVector) * 25 * root.AssemblyMass + Vector3.new(0, CFG.ANKLE_HOP * root.AssemblyMass, 0))
        end)
        task.delay(stumble, function()
            if not dead then humanoid.PlatformStand = false end
        end)
    end
end

local function dodge()
    local now = os.clock()
    if busy or not currentRoot or now - T.lastDodge < CFG.DODGE_COOLDOWN then return end
    if rng:NextNumber() > CFG.DODGE_CHANCE then return end
    local toTarget = flat(currentRoot.Position - root.Position)
    if toTarget.Magnitude < 0.1 then return end
    T.lastDodge = now
    local side = Vector3.new(-toTarget.Z, 0, toTarget.X).Unit * (rng:NextInteger(0, 1) == 0 and -1 or 1)
    doBurst(side, CFG.DODGE_SPEED, CFG.DODGE_TIME, true)
end

local function onPhaseChange(newIndex)
    phaseIndex = newIndex
    updateBar()
    npc:SetAttribute("Phase", newIndex)

    actionToken += 1
    busy = true
    burst = nil
    guardUntil = 0
    local token = actionToken
    stopMoving()
    setState("Roar")
    playSound(CFG.SOUNDS.roar)
    local center = groundPoint()
    shockwaveEffect(center, CFG.ROAR_RADIUS)
    sparks(root.Position, PHASES[newIndex].barColor, 50)
    shockwaveHit(CFG.ROAR_RADIUS, 0, CFG.ROAR_KNOCKBACK)
    task.delay(CFG.ROAR_TIME, function()
        if token == actionToken then busy = false end
    end)
end

---------------- BLEED + HEADSHOTS + HIT REACTIONS ----------------
local function makeBloodEmitter(parent)
    local e = Instance.new("ParticleEmitter")
    e.Name = "BloodEmitter"
    e.Texture = "rbxasset://textures/particles/smoke_main.dds"
    e.Color = ColorSequence.new(CFG.BLEED_COLOR)
    e.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(1, 0.1),
    })
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.7, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.Lifetime = NumberRange.new(0.4, 0.8)
    e.Speed = NumberRange.new(5, 10)
    e.SpreadAngle = Vector2.new(60, 60)
    e.Acceleration = Vector3.new(0, -35, 0)
    e.Drag = 1
    e.Rate = 0
    e.Parent = parent
    return e
end

local headEmitter = head and makeBloodEmitter(head) or nil
local bodyEmitter = makeBloodEmitter(torso)
local dripUntil = {}

local function bleed(fromHead)
    if not CFG.BLEED_ENABLED then return end
    local emitter = (fromHead and headEmitter) or bodyEmitter
    emitter:Emit(CFG.BLEED_PARTICLES)
    if CFG.BLEED_DRIP_TIME > 0 then
        emitter.Rate = 12
        dripUntil[emitter] = os.clock() + CFG.BLEED_DRIP_TIME
        task.delay(CFG.BLEED_DRIP_TIME, function()
            if os.clock() >= (dripUntil[emitter] or 0) - 0.01 then emitter.Rate = 0 end
        end)
    end
end

local lastHeadTouch = 0
if head then
    head.Touched:Connect(function(hit)
        if hit.Anchored or hit:IsDescendantOf(npc) then return end
        local npcFolder = workspace:FindFirstChild("NPCs")
        if npcFolder and hit:IsDescendantOf(npcFolder) then return end
        local model = hit:FindFirstAncestorOfClass("Model")
        local inTool = hit:FindFirstAncestorOfClass("Tool") ~= nil
        if not inTool and model and Players:GetPlayerFromCharacter(model) then return end
        lastHeadTouch = os.clock()
    end)
end

local function attributeHit(amount)
    local plr
    local tag = humanoid:FindFirstChild("creator")
    if tag and tag:IsA("ObjectValue") and typeof(tag.Value) == "Instance" and tag.Value:IsA("Player") then
        plr = tag.Value
    end
    if not plr then
        local uid = npc:GetAttribute("LastAttacker")
        if uid then plr = Players:GetPlayerByUserId(uid) end
    end
    if plr then
        threat[plr] = (threat[plr] or 0) + amount * CFG.THREAT_PER_DAMAGE
        damageBy[plr] = (damageBy[plr] or 0) + amount
    end
end

local lastHealth = humanoid.Health
local selfDamageHealth = nil
humanoid.HealthChanged:Connect(function(newHealth)
    updateBar()
    local damageTaken = lastHealth - newHealth
    lastHealth = newHealth

    if selfDamageHealth and math.abs(newHealth - selfDamageHealth) < 0.001 then
        selfDamageHealth = nil
        return
    end
    if damageTaken <= 0 then return end

    local now = os.clock()
    lastDamagedAt = now

    -- GUARD: the shield gives back most of the damage
    if now < guardUntil and newHealth > 0 then
        attributeHit(damageTaken)
        sparks(root.Position + Vector3.new(0, 1, 0), CFG.GUARD_COLOR, 10)
        humanoid.Health = math.min(humanoid.MaxHealth, newHealth + damageTaken * CFG.GUARD_BLOCK)
        return
    end

    local tagged = npc:GetAttribute("LastHit")
    local isHeadshot = CFG.HEADSHOT_ENABLED and (now - lastHeadTouch <= CFG.HEADSHOT_WINDOW or tagged == "Head")
    lastHeadTouch = 0
    npc:SetAttribute("LastHit", nil)

    bleed(isHeadshot)

    local total = damageTaken
    if isHeadshot and newHealth > 0 then
        local extra = damageTaken * (CFG.HEADSHOT_MULT - 1)
        selfDamageHealth = math.max(newHealth - extra, 0)
        humanoid:TakeDamage(extra)
        total += extra
    end
    attributeHit(total)

    if humanoid.Health > 0 and now >= staggeredUntil then
        local bigHit = total >= humanoid.MaxHealth * CFG.STAGGER_DAMAGE_PCT
        local staggerHit = bigHit or (CFG.STAGGER_HEADSHOT and isHeadshot)
        if CFG.GUARD_ENABLED and not busy and now - T.lastGuard >= CFG.GUARD_COOLDOWN and rng:NextNumber() < CFG.GUARD_CHANCE then
            task.spawn(doGuard)
        elseif CFG.STAGGER_ENABLED and staggerHit and now - T.lastStagger >= CFG.STAGGER_COOLDOWN then
            stagger()
        elseif CFG.DODGE_ENABLED then
            dodge()
        end
    end
end)
updateBar()

---------------- TARGETING ----------------
local function pickTarget(now)
    local cands = {}
    local bestPlr, bestScore
    eachLivePlayer(function(plr, hum, r)
        local dist = (r.Position - root.Position).Magnitude
        if dist > CFG.AGGRO_RANGE then return end
        local seen = (not CFG.REQUIRE_LINE_OF_SIGHT) or canSee(r)
        if seen then lastSeen[plr] = now end
        if not seen and now - (lastSeen[plr] or -1e9) > CFG.LOSE_AGGRO_TIME then return end

        cands[plr] = { root = r, hum = hum, dist = dist }
        local score = -dist
            + (threat[plr] or 0) * CFG.THREAT_WEIGHT
            + (1 - hum.Health / math.max(hum.MaxHealth, 1)) * CFG.LOW_HEALTH_PREFERENCE
        if plr == currentPlayer then score += CFG.STICKY_BONUS end
        if not bestScore or score > bestScore then
            bestPlr, bestScore = plr, score
        end
    end)

    if currentPlayer and cands[currentPlayer] and bestPlr ~= currentPlayer and now - lastSwitch < CFG.SWITCH_COOLDOWN then
        bestPlr = currentPlayer
    end
    if bestPlr ~= currentPlayer then
        lastSwitch = now
        currentPlayer = bestPlr
    end

    if bestPlr then
        local c = cands[bestPlr]
        lastKnownPos, lostSince = c.root.Position, nil
        return bestPlr, c.root, c.hum, c.dist, cands
    end
    if lastKnownPos and not lostSince then lostSince = now end
    return nil, nil, nil, math.huge, cands
end

local function countWithin(cands, radius)
    local n = 0
    for _, c in pairs(cands) do
        if c.dist <= radius then n += 1 end
    end
    return n
end

---------------- GHOST MODE (momentum-based, stays on the ground) ----------------
local npcParts = {}
for _, obj in ipairs(npc:GetDescendants()) do
    if obj:IsA("BasePart") then table.insert(npcParts, obj) end
end
npc.DescendantAdded:Connect(function(obj)
    if obj:IsA("BasePart") then table.insert(npcParts, obj) end
end)

local ghostConnection
if CFG.GHOST_MODE then
    root.Anchored = true
    ghostConnection = RunService.Heartbeat:Connect(function(dt)
        if dead then return end
        dt = math.min(dt, 0.1)
        for _, part in ipairs(npcParts) do
            if part.CanCollide then part.CanCollide = false end
        end

        local now = os.clock()
        local pos = root.Position
        local groundedMode = CFG.GHOST_STAY_GROUNDED
        local free = (not busy) and now >= staggeredUntil

        -- velocity: committed burst, or smoothly steer toward where it wants to go
        local bursting = burst ~= nil and now < burst.untilT
        if burst and not bursting then burst = nil end
        if bursting then
            gVel = burst.dir * burst.speed
        else
            local desired = Vector3.zero
            if ghostTarget and free then
                local to = ghostTarget - pos
                if groundedMode then to = flat(to) end
                local d = to.Magnitude
                if d > 0.05 then
                    local sp = ghostSpeed
                    if d < CFG.GHOST_SLOW_RADIUS then
                        sp *= math.clamp(d / CFG.GHOST_SLOW_RADIUS, 0.5, 1)
                    end
                    desired = to.Unit * sp
                end
            end
            local sharp = desired.Magnitude > 0.01 and CFG.GHOST_ACCEL * (1 + 0.8 * SK * jukeHeat) or CFG.GHOST_BRAKE
            gVel = gVel:Lerp(desired, 1 - math.exp(-sharp * dt))
        end
        if groundedMode then gVel = Vector3.new(gVel.X, 0, gVel.Z) end

        -- position
        local newPos = pos + gVel * dt
        if groundedMode then
            local climbing = ghostTarget ~= nil and free and not bursting
                and (ghostTarget.Y - pos.Y) > CFG.GHOST_CLIMB_HEIGHT
            if climbing then
                vy, grounded = 0, false
                newPos = Vector3.new(newPos.X, pos.Y + math.min(CFG.GHOST_CLIMB_SPEED * dt, ghostTarget.Y - pos.Y), newPos.Z)
            else
                local gY = groundRootY(newPos.X, newPos.Z, pos.Y + CFG.GHOST_STEP_UP)
                vy -= 196.2 * dt
                local ny = pos.Y + vy * dt
                if gY then
                    if ny <= gY then
                        ny, vy, grounded = gY, 0, true
                    else
                        grounded = false
                    end
                else
                    ny, vy, grounded = pos.Y, 0, false -- no ground below: hover
                end
                newPos = Vector3.new(newPos.X, ny, newPos.Z)
            end
        end

        -- facing (smooth turn): where it's moving, or toward the player when standing
        if free and not (bursting and burst.keepFacing) then
            local moveFlat = flat(gVel)
            local want
            if facePlayer and lookAtPos then
                want = flatUnit(lookAtPos - pos)
            elseif moveFlat.Magnitude > 2 then
                want = moveFlat.Unit
            elseif lookAtPos then
                want = flatUnit(lookAtPos - pos)
            end
            if want and want.Magnitude > 0 then
                local nl = yawLook:Lerp(want, 1 - math.exp(-CFG.GHOST_TURN * dt))
                if nl.Magnitude > 0.01 then yawLook = nl.Unit end
            end
        end

        -- apply (tilt is used by the ankle-break fall)
        local drop = math.abs(tilt) / math.rad(80) * 1.2
        local p = newPos - Vector3.new(0, drop, 0)
        root.CFrame = CFrame.lookAt(p, p + yawLook) * CFrame.Angles(tilt, 0, roll)
    end)
end

---------------- SKILL: READS YOUR ATTACKS ----------------
-- when a nearby player swings / fires a Tool it may sidestep (it still does not dodge everything)
local watched = setmetatable({}, { __mode = "k" })

local function onPlayerAttack(plr)
    if not CFG.READ_ATTACKS or dead or busy then return end
    local now = os.clock()
    local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not r or (r.Position - root.Position).Magnitude > CFG.READ_ATTACK_RANGE then return end
    if now - lastRead < CFG.READ_ATTACK_COOLDOWN or now < staggeredUntil then return end
    if rng:NextNumber() > CFG.READ_ATTACK_CHANCE * SK then return end
    lastRead = now
    task.delay(rng:NextNumber(0.05, 0.15), function()
        if dead or busy or os.clock() < staggeredUntil then return end
        local toShooter = flat(r.Position - root.Position)
        if toShooter.Magnitude < 0.1 then return end
        local side = Vector3.new(-toShooter.Z, 0, toShooter.X).Unit * (rng:NextInteger(0, 1) == 0 and -1 or 1)
        doBurst(side, CFG.DODGE_SPEED, CFG.DODGE_TIME, true)
    end)
end

local function watchTool(plr, tool)
    if watched[tool] then return end
    watched[tool] = tool.Activated:Connect(function() onPlayerAttack(plr) end)
end

local function watchCharacter(plr, char)
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") then watchTool(plr, c) end
    end
    char.ChildAdded:Connect(function(c)
        if c:IsA("Tool") then watchTool(plr, c) end
    end)
end

local function watchPlayer(plr)
    if plr.Character then watchCharacter(plr, plr.Character) end
    plr.CharacterAdded:Connect(function(char) watchCharacter(plr, char) end)
end
for _, plr in ipairs(Players:GetPlayers()) do watchPlayer(plr) end
Players.PlayerAdded:Connect(watchPlayer)

---------------- CONTACT DAMAGE ----------------
-- anyone whose body overlaps the NPC's body takes damage (checked continuously, so standing inside it still hurts)
local contactLast = setmetatable({}, { __mode = "k" })
task.spawn(function()
    while not dead and npc.Parent do
        if CFG.CONTACT_ENABLED and os.clock() >= staggeredUntil then
            local cf, size = npc:GetBoundingBox()
            local pad = CFG.CONTACT_PADDING * 2
            showBox(cf, size + Vector3.new(pad, pad, pad), 0.09, CFG.CONTACT_AREA_COLOR) -- yellow "touching hurts" box
            local now = os.clock()
            local seen = {}
            for _, part in ipairs(workspace:GetPartBoundsInBox(cf, size + Vector3.new(pad, pad, pad), overlap)) do
                local model = part:FindFirstAncestorOfClass("Model")
                local plr = model and Players:GetPlayerFromCharacter(model)
                if plr and not seen[plr] then
                    seen[plr] = true
                    if now - (contactLast[plr] or -1e9) >= CFG.CONTACT_COOLDOWN then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            contactLast[plr] = now
                            local pr = model:FindFirstChild("HumanoidRootPart")
                            if pr then
                                faceToward(pr.Position)
                                if attackTrack then attackTrack:Play(0.05) end -- instant attack the moment you touch it
                                playSound(CFG.SOUNDS.hit)
                                damagePlayer(hum, pr, phaseDamage(CFG.CONTACT_DAMAGE), flat(pr.Position - root.Position), 0, CFG.FLING_ON_CONTACT)
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.08)
    end
end)

---------------- DEATH / REWARDS ----------------
local rewardGiven = false
humanoid.Died:Connect(function()
    dead = true
    guardUntil = 0
    tilt, roll = 0, 0
    actionToken += 1
    if ghostConnection then ghostConnection:Disconnect() end
    pcall(function() root.Anchored = false end)
    for _, part in ipairs(npcParts) do
        if part.Name ~= "HumanoidRootPart" and part.Parent == npc and part.Name ~= "Handle" then
            part.CanCollide = true
        end
    end
    sparks(root.Position, Color3.fromRGB(255, 220, 80), 80)
    shockwaveEffect(groundPoint(), 25, Color3.fromRGB(255, 220, 80))

    if not rewardGiven then
        rewardGiven = true

        -- BOUNTY for every player in the server
        if CFG.BOUNTY_REWARD_PER_PLAYER > 0 then
            if _G.AddBounty then
                for _, plr in ipairs(Players:GetPlayers()) do
                    _G.AddBounty(plr, CFG.BOUNTY_REWARD_PER_PLAYER)
                end
            else
                warn("[NPCFollow] _G.AddBounty not found - is BountyStat in ServerScriptService?")
            end
        end

        if _G.AddDollars then
            for _, plr in ipairs(Players:GetPlayers()) do
                _G.AddDollars(plr, CFG.DOLLAR_REWARD_PER_PLAYER)
            end
            local topPlr, topDmg
            for plr, dmg in pairs(damageBy) do
                if plr.Parent and (not topDmg or dmg > topDmg) then topPlr, topDmg = plr, dmg end
            end
            if topPlr and CFG.TOP_DAMAGE_BONUS > 0 then
                _G.AddDollars(topPlr, CFG.TOP_DAMAGE_BONUS)
            end
        end
    end

    -- keep the body long enough that ragdolled players always get back up
    if CFG.CORPSE_TIME > 0 then
        Debris:AddItem(npc, math.max(CFG.CORPSE_TIME, CFG.RAGDOLL_TIME * 1.3 + 1))
    end
end)

---------------- MAIN BRAIN ----------------
local patrolPoint, patrolPauseUntil = nil, 0
local function patrol(now)
    setState("Patrol")
    local pSpeed = baseSpeed * CFG.PATROL_SPEED_MULT
    humanoid.WalkSpeed = pSpeed
    lookAtPos = nil
    if not CFG.PATROL_ENABLED or now < patrolPauseUntil then
        stopMoving()
        setRunning(false, 0)
        return
    end
    if not patrolPoint then
        local a = rng:NextNumber(0, math.pi * 2)
        local r = rng:NextNumber(CFG.PATROL_RADIUS * 0.3, CFG.PATROL_RADIUS)
        patrolPoint = spawnPos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
    end
    if flat(patrolPoint - root.Position).Magnitude < 3 then
        patrolPoint = nil
        patrolPauseUntil = now + rng:NextNumber(2, 5)
        return
    end
    moveTo(patrolPoint, pSpeed)
    setRunning(true, pSpeed)
end

local function getPlayerSpeed(targetHumanoid, targetRoot)
    return math.max(targetHumanoid.WalkSpeed, flat(targetRoot.AssemblyLinearVelocity).Magnitude)
end

-- did the player turn hard within the recent window?
local hist, histPlayer = {}, nil
local function playerCutHard(now, v, angleDeg)
    if v.Magnitude < CFG.ANKLE_MIN_SPEED then return false end
    local cosLimit = math.cos(math.rad(angleDeg))
    for i = 1, #hist do
        local s = hist[i]
        if now - s.t <= CFG.ANKLE_WINDOW and s.v.Magnitude >= CFG.ANKLE_MIN_SPEED then
            if s.v.Unit:Dot(v.Unit) <= cosLimit then return true end
        end
    end
    return false
end

-- where the player will be when an NPC moving at `mySpeed` can reach them
local function interceptPoint(npcPos, targetPos, targetVel, mySpeed)
    local rel = flat(targetPos - npcPos)
    local a = targetVel:Dot(targetVel) - mySpeed * mySpeed
    local b = 2 * rel:Dot(targetVel)
    local c = rel:Dot(rel)
    local t
    if math.abs(a) < 1e-4 then
        if math.abs(b) > 1e-4 then t = -c / b end
    else
        local disc = b * b - 4 * a * c
        if disc >= 0 then
            local sq = math.sqrt(disc)
            for _, x in ipairs({ (-b - sq) / (2 * a), (-b + sq) / (2 * a) }) do
                if x > 0 and (not t or x < t) then t = x end
            end
        end
    end
    t = math.clamp(t or 0, 0, 1.5)
    return targetPos + targetVel * t
end

local chaseTime = 0
local flankSide, flankSwitchAt = 1, 0
local stuckTime, jumpTimer, stuckCheckT, stuckCheckPos = 0, 0, os.clock(), root.Position
local lastTick = os.clock()

-- one "think" of the brain (in its own function so its variables don't count toward the 200 limit)
local function brainTick()
    local now = os.clock()
    local dt = math.min(now - lastTick, 0.5)
    lastTick = now

    for plr, v in pairs(threat) do
        threat[plr] = v * math.max(0, 1 - CFG.THREAT_DECAY * dt)
    end

    local plr, tRoot, tHum, dist, cands = pickTarget(now)
    currentRoot = tRoot

    -- phase check (only ever goes up)
    local hpPct = humanoid.Health / humanoid.MaxHealth
    local newPhase = phaseIndex
    for i, p in ipairs(PHASES) do
        if hpPct <= p.threshold and i > newPhase then newPhase = i end
    end
    if newPhase > phaseIndex then onPhaseChange(newPhase) end
    local phase = PHASES[phaseIndex]

    -- out-of-combat regen
    if CFG.REGEN_PCT_PER_SEC > 0 and now - lastDamagedAt > CFG.REGEN_DELAY and humanoid.Health < humanoid.MaxHealth then
        humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * CFG.REGEN_PCT_PER_SEC * dt)
    end

    -- track the target's movement history (reaction delay, juke reading, ankle breaks)
    jukeHeat = math.max(0, jukeHeat - dt / CFG.JUKE_MEMORY)
    local reactPos, tVel
    if tRoot then
        if histPlayer ~= plr then hist, histPlayer = {}, plr end
        tVel = flat(tRoot.AssemblyLinearVelocity)
        table.insert(hist, { t = now, v = tVel, p = tRoot.Position })
        while #hist > 1 and now - hist[1].t > 1 do table.remove(hist, 1) end

        -- learns your juking: every hard cut makes it harder to fool
        if CFG.LEARN_ENABLED and now - lastJukeT > 0.5 and playerCutHard(now, tVel, 75) then
            lastJukeT = now
            jukeHeat = math.min(1, jukeHeat + 0.3)
        end

        -- skilled = faster reactions, and it focuses harder against jukers
        local reactionNow = CFG.REACTION_TIME * (1 - 0.7 * SK) * (1 - 0.4 * jukeHeat)
        reactPos = tRoot.Position
        for i = #hist, 1, -1 do
            if now - hist[i].t >= reactionNow then
                reactPos = hist[i].p
                break
            end
        end
        lookAtPos = tRoot.Position
    else
        histPlayer = nil
    end

    -- speed: the player's speed x this NPC's spawn roll, with natural pace drift
    local rageBonus = 0
    if CFG.RAGE_ENABLED and tRoot and dist > CFG.RAGE_RESET_DIST then
        chaseTime += dt
        rageBonus = math.min(chaseTime * CFG.RAGE_PER_SECOND, CFG.RAGE_MAX_BONUS)
    else
        chaseTime = 0
    end
    local speed = baseSpeed
    local normalSpeed = baseSpeed -- speed when not sprinting (lunges and strafing use this)
    local sprinting = false
    if tRoot then
        local ref = CFG.MATCH_PLAYER_SPEED and getPlayerSpeed(tHum, tRoot) or baseSpeed
        normalSpeed = (ref * speedFactor + CFG.SPEED_BONUS + rageBonus) * phase.speedMult
        normalSpeed *= 1 + math.noise(now * 0.35, noiseSeed, 5.5) * 2 * CFG.PACE_VARIATION
        normalSpeed = math.min(normalSpeed, CFG.MAX_SPEED)
        speed = normalSpeed

        if CFG.SPRINT_ENABLED then
            if now >= sprintUntil and now >= sprintReadyAt and dist >= CFG.SPRINT_MIN_DISTANCE
                and not busy and now >= staggeredUntil then
                sprintUntil = now + CFG.SPRINT_DURATION
                sprintReadyAt = sprintUntil + CFG.SPRINT_COOLDOWN
                playSound(CFG.SOUNDS.sprint)
            end
            sprinting = now < sprintUntil
            if sprinting then
                speed = math.min(ref * CFG.SPRINT_MULT, CFG.MAX_SPEED)
            end
        end
    end
    if npc:GetAttribute("Sprinting") ~= sprinting then npc:SetAttribute("Sprinting", sprinting) end

    -- ANKLE BREAK check (not while its shield is up)
    if tRoot and CFG.ANKLE_ENABLED and now >= staggeredUntil and now >= guardUntil
        and now - T.lastAnkle >= CFG.ANKLE_COOLDOWN
        and dist >= CFG.ANKLE_MIN_DIST and dist <= CFG.ANKLE_RANGE then
        local npcSpeed = CFG.GHOST_MODE and gVel.Magnitude or flat(root.AssemblyLinearVelocity).Magnitude
        if npcSpeed >= CFG.ANKLE_MIN_NPC_SPEED and playerCutHard(now, tVel, CFG.ANKLE_MIN_ANGLE) and rng:NextNumber() <= ankleChanceNow then
            ankleBreak(plr)
        end
    end

    -- copy the player's jumps (after a short human delay)
    if tRoot and CFG.MIMIC_JUMPS and dist <= CFG.MIMIC_JUMP_RANGE and now - T.lastMimic >= CFG.MIMIC_JUMP_COOLDOWN then
        if tHum.FloorMaterial == Enum.Material.Air and tRoot.AssemblyLinearVelocity.Y > 15 then
            T.lastMimic = now
            if rng:NextNumber() <= CFG.MIMIC_JUMP_CHANCE then
                task.delay(rng:NextNumber(0.08, 0.3) * (1 - 0.6 * SK), function()
                    if not dead and not busy and os.clock() >= staggeredUntil then jumpNow() end
                end)
            end
        end
    end

    facePlayer = false
    if not CFG.GHOST_MODE then humanoid.AutoRotate = true end

    if now < staggeredUntil then
        setState("Stagger")
        stopMoving()
        setRunning(false, 0)

    elseif busy then
        stopMoving()
        setRunning(false, 0)

    elseif tRoot then
        setState("Chase")
        humanoid.WalkSpeed = speed

        -- which attacks are ready?
        local cd = phase.cooldownMult
        local sees = canSee(tRoot)
        local sightOK = sees or not CFG.RANGED_NEEDS_SIGHT
        local specialOK = now - T.lastSpecial >= CFG.SPECIAL_GAP

        local laserReady = CFG.LASER_ENABLED and specialOK and sees and phaseIndex >= CFG.LASER_MIN_PHASE
            and dist <= CFG.LASER_RANGE and now - T.lastLaser >= CFG.LASER_COOLDOWN * cd
        local meteorReady = CFG.METEOR_ENABLED and specialOK and dist <= CFG.METEOR_RANGE
            and now - T.lastMeteor >= CFG.METEOR_COOLDOWN * cd
        local ringsReady = CFG.RINGS_ENABLED and specialOK and dist <= CFG.RINGS_MAX_RADIUS * 0.8
            and now - T.lastRings >= CFG.RINGS_COOLDOWN * cd
        local barrageReady = CFG.BARRAGE_ENABLED and specialOK and sightOK
            and dist >= CFG.RANGED_MIN_RANGE and dist <= CFG.RANGED_MAX_RANGE
            and now - T.lastBarrage >= CFG.BARRAGE_COOLDOWN * cd
        local heavyReady = CFG.HEAVY_ENABLED and dist <= CFG.HEAVY_RANGE
            and now - T.lastHeavy >= CFG.HEAVY_COOLDOWN * cd
        local flurryReady = CFG.FLURRY_ENABLED and dist <= CFG.FLURRY_RANGE
            and now - T.lastFlurry >= CFG.FLURRY_COOLDOWN * cd
        local slamReady = CFG.SLAM_ENABLED and now - T.lastSlam >= CFG.SLAM_COOLDOWN * cd
        if slamReady then
            local near = countWithin(cands, CFG.SLAM_TRIGGER_RANGE)
            slamReady = near >= 1 and (phaseIndex >= CFG.SLAM_MIN_PHASE or near >= 2)
        end
        local attackReady = now - T.lastAttack >= CFG.ATTACK_COOLDOWN * cd
        local rangedReady = CFG.RANGED_ENABLED and sightOK and dist >= CFG.RANGED_MIN_RANGE and dist <= CFG.RANGED_MAX_RANGE
            and now - T.lastRanged >= CFG.RANGED_COOLDOWN * cd
            and now >= sprintUntil -- doesn't stop to throw in the middle of a sprint
        local lungeReady = CFG.LUNGE_ENABLED and dist > CFG.ATTACK_RANGE and dist <= CFG.LUNGE_RANGE
            and now - T.lastLunge >= CFG.LUNGE_COOLDOWN

        -- pick one: OP specials first, then close-range, then long-range
        if laserReady then
            task.spawn(doLaser, tRoot)
        elseif meteorReady then
            task.spawn(doMeteors)
        elseif ringsReady then
            task.spawn(doRings)
        elseif heavyReady then
            task.spawn(doHeavy, tRoot)
        elseif flurryReady then
            task.spawn(doFlurry, tRoot)
        elseif slamReady then
            task.spawn(doSlam)
        elseif dist <= CFG.ATTACK_RANGE and attackReady then
            task.spawn(doMelee, tRoot)
        elseif barrageReady then
            task.spawn(doBarrage, tRoot)
        elseif rangedReady then
            task.spawn(doRanged, tRoot)
        elseif lungeReady and (CFG.GHOST_MODE or humanoid.FloorMaterial ~= Enum.Material.Air) then
            doLunge(tRoot, normalSpeed)
        end

        if busy then
            stopMoving()
            setRunning(false, 0)
        elseif CFG.ORBIT_ENABLED and SK > 0.3 and dist <= CFG.STOP_DISTANCE + 2.5 then
            -- inside the fighting circle: circle-strafe the player while its attack recharges
            if now >= orbitSwitchAt then
                orbitSide = -orbitSide
                orbitSwitchAt = now + rng:NextNumber(1.2, 2.8)
            end
            local rel = flat(root.Position - tRoot.Position)
            local cur = rel.Magnitude > 0.1 and rel.Unit or Vector3.new(0, 0, 1)
            local rot = rotateFlat(cur, math.rad(40) * orbitSide)
            local oSpeed = normalSpeed * CFG.ORBIT_SPEED_MULT
            moveTo(tRoot.Position + rot * (CFG.STOP_DISTANCE + 1), oSpeed)
            setRunning(true, oSpeed)
            facePlayer = true
            if not CFG.GHOST_MODE then
                humanoid.AutoRotate = false
                faceToward(tRoot.Position)
            end
        elseif dist > CFG.STOP_DISTANCE then
            -- aim where the player WAS (reaction time) plus a small lead, like a person would
            local goal = reactPos
            if CFG.PREDICT_MOVEMENT and dist > 10 then
                goal += tVel * CFG.PREDICT_TIME
            end
            -- skilled: cut the player off. Jukers make it trust the prediction less.
            if CFG.INTERCEPT_ENABLED and dist > 8 then
                local cut = interceptPoint(root.Position, tRoot.Position, tVel, speed)
                goal = goal:Lerp(cut, SK * (1 - 0.6 * jukeHeat))
            end

            -- circles in from the side
            if CFG.FLANK_ENABLED and (phaseIndex >= 2 or SK >= 0.5) and dist > CFG.ATTACK_RANGE + 3 and dist < CFG.FLANK_RANGE then
                if now >= flankSwitchAt then
                    flankSide = -flankSide
                    flankSwitchAt = now + rng:NextNumber(2, 4)
                end
                local d = flatUnit(goal - root.Position)
                goal += Vector3.new(-d.Z, 0, d.X) * flankSide * CFG.FLANK_OFFSET * (dist / CFG.FLANK_RANGE)
            end

            -- slight human drift side to side when far away
            if CFG.WOBBLE > 0 then
                local d = flatUnit(goal - root.Position)
                if d.Magnitude > 0 then
                    local amt = math.noise(now * 0.6, noiseSeed, 1.5) * 2 * CFG.WOBBLE
                    goal += Vector3.new(-d.Z, 0, d.X) * amt * math.clamp(dist / 25, 0, 1)
                end
            end

            moveTo(goal, speed)
            setRunning(true, speed)

            if not CFG.GHOST_MODE then
                hopObstacle(goal)
                -- unstick: jump, then teleport behind the player
                if now - stuckCheckT >= 0.5 then
                    local moved = flat(root.Position - stuckCheckPos).Magnitude
                    stuckCheckT, stuckCheckPos = now, root.Position
                    if moved < 0.6 and dist > 4 then
                        stuckTime += 0.5
                        jumpTimer += 0.5
                        if CFG.JUMP_WHEN_STUCK and jumpTimer >= 1 then
                            humanoid.Jump = true
                            jumpTimer = 0
                        end
                        if stuckTime >= 8 then
                            teleportBehind(tRoot)
                            stuckTime, jumpTimer = 0, 0
                        end
                    else
                        stuckTime, jumpTimer = 0, 0
                    end
                end
            end
        else
            -- caught up: stand near the player and face them
            stopMoving()
            faceToward(tRoot.Position)
            setRunning(false, 0)
        end

    elseif lastKnownPos and lostSince and now - lostSince < CFG.SEARCH_TIME then
        setState("Search")
        humanoid.WalkSpeed = baseSpeed
        lookAtPos = nil
        if flat(lastKnownPos - root.Position).Magnitude > 4 then
            moveTo(lastKnownPos, baseSpeed)
            setRunning(true, baseSpeed)
        else
            stopMoving()
            setRunning(false, 0)
        end

    else
        lastKnownPos, lostSince = nil, nil
        patrol(now)
    end
end

while npc.Parent and humanoid.Health > 0 do
    local ok, err = pcall(brainTick)
    if not ok then warn("[NPCFollow] brain error: " .. tostring(err)) end
    task.wait(CFG.TICK)
end

-- NPC died or was removed
dead = true
if ghostConnection then ghostConnection:Disconnect() end
pcall(function() root.Anchored = false end)

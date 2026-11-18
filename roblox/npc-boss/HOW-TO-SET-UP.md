# NPC Ultra Boss: setup steps

A 2000 HP boss with 10 attacks. It's slower than you but hits hard, and big hits ragdoll you. When it dies, every player gets 500 Bounty.

## The files

| # | File | Script type | Where in Explorer | Which place |
|---|---|---|---|---|
| 1 | `1-NPCFollow.server.lua` | Script | INSIDE the boss NPC model in ServerStorage (replace its old NPCFollow) | **Game** |

## Steps (Game place)

1. Back up first: File → Save to File.
2. ServerStorage → open the boss NPC model → delete its old `NPCFollow` → **+** → **Script** → name it `NPCFollow` → paste file **1**.
3. Only put it in the NPC you want as a boss. Every kill gives 500 Bounty to everyone.
4. **BountyStat** must be in ServerScriptService.

## The attacks and how to survive them

| Attack | Warning | How to dodge |
|---|---|---|
| Melee combo | Swings | Back off; the 3rd hit launches you |
| Flurry (fast, low damage) | Yellow slashes | Run away from it |
| Heavy Smash | Jumps and glows **red** | Get away before it lands |
| Energy Ball | Purple ball grows | Run sideways |
| Barrage | 5 blue balls over its head | Run sideways or hide behind a wall |
| Guard (defence) | Blue bubble | Stop attacking and step back (it explodes) |
| Meteor Rain | **Red circles** on the ground | Get out of the circles |
| Shock Rings | Jumps and glows **orange** | **Jump** over each ring |
| Death Laser (below 60% health) | Glows pink, pink orb on its face | Hide behind a wall or get out of the sweep |
| Ground Slam | Red circle around it | Jump, or get out of the circle |

## Settings to try (CONFIG at the top)

- Every attack has `..._ENABLED`, `..._DAMAGE` and `..._COOLDOWN`. Set `_ENABLED = false` to turn one off.
- `SHOW_ATTACK_AREAS = true`: shows see-through red shapes where each attack hits, and a yellow box where touching the boss hurts. **Set it to `false` before publishing.**
- `SPECIAL_GAP`: how long it waits between big special attacks.
- `LASER_MIN_PHASE`: 1 = laser from the start, 2 = below 60% health, 3 = below 30%.
- `MAX_HEALTH`, `BOUNTY_REWARD_PER_PLAYER`, `RAGDOLL_TIME`.

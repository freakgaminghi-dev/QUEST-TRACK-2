# Weapon Shop: setup steps

Press your own ImageButton in the **Lobby** to buy a weapon with Bounty → get it in your backpack **every time** you spawn in the **Game** place.

## The files

| # | File | Script type | Where in Explorer | Which place |
|---|---|---|---|---|
| 1 | `1-WeaponShop.server.lua` | Script | ServerScriptService | **Both** |
| 2 | `2-WeaponButton.client.lua` | LocalScript | INSIDE your ImageButton (StarterGui > ScreenGui > ImageButton) | **Lobby** |

## Lobby place

1. ServerScriptService → **+** → **Script** → rename it `WeaponShop` → paste file **1**.
2. StarterGui → **+** → **ScreenGui** (or use one you already have).
3. Inside the ScreenGui → **+** → **ImageButton**. Set its **Image** to your picture, then move and resize it however you like.
4. Inside the ImageButton → **+** → **LocalScript** → rename it `WeaponButton` → paste file **2**.

## Game place

1. ServerScriptService → **+** → **Script** → rename it `WeaponShop` → paste file **1** (the same one).
2. ServerStorage → **+** → **Folder** → rename it `WEAPONS`.
3. Put your **Tool** inside `WEAPONS`, named exactly `Sword`. It needs a part named `Handle`.

## Both places

- **BountyStat** must be in ServerScriptService. It's the script that takes the Bounty away.

## Add another weapon

1. In **WeaponShop** (in both places), add a line to the list: `["Bat"] = 5,`
2. Put a Tool named `Bat` in `ServerStorage > WEAPONS` in the Game place.
3. In the Lobby, copy your ImageButton (Ctrl+D), change its picture, and in its WeaponButton script change `WEAPON_NAME = "Bat"`.

## Testing

- Teleporting doesn't work in Studio, so publish **both** places and test in the real game.
- To test buying in Studio: Home → Game Settings → Security → **Enable Studio Access to API Services** = ON.

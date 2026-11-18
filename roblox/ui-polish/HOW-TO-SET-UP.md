# UI Polish: setup steps

Two scripts that work on **all** your UI by themselves. You don't need to change your buttons.

## The files

| # | File | Script type | Where in Explorer | Which place |
|---|---|---|---|---|
| 1 | `1-UIScaler.client.lua` | LocalScript | StarterPlayer > StarterPlayerScripts | **Both** |
| 2 | `2-ButtonEffects.client.lua` | LocalScript | StarterPlayer > StarterPlayerScripts | **Both** |

## Steps (do this in the Lobby AND the Game place)

1. StarterPlayer > StarterPlayerScripts → **+** → **LocalScript** → name it `UIScaler` → paste file **1**.
2. StarterPlayer > StarterPlayerScripts → **+** → **LocalScript** → name it `ButtonEffects` → paste file **2**.

## Test on other devices

In Studio: **Test** tab → **Device** → pick a phone (like iPhone) or a tablet, then press **Play**.

## If something looks wrong

- **Your UI looks too big or too small everywhere:** change `DESIGN_SIZE` in UIScaler to the size of the Studio window you built the UI in.
- **One menu moves to a weird place:** add an Attribute `NoAutoScale` (boolean, ticked) to it, or put the ScreenGui's name in `SKIP_GUIS`.
- **A script that slides a menu in and out stops working:** set `FIX_POSITIONS = false`.
- **One button shouldn't pop:** add an Attribute `NoEffects` (boolean, ticked) to it.
- **No click sound:** change `CLICK_SOUND_ID` to a sound from the Toolbox, like `"rbxassetid://12345"`.

# Class Roll + Slots: setup steps

Spend Bounty to roll a random class. Buy more **slots** with Bounty to keep more classes, then click a slot to equip it.

## The files

| # | File | Script type | Where in Explorer | Which place |
|---|---|---|---|---|
| 1 | `1-ClassSystem.server.lua` | Script | ServerScriptService | **Both** |
| 2 | `2-RollButton.client.lua` | LocalScript | INSIDE your roll ImageButton | **Lobby** |
| 3 | `3-ClassSlots.client.lua` | LocalScript | INSIDE the ScreenGui that has Slot1, Slot2, Slot3 (ONE script for all slots) | **Lobby** |
| 4 | `4-BuySlotButton.client.lua` | LocalScript | INSIDE your buy-slot ImageButton | **Lobby** |

## How slots work

- Everyone starts with **1 slot**. Buy more with the Buy Slot button: slot 2 = 100, slot 3 = 250 Bounty (3 slots max).
- Click a slot to **equip** it. Only the equipped class is used in the game.
- **Rolling puts the new class in the EQUIPPED slot** (it replaces what was there). To keep a class, equip another slot before rolling.
- Buying a slot equips it, so your next roll fills it.

## Lobby place

1. ServerScriptService → **+ Script** → `ClassSystem` → paste file **1**.
2. StarterGui → your ScreenGui → **+ ImageButton** (your roll picture) → inside it **+ LocalScript** → `RollButton` → paste file **2**.
3. Make **3 slot ImageButtons** and **name them exactly** `Slot1`, `Slot2`, `Slot3`. Put **one** LocalScript named `ClassSlots` in the **ScreenGui** (not inside a button) → paste file **3**. Delete any old `SlotButton` scripts inside the buttons. (`3-SlotButton.client.lua` is the old version, not used anymore.)
4. **+ ImageButton** for buying slots → inside it **+ LocalScript** → `BuySlotButton` → paste file **4**.
5. (Optional) a **TextLabel** named `ClassText` in the same ScreenGui, where the roll shows.

## Class accessories (both places)

1. In **ServerStorage**, make a **Folder** called `ClassAccessories`. The names `Accessorys` and `Accessories` work too.
2. Inside it, make a **Folder for each class**, named exactly like the class (`Runner`, `Brute`, `Jumper`, `Tank`, `Ninja`, `Juggernaut`, `Phantom`), and put the **Accessories** in it. You can also use one Accessory named exactly like the class.
3. Put the same folder in the **Lobby AND the Game place**, so you wear them in both.

## Game place

1. ServerScriptService → **+ Script** → `ClassSystem` → paste file **1** (the same one).

## Both places

- **BountyStat** must be in ServerScriptService.

## Settings (ClassSystem CONFIG)

- `SLOT_PRICES = { 0, 100, 250 }`: price of each slot (3 slots). Add more numbers for more slots, and make that many slot buttons.
- `ROLL_COST`, `CLASSES`: like before. Change them in **both** places.
- `STUDIO_MODE = "free"`: rolls and slots cost 0 in Studio, and nothing is saved.

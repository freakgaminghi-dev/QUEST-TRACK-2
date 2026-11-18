# COCO Desktop Pet: Plan

## What to build
COCO, a fluffy light-brown puppy with a drum, sits on the desktop and plays the drum while I type.

| What happens | What COCO shows |
|---|---|
| Not typing | Both paws up (top-left cell) |
| Key on the **left** side pressed (from T G B to the left) | Left paw hits the drum (top-right cell) |
| Key on the **right** side pressed (from Y H N to the right) | Right paw hits the drum (bottom-left cell) |
| Space, Enter, arrows and other middle keys | Left and right take turns |
| No typing for **10 seconds** | Falls asleep (bottom-right cell) and wakes up on the next key press |

- Size: **250 px**
- Place: starts in the **bottom-right corner** (above the taskbar). I can **drag it** anywhere, and it remembers where I left it next time. Only the x/y position is saved.
- Counter: a small bubble under COCO shows **today's key press count** (like "123"). It is **not saved** and starts at 0 every time.
- Quit: **right-click COCO**, then "Quit".
- No background. Only COCO shows, always on top of other windows.

## Where it runs
- This Windows 11 computer.
- First run with Python (`python coco_pet.py`). At the end, bundle it into one `.exe` with PyInstaller.

## Materials
- **Picture:** `art/sheet.png`, the COCO 2×2 sheet (1254 × 1254). Known problems to fix in Step 2:
  - The checkerboard background is painted in, so the picture isn't really transparent.
  - COCO is in a slightly different spot in each cell.
- **Backup picture:** `art/pet_sheet.png` and `art/draw_pet.py` (the simple puppy, kept as a backup).
- **Packages** (OK'd to install at Step 1): `PySide6-Essentials`, `pynput`, `Pillow`, `PyInstaller`.

Planned files:
```
week-03/
  plan.md            this plan
  requirements.txt   the 4 packages
  cut_art.py         cleans and cuts the picture (run once)
  coco_pet.py        the pet program
  art/sheet.png      original picture (never changed)
  art/poses/         up.png, hit_left.png, hit_right.png, sleep.png
```

## How to run
- From Python: `python coco_pet.py` (inside `week-03`)
- As a program: `dist/COCO.exe`. Make it again with:
  `python -m PyInstaller --onefile --windowed --name COCO --add-data "art/poses;art/poses" --noconfirm coco_pet.py`

## Status: all 9 steps done (2026-11-18)
What changed from the plan while building:
- **Step 2:** the 4 cells were already lined up to within 1 px, so the "COCO jumps" worry was wrong. The script still lines them up by the drum.
- **Step 4:** `.gitignore` was added here instead of in Step 8, so `settings.json` could never be committed by accident.
- **Step 8:** the first `.exe` showed small see-through spots (eye shines, drum bolts, name tag). `cut_art.py` had treated those white spots as background. It now only removes the background from the outside edge, and all 4 poses have 0 holes.

## Steps

### Step 1: Install the packages
- Write `requirements.txt` and install the 4 packages with pip.
- **What to check** (every answer must be yes):
  - Did `pip install -r requirements.txt` finish without a red error? (If no because a package doesn't support Python 3.15, **stop and ask** before trying anything else.)
  - Run `python -c "import PySide6, pynput, PIL"`. Does it print nothing?
- **Commit:** "Step 1: add requirements.txt"

### Step 2: Clean and cut the picture
- `cut_art.py` cuts `sheet.png` into 4 cells, turns the checkerboard transparent, and moves each COCO so the drum sits in exactly the same spot in all 4.
- Save them as `art/poses/up.png`, `hit_left.png`, `hit_right.png` and `sleep.png`.
- **What to check** (every answer must be yes):
  - Are there exactly 4 files in `art/poses/`: `up.png`, `hit_left.png`, `hit_right.png`, `sleep.png`?
  - Open each one. Is the background see-through, with no checkerboard?
  - Is the fur free of white edges?
  - Are the eye shines, drum bolts and name tag solid, not see-through?
  - Flip between the 4 pictures. Does the drum stay in the same spot?
- **Commit:** "Step 2: cut COCO into 4 poses"

### Step 3: Show COCO on screen
- A window with no frame and a see-through background, always on top, showing `up.png` at 250 px in the bottom-right corner above the taskbar.
- **What to check** (every answer must be yes):
  - Run `python coco_pet.py`. Does COCO show up in the bottom-right corner?
  - Is COCO the only thing you see, with no box, frame or background around it?
  - Click another window (like Notepad). Is COCO still on top of it?
  - Is the whole taskbar still visible below COCO?
- **Commit:** "Step 3: show COCO in the corner"

### Step 4: Drag, remember the spot, right-click Quit
- Drag with the left mouse button. Save only the x/y position in `settings.json` when I let go. Right-click opens a menu with "Quit".
- **What to check** (every answer must be yes):
  - Hold the left mouse button on COCO and move the mouse. Does COCO follow?
  - Right-click COCO. Does a menu with "Quit" appear?
  - Click "Quit". Does COCO close?
  - Start it again. Does COCO appear where you left it?
  - Open `settings.json`. Does it hold only the x and y numbers and nothing else?
- **Commit:** "Step 4: drag, remember position, quit menu"

### Step 5: Play the drum while typing
- pynput listens for key presses. Each key is checked for its side (left / right / middle), then forgotten right away. The paw stays down for a short moment, then goes back up.
- **What to check** (every answer must be yes). Type in Notepad while COCO is running:
  - Press `A` a few times. Does the left paw hit the drum each time?
  - Press `L` a few times. Does the right paw hit the drum each time?
  - Press Space a few times. Do the paws take turns (left, right, left)?
  - After you stop, does the paw go back up within a second?
  - Mash keys fast for 10 seconds. Does COCO keep moving without freezing or closing?
  - **Privacy check:** search `coco_pet.py` for `print`, `open(`, `write` and `socket`. Is each one unrelated to keys (no key is ever printed, saved or sent)?
- **Commit:** "Step 5: COCO drums when I type"

### Step 6: Count bubble
- A small bubble under COCO shows the number of key presses since it started.
- **What to check** (every answer must be yes):
  - Does the bubble show `0` right after COCO starts?
  - Press any key 5 times. Does it show `5`?
  - Can you read the number easily on both a light and a dark window behind it?
  - Quit and start COCO again. Is it back to `0`?
- **Commit:** "Step 6: add key count bubble"

### Step 7: Fall asleep
- With no typing for 10 seconds, COCO shows `sleep.png`. Any key press wakes it up.
- **What to check** (every answer must be yes):
  - Stop typing and count to 8. Is COCO still awake?
  - Keep waiting until about 12 seconds. Is COCO asleep now?
  - Press one key. Does COCO wake up and hit the drum with that press?
  - Does the count bubble go up by 1 for that key?
- **Commit:** "Step 7: COCO dozes off after 10 seconds"

### Step 8: Bundle it into an .exe
- Use PyInstaller to make one `.exe` with the pictures inside. Add `build/`, `dist/`, `*.spec` and `settings.json` to `.gitignore`.
- **What to check** (every answer must be yes):
  - Is there a `COCO.exe` in `dist/`?
  - Close every terminal, then double-click `COCO.exe`. Does COCO appear with no black terminal window?
  - Go through the questions of Steps 3–7 again with the `.exe`. Is every answer still yes?
  - Run `git status`. Is `COCO.exe` (and `build/`, `dist/`, `COCO.spec`, `settings.json`) left out of the list?
- **Commit:** "Step 8: bundle COCO as an exe" (the .exe itself is not committed)

### Step 9: Final check
- Go through every check again and update this plan if anything changed.
- **What to check** (every answer must be yes):
  - Go through every row of the table in "What to build". Does COCO do each one?
  - Is COCO 250 px, starting in the bottom-right corner?
  - Is every question in Steps 1–8 still answered yes?
  - Does this plan match what was built (anything that changed is written under "Status")?
  - Run `git status`. Does it show no build files (`build/`, `dist/`, `*.spec`, `settings.json`)?
- **Commit:** "Step 9: final check"

## Version 2: size option and drum sounds

### What to add
| What I do | What COCO does |
|---|---|
| Right-click → **Size** → Small / Medium / Large / Huge | COCO becomes **150 / 250 / 350 / 450 px**. Medium (250) is the default. |
| Left paw hits the drum | A **low** drum sound plays |
| Right paw hits the drum | A **high** drum sound plays |
| Right-click → **Sound** (tick on / off) | Sounds play or stop. On is the default. |

- When the size changes, COCO's **bottom-right corner stays where it is**, and it never goes off the screen.
- COCO remembers the size and sound on/off for next time. `settings.json` now holds **x, y, size and sound**, and still never anything about keys.
- The sound only depends on the side (left/right), never on which key.

### How it's made
- **Sound:** Python's built-in `winsound`. PySide6-Essentials has no sound module, and this way nothing new is installed.
- **Drum sounds:** a new script `make_sounds.py` makes two short drum sounds from math (no downloaded files) and saves them as `art/sounds/drum_low.wav` and `art/sounds/drum_high.wav`. It runs once.
- **Size:** the 4 poses are scaled from the original pictures each time the size changes, so they stay sharp.
- The `.exe` command gets one more `--add-data "art/sounds;art/sounds"`.

### Step 10: Make the drum sounds
- Write `make_sounds.py` and run it.
- **What to check** (every answer must be yes):
  - Are there 2 files in `art/sounds/`: `drum_low.wav` and `drum_high.wav`?
  - Double-click each one. Does it sound like a short drum hit (under half a second)?
  - Is `drum_low.wav` clearly lower than `drum_high.wav`?
- **Commit:** "Step 10: make drum sounds"

### Step 11: Drum sounds while typing
- Play the low sound for the left paw and the high sound for the right paw. Add a **Sound** tick in the right-click menu.
- **What to check** (every answer must be yes):
  - Press `A`. Do you hear the low drum?
  - Press `L`. Do you hear the high drum?
  - Press Space a few times. Do low and high take turns, matching the paws?
  - Mash keys fast for 10 seconds. Does COCO keep moving without freezing?
  - Right-click → Sound to turn it off. Is it silent when you type, while the paws still move?
  - Quit and start again. Is Sound still off? (Turn it back on after.)
- **Commit:** "Step 11: COCO's drum makes sounds"

### Step 12: Size option
- Add a **Size** menu with Small / Medium / Large / Huge. The count bubble stays under COCO at every size.
- **What to check** (every answer must be yes):
  - Right-click COCO. Is there a Size menu with 4 choices, and a dot next to the current one?
  - Pick each size. Does COCO change to that size, still sharp and with no box around it?
  - Does the bottom-right corner stay in the same spot when the size changes?
  - With COCO in the bottom-right corner, pick Huge. Is all of COCO still on the screen, above the taskbar?
  - Do drumming, the count bubble and sleeping still work at Small and at Huge?
  - Quit and start again. Is it the size you picked last?
  - Open `settings.json`. Does it hold only x, y, size and sound?
- **Commit:** "Step 12: choose COCO's size"

### Step 13: Bundle Version 2 and final check
- Make the `.exe` again with the sounds inside.
- **What to check** (every answer must be yes):
  - Close every terminal and double-click `dist/COCO.exe`. Do you hear the drums when you type?
  - Go through the questions of Steps 3–7 and 11–12 with the `.exe`. Is every answer still yes?
  - Run `git status`. Does it show no build files (`build/`, `dist/`, `*.spec`, `settings.json`)?
- **Commit:** "Step 13: bundle Version 2"

### Step 14: Sleep and wake sounds
- `make_sounds.py` makes 2 more sounds from math: `art/sounds/snore.wav` (a soft, slow snore, about 1.5 seconds) and `art/sounds/wake.wav` (a short rising "boing", under half a second).
- When COCO falls asleep, the snore plays **once** (not over and over).
- The key press that wakes COCO plays the wake sound instead of a drum. COCO still hits the drum with that press, and the count still goes up by 1.
- The **Sound** tick in the right-click menu turns these off too.
- Test it with `python coco_pet.py`. The `.exe` is made again in Step 13 afterwards.
- **What to check** (every answer must be yes):
  - Are `snore.wav` and `wake.wav` in `art/sounds/`, next to the 2 drum sounds?
  - Double-click `snore.wav`. Does it sound like a soft snore, not loud or scary?
  - Double-click `wake.wav`. Is it a short rising sound, under half a second?
  - Stop typing. When COCO falls asleep (about 10 seconds), do you hear the snore once and then silence?
  - Press a key. Do you hear the wake sound, and does COCO hit the drum?
  - Press more keys. Are they normal drum sounds again?
  - Turn Sound off and let COCO sleep and wake. Is it silent both times?
- **Commit:** "Step 14: COCO snores and wakes up with a sound"

## What not to do
- Never save or send which keys were pressed. Only count how many times.
- Never save, show, print or send which keys were pressed. Only the side (left/right) is used, and only the count is shown.
- No internet use at all.
- Don't start COCO automatically when Windows starts.
- Don't commit the `.exe`, `build/`, `dist/` or `settings.json`.
- Don't install anything other than the 4 packages without asking.
- Don't change `art/sheet.png`. Make new files from it.
- Don't delete or rename files without asking. Work only in `week-03`.
- Don't push to GitHub unless I ask.
- Don't move on to the next step until the current step's check passes.

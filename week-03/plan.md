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

## Steps

### Step 1: Install the packages
- Write `requirements.txt` and install the 4 packages with pip.
- **What to check:** `python -c "import PySide6, pynput, PIL"` runs with no error. If a package doesn't support this Python version (3.15), **stop and ask** before trying anything else.
- **Commit:** "Step 1: add requirements.txt"

### Step 2: Clean and cut the picture
- `cut_art.py` cuts `sheet.png` into 4 cells, turns the checkerboard transparent, and moves each COCO so the drum sits in exactly the same spot in all 4.
- Save them as `art/poses/up.png`, `hit_left.png`, `hit_right.png` and `sleep.png`.
- **What to check:** open the 4 pictures. No checkerboard and no white edges around the fur. Flipping between them, the drum and body don't jump.
- **Commit:** "Step 2: cut COCO into 4 poses"

### Step 3: Show COCO on screen
- A window with no frame and a see-through background, always on top, showing `up.png` at 250 px in the bottom-right corner above the taskbar.
- **What to check:** only COCO is visible, with no box around it. It stays on top when another window is clicked. It doesn't cover the taskbar.
- **Commit:** "Step 3: show COCO in the corner"

### Step 4: Drag, remember the spot, right-click Quit
- Drag with the left mouse button. Save only the x/y position in `settings.json` when I let go. Right-click opens a menu with "Quit".
- **What to check:** drag COCO, quit, then start it again. It comes back in the same spot. `settings.json` contains only the position.
- **Commit:** "Step 4: drag, remember position, quit menu"

### Step 5: Play the drum while typing
- pynput listens for key presses. Each key is checked for its side (left / right / middle), then forgotten right away. The paw stays down for a short moment, then goes back up.
- **What to check:** typing in Notepad: left keys use the left paw, right keys the right paw, and Space takes turns. Fast typing doesn't freeze it. **Privacy check:** search the code to confirm no key is printed, saved, or sent anywhere.
- **Commit:** "Step 5: COCO drums when I type"

### Step 6: Count bubble
- A small bubble under COCO shows the number of key presses since it started.
- **What to check:** the number goes up by 1 per key press, it's readable, and it starts at 0 after a restart.
- **Commit:** "Step 6: add key count bubble"

### Step 7: Fall asleep
- With no typing for 10 seconds, COCO shows `sleep.png`. Any key press wakes it up.
- **What to check:** wait 10 seconds and it falls asleep. Press a key and it wakes up and hits the drum.
- **Commit:** "Step 7: COCO dozes off after 10 seconds"

### Step 8: Bundle it into an .exe
- Use PyInstaller to make one `.exe` with the pictures inside. Add `build/`, `dist/`, `*.spec` and `settings.json` to `.gitignore`.
- **What to check:** double-click the `.exe` (with no terminal open). Everything from Steps 3–7 still works.
- **Commit:** "Step 8: bundle COCO as an exe" (the .exe itself is not committed)

### Step 9: Final check
- Go through every check again and update this plan if anything changed.
- **What to check:** everything in "What to build" works. `git status` shows no build files.
- **Commit:** "Step 9: final check"

## What not to do
- Never save, show, print or send which keys were pressed. Only the side (left/right) is used, and only the count is shown.
- No internet use at all.
- Don't start COCO automatically when Windows starts.
- Don't commit the `.exe`, `build/`, `dist/` or `settings.json`.
- Don't install anything other than the 4 packages without asking.
- Don't change `art/sheet.png`. Make new files from it.
- Don't delete or rename files without asking. Work only in `week-03`.
- Don't push to GitHub unless I ask.
- Don't move on to the next step until the current step's check passes.

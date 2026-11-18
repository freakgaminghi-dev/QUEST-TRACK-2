"""COCO desktop pet.

Run:  python coco_pet.py
"""

import json
import os
import sys

try:
    import winsound  # built into Python on Windows
except ImportError:
    winsound = None

from pynput import keyboard
from PySide6.QtCore import QObject, QPoint, Qt, QTimer, Signal
from PySide6.QtGui import QActionGroup, QColor, QFont, QFontMetrics, QGuiApplication, QPainter, QPen, QPixmap
from PySide6.QtWidgets import QApplication, QMenu, QWidget

SIZES = {"Small": 150, "Medium": 250, "Large": 350, "Huge": 450}  # px
DEFAULT_SIZE = 250
MARGIN = 16     # gap from the screen edge
PAW_DOWN_MS = 150  # how long a paw stays on the drum
BUBBLE_H = 34      # height of the count bubble under COCO
SLEEP_AFTER_MS = 10_000  # no typing for 10 seconds -> COCO dozes off

# where the pictures are (works for "python coco_pet.py" and for the bundled .exe)
BASE = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
POSES_DIR = os.path.join(BASE, "art", "poses")
POSES = ("up", "hit_left", "hit_right", "sleep")

SOUNDS_DIR = os.path.join(BASE, "art", "sounds")
SOUNDS = {"left": os.path.join(SOUNDS_DIR, "drum_low.wav"),
          "right": os.path.join(SOUNDS_DIR, "drum_high.wav")}

# settings.json sits next to the program and holds ONLY: x, y, size, sound on/off.
# Never anything about keys.
APP_DIR = (os.path.dirname(sys.executable) if getattr(sys, "frozen", False)
           else os.path.dirname(os.path.abspath(__file__)))
SETTINGS = os.path.join(APP_DIR, "settings.json")


def load_settings():
    """Read settings.json and keep only the values we know, if they look right."""
    try:
        with open(SETTINGS, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return {}
    if not isinstance(data, dict):
        return {}
    good = {}
    if isinstance(data.get("x"), int) and isinstance(data.get("y"), int):
        good["x"], good["y"] = data["x"], data["y"]
    if data.get("size") in SIZES.values() and not isinstance(data.get("size"), bool):
        good["size"] = data["size"]
    if isinstance(data.get("sound"), bool):
        good["sound"] = data["sound"]
    return good


def save_settings(pos, size, sound):
    try:
        with open(SETTINGS, "w", encoding="utf-8") as f:
            json.dump({"x": pos.x(), "y": pos.y(), "size": size, "sound": sound}, f)
    except OSError:
        pass  # can't save? just use the defaults next time


def play_drum(side):
    """Play the drum for "left" or "right". Only the side decides the sound."""
    if winsound is None:
        return
    try:
        winsound.PlaySound(SOUNDS[side], winsound.SND_FILENAME | winsound.SND_ASYNC
                           | winsound.SND_NODEFAULT)
    except RuntimeError:
        pass  # no sound device? COCO still drums silently


# ----- which side of the keyboard? -----
# Windows key codes. Split down the middle: T G B (and 5) are left, Y H N (and 6) are right.
LEFT_KEYS = set(map(ord, "QWERTASDFGZXCVB12345"))
RIGHT_KEYS = set(map(ord, "YUIOPHJKLNM67890")) | {
    0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF,  # ; = , - . /
    0xDB, 0xDC, 0xDD, 0xDE,              # [ \ ] '
}


def side_of(key):
    """Return only "left", "right" or "middle". The key itself is never kept."""
    vk = getattr(key, "vk", None)
    if vk is None:  # special keys (Space, Enter, arrows...) keep their code in .value
        vk = getattr(getattr(key, "value", None), "vk", None)
    if vk in LEFT_KEYS:
        return "left"
    if vk in RIGHT_KEYS:
        return "right"
    return "middle"


class KeyWatcher(QObject):
    """Listens to the keyboard in the background.

    PRIVACY: for each key press it works out the side, sends just that word
    to the pet, and forgets the key. Keys are never printed, saved or sent.
    """
    pressed = Signal(str)  # "left" / "right" / "middle"

    def __init__(self):
        super().__init__()
        self.listener = keyboard.Listener(on_press=self._on_press)
        self.listener.daemon = True

    def _on_press(self, key):
        self.pressed.emit(side_of(key))

    def start(self):
        self.listener.start()

    def stop(self):
        self.listener.stop()


class Pet(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("COCO")
        # no frame, always on top, no taskbar button, see-through background
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)

        # the full-size pictures; self.pics holds them scaled to the chosen size
        self.originals = {name: QPixmap(os.path.join(POSES_DIR, name + ".png"))
                          for name in POSES}
        self.pics = {}
        self.pose = "up"
        self.count = 0  # key presses since COCO started (never saved)
        self.font = QFont("Segoe UI", 12, QFont.Bold)

        self.drag_offset = None
        self.next_middle = "left"  # middle keys take turns

        self.paw_timer = QTimer(self, singleShot=True, interval=PAW_DOWN_MS)
        self.paw_timer.timeout.connect(lambda: self.set_pose("up"))

        self.sleep_timer = QTimer(self, singleShot=True, interval=SLEEP_AFTER_MS)
        self.sleep_timer.timeout.connect(lambda: self.set_pose("sleep"))
        self.sleep_timer.start()

        settings = load_settings()
        self.sound_on = settings.get("sound", True)
        self.apply_size(settings.get("size", DEFAULT_SIZE))
        saved = QPoint(settings["x"], settings["y"]) if "x" in settings else None
        if saved is not None and self.fits_on_a_screen(saved):
            self.move(saved)
        else:
            self.move_to_corner()

    def save(self):
        save_settings(self.pos(), self.pet_px, self.sound_on)

    def apply_size(self, px):
        """Scale the 4 poses from the full-size pictures and resize the window."""
        self.pet_px = px
        self.pics = {name: pix.scaled(px, px, Qt.KeepAspectRatio, Qt.SmoothTransformation)
                     for name, pix in self.originals.items()}
        self.setFixedSize(px, px + BUBBLE_H)
        self.update()

    def change_size(self, px):
        """New size, keeping the bottom-right corner in place and COCO on the screen."""
        if px == self.pet_px:
            return
        old = self.frameGeometry()
        screen = QGuiApplication.screenAt(old.center()) or QGuiApplication.primaryScreen()
        area = screen.availableGeometry()  # without the taskbar
        self.apply_size(px)
        x = old.right() + 1 - self.width()
        y = old.bottom() + 1 - self.height()
        x = max(area.left(), min(x, area.right() + 1 - self.width()))
        y = max(area.top(), min(y, area.bottom() + 1 - self.height()))
        self.move(x, y)
        self.save()

    def fits_on_a_screen(self, pos):
        """Don't come back off-screen (e.g. a monitor was unplugged)."""
        middle = pos + QPoint(self.width() // 2, self.height() // 2)
        return any(s.availableGeometry().contains(middle) for s in QGuiApplication.screens())

    def move_to_corner(self):
        area = QGuiApplication.primaryScreen().availableGeometry()  # without the taskbar
        self.move(area.right() - self.width() - MARGIN + 1,
                  area.bottom() - self.height() - MARGIN + 1)

    # ----- typing -----
    def on_key(self, side):
        self.count += 1
        if side == "middle":
            side, self.next_middle = self.next_middle, (
                "right" if self.next_middle == "left" else "left")
        self.set_pose("hit_left" if side == "left" else "hit_right")
        if self.sound_on:
            play_drum(side)
        self.paw_timer.start()
        self.sleep_timer.start()  # restart the 10-second countdown
        self.update()  # redraw the count

    def set_pose(self, pose):
        if pose != self.pose:
            self.pose = pose
            self.update()

    # ----- mouse: drag with left button, menu with right button -----
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.drag_offset = event.globalPosition().toPoint() - self.pos()

    def mouseMoveEvent(self, event):
        if self.drag_offset is not None:
            self.move(event.globalPosition().toPoint() - self.drag_offset)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.LeftButton and self.drag_offset is not None:
            self.drag_offset = None
            self.save()

    def toggle_sound(self, on):
        self.sound_on = on
        self.save()

    def contextMenuEvent(self, event):
        self.build_menu().exec(event.globalPos())

    def build_menu(self):
        menu = QMenu(self)
        sound = menu.addAction("Sound")
        sound.setCheckable(True)
        sound.setChecked(self.sound_on)
        sound.toggled.connect(self.toggle_sound)
        size_menu = menu.addMenu("Size")
        group = QActionGroup(size_menu)
        for name, px in SIZES.items():
            act = size_menu.addAction(f"{name} ({px} px)")
            act.setCheckable(True)
            act.setChecked(px == self.pet_px)
            act.setActionGroup(group)
            act.triggered.connect(lambda _=False, px=px: self.change_size(px))
        menu.addSeparator()
        menu.addAction("Quit", QApplication.quit)
        return menu

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.SmoothPixmapTransform)
        p.setRenderHint(QPainter.Antialiasing)
        p.drawPixmap(0, 0, self.pics[self.pose])

        # count bubble
        text = f"{self.count:,}"
        p.setFont(self.font)
        w = max(56, QFontMetrics(self.font).horizontalAdvance(text) + 28)
        h = BUBBLE_H - 6
        x = (self.width() - w) / 2
        y = self.pet_px + 2
        p.setPen(QPen(QColor(0x3B, 0x24, 0x16), 3))
        p.setBrush(QColor(255, 250, 240))
        p.drawRoundedRect(x, y, w, h, h / 2, h / 2)
        p.drawText(int(x), int(y), int(w), int(h), Qt.AlignCenter, text)


def main():
    app = QApplication(sys.argv)
    pet = Pet()
    pet.show()
    keys = KeyWatcher()
    keys.pressed.connect(pet.on_key)
    keys.start()
    code = app.exec()
    keys.stop()
    sys.exit(code)


if __name__ == "__main__":
    main()

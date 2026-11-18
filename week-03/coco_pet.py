"""COCO desktop pet.

Run:  python coco_pet.py
"""

import json
import os
import sys

from pynput import keyboard
from PySide6.QtCore import QObject, QPoint, Qt, QTimer, Signal
from PySide6.QtGui import QColor, QFont, QFontMetrics, QGuiApplication, QPainter, QPen, QPixmap
from PySide6.QtWidgets import QApplication, QMenu, QWidget

PET_SIZE = 250  # px
MARGIN = 16     # gap from the screen edge
PAW_DOWN_MS = 150  # how long a paw stays on the drum
BUBBLE_H = 34      # height of the count bubble under COCO
SLEEP_AFTER_MS = 10_000  # no typing for 10 seconds -> COCO dozes off

# where the pictures are (works for "python coco_pet.py" and for the bundled .exe)
BASE = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
POSES_DIR = os.path.join(BASE, "art", "poses")
POSES = ("up", "hit_left", "hit_right", "sleep")

# settings.json sits next to the program and holds ONLY the window position
APP_DIR = (os.path.dirname(sys.executable) if getattr(sys, "frozen", False)
           else os.path.dirname(os.path.abspath(__file__)))
SETTINGS = os.path.join(APP_DIR, "settings.json")


def load_position():
    try:
        with open(SETTINGS, encoding="utf-8") as f:
            data = json.load(f)
        return QPoint(int(data["x"]), int(data["y"]))
    except (OSError, ValueError, KeyError, TypeError):
        return None


def save_position(pos):
    try:
        with open(SETTINGS, "w", encoding="utf-8") as f:
            json.dump({"x": pos.x(), "y": pos.y()}, f)
    except OSError:
        pass  # can't save? just start in the corner next time


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

        self.pics = {}
        for name in POSES:
            pix = QPixmap(os.path.join(POSES_DIR, name + ".png"))
            self.pics[name] = pix.scaled(PET_SIZE, PET_SIZE, Qt.KeepAspectRatio,
                                         Qt.SmoothTransformation)
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

        self.setFixedSize(PET_SIZE, PET_SIZE + BUBBLE_H)
        saved = load_position()
        if saved is not None and self.fits_on_a_screen(saved):
            self.move(saved)
        else:
            self.move_to_corner()

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
            save_position(self.pos())

    def contextMenuEvent(self, event):
        menu = QMenu(self)
        menu.addAction("Quit", QApplication.quit)
        menu.exec(event.globalPos())

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
        y = PET_SIZE + 2
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

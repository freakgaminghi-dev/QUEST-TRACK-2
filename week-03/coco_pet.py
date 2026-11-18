"""COCO desktop pet.

Run:  python coco_pet.py
"""

import json
import os
import sys

from PySide6.QtCore import QPoint, Qt
from PySide6.QtGui import QGuiApplication, QPainter, QPixmap
from PySide6.QtWidgets import QApplication, QMenu, QWidget

PET_SIZE = 250  # px
MARGIN = 16     # gap from the screen edge

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

        self.drag_offset = None

        self.setFixedSize(PET_SIZE, PET_SIZE)
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
        p.drawPixmap(0, 0, self.pics[self.pose])


def main():
    app = QApplication(sys.argv)
    pet = Pet()
    pet.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()

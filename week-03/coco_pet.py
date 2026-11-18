"""COCO desktop pet.

Run:  python coco_pet.py
"""

import os
import sys

from PySide6.QtCore import Qt
from PySide6.QtGui import QGuiApplication, QPainter, QPixmap
from PySide6.QtWidgets import QApplication, QWidget

PET_SIZE = 250  # px
MARGIN = 16     # gap from the screen edge

# where the pictures are (works for "python coco_pet.py" and for the bundled .exe)
BASE = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
POSES_DIR = os.path.join(BASE, "art", "poses")
POSES = ("up", "hit_left", "hit_right", "sleep")


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

        self.setFixedSize(PET_SIZE, PET_SIZE)
        self.move_to_corner()

    def move_to_corner(self):
        area = QGuiApplication.primaryScreen().availableGeometry()  # without the taskbar
        self.move(area.right() - self.width() - MARGIN + 1,
                  area.bottom() - self.height() - MARGIN + 1)

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

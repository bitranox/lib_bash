#!/usr/bin/env python3
import os
from pathlib import Path
from typing import List

# 👇 Import from submodule
from libs import setupenv

# -----------------------------
# Settings
# -----------------------------
# requirements_path: Path = Path("./requirements.txt")
requirements_path: Path = Path("")
venv_path: Path = Path.home() / ".local" / "share" / "lib_bash" / "venv"
additional_packages: List[str] = ["rich_click",]

# -----------------------------
# Run Environment Setup
# -----------------------------
setupenv.setup(venv_path, requirements_path, additional_packages, create_new_venv=True, debug=True)
setupenv.setup(venv_path, requirements_path, additional_packages, create_new_venv=False, debug=False)

import rich_click


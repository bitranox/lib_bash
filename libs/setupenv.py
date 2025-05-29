# setupenv.py

import shutil
import subprocess
import sys
import importlib
import os
from doctest import debug
from pathlib import Path
import venv
from typing import List

_debug = False
_pip_updated = False

def executed_in_virtualenv() -> bool:
    return sys.prefix != sys.base_prefix


def create_virtualenv(venv_path: Path) -> None:
    if not venv_path.exists():
        if _debug: print(f"📦 Creating virtual environment at '{venv_path}'...")
        venv.create(venv_path, with_pip=True)
    else:
        if _debug: print(f"✅ Virtual environment already exists at '{venv_path}'.")


def activate_virtualenv(venv_path: Path) -> None:
    if not executed_in_virtualenv():
        python_exe = venv_path / "bin" / "python"
        if not python_exe.exists():
            if _debug: print("❌ Could not find Python executable in virtual environment.")
            sys.exit(1)
        if _debug: print("🔁 Re-executing inside virtual environment...")
        os.execv(str(python_exe), [str(python_exe)] + sys.argv)


def read_requirements_file(path: Path) -> List[str]:
    if not path.is_file():
        raise FileNotFoundError(f"Requirements file '{path}' not found.")
    with path.open("r") as f:
        return [line.strip() for line in f if line.strip() and not line.startswith("#")]


def install_and_import(package: str) -> None:
    global _pip_updated
    try:
        importlib.import_module(package)
    except ImportError:
        if _debug: print(f"📦 '{package}' not found. Installing...")
        # update pip once
        if not _pip_updated:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", "pip"])
            _pip_updated = True
        # install the missing package
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        if _debug: print(f"✅ '{package}' installed successfully.")


def setup(venv_path: Path, requirements_path: Path, additional_packages: List[str], create_new_venv: bool = False, debug: bool = False) -> None:
    """

    Entry point for setting up the environment:
    - Create and activate venv if needed
    - Install required packages
    - Final setup and tips
    """
    global _debug
    _debug = debug
    if not executed_in_virtualenv():
        if create_new_venv:
            if venv_path.exists() and venv_path.is_dir():
                shutil.rmtree(venv_path)
        create_virtualenv(venv_path)
        activate_virtualenv(venv_path)
        return  # Script will restart inside venv

    # Load package list
    packages = list()
    if requirements_path != Path(""):
        try:
            packages = read_requirements_file(requirements_path)
            if _debug: print(f"📄 Using packages from '{requirements_path}'...")
        except FileNotFoundError as e:
            print(f"❌ {e}")

    packages = packages + additional_packages

    if not packages:
        if _debug: print("📦 No requirements specified...")

    # Install packages
    for package in packages:
        install_and_import(package)

    if packages:
        if _debug: print("🎉 All required packages are installed and ready.")

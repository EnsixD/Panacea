#!/usr/bin/python3
"""Redirection to a moved location"""

import os
import subprocess
import sys


def read_file(fn) -> str:
    """Read a file and return the contents"""
    with open(fn, "r", encoding="utf-8") as r:
        return r.read().strip()


def get_distro() -> str:
    """Get the distribution name"""
    distro = "unknown"
    if os.path.exists("/etc/os-release"):
        with open("/etc/os-release", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("ID="):
                    return line.split("=")[1].strip().strip('"')
    if os.path.exists("/etc/arch-release"):
        return "arch"
    elif os.path.exists("/etc/fedora-release"):
        return "fedora"
    elif os.path.exists("/etc/debian_version"):
        return "debian"

    return distro


def is_root() -> bool:
    """Check if the user is root"""
    return os.geteuid() == 0


def relaunch_sudo() -> None:
    """Relaunch the script with sudo if not already running as root"""
    if not is_root():
        print("Relaunching with sudo")
        os.execvp("sudo", ["sudo", "-E"] + sys.argv + ["-y"])


class DistroPackage:
    """Base class for distro packages"""

    def __init__(self, deb, rpm, arch, message):
        self.deb = deb
        self.rpm = rpm
        self.arch = arch
        self.message = message

    def install(self):
        """Install the package for a given distro"""
        relaunch_sudo()
        print(self.message)
        dist = get_distro()
        if dist in ("ubuntu", "debian"):
            if not self.deb:
                return False
            installer = ["apt", "install", self.deb]
        elif dist == "fedora":
            if not self.rpm:
                return False
            release = read_file("/usr/lib/os-release")
            variant = None
            for line in release.split("\n"):
                if line.startswith("VARIANT_ID"):
                    variant = line.split("=")[-1]
            if variant != "workstation":
                return False
            installer = ["dnf", "install", "-y", self.rpm]
        elif dist == "arch" or os.path.exists("/etc/arch-release"):
            if not self.arch:
                return False
            installer = ["pacman", "-Sy", self.arch]
        else:
            return False

        try:
            subprocess.check_call(installer)
        except subprocess.CalledProcessError as e:
            sys.exit(e)
        return True


class PipxPackage(DistroPackage):
    """Pyudev package"""

    def __init__(self):
        super().__init__(
            deb="pipx",
            rpm="pipx",
            arch="python-pipx",
            message="pipx is not installed",
        )


def check_amd_s2idle(stdout) -> bool:
    """Check if amd-s2idle is installed"""
    try:
        subprocess.check_call(["amd-s2idle", "--help"], stdout=stdout)
    except FileNotFoundError:
        return False
    return True


if __name__ == "__main__":
    print(
        "This script has been merged into the amd-debug-tools python wheel @ https://pypi.org/project/amd-debug-tools/"
    )
    if not check_amd_s2idle(stdout=subprocess.DEVNULL):
        if "-y" in sys.argv:
            download = "y"
        else:
            download = input("Install amd-debug-tools python wheel (y/N)? ")
        if "y" in download.lower():
            try:
                pipx = (
                    subprocess.call(["pipx", "--version"], stdout=subprocess.DEVNULL)
                    == 0
                )
            except FileNotFoundError:
                pipx = False
            if not pipx:
                package = PipxPackage()
                if not package.install():
                    print("Failed to install pipx")
                    sys.exit(1)
            # install amd-debug-tools wheel using pipx
            try:
                subprocess.check_call(["pipx", "install", "amd-debug-tools"])
            except subprocess.CalledProcessError as e:
                print(f"Failed to install amd-debug-tools: {e}")
                sys.exit(1)
            # run pipx ensurepath
            try:
                subprocess.check_call(["pipx", "ensurepath"])
            except subprocess.CalledProcessError as e:
                print(f"Failed to run pipx ensurepath: {e}")
                sys.exit(1)

    if check_amd_s2idle(None):
        sys.exit(0)

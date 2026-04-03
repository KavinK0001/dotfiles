#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting installation..."

# 1. Install AUR helper (yay) if not present
if ! command -v yay &> /dev/null; then
    echo "yay not found. Installing yay-bin from AUR..."
    # Make sure git and base-devel are installed for building packages
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin
    makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
    rm -rf /tmp/yay-bin
else
    echo "yay is already installed."
fi

# 2. Install pacman/AUR packages from packages.txt
PACKAGES_FILE="$SCRIPT_DIR/packages.txt"
if [[ -f "$PACKAGES_FILE" ]]; then
    echo "Installing packages from $PACKAGES_FILE using yay..."
    # Install packages defined in the file. yay doesn't need 'sudo' prefix.
    yay -S --needed --noconfirm - < "$PACKAGES_FILE"
else
    echo "Warning: packages.txt not found in $SCRIPT_DIR!"
fi

# 3. Move .config to runner's home directory
CONFIG_DIR="$SCRIPT_DIR/.config"
if [[ -d "$CONFIG_DIR" ]]; then
    echo "Transferring .config files to $HOME/.config..."
    mkdir -p "$HOME/.config"
    
    # We use cp -a to safely copy all contents (including hidden files) 
    # without creating nested .config directories.
    # Note: Using `cp` rather than `mv` is generally safer for dotfiles repos 
    # to keep your repo intact, treating it as moving the configs 'into place'.
    cp -a "$CONFIG_DIR/." "$HOME/.config/"
    
    echo "Configuration files successfully processed."
else
    echo "Warning: .config folder not found in $SCRIPT_DIR!"
fi

echo "Installation complete!"

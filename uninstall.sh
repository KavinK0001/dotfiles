#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting uninstallation..."

# 1. Uninstall pacman packages from packages.txt
PACKAGES_FILE="$SCRIPT_DIR/packages.txt"
if [[ -f "$PACKAGES_FILE" ]]; then
    echo "Uninstalling packages listed in $PACKAGES_FILE..."
    # -R removes the package, -ns removes unneeded dependencies and config files.
    # || true is used to prevent the script from failing if some packages are already uninstalled
    # We omit --noconfirm to allow the user to review what is being removed, 
    # as uninstalling packages might sometimes remove things relied upon by other apps!
    # If a silent uninstall is preferred, add --noconfirm below.
    sudo pacman -R $(cat "$PACKAGES_FILE") || true
else
    echo "Warning: packages.txt not found in $SCRIPT_DIR!"
fi

# 2. Remove copied .config items from runner's home directory
CONFIG_DIR="$SCRIPT_DIR/.config"
if [[ -d "$CONFIG_DIR" ]]; then
    echo "Removing transferred .config files from $HOME/.config..."
    
    # We look at exactly what is inside the repository's .config dir
    # and remove the corresponding files/folders from the home directory.
    find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 -exec basename {} \; | while read -r item; do
        TARGET_PATH="$HOME/.config/$item"
        if [[ -e "$TARGET_PATH" || -L "$TARGET_PATH" ]]; then
            rm -rf "$TARGET_PATH"
            echo "Removed target: $TARGET_PATH"
        fi
    done
    
    echo "Configuration files successfully processed."
else
    echo "Warning: .config folder not found in $SCRIPT_DIR!"
fi

echo "Uninstallation complete!"

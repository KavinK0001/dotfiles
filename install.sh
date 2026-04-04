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

# 4. Set fish as the default login shell
FISH_PATH="$(command -v fish)"
if [[ -n "$FISH_PATH" ]]; then
    if ! grep -qxF "$FISH_PATH" /etc/shells; then
        echo "Adding $FISH_PATH to /etc/shells..."
        echo "$FISH_PATH" | sudo tee -a /etc/shells > /dev/null
    fi
    echo "Setting fish as the default login shell..."
    sudo chsh -s "$FISH_PATH" "$USER"
    echo "Login shell changed to fish. Re-login to apply."
else
    echo "Warning: fish not found in PATH. Skipping shell change."
fi

# 5. Add fastfetch to fish config so it runs on every terminal open
FISH_CONFIG="$HOME/.config/fish/config.fish"
mkdir -p "$(dirname "$FISH_CONFIG")"
if ! grep -qF 'fastfetch' "$FISH_CONFIG" 2>/dev/null; then
    echo "Adding fastfetch to $FISH_CONFIG..."
    printf '\n# Run fastfetch on terminal startup\nif status is-interactive\n    fastfetch\nend\n' >> "$FISH_CONFIG"
else
    echo "fastfetch is already present in $FISH_CONFIG. Skipping."
fi

# 6. Set GTK theme to Adapta-Nokto
GTK_THEME="Adapta-Nokto"
echo "Setting GTK theme to $GTK_THEME..."

# GTK 2
GTK2_RC="$HOME/.gtkrc-2.0"
if grep -qF 'gtk-theme-name' "$GTK2_RC" 2>/dev/null; then
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=\"$GTK_THEME\"/" "$GTK2_RC"
else
    echo "gtk-theme-name=\"$GTK_THEME\"" >> "$GTK2_RC"
fi

# GTK 3
GTK3_SETTINGS="$HOME/.config/gtk-3.0/settings.ini"
mkdir -p "$(dirname "$GTK3_SETTINGS")"
if [[ ! -f "$GTK3_SETTINGS" ]]; then
    printf '[Settings]\ngtk-theme-name=%s\n' "$GTK_THEME" > "$GTK3_SETTINGS"
elif grep -qF 'gtk-theme-name' "$GTK3_SETTINGS"; then
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$GTK_THEME/" "$GTK3_SETTINGS"
else
    sed -i "/^\[Settings\]/a gtk-theme-name=$GTK_THEME" "$GTK3_SETTINGS"
fi

# GTK 4
GTK4_SETTINGS="$HOME/.config/gtk-4.0/settings.ini"
mkdir -p "$(dirname "$GTK4_SETTINGS")"
if [[ ! -f "$GTK4_SETTINGS" ]]; then
    printf '[Settings]\ngtk-theme-name=%s\n' "$GTK_THEME" > "$GTK4_SETTINGS"
elif grep -qF 'gtk-theme-name' "$GTK4_SETTINGS"; then
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$GTK_THEME/" "$GTK4_SETTINGS"
else
    sed -i "/^\[Settings\]/a gtk-theme-name=$GTK_THEME" "$GTK4_SETTINGS"
fi

# Apply via gsettings for apps that use GSettings (best-effort)
if command -v gsettings &> /dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
fi

echo "GTK theme set to $GTK_THEME."

# 7. Enable systemd services at boot
echo "Enabling systemd services..."

for SERVICE in tuned.service ly.service; do
    if systemctl list-unit-files "$SERVICE" &>/dev/null && systemctl list-unit-files "$SERVICE" | grep -q "$SERVICE"; then
        sudo systemctl enable "$SERVICE"
        echo "  ✔ Enabled $SERVICE"
    else
        echo "  ⚠ Warning: $SERVICE not found, skipping."
    fi
done


# 8. Configure Qt themes (qt5ct / qt6ct → Kvantum, Kvantum → KvAdaptaDark)
echo "Configuring Qt theme settings..."

# qt5ct
QT5CT_CONF="$HOME/.config/qt5ct/qt5ct.conf"
mkdir -p "$(dirname "$QT5CT_CONF")"
if [[ ! -f "$QT5CT_CONF" ]]; then
    printf '[Appearance]\nstyle=kvantum\n' > "$QT5CT_CONF"
elif grep -qF 'style=' "$QT5CT_CONF"; then
    sed -i 's/^style=.*/style=kvantum/' "$QT5CT_CONF"
else
    sed -i '/^\[Appearance\]/a style=kvantum' "$QT5CT_CONF"
fi
echo "  ✔ qt5ct: style set to kvantum"

# qt6ct
QT6CT_CONF="$HOME/.config/qt6ct/qt6ct.conf"
mkdir -p "$(dirname "$QT6CT_CONF")"
if [[ ! -f "$QT6CT_CONF" ]]; then
    printf '[Appearance]\nstyle=kvantum\n' > "$QT6CT_CONF"
elif grep -qF 'style=' "$QT6CT_CONF"; then
    sed -i 's/^style=.*/style=kvantum/' "$QT6CT_CONF"
else
    sed -i '/^\[Appearance\]/a style=kvantum' "$QT6CT_CONF"
fi
echo "  ✔ qt6ct: style set to kvantum"

# Kvantum — select KvAdaptaDark theme
KVANTUM_CONF="$HOME/.config/Kvantum/kvantum.kvconfig"
mkdir -p "$(dirname "$KVANTUM_CONF")"
if [[ ! -f "$KVANTUM_CONF" ]]; then
    printf '[General]\ntheme=KvAdaptaDark\n' > "$KVANTUM_CONF"
elif grep -qF 'theme=' "$KVANTUM_CONF"; then
    sed -i 's/^theme=.*/theme=KvAdaptaDark/' "$KVANTUM_CONF"
else
    sed -i '/^\[General\]/a theme=KvAdaptaDark' "$KVANTUM_CONF"
fi
echo "  ✔ Kvantum: theme set to KvAdaptaDark"

echo ""
echo "══════════════════════════════════════════"
echo " Installation complete!"
echo " Please reboot your system for all"
echo " changes to take effect."
echo "   $ reboot"
echo "══════════════════════════════════════════"

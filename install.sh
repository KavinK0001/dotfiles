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

# 6. Set GTK theme and icon theme
GTK_THEME="Adapta-Nokto"
ICON_THEME="Papirus-Dark"
echo "Setting GTK theme to $GTK_THEME and icon theme to $ICON_THEME..."

# Helper: apply a key=value setting to an INI [section] in a file
# Usage: set_ini_key <file> <section_header e.g. '[Settings]'> <key> <value>
set_ini_key() {
    local file="$1" section="$2" key="$3" value="$4"
    if [[ ! -f "$file" ]]; then
        printf '%s\n%s=%s\n' "$section" "$key" "$value" > "$file"
    elif grep -qF "${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        sed -i "/^${section//\[/\\[}/a ${key}=${value}" "$file"
    fi
}

# GTK 2
GTK2_RC="$HOME/.gtkrc-2.0"
if grep -qF 'gtk-theme-name' "$GTK2_RC" 2>/dev/null; then
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=\"$GTK_THEME\"/" "$GTK2_RC"
else
    echo "gtk-theme-name=\"$GTK_THEME\"" >> "$GTK2_RC"
fi
if grep -qF 'gtk-icon-theme-name' "$GTK2_RC" 2>/dev/null; then
    sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=\"$ICON_THEME\"/" "$GTK2_RC"
else
    echo "gtk-icon-theme-name=\"$ICON_THEME\"" >> "$GTK2_RC"
fi

# GTK 3
GTK3_SETTINGS="$HOME/.config/gtk-3.0/settings.ini"
mkdir -p "$(dirname "$GTK3_SETTINGS")"
[[ ! -f "$GTK3_SETTINGS" ]] && printf '[Settings]\n' > "$GTK3_SETTINGS"
set_ini_key "$GTK3_SETTINGS" '[Settings]' 'gtk-theme-name' "$GTK_THEME"
set_ini_key "$GTK3_SETTINGS" '[Settings]' 'gtk-icon-theme-name' "$ICON_THEME"

# GTK 4
GTK4_SETTINGS="$HOME/.config/gtk-4.0/settings.ini"
mkdir -p "$(dirname "$GTK4_SETTINGS")"
[[ ! -f "$GTK4_SETTINGS" ]] && printf '[Settings]\n' > "$GTK4_SETTINGS"
set_ini_key "$GTK4_SETTINGS" '[Settings]' 'gtk-theme-name' "$GTK_THEME"
set_ini_key "$GTK4_SETTINGS" '[Settings]' 'gtk-icon-theme-name' "$ICON_THEME"

# Apply via gsettings for apps that use GSettings (best-effort)
if command -v gsettings &> /dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
fi

echo "GTK theme set to $GTK_THEME, icon theme set to $ICON_THEME."

# 7. Enable systemd services at boot
echo "Enabling systemd services..."

# Enable tuned and set default profile
if systemctl list-unit-files tuned.service 2>/dev/null | grep -q tuned.service; then
    sudo systemctl enable tuned.service
    echo "  ✔ Enabled tuned.service"
    # Start tuned now so we can apply the profile immediately
    sudo systemctl start tuned.service 2>/dev/null || true
    sudo tuned-adm profile balanced-battery
    echo "  ✔ tuned profile set to balanced-battery"
else
    echo "  ⚠ Warning: tuned.service not found, skipping."
fi

# Set up Ly display manager on tty1
sudo systemctl enable ly@tty1.service
echo "  ✔ Enabled ly@tty1.service"
sudo systemctl disable getty@tty1.service 2>/dev/null || true
echo "  ✔ Disabled getty@tty1.service"


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

# 9. System-wide GTK theme (covers root apps launched via pkexec, e.g. timeshift-gtk)
# /etc/gtk-X.0/settings.ini is read by ALL users incl. root regardless of $HOME
echo "Writing system-wide GTK theme config (/etc/gtk-3.0 and /etc/gtk-4.0)..."

for ETC_GTK in /etc/gtk-3.0/settings.ini /etc/gtk-4.0/settings.ini; do
    sudo mkdir -p "$(dirname "$ETC_GTK")"
    if sudo test ! -f "$ETC_GTK"; then
        printf '[Settings]\ngtk-theme-name=%s\ngtk-icon-theme-name=%s\n' \
            "$GTK_THEME" "$ICON_THEME" | sudo tee "$ETC_GTK" > /dev/null
    else
        # gtk-theme-name
        if sudo grep -qF 'gtk-theme-name' "$ETC_GTK"; then
            sudo sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$GTK_THEME|" "$ETC_GTK"
        else
            sudo sed -i "/^\[Settings\]/a gtk-theme-name=$GTK_THEME" "$ETC_GTK"
        fi
        # gtk-icon-theme-name
        if sudo grep -qF 'gtk-icon-theme-name' "$ETC_GTK"; then
            sudo sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$ICON_THEME|" "$ETC_GTK"
        else
            sudo sed -i "/^\[Settings\]/a gtk-icon-theme-name=$ICON_THEME" "$ETC_GTK"
        fi
    fi
    echo "  ✔ $ETC_GTK updated"
done

# 10. Apply all theme settings for the root user as well
echo "Applying theme settings for root user..."

sudo bash -s -- "$GTK_THEME" "$ICON_THEME" << 'ROOTSCRIPT'
GTK_THEME="$1"
ICON_THEME="$2"

set_ini_key() {
    local file="$1" section="$2" key="$3" value="$4"
    if [[ ! -f "$file" ]]; then
        printf '%s\n%s=%s\n' "$section" "$key" "$value" > "$file"
    elif grep -qF "${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        sed -i "/^${section//\[/\\[}/a ${key}=${value}" "$file"
    fi
}

# GTK 2 (root)
GTK2_RC="/root/.gtkrc-2.0"
if grep -qF 'gtk-theme-name' "$GTK2_RC" 2>/dev/null; then
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=\"$GTK_THEME\"/" "$GTK2_RC"
else
    echo "gtk-theme-name=\"$GTK_THEME\"" >> "$GTK2_RC"
fi
if grep -qF 'gtk-icon-theme-name' "$GTK2_RC" 2>/dev/null; then
    sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=\"$ICON_THEME\"/" "$GTK2_RC"
else
    echo "gtk-icon-theme-name=\"$ICON_THEME\"" >> "$GTK2_RC"
fi

# GTK 3 (root)
GTK3_SETTINGS="/root/.config/gtk-3.0/settings.ini"
mkdir -p "$(dirname "$GTK3_SETTINGS")"
[[ ! -f "$GTK3_SETTINGS" ]] && printf '[Settings]\n' > "$GTK3_SETTINGS"
set_ini_key "$GTK3_SETTINGS" '[Settings]' 'gtk-theme-name' "$GTK_THEME"
set_ini_key "$GTK3_SETTINGS" '[Settings]' 'gtk-icon-theme-name' "$ICON_THEME"

# GTK 4 (root)
GTK4_SETTINGS="/root/.config/gtk-4.0/settings.ini"
mkdir -p "$(dirname "$GTK4_SETTINGS")"
[[ ! -f "$GTK4_SETTINGS" ]] && printf '[Settings]\n' > "$GTK4_SETTINGS"
set_ini_key "$GTK4_SETTINGS" '[Settings]' 'gtk-theme-name' "$GTK_THEME"
set_ini_key "$GTK4_SETTINGS" '[Settings]' 'gtk-icon-theme-name' "$ICON_THEME"

# qt5ct (root)
QT5CT_CONF="/root/.config/qt5ct/qt5ct.conf"
mkdir -p "$(dirname "$QT5CT_CONF")"
if [[ ! -f "$QT5CT_CONF" ]]; then
    printf '[Appearance]\nstyle=kvantum\n' > "$QT5CT_CONF"
elif grep -qF 'style=' "$QT5CT_CONF"; then
    sed -i 's/^style=.*/style=kvantum/' "$QT5CT_CONF"
else
    sed -i '/^\[Appearance\]/a style=kvantum' "$QT5CT_CONF"
fi

# qt6ct (root)
QT6CT_CONF="/root/.config/qt6ct/qt6ct.conf"
mkdir -p "$(dirname "$QT6CT_CONF")"
if [[ ! -f "$QT6CT_CONF" ]]; then
    printf '[Appearance]\nstyle=kvantum\n' > "$QT6CT_CONF"
elif grep -qF 'style=' "$QT6CT_CONF"; then
    sed -i 's/^style=.*/style=kvantum/' "$QT6CT_CONF"
else
    sed -i '/^\[Appearance\]/a style=kvantum' "$QT6CT_CONF"
fi

# Kvantum (root)
KVANTUM_CONF="/root/.config/Kvantum/kvantum.kvconfig"
mkdir -p "$(dirname "$KVANTUM_CONF")"
if [[ ! -f "$KVANTUM_CONF" ]]; then
    printf '[General]\ntheme=KvAdaptaDark\n' > "$KVANTUM_CONF"
elif grep -qF 'theme=' "$KVANTUM_CONF"; then
    sed -i 's/^theme=.*/theme=KvAdaptaDark/' "$KVANTUM_CONF"
else
    sed -i '/^\[General\]/a theme=KvAdaptaDark' "$KVANTUM_CONF"
fi

echo "  ✔ Root theme config applied."
ROOTSCRIPT

echo ""
echo "══════════════════════════════════════════"
echo " Installation complete!"
echo " Please reboot your system for all"
echo " changes to take effect."
echo "   $ reboot"
echo "══════════════════════════════════════════"

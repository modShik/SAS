#!/bin/bash
# SAS OS - Install-Only Version with Enhanced UI
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo $0"
    exit 1
fi

WORK_DIR="$HOME/SAS-build"

# Complete clean
if [ -d "$WORK_DIR" ]; then
    cd "$WORK_DIR"
    lb clean --purge 2>/dev/null || true
    cd "$HOME"
    rm -rf "$WORK_DIR"
fi

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
apt-get update -qq
for pkg in live-build debootstrap squashfs-tools xorriso isolinux syslinux-efi grub-pc-bin grub-efi-amd64-bin; do
    dpkg -l | grep -q "^ii  $pkg " || apt-get install -y -qq --no-install-recommends $pkg
done

lb config noauto \
    --distribution bookworm \
    --architectures amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --mode debian \
    --debian-installer true \
    --debian-installer-gui true \
    --debian-installer-distribution bookworm \
    --mirror-bootstrap http://deb.debian.org/debian/ \
    --mirror-chroot http://deb.debian.org/debian/ \
    --mirror-binary http://deb.debian.org/debian/ \
    --mirror-debian-installer http://deb.debian.org/debian/ \
    --apt-indices false \
    --apt-recommends true \
    --binary-images iso-hybrid \
    --bootloaders "syslinux,grub-efi" \
    --iso-application "SAS OS" \
    --iso-publisher "SAS" \
    --iso-volume "SAS_INSTALLER" \
    --memtest none \
    --win32-loader false

mkdir -p config/package-lists

# Core system with enhanced UI
cat > config/package-lists/system.list.chroot << 'EOF'
task-lxde-desktop
lxde
lxappearance
lxde-common
lxpanel
lxsession
openbox
obconf
pcmanfm
lxterminal
lightdm
lightdm-gtk-greeter
lightdm-gtk-greeter-settings
xorg
xserver-xorg-video-all
xserver-xorg-input-all
plymouth
plymouth-themes
desktop-base
systemd-sysv
dbus
udev
network-manager
network-manager-gnome
wireless-tools
wpasupplicant
firmware-linux
firmware-linux-free
firmware-linux-nonfree
firmware-misc-nonfree
firmware-iwlwifi
firmware-realtek
bluez
bluez-tools
pulseaudio
pavucontrol
alsa-utils
sudo
locales
ca-certificates
EOF

# Desktop applications and themes
cat > config/package-lists/desktop.list.chroot << 'EOF'
firefox-esr
chromium
gedit
pluma
file-roller
gparted
gnome-disk-utility
baobab
galculator
gpicview
xarchiver
nitrogen
feh
lxappearance
gtk2-engines
gtk2-engines-murrine
gtk2-engines-pixbuf
arc-theme
papirus-icon-theme
numix-gtk-theme
breeze-cursor-theme
fonts-dejavu
fonts-liberation
fonts-noto
fonts-roboto
fonts-ubuntu
libreoffice-writer
libreoffice-calc
libreoffice-impress
vlc
gimp
inkscape
audacity
transmission-gtk
synaptic
menulibre
screenfetch
neofetch
EOF

# Development tools (enhanced)
cat > config/package-lists/dev.list.chroot << 'EOF'
git
build-essential
gcc
g++
make
cmake
automake
autoconf
pkg-config
python3
python3-pip
python3-venv
python3-dev
nodejs
npm
default-jdk
default-jre
golang-go
rustc
cargo
vim
vim-gtk3
nano
geany
geany-plugins
htop
btop
tree
curl
wget
net-tools
openssh-server
openssh-client
rsync
unzip
zip
p7zip-full
gdb
valgrind
strace
EOF

# Installer preseed - User prompts enabled
mkdir -p config/includes.installer
cat > config/includes.installer/preseed.cfg << 'EOF'
# Locale and keyboard
d-i debian-installer/locale string en_US.UTF-8
d-i localechooser/supported-locales multiselect en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us

# Network configuration
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string sasos
d-i netcfg/get_domain string local

# Mirror settings
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

# USER PROMPTS ENABLED - No preseed for user/password
# This ensures installer asks for username and password
d-i passwd/root-login boolean false
# Commented out to enable prompts:
# d-i passwd/user-fullname string 
# d-i passwd/username string 
# d-i passwd/user-password password 
# d-i passwd/user-password-again password 
d-i passwd/user-default-groups string audio cdrom video sudo netdev plugdev

# Clock and timezone
d-i clock-setup/utc boolean true
d-i time/zone string US/Eastern
d-i clock-setup/ntp boolean true

# Partitioning
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

# Package selection - Enhanced desktop
tasksel tasksel/first multiselect standard
d-i pkgsel/include string task-lxde-desktop openssh-server build-essential git
d-i pkgsel/upgrade select full-upgrade
popularity-contest popularity-contest/participate boolean false

# Bootloader
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string default

# Finish
d-i finish-install/reboot_in_progress note
EOF

# Download professional wallpaper
mkdir -p config/includes.chroot/usr/share/backgrounds/sasos
cat > config/hooks/normal/0050-download-wallpaper.hook.chroot << 'EOF'
#!/bin/bash
set -e

# Download high-quality wallpapers
cd /usr/share/backgrounds/sasos

# Primary wallpaper - Modern abstract tech design
wget -q -O default.jpg "https://images.unsplash.com/photo-1557683316-973673baf926?w=1920&h=1080&fit=crop" || \
wget -q -O default.jpg "https://wallpaperaccess.com/full/1567665.jpg" || \
convert -size 1920x1080 gradient:'#0f2027'-'#203a43'-'#2c5364' default.jpg

# Alternative wallpapers
wget -q -O space.jpg "https://images.unsplash.com/photo-1462331940025-496dfbfc7564?w=1920&h=1080&fit=crop" || true
wget -q -O mountain.jpg "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1920&h=1080&fit=crop" || true
wget -q -O nature.jpg "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=1920&h=1080&fit=crop" || true

# Fallback gradient if downloads fail
if [ ! -f default.jpg ]; then
    convert -size 1920x1080 gradient:'#0f2027'-'#203a43'-'#2c5364' \
        -gravity center \
        -pointsize 80 \
        -fill '#ffffff' \
        -font DejaVu-Sans-Bold \
        -annotate +0-50 'SAS OS' \
        -pointsize 30 \
        -annotate +0+50 'Development Environment' \
        default.jpg
fi

chmod 644 *.jpg
EOF
chmod +x config/hooks/normal/0050-download-wallpaper.hook.chroot

# System customization hook
mkdir -p config/hooks/normal
cat > config/hooks/normal/0100-customize.hook.chroot << 'EOF'
#!/bin/bash
set -e

# Hostname
echo "SAS" > /etc/hostname
echo "127.0.1.1 SAS" >> /etc/hosts

# Enhanced LXDE Panel Configuration
mkdir -p /etc/skel/.config/lxpanel/LXDE/panels
cat > /etc/skel/.config/lxpanel/LXDE/panels/panel << 'LXPANEL'
Global {
    edge=bottom
    allign=center
    margin=0
    widthtype=percent
    width=100
    height=32
    transparent=0
    tintcolor=#000000
    alpha=230
    autohide=0
    heightwhenhidden=2
    setdocktype=1
    setpartialstrut=1
    usefontcolor=1
    fontsize=10
    fontcolor=#ffffff
    usefontsize=0
    background=1
    backgroundfile=/usr/share/lxpanel/images/background.png
    iconsize=24
}

Plugin {
    type=menu
    Config {
        image=/usr/share/pixmaps/debian-logo.png
        system {
        }
        separator {
        }
        item {
            command=run
        }
        separator {
        }
        item {
            image=gnome-logout
            command=logout
        }
    }
}

Plugin {
    type=launchbar
    Config {
        Button {
            id=firefox-esr.desktop
        }
        Button {
            id=lxterminal.desktop
        }
        Button {
            id=pcmanfm.desktop
        }
        Button {
            id=gedit.desktop
        }
    }
}

Plugin {
    type=space
    Config {
        Size=4
    }
}

Plugin {
    type=pager
}

Plugin {
    type=space
    Config {
        Size=4
    }
}

Plugin {
    type=taskbar
    expand=1
    Config {
        tooltips=1
        IconsOnly=0
        ShowAllDesks=0
        UseMouseWheel=1
        UseUrgencyHint=1
        FlatButton=0
        MaxTaskWidth=200
        spacing=1
        GroupedTasks=0
    }
}

Plugin {
    type=cpu
}

Plugin {
    type=monitors
    Config {
        DisplayCPU=1
        DisplayRAM=1
        CPUColor=#0080FF
        RAMColor=#00FF00
    }
}

Plugin {
    type=tray
}

Plugin {
    type=volumealsa
}

Plugin {
    type=netstat
}

Plugin {
    type=dclock
    Config {
        ClockFmt=%I:%M %p
        TooltipFmt=%A %x
        BoldFont=1
        IconOnly=0
    }
}
LXPANEL

# PCManFM Desktop Configuration with wallpaper
mkdir -p /etc/skel/.config/pcmanfm/LXDE
cat > /etc/skel/.config/pcmanfm/LXDE/desktop-items-0.conf << 'PCMANFM'
[*]
wallpaper_mode=stretch
wallpaper_common=1
wallpaper=/usr/share/backgrounds/sasos/default.jpg
desktop_bg=#1a1a1a
desktop_fg=#ffffff
desktop_shadow=#000000
show_wm_menu=1
show_documents=0
show_trash=1
show_mounts=1
PCMANFM

# GTK Theme Configuration
mkdir -p /etc/skel/.config/gtk-3.0
cat > /etc/skel/.config/gtk-3.0/settings.ini << 'GTK3'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Ubuntu 10
gtk-cursor-theme-name=Breeze_Snow
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
gtk-xft-rgba=rgb
GTK3

# GTK2 Configuration
cat > /etc/skel/.gtkrc-2.0 << 'GTK2'
gtk-theme-name="Arc-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Ubuntu 10"
gtk-cursor-theme-name="Breeze_Snow"
gtk-cursor-theme-size=24
GTK2

# Openbox configuration for better window management
mkdir -p /etc/skel/.config/openbox
cat > /etc/skel/.config/openbox/lxde-rc.xml << 'OPENBOX'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <theme>
    <name>Arc-Dark</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>yes</keepBorder>
    <animateIconify>yes</animateIconify>
  </theme>
  <desktops>
    <number>4</number>
    <firstdesk>1</firstdesk>
    <names>
      <name>Desktop 1</name>
      <name>Desktop 2</name>
      <name>Desktop 3</name>
      <name>Desktop 4</name>
    </names>
  </desktops>
</openbox_config>
OPENBOX

# LXAppearance config
mkdir -p /etc/skel/.config/lxsession/LXDE
cat > /etc/skel/.config/lxsession/LXDE/desktop.conf << 'LXSESSION'
[GTK]
sNet/ThemeName=Arc-Dark
sNet/IconThemeName=Papirus-Dark
sGtk/FontName=Ubuntu 10
sGtk/CursorThemeName=Breeze_Snow
iGtk/ToolbarStyle=3
iGtk/ButtonImages=1
iGtk/MenuImages=1
iGtk/CursorThemeSize=24
iXft/Antialias=1
iXft/Hinting=1
sXft/HintStyle=hintfull
sXft/RGBA=rgb

[Core]
Wallpaper=/usr/share/backgrounds/sasos/default.jpg
LXSESSION

# Create desktop shortcuts
mkdir -p /etc/skel/Desktop

cat > /etc/skel/Desktop/Terminal.desktop << 'TERMINAL'
[Desktop Entry]
Type=Application
Name=Terminal
Comment=Use the command line
Icon=utilities-terminal
Exec=lxterminal
Categories=System;TerminalEmulator;
TERMINAL

cat > /etc/skel/Desktop/Firefox.desktop << 'FIREFOX'
[Desktop Entry]
Type=Application
Name=Firefox
Comment=Web Browser
Icon=firefox-esr
Exec=firefox-esr
Categories=Network;WebBrowser;
FIREFOX

cat > /etc/skel/Desktop/Files.desktop << 'FILES'
[Desktop Entry]
Type=Application
Name=Files
Comment=File Manager
Icon=system-file-manager
Exec=pcmanfm
Categories=System;FileManager;
FILES

cat > /etc/skel/Desktop/Wallpaper.desktop << 'WALLPAPER'
[Desktop Entry]
Type=Application
Name=Change Wallpaper
Comment=Select desktop wallpaper
Icon=preferences-desktop-wallpaper
Exec=nitrogen /usr/share/backgrounds/sasos
Categories=Settings;DesktopSettings;
WALLPAPER

chmod +x /etc/skel/Desktop/*.desktop

# Welcome document
cat > /etc/skel/Desktop/Welcome.txt << 'WELCOME'
Welcome to SAS OS!
==================

System Requirements:
- CPU: 5th Gen Intel or equivalent
- RAM: 2-4 GB
- Storage: 25 GB
- Architecture: 64-bit

Your Installation:
- Username: [Your chosen username]
- Change wallpaper: Click "Change Wallpaper" icon
- Installed themes: Arc-Dark, Papirus icons

Development Tools Installed:
✓ Python 3, Node.js, Java, Go, Rust
✓ GCC/G++, Make, CMake
✓ Git, SSH, Build tools
✓ Geany IDE, Vim, VS Code compatible

Applications:
✓ Firefox & Chromium browsers
✓ LibreOffice suite
✓ GIMP, Inkscape (graphics)
✓ VLC media player
✓ Audacity (audio editor)

Quick Tips:
- Right-click desktop for menu
- Use Nitrogen to change wallpaper
- LXAppearance for theme customization
- MenuLibre for menu editing

Enjoy your new system!
WELCOME

# Locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# Performance tuning for modern systems
cat > /etc/sysctl.d/99-performance.conf << 'SYSCTL'
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=10
vm.vfs_cache_pressure=50
SYSCTL

# Clean
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF
chmod +x config/hooks/normal/0100-customize.hook.chroot

# Minimal boot menu - Install only
mkdir -p config/bootloaders/isolinux
cat > config/bootloaders/isolinux/isolinux.cfg << 'EOF'
default install
timeout 30
prompt 1

say 
say ==========================================
say        SAS OS Installer
say ==========================================
say 
say   Press ENTER to install SAS OS
say   Starting installation in 3 seconds...
say 

label install
    kernel /install/gtk/vmlinuz
    append initrd=/install/gtk/initrd.gz priority=critical

label installtext
    kernel /install/vmlinuz
    append initrd=/install/initrd.gz priority=critical
EOF

# GRUB for UEFI
mkdir -p config/bootloaders/grub-pc
cat > config/bootloaders/grub-pc/grub.cfg << 'EOF'
set default=0
set timeout=3
set menu_color_normal=white/black
set menu_color_highlight=black/white

menuentry "Install SAS OS" {
    linux /install/vmlinuz priority=critical
    initrd /install/initrd.gz
}

menuentry "Install SAS OS (Graphical)" {
    linux /install/gtk/vmlinuz priority=critical
    initrd /install/gtk/initrd.gz
}

menuentry "Install SAS OS (Text Mode)" {
    linux /install/vmlinuz priority=critical
    initrd /install/initrd.gz
}
EOF

if ! lb build 2>&1 | tee build.log; then
    echo "Build failed. Check: $WORK_DIR/build.log"
    exit 1
fi

# Find the ISO file (it might have different names)
ISO_FILE=$(ls -1 *.iso 2>/dev/null | head -n1)

if [ -n "$ISO_FILE" ]; then
    mv "$ISO_FILE" SAS.iso
    echo "$WORK_DIR/SAS.iso"
else
    echo "Build failed: ISO not created"
    ls -lh "$WORK_DIR/" | grep -i iso || true
    exit 1
fi

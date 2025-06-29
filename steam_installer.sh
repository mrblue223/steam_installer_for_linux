#!/bin/bash

# This script automates the installation of Steam on various Linux distributions.
# It attempts to detect your distribution and use the appropriate package manager.
# This enhanced version includes more robust error handling and verification steps.

# IMPORTANT DISCLAIMER:
# While Steam works well on Linux, the gaming experience can vary significantly
# depending on your distribution, graphics drivers, and hardware. For optimal
# gaming performance and stability, ensure your system's graphics drivers are
# properly installed and up-to-date.
# If you are using Kali Linux, please remember it is a specialized distribution
# for penetration testing and security. It is generally NOT recommended for
# gaming or as a daily driver due to its unique configurations, security focus,
# and potential for instability with general desktop applications and games.
# For a smoother gaming experience, consider distributions like Ubuntu, Pop!_OS,
# Fedora, or Manjaro.

# --- Script Configuration ---
# You generally shouldn't need to change these.
STEAM_DEB_URL="https://repo.steampowered.com/steam/archive/stable/steam_latest.deb"
MAX_RETRIES=3
RETRY_DELAY=5 # seconds

# --- Functions ---

# Function to check for root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root or with sudo."
        echo "Please use: sudo ./install_steam.sh"
        exit 1
    fi
}

# Function to display messages
log_info() {
    echo -e "\n\033[1;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\n\033[1;32m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\n\033[1;33m[WARNING]\033[0m $1"
}

log_error() {
    echo -e "\n\033[1;31m[ERROR]\033[0m $1"
    exit 1
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif type lsb_release >/dev/null 2>&1; then
        lsb_release -is
    elif [ -f /etc/redhat-release ]; then
        cat /etc/redhat-release | awk '{print $1}'
    else
        echo "Unknown"
    fi
}

# Function to run commands with retries
run_with_retries() {
    local cmd="$@"
    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        log_info "Attempt $attempt/$MAX_RETRIES: Running command: $cmd"
        if eval "$cmd"; then
            return 0 # Success
        else
            log_warning "Command failed. Retrying in $RETRY_DELAY seconds..."
            sleep "$RETRY_DELAY"
            attempt=$((attempt + 1))
        fi
    done
    return 1 # Failure after all retries
}


# --- Main Script Logic ---

log_info "Starting Universal Steam installation script for Linux."
check_root

DISTRO=$(detect_distro | tr '[:upper:]' '[:lower:]')
log_info "Detected Distribution: ${DISTRO}"

case "${DISTRO}" in
    debian|ubuntu|kali|linuxmint|pop|raspbian)
        log_info "Running installation for Debian-based distribution (${DISTRO})..."

        # Check for apt command
        if ! type apt >/dev/null 2>&1; then
            log_error "apt command not found. This script requires APT for Debian-based systems. Aborting."
        fi

        # Enable i386 architecture
        log_info "Adding i386 architecture support..."
        if ! dpkg --add-architecture i386; then
            log_error "Failed to add i386 architecture. Check your system's dpkg configuration. Aborting."
        fi
        log_success "i386 architecture added."

        # Update package lists
        log_info "Updating package lists (apt update)..."
        if ! run_with_retries "apt update"; then
            log_error "Failed to update apt package lists after multiple retries. Check your internet connection or /etc/apt/sources.list. Aborting."
        fi
        log_success "Package lists updated."

        # Install Steam client and core dependencies
        log_info "Attempting to install 'steam' package from repositories..."
        if ! run_with_retries "apt install -y steam"; then
            log_warning "Failed to install 'steam' package via apt repositories. Attempting direct .deb download as fallback."

            # Ensure wget is installed for .deb download fallback
            if ! type wget >/dev/null 2>&1; then
                log_info "wget not found. Installing wget..."
                if ! run_with_retries "apt install -y wget"; then
                    log_error "Failed to install wget. Cannot proceed with .deb download fallback. Aborting."
                fi
            fi

            log_info "Downloading Steam .deb package from ${STEAM_DEB_URL}..."
            if ! run_with_retries "wget -O /tmp/steam_latest.deb \"${STEAM_DEB_URL}\""; then
                log_error "Failed to download Steam .deb package after multiple retries. Check URL or internet connection. Aborting."
            fi
            log_info "Installing downloaded Steam .deb package..."
            if ! dpkg -i /tmp/steam_latest.deb; then
                log_warning "dpkg installation of Steam .deb failed. This usually means missing dependencies. Attempting to fix."
                log_info "Running apt --fix-broken install to resolve dependencies..."
                if ! run_with_retries "apt --fix-broken install -y"; then
                    log_error "Failed to fix broken dependencies after multiple retries. Please try manually: 'sudo apt --fix-broken install'. Aborting."
                fi
                log_success "Broken dependencies resolved (or attempted)."
                # Retry dpkg after fixing broken dependencies, in case it was stuck
                log_info "Retrying dpkg install after fixing broken dependencies..."
                if ! dpkg -i /tmp/steam_latest.deb; then
                    log_error "Steam .deb package installation failed again. Manual intervention may be required. Aborting."
                fi
            fi
            log_success "Steam .deb package installed successfully (or attempted fix)."
        else
            log_success "Steam client (steam-launcher) installed via apt repositories."
        fi

        # Install crucial 32-bit graphics and DRM libraries
        log_info "Installing essential 32-bit graphics and DRM libraries (libgl1:i386 libdrm2:i386)..."
        if ! run_with_retries "apt install -y libgl1:i386 libdrm2:i386"; then
            log_error "Failed to install crucial 32-bit graphics/DRM libraries after multiple retries. This will likely prevent Steam from launching correctly. Aborting."
        fi
        log_success "Essential 32-bit libraries installed."

        # Install recommended additional libraries for better compatibility/performance
        log_info "Installing recommended additional libraries for gaming (mesa-utils libvulkan1 libvulkan1:i386)..."
        if ! run_with_retries "apt install -y mesa-utils libvulkan1 libvulkan1:i386"; then
            log_warning "Could not install all recommended libraries after multiple retries. This is not critical, but some games might benefit from them. Continuing..."
        else
            log_success "Recommended additional libraries installed."
        fi

        # Final check for broken installations (just in case)
        log_info "Running final dependency check and fixing any broken installations..."
        if ! run_with_retries "apt --fix-broken install -y"; then
            log_error "Final dependency fix failed after multiple retries. Your system might have unresolved package issues. Aborting."
        fi
        log_success "Final dependency check completed."
        ;;

    fedora|centos|rhel)
        log_info "Running installation for RPM-based distribution (${DISTRO})..."

        # Check for dnf command
        if ! type dnf >/dev/null 2>&1; then
            log_error "dnf command not found. This script requires DNF for RPM-based systems. Aborting."
        fi

        # Add RPM Fusion non-free repository (where Steam usually resides)
        log_info "Adding RPM Fusion non-free repository..."
        if ! run_with_retries "dnf install -y \"https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm\""; then
            log_error "Failed to add RPM Fusion non-free repository after multiple retries. This is crucial for Steam. Aborting."
        fi
        log_success "RPM Fusion non-free repository added."

        # Update package lists (full update recommended here)
        log_info "Updating system packages (dnf update --refresh)... This may take some time."
        if ! run_with_retries "dnf update --refresh -y"; then
            log_warning "DNF update encountered issues. Continuing, but a manual 'sudo dnf update' might be needed."
        fi
        log_success "System packages updated."

        # Install Steam and 32-bit libraries
        log_info "Installing Steam and 32-bit libraries via dnf..."
        # Package names for 32-bit compatibility and Steam on Fedora
        # libglvnd-glx.i686 for libGL.so.1, libdrm.i686 for libdrm.so.2
        if ! run_with_retries "dnf install -y steam.x86_64 steam.i686 libglvnd-glx.i686 libdrm.i686 mesa-vulkan-drivers.i686"; then
            log_error "Failed to install Steam or required 32-bit libraries via dnf after multiple retries. Manual intervention may be required. Aborting."
        fi
        log_success "Steam and essential 32-bit libraries installed."

        # Additional recommended libraries
        log_info "Installing recommended additional libraries for gaming (mesa-utils vulkan-tools)..."
        if ! run_with_retries "dnf install -y mesa-utils vulkan-tools"; then
            log_warning "Could not install all recommended libraries after multiple retries. This is not critical. Continuing..."
        else
            log_success "Recommended additional libraries installed."
        fi
        ;;

    arch|manjaro|endeavouros)
        log_info "Running installation for Arch-based distribution (${DISTRO})..."

        # Check for pacman command
        if ! type pacman >/dev/null 2>&1; then
            log_error "pacman command not found. This script requires pacman for Arch-based systems. Aborting."
        fi

        # Enable multilib repository
        log_info "Ensuring 'multilib' repository is enabled in /etc/pacman.conf..."
        # Check if multilib is commented out
        MULTILIB_COMMENTED=$(grep -Pzo '^#\[multilib\]\n#Include = /etc/pacman.d/mirrorlist' /etc/pacman.conf | wc -l)
        if [ "$MULTILIB_COMMENTED" -gt 0 ]; then
            log_warning "Multilib repository appears to be commented out in /etc/pacman.conf."
            log_info "Attempting to uncomment [multilib] and its Include line..."
            sudo sed -i '/^#\[multilib\]/{N;s/^#\[multilib\]\n#Include = \/etc\/pacman.d\/mirrorlist/\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist/}' /etc/pacman.conf
            if ! grep -q "^\[multilib\]" /etc/pacman.conf || grep -q "^Include = /etc/pacman.d/mirrorlist" /etc/pacman.conf | grep -q "^#" -A 1 | grep -q "\[multilib\]"; then
                log_error "Failed to automatically uncomment multilib. Please manually uncomment [multilib] and its Include line in /etc/pacman.conf and then re-run the script. Aborting."
            fi
            log_success "Multilib repository enabled (or confirmed)."
        else
            log_success "Multilib repository appears to be already enabled."
        fi

        # Update package lists
        log_info "Updating package lists (pacman -Sy)..."
        if ! run_with_retries "pacman -Sy --noconfirm"; then
            log_error "Failed to update pacman package lists after multiple retries. Check your internet connection or /etc/pacman.conf. Ensure multilib is correctly enabled. Aborting."
        fi
        log_success "Package lists updated."

        # Install Steam and 32-bit libraries
        log_info "Installing Steam and 32-bit libraries via pacman..."
        # 'steam' meta-package and common 32-bit graphics dependencies for Arch
        if ! run_with_retries "pacman -S --noconfirm steam lib32-mesa lib32-libdrm lib32-vulkan-intel lib32-vulkan-radeon"; then
            log_error "Failed to install Steam or required 32-bit libraries via pacman after multiple retries. Manual intervention may be required. Aborting."
        fi
        log_success "Steam and essential 32-bit libraries installed."

        # Additional recommended libraries
        log_info "Installing recommended additional libraries for gaming (mesa-utils vulkan-tools)..."
        if ! run_with_retries "pacman -S --noconfirm mesa-utils vulkan-tools"; then
            log_warning "Could not install all recommended libraries after multiple retries. This is not critical. Continuing..."
        else
            log_success "Recommended additional libraries installed."
        fi
        ;;

    *)
        log_error "Unsupported distribution: ${DISTRO}. This script currently supports Debian/Ubuntu, Fedora/RHEL, and Arch-based distributions. Please install Steam manually or adapt the script for your specific distro. Aborting."
        ;;
esac

# Final cleanup and verification
log_info "Killing any lingering Steam processes to ensure a clean launch..."
sudo killall steam steamwebhelper 2>/dev/null || true # Suppress "no process found" errors

log_info "Verifying Steam executable exists..."
if ! type steam >/dev/null 2>&1; then
    log_error "Steam executable not found in PATH after installation. This indicates a critical failure. Aborting."
else
    log_success "Steam executable found."
fi

log_success "Steam installation process completed!"

echo -e "\n------------------------------------------------------------"
echo "You can now launch Steam from your applications menu or by typing 'steam' in the terminal."
echo "The first time you launch it, Steam will download its latest client files."
echo "If Steam does not launch or encounters errors, ensure your graphics drivers are properly installed and up-to-date."
echo "------------------------------------------------------------\n"

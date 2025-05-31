#!/bin/bash

FLATPAKS=(
  com.spotify.Client
  com.rustdesk.RustDesk
  com.protonvpn.www
  it.mijorus.gearlever
  com.mattjakeman.ExtensionManager
  us.zoom.Zoom
  com.github.tchx84.Flatseal
  com.discordapp.Discord
  app.openbubbles.OpenBubbles
)

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "${SCRIPT_DIR}/../utils.sh" ]; then
  print_info "error: utils.sh not found!"
  exit 1
fi

source "${SCRIPT_DIR}/../utils.sh"

function install_neovim_deps {
  sudo gem install ruby
  cpan
  sudo cpan install Neovim::Ext
}

function enable_multilib {
  local pacmanconf="/etc/pacman.conf"

  if [[ $(uname -m) = "x86_64" ]]; then
    sudo sed -i \
      -e "s/^#\[multilib\]$/\[multilib\]/g" \
      -e "/^\[multilib\]$/{n;s/^#Include = /Include = /}" "${pacmanconf}"
    sudo pacman -Sy
  else
    print_info "Multilib not applicable for 32-bit installations. Skipping."
    print_info "Arch discontinued 32-bit support in early 2017. Consider upgrading to a 64-bit."
  fi
}

function configure_flatpak {
  sudo pacman -S flatpak
  sudo flatpak override --system --nosocket=x11 --nosocket=fallback-x11 --nosocket=pulseaudio --nosocket=session-bus --nosocket=system-bus --unshare=network --unshare=ipc --nofilesystem=host:reset --nodevice=input --nodevice=shm --nodevice=all --no-talk-name=org.freedesktop.Flatpak --no-talk-name=org.freedesktop.systemd1 --no-talk-name=ca.desrt.dconf --no-talk-name=org.gnome.Shell.Extensions
  flatpak override --user --nosocket=x11 --nosocket=fallback-x11 --nosocket=pulseaudio --nosocket=session-bus --nosocket=system-bus --unshare=network --unshare=ipc --nofilesystem=host:reset --nodevice=input --nodevice=shm --nodevice=all --no-talk-name=org.freedesktop.Flatpak --no-talk-name=org.freedesktop.systemd1 --no-talk-name=ca.desrt.dconf --no-talk-name=org.gnome.Shell.Extensions
  flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  flatpak update

  for pak in "${FLATPAKS[@]}"; do
    if ! flatpak list | grep -i "$pak" &>/dev/null; then
      print_info "installing flatpak: $pak"
      flatpak install --noninteractive --user flathub "$pak"
    else
      echo "Flatpak already installed: $pak"
    fi
  done
}

function enable_services {
  sudo systemctl enable firewalld --now && sudo systemctl start firewalld
  sudo systemctl enable reflector.timer --now && sudo systemctl start reflector.timer
  sudo systemctl enable NetworkManager --now && sudo systemctl start NetworkManager
  sudo systemctl enable systemd-networkd --now && sudo systemctl start systemd-networkd
  # sudo systemctl enable bluetooth.service --now && sudo systemctl start bluetooth.service
  # sudo systemctl enable sshd --now && sudo systemctl start sshd
}

function install_tpm {
  TPM_DIR="${ACTUAL_HOME}.tmux/plugins/tpm"

  if [ -d "$TPM_DIR" ]; then
    echo "TPM is already installed in $TPM_DIR"
  else
    echo "Installing Tmux Plugin Manager (TPM)..."
    git clone https://github.com/tmux-plugins/tpm $TPM_DIR
  fi
}

function install_kvm {
  local libvirtlocaldir="${ACTUAL_HOME}/.local/libvirt"
  local nsconf="/etc/nsswitch.conf"
  local libvirtnetworkconf="/etc/libvirt/network.conf"

  print_info "Adding $(whoami) to libvirt group."
  sudo usermod -aG libvirt "$(whoami)"

  print_info "Creating local libvirt directories."
  mkdir -p "${libvirtlocaldir}"/{images,share}
  sudo chown "${ACTUAL_USER}":libvirt-qemu "${libvirtlocaldir}/images"

  if [ -f "${nsconf}" ] && ! grep -q "^hosts: .*libvirt" "${nsconf}"; then
    print_info "Enabling access to VMs on un-isolated bridge network."
    sudo sed -i "/^hosts/{s/files/files libvirt libvirt_guest/g}" "${nsconf}"
  fi

  print_info "Setting libvirt to use iptables (for UFW compatibility)."
  sudo sed -i 's/^#\?firewall_backend = "nftables"/firewall_backend = "iptables"/g' "${libvirtnetworkconf}"

  sudo systemctl enable libvirtd
  sudo systemctl start libvirtd
}

# print_info "installing kvm"
# install_kvm

print_info "configuring multilib"
enable_multilib

print_info "enabling services"
enable_services

print_info "configuring flatpak"
configure_flatpak

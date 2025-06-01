#!/bin/bash

function install_network {
  local nmconf="/etc/NetworkManager/NetworkManager.conf"
  local nmrandomconf="/etc/NetworkManager/conf.d/randomize_mac_address.conf"

  if ! find "${nmconf}" /etc/NetworkManager/conf.d/ -type f -exec grep -q "mac-address=random" {} +; then;
    sudo tee -a "${nmrandomconf}" >/dev/null <<EOF
[connection-mac-randomization]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF
  fi

  sudo systemctl enable --now NetworkManager

  sudo sed -i \
    -e "/^#PermitRootLogin prohibit-password$/a PermitRootLogin no" \
    -e "/^#Port 22$/i Protocol 2" \
    /etc/ssh/sshd_config
}

function install_discovery {
  local nsconf="/etc/nsswitch.conf"

  if [ -f "${nsconf}" ]; then
    if ! grep -q "^hosts: .*mdns_minimal" "${nsconf}"; then
      sudo sed -i "/^hosts:/{s/myhostname/myhostname mdns_minimal \[NOTFOUND=return\]/g}" ${nsconf};
    else
      echo "Local hostname resolution already set."
    fi
  else
    echo "${nsconf@Q} missing. Skipping."
    return
  fi
  sudo systemctl enable avahi-daemon.service
  sudo systemctl start avahi-daemon.service
}

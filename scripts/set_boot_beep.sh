#!/bin/bash

set -e

# Function to enable beep at startup (systemd service)
enable_beep_systemd() {
  sudo tee /etc/systemd/system/startup-beep.service > /dev/null <<EOF
[Unit]
Description=Beep at startup

[Service]
Type=oneshot
ExecStart=/bin/echo -e '\\a'

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl enable startup-beep.service
}

# Function to enable beep at startup (rc.local fallback)
enable_beep_rc_local() {
  if [ -f /etc/rc.local ]; then
    sudo sed -i '/exit 0/i echo -e "\\a"' /etc/rc.local
  else
    echo -e '#!/bin/bash\necho -e "\\a"\nexit 0' | sudo tee /etc/rc.local
    sudo chmod +x /etc/rc.local
  fi
}

# Detect bootloader
if [ -d /sys/firmware/efi/efivars ] && [ -d /boot/loader ]; then
  # systemd-boot
  echo "Detected systemd-boot."
  sudo sed -i 's/^timeout.*/timeout 0/' /boot/loader/loader.conf || echo "timeout 0" | sudo tee -a /boot/loader/loader.conf
  enable_beep_systemd
elif grep -qi grub /proc/cmdline || [ -f /etc/default/grub ]; then
  # GRUB
  echo "Detected GRUB."
  sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
  sudo update-grub
  enable_beep_systemd
else
  echo "Bootloader not detected. Applying beep to rc.local."
  enable_beep_rc_local
fi

echo "Done."
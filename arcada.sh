#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Author: ChatGPT für PVE Community Scripts
# Description: Erstellt einen LXC-Container mit Arcada (virtuelle Raumplanung) auf Port 3000

set -euo pipefail

# ----- Konfiguration -----
CTID=${CTID:-8001}
HOSTNAME=${HOSTNAME:-arcada}
DISK_SIZE=${DISK_SIZE:-4}   # GB
RAM_SIZE=${RAM_SIZE:-1024}  # MB
BRIDGE=${BRIDGE:-vmbr0}
GATEWAY=${GATEWAY:-}
IP=${IP:-dhcp}
PASSWORD=${PASSWORD:-arcada123}
IMG_URL="https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64-lxd.tar.xz"

# ----- Funktionen -----
function msg() {
  local message="${1:-}"
  echo -e "\e[1;32m==> $message\e[0m"
}

# ----- Container erstellen -----
msg "LXC-Container $CTID wird erstellt..."
pct create $CTID local:vztmpl/$(basename $IMG_URL) \
  -hostname $HOSTNAME \
  -net0 name=eth0,bridge=$BRIDGE,ip=$IP,gw=$GATEWAY \
  -cores 2 \
  -memory $RAM_SIZE \
  -rootfs local-lvm:$DISK_SIZE \
  -password $PASSWORD \
  -features nesting=1 \
  -unprivileged 1

# ----- Container starten -----
msg "Starte LXC-Container $CTID..."
pct start $CTID
sleep 5

# ----- Arcada installieren -----
msg "Installiere Arcada im Container $CTID..."

pct exec $CTID -- bash -c "
apt update && apt install -y curl git build-essential
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
git clone https://github.com/mehanix/arcada.git /opt/arcada
cd /opt/arcada
npm install
npm run build
npm install -g serve
cat <<EOF > /opt/arcada/start.sh
#!/bin/bash
npx serve -s build -l 3000
EOF
chmod +x /opt/arcada/start.sh
"

# ----- Autostart konfigurieren -----
msg "Aktiviere Autostart von Arcada..."

pct exec $CTID -- bash -c "
npm install -g pm2
pm2 start /opt/arcada/start.sh --name arcada
pm2 save
pm2 startup | grep sudo | bash
"

# ----- Abschluss -----
msg "✅ Arcada ist bereit!"
IP_ADDR=$(pct exec $CTID -- hostname -I | awk '{print $1}')
echo -e "\n🌐 Öffne http://$IP_ADDR:3000 im Browser."
echo -e "🔐 Standard-Passwort für root im Container: $PASSWORD"

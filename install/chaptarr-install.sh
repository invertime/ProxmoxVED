#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: invertime
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/Chaptarr/chaptarr

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  ffmpeg \
  git \
  sqlite3
msg_ok "Installed Dependencies"

NODE_VERSION="22" setup_nodejs
$STD npm install -g yarn

msg_info "Installing .NET 10 SDK"
wget -q https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
chmod +x dotnet-install.sh
$STD ./dotnet-install.sh --channel 10.0 --install-dir /usr/share/dotnet
ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
rm -f dotnet-install.sh
msg_ok "Installed .NET 10 SDK"

msg_info "Building Chaptarr from source"
temp_dir=$(mktemp -d)
$STD git clone https://github.com/Chaptarr/chaptarr.git "$temp_dir"
cd "$temp_dir"

$STD dotnet publish src/NzbDrone.Console/Chaptarr.Console.csproj -c Release -f net10.0 -o /opt/chaptarr
$STD yarn install
$STD yarn build
cp -r _output/UI /opt/chaptarr/UI

rm -rf "$temp_dir"
msg_ok "Built Chaptarr"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/chaptarr.service
[Unit]
Description=Chaptarr Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/chaptarr
ExecStart=/usr/bin/dotnet /opt/chaptarr/Chaptarr.dll -nobrowser -data=/var/lib/chaptarr
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /var/lib/chaptarr
systemctl enable -q --now chaptarr
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc

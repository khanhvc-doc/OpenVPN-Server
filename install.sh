#!/bin/bash
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

[ "$EUID" -ne 0 ] && error "Run as root: sudo bash install.sh"

CODENAME=$(lsb_release -sc 2>/dev/null)
OS=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
[ "$OS" != "ubuntu" ] && error "Ubuntu only. Detected: $OS"

info "Updating packages..."
apt update -qq && apt install -y -qq ca-certificates wget gnupg ufw curl

info "Importing OpenVPN repo key..."
wget -qO - https://as-repository.openvpn.net/as-repo-public.gpg \
  | gpg --dearmor -o /usr/share/keyrings/openvpn.gpg

info "Adding OpenVPN repo (${CODENAME})..."
echo "deb [signed-by=/usr/share/keyrings/openvpn.gpg] http://as-repository.openvpn.net/as/debian ${CODENAME} main" \
  | tee /etc/apt/sources.list.d/openvpn-as-repo.list > /dev/null

apt update -qq

info "Installing openvpn-as..."
apt install -y -qq openvpn-as

info "Configuring firewall..."
ufw allow 22/tcp   > /dev/null 2>&1
ufw allow 443/tcp  > /dev/null 2>&1
ufw allow 943/tcp  > /dev/null 2>&1
ufw allow 1194/udp > /dev/null 2>&1
ufw allow 1194/tcp > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
info "Ports opened: 22, 443, 943, 1194 (tcp/udp)"

info "Setting admin password..."
ADMIN_PASS="openVpn@123"
/usr/local/openvpn_as/scripts/sacli --user openvpn --new_pass "$ADMIN_PASS" SetLocalPassword > /dev/null 2>&1
info "Password set to: $ADMIN_PASS"

# Optional extra config
CONFIG_URL="https://raw.githubusercontent.com/khanhvc-doc/OpenVPN-Server/master/config.sh"
if curl -sfI "$CONFIG_URL" > /dev/null 2>&1; then
  info "Running config.sh..."
  bash <(curl -s "$CONFIG_URL")
fi

# Collect info
LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me || echo "N/A")

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   OpenVPN Access Server installed OK${NC}"
echo -e "${GREEN}============================================${NC}"
printf "  %-12s: %b%s%b\n" "Local IP"  "$YELLOW" "$LOCAL_IP"  "$NC"
printf "  %-12s: %b%s%b\n" "Public IP" "$YELLOW" "$PUBLIC_IP" "$NC"
printf "  %-12s: %b%s%b\n" "Admin UI"  "$GREEN"  "https://${PUBLIC_IP}:943/admin" "$NC"
printf "  %-12s: %b%s%b\n" "Client UI" "$GREEN"  "https://${PUBLIC_IP}:943"       "$NC"
printf "  %-12s: %b%s%b\n" "Username"  "$YELLOW" "openvpn" "$NC"
printf "  %-12s: %b%s%b\n" "Password"  "$YELLOW" "$ADMIN_PASS" "$NC"
echo -e "${GREEN}============================================${NC}"
echo ""
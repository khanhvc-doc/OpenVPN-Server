#!/bin/bash
# config.sh - Post-install configuration for OpenVPN AS
# Called automatically by install.sh, or run manually: sudo bash config.sh

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

[ "$EUID" -ne 0 ] && error "Run as root."
command -v sacli > /dev/null 2>&1 || error "sacli not found. Is openvpn-as installed?"

SACLI=/usr/local/openvpn_as/scripts/sacli

# ── Configurable variables ────────────────────────────────────────────────────
VPN_NETWORK="10.8.0.0"
VPN_NETMASK="255.255.255.0"
MAX_CLIENTS=10
ADMIN_UI_PORT=943
VPND_PORT=1194
# ─────────────────────────────────────────────────────────────────────────────

info "Applying OpenVPN AS settings..."

$SACLI --key "vpn.daemon.0.listen.protocol" --value "tcp"  ConfigPut
$SACLI --key "vpn.daemon.0.listen.port"     --value "$VPND_PORT" ConfigPut
$SACLI --key "vpn.server.port_share.enable" --value "true" ConfigPut

$SACLI --key "vpn.server.routing.private_network.0" \
       --value "${VPN_NETWORK}/${VPN_NETMASK}" ConfigPut

$SACLI --key "vpn.client.routing.reroute_gw" --value "true"  ConfigPut  # route all traffic
$SACLI --key "vpn.client.routing.reroute_dns" --value "true" ConfigPut

$SACLI --key "cs.max_clients_per_user" --value "$MAX_CLIENTS" ConfigPut

info "Restarting OpenVPN AS..."
$SACLI start > /dev/null 2>&1 || service openvpnas restart > /dev/null 2>&1

info "config.sh done."
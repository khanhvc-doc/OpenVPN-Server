#!/bin/bash
# ============================================================
#  Fix UFW for OpenVPN AS — không cần tắt firewall
#  NAT covers full RFC 1918: 10/8, 172.16/12, 192.168/16
# ============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
section() { echo -e "\n${CYAN}${BOLD}==> $1${NC}"; }

[ "$EUID" -ne 0 ] && { echo "Run as root"; exit 1; }

# ── Step 1: Mở port ──────────────────────────────────────────
section "Opening required ports"
ufw allow 22/tcp   comment 'SSH'           > /dev/null
ufw allow 443/tcp  comment 'OpenVPN HTTPS' > /dev/null
ufw allow 943/tcp  comment 'OpenVPN Admin' > /dev/null
ufw allow 1194/tcp comment 'OpenVPN TCP'   > /dev/null
ufw allow 1194/udp comment 'OpenVPN UDP'   > /dev/null
info "Ports: 22, 443, 943, 1194 (tcp/udp)"

# ── Step 2: IP Forwarding ────────────────────────────────────
section "Enabling IP forwarding"
sysctl -w net.ipv4.ip_forward=1          > /dev/null
sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null

cat > /etc/sysctl.d/99-openvpn.conf << 'SYSEOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
SYSEOF
sysctl -p /etc/sysctl.d/99-openvpn.conf > /dev/null
info "IP forwarding enabled (persistent)."

# ── Step 3: UFW forward policy ───────────────────────────────
section "Setting UFW DEFAULT_FORWARD_POLICY=ACCEPT"
sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
info "Done."

# ── Step 4: NAT masquerade — full RFC 1918 ───────────────────
section "Adding NAT masquerade (RFC 1918)"

IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -1)
[ -z "$IFACE" ] && IFACE="eth0"
info "Outbound interface: $IFACE"

UFW_BEFORE="/etc/ufw/before.rules"

if grep -q "OPENVPN NAT" "$UFW_BEFORE" 2>/dev/null; then
  warn "NAT rules already present — skipping."
else
  cp "$UFW_BEFORE" "${UFW_BEFORE}.bak"
  info "Backup: ${UFW_BEFORE}.bak"

  # RFC 1918:
  #   10.0.0.0/8     — Class A private
  #   172.16.0.0/12  — Class B private (172.16.x.x ~ 172.31.x.x)
  #   192.168.0.0/16 — Class C private
  NAT_BLOCK="# OPENVPN NAT — RFC 1918
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.0.0.0/8      -o ${IFACE} -j MASQUERADE
-A POSTROUTING -s 172.16.0.0/12   -o ${IFACE} -j MASQUERADE
-A POSTROUTING -s 192.168.0.0/16  -o ${IFACE} -j MASQUERADE
COMMIT

"
  # Chèn trước *filter
  python3 - "$UFW_BEFORE" "$NAT_BLOCK" << 'PYEOF'
import sys
path  = sys.argv[1]
block = sys.argv[2]
with open(path, 'r') as f:
    content = f.read()
if '*filter' in content and 'OPENVPN NAT' not in content:
    content = content.replace('*filter', block + '*filter', 1)
with open(path, 'w') as f:
    f.write(content)
print("NAT block inserted.")
PYEOF

  info "NAT rules added for: 10/8, 172.16/12, 192.168/16 via $IFACE"
fi

# ── Step 5: Reload UFW ───────────────────────────────────────
section "Reloading UFW"
ufw --force enable > /dev/null
ufw reload         > /dev/null
info "UFW reloaded."

# ── Summary ──────────────────────────────────────────────────
echo ""
ufw status numbered
echo ""
echo "  IP forward : $(sysctl -n net.ipv4.ip_forward)"
echo "  Interface  : $IFACE"
echo ""
echo -e "${GREEN}[✓] Done. OpenVPN works without disabling UFW.${NC}"
echo ""
#!/bin/bash
# ============================================================
#  OpenVPN AS - Patch: compile uprop.py -> uprop.pyc & repack
#  Usage: curl -s https://raw.githubusercontent.com/khanhvc-doc/OpenVPN-Server/master/patch.sh | sudo bash
# ============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}==> $1${NC}"; }

[ "$EUID" -ne 0 ] && error "Run as root."

EGG_DIR="/usr/local/openvpn_as/lib/python"
[ ! -d "$EGG_DIR" ] && error "openvpn-as not found. Run install.sh first."

# ── Step 1: Dependencies ─────────────────────────────────────
section "Checking dependencies"
MISSING=()
command -v python3 &>/dev/null || MISSING+=(python3)
command -v unzip   &>/dev/null || MISSING+=(unzip)
command -v zip     &>/dev/null || MISSING+=(zip)
if [ ${#MISSING[@]} -gt 0 ]; then
  warn "Missing: ${MISSING[*]} — installing..."
  apt update -qq && apt install -y -qq "${MISSING[@]}"
fi
info "OK."

# ── Step 2: Detect egg ───────────────────────────────────────
section "Detecting egg file"
EGG_FILE=$(find "$EGG_DIR" -maxdepth 1 -name "pyovpn-*.egg" | sort | tail -1)
[ -z "$EGG_FILE" ] && error "No pyovpn-*.egg found."
EGG_NAME=$(basename "$EGG_FILE")
PY_VER=$(echo "$EGG_NAME" | grep -oP '(?<=py)\d+\.\d+(?=\.egg)')
info "Egg    : $EGG_NAME"
info "Python : $PY_VER"

# Verify python version matches
SYS_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
[ "$SYS_VER" != "$PY_VER" ] && \
  warn "System python ($SYS_VER) != egg python ($PY_VER). Proceeding anyway..."

# ── Step 3: Stop service ─────────────────────────────────────
section "Stopping openvpnas"
service openvpnas stop 2>/dev/null || systemctl stop openvpnas 2>/dev/null || true
info "Stopped."

# ── Step 4: Backup ───────────────────────────────────────────
section "Backup"
BACKUP="${EGG_FILE}.orig"
[ ! -f "$BACKUP" ] && cp "$EGG_FILE" "$BACKUP" && info "Backup: $BACKUP"
[ -f "$BACKUP" ]   && warn "Backup exists, skipping: $BACKUP"

# ── Step 5: Extract egg ──────────────────────────────────────
section "Extracting egg"
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT
cp "$EGG_FILE" "$WORK_DIR/pyovpn.zip"
unzip -q "$WORK_DIR/pyovpn.zip" -d "$WORK_DIR/egg"
UPROP_PYC=$(find "$WORK_DIR/egg" -name "uprop.pyc" | head -1)
[ -z "$UPROP_PYC" ] && error "uprop.pyc not found in egg."
UPROP_DIR=$(dirname "$UPROP_PYC")
info "Found: $UPROP_PYC"

# ── Step 6: Write patched uprop.py ───────────────────────────
section "Writing patched uprop.py"
cat > "$WORK_DIR/uprop.py" << 'PYEOF'
# PATCHED uprop.py — concurrent_connections hardcoded to 1000000

from pyovpn.aws.info import AWSInfo
from pyovpn.lic.prop import LicenseProperties
from pyovpn.util.date import YYYYMMDD
from pyovpn.util.env import get_env_debug
from pyovpn.util.error import Passthru

DEBUG = get_env_debug('DEBUG_UPROP')

class UsageProperties(object):

    def figure(self, licdict):
        proplist = set(('concurrent_connections',))
        good = set()
        ret = None
        if licdict:
            for key, props in list(licdict.items()):
                if 'quota_properties' not in props:
                    print('License Manager: key %s is missing usage properties' % key)
                    continue
                proplist.update(props['quota_properties'].split(','))
                good.add(key)
        for prop in proplist:
            v_agg = 0
            v_nonagg = 0
            if licdict:
                for key, props in list(licdict.items()):
                    if key not in good:
                        continue
                    if prop not in props:
                        continue
                    nonagg = int(props[prop])
                    v_nonagg = max(v_nonagg, nonagg)
                    prop_agg = '%s_aggregated' % prop
                    agg = 0
                    if prop_agg in props:
                        agg = int(props[prop_agg])
                        v_agg += agg
                    if DEBUG:
                        print('PROP=%s KEY=%s agg=%d(%d) nonagg=%d(%d)' % (prop, key, agg, v_agg, nonagg, v_nonagg))
            apc = self._apc()
            v_agg += apc
            if ret is None:
                ret = {}
            ret[prop] = max(v_agg + v_nonagg, bool('v_agg') + bool('v_nonagg'))
            ret['apc'] = bool(apc)
            if DEBUG:
                print("ret['%s'] = v_agg(%d) + v_nonagg(%d)" % (prop, v_agg, v_nonagg))

        # ── PATCH: force unlimited ──────────────────────────
        if ret is None:
            ret = {}
        ret['concurrent_connections'] = 1000000
        return ret

    def _apc(self):
        pcs = AWSInfo.get_product_code()
        if pcs:
            return pcs['snoitcennoCtnerrucnoc'[::-1]]
        return 0

    @staticmethod
    def _expired(today, props):
        if 'expiry_date' in props:
            exp = YYYYMMDD.validate(props['expiry_date'])
            return today > exp
        return False


class UsagePropertiesValidate(object):
    proplist = ('concurrent_connections', 'client_certificates')

    def validate(self, usage_properties):
        lp = LicenseProperties(usage_properties)
        lp.aggregated_post()
PYEOF
info "uprop.py written."

# ── Step 7: Compile uprop.py → uprop.pyc ────────────────────
section "Compiling uprop.py → uprop.pyc"

# Read the 16-byte header from original pyc (magic + flags + timestamp + size)
# then compile our source and write header + new bytecode
python3 - "$WORK_DIR/uprop.py" "$UPROP_PYC" << 'PYEOF'
import sys, marshal, importlib.util, struct, time

src_path = sys.argv[1]
out_path = sys.argv[2]

# Read header from existing pyc to keep correct magic number
with open(out_path, 'rb') as f:
    header = f.read(16)

# Compile source
with open(src_path, 'r') as f:
    source = f.read()

code = compile(source, 'uprop.py', 'exec', optimize=0)

# Write new pyc: same header (magic), fresh bytecode
with open(out_path, 'wb') as f:
    f.write(header)
    f.write(marshal.dumps(code))

print(f"Compiled OK -> {out_path}")
PYEOF

info "Compiled."

# ── Step 8: Repack egg ───────────────────────────────────────
section "Repacking egg"
cd "$WORK_DIR/egg"
zip -qr "$WORK_DIR/patched.zip" .
cp "$WORK_DIR/patched.zip" "$EGG_FILE"
cd /
info "Repacked: $EGG_NAME"

# ── Step 9: Restart ──────────────────────────────────────────
section "Starting openvpnas"
echo "" > /var/log/openvpnas.log 2>/dev/null || true
service openvpnas start 2>/dev/null || systemctl start openvpnas 2>/dev/null
sleep 5

# ── Step 10: Hold version ────────────────────────────────────
apt-mark hold openvpn-as openvpn-as-bundled-clients > /dev/null 2>&1 || true

# ── Step 11: Verify ──────────────────────────────────────────
section "Verifying"
if systemctl is-active --quiet openvpnas 2>/dev/null || \
   service openvpnas status 2>/dev/null | grep -q "running"; then
  info "Service running OK."
else
  warn "Service may not be running — check: systemctl status openvpnas"
fi

# Quick check via sacli
cd /usr/local/openvpn_as 2>/dev/null || true
SACLI=/usr/local/openvpn_as/scripts/sacli
SUB=$("$SACLI" SubscriptionStatus 2>/dev/null || echo "N/A")
echo "$SUB" | grep -iE "concurrent|CCN|connect" | head -5 || true

LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || echo "N/A")

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Patch applied successfully!          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
printf "  ${CYAN}%-12s${NC}: ${YELLOW}%s${NC}\n" "Egg"      "$EGG_NAME"
printf "  ${CYAN}%-12s${NC}: ${YELLOW}%s${NC}\n" "Python"   "$PY_VER"
printf "  ${CYAN}%-12s${NC}: ${GREEN}%s${NC}\n"  "Method"   "compile uprop.py -> uprop.pyc"
printf "  ${CYAN}%-12s${NC}: ${GREEN}%s${NC}\n"  "Limit"    "1,000,000 connections"
printf "  ${CYAN}%-12s${NC}: ${GREEN}%s${NC}\n"  "Admin UI" "https://${PUBLIC_IP}:943/admin"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
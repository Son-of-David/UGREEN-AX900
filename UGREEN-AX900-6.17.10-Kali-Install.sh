#!/usr/bin/env bash
set -euo pipefail

# UGREEN AX900 (AIC 8800D80) installer for Kali Linux 6.17.10+kali-amd64
#
# What this script does:
# 1) Installs build/runtime deps
# 2) Builds the driver (expects your del_timer -> timer_shutdown_sync fixes already applied)
# 3) Installs kernel modules into /lib/modules/$(uname -r)/extra and runs depmod
# 4) Installs firmware into /lib/firmware/aic8800D80 (copies *ipc.bin too)
# 5) Sets up udev "eject" rule to switch a69c:5721/5723/5724 storage-mode -> WiFi mode
# 6) Reloads udev rules, unloads/reloads modules

SCRIPT_NAME="$(basename "$0")"
KVER="$(uname -r)"

die() { echo "ERROR: $*" >&2; exit 1; }
need_root() { [[ $EUID -eq 0 ]] || die "Run as root (use sudo)."; }

say() { echo -e "\n==> $*\n"; }

REPO_ROOT="${1:-$(pwd)}"

# Detect expected build directory inside the repo
DRIVER_DIR="$REPO_ROOT/Linux/aic8800_linux_driver/drivers/aic8800"
FW_SRC_DIR="$REPO_ROOT/Linux/aic8800_linux_driver/fw/aic8800D80"

# Output locations
FW_DST_DIR="/lib/firmware/aic8800D80"
MOD_DST_DIR="/lib/modules/$KVER/extra"

# udev rule path
UDEV_RULE="/etc/udev/rules.d/99-aic8800-eject.rules"

# Basic sanity checks
[[ -d "$DRIVER_DIR" ]] || die "Driver directory not found: $DRIVER_DIR"
[[ -d "$FW_SRC_DIR" ]] || die "Firmware source directory not found: $FW_SRC_DIR"

need_root

say "Kernel: $KVER"
say "Repo root: $REPO_ROOT"
say "Driver dir: $DRIVER_DIR"
say "FW source:  $FW_SRC_DIR"

say "Installing dependencies (build + runtime)"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  build-essential \
  bc \
  bison \
  flex \
  git \
  kmod \
  libelf-dev \
  pahole \
  pkg-config \
  linux-headers-"$KVER" \
  usb-modeswitch \
  eject \
  iw \
  rfkill

say "Building kernel modules (make clean; make -j\$(nproc))"
pushd "$DRIVER_DIR" >/dev/null
make clean
make -j"$(nproc)"
popd >/dev/null

say "While it was compiling White=GREAT BLUE=GOOD Purple=OKAY RED=BAD" 

say "Use the RED text and the 40 lines before for troubleshooting"

# Find built modules
AIC_LOAD_FW_KO="$DRIVER_DIR/aic_load_fw/aic_load_fw.ko"
AIC_FDRV_KO="$DRIVER_DIR/aic8800_fdrv/aic8800_fdrv.ko"

[[ -f "$AIC_LOAD_FW_KO" ]] || die "Missing built module: $AIC_LOAD_FW_KO"
[[ -f "$AIC_FDRV_KO" ]] || die "Missing built module: $AIC_FDRV_KO"

say "Installing kernel modules into $MOD_DST_DIR"
install -d -m 755 "$MOD_DST_DIR"
install -m 644 "$AIC_LOAD_FW_KO" "$MOD_DST_DIR/aic_load_fw.ko"
install -m 644 "$AIC_FDRV_KO" "$MOD_DST_DIR/aic8800_fdrv.ko"

say "Running depmod"
depmod -a

say "Verifying module vermagic matches running kernel"
modinfo "$MOD_DST_DIR/aic8800_fdrv.ko" | egrep -i 'filename|vermagic|depends' || true
modinfo "$MOD_DST_DIR/aic_load_fw.ko" | egrep -i 'filename|vermagic|depends' || true

say "Installing firmware to $FW_DST_DIR"
install -d -m 755 "$FW_DST_DIR"

# Copy everything relevant, including ipc variant.
# You explicitly asked: copy *ipc.bin to /lib/firmware/aic8800D80
# We'll copy all .bin files as well to avoid missing auxiliary blobs.
shopt -s nullglob
BIN_FILES=("$FW_SRC_DIR"/*.bin)
IPC_FILES=("$FW_SRC_DIR"/*ipc.bin)

if [[ ${#BIN_FILES[@]} -eq 0 ]]; then
  die "No .bin firmware files found in: $FW_SRC_DIR"
fi

cp -av "${BIN_FILES[@]}" "$FW_DST_DIR/"
chmod 644 "$FW_DST_DIR"/fmacfw_8800d80_u02.bin

say "Firmware directory contents"
ls -la "$FW_DST_DIR"

say "Creating udev rule to switch AIC storage-mode (MSC) to WiFi by ejecting the disk"
# This is the approach you confirmed works (forum + your successful run).
cat > "$UDEV_RULE" <<'EOF'
# AIC Semi / UGREEN AX900 (AIC8800D80) USB storage-mode -> WiFi mode
# The dongle enumerates as a USB mass storage device first (a69c:572x).
# Ejecting the created /dev/sdX triggers re-enumeration into WiFi/BT mode.
KERNEL=="sd*", SUBSYSTEM=="block", ATTRS{idVendor}=="a69c", ATTRS{idProduct}=="5721", RUN+="/usr/bin/eject /dev/%k"
KERNEL=="sd*", SUBSYSTEM=="block", ATTRS{idVendor}=="a69c", ATTRS{idProduct}=="5723", RUN+="/usr/bin/eject /dev/%k"
KERNEL=="sd*", SUBSYSTEM=="block", ATTRS{idVendor}=="a69c", ATTRS{idProduct}=="5724", RUN+="/usr/bin/eject /dev/%k"
EOF

chmod 644 "$UDEV_RULE"

say "Reloading udev rules"
udevadm control --reload-rules
udevadm trigger

say "Unloading any existing modules (ignore errors)"
modprobe -r aic8800_fdrv 2>/dev/null || true
modprobe -r aic_load_fw 2>/dev/null || true

say "Loading modules"
# These names work if depmod picks them up; otherwise we'll insmod from extra/.
# Prefer modprobe because it handles dependencies.
if modprobe aic_load_fw 2>/dev/null; then
  :
else
  insmod "$MOD_DST_DIR/aic_load_fw.ko"
fi

if modprobe aic8800_fdrv 2>/dev/null; then
  :
else
  insmod "$MOD_DST_DIR/aic8800_fdrv.ko"
fi

say "Post-install hints / verification commands"
cat <<EOF
1) Replug the dongle if needed (udev will eject MSC mode automatically).
2) Check that it re-enumerates from a69c:5723 -> a69c:8d81 (or similar) and wlan0 appears:

   lsusb | grep -i a69c
   ip link
   iw dev
   rfkill list
   sudo rfkill unblock all

3) If wlan0 exists but is DOWN:
   sudo ip link set wlan0 up
   sudo iw dev wlan0 scan | head

4) Logs:
   dmesg -T | tail -n 200

EOF

say "Done."


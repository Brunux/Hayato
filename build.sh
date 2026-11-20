#!/bin/bash
# Root umbrella wrapper for Hayato.
# Resolves submodules (core/, desktop/, devices/) and delegates build or verification commands.
#
# Usage:
#   ./build.sh                 build kernel, desktop, rootfs, and kpart (default)
#   ./build.sh kernel          build device kernel stage only
#   ./build.sh desktop         build swayfx, workstyle, and hayato binaries
#   ./build.sh rootfs          build and populate rootfs
#   ./build.sh image [IMG]     build sanitized disk image
#   ./build.sh release [DIR]   build release artifacts + SHA256SUMS
#   ./build.sh sd [DEV]        write image onto removable SD/USB (default /dev/mmcblk1)
#   ./build.sh emmc            install running system to internal eMMC
#   ./build.sh check [ARGS]    run modular health check (check-system.sh)
#   ./build.sh validate        run standalone device & core validations
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
export HAYATO_ROOT_DIR="$ROOT_DIR"
export HAYATO_CORE_DIR="${HAYATO_CORE_DIR:-$ROOT_DIR/core}"
export HAYATO_DESKTOP_DIR="${HAYATO_DESKTOP_DIR:-$ROOT_DIR/desktop}"
export HAYATO_DEVICES_DIR="${HAYATO_DEVICES_DIR:-$ROOT_DIR/devices}"

for sub in "$HAYATO_CORE_DIR/scripts" "$HAYATO_DESKTOP_DIR/uis" "$HAYATO_DEVICES_DIR/devices"; do
	if [ ! -d "$sub" ]; then
		echo "error: submodule checkout incomplete (missing $sub). Run: git submodule update --init --recursive" >&2
		exit 1
	fi
done

cmd="${1:-all}"
[ "$#" -gt 0 ] && shift

case "$cmd" in
	-h|--help|help)
		sed -n '2,15p' "$0" | cut -c3-
		exit 0
		;;
	all)
		exec "$HAYATO_CORE_DIR/scripts/build.sh" "$@"
		;;
	kernel)
		exec "$HAYATO_DEVICES_DIR/scripts/build-kernel.sh" "$@"
		;;
	desktop)
		exec "$HAYATO_DESKTOP_DIR/scripts/stage-desktop.sh" "$@"
		;;
	rootfs)
		"$HAYATO_CORE_DIR/scripts/build-rootfs.sh" "$@"
		"$HAYATO_CORE_DIR/scripts/install-kernel.sh"
		exec "$HAYATO_CORE_DIR/scripts/install-desktop.sh"
		;;
	image)
		exec "$HAYATO_CORE_DIR/scripts/make-image.sh" "$@"
		;;
	release)
		exec "$HAYATO_CORE_DIR/scripts/make-release.sh" "$@"
		;;
	sd)
		exec "$HAYATO_CORE_DIR/scripts/write-sd.sh" "$@"
		;;
	emmc)
		exec "$HAYATO_CORE_DIR/scripts/install-emmc.sh" "$@"
		;;
	check)
		exec "$HAYATO_CORE_DIR/scripts/check-system.sh" "$ROOT_DIR" "$@"
		;;
	validate)
		"$HAYATO_DEVICES_DIR/scripts/validate-devices.sh"
		bash "$HAYATO_CORE_DIR/tests/run.sh"
		bash "$HAYATO_DEVICES_DIR/tests/run.sh"
		for f in "$HAYATO_CORE_DIR"/scripts/*.sh "$HAYATO_CORE_DIR"/boot/*.sh "$HAYATO_DESKTOP_DIR"/scripts/*.sh; do
			bash -n "$f"
		done
		"$HAYATO_CORE_DIR/scripts/check-system.sh" --help >/dev/null
		# The old brand name lives in history (reports/, docs/releases/, the
		# old specs and design notes) and nowhere in the product. This is the
		# guard for specs/026-hayato-rebrand.md: a stray identifier in the
		# tree is a path that resolves to nothing on the device.
		stale=$(grep -rIl --exclude-dir=.git --exclude-dir=target \
			-e 'lazyos' -e 'LazyOS' -e 'LAZYOS' \
			"$HAYATO_DESKTOP_DIR/uis" "$HAYATO_DESKTOP_DIR/rust" \
			"$HAYATO_CORE_DIR/scripts" "$HAYATO_CORE_DIR/boot" \
			"$HAYATO_DEVICES_DIR/devices" "$HAYATO_DEVICES_DIR/kernels" \
			"$ROOT_DIR/site" "$ROOT_DIR/.github" 2>/dev/null || true)
		if [ -n "$stale" ]; then
			echo "error: the old brand name is still in the product tree:" >&2
			echo "$stale" >&2
			exit 1
		fi
		echo "Umbrella validation passed."
		;;
	*)
		echo "Unknown subcommand: $cmd (try ./build.sh --help)" >&2
		exit 2
		;;
esac

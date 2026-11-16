#!/bin/bash
# Root umbrella wrapper for LazyOS.
# Resolves submodules (core/, desktop/, devices/) and delegates build or verification commands.
#
# Usage:
#   ./build.sh                 build kernel, desktop, rootfs, and kpart (default)
#   ./build.sh kernel          build device kernel stage only
#   ./build.sh desktop         build swayfx, workstyle, and lazyos binaries
#   ./build.sh rootfs          build and populate rootfs
#   ./build.sh image [IMG]     build sanitized disk image
#   ./build.sh release [DIR]   build release artifacts + SHA256SUMS
#   ./build.sh sd [DEV]        write image onto removable SD/USB (default /dev/mmcblk1)
#   ./build.sh emmc            install running system to internal eMMC
#   ./build.sh check [ARGS]    run modular health check (check-system.sh)
#   ./build.sh validate        run standalone device & core validations
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LAZYOS_ROOT_DIR="$ROOT_DIR"
export LAZYOS_CORE_DIR="${LAZYOS_CORE_DIR:-$ROOT_DIR/core}"
export LAZYOS_DESKTOP_DIR="${LAZYOS_DESKTOP_DIR:-$ROOT_DIR/desktop}"
export LAZYOS_DEVICES_DIR="${LAZYOS_DEVICES_DIR:-$ROOT_DIR/devices}"

for sub in "$LAZYOS_CORE_DIR/scripts" "$LAZYOS_DESKTOP_DIR/uis" "$LAZYOS_DEVICES_DIR/devices"; do
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
		exec "$LAZYOS_CORE_DIR/scripts/build.sh" "$@"
		;;
	kernel)
		exec "$LAZYOS_DEVICES_DIR/scripts/build-kernel.sh" "$@"
		;;
	desktop)
		exec "$LAZYOS_DESKTOP_DIR/scripts/stage-desktop.sh" "$@"
		;;
	rootfs)
		"$LAZYOS_CORE_DIR/scripts/build-rootfs.sh" "$@"
		"$LAZYOS_CORE_DIR/scripts/install-kernel.sh"
		exec "$LAZYOS_CORE_DIR/scripts/install-desktop.sh"
		;;
	image)
		exec "$LAZYOS_CORE_DIR/scripts/make-image.sh" "$@"
		;;
	release)
		exec "$LAZYOS_CORE_DIR/scripts/make-release.sh" "$@"
		;;
	sd)
		exec "$LAZYOS_CORE_DIR/scripts/write-sd.sh" "$@"
		;;
	emmc)
		exec "$LAZYOS_CORE_DIR/scripts/install-emmc.sh" "$@"
		;;
	check)
		exec "$LAZYOS_CORE_DIR/scripts/check-system.sh" "$ROOT_DIR" "$@"
		;;
	validate)
		"$LAZYOS_DEVICES_DIR/scripts/validate-devices.sh"
		for f in "$LAZYOS_CORE_DIR"/scripts/*.sh "$LAZYOS_CORE_DIR"/boot/*.sh "$LAZYOS_DESKTOP_DIR"/scripts/*.sh; do
			bash -n "$f"
		done
		"$LAZYOS_CORE_DIR/scripts/check-system.sh" --help >/dev/null
		echo "Umbrella validation passed."
		;;
	*)
		echo "Unknown subcommand: $cmd (try ./build.sh --help)" >&2
		exit 2
		;;
esac

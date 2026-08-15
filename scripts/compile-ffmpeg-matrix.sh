#!/bin/bash
# Compile against FFmpeg 6, 7, and 8 using stock distro images.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
images=(
	ubuntu:24.04
	ubuntu:25.04
	ubuntu:26.04
)

status=0
for image in "${images[@]}"; do
	echo
	echo "########## $image ##########"
	if ! "$root/scripts/compile-in-image.sh" "$image"; then
		echo "FAILED $image"
		status=1
	fi
done
exit "$status"

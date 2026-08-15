#!/bin/bash
# Compile src/ inside a distro image. Used by CI and the local matrix.
set -euo pipefail

image=${1:?usage: compile-in-image.sh <docker-image>}
root=$(cd "$(dirname "$0")/.." && pwd)

exec docker run --rm \
	-v "$root/src:/src:ro" \
	-w /tmp \
	"$image" \
	bash -lc '
		set -euo pipefail
		export DEBIAN_FRONTEND=noninteractive
		apt-get update -qq
		apt-get install -y --no-install-recommends \
			build-essential pkg-config gettext autopoint autoconf automake \
			libavformat-dev libavutil-dev libavcodec-dev \
			libjpeg-dev libsqlite3-dev libexif-dev libid3tag0-dev \
			libogg-dev libvorbis-dev libflac-dev \
			libffmpegthumbnailer-dev zlib1g-dev \
			ca-certificates
		av=$(apt-cache policy libavformat-dev | awk "/Candidate:/ {print \$2}")
		echo "=== building against $av ==="
		cp -a /src /tmp/src
		cd /tmp/src
		./autogen.sh
		./configure --prefix=/usr --sysconfdir=/etc --enable-thumbnail
		make -j"$(nproc)"
		cc -O2 -Wall -Wextra -I. -o /tmp/test_improvements test_improvements.c
		/tmp/test_improvements
		echo "=== OK $av ==="
	'

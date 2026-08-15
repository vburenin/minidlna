# MiniDLNA (ReadyMedia) fork

A [MiniDLNA](https://sourceforge.net/projects/minidlna/) 1.3.3 fork with
two practical fixes, plus a Docker image that builds the in-tree source.

MiniDLNA is GPLv2. This repository keeps that license.

## Why this fork exists

### 1. Kodi shows video dates as 1905 / 1906

MiniDLNA stored video `dc:date` as a 19-character local timestamp:

```
2024-03-15T14:30:00
```

Kodi’s Platinum / Neptune `FORMAT_W3C` parser accepts either `YYYY-MM-DD`
(exactly 10 characters) or a datetime **with a timezone** (length ≥ 20,
e.g. `…SSZ`). A 19-character `YYYY-MM-DDTHH:MM:SS` is rejected. Platinum
then clears the date, and Kodi treats a leftover year as an OLE serial
day count from 1899-12-30 — which lands in mid-1905 (sometimes 1906).

This fork:

- writes new video dates as `YYYY-MM-DDTHH:MM:SSZ` (UTC) from `st_mtime`
- normalizes `dc:date` on SOAP emit, so existing databases are fixed
  without a rescan (including EXIF `YYYY:MM:DD HH:MM:SS`)

Restart or refresh Kodi after deploy so it does not keep a cached DIDL.

### 2. `exclude_dir` — skip folders such as `video/incomplete`

Stock MiniDLNA has no exclude list. In-progress downloads sitting under
the media tree get scanned, then shown (and often fail) in Kodi.

```conf
# minidlna.conf — repeat the option to exclude more than one location
exclude_dir=video/incomplete
```

- An absolute path matches that directory and everything under it.
- A relative value matches as path components anywhere under a
  `media_dir` (`video/incomplete` matches `/storage/video/incomplete`,
  but not `incompleteness`).
- The scanner and inotify both honor the list. A soft rescan (`-r`)
  drops previously indexed files that now match.

Junk folders that NAS and desktop systems drop into a media tree
(`@eaDir`, `#recycle`, `lost+found`, `$RECYCLE.BIN`, …) and unfinished
download suffixes (`.part`, `.!qB`, `.crdownload`, …) are skipped
automatically. You do not need an `exclude_dir` line for those.

The tree also builds against FFmpeg 7 (`ch_layout`) as well as the
FFmpeg 6 stack on Ubuntu 24.04.

## Layout

| Path | What |
|---|---|
| `src/` | MiniDLNA 1.3.3 plus the patches above |
| `Dockerfile` | multi-stage Ubuntu 24.04 build of `src/` |
| `docker-compose.yaml` | host network (required for SSDP); generic bind mounts |
| `docker-compose.override.yaml.example` | template for host paths (copy, do not commit) |
| `minidlna.conf` | example daemon config baked into the image |
| `restart.sh` | `docker compose build && up -d` |

Image name: `minidlna:local`. Container name: `minidlna`.

SSDP is multicast `239.255.255.250:1900`. The compose file **must** use
`network_mode: host`. Publishing port 8200 on a bridge network is not
enough for Kodi to discover the server.

Point the container at your library with a private `.env` (gitignored):

```bash
cp .env.example .env
# set MINIDLNA_MEDIA / MINIDLNA_CACHE / MINIDLNA_LOG
# optional: MINIDLNA_CONF=./minidlna.local.conf
./restart.sh
```

`docker-compose.override.yaml` is also supported and gitignored if you
prefer bind mounts over env vars. Do not commit either file.

```bash
./restart.sh
curl -sI http://127.0.0.1:8200/ | head
```

## Building without Docker

Same dependencies as upstream 1.3.3 (libavformat, sqlite3, libexif,
libid3tag, libjpeg, libogg, libvorbis, libflac). On Ubuntu 24.04 this
is FFmpeg 6.x; `src/libav.h` already guards `av_register_all()` for
libavformat ≥ 58.

```bash
cd src
./configure --prefix=/usr --sysconfdir=/etc
make -j"$(nproc)"
```

## License

GNU GPL version 2 only. See [`COPYING`](src/COPYING) and
[`LICENCE.miniupnpd`](src/LICENCE.miniupnpd) for the MiniUPnP portions
(BSD-3-Clause).

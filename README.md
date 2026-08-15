# MiniDLNA (ReadyMedia) fork

A [MiniDLNA](https://sourceforge.net/projects/minidlna/) 1.3.3 fork for
Kodi and other UPnP/DLNA clients, plus a Docker image built from this
tree.

MiniDLNA is GPLv2. This repository keeps that license.

The production image is **Ubuntu 26.04 / FFmpeg 8**. MiniDLNA does not
transcode; FFmpeg is only used to read metadata. The same source is
compiled in CI against FFmpeg 6, 7, and 8.

## What this fork changes

### Kodi video dates show as 1905

MiniDLNA stored video `dc:date` as a 19-character local timestamp:

```
2024-03-15T14:30:00
```

Kodi’s Platinum / Neptune `FORMAT_W3C` parser accepts either `YYYY-MM-DD`
(exactly 10 characters) or a datetime **with a timezone** (length ≥ 20,
e.g. `…SSZ`). A 19-character `YYYY-MM-DDTHH:MM:SS` is rejected. Platinum
then clears the date, and Kodi treats a leftover year as an OLE serial
day count from 1899-12-30 — which lands in mid-1905.

This fork:

- writes new video dates as `YYYY-MM-DDTHH:MM:SSZ` (UTC) from `st_mtime`
- prefers a sidecar Kodi NFO when present: `<premiered>`, then `<aired>`,
  then `<year>` (stored as `YYYY-01-01`), then MiniDLNA `<capturedate>`
- normalizes `dc:date` on SOAP emit, so existing databases are fixed
  without a rescan (including EXIF `YYYY:MM:DD HH:MM:SS` and a bare year)

NFO dates apply when the video or `.nfo` is scanned or touched. A soft
`-r` start does not rewrite unchanged rows; use `-R` or edit the NFO.

Restart or refresh Kodi after deploy so it does not keep a cached DIDL.

### Skip folders and unfinished downloads

Stock MiniDLNA has no exclude list. In-progress downloads under the
media tree get scanned and shown (and often fail) in Kodi.

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

These are skipped automatically, with no config line:

- NAS / desktop junk folders: `@eaDir`, `#recycle`, `lost+found`,
  `$RECYCLE.BIN`, `System Volume Information`, `.Trash` / `.Trash-<uid>`,
  and similar
- Unfinished download suffixes: `.part`, `.!qB`, `.!ut`, `.bc!`,
  `.crdownload`, `.aria2`, `.download`, `.tmp`

### Artwork names

Besides the usual `folder.jpg` / `Cover.jpg` / `Movie.cover.jpg`, the
scanner also looks for Kodi sidecars:

- `Movie-poster.jpg`, `Movie-fanart.jpg` next to `Movie.mkv`
- `poster.jpg` / `Poster.jpg` in the folder (`album_art_names`)

### Video thumbnails

The image is built with `--enable-thumbnail` (`libffmpegthumbnailer`).
When no embedded art or sidecar poster / `folder.jpg` exists,
the scanner can decode a frame and serve it as `upnp:albumArtURI`.

```conf
enable_thumbnail=yes
#thumbnail_width=160
#thumbnail_quality=8
#enable_thumbnail_filmstrip=no
```

Default is off so a first scan does not decode every video. Turning it
on walks files that still lack art and fills `art_cache`.

Also from Debian 1.3.3:

- compilation albums no longer spawn one container per artist on inotify
- SIGHUP reopens the log without tearing down SSDP sockets
- the non-fork scanner path closes SQLite after a scan

### FFmpeg 6 / 7 / 8

`src/libav.h` uses `ch_layout.nb_channels` on libavutil ≥ 57.28, so the
tree builds on FFmpeg 6 (deprecated `channels`), 7, and 8.

| Image | libavformat | Role |
|---|---|---|
| `ubuntu:24.04` | FFmpeg 6.1 | CI compile |
| `ubuntu:25.04` | FFmpeg 7.1 | CI compile |
| `ubuntu:26.04` | FFmpeg 8.0 | CI compile **and** production image |

GitHub Actions runs this matrix on every push. Locally:

```bash
./scripts/compile-ffmpeg-matrix.sh
# or one image:
./scripts/compile-in-image.sh ubuntu:26.04
```

## Layout

| Path | What |
|---|---|
| `src/` | MiniDLNA 1.3.3 plus the patches above |
| `Dockerfile` | multi-stage Ubuntu 26.04 / FFmpeg 8 build of `src/` |
| `docker-compose.yaml` | host network (required for SSDP); generic bind mounts |
| `docker-compose.override.yaml.example` | template for host paths (copy, do not commit) |
| `.env.example` | template for `MINIDLNA_MEDIA` / cache / log / conf |
| `minidlna.conf` | example daemon config baked into the image |
| `restart.sh` | `docker compose build && up -d` |
| `scripts/` | FFmpeg 6/7/8 compile helpers |
| `.github/workflows/compile.yml` | compile matrix |

Image name: `minidlna:local`. Container name: `minidlna`.

## Docker

SSDP is multicast `239.255.255.250:1900`. The compose file **must** use
`network_mode: host`. Publishing port 8200 on a bridge network is not
enough for Kodi to discover the server.

Point the container at your library with a private `.env` (gitignored):

```bash
cp .env.example .env
# set MINIDLNA_MEDIA / MINIDLNA_CACHE / MINIDLNA_LOG
# optional: MINIDLNA_CONF=./minidlna.local.conf
./restart.sh
curl -sI http://127.0.0.1:8200/ | head
```

`docker-compose.override.yaml` is also supported and gitignored if you
prefer bind mounts over env vars. Do not commit either file.

## Building without Docker

Same dependencies as upstream 1.3.3 (libavformat, sqlite3, libexif,
libid3tag, libjpeg, libogg, libvorbis, libflac). Add
`libffmpegthumbnailer` for `--enable-thumbnail`. `src/libav.h` already
guards `av_register_all()` for libavformat ≥ 58.

```bash
cd src
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc --enable-thumbnail
make -j"$(nproc)"
```

## License

GNU GPL version 2 only. See [`COPYING`](src/COPYING) and
[`LICENCE.miniupnpd`](src/LICENCE.miniupnpd) for the MiniUPnP portions
(BSD-3-Clause).

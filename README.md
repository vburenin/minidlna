# MiniDLNA (ReadyMedia) fork

A [MiniDLNA](https://sourceforge.net/projects/minidlna/) 1.3.3 fork for
Kodi and other UPnP/DLNA clients, plus a Docker image built from this
tree.

MiniDLNA is GPLv2. This repository keeps that license.

The production image is **Ubuntu 26.04 / FFmpeg 8**. MiniDLNA does not
transcode; FFmpeg is only used to read metadata. The same source is
compiled in CI against FFmpeg 6, 7, and 8.

## Improvements

### Dates (Kodi 1905)

- Video `dc:date` is stored as `YYYY-MM-DDTHH:MM:SSZ` (UTC) from
  `st_mtime`, so Kodi’s Platinum `FORMAT_W3C` parser accepts it.
- SOAP emit rewrites existing rows with no rescan: 19-character
  `YYYY-MM-DDTHH:MM:SS`, EXIF `YYYY:MM:DD HH:MM:SS`, and a bare year
  (`1999` → `1999-01-01`).
- Sidecar Kodi `.nfo` wins when present: `<premiered>`, then `<aired>`,
  then `<year>`, then MiniDLNA `<capturedate>`.
- NFO dates apply when the video or `.nfo` is scanned or touched. Soft
  `-r` does not rewrite unchanged rows; use `-R` or edit the NFO.
- Refresh or restart Kodi after deploy so it does not keep a cached DIDL.

Stock MiniDLNA emitted `2024-03-15T14:30:00` (19 characters, no
timezone). Kodi rejects that, clears the date, and shows year **1905**.

### Library paths

- `exclude_dir=` skips a directory and everything under it (absolute
  prefix or path-component match). Repeat the option. Honored by scan,
  inotify, and `-r`.
- Built-in skip, no config: NAS junk folders (`@eaDir`, `#recycle`,
  `lost+found`, `$RECYCLE.BIN`, `System Volume Information`,
  `.Trash` / `.Trash-<uid>`, and similar).
- Built-in skip, no config: unfinished download suffixes (`.part`,
  `.!qB`, `.!ut`, `.bc!`, `.crdownload`, `.aria2`, `.download`, `.tmp`).

```conf
exclude_dir=video/incomplete
```

### Artwork

- Kodi sidecars: `Movie-poster.jpg`, `Movie-fanart.jpg` next to
  `Movie.mkv`, plus folder `poster.jpg` / `Poster.jpg`.
- Optional video thumbnails (`libffmpegthumbnailer`): a frame is decoded
  only when there is no embedded or sidecar art.

```conf
enable_thumbnail=yes
#thumbnail_width=160
#thumbnail_quality=8
#enable_thumbnail_filmstrip=no
```

Default is off. The image is built with `--enable-thumbnail`.

### Symlink aliases

- Every path stays browseable (`genres/…` and `kids/Movies/…`).
- Metadata, date, and album art are computed once per inode. Later
  aliases clone that row.
- Deleting one path does not remove the others. The shared JPEG is
  removed only when the last alias is gone.
- Database v12. Rebuild (`-R` or a new `files.db`) to apply on an
  existing cache.

### Debian 1.3.3 scanner fixes

- Compilation albums no longer spawn one container per artist on inotify.
- SIGHUP reopens the log without tearing down SSDP sockets.
- The non-fork scanner path closes SQLite after a scan.
- `AC_INIT` reports 1.3.3 (was the leftover 1.1.3).

### Build and image

- Compiles on FFmpeg 6, 7, and 8 (`ch_layout.nb_channels` on libavutil
  ≥ 57.28).
- Production Docker image: Ubuntu 26.04 / FFmpeg 8, host network (SSDP).
- CI and `scripts/compile-ffmpeg-matrix.sh` build against
  `ubuntu:24.04` (FFmpeg 6.1), `25.04` (7.1), and `26.04` (8.0).

## Layout

| Path | What |
|---|---|
| `src/` | MiniDLNA 1.3.3 plus the improvements above |
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

Compile against FFmpeg 6, 7, and 8:

```bash
./scripts/compile-ffmpeg-matrix.sh
# or one image:
./scripts/compile-in-image.sh ubuntu:26.04
```

## License

GNU GPL version 2 only. See [`COPYING`](src/COPYING) and
[`LICENCE.miniupnpd`](src/LICENCE.miniupnpd) for the MiniUPnP portions
(BSD-3-Clause).

# Build MiniDLNA 1.3.3 from the in-tree source (includes the Kodi dc:date fix).
# Ubuntu 24.04 matches the host package's FFmpeg 6.x stack.

FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        gettext \
        autoconf \
        automake \
        libavformat-dev \
        libavutil-dev \
        libavcodec-dev \
        libjpeg-dev \
        libsqlite3-dev \
        libexif-dev \
        libid3tag0-dev \
        libogg-dev \
        libvorbis-dev \
        libflac-dev \
        zlib1g-dev \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY src/ .

RUN ./configure --prefix=/usr --sysconfdir=/etc \
    && make -j"$(nproc)" \
    && make install DESTDIR=/out

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Los_Angeles

RUN apt-get update && apt-get install -y --no-install-recommends \
        libavformat60 \
        libavutil58 \
        libavcodec60 \
        libswresample4 \
        libjpeg8 \
        libsqlite3-0 \
        libexif12 \
        libid3tag0 \
        libogg0 \
        libvorbis0a \
        libflac12t64 \
        zlib1g \
        tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && useradd --system --no-create-home --uid 114 --user-group minidlna \
    && mkdir -p /var/cache/minidlna /var/log/minidlna /storage/video \
    && chown -R minidlna:minidlna /var/cache/minidlna /var/log/minidlna \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/usr/sbin/minidlnad /usr/sbin/minidlnad
COPY minidlna.conf /etc/minidlna.conf

# HTTP descriptions/SOAP/media. SSDP is UDP/1900 (host network).
EXPOSE 8200/tcp 1900/udp

# Start as root so minidlnad can bind UDP/1900, then it drops to user=minidlna.
# -S: stay in the foreground (container PID 1).
# -r: soft non-destructive DB rebuild on start (same as the host unit).
CMD ["/usr/sbin/minidlnad", "-f", "/etc/minidlna.conf", "-S", "-r"]

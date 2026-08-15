# Build MiniDLNA 1.3.3 from the in-tree source (Kodi dc:date, exclude_dir,
# junk/incomplete skips, optional video thumbnails). Ubuntu 26.04 ships
# FFmpeg 8; src/libav.h uses ch_layout so it also covers FFmpeg 7.

FROM ubuntu:26.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        gettext \
        autopoint \
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
        libffmpegthumbnailer-dev \
        zlib1g-dev \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY src/ .

RUN ./autogen.sh \
    && ./configure --prefix=/usr --sysconfdir=/etc --enable-thumbnail \
    && make -j"$(nproc)" \
    && make install DESTDIR=/out

FROM ubuntu:26.04

ARG MINIDLNA_UID=
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
        libavformat62 \
        libavutil60 \
        libavcodec62 \
        libswresample6 \
        libjpeg8 \
        libsqlite3-0 \
        libexif12 \
        libid3tag0 \
        libogg0 \
        libvorbis0a \
        libflac14 \
        libffmpegthumbnailer4v5 \
        zlib1g \
        tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && if [ -n "$MINIDLNA_UID" ]; then \
           useradd --system --no-create-home --uid "$MINIDLNA_UID" --user-group minidlna; \
       else \
           useradd --system --no-create-home --user-group minidlna; \
       fi \
    && mkdir -p /var/cache/minidlna /var/log/minidlna /storage/video \
    && chown -R minidlna:minidlna /var/cache/minidlna /var/log/minidlna \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/usr/sbin/minidlnad /usr/sbin/minidlnad
COPY minidlna.conf /etc/minidlna.conf

# HTTP descriptions/SOAP/media. SSDP is UDP/1900 (host network).
EXPOSE 8200/tcp 1900/udp

# Start as root so minidlnad can bind UDP/1900, then it drops to user=minidlna.
# -S: stay in the foreground (container PID 1).
# -r: soft non-destructive DB rebuild on start.
CMD ["/usr/sbin/minidlnad", "-f", "/etc/minidlna.conf", "-S", "-r"]

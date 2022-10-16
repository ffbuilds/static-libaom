
# bump: aom /AOM_VERSION=([\d.]+)/ git:https://aomedia.googlesource.com/aom|*
# bump: aom after ./hashupdate Dockerfile AOM $LATEST
# bump: aom after COMMIT=$(git ls-remote https://aomedia.googlesource.com/aom v$LATEST^{} | awk '{print $1}') && sed -i -E "s/^ARG AOM_COMMIT=.*/ARG AOM_COMMIT=$COMMIT/" Dockerfile
# bump: aom link "CHANGELOG" https://aomedia.googlesource.com/aom/+/refs/tags/v$LATEST/CHANGELOG
ARG AOM_VERSION=3.5.0
ARG AOM_URL="https://aomedia.googlesource.com/aom"
ARG AOM_COMMIT=bcfe6fbfed315f83ee8a95465c654ee8078dbff9

FROM ghcr.io/ffbuilds/static-libvmaf:main@sha256:52598ef2a3af734b539372ba56dd88b417e5f664dbfc6a9146157185e20f6062 AS vmaf

# bump: alpine /FROM alpine:([\d.]+)/ docker:alpine|^3
# bump: alpine link "Release notes" https://alpinelinux.org/posts/Alpine-$LATEST-released.html
FROM alpine:3.16.2 AS base

FROM base AS download
ARG AOM_VERSION
ARG AOM_URL
ARG AOM_COMMIT
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    git && \
  git clone --depth 1 --branch v$AOM_VERSION "$AOM_URL" && \
  cd aom && test $(git rev-parse HEAD) = $AOM_COMMIT && \
  apk del download

FROM base AS build
COPY --from=download /tmp/aom/ /tmp/aom/
COPY --from=vmaf /usr/local/lib/pkgconfig/libvmaf.pc /usr/local/lib/pkgconfig/libvmaf.pc
COPY --from=vmaf /usr/local/lib/libvmaf.a /usr/local/lib/libvmaf.a
COPY --from=vmaf /usr/local/include/libvmaf/ /usr/local/include/libvmaf/
ARG TARGETPLATFORM
WORKDIR /tmp/aom/build_tmp
RUN \
  case ${TARGETPLATFORM} in \
    linux/arm/v*) \
      # Fake it 'til we make it
      touch /usr/local/lib/pkgconfig/aom.pc && \
      touch /usr/local/lib/libaom.a && \
      mkdir -p /usr/local/include/aom/ && \
      exit 0 \
    ;; \
  esac && \
  apk add --no-cache --virtual build \
    build-base cmake yasm nasm perl pkgconf && \
  cmake \
    -G"Unix Makefiles" \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DENABLE_EXAMPLES=NO \
    -DENABLE_DOCS=NO \
    -DENABLE_TESTS=NO \
    -DENABLE_TOOLS=NO \
    -DCONFIG_TUNE_VMAF=1 \
    -DENABLE_NASM=ON \
    -DCMAKE_INSTALL_LIBDIR=lib \
    .. && \
  make -j$(nproc) install && \
  apk del build

FROM scratch
ARG AOM_VERSION
COPY --from=build /usr/local/lib/pkgconfig/aom.pc /usr/local/lib/pkgconfig/aom.pc
COPY --from=build /usr/local/lib/libaom.a /usr/local/lib/libaom.a
COPY --from=build /usr/local/include/aom/ /usr/local/include/aom/

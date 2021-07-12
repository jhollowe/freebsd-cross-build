# The version of Alpine to use in the Docker image.
ARG ALPINE_VERSION=3.12
FROM alpine:$ALPINE_VERSION AS enviro

# Lots of cross-compiler guides include instructions for compiling MPC, MPFR,
# and GMP. Don't: these are dependencies required for compiling GCC itself, and
# do not affect the compiled output. Per GCC's own documented recommendation
# (https://gcc.gnu.org/wiki/InstallingGCC), we'll use the libraries provided by
# our distro package manager.
RUN apk add --no-cache file make gcc musl-dev gmp-dev mpc1-dev mpfr-dev

# what version will this image (tag) cross-compile for?
ARG FBSD_VERSION=10.0
ARG FBSD_ARCH=amd64
ARG GCC_VERSION=4.2.4
ARG BINUTILS_VERSION=2.19.1a

# The mirror from which to retrieve FreeBSD archives. It may be easier to
# override this mirror than to use an HTTP proxy (e.g., to speed up local
# development or reduce bandwidth consumption).
ARG FBSD_MIRROR=http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases
ARG FBSD_BASE_URL=${FBSD_MIRROR}/${FBSD_ARCH}/${FBSD_VERSION}-RELEASE/base.txz

# The mirror from which to retrieve GNU sources.
ARG GNU_MIRROR=https://ftp.gnu.org/gnu
# FreeBSD 9.3 includes GCC 4.2.1; 4.2.4 is the last patch version in the 4.2.x
# series. We want to keep the compiler version pretty close to that included
# with the distro so we retain compatibility with the original libgcc.
ARG GCC_URL=${GNU_MIRROR}/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.bz2
# Per https://wiki.osdev.org/Cross-Compiler_Successful_Builds, binutils
# versions above 2.19.1 are uncharted territory with GCC 4.2.
ARG BINUTILS_URL=${GNU_MIRROR}/binutils/binutils-${BINUTILS_VERSION}.tar.bz2

ARG MAKEFLAGS="-j 1"

ADD $FBSD_BASE_URL /usr/local/src/fbsd-base.txz
ADD $GCC_URL $BINUTILS_URL /usr/local/src/
COPY compile .

FROM enviro AS compile
RUN export FBSD_MAJOR=$(echo $FBSD_VERSION | cut -d '.' -f 1) \
    && /usr/local/src/build-cross ${FBSD_ARCH}-freebsd$FBSD_MAJOR \
                                  /usr/local/src/fbsd-base.txz
RUN rm -Rf /usr/local/src

ARG ALPINE_VERSION
FROM alpine:$ALPINE_VERSION AS deploy

RUN apk add --no-cache file make

COPY --from=compile \
     /usr/local/ \
     /usr/local/
COPY deploy .
COPY README.md .
WORKDIR /workdir

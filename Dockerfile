FROM debian:bookworm

ARG DEBIAN_FRONTEND=noninteractive
ARG SRC_DIR="."

# Harden APT (retries, IPv4) and install cross toolchain + common dev libs
RUN set -eux; \
  printf 'Acquire::Retries "5";\nAcquire::http::Timeout "25";\nAcquire::https::Timeout "25";\nAcquire::ForceIPv4 "true";\n' > /etc/apt/apt.conf.d/99resilient; \
  dpkg --add-architecture arm64; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates git cmake ninja-build pkg-config \
    crossbuild-essential-arm64 \
    libserialport-dev:arm64 libpigpio-dev:arm64 libi2c-dev:arm64 libbluetooth-dev:arm64; \
  rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . /src

# Pick/validate the source directory
RUN bash -lc 'set -eux; \
  PICK="$SRC_DIR"; \
  if [ ! -f "$PICK/CMakeLists.txt" ]; then \
    echo "CMakeLists.txt not found in $PICK"; \
    echo "Available CMakeLists (<=3 levels):"; \
    find . -maxdepth 3 -name CMakeLists.txt -print; \
    exit 1; \
  fi; \
  echo "==> Using source dir: $PICK" > /src/.chosen; \
  cat /src/.chosen'

# Configure & build (ARM64 cross)
RUN bash -lc 'set -eux; \
  SRC_DIR=$(sed -E "s/^==> Using source dir: //" /src/.chosen); \
  cmake -B build -S "$SRC_DIR" -G Ninja \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
    -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
    -DCMAKE_BUILD_TYPE=Release; \
  cmake --build build -j'

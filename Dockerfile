FROM debian:bookworm

ARG DEBIAN_FRONTEND=noninteractive

# Make APT resilient (retries, timeouts, force IPv4 to dodge runner IPv6 quirks)
RUN set -eux; \
  printf 'Acquire::Retries "5";\nAcquire::http::Timeout "25";\nAcquire::https::Timeout "25";\nAcquire::ForceIPv4 "true";\n' > /etc/apt/apt.conf.d/99resilient; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates git cmake ninja-build pkg-config \
    crossbuild-essential-arm64 \
    libserialport-dev:arm64 libpigpio-dev:arm64 libi2c-dev:arm64 libbluetooth-dev:arm64; \
  rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . /src

# Pick a source directory automatically (or force one—see note below)
RUN bash -lc 'set -eux; \
  PICK="."; \
  if [ ! -f CMakeLists.txt ]; then \
    for d in lora_shooting-userside lora_shooting-targetside weather_center; do \
      if [ -f "$d/CMakeLists.txt" ]; then PICK="$d"; break; fi; \
    done; \
  fi; \
  echo "==> Using source dir: $PICK"; \
  test -f "$PICK/CMakeLists.txt"; \
  echo "$PICK" > .src_dir; \
  echo "CMakeLists found (<=3 levels):"; find . -maxdepth 3 -name CMakeLists.txt -print'

# Configure & build (ARM64 cross)
RUN bash -lc 'set -eux; \
  SRC_DIR=$(cat .src_dir); \
  cmake -B build -S "$SRC_DIR" -G Ninja \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
    -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
    -DCMAKE_BUILD_TYPE=Release; \
  cmake --build build -j'

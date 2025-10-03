FROM debian:bookworm

# --- Toolchain + common dev libs for Pi projects ---
RUN dpkg --add-architecture arm64 && apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates git cmake ninja-build pkg-config \
      crossbuild-essential-arm64 \
      libserialport-dev:arm64 libpigpio-dev:arm64 libi2c-dev:arm64 \
      libbluetooth-dev:arm64 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . /src

# --- Choose the source subdir automatically (bias to userside/targetside/weather) ---
# Writes the chosen folder into .src_dir (e.g., "lora_shooting-userside")
RUN bash -lc 'set -eux; \
  PICK=""; \
  if [ -f CMakeLists.txt ]; then PICK="."; fi; \
  for d in lora_shooting-userside lora_shooting-targetside weather_center; do \
    [ -n "$PICK" ] && break; \
    if [ -f "$d/CMakeLists.txt" ]; then PICK="$d"; fi; \
  done; \
  if [ -z "$PICK" ]; then \
    # last resort: first CMakeLists.txt within depth 3
    PICK=$(find . -maxdepth 3 -type f -name CMakeLists.txt | head -n1 | xargs dirname || true); \
  fi; \
  echo "==> Using source dir: ${PICK}"; \
  test -n "$PICK" && test -f "${PICK}/CMakeLists.txt"; \
  echo "$PICK" > .src_dir; \
  echo "CMakeLists found (<=3 levels):"; find . -maxdepth 3 -name CMakeLists.txt -print'

# --- Configure & build (ARM64 cross) with verbose output ---
RUN bash -lc 'set -eux; \
  SRC_DIR=$(cat .src_dir); \
  cmake -B build -S "$SRC_DIR" -G Ninja \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
    -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_VERBOSE_MAKEFILE=ON || { \
      echo "----- CMake configure failed. Dumping logs (if any) -----"; \
      [ -f build/CMakeFiles/CMakeError.log ] && cat build/CMakeFiles/CMakeError.log || true; \
      [ -f build/CMakeFiles/CMakeOutput.log ] && head -n 200 build/CMakeFiles/CMakeOutput.log || true; \
      exit 1; \
    }; \
  cmake --build build -j || { \
      echo "----- Build failed. Listing objects and last 200 lines from ninja log (if present) -----"; \
      find build -maxdepth 2 -type f | sort | tail -n 50 || true; \
      [ -f build/.ninja_log ] && tail -n 200 build/.ninja_log || true; \
      ex

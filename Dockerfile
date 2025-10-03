FROM debian:bookworm

ARG SRC_DIR="."

RUN dpkg --add-architecture arm64 && apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates git cmake ninja-build pkg-config \
      crossbuild-essential-arm64 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . /src

# Auto-pick a likely subproject if top-level doesn't have CMakeLists.txt
RUN bash -lc 'set -eux; \
  if [ ! -f CMakeLists.txt ]; then \
    for d in lora_shooting-userside lora_shooting-targetside weather_center; do \
      if [ -f "$d/CMakeLists.txt" ]; then echo "==> Using $d"; echo "$d" > .src_dir; break; fi; \
    done; \
  else \
    echo "." > .src_dir; \
  fi; \
  cat .src_dir'

# Just list things for now (no compile yet)
RUN bash -lc 'set -eux; \
  echo "CMakeLists found (depth<=3):"; \
  find . -maxdepth 3 -name CMakeLists.txt -print; \
  echo "SRC_DIR=$(cat .src_dir)"'

# FreeTrack/UDP SteamVR Vive Controller Driver - Build Container

This directory contains the Docker configuration for the standard build environment used to compile, run, and debug the FreeTrack/UDP SteamVR Vive controller driver.

## Overview

The build container provides a consistent, reproducible environment with all necessary tools:
- **Base OS**: Ubuntu 24.04 LTS (noble)
- **Compilers**: GCC 12, G++ 12, Clang 15
- **Build Tools**: CMake 3.28+, Make, Ninja
- **Debugging/Analysis**: GDB, LLDB, Valgrind, clang-tidy, cppcheck
- **OpenVR SDK**: Headers at `/opt/openvr/headers` (from ValveSoftware/openvr)
- **Network Tools**: socat, netcat, iproute2 (for UDP testing/debugging)
- **Scripting**: Python 3.12 + pip

## Quick Start

### Build the Container

```bash
# Using the build script (recommended)
./build.sh build

# Or directly with docker
docker build -t freectrl-dev .
```

### Run Interactive Development Shell

```bash
# Using the build script (mounts current directory)
./build.sh run

# Or directly with docker
docker run --rm -it -v $(pwd):/workspace/freectrl_driver freectrl-dev
```

### Using Docker Compose

```bash
# Start container in background
docker-compose up -d

# Attach to running container
docker-compose exec freectrl-dev bash

# Stop container
docker-compose down
```

### Build the Driver Inside Container

Once inside the container:

```bash
cd /workspace/freectrl_driver
cmake -B build
cmake --build build
```

## Registry Push

The container image should be pushed to the internal registry:

```bash
# Tag for registry
docker tag freectrl-dev registry.home.com/system-utilities/container-registry/steamvr-build-container:latest

# Login (requires GITLAB_TOKEN and GITLAB_USER environment variables)
echo "$GITLAB_TOKEN" | docker login registry.home.com -u "$GITLAB_USER" --password-stdin

# Push with retry logic (handles flaky registry)
./build.sh push

# Or push directly
docker push registry.home.com/system-utilities/container-registry/steamvr-build-container:latest
```

**Note**: The registry can be flaky (intermittent 5xx, auth timeouts). The build script implements retry logic with exponential backoff (3 retries). If push fails after retries, manual intervention is required.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CC` | C compiler | `gcc-12` |
| `CXX` | C++ compiler | `g++-12` |
| `OPENVR_HEADERS` | Path to OpenVR headers | `/opt/openvr/headers` |

## Container User

The container runs as a non-root user `developer` (UID 1000, GID 1000) with passwordless sudo access for development convenience.

## Image Size

The final image size is approximately **2.01 GB**, containing all necessary build tools and debugging utilities.

## Acceptance Criteria Verification

- ✅ `docker build -t freectrl-dev .` succeeds
- ✅ `docker run --rm freectrl-dev cmake --version` shows >=3.20
- ✅ `docker run --rm freectrl-dev g++ --version` shows >=11
- ✅ `docker run --rm freectrl-dev ls /opt/openvr/headers/` shows openvr_driver.h
- ✅ Container can compile a test C++17 file with OpenVR headers
- ✅ Image size reasonable (~2.01 GB)
- ✅ Image tagged as `registry.home.com/system-utilities/container-registry/steamvr-build-container:latest`
- ✅ Push to registry works with retry logic (when credentials provided)

## Directory Structure

```
freectrl_driver/
├── Dockerfile              # Multi-stage Docker build
├── docker-compose.yml      # Docker Compose configuration
├── build.sh                # Build script with validation and registry push
├── entrypoint.sh           # Container entrypoint (handles commands and interactive shell)
├── openvr_headers -> /opt/openvr/headers  # Symlink to OpenVR headers
└── README.md               # This file
```

## Customization

To customize the build, modify the `ARG` values in the Dockerfile:

```dockerfile
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000
```

Build with custom values:

```bash
docker build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -t freectrl-dev .
```

## Troubleshooting

### Container fails to start
Ensure Docker daemon is running and you have permission to run containers.

### OpenVR headers not found
The headers are downloaded during build from `https://github.com/ValveSoftware/openvr`. If download fails, check network connectivity.

### Permission issues with volume mounts
The container user has UID/GID 1000. Ensure your host user matches, or rebuild with custom UID/GID.

### Registry push fails
Check that `GITLAB_TOKEN` and `GITLAB_USER` are set correctly. The registry at `registry.home.com` may have intermittent issues - retry manually if needed.
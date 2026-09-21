# SteamVR Build Container for FreeTrack/UDP Vive Controller Driver
# Multi-stage build to minimize final image size
# Stage 1: Build stage - download OpenVR headers and prepare
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install minimal dependencies for downloading OpenVR
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and install OpenVR SDK headers
RUN mkdir -p /opt/openvr/headers \
    && cd /tmp \
    && wget -q https://github.com/ValveSoftware/openvr/archive/refs/heads/master.zip -O openvr-master.zip \
    && unzip -q openvr-master.zip \
    && cp -r openvr-master/headers/* /opt/openvr/headers/ \
    && rm -rf openvr-master.zip openvr-master \
    && chmod -R a+r /opt/openvr/headers

# Verify OpenVR headers are present
RUN ls -la /opt/openvr/headers/ && test -f /opt/openvr/headers/openvr_driver.h && test -f /opt/openvr/headers/openvr.h && test -f /opt/openvr/headers/openvr_capi.h


# Stage 2: Final runtime stage
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
# Avoid build-essential metapackage to prevent pulling gcc-13; install specific packages instead
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    gcc-12 \
    g++-12 \
    clang-15 \
    make \
    ninja-build \
    python3 \
    python3-pip \
    gdb \
    lldb-15 \
    valgrind \
    clang-tidy-15 \
    cppcheck \
    netcat-openbsd \
    socat \
    iproute2 \
    git \
    sudo \
    binutils \
    libstdc++-12-dev \
    libc6-dev \
    dpkg-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/locale/* \
    && rm -rf /tmp/* /var/tmp/*

# Set up alternatives for gcc/g++ and clang tools
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 100 \
    && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-15 100 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-15 100 \
    && update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-15 100 \
    && update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-15 100

# Copy OpenVR headers from builder stage
COPY --from=builder /opt/openvr/headers /opt/openvr/headers

# Create non-root user for development
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000

# Remove existing user/group with UID/GID 1000 if they exist (e.g., ubuntu user in base image)
# Must remove user first, then group
RUN if id -u $USER_UID > /dev/null 2>&1; then \
        EXISTING_USER=$(id -un $USER_UID); \
        echo "Removing existing user with UID $USER_UID: $EXISTING_USER"; \
        userdel -r $EXISTING_USER; \
    fi \
    && if getent group $USER_GID > /dev/null; then \
        GROUP_NAME=$(getent group $USER_GID | cut -d: -f1); \
        echo "Removing existing group with GID $USER_GID: $GROUP_NAME"; \
        groupdel $GROUP_NAME; \
    fi \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory
WORKDIR /workspace/freectrl_driver

# Create a convenience symlink for OpenVR headers in the workspace
RUN ln -s /opt/openvr/headers /workspace/freectrl_driver/openvr_headers

# Switch to non-root user
USER $USERNAME

# Set up environment
ENV CC=gcc-12
ENV CXX=g++-12
ENV OPENVR_HEADERS=/opt/openvr/headers

# Entrypoint: handles both interactive shell and command execution
ENTRYPOINT ["/entrypoint.sh"]
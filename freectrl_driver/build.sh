#!/bin/bash
# Build script for SteamVR Build Container
# Builds the Docker image, runs basic validation, and optionally pushes to registry

set -euo pipefail

# Configuration
IMAGE_NAME="freectrl-dev"
REGISTRY_IMAGE="registry.home.com/system-utilities/container-registry/steamvr-build-container:latest"
DOCKERFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_RETRIES=3
RETRY_BASE_DELAY=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Retry function with exponential backoff
retry_command() {
    local cmd="$1"
    local description="$2"
    local attempt=1
    local delay=$RETRY_BASE_DELAY

    while [ $attempt -le $MAX_RETRIES ]; do
        log_info "Attempt $attempt/$MAX_RETRIES: $description"
        if eval "$cmd"; then
            log_info "$description succeeded"
            return 0
        else
            log_warn "$description failed (attempt $attempt/$MAX_RETRIES)"
            if [ $attempt -lt $MAX_RETRIES ]; then
                log_info "Waiting ${delay}s before retry..."
                sleep $delay
                delay=$((delay * 2))
            fi
            attempt=$((attempt + 1))
        fi
    done

    log_error "$description failed after $MAX_RETRIES attempts"
    return 1
}

# Build the Docker image
build_image() {
    log_info "Building Docker image: $IMAGE_NAME"
    cd "$DOCKERFILE_DIR"
    docker build -t "$IMAGE_NAME" .
}

# Validate the built image
validate_image() {
    log_info "Validating built image..."

    # Check cmake version
    log_info "Checking cmake version..."
    docker run --rm "$IMAGE_NAME" cmake --version | head -1

    # Check g++ version
    log_info "Checking g++ version..."
    docker run --rm "$IMAGE_NAME" g++ --version | head -1

    # Check OpenVR headers
    log_info "Checking OpenVR headers..."
    docker run --rm "$IMAGE_NAME" ls -la /opt/openvr/headers/
    docker run --rm "$IMAGE_NAME" test -f /opt/openvr/headers/openvr_driver.h
    docker run --rm "$IMAGE_NAME" test -f /opt/openvr/headers/openvr.h
    docker run --rm "$IMAGE_NAME" test -f /opt/openvr/headers/openvr_capi.h

    # Test compile a simple C++17 file with OpenVR headers
    # Note: Only include openvr_driver.h as including both openvr.h and openvr_driver.h causes redefinitions
    log_info "Testing C++17 compilation with OpenVR headers..."
    cat << 'EOF' | docker run --rm -i "$IMAGE_NAME" bash -c 'cat > /tmp/test_openvr.cpp && g++-12 -std=c++17 -I/opt/openvr/headers -c /tmp/test_openvr.cpp -o /tmp/test_openvr.o && echo "Compilation successful"'
#include <openvr_driver.h>
#include <iostream>

int main() {
    std::cout << "OpenVR driver headers work!" << std::endl;
    return 0;
}
EOF

    # Check image size
    log_info "Checking image size..."
    docker images "$IMAGE_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

    log_info "All validations passed!"
}

# Login to registry
registry_login() {
    if [ -z "${GITLAB_TOKEN:-}" ] || [ -z "${GITLAB_USER:-}" ]; then
        log_warn "GITLAB_TOKEN or GITLAB_USER not set. Skipping registry login."
        return 1
    fi

    log_info "Logging into registry.home.com..."
    echo "$GITLAB_TOKEN" | docker login registry.home.com -u "$GITLAB_USER" --password-stdin
}

# Tag and push image to registry
push_image() {
    log_info "Tagging image for registry: $REGISTRY_IMAGE"
    docker tag "$IMAGE_NAME" "$REGISTRY_IMAGE"

    log_info "Pushing image to registry..."
    retry_command "docker push $REGISTRY_IMAGE" "Push image to registry"
}

# Run container interactively
run_interactive() {
    log_info "Starting interactive container..."
    cd "$DOCKERFILE_DIR"
    docker run --rm -it -v "$(pwd):/workspace/freectrl_driver" "$IMAGE_NAME"
}

# Run container with docker-compose
run_compose() {
    log_info "Starting container with docker-compose..."
    cd "$DOCKERFILE_DIR"
    docker-compose up --build -d
    docker-compose exec freectrl-dev bash
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
  build       Build the Docker image (default)
  validate    Validate the built image
  push        Tag and push image to registry (requires GITLAB_TOKEN and GITLAB_USER)
  run         Run container interactively with volume mount
  compose     Run container using docker-compose
  all         Build, validate, and push (if credentials available)
  help        Show this help message

Environment Variables:
  GITLAB_TOKEN    GitLab personal access token for registry authentication
  GITLAB_USER     GitLab username for registry authentication

Examples:
  $0 build
  $0 validate
  $0 run
  $0 push
  $0 all
  GITLAB_TOKEN=xxx GITLAB_USER=yyy $0 push
EOF
}

# Main
main() {
    local command="${1:-build}"

    case "$command" in
        build)
            build_image
            ;;
        validate)
            validate_image
            ;;
        push)
            if registry_login; then
                push_image
            else
                log_error "Registry login failed. Cannot push."
                exit 1
            fi
            ;;
        run)
            run_interactive
            ;;
        compose)
            run_compose
            ;;
        all)
            build_image
            validate_image
            if registry_login; then
                push_image
            else
                log_warn "Registry credentials not available. Skipping push."
            fi
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
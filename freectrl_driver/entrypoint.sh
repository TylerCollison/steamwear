#!/bin/bash
# Entrypoint script for freectrl-dev container
# Allows running commands or starting interactive shell

if [ $# -eq 0 ]; then
    # No arguments: start interactive bash
    exec /bin/bash
else
    # Arguments provided: execute the command
    exec "$@"
fi

#!/usr/bin/env bash
set -euo pipefail

# Responsible for removing the container, and optionally the volume and network

source .env.database
source .env.volume
source .env.network

if [ "$(docker ps -aq -f name="^${DB_CONTAINER_NAME}$")" ]; then
    docker rm -f "$DB_CONTAINER_NAME"
else
    echo "No container named $DB_CONTAINER_NAME. Skipping."
fi

# The volume outlives the container on purpose. Pass --volume to wipe the data.
if [[ "${1:-}" == "--volume" || "${1:-}" == "--all" ]]; then
    if [ "$(docker volume ls -q -f name="^${VOLUME_NAME}$")" ]; then
        docker volume rm "$VOLUME_NAME"
    else
        echo "No volume named $VOLUME_NAME. Skipping."
    fi
fi

if [[ "${1:-}" == "--all" ]]; then
    if [ "$(docker network ls -q -f name="^${NETWORK_NAME}$")" ]; then
        docker network rm "$NETWORK_NAME"
    else
        echo "No network named $NETWORK_NAME. Skipping."
    fi
fi

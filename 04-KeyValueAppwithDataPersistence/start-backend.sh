#!/usr/bin/env bash
set -euo pipefail

# Builds the backend image and runs it on the shared network.
# The database must already be running - the app connects at startup and does not retry.

BACKEND_IMAGE="key-value-backend"
BACKEND_TAG="latest"
BACKEND_CONTAINER_NAME="backend"
BACKEND_CONTEXT="./backend"
BACKEND_DOCKERFILE="Dockerfile.dev"

# Connectivity
source .env.network
source .env.database
LOCALHOST_PORT=3000
CONTAINER_PORT=3000

source setup.sh

if [ "$(docker ps -aq -f name="^${BACKEND_CONTAINER_NAME}$")" ]; then
    echo "A container with the name $BACKEND_CONTAINER_NAME already exists."
    echo "To remove it, run: docker rm -f $BACKEND_CONTAINER_NAME"
    exit 1
fi

if [ -z "$(docker ps -q -f name="^${DB_CONTAINER_NAME}$")" ]; then
    echo "No running container named $DB_CONTAINER_NAME. Start it first: ./start-db.sh"
    exit 1
fi

docker build \
  -f "$BACKEND_CONTEXT/$BACKEND_DOCKERFILE" \
  -t "$BACKEND_IMAGE:$BACKEND_TAG" \
  "$BACKEND_CONTEXT"

docker run -d \
  --name "$BACKEND_CONTAINER_NAME" \
  -p $LOCALHOST_PORT:$CONTAINER_PORT \
  --network $NETWORK_NAME \
  "$BACKEND_IMAGE:$BACKEND_TAG"

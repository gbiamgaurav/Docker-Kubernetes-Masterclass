# 04 - Key/Value App with Data Persistence

MongoDB plus an Express backend, on a shared network. Named volume for the data,
root user plus an app user seeded by an init script.

DB on host port `27017`, backend on `3000`.

Run the steps in order. Each one assumes the previous has completed.

## Files

```
.env.database             DB_CONTAINER_NAME
.env.network              NETWORK_NAME
.env.volume               VOLUME_NAME
setup.sh                  creates the volume and network
start-db.sh               runs the database container
start-backend.sh          builds and runs the backend container
cleanup-db.sh             removes the container, optionally volume and network
db-config/mongo-init.js   seeds the app user on first start
backend/                  Express app, connects to mongodb:27017
```

Names live in `.env.*` so `setup.sh`, `start-db.sh`, `start-backend.sh` and
`cleanup-db.sh` cannot drift apart. A hardcoded name in one script means cleanup
deletes something the other never created.

## 1. Make the scripts executable

```bash
chmod +x setup.sh start-db.sh start-backend.sh cleanup-db.sh
```

Once only. Without it: `permission denied`.

## 2. Create the volume and network

```bash
./setup.sh
```

Idempotent - skips whatever already exists. `./` is required; a bare `setup.sh`
searches `$PATH`, which excludes the current directory:
`zsh: command not found: setup.sh`.

Manual equivalent:

```bash
docker volume create key-value-data
docker network create key-value-net
```

| Command | Why |
| --- | --- |
| `docker volume create` | Optional - `-v name:/path` auto-creates a missing named volume. |
| `docker network create` | Required. `--network` does **not** auto-create: `network key-value-net not found`. |

## 3. Start the database

```bash
./start-db.sh
```

Sources `setup.sh` first, so step 2 is guaranteed even if skipped.

Manual equivalent:

```bash
docker run --rm -d \
  --name mongodb \
  -e MONGODB_INITDB_ROOT_USERNAME=root-user \
  -e MONGODB_INITDB_ROOT_PASSWORD=root-password \
  -e KEY_VALUE_DB=key-value-db \
  -e KEY_VALUE_USER=key-value-user \
  -e KEY_VALUE_PASSWORD=key-value-password \
  -p 27017:27017 \
  -v key-value-data:/data/db/ \
  -v ./db-config/mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js:ro \
  --network key-value-net \
  mongodb/mongodb-community-server:8.0-ubi9-slim
```

| Flag | Why |
| --- | --- |
| `--rm` | Deletes the container when it stops. Prevents `name "/mongodb" is already in use` on the next run. The volume is unaffected. |
| `-d` | Detached. Without it the terminal is held by mongod's log output. |
| `--name mongodb` | Stable name for `exec`, `logs`, `rm`, and for the backend's connection string. Otherwise docker assigns a random one. |
| `MONGODB_INITDB_ROOT_USERNAME` | Creates the root user on first init. Note `USERNAME`, not `USER` - a wrong name is ignored silently and mongo starts with no auth. |
| `MONGODB_INITDB_ROOT_PASSWORD` | Its password. Both are read by the image entrypoint. |
| `KEY_VALUE_DB` / `_USER` / `_PASSWORD` | Not read by mongo. Passed through for `mongo-init.js` via `process.env`. |
| `-p 27017:27017` | Publishes host:container. Without it the container runs but nothing on the host can reach it - `docker ps` shows `27017/tcp` with no `->`. |
| `-v key-value-data:/data/db/` | The persistence. `/data/db` is where mongod writes; without a volume it lives in the container's writable layer and dies with the container. |
| `-v ./db-config/...:ro` | Mounts the seed script. `/docker-entrypoint-initdb.d/` is run by the entrypoint on first init only. `:ro` stops the container writing to your source file. |
| `--network key-value-net` | Own network, so the backend reaches it by the name `mongodb` instead of an IP. |

## 4. Confirm the database is up

```bash
docker ps
docker logs mongodb
docker exec -it mongodb mongosh -u root-user -p root-password
```

| Command | Why |
| --- | --- |
| `docker ps` | Check `STATUS` is `Up` and `PORTS` shows `0.0.0.0:27017->27017/tcp`. |
| `docker logs mongodb` | mongod output. First place to look if the container exits immediately. |
| `docker exec` | Runs a command in the *running* container. `docker run` would start a second one. |
| `-it` | `-i` keeps stdin open, `-t` allocates a TTY. Both needed for an interactive shell. One dash - `-it`, not `--it`. |
| `-u` / `-p` | Credentials. Required once a root user exists; without them commands fail with `requires authentication`. |

App user, seeded by `mongo-init.js`:

```bash
docker exec -it mongodb mongosh \
  -u key-value-user -p key-value-password \
  --authenticationDatabase key-value-db key-value-db
```

`--authenticationDatabase` is where the user is *defined*. The app user lives in
`key-value-db`, not `admin`, so it must be named. Root does not need it.

## 5. Build and run the backend

```bash
./start-backend.sh
```

Refuses to run if `backend` already exists or if `mongodb` is not up, so the two
failure modes in step 6 are caught before the container is created.

Manual equivalent:

```bash
docker build -f backend/Dockerfile.dev -t key-value-backend ./backend
docker run -d --name backend --network key-value-net -p 3000:3000 key-value-backend
```

| Flag | Why |
| --- | --- |
| `-f backend/Dockerfile.dev` | Non-default filename, so it must be named. The path is relative to the shell, not the context. |
| `./backend` | The build context - the last argument, not the Dockerfile. `COPY` sources resolve inside it. |
| `-t key-value-backend` | Tags the image. Otherwise it is ID-only and awkward to run. |
| `--network key-value-net` | **Required.** The app dials `mongodb://mongodb/key-value-db`; that hostname only resolves on the shared network. |
| `-p 3000:3000` | Publishes the API to the host. |

No `--rm` here, unlike the database - a crashed backend is left behind so
`docker logs backend` still works. It has to be removed by hand before the next
run, which is what the name check reports.

The database must already be running - the backend connects at startup and does
not retry.

## 6. Confirm the backend is up

```bash
docker logs backend
curl localhost:3000/health
```

Expect `Connected to DB` then `Listening on port 3000`, and `up` from `/health`.

Two failure modes, distinguishable by the error:

| Log | Meaning |
| --- | --- |
| `MongooseServerSelectionError`, server state `Unknown` | Nothing is listening. The `mongodb` container is not running. |
| `MongoNetworkTimeoutError` against a resolved IP | Something answered but the handshake exceeded `connectTimeoutMS` in `backend/src/server.js`. |

A failed connection logs the error but leaves the process alive without ever
calling `app.listen`, so the container stays `Up` while serving nothing.

## 7. Verify persistence

```bash
docker exec mongodb mongosh -u root-user -p root-password --quiet --eval \
  'db.getSiblingDB("key-value-db").pairs.insertOne({_id:"colour", value:"blue"})'

./cleanup-db.sh
./start-db.sh

docker exec mongodb mongosh -u root-user -p root-password --quiet --eval \
  'JSON.stringify(db.getSiblingDB("key-value-db").pairs.findOne({_id:"colour"}))'
```

Write, destroy the container, recreate, read back. The document survives because
it lives in the volume, not the container. `--eval` runs a statement and exits;
`--quiet` drops the startup banner so the output is parseable.

Restart the backend afterwards - its connection died with the old container:

```bash
docker restart backend
```

## 8. Inspect

```bash
docker volume ls
docker volume inspect key-value-data
docker network ls
docker network inspect key-value-net
```

| Command | Why |
| --- | --- |
| `docker volume ls` | Confirms the volume outlived the container. |
| `docker volume inspect` | Shows the mountpoint on the docker host. |
| `docker network ls` | Confirms the network exists before `start-db.sh`. |
| `docker network inspect` | Lists which containers are attached - both `mongodb` and `backend` should appear. |

## 9. Cleanup

```bash
docker rm -f backend
./cleanup-db.sh            # container only
./cleanup-db.sh --volume   # container + volume (deletes the data)
./cleanup-db.sh --all      # container + volume + network
```

Backend first - `--all` removes the network, which fails while a container is
still attached. Default keeps the data, so a restart resumes where it left off.
`--volume` is not recoverable.

The failure is partial: `--all` deletes the volume before it fails on the
network, so a retry reports `No volume named key-value-data. Skipping.` and
still errors.

### Machine-wide

Not scoped to this project - these hit every image on the machine.

```bash
docker image prune -a              # unused images only; keeps images with containers
docker system prune -a --volumes   # images, containers, networks, build cache, volumes
```

| Command | Why |
| --- | --- |
| `image prune -a` | Frees disk without touching a running stack. `Total reclaimed space: 0B` still means tags were removed - layers shared with a surviving image free no bytes. |
| `system prune -a --volumes` | The full sweep. `--volumes` reaches **named** volumes, so `key-value-data` and its data go with it. |

To remove every image outright, containers first - `rmi -f` forces past *stopped*
containers only:

```bash
docker rm -f $(docker ps -aq)
docker rmi -f $(docker images -aq)
```

A running container still wins:
`conflict: unable to delete <id> (cannot be forced) - image is being used by running container <id>`.
With nothing to delete the substitution is empty and docker reports
`"rmi" requires at least 1 argument`.

## Gotchas

- `NAME="value"` - no spaces around `=`. Same for `-e KEY=value`.
- `--name` not `-name`; `-it` not `--it`. One dash means bundled short flags, two
  means a long name.
- `--name` takes a value, so the image must be a separate argument.
- Volumes and networks are separate namespaces. `docker volume rm key-value-net`
  fails with `no such volume` - networks need `docker network rm`.
- `mongo-init.js` and the root credentials only apply when the data directory is
  empty. To re-seed: `./cleanup-db.sh --volume`.
- Name conflicts count stopped containers - check `docker ps -a`, not `docker ps`.
- Scripts `source .env.*` by relative path, so run them from this directory.
- `docker system prune -a --volumes` destroys `key-value-data`.
- Credentials are hardcoded for local practice only.

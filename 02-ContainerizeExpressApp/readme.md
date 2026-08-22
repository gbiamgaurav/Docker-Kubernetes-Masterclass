# 02 - Containerize an Express App

## Setup

```bash
npm init -y
npm install express@4.19.2 body-parser@1.20.2 --save-exact
```

## Run locally

```bash
node index.js
curl localhost:3000
```

## Build

```bash
docker build -t express-app:1.0 .
```

## Run

```bash
docker run -d -p 3000:3000 --name express_server express-app
docker ps
```

## Test

```bash
curl localhost:3000
curl localhost:3000/users

curl -X POST localhost:3000/users \
  -H 'Content-Type: application/json' \
  -d '{"userId":"Gaurav"}'
```

## Logs and shell

```bash
docker logs -f express_server
docker exec -it express_server sh
```

## Dev loop (bind mount)

```bash
docker rm -f express_server
docker run -d -p 3000:3000 \
  -v "$(pwd):/app" \
  -v /app/node_modules \
  --name express_server express-app:1.0
```

## Names

| Name | What it is | Used by |
|------|-----------|---------|
| `express-app:1.0` | image tag | `build`, `rmi`, `run` |
| `express_server` | container name | `stop`, `start`, `rm`, `logs`, `exec` |

`docker build -t express-app .` with no tag gives `express-app:latest`.

## Lifecycle

```bash
docker stop express_server
docker start express_server
docker restart express_server
```

## Cleanup

Containers first, then images.

```bash
docker stop express_server
docker rm express_server
docker rmi express-app:1.0
```

Force-remove a running container in one step:

```bash
docker rm -f express_server
```

Remove everything for this project:

```bash
docker rm -f express_server
docker rmi express-app:1.0 express-app:latest
```

Reclaim disk:

```bash
docker system df          # what is reclaimable
docker image prune        # dangling images
docker builder prune      # build cache
docker volume prune       # orphaned volumes
```

## Notes

- JSON needs double quotes: `{"userId":"Gaurav"}`, not `{'userId':'Gaurav'}`
- `app.listen(port, '0.0.0.0')` - loopback bind makes `-p` look broken
- `SIGTERM`/`SIGINT` handlers required, else `docker stop` takes 10s
- `.dockerignore` must list `node_modules`
- `npm ci` needs `package-lock.json` committed
- Alpine has no bash - use `sh`
- `stop`/`rm` take container names, `rmi` takes image tags - not interchangeable
- `rmi` fails with `must be forced` while any container references the image
- `rmi` prints nothing on success; a second run gives `No such image`

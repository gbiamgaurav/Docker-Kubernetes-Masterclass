# 03 - Containerize a React App

Build a React + TypeScript app with Vite, serve the compiled bundle from nginx
in a multi-stage image.

Host port `8081`. `01` uses `8080`, `02` uses `3000`.

## Scaffold

```bash
npm create vite@latest . -- --template react-ts
npm install
```

`create-react-app` is deprecated since Feb 2025. `npx create-react-app --template typescript`
also fails with `Please specify the project directory:` - the template flag is not a name.

Trailing `.` scaffolds into the current directory. Vite prompts about the
non-empty folder - pick **Ignore files and continue**, or this Readme is deleted.

## Develop

```bash
npm run dev
```

http://localhost:5173 with HMR. Edit `src/App.tsx` and Vite logs the patch:
`[vite] (client) hmr update /src/App.tsx`. No refresh, no rebuild.

This is the only command with live reload. `Ctrl+C` stops it.

## Build the bundle

```bash
npm run build
```

Type-checks, then bundles to `dist/`. CRA used `build/` - anywhere a CRA-era
tutorial says `build`, read `dist`.

```bash
npx http-server@14.1.1 dist -p 8081 -c-1
```

Serves `dist/` with a plain static server. Pass `dist` explicitly: the root
`index.html` is Vite *source* pointing at `/src/main.tsx`, which browsers cannot
execute. `-c-1` disables the 1-hour default cache, otherwise rebuilds look like
they never landed.

Proves `dist/` is inert static files. nginx does the same job in stage 2.

## Build the image

```bash
docker build -t react-app:nginx .
```

Stage 1 `node:22-alpine` runs `npm ci` and `npm run build`. Stage 2 copies only
`/app/dist` into nginx. Node never ships.

`COPY --from=build /app/dist`, not `/app/build` - the CRA path fails with
`"/app/build": not found` at cache-key computation.

`npm ci` sits above `COPY . .` so editing source invalidates the last two steps
only; the install layer is reused.

```bash
docker images react-app
```

Single-stage was 399MB. Multi-stage on `nginx:1.27.0` is 276MB.
`nginx:1.27.0-alpine` gets it to ~50MB - the Debian base is the remaining bulk.

## Run

```bash
docker run -d -p 8081:80 --name react_server react-app:nginx
curl localhost:8081
open http://localhost:8081
```

`-p 8081:80` host 8081 -> nginx port 80 inside. Expect `HTTP 200`, and the
served `index.html` referencing `/assets/index-<hash>.js` - the compiled bundle,
not `/src/main.tsx`.

## Inspect

```bash
docker logs -f react_server
docker exec -it react_server sh
ls /usr/share/nginx/html
```

The final image holds `index.html` and `assets/` only. No `src`, no
`node_modules`, no node. Alpine has no bash - use `sh`.

## Rebuild after a code change

```bash
docker build -t react-app:nginx .
docker rm -f react_server
docker run -d -p 8081:80 --name react_server react-app:nginx
```

Required for the image; use `npm run dev` while writing code. `rm -f` first or
the name collides: `Conflict. The container name "/react_server" is already in use`.

A bind mount cannot shortcut this the way it did in `02` - nginx serves compiled
output, and nothing in the final image can compile.

## Lifecycle

```bash
docker stop react_server
docker start react_server
docker restart react_server
```

## Cleanup

```bash
docker rm -f react_server
docker rmi react-app:nginx react-app:alpine
docker builder prune
```

Container first - `rmi` fails with `must be forced` while a container references
the image. Multi-stage builds leave large intermediate layers in the cache.

## Clear all images

The commands above are scoped to this project. These are not - they hit every
image on the machine, including ones unrelated to this repo.

```bash
docker image prune -a
```

Removes every image not referenced by a container. This is the one to reach for:
running containers keep their images, so an active stack survives.

`Total reclaimed space: 0B` does not mean nothing was removed. Tags sharing
every layer with an image that survives - `react-app-test` next to
`react-app:nginx` from the same build - free no bytes when dropped.

```bash
docker rm -f $(docker ps -aq)
docker rmi -f $(docker images -aq)
```

Containers first, then images. `-f` on `rmi` forces past *stopped* containers
only - a running one still wins:

```
Error response from daemon: conflict: unable to delete 41cb3402dde4
(cannot be forced) - image is being used by running container b4ba088940da
```

`docker rm -f` is what stops it. On `images`, `-a` includes intermediate and
dangling layers, `-q` reduces the list to IDs. With nothing to delete the
substitution is empty and docker reports `"rmi" requires at least 1 argument`.

```bash
docker system prune -a --volumes
```

Images, stopped containers, networks, build cache, and named volumes. `--volumes`
discards database contents and anything else persisted outside a container.

Everything cleared here is re-pulled or rebuilt on the next `docker build` -
`node:22-alpine` and `nginx:1.27.0` come down from the registry again, and the
layer cache starts cold.

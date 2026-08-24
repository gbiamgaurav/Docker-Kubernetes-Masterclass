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

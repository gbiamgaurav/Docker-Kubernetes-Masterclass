# 01 - Nginx Project

Run nginx in a Docker container and serve a custom page.

## Prompt cheat sheet

| Prompt | Where you are |
|--------|---------------|
| `%` or `$` | Your Mac (host) |
| `#` | Inside the container |

Run every command below from your Mac, one at a time.

Host port `8080` is used throughout so nothing collides with anything already
listening on port 80 on your Mac. Container port stays `80` - that is what nginx
listens on inside the image.

---

## 1. Pull the image

```bash
docker pull nginx:1.27.0
```

Note the spelling: `nginx`, not `ngnix`. A typo gives
`Error response from daemon: pull access denied for ngnix, repository does not exist or may require 'docker login'`

## 2. List local images

```bash
docker images
```

## 3. Run the container

```bash
docker run -d -p 8080:80 --name web_server nginx:1.27.0
```

- `-d` detached (background)
- `-p 8080:80` host port 8080 -> container port 80
- `--name web_server` container name

## 4. List running containers

```bash
docker ps
```

Use `docker ps -a` to include stopped containers.

Check the `PORTS` column. You want:

```
0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
```

If it only says `80/tcp` with no `->`, the port was never published. See
[Troubleshooting](#troubleshooting).

## 5. Verify nginx responds

```bash
curl localhost:8080
```

Or open http://localhost:8080 in a browser.

## 6. Stop and start

```bash
docker stop web_server
docker start web_server
```

---

## Publishing ports: `-p` vs `EXPOSE`

This trips up everyone once.

| | What it does | Where it lives |
|---|---|---|
| `EXPOSE 80` | Documentation only. Records that the app inside listens on 80. Opens nothing on your Mac. | Dockerfile |
| `-p 8080:80` | Actually maps host port 8080 to container port 80. | `docker run`, runtime |

A Dockerfile **cannot** set the host port. That is deliberate - the image has to
stay portable, and the host's free ports differ machine to machine.

There is no `PORT` instruction. Writing `PORT 8080` in a Dockerfile fails the build:

```
dockerfile parse error on line 7: unknown instruction: PORT
```

The `nginx:1.27.0` base image already contains `EXPOSE 80`, which is why a
container started with no `-p` still shows `80/tcp` in `docker ps` - exposed, but
not published, so nothing answers on your Mac.

### Auto-publish with `-P`

Capital `-P` publishes every `EXPOSE`d port to a random free host port:

```bash
docker run -d -P --name web_server nginx:1.27.0
docker port web_server        # shows which host port you got
```

### Pinning the port in a file instead of the command

Use Compose when you are tired of retyping `-p`:

```yaml
# compose.yaml
services:
  web:
    build: .
    ports:
      - "8080:80"
```

```bash
docker compose up -d
```

---

## Editing the served page

The web root `/usr/share/nginx/html` exists **inside the container**, not on your Mac.
Running `cat /usr/share/nginx/html/index.html` on the host gives `No such file or directory`.

The default page shipped in the image looks like this:

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

### Option A - one-liner from the host (simplest, single line only)

```bash
docker exec web_server ls /usr/share/nginx/html
docker exec web_server cat /usr/share/nginx/html/index.html
docker exec web_server sh -c 'echo "<h1>Hello Gaurav</h1>" > /usr/share/nginx/html/index.html'
curl localhost:8080
```

### Option B - heredoc, write the whole file in one command

`echo` is awkward for multi-line HTML. Paste this entire block at once - it is a single command:

```bash
docker exec -i web_server sh -c 'cat > /usr/share/nginx/html/index.html' <<'EOF'
<!DOCTYPE html>
<html>
<head>
<title>Gaurav's Nginx</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Hello Gaurav!</h1>
<p>Nginx 1.27.0 running in Docker.</p>
<p><em>Docker-Kubernetes-Masterclass</em></p>
</body>
</html>
EOF
```

Verify:

```bash
curl localhost:8080
```

### Option C - interactive shell

```bash
docker exec -it web_server sh
```

Now the prompt is `#`. Inside:

```sh
cat /usr/share/nginx/html/index.html
echo "<h1>Hello Gaurav</h1>" > /usr/share/nginx/html/index.html
exit
```

Do not type `docker ...` while inside the container - it is not installed there and gives `sh: docker: not found`.

### Option D - copy out, edit in VS Code, copy back

Best when you want real editing with syntax highlighting.

```bash
# 1. pull the file onto your Mac
docker cp web_server:/usr/share/nginx/html/index.html ./index.html

# 2. open it in VS Code, edit, save with Cmd+S
code index.html

# 3. push it back into the container
docker cp ./index.html web_server:/usr/share/nginx/html/index.html

# 4. verify
curl localhost:8080
```

### Option E - bind mount (best for development)

Mount this project's `index.html` straight over the one in the image:

```bash
docker rm -f web_server
docker run -d -p 8080:80 \
  -v "$(pwd)/index.html:/usr/share/nginx/html/index.html" \
  --name web_server nginx:1.27.0
```

Edit `index.html` on your Mac, hit refresh - no rebuild, no restart.

---

## Using an editor inside the container

The nginx image ships without vim or nano. Install one:

```sh
apt-get update
apt-get install -y vim     # or: apt-get install -y nano
vim /usr/share/nginx/html/index.html
```

`apt-get update vim` is not a valid command - `update` and `install` are separate subcommands.

### Minimum vim survival kit

| Key | Action |
|-----|--------|
| `i` | insert mode (start typing) |
| `Esc` | back to normal mode |
| `:w` | save |
| `:q` | quit |
| `:wq` | save and quit |
| `:q!` | quit, discard changes |
| `dd` | delete line |
| `u` | undo |

---

## Making the change permanent

Container edits vanish when the container is removed or recreated. Bake the page
into an image instead. This is what the `Dockerfile` in this folder does:

```dockerfile
FROM nginx:1.27.0

RUN apt-get update && apt-get install -y vim \
    && rm -rf /var/lib/apt/lists/*

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

Two details worth copying into your own images:

- **One `RUN`, not two.** Split across layers, a cached `apt-get update` goes
  stale and the later `install` reads an outdated package index. Chaining them
  keeps update and install in the same layer. `rm -rf /var/lib/apt/lists/*` drops
  the package index afterwards so it never ships in the image.
- **`COPY` last.** Layers rebuild from the first change onward. With `COPY` after
  `RUN`, editing `index.html` reuses the cached apt layer and the build takes
  about a second.

Build and run:

```bash
docker build -t web_server .
docker rm -f web_server
docker run -d -p 8080:80 --name web_server web_server
curl localhost:8080
```

Note that `web_server` is now both an image tag and a container name. Docker keeps
those in separate namespaces so it works, but see the ID section below before you
start deleting things.

---

## Troubleshooting

### Nothing loads on http://localhost:8080

Check `docker ps` first.

| What you see | Meaning | Fix |
|---|---|---|
| No rows at all | Container not running | `docker ps -a` to find it, then `docker start web_server`, or `docker run ...` again |
| `PORTS` shows `80/tcp` | Exposed, not published - you forgot `-p` | `docker rm -f web_server` then rerun with `-p 8080:80` |
| `PORTS` shows `0.0.0.0:8080->80/tcp` | Mapping is fine | Problem is elsewhere - check `docker logs web_server` |

A container removed with `docker rm -f` does not come back on its own. Recreating
it means a full `docker run` again, not `docker start`.

### Image IDs and container IDs are not interchangeable

```
$ docker stop 4bed162d589b
Error response from daemon: No such container: 4bed162d589b

$ docker stop web_server:latest
Error response from daemon: No such container: web_server:latest
```

`docker stop` takes a container ID or container name. `4bed162d589b` is an image
ID; `web_server:latest` is an image tag. Adding `:latest` makes the argument
unambiguously an image reference, so the container lookup fails even though a
container named `web_server` exists.

- Container IDs and names come from `docker ps`
- Image IDs and tags come from `docker images`

Never cross them.

### `unable to delete ... (must be forced)`

```
$ docker rmi web_server:latest
Error response from daemon: conflict: unable to delete web_server:latest (must be forced) - container ec0da47c32b6 is using its referenced image 4bed162d589b
```

An image cannot be deleted while a container references it, running or stopped.
Remove the container first:

```bash
docker rm -f web_server
docker rmi web_server:latest
```

### `docker images` shows an ID that `docker rmi` says does not exist

Each `docker build` with the same tag produces a **new** image and moves the tag
to it. The previous image loses its tag, becomes dangling, and may be cleaned up.
If your terminal is showing output from before a rebuild, the ID on screen is
stale. Re-run `docker images` for the current one.

### Image is much larger than the base

```
IMAGE               ID             DISK USAGE   CONTENT SIZE
web_server:latest   4bed162d589b        336MB         81.4MB
```

`nginx:1.27.0` is roughly 81MB. The rest is the `apt-get` + vim layer. Drop that
`RUN` line once you no longer need an editor inside the container and the image
returns to about 81MB.

---

## Cleanup

Order matters - containers before images.

```bash
docker stop web_server        # or skip straight to rm -f
docker rm web_server
docker rmi web_server:latest
docker rmi nginx:1.27.0       # the base image, if you want it gone too
```

Force-remove a running container in one step:

```bash
docker rm -f web_server
```

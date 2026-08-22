# 01 - Nginx Project

Run nginx in a Docker container and serve a custom page.

## Prompt cheat sheet

| Prompt | Where you are |
|--------|---------------|
| `%` or `$` | Your Mac (host) |
| `#` | Inside the container |

Run every command below from your Mac, one at a time.

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
docker run -d -p 80:80 --name web_server nginx:1.27.0
```

- `-d` detached (background)
- `-p 80:80` host port 80 -> container port 80
- `--name web_server` container name

## 4. List running containers

```bash
docker ps
```

Use `docker ps -a` to include stopped containers.

## 5. Verify nginx responds

```bash
curl localhost:80
```

Or open http://localhost in a browser.

## 6. Stop and start

```bash
docker stop web_server
docker start web_server
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
curl localhost:80
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
curl localhost:80
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
curl localhost:80
```

### Option E - bind mount (best for development)

```bash
mkdir -p html
echo "<h1>Hello Gaurav</h1>" > html/index.html
docker rm -f web_server
docker run -d -p 80:80 -v "$(pwd)/html:/usr/share/nginx/html" --name web_server nginx:1.27.0
```

Edits to `html/index.html` on your Mac appear immediately in the container.

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

Container edits vanish when the container is removed or recreated. Bake the page into an image instead.

Start from the current page so you keep your edits:

```bash
mkdir -p html
docker cp web_server:/usr/share/nginx/html/index.html ./html/index.html
code html/index.html
```

`Dockerfile`:

```dockerfile
FROM nginx:1.27.0
COPY html/ /usr/share/nginx/html/
```

Build and run:

```bash
docker build -t my-nginx:1.0 .
docker rm -f web_server
docker run -d -p 80:80 --name web_server my-nginx:1.0
curl localhost:80
```

---

## Cleanup

```bash
docker stop web_server
docker rm web_server
docker rmi nginx:1.27.0
```

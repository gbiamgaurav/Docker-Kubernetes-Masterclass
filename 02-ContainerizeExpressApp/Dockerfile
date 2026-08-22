FROM node:22-alpine

WORKDIR /app

# Manifests first: this layer is keyed to the lockfile alone, so editing
# application code below does not re-run the dependency install.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Application code last - the layer that changes most often.
COPY . .

# Drop root. The node image ships an unprivileged `node` user.
USER node

# Documentation only. Publishing still needs -p at runtime.
EXPOSE 3000

# Exec form so node is PID 1 and receives SIGTERM on `docker stop`.
CMD ["node", "index.js"]

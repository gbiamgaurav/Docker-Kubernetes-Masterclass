FROM nginx:1.27.0

RUN apt-get update && apt-get install -y vim \
    && rm -rf /var/lib/apt/lists/*

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

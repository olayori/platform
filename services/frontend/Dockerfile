# Unprivileged nginx: already runs as non-root and listens on 8080.
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Replace the default server block with ours.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Static assets.
COPY src/ /usr/share/nginx/html/

EXPOSE 8080
#

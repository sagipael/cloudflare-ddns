FROM alpine:latest

RUN apk add --no-cache curl bash jq nano certbot certbot-dns-cloudflare


COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]

LABEL org.opencontainers.image.source https://github.com/sagipael/cloudflare-ddns

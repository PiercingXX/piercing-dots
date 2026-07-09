FROM caddy:2.9.1-builder-alpine AS builder
RUN xcaddy build --with github.com/mholt/caddy-l4@87e3e5e2c7f986b34c0df373a5799670d7b8ca03

FROM caddy:2.9.1-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
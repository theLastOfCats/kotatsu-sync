FROM docker.io/library/rust:1.100.0-trixie AS build
RUN apt-get update && apt-get install -y --no-install-recommends cmake \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY templates ./templates
RUN cargo build --locked --release

FROM docker.io/library/debian:trixie-slim
LABEL org.opencontainers.image.source="https://github.com/theLastOfCats/kotatsu-sync"
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /app/target/release/kotatsu-sync /usr/local/bin/kotatsu-sync
RUN install -d -m 0700 -o 65532 -g 65532 /data
USER 65532:65532
ENV BIND_ADDRESS=0.0.0.0 DATABASE_PATH=/data/kotatsu.sqlite
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/kotatsu-sync"]

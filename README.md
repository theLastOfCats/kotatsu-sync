# Kotatsu Sync

Self-hosted sync for the Kotatsu Android reader: accounts, reading history, favourites, and categories. Runs on SQLite by default, with optional MySQL storage. The Rust/Axum implementation was extracted from [the sync server experiments](https://github.com/theLastOfCats/kotatsu-syncserver-experiments), which also hosts the [HTTP contract scenarios](https://github.com/theLastOfCats/kotatsu-syncserver-experiments/tree/main/contract-tests).

## Run

```sh
printf 'JWT_SECRET=%s\nBASE_URL=https://sync.example.org\n' "$(openssl rand -hex 32)" > .env
chmod 600 .env
docker run -d --name kotatsu-sync --restart unless-stopped \
  --env-file .env -p 127.0.0.1:8080:8080 \
  -v kotatsu-sync-data:/data ghcr.io/thelastofcats/kotatsu-sync:v1.0.0
curl -fsS http://127.0.0.1:8080/ # Alive
```

GitHub Actions builds `linux/amd64` and `linux/arm64` images. On `master` it publishes `ghcr.io/thelastofcats/kotatsu-sync:latest` (also tagged `master`); a Git tag such as `v1.0.0` publishes the matching image tag. Published images also get a `sha-<commit>` tag and build provenance. To build locally instead, run `docker build -t kotatsu-sync:local .` and use that image in `docker run`.

Put it behind an HTTPS reverse proxy. `BASE_URL` is the public origin used in password-reset links. Keep the signing secret and database volume across releases; back up SQLite with its online backup API (or `sqlite3 .backup`), not by copying just the main file while the server is running. An existing bind-mounted directory must be writable by container UID/GID `65532`.

For a native build, use Rust 1.100 or newer, a C toolchain, and CMake: `cargo build --locked --release`. Native runs bind `127.0.0.1` by default; the container binds `0.0.0.0`. Set `PORT` to override `8080` and `DATABASE_PATH` to set the SQLite path. `DATABASE_DIALECT=mysql` uses `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, and `DATABASE_PASSWORD` instead.

`ALLOW_NEW_REGISTER=false` disables new accounts without disabling login. Set `TRUSTED_PROXY_IP` only if the reverse proxy has a fixed, dedicated peer IP and overwrites `X-Forwarded-For` with the connecting client's IP. For Caddy, use `header_up X-Forwarded-For {remote_host}` inside `reverse_proxy`. Without a trusted peer configured, the per-IP auth limits use the direct connection address. The global API limit applies in either case.

### Password recovery

Set `MAIL_PROVIDER=smtp`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_FROM`, and, for authenticated SMTP, `SMTP_USERNAME` and `SMTP_PASSWORD`. Port 587 with a username requires STARTTLS; port 465 uses implicit TLS. The former Go service called the username setting `SMTP_USER`. With `MAIL_PROVIDER=console` (the local default), reset links go to process logs, not an email inbox. Use real SMTP for production.

The original Go server and Kotatsu Sync use different database layouts. For a fresh replacement, use a new database path and keep the Go database untouched. Go-issued session tokens aren't accepted; sign in again after switching servers.

The service is distributed under the [GNU GPL v3](LICENSE).

## Verify released artifacts

[GitHub releases](https://github.com/theLastOfCats/kotatsu-sync/releases) include standalone GNU/Linux binaries (`kotatsu-sync-linux-amd64` and `kotatsu-sync-linux-arm64`) and `SHA256SUMS`. The binaries are extracted from the released images and dynamically linked against glibc. After downloading, run `chmod +x kotatsu-sync-linux-<arch>` to make the selected binary executable.

Verify release provenance with the GitHub CLI:

```sh
gh attestation verify oci://ghcr.io/thelastofcats/kotatsu-sync:v1.0.0 \
  --repo theLastOfCats/kotatsu-sync --source-ref refs/tags/v1.0.0
gh attestation verify ./kotatsu-sync-linux-amd64 \
  --repo theLastOfCats/kotatsu-sync --source-ref refs/tags/v1.0.0
```


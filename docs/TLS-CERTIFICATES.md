# TLS Certificates

Operator reference for the `cardalmanac.com` production certificate: where it lives,
how it renews, how to renew it by hand, and what a brand-new host needs before it can
serve HTTPS.

This covers **production only**. Local development uses a self-signed certificate — see
[LOCAL-ENVIRONMENTS.md](LOCAL-ENVIRONMENTS.md).

## Where the certificate lives

The certificate is issued by Let's Encrypt via certbot and stored on a **mounted volume**,
not inside the container image. It therefore survives container recreation.

| Path                             | What it is                                                                                    |
| -------------------------------- | --------------------------------------------------------------------------------------------- |
| `/mnt/cardalmanac/certs`         | DigitalOcean block volume attached to the host                                                |
| `/var/www/cardalmanac.com/certs` | Symlink to the above, created by `.docker/scripts/deploy.sh`                                  |
| `/etc/letsencrypt`               | Where the symlinked path is mounted inside the container (`.docker/prod.docker-compose.yaml`) |

Because the certificate is on the volume, every container restart already finds a valid
certificate on disk. The container does no certificate work at startup.

## nginx will not start without a certificate

`.docker/config/nginx-site-prod.conf` hard-references the certificate files:

```nginx
ssl_certificate     /etc/letsencrypt/live/cardalmanac.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/cardalmanac.com/privkey.pem;
```

If those files are absent, nginx fails to start and the container cannot serve traffic.
This is what makes the one-time bootstrap below a real provisioning prerequisite rather
than a nicety.

## Automatic renewal

Renewal runs out-of-band in GitHub Actions, not in the container entrypoint:

-   **Workflow:** `.github/workflows/renew-certificate.yaml`
-   **Schedule:** twice daily (`cron: "17 3,15 * * *"`). A run is a no-op unless the
    certificate is inside its 30-day renewal window.
-   **Manual trigger:** `workflow_dispatch` — use this for an immediate check.

    ```bash
    gh workflow run renew-certificate.yaml -R cardtechie/cardalmanac-app
    ```

The workflow SSHes to the host, runs `certbot renew` inside the **running** container, and
then independently verifies the certificate nginx is actually serving over TLS. The renewal
profile carries `renew_hook = service nginx reload`, so a new certificate is picked up
without a restart and without downtime. On failure the workflow files or comments on a
GitHub issue.

> **This workflow is now the only automated renewal path.** Since #407 the container no
> longer runs certbot at startup, so if the scheduled workflow stops firing, nothing else
> will renew the certificate. Note that GitHub disables `schedule` triggers on repositories
> with no activity for 60 days. If the repository ever goes quiet for an extended period,
> confirm the workflow is still enabled — or renew by hand using the commands below.

## Manual renewal

To renew by hand on the host:

```bash
container=$(docker ps \
  --filter "label=com.docker.compose.project=cardalmanaccom" \
  --format '{{.Names}}' | head -n 1)

docker exec "$container" certbot renew --no-random-sleep-on-renew
docker exec "$container" certbot certificates
```

`--no-random-sleep-on-renew` drops certbot's 0–8 minute jitter, which exists only to spread
load across large cron fleets and just burns time here.

`.docker/scripts/install-cert.sh` also performs a renewal when a certificate already exists,
and remains available to run by hand:

```bash
docker exec "$container" /var/www/app/.docker/scripts/install-cert.sh
```

To check what is actually being served, from anywhere:

```bash
echo | openssl s_client -servername cardalmanac.com -connect cardalmanac.com:443 2>/dev/null \
  | openssl x509 -noout -enddate -fingerprint
```

## The container entrypoint does _not_ renew (#407)

`.docker/scripts/update.entrypoint.sh` used to call `install-cert.sh` on every container
start. That call was removed because it bought nothing and cost two real failure modes:

1. **Unpredictable restart downtime.** `certbot renew` sleeps up to ~8 minutes of jitter,
   and the call sat _before_ `exec "$@"` — the line that starts supervisord and therefore
   nginx. Measured 2026-08-09: container recreated 21:35:58Z, first HTTP 200 at 21:43:58Z,
   8m00s of hard downtime, essentially all of it sleeping.
2. **A certbot failure blocked the boot entirely.** The entrypoint runs under `set -ex` and
   the call had no `|| true`, so any non-zero exit from certbot aborted the script before
   `exec "$@"` and the container never came up. That made Let's Encrypt availability a hard
   prerequisite for the site booting.

Since the certificate is already on the mounted volume at every restart and the scheduled
workflow keeps it renewed, the entrypoint call was pure redundancy.

## Bootstrapping a brand-new host

**This is now an explicit provisioning step.** On a host with an empty certificate volume
there is no certificate on disk, nginx will not start, and nothing in the container will
obtain one for you. A certificate must exist under `/mnt/cardalmanac/certs` before the
container can serve HTTPS.

Order of operations on a new host:

1. Run `.docker/scripts/deploy.sh` far enough to create the `/var/www/cardalmanac.com/certs`
   → `/mnt/cardalmanac/certs` symlink.
2. Obtain a certificate for `cardalmanac.com` into that volume. Ports 80 and 443 must be
   reachable from the internet for the ACME challenge, and DNS must already point at the
   host.
3. Confirm `/mnt/cardalmanac/certs/live/cardalmanac.com/fullchain.pem` exists.
4. Start the container. nginx now finds the certificate and comes up.
5. Trigger `renew-certificate.yaml` via `workflow_dispatch` to confirm the scheduled
   renewal path works against the new host.

### Caveat: the first-issuance path is unproven

`.docker/scripts/install-cert.sh`'s `else` branch — the one that runs when no certificate
exists — invokes:

```sh
certbot --nginx -m josh@picklewagon.com -d cardalmanac.com --agree-tos certonly
```

The `--nginx` authenticator needs a **running** nginx, but on a new host nginx cannot start
until the certificate exists. That is a chicken-and-egg problem, and it is pre-existing:
the current production host's certificates predate this script and simply persist on the
volume, so this branch has never actually been exercised in its current form.

Treat step 2 above as needing a working method rather than an established one. A standalone
issuance (for example `certbot certonly --standalone`, with nginx stopped and port 80 free)
writing into the mounted volume is the likely shape, but it has not been validated here.
Reworking `install-cert.sh` for first issuance is tracked separately and is out of scope
for #407.

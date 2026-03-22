# Jackett + Gluetun + ProtonVPN + FlareSolverr

This setup routes **only Jackett’s outbound tracker/indexer requests** through a VPN-backed HTTP proxy provided by Gluetun.

It is designed for a media stack where:
- `jackett` must remain reachable by `sonarr` and `radarr`
- `flaresolverr` must remain reachable by `jackett`
- only tracker/index-site access should use the VPN
- other containers on the same Docker network should **not** automatically use the VPN

This project uses:
- **ProtonVPN WireGuard** for the VPN tunnel
- **Gluetun** as the VPN client
- **Gluetun HTTP proxy** so Jackett can use a normal HTTP proxy instead of needing native VPN support
- **FlareSolverr** for Cloudflare-protected indexers
- **Jackett** as the indexer aggregation service

---

## Why this design

Jackett supports proxy settings such as HTTP, SOCKS4, and SOCKS5, but it does not natively terminate a VPN tunnel itself. Gluetun solves this by connecting to ProtonVPN and exposing an internal HTTP proxy that Jackett can use.

This means:
- Jackett traffic to indexers goes through `gluetun`
- Sonarr and Radarr still talk to Jackett normally over Docker networking
- Deluge or other download clients are unaffected unless you explicitly configure them to use the proxy or VPN

So this is **not** “the whole Docker network uses the VPN”.

Only applications configured to use `http://gluetun:8888` will send outbound traffic through the VPN.

---

## Architecture

```text
                         +----------------------+
                         |  Sonarr / Radarr     |
                         |  normal local access |
                         +----------+-----------+
                                    |
                                    | HTTP to Jackett
                                    v
                         +----------------------+
                         |       Jackett        |
                         |  Web UI: :9117       |
                         |  Proxy: gluetun:8888 |
                         +----------+-----------+
                                    |
                     normal API      | FlareSolverr API
                     requests        v
                         +----------------------+
                         |    FlareSolverr      |
                         |  API: :8191/v1       |
                         +----------------------+

                Jackett outbound indexer requests
                and FlareSolverr browser sessions
                           use HTTP proxy
                                    |
                                    v
                         +----------------------+
                         |       Gluetun        |
                         |  HTTP Proxy :8888    |
                         |  WireGuard client    |
                         +----------+-----------+
                                    |
                                    | encrypted tunnel
                                    v
                         +----------------------+
                         |      ProtonVPN       |
                         |   Free WireGuard     |
                         +----------------------+
```

---

## Components

### Jackett
Jackett remains on your normal `public_facing` Docker network and exposes port `9117`.

Sonarr and Radarr continue to access Jackett exactly as before.

### FlareSolverr
FlareSolverr stays on the same Docker network and is configured in Jackett using:

- `FlareSolverr API URL: http://flaresolverr:8191/v1`
- `FlareSolverr Max Timeout (ms): 90000`

A higher timeout may be required for some Cloudflare-protected sites.

### Gluetun
Gluetun connects to ProtonVPN using a WireGuard private key and exposes an internal HTTP proxy on port `8888`.

That proxy is only meant for other containers on the Docker network unless you explicitly publish the port to the host.

### ProtonVPN
This setup uses a ProtonVPN WireGuard configuration generated from the ProtonVPN dashboard.

The important value for Gluetun is the WireGuard `PrivateKey` from the generated config.

---

## ProtonVPN setup

### 1. Create a ProtonVPN account
Create or log in to your ProtonVPN account.

### 2. Generate a WireGuard configuration
In the ProtonVPN dashboard:
- go to **Downloads**
- open **WireGuard configuration**
- create a config for Linux

You will receive a config that looks like this:

```ini
[Interface]
PrivateKey = <your_private_key>
Address = 10.x.x.x/32
DNS = 10.x.x.x

[Peer]
PublicKey = <peer_public_key>
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = <server_ip>:51820
PersistentKeepalive = 25
```

### 3. Take the private key
For the simplified Gluetun setup in this project, the main value you need is:

- `PrivateKey = ...`

That value becomes:

```env
WIREGUARD_PRIVATE_KEY=your_private_key_here
```

---

## File layout

Example project directory:

```text
jackett_radarr_sonarr/
├── docker-compose.yml
├── .env
└── README.md
```

---

## .env file

Create a `.env` file in the same directory as `docker-compose.yml`:

```env
WIREGUARD_PRIVATE_KEY=your_private_key_here
```

Example:

```env
WIREGUARD_PRIVATE_KEY=REPLACE_WITH_YOUR_KEY
```

Do **not** commit this file to Git.

---

## Jackett configuration

Open the Jackett UI and configure the following.

### Proxy settings

Set:

- **Proxy type:** `HTTP`
- **Proxy URL:** `http://gluetun`
- **Proxy port:** `8888`
- **Proxy username:** leave blank
- **Proxy password:** leave blank

This works because Gluetun is exposing an internal HTTP proxy on the shared Docker network.

### FlareSolverr settings

Set:

- **FlareSolverr API URL:** `http://flaresolverr:8191/v1`
- **FlareSolverr Max Timeout (ms):** `90000`

If some indexers are fast, lower values may still work, but `90000` is safer for sites that delay Cloudflare checks.

---

## How traffic flows

### Normal app-to-app traffic
- Sonarr -> Jackett
- Radarr -> Jackett
- Jackett -> FlareSolverr API

This traffic stays on the local Docker network.

### VPN-routed traffic
- Jackett -> tracker/index site via `http://gluetun:8888`
- FlareSolverr browser traffic -> tracker/index site via `http://gluetun:8888` when proxying is used through Jackett’s FlareSolverr integration

So the VPN is only used for outbound website access, not for all inter-container communication.

---

## Bring the stack up

From the directory containing `docker-compose.yml`:

```bash
docker compose pull
docker compose up -d
```

To restart specific services:

```bash
docker compose restart gluetun jackett flaresolverr
```

To recreate only Gluetun:

```bash
docker compose up -d --force-recreate gluetun
```

---

## Verification

### 1. Confirm Gluetun is connected
Check the logs:

```bash
docker logs -f gluetun
```

You want to see messages indicating the VPN tunnel is established.

### 2. Confirm FlareSolverr is alive
From the host:

```bash
docker exec -it jackett curl -i http://flaresolverr:8191/
```

You should get a `200 OK` response with a JSON message such as:

```json
{"msg":"FlareSolverr is ready!"}
```

### 3. Confirm the proxy changes the IP
Check your host IP:

```bash
curl https://ifconfig.me
```

Now check from inside Jackett through the Gluetun proxy:

```bash
docker exec -it jackett curl -x http://gluetun:8888 https://ifconfig.me
```

The second IP should be different from your host IP.

### 4. Confirm FlareSolverr works through the proxy
Test with a page often used for Cloudflare checks:

```bash
docker exec jackett curl -sSLX POST http://flaresolverr:8191/v1 \
  -H 'Content-Type: application/json' \
  --data-raw '{
    "cmd": "request.get",
    "url": "https://nowsecure.nl",
    "maxTimeout": 90000,
    "proxy": {"url": "http://gluetun:8888"}
  }' | jq -r '.status'
```

Expected output:

```text
ok
```

If `jq` is not installed:

```bash
docker exec jackett curl -sSLX POST http://flaresolverr:8191/v1 \
  -H 'Content-Type: application/json' \
  --data-raw '{
    "cmd": "request.get",
    "url": "https://nowsecure.nl",
    "maxTimeout": 90000,
    "proxy": {"url": "http://gluetun:8888"}
  }' | python3 -c 'import sys,json; print(json.load(sys.stdin)["status"])'
```

---

## Useful log commands

Tail logs live:

```bash
docker logs -f gluetun
docker logs -f jackett
docker logs -f flaresolverr
```

Compose-based:

```bash
docker compose logs -f gluetun jackett flaresolverr
```

---

## Notes

### Free VPN limitations
Free ProtonVPN servers can be slower or more likely to hit stricter anti-bot protection.

If a specific country works better, try:

```yaml
- SERVER_COUNTRIES=Netherlands
```

or another free country.

### Timeout tuning
Some sites need longer than 55 seconds for FlareSolverr to complete.

If an indexer times out in FlareSolverr but works manually with a larger timeout, increase Jackett’s FlareSolverr timeout.

### Tracker-specific breakage
If one tracker still fails while others work, the problem may be the tracker definition, mirror, or site path rather than your VPN or proxy setup.

In those cases:
- remove and re-add the indexer
- try another site link or mirror
- check Jackett logs
- test the same site manually with FlareSolverr

---

## Security notes

- Keep `.env` private
- Do not expose Gluetun’s proxy to the public internet unless you intentionally want host access
- Use strong Docker/network isolation
- Remember that only apps explicitly configured to use the proxy will use the VPN

---

## Summary

This setup keeps your media stack simple:

- Jackett stays reachable by Sonarr and Radarr
- FlareSolverr stays reachable by Jackett
- only tracker/indexing traffic uses the VPN
- the VPN credentials stay outside compose in `.env`
- the rest of the Docker network behaves normally

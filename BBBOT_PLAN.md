# BBBot Project Plan

BBBot is a personal AI assistant running on OpenClaw in Docker (Colima),
accessible via Telegram (@JOSiiiBot).

## Current State

- **Runtime**: Docker via Colima on josmp25
- **Models**: Gemini 2.5 Pro (primary), Claude Sonnet 4.6, Claude Haiku 4.5, Gemini 2.5 Flash
- **Channel**: Telegram DM
- **Tools installed**: Go 1.24.1, build-essential, python3, libavahi-compat-libdnssd-dev
- **Go tools**: mctofu/homekit (HomeKit CLI, persistent in named Docker volume)

## Project 1: HomeKit Control Interface

### Goal
Voice and text control of Apple HomeKit devices via Telegram.
"Turn off the lights", "lock the front door", "what's the temperature?"

### Discovered Devices (2026-03-27)
| Device | IP | Port | Network |
|--------|-----|------|---------|
| HomePod (Bedroom) | 192.168.86.50 | 56680 | josgoogle |
| Circle View Camera | 192.168.86.26 | 49152 | josgoogle |
| Circle View Doorbell | 192.168.86.24 | 49152 | josgoogle |
| Nanoleaf Elements | 192.168.1.183 | 6517 | danny |
| ~9 HomePod sensors | 192.168.86.x | various | josgoogle |

### Known Limitations
- mDNS discovery doesn't work from Docker (Colima VM blocks multicast)
- Must use direct IP connections or run discovery on Mac host
- HomeKit pairing requires initial setup per device

### Next Steps
- [ ] Pair with a test device via mctofu/homekit using direct IP
- [ ] Build a device registry (IP, port, paired key) persisted in workspace
- [ ] Create BBBot commands: /lights, /lock, /temp, /devices
- [ ] Voice message support (Telegram voice notes -> transcription -> command parsing)
- [ ] Investigate HomeKit pairing persistence across container restarts

## Project 2: Network Upgrade

### Goal
Replace Google WiFi (2016, no bridge mode, no band control) with Netgear Orbi 970
to unify home network and enable IoT device management.

### Current Network Problems
- Two subnets: danny (192.168.1.x, AT&T modem) and josgoogle (192.168.86.x, Google WiFi)
- No bridge mode on Google WiFi — can't unify to one subnet
- Printing only works on danny subnet
- HomePod Minis land on different networks, breaking multi-room audio
- Nanoleaf Elements (2.4 GHz only) can't connect via Google WiFi band steering
- AT&T modem too far from Nanoleaf for direct 2.4 GHz connection

### Planned Fix: Netgear Orbi 970 (3-pack)
- Bridge mode: Orbi handles WiFi only, AT&T modem remains the router
- Single subnet (192.168.1.x) for all devices
- Dedicated IoT SSID locked to 2.4 GHz for Nanoleaf and other IoT devices
- WiFi 7, quad-band, ~$2,300

### Expected Improvements
- [x] Printing from any device (single subnet)
- [x] Multi-room HomePod audio (all on same subnet, multicast works)
- [x] mDNS/Bonjour discovery across all devices
- [x] Nanoleaf reconnection without disabling networks
- [ ] Potentially: mDNS discovery from Docker if Colima can bridge to host network

## Project 3: Network Monitoring via BBBot

### Goal
BBBot monitors the home network and alerts via Telegram on issues.

### Capabilities (Orbi 970 SOAP API)
The Orbi 970 exposes a local SOAP API (port 5000) that supports:
- List attached devices (IP, MAC, name, signal, type, SSID, connected AP)
- Traffic monitoring
- Device allow/block

Libraries: [pynetgear](https://github.com/MatMaul/pynetgear) (Python),
[netgear_client](https://github.com/DRuggeri/netgear_client) (Go),
[netgear](https://www.npmjs.com/package/netgear) (Node.js)

### Monitoring Features
- [ ] **Device health**: periodic ping/TCP check of HomeKit devices, alert on Telegram if any go offline
- [ ] **New device alerts**: poll Orbi for attached devices, alert on unknown MAC addresses
- [ ] **Network status**: alert if Orbi satellite nodes lose connection
- [ ] **Nanoleaf watchdog**: detect when Elements drops off, alert with reconnection instructions
- [ ] **Bandwidth alerts**: notify on unusual traffic spikes (possible compromise)

### Security Features (Orbi 970)
**Built-in (free):**
- WPA3 encryption
- IoT VLAN (network isolation between IoT and primary devices)
- Guest network with device isolation
- Automatic firmware updates
- WireGuard VPN server

**NETGEAR Armor (Bitdefender, free 1 year then $100/yr):**
- Real-time threat/phishing/botnet blocking at router level
- Vulnerability scanning + weekly security reports
- New device join alerts
- Brute force protection

### Implementation Approach
- Use pynetgear or netgear npm package from within Docker container
- Poll Orbi SOAP API on interval (every 5 min for devices, every 30 min for traffic)
- BBBot sends alerts via existing Telegram channel
- Store known-device registry in workspace for diffing

## Project 4: Gmail Integration

### Goal
BBBot receives, triages, and acts on incoming Gmail in real-time,
delivering summaries and alerts to Telegram.

### Why This Is Useful
- **Email triage**: BBBot summarizes new emails so you can scan Telegram
  instead of opening Gmail — especially useful on the go or when deep in work
- **Action extraction**: "You have a meeting confirmation for Thursday at 2pm",
  "Your Amazon order shipped, arriving Monday"
- **Filtering**: only surface emails that matter — skip newsletters, marketing,
  automated notifications unless they contain something unusual
- **Cross-channel awareness**: BBBot can correlate email content with HomeKit
  events or network alerts ("power company says outage in your area" + "Nanoleaf went offline")
- **Response drafting**: ask BBBot to draft a reply, then approve/send from Gmail
- **Searchable context**: ask "did I get an email from Stanford this week?" via Telegram

### How It Works
OpenClaw's gmail-watcher uses Google Cloud Pub/Sub:
1. Gmail sends a push notification to a Pub/Sub topic when new mail arrives
2. Pub/Sub forwards it to a webhook on the OpenClaw gateway
3. BBBot receives the email content and processes it per your instructions
4. Alerts/summaries delivered to Telegram

### Prerequisites
- Google Cloud project with Pub/Sub enabled
- `gcloud` CLI installed and authenticated in Docker container
- `gog` CLI tool (OpenClaw's Gmail helper)
- Publicly reachable webhook endpoint (options below)

### Endpoint Options (for Pub/Sub to reach Docker)
- [ ] **Tailscale Funnel** (recommended) — free, secure, no port forwarding
- [ ] **Cloudflared tunnel** — Cloudflare's free tunnel service
- [ ] **ngrok** — simple but adds a dependency
- [ ] **Port forward** on AT&T modem (least ideal, exposes a port)

### Configuration
```json5
{
  hooks: {
    enabled: true,
    presets: ["gmail"],
    gmail: {
      account: "your@gmail.com",
      label: "INBOX",
      topic: "projects/<gcp-project>/topics/gog-gmail-watch",
      includeBody: true,
      maxBytes: 20000,
      renewEveryMinutes: 720,
      tailscale: { mode: "funnel" }
    }
  }
}
```

### Setup Steps
- [ ] Install Tailscale in Docker container (or choose tunnel approach)
- [ ] Create GCP project, enable Pub/Sub and Gmail API
- [ ] Run `openclaw webhooks gmail setup --account your@gmail.com`
- [ ] Configure BBBot's email handling instructions (triage rules, summary format)
- [ ] Test with a sample email

## Infrastructure Notes

- Docker image: `openclaw:local` built with `OPENCLAW_INSTALL_GO=1` and apt packages
- Config: `~/.openclaw/openclaw.json`
- Secrets: `~/.openclaw/.env` (moved out of repo dir for security)
- Go binaries: persistent Docker named volume `openclaw_openclaw-gopath`
- Compose: `docker compose --env-file ~/.openclaw/.env` (required for all compose commands)
- Aliases: `bbs` (Sonnet), `bbp` (Pro), `bbf` (Flash), `bbh` (Haiku), `bbu` (usage), `bbl` (logs)

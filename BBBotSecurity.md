# BBBot Security Hardening — Beyond Defaults

Custom security measures applied to the JOS OpenClaw Docker instance
on josmp25, beyond what OpenClaw and Docker provide out of the box.

## Host (josmp25)

- **SSH password auth disabled** — key-only access via
  `/etc/ssh/sshd_config.d/200-no-password.conf`
- **macOS Screen Sharing (VNC :5900) disabled**

## docker-compose.yml — Gateway Service

The stock `docker-compose.yml` only applies `cap_drop` and
`security_opt` to the CLI service. These were added to the gateway:

- **`cap_drop: [NET_RAW, NET_ADMIN]`** — prevents raw packet crafting
  (ping, ARP spoofing) and network config changes (iptables, routing)
- **`security_opt: [no-new-privileges:true]`** — blocks privilege
  escalation via setuid/setgid binaries
- **`dns: [192.168.1.254]`** — forces all DNS through the AT&T Uverse
  gateway; mitigates DNS tunneling exfiltration by preventing the
  container from querying arbitrary external DNS servers

## OpenClaw Config

- **`gateway.controlUi.dangerouslyDisableDeviceAuth: false`** —
  re-enabled device pairing for the Control UI (was temporarily
  disabled during initial setup)
- **`gateway.controlUi.allowedOrigins: ["http://127.0.0.1:18789"]`** —
  restricts Control UI WebSocket connections to localhost origin
- **`channels.telegram.groupPolicy: "allowlist"`** — Telegram group
  messages silently dropped (DMs only; allowFrom list is empty)
- **`gateway.nodes.denyCommands`** — blocks sensitive device commands:
  `camera.snap`, `camera.clip`, `screen.record`, `contacts.add`,
  `calendar.add`, `reminders.add`, `sms.send`

## Not Yet Done

- No outbound firewall rules beyond DNS pinning (iptables on the
  Docker bridge)
- No DNS query monitoring/alerting (e.g. Pi-hole)
- API keys stored in plaintext in `openclaw.json` inside the container
- Skills not sandboxed (gemini-cli, gh, whisper, summarize not
  installed, but also no sandbox boundary if they were)

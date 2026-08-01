---
spike: 006
name: spotify-local-connect-endpoint
type: standard
validates: "Given Spotify desktop is running, when Islet probes Spotify's local Connect/Zeroconf discovery endpoint (127.0.0.1), then track or queue data is inspectable without OAuth or a Premium-gated developer app"
verdict: INVALIDATED
related: [002]
tags: [spotify, local-api, phase-74, frontier]
---

# Spike 006: Spotify Local Connect Endpoint

## What This Validates

Given Spotify desktop is running, when Islet probes whatever local network surface Spotify
exposes on `127.0.0.1` (Connect/Zeroconf discovery, or any other local IPC), then track or queue
data is inspectable — without the OAuth Authorization Code Flow + PKCE and Premium-gated
developer-app registration that blocked the official Web API path in Spike 002.

## Research

**No documentation to check first — this had to start from live enumeration.** Unlike a public
API (Spike 002) there's no published spec for whatever Spotify Desktop binds locally; the
"static check" equivalent here is `lsof`, not `sdef` — enumerate what's actually open before
touching anything.

**Historical context:** Spotify Desktop used to run a documented-by-reverse-engineering local
HTTP API (`SpotifyWebHelper`, ports 4370-4382) for browser extensions and scrobblers. That API
was deprecated and shut down around 2014-2015 after a cross-site WebSocket hijacking (CSWSH)
vulnerability was disclosed against it. Worth checking whether *anything* comparable still
exists in 2026, not assuming it's gone just because that specific old mechanism is dead.

## How to Run

```bash
cd .planning/spikes/006-spotify-local-connect-endpoint
bash inspect-ports.sh                    # enumerate what Spotify has open
bash probe-endpoints.sh 7768 57621 51949 # raw GET against each candidate port
```

## What to Expect

`inspect-ports.sh` lists Spotify's open sockets. `probe-endpoints.sh` sends a bare HTTP GET over
raw TCP (via `nc`, not `curl` — the sandbox's context-mode tool intercepts `curl`/`wget` against
any URL including loopback, which isn't useful for byte-level protocol inspection) and hexdumps
whatever comes back.

## Investigation Trail

**1. Enumerated Spotify's actual open sockets** (`inspect-ports.sh`). Found, among mDNS/SSDP
noise: `TCP 127.0.0.1:7768 (LISTEN)`, `TCP *:57621 (LISTEN)` (the old legacy port, still open),
`TCP *:51949 (LISTEN)` (ephemeral, likely reassigned per launch).

**2. Port 57621 — silent.** No response to a plain HTTP GET at all. Consistent with the legacy
`SpotifyWebHelper` protocol being fully dead, even though the port itself is still bound (likely
vestigial/unrelated internal use, not a web-helper-style responder).

**3. Port 51949 — alive but not an API.** Returns an identical static
`{"type":"Tier1","version":"1.0"}` regardless of request path (`/` and `/spotify_info` both
returned the exact same bytes). No framing, plain text, terminated with `\r\n`. Reads as a fixed
capability/tier banner — likely local-network tier signaling for some internal handshake — not a
queryable data endpoint. Confirmed dead end without needing further probing.

**4. Port 7768 — a real, live, unauthenticated-format-unknown JSON-RPC surface.** Sending a bare
HTTP GET returned a structured error, not silence or a TCP reset:
```
{"jsonrpc":"2.0","error":{"code":1,"category":"desktop_api_failure_source","message":"desktop_api_failure_source: bad request"},"id":null}
```
prefixed by 4 bytes (`1d 8a 00 00`) that don't resolve to a simple length prefix in either
endianness against the 139-byte JSON payload — some other framing/magic-header scheme is in use.
This is almost certainly Spotify Desktop's internal Electron/CEF renderer-to-native-backend IPC
channel (the mechanism the app's own UI uses to talk to its playback engine), not a documented
public surface.

**Stopped here — deliberately, not from lack of trying.** Making a valid request against this
port would require reverse-engineering an undocumented binary framing format *and* an unknown
JSON-RPC method surface, with **no independent reference implementation to cross-check against**
— unlike Spike 003 (MediaRemote), where two authoritative sources (a reversed header and an
actively-maintained third-party library) existed to confirm findings against. Guessing method
names and framing bytes against a single unverified live target is exactly the "fishing, not
engineering" pattern the project's own conventions rule out. This is a real, non-trivial
reverse-engineering project in its own right, not a spike-scale probe.

## Results

**INVALIDATED** for this spike's scope, with a genuine open lead flagged for the record:

- Port 51949: dead end, confirmed — static banner, not an API.
- Port 57621: dead end, confirmed — legacy port, no longer responsive.
- **Port 7768: unresolved, not disqualified.** A real local JSON-RPC API is listening and
  responding to malformed requests with structured errors — meaning Spotify Desktop *does* run
  a local backend IPC surface today. Whether it exposes queue/track data is genuinely unknown;
  answering that needs a dedicated reverse-engineering effort (binary framing analysis, method
  discovery) that's out of proportion to a frontier spike and has no existing reference to lean
  on. If a Premium account becomes available (unblocking the official Web API path from Spike
  002) that route is far better evidenced and should be preferred over pursuing this one.

## Origin

Independent live-network investigation. Related to Spike 002 (same underlying question — local
Spotify data access without the Premium-gated Web API) but a different technical surface
(internal local IPC vs. AppleScript).

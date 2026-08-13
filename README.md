# GnoNightSky: Decentralized Telescope Network

Connect telescopes to the Gno.land blockchain. Telescope owners share access to their equipment; anyone with access can point the telescope at any target and get a captured image back.

**Goal:** Observe anything in the sky in real time through a community-driven telescope network.

[![Watch video](https://img.shields.io/badge/▶%20Watch-video-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/watch?v=RgoUgKUKft8)

Architecture inspired by [PiaGno](https://github.com/gnoverse/piagno) 🎹

---

## Architecture

```
┌─────────────────────┐
│  Authorized User    │
│  (web or gnokey)    │
└────────┬────────────┘
         │ SubmitCommand(capture, ra, dec, exposure)
         ▼
┌─────────────────────────────┐
│  r/nym-vikbez000/telescope  │  ← your telescope realm
│                             │
│  - Access control           │
│  - Command queue            │
│  - Capture history          │
│  - Render (web UI + forms)  │
└────────┬────────────────────┘
         │ cross-realm: Register / UpdateStatus / SubmitCapture
         │                                    ▼
         │                    ┌─────────────────────────────┐
         │                    │  r/nym-vikbez000/nightsky/v1│  ← network registry
         │                    │                             │
         │                    │  - Telescope registry       │
         │                    │  - Network-wide captures    │
         │                    └─────────────────────────────┘
         │
         │ Poll :status / :commandData  →  call GetNextCommand / RecordCapture
         ▼
┌─────────────────────────────┐
│  telescope-controller       │  ← runs on computer with telescope access
│  (Go binary)                │
│                             │
│  - Polls blockchain         │
│  - Runs capture/stop binary │
│  - Uploads to Imgur         │
│  - Reports results          │
└─────────────────────────────┘
         │
         ▼
   telescope hardware
   (via telescope_control.py)
```

### Components

| Path | Type | Role |
|------|------|------|
| `gno.land/p/nym-vikbez000/nightsky/v1` | package | Shared types, `TelescopeRealm` logic, render functions |
| `gno.land/r/nym-vikbez000/nightsky/v1` | realm | Telescope registry, global capture feed |
| `gno.land/r/nym-vikbez000/nightsky` | realm | Landing page linking to the current version (`/v1`) |
| `gno.land/r/nym-vikbez000/telescope` | realm | Vik's personnal telescope - usable as a template |
| `telescope-controller/` | Go binary | Hardware bridge to telescope |

---

## Deploying Your Own Telescope

### 1. Deploy your telescope realm

Copy `gno.land/r/nym-vikbez000/telescope` and update:
- `owner` address in `init()`
- telescope name, model, coordinates
- package path in `gnomod.toml`

Registration with the network happens automatically from `init()` via `registry.Register(cross(cur), config)`.

### 2. Publish your realm

```bash
gnokey maketx addpkg \
  -pkgpath "gno.land/r/yourusername/telescope" \
  -pkgdir "." \
  -gas-fee AMOUNT -gas-wanted AMOUNT \
  -broadcast -chainid CHAIN -remote rpc.gno.land:443 \
  YOUR_ADDRESS
```

### 3. Configure and run the telescope controller

Edit `telescope-controller/config.ini`.

Build and run:

```bash
cd telescope-controller
go build -o telescope-controller .
./telescope-controller
```

The controller polls `:status` every `interval_seconds`, reads `:commandData` when a command is queued, executes the configured binary (blocking), uploads the result to Imgur, and reports back via `RecordCapture`.

Capture args are appended as positional parameters:
```
telescope_control.py capture <ra> <dec> <exposure_seconds>
telescope_control.py stop
```

---

## Submitting Commands

### Via the web UI

Navigate to `gno.land/r/yourusername/telescope:control` - an interactive form lets you choose capture/stop, enter RA/Dec/exposure, and submit directly through your adena wallet.

### Via gnokey

```bash
# Capture - RA in hours (0–24), Dec in degrees (−90–90), exposure in seconds (1–300)
gnokey maketx call \
  -pkgpath "gno.land/r/yourusername/telescope" \
  -func "SubmitCommand" \
  -args "capture" -args "5.5" -args "22.5" -args "60" \
  -gas-fee 1000000ugnot -gas-wanted 2000000 \
  -broadcast -chainid portal-loop -remote rpc.gno.land:443 \
  YOUR_ADDRESS

# Stop
gnokey maketx call \
  -pkgpath "gno.land/r/yourusername/telescope" \
  -func "SubmitCommand" \
  -args "stop" -args "" -args "" -args "" \
  -gas-fee 1000000ugnot -gas-wanted 2000000 \
  -broadcast -chainid portal-loop -remote rpc.gno.land:443 \
  YOUR_ADDRESS
```

### Granting access

```bash
gnokey maketx call \
  -pkgpath "gno.land/r/yourusername/telescope" \
  -func "GrantAccess" \
  -args "g1friend_address" -args "30" \
  -gas-fee 1000000ugnot -gas-wanted 2000000 \
  -broadcast -chainid portal-loop -remote rpc.gno.land:443 \
  YOUR_ADDRESS
```

`durationDays = 0` means access never expires.

---

## Current hardware

- **Seestar S30 / S50** smart telescopes (~$500–700)
- Controlled via [seestar_alp](https://github.com/smart-underworld/seestar_alp) or a custom `telescope_control.py`

---

## Roadmap

- **Phase 1:** Working prototype - one telescope, command queue, Imgur captures, web forms, access control
- **Phase 2:** Multi-telescope network with map, bidding/scheduling for telescope time
- **Phase 3:** Integration with professional 3-axis mounts and higher-end cameras
- **Future:** DIY telescope builds using 3D printing and open-source designs

---

## Links

- Network: [gno.land/r/nym-vikbez000/nightsky/v1](https://gno.land/r/nym-vikbez000/nightsky/v1)
- Example telescope: [gno.land/r/nym-vikbez000/telescope](https://gno.land/r/nym-vikbez000/telescope)
- Gno.land docs: [docs.gno.land](https://docs.gno.land)

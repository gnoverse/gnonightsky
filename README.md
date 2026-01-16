# GnoNightSky: Telescopes Meet Gno.land

Connect telescopes to the Gno.land blockchain, enabling telescope owners to share access to their equipment through a decentralized network.

**Goal:** Observe anything in the sky you want in real time through a community-driven telescope network.

## What It Does
- Remotely control telescopes (pointing, tracking, image capture)
- Live video streaming from connected telescopes
- Interactive community features: chat + bidding for telescope time
- Display a live, worldwide map of available telescopes
- Store and share captured images using Imgur
- Owner-defined access control rules

## Hardware
- Begin with Seestar S30 / S50 smart telescopes using the open-source [seestar_alp](https://github.com/smart-underworld/seestar_alp) project
- Future: integration with professional 3-axis telescopes and higher-end cameras
- Parallel: Share and enable DIY telescope builds using 3D printing and open-source designs

## Security Features
- Owner-defined access control rules
- Hard-coded safety limits
- Rate limiting to prevent abuse
- Emergency stop functionality
- Ban list for users abusing the system
- Future: reputation system for telescope providers?

## Image Licensing
- All captured images are by default CC BY-NC-SA

## Inspiration
This is similar in spirit to [**PiaGno**](https://github.com/gnoverse/piagno), but for stargazing instead of music.

## Architecture
- Each telescope has its own Gno realm
- Global realm shows all registered telescopes and their status
- Package can be imported by users to deploy their own telescope realms
- Raspberry Pi controls the telescope hardware
- Everything built with open-source Golang tools where possible

## Roadmap

### Phase 1: Prototype with Seestar
- Build working prototype with 1 telescope
- Use Seestar S30/S50 and seestar_alp project
- Establish basic control, streaming, and access patterns

### Phase 2: Professional Equipment
- Integrate with more professional telescopes that also handle rotation

### Phase 3: Multi-Telescope Network
- Enable multiple telescopes to connect to the network
- Deploy global realm for telescope discovery and status

### Parallel: DIY & Open Source
- Source and experiment with open-source telescope builds using 3D printing
- Provide comprehensive documentation for building your own telescope
- Make everything accessible and reproducible

## Special mention
This is an early research-phase project following the principle: **SIMPLIFY EVERYTHING**. 



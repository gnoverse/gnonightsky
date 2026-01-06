# GnoNightSky: Telescopes Meet Gno.land

This is an early-stage project trying to connect smart telescopes to the Gno.land blockchain, enabling telescope owners to share access to their equipment through a decentralized network.

## What It Does
- Remotely control telescopes (pointing, tracking, image capture)
- Display a live, worldwide map of available telescopes
- Store and share captured photos using Imgur
- Allow telescope owners to define who can access and use their equipment

## Hardware
- Seestar S30 / S50 smart telescopes (≈ $500–700)
- Controlled using the open-source [seestar_alp](https://github.com/smart-underworld/seestar_alp) project

## Security Features
- Owner-defined access control rules
- Hard-coded safety limits (e.g. altitude constraints)
- Rate limiting to prevent abuse
- Emergency stop functionality

## Inspiration
This is similar in spirit to [**PiaGno**](https://github.com/gnoverse/piagno), but for stargazing instead of music.

## Status
This is an early research-phase project. The core building blocks are in place, and the system is being developed as a Gno realm package that anyone can deploy for their own telescope.

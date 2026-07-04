# Horus Project

> A Noctalia rice that got out of hand and ended up becoming a full post-install for CachyOS.

*Español: [README.es.md](README.es.md)*

Horus Project was born from the idea of building a distro that could fit any occasion, good for everything you need without burning through resources; after years on Windows and a round of distrohopping I noticed something that, at least on my modest 8 GB of RAM, stood out between distros: the CachyOS kernel was a marvel. Running games on Arch, Artix, Zorin OS, etc., there was always the limit of my hardware not giving more than it could, but Cachy was the exception. Taking **Niri** as a base — for how its **Noctalia** shell reminded me of GNOME (the first DE I ever touched) — and built on Cachy, even though it isn't made from scratch, it became a post-install script for CachyOS that, once installed with the **Niri** compositor (**Noctalia** shell) —and for now, for time reasons, only supporting systemd-boot from the installer—, is installable through a git repo with a single command. My rice tries to gather every function I find useful, brought straight into Niri simply and enabling a distraction-free, productivity-focused workflow with several different angles: its aesthetic, the performance for demanding tasks, and support that can give most devices a smooth, enjoyable experience.

**Shall we begin?**

```
bash <(curl -fsSL https://raw.githubusercontent.com/Johankyuk/Horus-Project/main/bootstrap.sh)
```

## Contents

- **Niri** (scrollable tiling) with **Noctalia** as the shell: bar, dock, control center and lockscreen.
- Terminal **foot**, file manager **Thunar**, browser **Zen**.
- **SDDM** greeter with its own theme (sugar-dark-horus), background kept consistent with your wallpaper.
- Theme engine with **9 palettes** that recolor the whole system at once — and you can add your own.
- **ES/EN language** switch in one command.
- **Power and hybrid-GPU** management aimed at laptops with an NVIDIA dGPU.
- **Keyboard RGB** with software effects.
- Its own branding: black boot titled "Horus Project (your base)" and fastfetch with the Horus eye in the active theme's color. No fake `os-release`: it's not a distro and doesn't pretend to be one.

## Requirements

- **CachyOS**.
- **UEFI boot with systemd-boot**. *(for easier editing)*
- An internet connection.

## Quick install

One command. Installs git if missing, clones the repo into `~/horus` and launches the installer:

```
bash <(curl -fsSL https://raw.githubusercontent.com/Johankyuk/Horus-Project/main/bootstrap.sh)
```

That's it. From there the installer walks you through it.

## Install modes

On launch, the installer asks how you want to install:

**Full** — Everything you see in this README, no questions asked. For whoever wants the setup as-is.

**Custom** *(recommended)* — You pick package by package what goes in. Each section has its own selector and explanation. If you didn't read the options below, this is your mode: it shows them to you and you decide on the fly. *(it's my favorite because I know that instead of reading I'd jump straight to seeing it all in practice)*

**Minimal** — Core only: the essentials to get Niri + Noctalia running. To build on top your way.

The whole point of Horus Project is for you to feel free: in custom mode nothing installs behind your back, and every parameter you'd want to touch has its own selector.

## What's in each package

**Core** *(always installed)* — Niri, Noctalia, foot, Thunar, fonts, configs, keybinds, SDDM, monitor projection, battery limit, keyboard RGB and Steam fixes *(happened to me on an 11th-gen i7)*.

**Cosmetics** — Per-theme coloring of the cursor, Thunar folders, GTK accent and the window focus-ring, plus the theme selector. The visual stuff, what'll make your desktop and day-to-day unique. *(recommended to always install this block for a cozier experience)*

**Apps** — By category: office (OnlyOffice by default, LibreOffice as an alternative), media (VLC, imv, OBS) and browser (Zen). Steam and the gaming meta go here. Opening each category reveals the following alternatives, but they don't go in by default: the truly optional stuff — extra browsers, Discord, extra media. None of it is required; it's there if you want it.

**Gaming** — Nostalgic web games (PvZ Gardenless, Angry Birds Epic, AllStars) served by a script with its own launcher. *(still pending)*

**Graphics performance** *(only if a dGPU is detected)* — supergfxctl, nvtop and the horus-power setup (fan curves + power hook). If your machine has no dedicated GPU, this section doesn't show up.

## Themes

Horus Project ships a color engine (OKLCH) with **9 themes** that recolor Noctalia, foot, Niri, the wallpaper, the cursor and the keyboard RGB all at once:

Purple, Electric blue, Royal blue, Bright pink, Pale pink, Yellow, Orange, Red and Gray.

```
horus-theme            # opens the selector with color swatches
horus-theme Red        # applies a theme directly (Red in this case)
horus-theme --actual   # shows the active theme
```

You can also add your own **custom theme** (a central color and a couple of tweaks) or install with **no theme** and keep the base purple.

## Language

English by default, Spanish with one command. The language also adjusts details like the first day of the week in the clock (lunes → monday).

```
horus-language         # ES / EN selector
```

Unlike a certain toby fox, I *do* translate 1300+ lines of code into another language… beat that.

## Power & GPU

Aimed at laptops with a hybrid GPU (iGPU + NVIDIA dGPU). `horus-power` unifies profiles, fan curves and GPU modes:

```
horus-power eco          # quiet, dGPU heavily capped
horus-power equilibrado  # daily use
horus-power rendimiento  # full power (only on AC)
horus-power gpu-off      # turns the dGPU off, desktop on the iGPU (logs out)
horus-power gpu-on       # turns it back on
```

A hook watches the power profile and adjusts only the dGPU's power limit. **gpu-off** is the option for maximum battery life: it leaves the machine running on the iGPU alone; the mode persists across reboots and is undone with `gpu-on`.

## Keyboard RGB

The keyboard RGB follows the theme color. Effects run in software (this machine's firmware doesn't support them natively). *(ASUS TUF only; this will be extended later to cover other devices)*

```
Fn + F4   # cycles effects: static, breathing, rainbow, pulse, strobe
```

## Shortcuts

The whole interface is `horus-*` shortcuts, available for quick access after install. *(all in English, for professionalism — and so the gringos don't start crying when they hit an ñ in the terminal)*

| Command | What it does |
|---|---|
| `horus-start` | Install / reconfigure (shows the plan and asks for confirmation). |
| `horus-theme` | Change theme (no arguments opens the selector). |
| `horus-language` | Change the system language (ES / EN). |
| `horus-update` | Updates mirrors + repos/AUR + Flatpaks. |
| `horus-check` | Setup diagnostics: what's fine and what's missing. |
| `horus-sync` | Dumps your ~/.config into the repo (to commit your changes). |

## Repository structure (Beta 1.2)

```
horus/
├── bootstrap.sh          # one-command install
├── setup_master.sh       # master installer (idempotent sections)
├── config/               # dotfiles → ~/.config (niri, noctalia, foot)
├── local-bin/            # horus-* shortcuts → ~/.local/bin
├── branding/         # fastfetch logo and config (rotated by the theme)
├── sugar-dark-horus/       # SDDM theme
├── proyectar/            # monitor projection utility
├── system/               # systemd services (power hook)
├── udev/                 # rules (keyboard RGB)
├── Wallpapers/  PFP/     # wallpapers and avatar
└── horus_themes.py          # color engine
```

## Credits

Horus Project is built and maintained by me, a university student who in his spare time messes around with lines of Python.

Thanks for reading and choosing Horus Project.

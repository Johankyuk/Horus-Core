<div align="center">

# Horus Project

**Content repository for the Horus desktop — consumed by [horus-nix](https://github.com/Johankyuk/horus-nix)**

[English](#english) · [Español](#espanol)

</div>

---

<a name="english"></a>
## English

### What this is

This repo holds the **content** of the Horus desktop: dotfiles, branding, wallpapers, and themes. It contains no installer and no tooling — the system itself (packages, services, scripts like `horus-theme`) is built declaratively by the [horus-nix](https://github.com/Johankyuk/horus-nix) flake on NixOS.

> Historical note: this repo used to carry a full post-install automation suite for Arch/CachyOS (`setup_master.sh`, `local-bin/`). That era lives in the git history up to `56291e9`. Everything executable now lives in horus-nix.

### Structure

| Path | Purpose |
|---|---|
| `config/` | Dotfiles deployed to `~/.config` (Niri, Noctalia, foot, MangoHud, Dark Reader, Heroic, Zen…) |
| `branding/` | fastfetch config + Horus ASCII logo |
| `Wallpapers/` | `base.svg` + per-theme generated wallpapers |
| `sugar-dark-horus/` | SDDM theme (colors governed by the theme engine) |
| `PFP/`, `preview/`, `proyectar/`, `docs/` | Assets and documentation |

### How it's consumed

1. **Seed** (`horus-seed`, system service): a pinned snapshot of this repo ships inside the NixOS build so the first boot has Niri/Noctalia/foot config before SDDM — no network, no race.
2. **Bootstrap** (`horus-bootstrap`, user service): clones/updates this repo to `~/Horus-Project` on login and deploys missing config non-destructively (`cp -rn`).
3. **Runtime**: tools like `horus-theme` read content (wallpapers, branding, theme sources) from the clone; the color engine itself ships with the tools in horus-nix.

`Wallpapers/base.svg` is the marker the tools use to locate this repo (`HORUS_DIR` overrides).

---

<a name="espanol"></a>
## Español

### Qué es esto

Este repo contiene el **contenido** del escritorio Horus: dotfiles, branding, wallpapers y temas. No hay instalador ni tooling — el sistema (paquetes, servicios, scripts como `horus-theme`) lo construye declarativamente el flake [horus-nix](https://github.com/Johankyuk/horus-nix) en NixOS.

> Nota histórica: este repo cargó una suite completa de automatización post-install para Arch/CachyOS (`setup_master.sh`, `local-bin/`). Esa era vive en el historial git hasta `56291e9`. Todo lo ejecutable vive ahora en horus-nix.

### Estructura

| Ruta | Propósito |
|---|---|
| `config/` | Dotfiles desplegados a `~/.config` (Niri, Noctalia, foot, MangoHud, Dark Reader, Heroic, Zen…) |
| `branding/` | Config de fastfetch + logo ASCII de Horus |
| `Wallpapers/` | `base.svg` + wallpapers generados por tema |
| `sugar-dark-horus/` | Tema de SDDM (colores gobernados por el motor de temas) |
| `PFP/`, `preview/`, `proyectar/`, `docs/` | Assets y documentación |

### Cómo se consume

1. **Seed** (`horus-seed`, servicio de sistema): un snapshot pineado de este repo viaja dentro del build de NixOS para que el primer boot tenga config de Niri/Noctalia/foot antes de SDDM — sin red, sin race.
2. **Bootstrap** (`horus-bootstrap`, servicio de usuario): clona/actualiza este repo a `~/Horus-Project` al iniciar sesión y despliega config faltante sin pisar nada (`cp -rn`).
3. **Runtime**: herramientas como `horus-theme` leen contenido (wallpapers, branding, fuentes de tema) desde el clon; el motor de color viaja con las herramientas en horus-nix.

`Wallpapers/base.svg` es el marcador que usan las herramientas para localizar este repo (`HORUS_DIR` lo sobreescribe).

# Horus Project

> **A better Noctalia — for laptops.**

**English** | [Español](#espanol)

Horus is a one-command post-install for **CachyOS**. It takes **Noctalia** — a Wayland desktop shell — and turns it into a complete, laptop-ready daily driver: a unified purple theme, hybrid-GPU management, battery care, keyboard RGB, power profiles, and clean boot branding. The parts a bare Noctalia install leaves you to wire up yourself, Horus wires up for you.

It's a personal setup, kept public as a reference. It isn't a distro and doesn't pretend to be one — no fake `os-release`, no impersonation. Just CachyOS, configured the way I run it.

Built on **Noctalia v4.7.7** (the frozen final of the v4 branch). A port to **Noctalia v5** is planned once v5 leaves beta — for now this is the stable snapshot for v4.

## Install

One command. It installs `git` if missing, clones the repo to `~/Horus-Project`, and runs the installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Johankyuk/Horus-Project/main/bootstrap.sh)
```

No prompts. Full install, in Spanish, purple theme. It runs every section and leaves the machine ready. For fine control, `horus-start --solo=<section>` runs individual sections.

## Requirements

- **CachyOS**
- **UEFI** boot with **systemd-boot**
- An internet connection

Horus installs Niri and Noctalia for you — you don't need them beforehand. It's built and tested on an ASUS TUF laptop with a hybrid AMD iGPU + NVIDIA dGPU and an ITE5570 RGB keyboard; the GPU, battery, and RGB pieces target that hardware, while everything else is plain CachyOS + Niri + Noctalia.

## What it installs

- **Niri** (scrollable tiling) with **Noctalia** as the shell: bar, dock, control center, and lockscreen.
- **foot** terminal, **PCManFM-Qt** file manager, **Zen** browser (themed).
- **SDDM** greeter with a matching theme (sugar-dark-horus).
- Everyday apps: VLC, imv, OBS, OnlyOffice, VSCodium, Steam (with its Wayland fix), Sober (Roblox).
- **Power and hybrid-GPU management** for laptops with an NVIDIA dGPU.
- **Keyboard RGB** with software effects (ASUS TUF / ITE5570).
- Own branding: black boot with a "Horus (your base)" title and a purple Horus-eye fastfetch. No fake `os-release`.
- **Minecraft Bedrock** via mcpelauncher, with optional Newb shaders.

## Theme

Everything is **purple** (`#8b45f7`). An OKLCH color engine recolors Noctalia, foot, Niri, the wallpaper, the cursor, and the keyboard RGB in one shot. The install applies purple and that's it — the engine keeps other palettes internally, but there's no selector and none are offered. This is a single-theme setup on purpose.

## Power & GPU

Built for laptops with a hybrid GPU (iGPU + NVIDIA dGPU). `horus-power` unifies profiles, fan curves, and GPU modes:

```bash
horus-power eco          # quiet, dGPU heavily capped
horus-power equilibrado  # daily use
horus-power rendimiento  # full power (AC only)
horus-power gpu-off      # disable the dGPU, desktop on the iGPU (logs out)
horus-power gpu-on       # turn it back on
```

A hook watches the power profile and adjusts only the dGPU's power limit. A per-boot service keeps the battery charge limit (80%).

> **Dual-boot note:** if you boot Windows before Linux, Windows can override the EC charge limit. The hook re-applies it within seconds back in Linux, but there's a brief window where the limit may read differently. That's expected, not a fault.

## Keyboard RGB

The RGB follows the theme color. Effects run in software (the firmware doesn't do them natively). ITE5570 (ASUS TUF) only — other keyboards are out by design; that's what OpenRGB is for.
Fn + F4   # cycle effects: static, breathing, rainbow, pulse, strobe
## Commands

The whole interface is `horus-*` shortcuts, available after install:

| Command | What it does |
|---|---|
| `horus-start` | Install / reconfigure. `--solo=<section>` runs individual sections. |
| `horus-theme` | Applies the theme (purple). Live applier, no selector. |
| `horus-power` | Power profiles and GPU modes. |
| `horus-update` | Updates mirrors + repos/AUR + Flatpaks. |
| `horus-check` | Setup diagnostics: what's fine and what's missing. |
| `horus-sync` | Dumps your `~/.config` into the repo (to commit GUI changes). |

> **Maintenance note:** the `horus-*` commands live copied in `~/.local/bin` (they aren't symlinks to the repo). Editing the repo isn't enough — sync the copy (`horus-sync` or `cp local-bin/* ~/.local/bin/`) before testing.

## Repository layout
Horus-Project/
├── bootstrap.sh          # one-command install
├── setup_master.sh       # master installer (idempotent sections)
├── config/               # dotfiles → ~/.config (niri, noctalia, foot)
├── local-bin/            # horus-* shortcuts → ~/.local/bin
├── branding/             # fastfetch logo/config (the theme rotates them)
├── sugar-dark-horus/     # SDDM theme
├── proyectar/            # display-projection utility
├── system/               # systemd services (power hook)
├── udev/                 # rules (keyboard RGB)
├── Wallpapers/  PFP/      # wallpapers and avatar
└── horus_themes.py       # color engine
The `archive/wizard-temas-folders` branch keeps the previous state (install wizard, multi-theme selector, Thunar folder recoloring) in case I ever want it back.

## Credits

Built and maintained by me — a Biomedical Engineering student who plays with Python in his spare time. Thanks for reading.

---

<a name="espanol"></a>

# Horus Project — Español

> **Un mejor Noctalia — para laptops.**

[English](#horus-project) | **Español**

Horus es un post-install de un comando para **CachyOS**. Toma **Noctalia** —un shell de escritorio para Wayland— y lo convierte en un daily driver completo y listo para portátil: tema morado unificado, gestión de GPU híbrida, cuidado de batería, RGB de teclado, perfiles de energía y branding de arranque limpio. Todo lo que un Noctalia pelón te deja cablear a mano, Horus lo cablea por vos.

Es un setup personal, público como referencia. No es una distro ni pretende serlo —sin `os-release` falso, sin disfraces. Solo CachyOS, configurado como lo uso yo.

Construido sobre **Noctalia v4.7.7** (el final congelado de la rama v4). El port a **Noctalia v5** está planeado para cuando v5 salga de beta —por ahora este es el snapshot estable para v4.

## Instalación

Un solo comando. Instala `git` si falta, clona el repo en `~/Horus-Project` y lanza el instalador:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Johankyuk/Horus-Project/main/bootstrap.sh)
```

Sin preguntas. Instalación completa, en español, con tema morado. Corre todas las secciones y deja el equipo listo. Si querés control fino, `horus-start --solo=<seccion>` corre secciones sueltas.

## Requisitos

- **CachyOS**
- Arranque **UEFI con systemd-boot**
- Conexión a internet

Horus instala Niri y Noctalia por vos —no hacen falta de antemano. Está construido y probado en una laptop ASUS TUF con iGPU AMD + dGPU NVIDIA híbrida y teclado RGB ITE5570; las piezas de GPU, batería y RGB apuntan a ese hardware, y el resto es CachyOS + Niri + Noctalia genérico.

## Qué instala

- **Niri** (tiling scrollable) con **Noctalia** como shell: barra, dock, centro de control y lockscreen.
- Terminal **foot**, gestor de archivos **PCManFM-Qt**, navegador **Zen** (con tema).
- Greeter **SDDM** con tema propio (sugar-dark-horus).
- Apps de diario: VLC, imv, OBS, OnlyOffice, VSCodium, Steam (con su fix de Wayland), Sober (Roblox).
- **Gestión de energía y GPU híbrida** para portátiles con dGPU NVIDIA.
- **RGB del teclado** con efectos por software (ASUS TUF / ITE5570).
- Branding propio: boot negro con título "Horus (tu base)" y fastfetch con el ojo de Horus en morado. Sin `os-release` falso.
- **Minecraft Bedrock** vía mcpelauncher, con shaders Newb opcionales.

## Tema

Todo va en **morado** (`#8b45f7`). Un motor de color OKLCH recolorea Noctalia, foot, Niri, wallpaper, cursor y RGB del teclado de golpe. En la instalación se aplica morado y punto —el motor conserva otras paletas internamente, pero no hay selector ni se ofrecen. Es un setup de un solo tema a propósito.

## Energía y GPU

Pensado para portátiles con GPU híbrida (iGPU + dGPU NVIDIA). `horus-power` unifica perfiles, curvas de ventilador y modos de GPU:

```bash
horus-power eco          # silencioso, dGPU muy capada
horus-power equilibrado  # uso diario
horus-power rendimiento  # a tope (solo con cargador)
horus-power gpu-off      # apaga la dGPU, escritorio a iGPU (cierra sesión)
horus-power gpu-on       # la vuelve a encender
```

Un hook vigila el perfil de energía y ajusta solo el límite de potencia de la dGPU. El límite de carga de batería (80%) lo mantiene un servicio en cada arranque.

> **Nota dual boot:** si arrancás desde Windows antes que Linux, Windows puede pisar el tope de carga en el EC. El hook lo recorrige en segundos al volver a Linux, pero hay una ventana breve donde el límite puede verse en otro valor. Es esperado, no un fallo.

## Teclado RGB

El RGB sigue el color del tema. Los efectos van por software (el firmware no los soporta nativo). Solo para el ITE5570 de ASUS TUF; otros teclados quedan fuera por diseño —para eso está OpenRGB.
Fn + F4   # cicla efectos: estático, respiración, arcoíris, pulso, strobe
## Comandos

Toda la interfaz son atajos `horus-*` disponibles tras la instalación:

| Comando | Qué hace |
|---|---|
| `horus-start` | Instalación / reconfiguración. `--solo=<seccion>` corre secciones sueltas. |
| `horus-theme` | Aplica el tema (morado). Aplicador vivo, sin selector. |
| `horus-power` | Perfiles de energía y modos de GPU. |
| `horus-update` | Actualiza mirrors + repos/AUR + Flatpaks. |
| `horus-check` | Diagnóstico del setup: qué está bien y qué falta. |
| `horus-sync` | Vuelca tu `~/.config` al repo (para commitear cambios de GUI). |

> **Nota de mantenimiento:** los comandos `horus-*` viven copiados en `~/.local/bin` (no son symlinks al repo). Editar el repo no basta: hay que sincronizar la copia (`horus-sync` o `cp local-bin/* ~/.local/bin/`) antes de probar.

## Estructura del repositorio
Horus-Project/
├── bootstrap.sh          # instalación de un comando
├── setup_master.sh       # instalador maestro (secciones idempotentes)
├── config/               # dotfiles → ~/.config (niri, noctalia, foot)
├── local-bin/            # atajos horus-* → ~/.local/bin
├── branding/             # logo y config de fastfetch (el tema los rota)
├── sugar-dark-horus/     # tema de SDDM
├── proyectar/            # utilidad de proyección a monitores
├── system/               # servicios systemd (hook de energía)
├── udev/                 # reglas (RGB del teclado)
├── Wallpapers/  PFP/      # fondos y avatar
└── horus_themes.py       # motor de color
La rama `archive/wizard-temas-folders` conserva el estado anterior (wizard de instalación, selector multi-tema, recoloreo de carpetas de Thunar) por si alguna vez lo quiero de vuelta.

## Créditos

Lo construyo y mantengo yo, un estudiante de Ingeniería Biomédica que en ratos libres juega con Python. Gracias por leer.

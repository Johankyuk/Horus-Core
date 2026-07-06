# Horus Project

> Un rice de Noctalia que se me fue de las manos y terminó siendo mi post-install personal para CachyOS.

Esto ya no pretende ser un proyecto para todo el mundo. Es **mi** setup: lo que uso a diario, con la estética que me gusta y el rendimiento que necesito para lo mío. Lo dejo público por si a alguien le sirve de referencia, pero está pensado para mi equipo y mi flujo, no para mantenerse como algo universal.

Nació de años de distrohopping. Tras probar Arch, Artix, Zorin y compañía en un equipo modesto, el kernel de CachyOS fue el único que le sacó juego de verdad al hardware. Sobre esa base monté **Niri** (tiling scrollable) con **Noctalia** como shell —me recordaba a GNOME, mi primer contacto con Linux— y fui recopilando todo lo que considero útil en un solo script de post-instalación, instalable con un comando.

## Instalación

Un solo comando. Instala git si falta, clona el repo en `~/Horus-Project` y lanza el instalador:
bash <(curl -fsSL https://raw.githubusercontent.com/Johankyuk/Horus-Project/main/bootstrap.sh)
**Sin preguntas.** Instalación completa, en español, con tema morado. Corre todas las secciones y deja el equipo listo. Si querés control fino, `horus-start --solo=<seccion>` corre secciones sueltas.

## Requisitos

- **CachyOS**
- Arranque **UEFI con systemd-boot**
- Conexión a internet

## Qué instala

- **Niri** (tiling scrollable) con **Noctalia** como shell: barra, dock, centro de control y lockscreen.
- Terminal **foot**, gestor de archivos **Thunar**, navegador **Zen**.
- Greeter **SDDM** con tema propio (sugar-dark-horus), coherente con el wallpaper.
- Apps de diario: VLC, imv, OBS, OnlyOffice, VSCodium, Steam (con su fix de Wayland), Sober (Roblox).
- Gestión de **energía y GPU híbrida** para portátiles con dGPU NVIDIA.
- **RGB del teclado** con efectos por software (ASUS TUF / ITE5570).
- Branding propio: boot negro con título "Horus Project (tu base)" y fastfetch con el ojo de Horus en morado. Sin `os-release` falso: no es una distro y no se disfraza de una.

## Tema

Todo va en **morado** (`#8b45f7`). El sistema tiene un motor de color OKLCH que recolorea Noctalia, foot, Niri, wallpaper, cursor y RGB del teclado de golpe. En la instalación se aplica morado y punto. El motor conserva otras paletas internamente por si algún día las quiero, pero no hay selector ni se ofrecen: esto es un setup de un solo tema a propósito.

## Energía y GPU

Pensado para portátiles con GPU híbrida (iGPU + dGPU NVIDIA). `horus-power` unifica perfiles, curvas de ventilador y modos de GPU:
horus-power eco          # silencioso, dGPU muy capada
horus-power equilibrado  # uso diario
horus-power rendimiento  # a tope (solo con cargador)
horus-power gpu-off      # apaga la dGPU, escritorio a iGPU (cierra sesión)
horus-power gpu-on       # la vuelve a encender
Un hook vigila el perfil de energía y ajusta solo el límite de potencia de la dGPU. El límite de carga de batería (80%) también lo mantiene un servicio en cada arranque.

> **Nota dual boot:** si arrancás desde Windows antes que Linux, Windows puede pisar el tope de carga en el EC. El hook lo recorrige en segundos al volver a Linux, pero hay una ventana breve donde el límite puede verse en otro valor. Es esperado, no un fallo.

## Teclado RGB

El RGB sigue el color del tema. Los efectos van por software (el firmware no los soporta nativo). Solo para el ITE5570 de ASUS TUF; otros teclados quedan fuera por diseño — para eso está OpenRGB.

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
├── Wallpapers/  PFP/     # fondos y avatar
└── horus_themes.py       # motor de color
La rama `archive/wizard-temas-folders` conserva el estado anterior (wizard de instalación, selector multi-tema, recoloreo de carpetas de Thunar) por si alguna vez lo quiero de vuelta.

## Créditos

Lo construyo y mantengo yo, un estudiante de Ingeniería Biomédica que en ratos libres juega con Python. Gracias por leer.

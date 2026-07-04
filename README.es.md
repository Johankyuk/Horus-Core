# Horus Project

> Un rice de Noctalia que se le fue de las manos y terminó siendo un post-install completo para CachyOS.

*English: [README.md](README.md)*

Horus Project nació de la idea de crear una distro que pudiera prestarse para cualquier ocasión, buena para todo lo necesario sin consumir recursos de forma despilfarrada; tras usar Windows por años y hacer un distrohopping me percaté de algo que, al menos en mi dispositivo con modestos 8 GB de RAM, notaba entre distros: el kernel de CachyOS era una maravilla. Al correr juegos en Arch, Artix, Zorin OS, etc., siempre estaba la limitante de que mi hardware no pudiera dar más de sí, pero Cachy fue la excepción. Tomando de base **Niri** por el recuerdo similar a su shell **Noctalia**, con un amplio parecido a GNOME (el primer DE con el que hice contacto), y con base Cachy, a pesar de no estar hecha desde cero, se volvió un script post-instalación de CachyOS que, al instalarse con el compositor **Niri** (shell **Noctalia**) —y por ahora, por temas de tiempo, únicamente soportando systemd-boot como opción desde el instalador—, es instalable a través de un repositorio git con un solo comando. Mi rice trata de recopilar todas las funciones que considero útiles, traídas directamente a Niri con simpleza y permitiendo un workflow enfocado en la productividad sin distracciones pero con varios enfoques distintos: su estética, el rendimiento para tareas exigentes y un soporte que pueda brindar a la mayoría de dispositivos una experiencia fluida y disfrutable.

**¿Empezamos?**

```
bash <(curl -fsSL https://raw.githubusercontent.com/Johankyuk/Horus-Project/main/bootstrap.sh)
```

## Contenido

- **Niri** (tiling scrollable) con **Noctalia** como shell: barra, dock, centro de control y lockscreen.
- Terminal **foot**, gestor de archivos **Thunar**, navegador **Zen**.
- Greeter **SDDM** con tema propio (sugar-dark-horus), con el fondo coherente con tu wallpaper.
- Motor de temas con **9 paletas** que recolorean todo el sistema de golpe — y puedes meter las tuyas.
- Cambio de **idioma ES/EN** en un comando.
- Gestión de **energía y GPU híbrida** pensada para portátiles con dGPU NVIDIA.
- **RGB del teclado** con efectos por software.
- Branding propio: boot negro con título "Horus Project (tu base)" y fastfetch con el ojo de Horus al color del tema activo. Sin `os-release` falso: no es una distro y no se disfraza de una.

## Requisitos

- **CachyOS**.
- Arranque **UEFI con systemd-boot**. *(para mayor facilidad de edición)*
- Conexión a internet.

## Instalación rápida

Un solo comando. Instala git si falta, clona el repo en `~/horus` y lanza el instalador:

```
bash <(curl -fsSL https://raw.githubusercontent.com/Johankyuk/Horus-Project/main/bootstrap.sh)
```

Eso es todo. A partir de ahí el instalador te lleva de la mano.

## Modos de instalación

Al arrancar, el instalador te pregunta cómo quieres instalar:

**Completa** — Todo lo que ves en este README, sin preguntar nada más. Para quien quiere el setup tal cual.

**Personalizada** *(recomendada)* — Eliges paquete por paquete qué entra. Cada sección tiene su selector y su explicación. Si no leíste las opciones de abajo, este es tu modo: te las va mostrando y decides sobre la marcha. *(es mi preferido porque sé que en vez de leer me saltaría a ver todo en práctica)*

**Mínima** — Solo el núcleo: lo imprescindible para tener Niri + Noctalia funcionando. Para construir encima a tu gusto.

La idea principal de Horus Project es que te sientas libre: en modo personalizado nada se instala a tus espaldas, y todo parámetro que quieras tocar tiene su selector.

## Qué hay en cada paquete

**Núcleo** *(siempre se instala)* — Niri, Noctalia, foot, Thunar, fuentes, configs, atajos de teclado, SDDM, proyección a monitores, límite de batería, RGB del teclado y fixes de Steam *(me pasó con un i7 11th gen)*.

**Cosméticos** — El coloreado por tema del cursor, las carpetas de Thunar, el acento GTK y el focus-ring de las ventanas, más el selector de tema. Lo visual, lo que hará único a tu escritorio y día a día. *(recomendado instalar siempre este bloque para una experiencia más acogedora)*

**Apps** — Selección por categoría: oficina (OnlyOffice por defecto, LibreOffice como alternativa), multimedia (VLC, imv, OBS) y navegador (Zen). Steam y el meta de gaming entran aquí. Al abrir cada categoría se agregan las siguientes alternativas, pero no van directamente: lo opcional de verdad — navegadores extra, Discord, multimedia adicional. Nada de esto es necesario; está por si lo quieres.

**Gaming** — Juegos web nostálgicos (PvZ Gardenless, Angry Birds Epic, AllStars) servidos por un script con su propio lanzador. *(pendientes aún)*

**Rendimiento gráfico** *(solo si detecta dGPU)* — supergfxctl, nvtop y la configuración de horus-power (curvas de ventilador + hook de energía). Si tu equipo no tiene GPU dedicada, esta sección no aparece.

## Temas

Horus Project trae un gestor de color (OKLCH) con **9 temas** que recolorean Noctalia, foot, Niri, el wallpaper, el cursor y el RGB del teclado a la vez:

Morado, Azul eléctrico, Azul rey, Rosa brillante, Rosa pálido, Amarillo, Naranja, Rojo y Gris.

```
horus-theme            # abre el selector con muestras de color
horus-theme Rojo       # aplica un tema directo (rojo en este caso)
horus-theme --actual   # muestra el tema activo
```

Adicionalmente existe la opción de agregar un **tema propio** (un color central y un par de ajustes) o instalar **sin tema** y quedarte con el morado base.

## Idioma

Inglés por defecto, español con un comando. El idioma también ajusta detalles como el primer día de la semana en el reloj (lunes → monday).

```
horus-language         # selector ES / EN
```

al contrario de un tal toby fox, yo sí traduzco a un idioma más de 1300 líneas de código… Supera eso.

## Energía y GPU

Pensado para portátiles con GPU híbrida (iGPU + dGPU NVIDIA). `horus-power` unifica perfiles, curvas de ventilador y modos de GPU:

```
horus-power eco          # silencioso, dGPU muy capada
horus-power equilibrado  # uso diario
horus-power rendimiento  # a tope (solo con cargador)
horus-power gpu-off      # apaga la dGPU, escritorio a iGPU (cierra sesión)
horus-power gpu-on       # la vuelve a encender
```

Un hook vigila el perfil de energía y ajusta solo el límite de potencia de la dGPU. **gpu-off** es la opción para máxima autonomía: deja el equipo corriendo solo en la iGPU; el modo persiste tras reiniciar y se revierte con `gpu-on`.

## Teclado RGB

El RGB del teclado sigue el color del tema. Los efectos van por software (el firmware de este equipo no los soporta de forma nativa). *(para ASUS TUF únicamente; eso se irá configurando más adelante para cubrir otros dispositivos)*

```
Fn + F4   # cicla efectos: estático, respiración, arcoíris, pulso, strobe
```

## Atajos

Toda la interfaz son atajos `horus-*` que quedan disponibles para acceso rápido tras la instalación. *(todos en inglés por profesionalismo y para que los gringos no se me pongan a chillar al poner una ñ en la terminal)*

| Comando | Qué hace |
|---|---|
| `horus-start` | Instalación / reconfiguración (muestra el plan y pide confirmación). |
| `horus-theme` | Cambiar de tema (sin argumentos abre el selector). |
| `horus-language` | Cambiar el idioma del sistema (ES / EN). |
| `horus-update` | Actualiza mirrors + repos/AUR + Flatpaks. |
| `horus-check` | Diagnóstico del setup: qué está bien y qué falta. |
| `horus-sync` | Vuelca tu ~/.config al repo (para commitear tus cambios). |

## Estructura del repositorio (Beta 1.2)

```
horus/
├── bootstrap.sh          # instalación de un comando
├── setup_master.sh       # instalador maestro (secciones idempotentes)
├── config/               # dotfiles → ~/.config (niri, noctalia, foot)
├── local-bin/            # atajos horus-* → ~/.local/bin
├── branding/         # logo y config de fastfetch (el tema los rota)
├── sugar-dark-horus/       # tema de SDDM
├── proyectar/            # utilidad de proyección a monitores
├── system/               # servicios systemd (hook de energía)
├── udev/                 # reglas (RGB del teclado)
├── Wallpapers/  PFP/     # fondos y avatar
└── horus_themes.py          # motor de color
```

## Créditos

Horus Project lo construyo y mantengo yo, un estudiante universitario que en mis ratos libres me pongo a jugar con líneas de código en Python.

Gracias por leer y escoger Horus Project.

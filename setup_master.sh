#!/bin/bash
export HORUS_NO_CLOSE=1  # horus-theme no debe cerrar la terminal del setup
# Descripcion: Setup maestro - CachyOS -> Horus (Niri + Noctalia)
#               Instala paquetes, despliega configs y aplica branding.
# Uso:   La interfaz son los atajos horus-* (se despliegan en la 1ª corrida y quedan
#        en PATH). Cada atajo es este script con su modo:
#          horus-start       corrida completa (muestra el plan y pide confirmación)
#          horus-dry         solo el plan, no toca nada
#          horus-check       healthcheck post-setup
#          horus-sync        vuelca tu ~/.config al repo (para commitear)
#          horus-solo SECS   corre solo esas secciones (horus-solo lista para verlas;
#                          por nombre o número: horus-solo cursor · horus-solo 7,9)
#          horus-clean      borra restos de versiones viejas del setup
#        La 1ª vez, sin atajos aún:  bash setup_master.sh
# Avanzado (flags de uso puntual, sin atajo propio):
#          --skip-update   no corre 'pacman -Syu' al inicio (iterar rápido)
#          --bateria=N     límite de carga de batería en N% (default 80; 0 = off)
#          --no-bateria    no configura el límite de carga
#
# Estructura esperada JUNTO a este script:
#   setup_master.sh
#   config/            <- dotfiles que se despliegan en ~/.config
#     niri/  noctalia/  foot/
#   local-bin/         <- scripts personales -> ~/.local/bin (puede ir vacio)
#   sugar-dark-horus/    <- tema SDDM pre-customizado (lo aportas tu)
#   PFP/  Wallpapers/  <- recursos personales (los aportas tu)
#
# La carpeta config/ es la MISMA fuente que alimenta airootfs/etc/skel/ en
# el proyecto horus (ISO). Edita las configs ahi, no en dos lados.

set -uo pipefail

# ── Utilidades de output ─────────────────────────────────────
PURPLE='\033[0;35m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()    { echo -e "${PURPLE}[horus]${NC} $1"; }
ok()     { echo -e "${GREEN}[ok]${NC} $1"; }
warn()   { echo -e "${YELLOW}[warn]${NC} $1"; }
err()    { echo -e "${RED}[err]${NC} $1"; }
section(){ echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; \
           echo -e "${PURPLE}  $1${NC}"; \
           echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ── Registro de resultados (para un resumen final VERAZ) ─────
# En vez de pintar ✔ en todo a ciegas, cada paso registra lo que DE VERDAD pasó:
# si HIZO algo nuevo, si YA ESTABA, si es un AVISO informativo, o si FALLÓ. El
# resumen final y los "pasos siguientes" se construyen a partir de esto, no de
# texto fijo. Así "reinicia por el cursor" solo aparece si el cursor cambió.
CAMBIOS=()   # acciones reales ejecutadas en esta corrida
YA_OK=()     # cosas que ya estaban bien (no se tocó nada)
AVISOS=()    # advertencias informativas (no son fallos)
FALLOS=()    # errores reales

did()   { CAMBIOS+=("$1"); echo -e "${GREEN}[+]${NC} $1"; }   # se hizo algo nuevo
skip()  { YA_OK+=("$1");   echo -e "${PURPLE}[=]${NC} $1"; }  # ya estaba, sin cambios
nota()  { AVISOS+=("$1");  echo -e "${YELLOW}[i]${NC} $1"; }  # aviso informativo
fallo() { FALLOS+=("$1");  echo -e "${RED}[x]${NC} $1"; }     # error real

# Banderas de "pasos siguientes": se encienden SOLO cuando ocurre la acción que
# de verdad las requiere. Si nada cambió, no se sugiere reiniciar ni re-loguear.
NEED_RELOGIN=0          # cerrar sesión y entrar de nuevo (cursor/tema/configs)
NEED_REBOOT=0           # reiniciar (SDDM nuevo, branding de arranque)
RELOGIN_RAZONES=()      # qué cambió que pide re-login
REBOOT_RAZONES=()       # qué cambió que pide reinicio

# ── ¿El setup ya corrió antes en esta máquina? Se detecta por el shortcut
#    horus-start, que sec_configs despliega en la primera corrida. Hay que capturarlo
#    AHORA, antes de que esa sección lo cree, o al final siempre parecería existir.
HORUS_SETUP_PREVIO=0
[ -f "$HOME/.local/bin/horus-start" ] && HORUS_SETUP_PREVIO=1

# ── Flags ────────────────────────────────────────────────────
SKIP_UPDATE=0; DRY_RUN=0; DO_CHECK=0; DO_BATERIA=1; BAT_LIMIT=80; DO_CAPTURAR=0; DO_LIMPIAR=0; SOLO_RAW=""; HORUS_PREVIEW=0
for arg in "$@"; do
    case "$arg" in
        --skip-update)  SKIP_UPDATE=1 ;;
        --dry-run)      DRY_RUN=1 ;;
        --preview)      HORUS_PREVIEW=1 ;;
        --check)        DO_CHECK=1 ;;
        --capturar)     DO_CAPTURAR=1 ;;
        --no-bateria)   DO_BATERIA=0 ;;
        --bateria=*)    BAT_LIMIT="${arg#*=}" ;;
        --limpiar)      DO_LIMPIAR=1 ;;
        --solo=*)       SOLO_RAW="${arg#*=}" ;;
        -h|--help)
            cat <<'EOF'
Horus — setup maestro. Interfaz: atajos horus-* (en PATH tras la 1ª corrida).
  horus-start       corrida completa (muestra el plan y pide confirmación)
  horus-dry         solo el plan, no toca nada
  horus-check       healthcheck post-setup
  horus-sync        vuelca tu ~/.config al repo (para commitear)
  horus-solo SECS   corre solo esas secciones  (horus-solo lista para verlas)
  horus-clean      borra restos de versiones viejas del setup
  horus-update      actualiza mirrors + repos/AUR + flatpaks
Avanzado (flags de uso puntual, sin atajo):
  --preview       muestra el asistente gum SIN instalar nada (verlo sin reinstalar)
  --skip-update   no corre 'pacman -Syu' (iterar rápido)
  --bateria=N     límite de carga N% (default 80; 0 = off)
  --no-bateria    no toca el límite de carga
EOF
            exit 0 ;;
        *) warn "Flag desconocido: $arg (ignorado)" ;;
    esac
done

# Validar el límite de batería: entero 0-100. 0 = desactivar.
if ! [[ "$BAT_LIMIT" =~ ^[0-9]+$ ]] || [ "$BAT_LIMIT" -gt 100 ]; then
    warn "Valor de --bateria inválido ($BAT_LIMIT); usando 80."; BAT_LIMIT=80
fi
[ "$BAT_LIMIT" -eq 0 ] && DO_BATERIA=0

# ── Guard: NO como root ──────────────────────────────────────
# Si se corre con sudo, $HOME seria /root y TODO se configuraria en el lugar
# equivocado de forma silenciosa. Se aborta de inmediato.
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    err "No corras este script como root ni con sudo."
    err "Corre como tu usuario; el script pide sudo cuando lo necesita."
    exit 1
fi

# ── Rutas ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
LOCALBIN_DIR="$SCRIPT_DIR/local-bin"
# Los logs van a una carpeta DEDICADA fuera del repo (estándar XDG para logs de
# usuario). El archivo concreto, uno por corrida, se nombra y crea junto al exec
# de más abajo —así --dry-run/--check no dejan logs vacíos.
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/horus/logs"

# ── AUR helper (una sola vez) ────────────────────────────────
# Solo es imprescindible para INSTALAR (flujo normal). Los modos --dry-run,
# --check y --capturar no instalan nada; aquí solo se detecta. Si falta, se
# aborta más abajo, ya dentro del flujo de instalación.
if command -v paru &>/dev/null; then AUR="paru"
elif command -v yay &>/dev/null; then AUR="yay"
else AUR=""; fi

# LISTAS DE PAQUETES (centralizadas -> instalacion agrupada)
# Repos oficiales: una sola transaccion de pacman (rapido, sin overhead AUR).
PKGS_REPO=(
    # Compositor (las apps de consumo —Steam, Discord, navegador, reproductores…—
    # NO van aquí: las instala el instalador de CachyOS, o el menú de la sección 'opcionales')
    niri
    # Terminal + toys de repo
    foot cava cmatrix tty-clock
    # Gestor de archivos (Qt: se tematiza por PALETA via qt6ct, no por CSS fragil
    # como el GTK de Thunar) + montaje/MTP + thumbnails de video (libfm-qt trae
    # los de imagen; tumbler era el thumbnailer de la era Thunar y ya no hace falta)
    pcmanfm-qt qt6ct
    gvfs gvfs-mtp ffmpegthumbnailer
    # Archivador GUI + motores de compresión: el menú "Comprimir/Extraer" de
    # PCManFM-Qt invoca el Archiver fijado en config/pcmanfm-qt (xarchiver).
    # p7zip/zip/unzip son el backend; tar/gzip/bzip2/xz vienen en el sistema base.
    xarchiver p7zip zip unzip
    # Meta de gaming oficial de CachyOS (proton-cachyos, wine, vulkan, gamemode…).
    # OJO (jul 2026): el meta YA NO trae mangohud/gamescope/lutris/heroic como deps
    # duras — se listan explicitos abajo. Requiere multilib.
    cachyos-gaming-meta
    # Overlay de metricas en juego (FPS/GPU/CPU); horus-theme genera su .conf
    # con la paleta del tema activo (gen_mangohud). lib32 para juegos de 32 bits.
    mangohud lib32-mangohud
    # Microcompositor por-juego: upscale FSR / cap de FPS via horus-fsr (local-bin)
    gamescope
    # Gestor GUI de versiones Proton-GE / Wine-GE para Steam, Lutris y Heroic
    protonplus
    # Iconos (base; las carpetas por tema salen del overlay Horus-Folders de horus-theme)
    papirus-icon-theme
    # SDDM (el tema sugar-dark-horus ya no usa QtGraphicalEffects; qt5-quickcontrols2
    # se mantiene por si pruebas el greeter en modo Qt5)
    sddm qt5-quickcontrols2
    # Portal del selector de archivos (dialogos con tema morado)
    xdg-desktop-portal xdg-desktop-portal-gtk
    # Herramientas para generar el cursor morado
    imagemagick xorg-xcursorgen xcur2png
    # Flatpak (para el Sober opcional de la sección [5])
    flatpak
    # Fuentes (ttf-meslo-nerd para glifos en prompt/fastfetch/Noctalia)
    ttf-meslo-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk
    # Notificaciones (notify-send): lo usa 'proyectar toggle' para avisar el modo
    libnotify
    # Luz nocturna (filtro de luz azul): wlsunset ajusta la temperatura de color
    # según el amanecer/atardecer. Se lanza desde el autostart de Niri.
    wlsunset
)

# AUR: una sola invocacion del helper. Incluye dudosos (paru los toma de repos
# si resulta que no son AUR, sin tronar el batch).
PKGS_AUR=(
    lavat-git cbonsai
    catppuccin-gtk-theme-mocha bibata-cursor-theme rar   # papirus-folders fuera: las carpetas por tema las genera horus-theme (overlay Horus-Folders)
    wob                             # OSD del brillo del teclado (horus-kbd-osd)
    # Launcher de Epic/GOG/Amazon; tema CSS Horus lo genera horus-theme (gen_heroic)
    heroic-games-launcher-bin
    # Espejo de pantalla para presentaciones (modo 'espejo' de ~/.local/bin/proyectar).
    # Niri no clona salidas de forma nativa; wl-mirror es el unico camino (fragil).
    wl-mirror
)

# ── Bundle de apps OPCIONALES (consumo) — lo consume la sección 'opcionales' ──
# UNA sola pregunta instala todo este set. Para sumar apps, agrégalas al canal que
# toque y ya; la lógica no se toca. Steam/Discord/OBS van aquí cuando los quieras
# (Steam pide multilib habilitado —en CachyOS viene activo— y su fix de ventana
#  negra en Wayland ya vive en 'generables': como 'opcionales' corre antes, el fix
#  se aplica solo en la misma pasada al detectar Steam instalado).
BUNDLE_REPO=(
    vlc vlc-plugins-all             # multimedia (Arch dividió vlc en jul-2025; -all = todos los códecs)
    imv                             # visor de imagenes (Wayland-native, ligero)
    steam                           # requiere multilib (activo en CachyOS); fix de tiling en rules.kdl
    obs-studio
)
BUNDLE_AUR=(
    zen-browser-bin                 # navegador
    onlyoffice-bin                  # OnlyOffice
    vscodium-bin                    # VSCodium (VS Code sin telemetría)
)
BUNDLE_FLATPAK=(
    org.vinegarhq.Sober             # Roblox (Sober) — FFlags se aplican en 'opcionales'
)

# ── Helpers de instalacion ───────────────────────────────────
# Devuelve, de una lista, solo los que NO estan instalados.
faltantes() {
    local out=() p
    for p in "$@"; do pacman -Q "$p" &>/dev/null || out+=("$p"); done
    echo "${out[@]}"
}

instala_repo() {  # $@ = paquetes de repos oficiales
    local pend; pend=$(faltantes "$@")
    if [ -z "$pend" ]; then skip "Repos: todo presente (nada que instalar)."; return; fi
    log "Instalando de repos: $pend"
    if sudo pacman -S --needed --noconfirm $pend; then
        did "Repos instalados: $pend"
    else
        # Un solo paquete malo tumba la transacción ENTERA de pacman. Reintento
        # uno por uno: se instala lo que sí se puede y se identifica al culpable.
        warn "El batch de pacman falló; reintentando paquete por paquete..."
        local p oks=() bads=()
        for p in $pend; do
            if sudo pacman -S --needed --noconfirm "$p" &>/dev/null; then oks+=("$p")
            else bads+=("$p"); fi
        done
        [ "${#oks[@]}" -gt 0 ] && did "Repos instalados (individual): ${oks[*]}"
        [ "${#bads[@]}" -gt 0 ] && fallo "Repos que NO se pudieron instalar: ${bads[*]}"
    fi
}

instala_aur() {   # $@ = paquetes AUR
    local pend; pend=$(faltantes "$@")
    if [ -z "$pend" ]; then skip "AUR: todo presente (nada que compilar)."; return; fi
    # rar (AUR) conflictúa con unrar (repos) y trae su propio unrar. Si vamos a
    # instalar rar y unrar está presente, se quita ANTES: de lo contrario el batch
    # entero aborta al pedir confirmación del conflicto (--noconfirm responde 'No'
    # y la transacción de pacman falla, tumbando todos los paquetes con ella).
    if printf '%s\n' $pend | grep -qx 'rar' && pacman -Qq unrar &>/dev/null; then
        sudo pacman -Rdd --noconfirm unrar && nota "unrar removido (rar lo reemplaza)."
    fi
    log "Instalando de AUR: $pend"
    # --skipreview: no abrir el diff del PKGBUILD (si no, en una build nueva paru
    # se detiene esperando confirmación y rompe el modo desatendido).
    if $AUR -S --needed --noconfirm --skipreview $pend; then
        did "AUR instalado: $pend"
    else
        # Igual que en repos: una build rota no debe tumbar el batch completo.
        warn "El batch de AUR falló; reintentando paquete por paquete (lento)..."
        local p oks=() bads=()
        for p in $pend; do
            if $AUR -S --needed --noconfirm --skipreview "$p"; then oks+=("$p")
            else bads+=("$p"); fi
        done
        [ "${#oks[@]}" -gt 0 ] && did "AUR instalado (individual): ${oks[*]}"
        [ "${#bads[@]}" -gt 0 ] && fallo "AUR que NO se pudo instalar: ${bads[*]}"
    fi
}

# ── Despliegue de configs (carpeta config/ -> ~/.config) ─────
# Backup en una sola carpeta por corrida; solo se crea si de verdad se pisa algo.
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
_backup_hecho=0
# Render node by-path de la iGPU: la tarjeta cuyo driver NO es nvidia. Se usa
# para fijar render-drm-device de Niri en la máquina destino, en vez de dejar el
# PCI de mi equipo hardcodeado en el repo. Devuelve vacío si hay cero o más de
# una candidata (p.ej. iGPU AMD + dGPU AMD): ahí es ambiguo y NO se adivina.
_render_igpu() {
    local card drv pci node; local -a hits=()
    for card in /sys/class/drm/card[0-9]*; do
        [ -e "$card/device/driver" ] || continue
        drv=$(basename "$(readlink -f "$card/device/driver")")
        case "$drv" in amdgpu|i915|xe) ;; *) continue ;; esac
        pci=$(basename "$(readlink -f "$card/device")")
        node="/dev/dri/by-path/pci-$pci-render"
        [ -e "$node" ] && hits+=("$node")
    done
    [ "${#hits[@]}" = 1 ] && { echo "${hits[0]}"; return 0; }
    return 1
}

deploy() {  # $1 = ruta relativa dentro de config/  (ej: niri, foot, noctalia/settings.json)
    local rel="$1" src="$CONFIG_DIR/$1" dst="$HOME/.config/$1"
    if [ ! -e "$src" ]; then nota "config/$rel no existe en el paquete; se omite."; return; fi
    # ¿El destino ya es byte-idéntico al fuente? Entonces NO hay cambio real.
    if [ -e "$dst" ] && diff -rq "$src" "$dst" &>/dev/null; then
        skip "Config ~/.config/$rel ya estaba al día."
        return
    fi
    if [ -e "$dst" ]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp -r "$dst" "$BACKUP_DIR/$rel" && _backup_hecho=1
    fi
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    if cp -r "$src" "$dst"; then
        did "Config desplegada: ~/.config/$rel"
        # Config de la sesión activa -> conviene re-loguear/recargar para verla.
        NEED_RELOGIN=1; RELOGIN_RAZONES+=("config $rel")
    else
        fallo "No se pudo desplegar config/$rel."
    fi
}

# Escribe en $1 el contenido recibido por STDIN, pero SOLO si cambió respecto a
# lo que ya había. Reporta did/skip con la etiqueta $2. Devuelve 0 si escribió
# (cambió), 1 si no hubo cambios, 2 si falló. Útil para encadenar acciones.
write_if_changed() {  # $1 = ruta destino, $2 = etiqueta; contenido por STDIN
    local dst="$1" label="$2" tmp; tmp=$(mktemp)
    cat > "$tmp"
    if [ -f "$dst" ] && diff -q "$tmp" "$dst" &>/dev/null; then
        skip "$label: ya estaba al día."; rm -f "$tmp"; return 1
    fi
    mkdir -p "$(dirname "$dst")"
    if mv "$tmp" "$dst"; then
        chmod 644 "$dst"   # mktemp crea en 600; los configs deben quedar legibles (644)
        did "$label."; return 0
    else fallo "No se pudo escribir $label."; rm -f "$tmp"; return 2; fi
}

# ── Helpers compartidos por varias secciones ────────────────
# (GTK los usan las secciones gtk y cursor; preguntar_si la usa opcionales)
GTK3_CONF="$HOME/.config/gtk-3.0/settings.ini"; GTK4_CONF="$HOME/.config/gtk-4.0/settings.ini"
apply_gtk_key() {
    local file="$1" key="$2" value="$3"; mkdir -p "$(dirname "$file")"
    if [[ ! -f "$file" ]]; then printf "[Settings]\n%s=%s\n" "$key" "$value" > "$file"; return; fi
    if grep -q "^$key=" "$file" 2>/dev/null; then sed -i "s|^$key=.*|$key=$value|" "$file"
    elif grep -q "^\[Settings\]" "$file" 2>/dev/null; then sed -i "/^\[Settings\]/a $key=$value" "$file"
    else printf "[Settings]\n%s=%s\n" "$key" "$value" >> "$file"; fi
}

# Pregunta s/N. Devuelve 0 (sí) solo con respuesta afirmativa explícita.
preguntar_si() {  # $1 = texto de la pregunta
    if [ ! -t 0 ]; then nota "Sin terminal interactiva; se omite: $1."; return 1; fi
    local r; read -rp "  ¿$1? [s/N] " r
    [[ "$r" =~ ^[sSyY] ]]
}

# Imprime el plan: que se instalaria y que se desplegaria. No toca nada.
# Para el PLAN: imprime la lista de paquetes que faltan, o un aviso claro si no
# falta ninguno (antes la línea quedaba vacía tras los dos puntos).
_pend_txt() { local p; p=$(faltantes "$@"); [ -n "$p" ] && echo "$p" || echo "(nada, ya está instalado)"; }

# Verificación REAL de los "ajustes extra": devuelve solo los que AÚN no están
# aplicados en el sistema (no un texto fijo). Así el plan deja de anunciarlos como
# pendientes en re-corridas donde ya están hechos. Mira el estado ACTIVO, con los
# mismos criterios que el healthcheck (--check):
#   • foot moderno  -> ~/.config/foot/foot.ini ya trae la sección [colors-dark]
#   • foot difuminado-> ~/.config/foot/foot.ini con alpha=0.70 (para que el blur lea)
#   • Noctalia 12h  -> settings.json con use12hourFormat en true
#   • SDDM 12h      -> theme.conf desplegado con HourFormat= descomentado
#   • prompt mínimo -> marca '# horus-prompt' presente en ~/.bashrc
_pend_extras() {
    local pend=()
    # shellcheck disable=SC2178  # 'out' es string; falso positivo por el += de abajo
    local out="" e
    [ -f "$CONFIG_DIR/foot/foot.ini" ] \
        && ! grep -qxF '[colors-dark]' "$HOME/.config/foot/foot.ini" 2>/dev/null \
        && pend+=("foot→sintaxis moderna")
    grep -qE '^alpha=0\.70' "$HOME/.config/foot/foot.ini" 2>/dev/null \
        || pend+=("foot fondo difuminado")
    grep -qE 'use12hourFormat[^,]*true' "$HOME/.config/noctalia/settings.json" 2>/dev/null \
        || pend+=("reloj 12h Noctalia")
    grep -qE '^[[:space:]]*HourFormat=' /usr/share/sddm/themes/sugar-dark-horus/theme.conf 2>/dev/null \
        || pend+=("reloj 12h SDDM")
    grep -q '# horus-prompt' "$HOME/.bashrc" 2>/dev/null \
        || pend+=("prompt minimalista")
    # shellcheck disable=SC2128
    for e in "${pend[@]}"; do [ -n "$out" ] && out+=" · "; out+="$e"; done
    echo "$out"
}
mostrar_plan() {
    section "PLAN (esto es lo que se haría)"
    echo -e "  ${PURPLE}Repos por instalar:${NC}    $(_pend_txt "${PKGS_REPO[@]}")"
    echo -e "  ${PURPLE}AUR por instalar:${NC}      $(_pend_txt "${PKGS_AUR[@]}")"
    echo -e "  ${PURPLE}Apps opcionales:${NC}       $(_pend_txt "${BUNDLE_REPO[@]}" "${BUNDLE_AUR[@]}") + Sober (flatpak) — set único, se pregunta en 'opcionales'"
    echo -e "  ${PURPLE}Configs a desplegar:${NC}"
    for c in niri noctalia/settings.json foot; do
        [ -e "$CONFIG_DIR/$c" ] && echo "    • ~/.config/$c" || echo "    • (falta config/$c)"
    done
    local _ex; _ex=$(_pend_extras)
    [ -n "$_ex" ] \
        && echo -e "  ${PURPLE}Ajustes extra:${NC}         $_ex" \
        || echo -e "  ${PURPLE}Ajustes extra:${NC}         (nada, ya aplicado)"
    echo -e "  ${PURPLE}Update inicial:${NC}        $([ "$SKIP_UPDATE" -eq 1 ] && echo 'omitido (--skip-update)' || echo 'sí (pacman -Syu)')"
    echo ""
}

# REGISTRO DE SECCIONES (para el flujo normal y para --solo)
# Orden canónico de ejecución. --solo acepta estos nombres o su número.
SECCIONES=(snapshot update repos aur noctalia flatpak opcionales configs generables launcher gtk cursor sddm branding steam teclado recursos proyeccion sesion sistema zen rendimiento gaming privacidad)
declare -A SEC_DESC=(
    [privacidad]="Privacidad de red (DoT, firewall, MAC aleatoria)"
    [snapshot]="Snapshot pre-setup"
    [update]="Actualizar sistema"
    [repos]="Paquetes de repos oficiales"
    [aur]="Paquetes AUR"
    [noctalia]="Noctalia v4 congelado (release del repo)"
    [opcionales]="Apps opcionales"
    [configs]="Configs (Niri, Noctalia, Foot) + scripts"
    [generables]="Generables (Noctalia scheme, fastfetch)"
    [launcher]="Limpieza del lanzador (ocultar no-apps)"
    [gtk]="GTK, iconos y gestor de archivos"
    [cursor]="Cursor morado Bibata"
    [sddm]="SDDM Sugar-Dark"
    [branding]="Branding Horus (systemd-boot)"
    [steam]="Steam (wrapper anti-pantalla-negra del cliente)"
    [teclado]="RGB del teclado (regla udev ITE5570)"
    [recursos]="Recursos + batería"
    [proyeccion]="Utilidad de proyección"
    [sesion]="Sesión: tecla power/tapa → bloqueo (sin suspender)"
    [sistema]="Servicios de sistema (power-hook, keyd, gpu-watch, fix Sober, Noctalia es)"
    [flatpak]="Flatpak + remoto Flathub"
    [zen]="Navegador Zen: tema Horus, prefs y extensiones"
    [rendimiento]="Rendimiento gráfico (supergfxctl, nvtop, horus-power)"
    [gaming]="Gaming — Minecraft Bedrock (mcpelauncher) + shader Newb"
)
# Qué necesita cada sección. Con --solo, si NINGUNA de las elegidas requiere
# sudo no se pide password ni keep-alive (p.ej. --solo=proyeccion corre sin
# privilegios); ídem con la red y con exigir paru/yay.
# 'recursos' solo usa sudo para el servicio de batería: hereda DO_BATERIA.
declare -A SEC_SUDO=( [privacidad]=1 [sistema]=1 [snapshot]=1 [update]=1 [repos]=1 [aur]=1 [opcionales]=1
    [configs]=1 [generables]=0 [launcher]=0 [gtk]=0 [cursor]=0 [sddm]=1 [branding]=1 [steam]=1
    [teclado]=1 [recursos]=$DO_BATERIA [proyeccion]=0 [sesion]=1 [flatpak]=1 [zen]=1 [rendimiento]=1 [gaming]=0 [noctalia]=1 )
declare -A SEC_RED=(  [privacidad]=1 [sistema]=1 [snapshot]=0 [update]=1 [repos]=1 [aur]=1 [opcionales]=1
    [configs]=0 [generables]=0 [launcher]=0 [gtk]=0 [cursor]=0 [sddm]=0 [branding]=0
    [steam]=0 [teclado]=0 [recursos]=0 [proyeccion]=0 [sesion]=0 [flatpak]=1 [zen]=0 [rendimiento]=1 [gaming]=1 [noctalia]=1 )

# Mapeo sección → paquete (taxonomía del asistente). El núcleo SIEMPRE corre.
# El asistente decide qué paquetes encender; la SELECCION se arma filtrando
# SECCIONES por este mapeo, conservando el orden canónico de ejecución.
declare -A SEC_PKG=(
    [snapshot]=nucleo [update]=nucleo [repos]=nucleo [aur]=nucleo
    [configs]=nucleo [generables]=nucleo [launcher]=nucleo [sddm]=nucleo
    [branding]=nucleo [teclado]=nucleo [recursos]=nucleo [proyeccion]=nucleo [sesion]=nucleo [sistema]=nucleo
    [gtk]=cosmeticos [cursor]=cosmeticos
    [flatpak]=apps [opcionales]=apps [zen]=apps [steam]=apps
    [rendimiento]=nucleo [gaming]=gaming [noctalia]=nucleo )

_tabla_secciones() {
    local i=1 sec
    echo "Secciones disponibles (--solo=nombre o --solo=N, separa con comas):"
    for sec in "${SECCIONES[@]}"; do
        printf '  %2d  %-12s %s\n' "$i" "$sec" "${SEC_DESC[$sec]}"
        i=$((i+1))
    done
}

# Resolución de --solo -> SOLO_SECS, en orden canónico y sin duplicados.
SOLO_SECS=()
if [ -n "$SOLO_RAW" ]; then
    if [[ "$SOLO_RAW" == "lista" || "$SOLO_RAW" == "list" ]]; then
        _tabla_secciones; exit 0
    fi
    declare -A _pedidas=()
    IFS=',' read -ra _toks <<< "$SOLO_RAW"
    for _t in "${_toks[@]}"; do
        _t="${_t//[[:space:]]/}"; [ -z "$_t" ] && continue
        if [[ "$_t" =~ ^[0-9]+$ ]] && [ "$_t" -ge 1 ] && [ "$_t" -le "${#SECCIONES[@]}" ]; then
            _pedidas["${SECCIONES[$((_t-1))]}"]=1
        elif [ -n "${SEC_DESC[$_t]:-}" ]; then
            _pedidas["$_t"]=1
        else
            err "Sección desconocida en --solo: '$_t'"; _tabla_secciones; exit 1
        fi
    done
    for _t in "${SECCIONES[@]}"; do
        [ -n "${_pedidas[$_t]:-}" ] && SOLO_SECS+=("$_t")
    done
    if [ "${#SOLO_SECS[@]}" -eq 0 ]; then
        err "--solo no recibió ninguna sección válida."; _tabla_secciones; exit 1
    fi
fi

# MODO --dry-run : solo el plan, no toca nada
if [ "$DRY_RUN" -eq 1 ]; then
    if [ "${#SOLO_SECS[@]}" -gt 0 ]; then
        section "PLAN (--solo)"
        echo -e "  ${PURPLE}Se correrían SOLO estas secciones, en este orden:${NC}"
        for _t in "${SOLO_SECS[@]}"; do echo "    • $_t — ${SEC_DESC[$_t]}"; done
        echo ""
    else
        mostrar_plan
    fi
    exit 0
fi

# MODO --check : healthcheck post-setup
if [ "$DO_CHECK" -eq 1 ]; then
    section "Healthcheck Horus"
    chk(){ if eval "$2" &>/dev/null; then ok "$1"; else warn "$1 — FALTA"; fi; }
    chk "Niri instalado"               "pacman -Q niri"
    chk "Noctalia v4 congelado (4.7.7-3)" "pacman -Q noctalia-shell | grep -q 4.7.7-3"
    chk "Config de Niri desplegada"    "test -f $HOME/.config/niri/config.kdl"
    chk "settings.json de Noctalia"    "test -f $HOME/.config/noctalia/settings.json"
    chk "Color scheme 'Horus Project'"        "test -f '$HOME/.config/noctalia/colorschemes/Horus Project/Horus Project.json'"
    chk "foot.ini desplegado"          "test -f $HOME/.config/foot/foot.ini"
    chk "foot en sintaxis moderna"     "grep -qxF '[colors-dark]' $HOME/.config/foot/foot.ini"
    chk "foot fondo difuminado"        "grep -qE '^alpha=0?\.[0-9]' $HOME/.config/foot/foot.ini"
    chk "Noctalia reloj 12h"           "grep -qE 'use12hourFormat[^,]*true' $HOME/.config/noctalia/settings.json"
    chk "Cursor morado generado"       "test -d $HOME/.icons/Bibata-Modern-Purple/cursors"
    chk "Fuente Nerd (Meslo)"          "pacman -Q ttf-meslo-nerd"
    chk "SDDM habilitado"              "systemctl is-enabled sddm"
    chk "Tema SDDM sugar-dark-horus"     "test -d /usr/share/sddm/themes/sugar-dark-horus"
    chk "SDDM reloj 12h (HourFormat)"  "grep -qE '^HourFormat=' /usr/share/sddm/themes/sugar-dark-horus/theme.conf"
    chk "Fastfetch logo"               "test -f $HOME/.config/fastfetch/logo.txt"
    chk "Prompt minimalista (PS1)"     "grep -q '# horus-prompt' $HOME/.bashrc"
    chk "Utilidad de proyección"       "test -x $HOME/.local/bin/proyectar"
    chk "Límite de batería (asusd)"     "asusctl battery info 2>/dev/null | grep -q ${BAT_LIMIT}%"
    chk "Kernel: imagen presente en /boot"  "ls /boot/vmlinuz-* &>/dev/null"
    chk "Kernel: paquete linux* instalado"  "pacman -Qq | grep -qE '^linux(-cachyos|-lts|-zen|-hardened|-rt)?\$'"
    chk "Kernel: entrada en systemd-boot"   "sudo ls /boot/loader/entries/ &>/dev/null"
    echo -e "  ${PURPLE}Kernels:${NC} instalados [$(pacman -Qq 2>/dev/null | grep -E '^linux(-cachyos|-lts|-zen|-hardened|-rt)?$' | paste -sd', ' -)]  ·  corriendo [$(uname -r)]"
    echo ""
    exit 0
fi

# MODO --capturar : vuelca lo ACTIVO (~/.config) de vuelta al REPO
# El despliegue normal va repo -> ~/.config y PISA el activo (rm -rf). Todo lo
# que ajustes por GUI (Noctalia) o a mano vive SOLO en el activo y se pierde en
# la siguiente corrida. Este modo hace el camino inverso: copia el estado activo
# al repo para que el repo quede como fuente de verdad. Es lo que corres ANTES
# de comprimir/commitear Configs para migrar a otra maquina.
# NO instala nada ni pide sudo: solo escribe dentro de $CONFIG_DIR.
if [ "$DO_CAPTURAR" -eq 1 ]; then
    section "Capturar configs activas -> repo"
    _cap_bk="$SCRIPT_DIR/.repo-backup-$(date +%Y%m%d-%H%M%S)"
    _cap_n=0

    _bk_repo() {  # respalda config/$1 dentro de _cap_bk antes de pisarlo
        local rel="$1"
        [ -e "$CONFIG_DIR/$rel" ] || return 0
        mkdir -p "$_cap_bk/$(dirname "$rel")"
        cp -r "$CONFIG_DIR/$rel" "$_cap_bk/$rel"
    }

    capturar() {  # $1 = ruta relativa dentro de config/ (carpeta o archivo)
        local rel="$1" src="$HOME/.config/$1" dst="$CONFIG_DIR/$1"
        # shellcheck disable=SC2088  # la tilde es texto del mensaje, no una ruta
        [ -e "$src" ] || { nota "~/.config/$rel no existe; se omite."; return; }
        if [ -e "$dst" ] && diff -rq "$src" "$dst" &>/dev/null; then
            skip "Repo ya tenía config/$rel al día."; return
        fi
        _bk_repo "$rel"
        mkdir -p "$(dirname "$dst")"; rm -rf "$dst"
        if cp -r "$src" "$dst"; then did "Capturado al repo: config/$rel"; _cap_n=$((_cap_n+1))
        else fallo "No se pudo capturar config/$rel."; fi
    }

    # Simétrico a lo que el despliegue toca: niri y foot como carpeta completa.
    capturar niri
    capturar foot

    # Noctalia: SOLO settings.json (la carpeta colorschemes/ la genera el setup,
    # no se captura). Se normaliza igual que en el despliegue para que el repo
    # quede canónico pase lo que pase en el activo: scheme fijo "Horus Project" y sin
    # colores de wallpaper. Las rutas se dejan; el despliegue las reescribe a
    # $SCRIPT_DIR en destino.
    _sns="$HOME/.config/noctalia/settings.json"; _dns="$CONFIG_DIR/noctalia/settings.json"
    if [ -f "$_sns" ]; then
        _t=$(mktemp)
        sed -e 's/"predefinedScheme": *"[^"]*"/"predefinedScheme": "Horus Project"/' \
            -e 's/"useWallpaperColors": *true/"useWallpaperColors": false/' \
            -e 's/"use12hourFormat": *false/"use12hourFormat": true/' \
            "$_sns" > "$_t"
        if [ -f "$_dns" ] && diff -q "$_t" "$_dns" &>/dev/null; then
            skip "Repo ya tenía noctalia/settings.json al día."
        else
            _bk_repo "noctalia/settings.json"
            mkdir -p "$(dirname "$_dns")"
            if cp "$_t" "$_dns"; then did "Capturado al repo: config/noctalia/settings.json"; _cap_n=$((_cap_n+1))
            else fallo "No se pudo capturar noctalia/settings.json."; fi
        fi
        rm -f "$_t"
    else
        # shellcheck disable=SC2088  # tilde como texto del mensaje
        nota "~/.config/noctalia/settings.json no existe; se omite."
    fi

    echo ""
    if [ "$_cap_n" -gt 0 ]; then
        ok "Captura lista: $_cap_n cambio(s) volcado(s) al repo."
        log "Respaldo del repo previo: $_cap_bk"
        log "Ahora commitea (git) o comprime ~/Documentos/Configs para migrar."
    else
        ok "Nada que capturar: el repo ya reflejaba tu config activa."
        rmdir "$_cap_bk" 2>/dev/null || true
    fi
    exit 0
fi

# MODO --limpiar : borra restos de versiones viejas del setup
# Antes el setup duplicaba PFP/Wallpapers a ~/Imágenes y dejaba un log único en
# el repo. Ya no: las imágenes viven en el propio repo (Noctalia las lee de ahí)
# y los logs van a ~/.local/state/horus/logs. Esto borra esos restos. Pide
# confirmación y NO toca nada del sistema. (Reemplaza al viejo limpiar_huerfanos.sh.)
if [ "$DO_LIMPIAR" -eq 1 ]; then
    section "Limpieza de huérfanos"
    OBJETIVOS=(
        "$HOME/Imágenes/PFP"
        "$HOME/Imágenes/Wallpapers"
        "$SCRIPT_DIR/setup_master.log"
    )
    PRESENTES=()
    for t in "${OBJETIVOS[@]}"; do
        if [ -e "$t" ]; then
            echo -e "  ${YELLOW}•${NC} $t  ($(du -sh "$t" 2>/dev/null | cut -f1))"
            PRESENTES+=("$t")
        fi
    done
    if [ "${#PRESENTES[@]}" -eq 0 ]; then
        ok "Nada que borrar, ya está limpio."
        exit 0
    fi
    echo ""
    read -rp "$(echo -e "${YELLOW}¿Borrar lo de arriba? [s/N]: ${NC}")" _r
    if [[ "$_r" =~ ^[sS]$ ]]; then
        for t in "${PRESENTES[@]}"; do
            rm -rf "$t" && ok "Borrado: $t"
        done
    else
        warn "Cancelado, no se borró nada."
    fi
    exit 0
fi

# PLAN + CONFIRMACION (flujo completo pregunta; --solo va directo)
if [ "${#SOLO_SECS[@]}" -eq 0 ]; then
    # Asistente interactivo (idioma → modo → paquetes → tema). Vive en lib/ui.sh;
    # lo comparte preview/ui-preview.sh para que ambos usen la misma UI.
    if [ ! -f "$SCRIPT_DIR/lib/ui.sh" ]; then
        err "Falta $SCRIPT_DIR/lib/ui.sh (capa de interfaz del instalador)."; exit 1
    fi
    HORUS_SDBOOT=1; bootctl is-installed &>/dev/null || HORUS_SDBOOT=0
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/ui.sh"
    [ "${HORUS_PREVIEW:-0}" -eq 1 ] && export HORUS_UI_PREVIEW=1
    horus_wizard || { echo; exit 0; }   # cancelar en el asistente = salir limpio

    # Puente asistente → maquinaria: HORUS_MODE + HORUS_PKGS -> PKG_ON.
    # El núcleo siempre entra; el loop de abajo (intacto) arma SELECCION.
    declare -A PKG_ON=([nucleo]=1)
    case "$HORUS_MODE" in
        full)
            PKG_ON+=([cosmeticos]=1 [apps]=1 [gaming]=1) ;;
        custom)
            for _p in "${HORUS_PKGS[@]}"; do PKG_ON[$_p]=1; done ;;
        min) : ;;
    esac
    SELECCION=()
    for _s in "${SECCIONES[@]}"; do
        [ -n "${PKG_ON[${SEC_PKG[$_s]:-}]:-}" ] && SELECCION+=("$_s")
    done

    # Modo preview: enseña el plan resultante y sale sin tocar nada.
    if [ "$HORUS_PREVIEW" -eq 1 ]; then
        section "PLAN (preview — no se instala nada)"
        echo -e "  ${PURPLE}Idioma:${NC} $HORUS_LANG_NAME   ${PURPLE}Modo:${NC} $HORUS_MODE   ${PURPLE}Tema:${NC} ${HORUS_THEME:-(sin tema)}"
        echo -e "  ${PURPLE}Secciones que correrían (${#SELECCION[@]}):${NC}"
        for _t in "${SELECCION[@]}"; do echo "    • $_t — ${SEC_DESC[$_t]}"; done
        echo ""; ok "Preview terminada — no se instaló ni cambió nada."
        exit 0
    fi
else
    # Con --solo NO se pregunta: elegir secciones explícitamente ya es consentir.
    SELECCION=("${SOLO_SECS[@]}")
    section "Modo --solo: ${SELECCION[*]}"
fi

# ¿Qué necesita la selección? (en el flujo completo: todo, como siempre)
NECESITA_SUDO=0; NECESITA_RED=0; NECESITA_AUR=0
for _t in "${SELECCION[@]}"; do
    [ "${SEC_SUDO[$_t]}" = "1" ] && NECESITA_SUDO=1
    [ "${SEC_RED[$_t]}"  = "1" ] && NECESITA_RED=1
    case "$_t" in aur|opcionales|rendimiento) NECESITA_AUR=1 ;; esac
done

# AUR helper: obligatorio solo si se van a instalar paquetes AUR.
if [ "$NECESITA_AUR" -eq 1 ] && [ -z "$AUR" ]; then
    err "No se encontró paru ni yay. Instala uno primero."; exit 1
fi

# Aviso + log (+ sudo con keep-alive solo si la selección lo pide)
if [ "$NECESITA_SUDO" -eq 1 ]; then
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  ADVERTENCIA: Este script requiere sudo.${NC}"
    echo -e "${YELLOW}  Al terminar NO reinicia solo; hazlo manual con 'sudo reboot'.${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
fi

# Todo el output queda registrado para revisar warnings que pasan volando.
# Un archivo POR CORRIDA (nombre con fecha-hora): ni se sobrescriben ni se apilan
# en el mismo .log como antes. Se conservan los 10 más recientes; el resto se borra.
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup_$(date +%Y%m%d-%H%M%S).log"
ls -1t "$LOG_DIR"/setup_*.log 2>/dev/null | tail -n +10 | xargs -r rm -f
# El archivo se guarda SIN códigos ANSI (sed -u, line-buffered) para que sea
# legible con less/grep; la terminal conserva los colores normales.
exec > >(tee >(sed -u $'s/\x1b\\[[0-9;]*m//g' > "$LOG_FILE")) 2>&1
ln -sfn "$LOG_FILE" "$LOG_DIR/setup-latest.log"   # acceso rápido al último
log "Log de esta corrida: $LOG_FILE ($(date))"

# Ctrl+C a mitad de corrida: avisar dónde quedó el log antes de salir.
trap 'echo ""; err "Interrumpido (Ctrl+C). El sistema puede haber quedado a medio configurar."; \
      err "Log parcial: $LOG_FILE — re-corre el script para completar (es idempotente)."; exit 130' INT

if [ "$NECESITA_SUDO" -eq 1 ]; then
    sudo -v || { err "Se necesita sudo."; exit 1; }
    # Keep-alive: refresca el timestamp de sudo en background mientras corre el
    # script (el rebuild del cursor puede pasarse de los ~15 min del timeout, y sin
    # esto pacman --noconfirm pediria password a mitad o fallaria).
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_PID=$!
    trap 'kill "$SUDO_PID" 2>/dev/null' EXIT
fi

# ── Check de red: solo si la selección instala/actualiza algo ──
_hay_red() {
    if command -v curl &>/dev/null; then
        curl -sI --max-time 5 https://archlinux.org &>/dev/null && return 0
    fi
    ping -c1 -W2 archlinux.org &>/dev/null || ping -c1 -W2 1.1.1.1 &>/dev/null
}
if [ "$NECESITA_RED" -eq 1 ] && ! _hay_red; then
    err "Sin conexión a internet. Conéctate y vuelve a correr."
    exit 1
fi

# SECCIONES DEL SETUP
# Cada sección es una función sec_<nombre>. El loop del final corre las
# del array SELECCION (todas en el flujo normal, las elegidas con --solo).
# El encabezado "[N/M]" lo imprime el loop con numeración dinámica.

# SECCIÓN «snapshot» — SNAPSHOT PRE-SETUP (red de seguridad)
sec_snapshot() {
# CachyOS trae btrfs + snapper + limine. Un snapshot ANTES de tocar el sistema
# permite revertir si algo sale mal. Solo si snapper esta configurado.
if command -v snapper &>/dev/null && sudo snapper list-configs 2>/dev/null | grep -q root; then
    sudo snapper -c root create -d "pre setup_master Horus" \
        && ok "Snapshot 'pre setup_master' creado (revierte con snapper si hace falta)." \
        || nota "No se pudo crear snapshot; continúo de todos modos."
else
    warn "snapper no configurado para 'root'; sin snapshot. Continúo."
fi
}

# SECCIÓN «update» — ACTUALIZAR SISTEMA
sec_update() {
if [ "$SKIP_UPDATE" -eq 1 ]; then
    warn "Update omitido (--skip-update)."
else
    sudo pacman -Syu --noconfirm && ok "Sistema actualizado." \
        || nota "Actualización con errores, continuando."
fi
}

# SECCIÓN «repos» — PAQUETES DE REPOS (un solo batch)
sec_repos() {
instala_repo "${PKGS_REPO[@]}"
}

# SECCIÓN «aur» — PAQUETES AUR (un solo batch)
sec_aur() {
instala_aur "${PKGS_AUR[@]}"
}

# SECCIÓN «noctalia» — NOCTALIA v4 CONGELADO
# El shell NO se toma de los repos: se instala desde el release del propio repo
# (noctalia-v4-freeze). Motivo: CachyOS sirve la versión del día, y el día que
# suba a v5 toda la integración de Horus (IPC colorScheme, wallpaper, el parche
# de PowerProfileService) deja de existir — v5 es una reescritura en C++/OpenGL
# sin capa QML. Vendorizar los .pkg reproduce el artefacto exacto ya probado,
# sin recompilar y sin depender de que CachyOS siga sirviendo estas versiones.
#
# Contingencia: noctalia-qs es binario compilado contra Qt6. Si un update de Qt
# rompe el ABI, el binario congelado deja de cargar. Para ese día el source está
# forkeado y pineado: Johankyuk/noctalia @ horus-freeze-v4.7.7 y
# Johankyuk/noctalia-qs @ horus-freeze-v0.0.12.
sec_noctalia() {
local base="https://github.com/Johankyuk/Horus-Project/releases/download/noctalia-v4-freeze"
local tmp="/tmp/horus-noctalia-freeze"
local -a PKGS=(
    "noctalia-qs-0.0.12-1.1-x86_64.pkg.tar.zst"
    "noctalia-shell-4.7.7-3-any.pkg.tar.zst"
    "cachyos-niri-noctalia-1.1.2-1-any.pkg.tar.zst"
)
local pins="noctalia-shell noctalia-qs cachyos-niri-noctalia"
local p faltan=0 f ok=1

# --- 1: pin en pacman.conf. Sin esto el primer -Syu se lleva el freeze y todo
#        lo anterior fue en vano. Los tres juntos: si el meta queda libre y pide
#        noctalia-shell>=5, rompe la resolución de dependencias en cada update.
for p in $pins; do
    grep -qE "^IgnorePkg.*\b$p\b" /etc/pacman.conf || faltan=1
done
if [ "$faltan" = 1 ]; then
    sudo cp -n /etc/pacman.conf /etc/pacman.conf.horus-bak 2>/dev/null
    if grep -qE '^IgnorePkg' /etc/pacman.conf; then
        for p in $pins; do
            grep -qE "^IgnorePkg.*\b$p\b" /etc/pacman.conf || \
                sudo sed -i "/^IgnorePkg/ s/\$/ $p/" /etc/pacman.conf
        done
    else
        sudo sed -i "0,/^#IgnorePkg/{s|^#IgnorePkg.*|IgnorePkg   = $pins|}" /etc/pacman.conf
    fi
    did "Noctalia v4 fijado en IgnorePkg (ningún -Syu lo mueve)."
else
    skip "IgnorePkg ya fija Noctalia v4."
fi

# --- 2: ¿ya están las versiones exactas? ---
if [ "$(pacman -Q noctalia-shell 2>/dev/null | awk '{print $2}')" = "4.7.7-3" ] && \
   [ "$(pacman -Q noctalia-qs   2>/dev/null | awk '{print $2}')" = "0.0.12-1.1" ]; then
    skip "Noctalia 4.7.7-3 ya instalado (versión congelada)."
    return
fi

# --- 3: bajar los artefactos. curl y no gh: en un fresh install no hay auth. ---
mkdir -p "$tmp"
for f in "${PKGS[@]}"; do
    [ -s "$tmp/$f" ]     || curl -fsSL -o "$tmp/$f"     "$base/$f"     || ok=0
    [ -s "$tmp/$f.sig" ] || curl -fsSL -o "$tmp/$f.sig" "$base/$f.sig" || ok=0
done
if [ "$ok" != 1 ]; then
    nota "No se pudo bajar el freeze; cayendo al repo (versión del día, puede no ser v4)."
    instala_aur noctalia-shell
    return
fi

# --- 4: instalar. --noconfirm no es cosmético: están en IgnorePkg y pacman
#        pediría confirmación para instalarlos igual. Los .sig se validan
#        contra el keyring de CachyOS del sistema.
log "Instalando Noctalia v4 congelado desde el release"
if (cd "$tmp" && sudo pacman -U --noconfirm "${PKGS[@]}"); then
    did "Noctalia 4.7.7-3 instalado desde el release congelado."
    rm -rf "$tmp"
else
    fallo "Falló pacman -U del freeze de Noctalia."
fi
}

# SECCIÓN «opcionales» — APPS OPCIONALES (menú interactivo)
sec_opcionales() {
# Apps de consumo en UN solo paso: se calcula qué falta de cada canal, se muestra
# el set pendiente y, con un único "s", se instala todo. Reglas heredadas: sin TTY
# (ISO/CI) se salta solo; --dry-run no llega aquí; lo ya instalado no se reinstala.
# Para sumar apps (Steam, Discord, OBS…): edita los arrays BUNDLE_* de arriba.

local pend_repo pend_aur id _zenfp
local -a pend_flat=()

# Limpieza: si quedó Zen por Flatpak (instalacion previa), se quita — el navegador
# pasa a ser el del AUR (zen-browser-bin). Deteccion dinamica del id real.
_zenfp=$(flatpak list --app --columns=application 2>/dev/null | grep -iE 'zen[_-]browser' | head -1)
if [ -n "$_zenfp" ]; then
    if flatpak uninstall --user --noninteractive "$_zenfp" &>/dev/null \
    || flatpak uninstall --noninteractive "$_zenfp" &>/dev/null; then
        did "Zen (Flatpak) eliminado: $_zenfp — queda el del AUR."
    else
        nota "No pude quitar Zen de Flatpak ($_zenfp); quitalo a mano: flatpak uninstall $_zenfp"
    fi
fi

pend_repo=$(faltantes "${BUNDLE_REPO[@]}")
pend_aur=$(faltantes "${BUNDLE_AUR[@]}")
for id in "${BUNDLE_FLATPAK[@]}"; do
    flatpak info --user "$id" &>/dev/null || pend_flat+=("$id")
done

if [ -z "$pend_repo" ] && [ -z "$pend_aur" ] && [ "${#pend_flat[@]}" -eq 0 ]; then
    skip "Apps opcionales: el set completo ya está instalado."
else
    log "Apps opcionales por instalar (un solo set):"
    [ -n "$pend_repo" ]          && echo "    • repos:   $pend_repo"
    [ -n "$pend_aur" ]           && echo "    • AUR:     $pend_aur"
    [ "${#pend_flat[@]}" -gt 0 ] && echo "    • flatpak: ${pend_flat[*]}"
    if preguntar_si "Instalar TODO este set de apps"; then
        [ -n "$pend_repo" ] && instala_repo "${BUNDLE_REPO[@]}"
        [ -n "$pend_aur" ]  && instala_aur  "${BUNDLE_AUR[@]}"
        if [ "${#pend_flat[@]}" -gt 0 ]; then
            flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null
            for id in "${pend_flat[@]}"; do
                flatpak install --user --noninteractive flathub "$id" \
                    && did "Flatpak instalado: $id" \
                    || fallo "No se pudo instalar flatpak: $id"
            done
        fi
    else
        nota "Set de apps opcionales omitido por elección."
    fi
fi

# FFlags de Sober: solo si quedó instalado (recién o de antes); sin Sober su
# carpeta de config no existe y escribir ahí no tendría sentido.
if flatpak info --user org.vinegarhq.Sober &>/dev/null; then
SOBER_CONFIG_DIR="$HOME/.var/app/org.vinegarhq.Sober/config/sober"
write_if_changed "$SOBER_CONFIG_DIR/config.json" "Config de Sober (FFlags)" << 'SOBER_EOF'
{
    "allow_gamepad_permission": true,
    "close_on_leave": false,
    "discord_rpc_enabled": true,
    "discord_rpc_show_join_button": true,
    "enable_gamemode": true,
    "enable_hidpi": true,
    "fflags": {
        "FIntPGSPenetrationMarginMin": "2147483647",
        "FIntPGSPenetrationMarginMax": "2147483647",
        "FFlagGlobalWindActivated": "False",
        "FFlagGlobalWindRendering": "False",
        "FFlagEnableChromeEscapeFix": "True",
        "FFlagEnableChromeMicShimmer": "True",
        "FFlagHandleAltEnterFullscreenManually": "False",
        "DFIntMaxFrameBufferSize": "4",
        "FFlagEnableInGameMenuChrome": "True",
        "FFlagPlayerListChromePushdown": "True",
        "DFFlagTextureQualityOverrideEnabled": "True",
        "FFlagEnableInGameMenuChromeSignalAPI": "True",
        "FIntRenderLocalLightFadeInMs": "0",
        "FFlagNewLightAttenuation": "True",
        "FFlagEnableInGameMenuChromeABTest": "True",
        "FFlagEnableChromePinnedChat": "True",
        "FFlagEnableQuickGameLaunch": "True",
        "FFlagChromeBetaFeature": "True",
        "DFIntTaskSchedulerTargetFps": "999999",
        "FIntRenderShadowIntensity": "0",
        "FFlagDisablePostFx": "True",
        "FIntTerrainArraySliceSize": "0",
        "FIntFullscreenTitleBarTriggerDelayMillis": "3600000",
        "FIntFontSizePadding": "3",
        "FFlagDebugSkyGray": "True"
    },
    "graphics_optimization_mode": "balanced",
    "server_location_indicator_enabled": false,
    "touch_mode": "off",
    "use_console_experience": true,
    "use_libsecret": false,
    "use_opengl": true
}
SOBER_EOF
fi
}

# SECCIÓN «configs» — DESPLIEGUE DE CONFIGS + LIMPIEZA + SCRIPTS
sec_configs() {

# Despliega tus dotfiles desde config/. Esto REEMPLAZA los antiguos parches sed
# (focus ring, keybinds, cursor, gestures): ya vienen correctos en los .kdl.
# NOTA: noctalia/settings.json NO va aquí; se construye parcheado en la sección 'generables' (lleva
# el scheme fijo y las rutas reescritas a $HOME), si no el comparador lo vería
# "cambiado" en cada corrida porque el repo trae rutas /home/kyu.
# niri: se despliega REESCRIBIENDO render-drm-device al render node de la iGPU de
# ESTA máquina. El repo trae un valor concreto (el PCI de mi equipo); copiado tal
# cual, en otra laptop apuntaría a un bus inexistente y Niri caería a la dGPU
# (consumo en batería) o no arrancaría. Se parchea una COPIA TEMPORAL, igual que
# foot: el repo no se toca y queda idempotente. Por diseño da igual qué capture
# horus-sync — el deploy siempre reescribe con lo detectado aquí.
if [ -d "$CONFIG_DIR/niri" ]; then
    _niri_tmp=$(mktemp -d)
    cp -r "$CONFIG_DIR/niri/." "$_niri_tmp/"
    _render=$(_render_igpu)
    if [ -z "$_render" ]; then
        nota "No se pudo identificar la iGPU sin ambigüedad; render-drm-device se deja como viene en el repo."
    elif [ -f "$_niri_tmp/cfg/misc.kdl" ]; then
        sed -i -E "s#(render-drm-device[[:space:]]+)\"[^\"]*\"#\\1\"$_render\"#" "$_niri_tmp/cfg/misc.kdl"
    fi
    _niri_dst="$HOME/.config/niri"
    if [ -e "$_niri_dst" ] && diff -rq "$_niri_tmp" "$_niri_dst" &>/dev/null; then
        skip "Config ~/.config/niri ya estaba al día."
    else
        if [ -e "$_niri_dst" ]; then
            mkdir -p "$BACKUP_DIR"; cp -r "$_niri_dst" "$BACKUP_DIR/niri" && _backup_hecho=1
        fi
        mkdir -p "$(dirname "$_niri_dst")"; rm -rf "$_niri_dst"
        if cp -r "$_niri_tmp" "$_niri_dst"; then
            did "Config desplegada: ~/.config/niri (render-drm-device → ${_render:-sin cambio})."
            NEED_RELOGIN=1; RELOGIN_RAZONES+=("config niri")
        else
            fallo "No se pudo desplegar config/niri."
        fi
    fi
    rm -rf "$_niri_tmp"
else
    nota "config/niri no existe en el paquete; se omite."
fi

# Paleta Qt: el ESQUEMA (colores) sí viaja desde el repo; qt6ct.conf NO, porque
# lleva la ruta absoluta al esquema (cambia por usuario) — lo escribe la sección
# gtk y lo regenera horus-theme (gen_qt6ct) con cada cambio de tema.
deploy qt6ct
# PCManFM-Qt: fija Archiver (xarchiver) y Terminal (foot). OJO: como Noctalia,
# reescribe su settings.conf al cerrar; el repo es la fuente y el deploy lo pisa.
deploy pcmanfm-qt

# foot: se despliega NORMALIZANDO la sintaxis deprecada antes de copiar (lo que
# hacía fix_foot.sh). foot >= 1.23 reemplazó la sección [colors] por
# [colors-dark]/[colors-light] e initial-color-theme pasó a tomar dark/light en
# vez de 0/1; la sintaxis vieja escupe warnings en cada arranque. Se parchea una
# COPIA TEMPORAL (igual que el settings.json de Noctalia más abajo), así el repo
# no se toca y queda idempotente: si el foot.ini del repo ya está en sintaxis
# moderna, el sed es no-op y esto equivale a un 'deploy foot' normal.
if [ -d "$CONFIG_DIR/foot" ]; then
    _foot_tmp=$(mktemp -d)
    cp -r "$CONFIG_DIR/foot/." "$_foot_tmp/"
    if [ -f "$_foot_tmp/foot.ini" ]; then
        sed -i -E -e 's/^\[colors\]$/[colors-dark]/' \
                  -e 's/^(initial-color-theme=)[0-9]+$/\1dark/' "$_foot_tmp/foot.ini"
    fi
    _foot_dst="$HOME/.config/foot"
    if [ -e "$_foot_dst" ] && diff -rq "$_foot_tmp" "$_foot_dst" &>/dev/null; then
        skip "Config ~/.config/foot ya estaba al día."
    else
        if [ -e "$_foot_dst" ]; then
            mkdir -p "$BACKUP_DIR"; cp -r "$_foot_dst" "$BACKUP_DIR/foot" && _backup_hecho=1
        fi
        mkdir -p "$(dirname "$_foot_dst")"; rm -rf "$_foot_dst"
        if cp -r "$_foot_tmp" "$_foot_dst"; then
            did "Config desplegada: ~/.config/foot (sintaxis foot normalizada)."
            NEED_RELOGIN=1; RELOGIN_RAZONES+=("config foot")
        else
            fallo "No se pudo desplegar config/foot."
        fi
    fi
    rm -rf "$_foot_tmp"
else
    nota "config/foot no existe en el paquete; se omite."
fi

# Scripts del ecosistema -> /usr/local/bin (canonico) + symlink en ~/.local/bin
# (compatibilidad con referencias viejas). install -m755 normaliza permisos
# SIEMPRE: un clon sin bit +x ya no reproduce el deploy silenciosamente roto.
if [ -d "$LOCALBIN_DIR" ] && [ -n "$(find "$LOCALBIN_DIR" -type f ! -name '.gitkeep' 2>/dev/null)" ]; then
    mkdir -p "$HOME/.local/bin"
    for _f in "$LOCALBIN_DIR"/*; do
        [ -f "$_f" ] || continue
        _b="${_f##*/}"
        case "$_b" in *.bak*|*.pyc|.gitkeep) continue ;; esac
        sudo install -m755 "$_f" "/usr/local/bin/$_b"
        ln -sf "/usr/local/bin/$_b" "$HOME/.local/bin/$_b"
    done
    did "Scripts desplegados a /usr/local/bin (+symlinks en ~/.local/bin)."
else
    skip "Sin scripts en local-bin (nada que copiar)."
fi

# Limpieza de apps conflictivas: queremos Zen/Foot/PCManFM-Qt como únicos.
# OJO (esto causaba ruido en el log): en CachyOS varios de estos los arrastra un
# meta-paquete (p.ej. cachyos-niri-noctalia depende de cachyos-alacritty-config y
# de xdg-desktop-portal-gnome). Quitarlos a la fuerza ROMPE dependencias y pacman
# escupe errores. Por eso ahora: si algo los requiere, se DEJAN y se reporta como
# aviso; el error crudo de pacman se silencia (&>/dev/null). LC_ALL=C fija el
# idioma de "Required By" para que el parseo no dependa del locale.
log "Revisando apps conflictivas..."
_quitar_pkg() {  # $1 = paquete a intentar remover
    local pkg="$1" reqby
    pacman -Qi "$pkg" &>/dev/null || return 0   # no está -> nada que hacer
    reqby=$(LC_ALL=C pacman -Qi "$pkg" 2>/dev/null | awk -F': ' '/^Required By/{print $2; exit}')
    if [ -n "$reqby" ] && [ "$reqby" != "None" ]; then
        nota "$pkg se deja (lo requiere: $reqby)."
    elif sudo pacman -Rns --noconfirm "$pkg" &>/dev/null; then
        did "Removido: $pkg"
    else
        nota "$pkg no se pudo quitar (dependencias); se deja."
    fi
}
# Nota: Firefox ya NO se quita — el navegador es opcional (Zen se ofrece en [5])
# y alguien puede preferir Firefox. Sí se limpian terminales y file managers
# alternos, porque Foot y PCManFM-Qt sí son base fija del entorno. Thunar (y su
# stack: plugins + tumbler) pasó a conflictivo tras la migración a Qt: su theming
# GTK-CSS era frágil y fue lo que descarriló la personalización fuera del morado.
for pkg in chromium google-chrome brave-bin \
           vivaldi vivaldi-ffmpeg-codecs \
           alacritty kitty wezterm cachyos-alacritty-config \
           nautilus dolphin nemo caja pcmanfm \
           thunar-volman thunar-archive-plugin thunar-media-tags-plugin tumbler thunar; do
    _quitar_pkg "$pkg"
done
# Portal: si quedó el de gnome y NO lo bloquea un meta-paquete, cambiar a gtk.
if pacman -Qi xdg-desktop-portal-gnome &>/dev/null; then
    _reqby=$(LC_ALL=C pacman -Qi xdg-desktop-portal-gnome 2>/dev/null | awk -F': ' '/^Required By/{print $2; exit}')
    if [ -n "$_reqby" ] && [ "$_reqby" != "None" ]; then
        nota "portal-gnome se deja (lo requiere: $_reqby); igual uso portal-gtk."
    else
        sudo pacman -S --needed --noconfirm xdg-desktop-portal-gtk &>/dev/null
        sudo pacman -Rns --noconfirm xdg-desktop-portal-gnome &>/dev/null \
            && did "portal-gnome -> portal-gtk." \
            || nota "No se pudo cambiar portal-gnome a gtk."
    fi
fi

# Zen como navegador predeterminado (Vivaldi quedó desinstalado arriba). Se detecta
# el .desktop real de Zen (AUR) por si su nombre cambia entre versiones.
_zendesktop=$(ls /usr/share/applications/ 2>/dev/null | grep -iE '^zen.*\.desktop$' | head -1)
if [ -n "$_zendesktop" ] && command -v xdg-settings &>/dev/null; then
    if xdg-settings set default-web-browser "$_zendesktop" 2>/dev/null; then
        did "Zen fijado como navegador predeterminado ($_zendesktop)."
    else
        nota "No pude fijar Zen como predeterminado; hazlo con: xdg-settings set default-web-browser $_zendesktop"
    fi
elif [ -z "$_zendesktop" ]; then
    nota "No encontré el .desktop de Zen aún (instálalo en la sección [5] y reintenta)."
fi
}

# SECCIÓN «generables» — GENERABLES KYU (colorscheme, fastfetch, steam, alias)
gen_lanzadores() {
    # Lanzadores .desktop para los wizards interactivos. Idempotente: sobreescribe
    # (archivos 100% generados) y elimina lanzadores de comandos inexistentes.
    # Exec con ruta ABSOLUTA: el entorno de Niri no garantiza ~/.local/bin en PATH.
    local _dir="$HOME/.local/share/applications" _id _nombre _cmd _ruta _ejec
    mkdir -p "$_dir"
    while IFS='|' read -r _id _nombre _cmd; do
        if [ -x "/usr/local/bin/$_cmd" ]; then _ruta="/usr/local/bin/$_cmd"
        else
            _ruta=$(command -v "$_cmd" 2>/dev/null) || {
                nota "Lanzador omitido: $_nombre ($_cmd no existe)"
                rm -f "$_dir/horus-$_id.desktop"; continue; }
        fi
        _ejec="foot -e $_ruta"
        # horus-estado termina al instante: pausa para que foot no se cierre.
        [ "$_id" = "estado" ] && _ejec="foot -e bash -c \"$_ruta; read -rsn1\""
        cat > "$_dir/horus-$_id.desktop" <<DESKEOF
[Desktop Entry]
Type=Application
Name=$_nombre
Comment=Asistente Horus
Exec=$_ejec
Icon=preferences-system
Terminal=false
Categories=Settings;Utility;
DESKEOF
        did "Lanzador: $_nombre -> $_ruta"
    done <<'LISTA'
tema|Horus Tema|horus-theme
privacidad|Horus Privacidad|horus-privacy
estado|Horus Estado|horus-estado
LISTA
    command -v update-desktop-database >/dev/null && update-desktop-database "$_dir" || true
}

sec_privacidad() {
    # El script ya fue desplegado a /usr/local/bin por el deploy de local-bin.
    sudo pacman -S --needed --noconfirm ufw
    /usr/local/bin/horus-privacy --aplicar
}

sec_generables() {
    gen_lanzadores

# --- Color scheme "Horus Project" para Noctalia (paleta morada fija) ---
NOCTALIA_SCHEME_DIR="$HOME/.config/noctalia/colorschemes/Horus Project"
NOCTALIA_SETTINGS="$HOME/.config/noctalia/settings.json"
if write_if_changed "$NOCTALIA_SCHEME_DIR/Horus Project.json" "Color scheme 'Horus Project'" << 'NOCTALIA_EOF'
{
  "dark": {
    "mPrimary": "#7a2be8", "mOnPrimary": "#140622",
    "mSecondary": "#b340e0", "mOnSecondary": "#140622",
    "mTertiary": "#df54a6", "mOnTertiary": "#140622",
    "mError": "#f5567a", "mOnError": "#140622",
    "mSurface": "#140622", "mOnSurface": "#a872f2",
    "mSurfaceVariant": "#1e0c3a", "mOnSurfaceVariant": "#9568d8",
    "mOutline": "#482a92", "mShadow": "#070210",
    "mHover": "#2a1350", "mOnHover": "#a872f2",
    "terminal": {
      "foreground": "#e8dcff", "background": "#160a28",
      "selectionFg": "#a872f2", "selectionBg": "#482a92",
      "cursorText": "#160a28", "cursor": "#7a2be8",
      "normal": { "black": "#2a1350", "red": "#f5567a", "green": "#5ee6a0", "yellow": "#f5c453",
                  "blue": "#7d6ff5", "magenta": "#b340e0", "cyan": "#5fd6e0", "white": "#9568d8" },
      "bright": { "black": "#482a92", "red": "#ff7492", "green": "#74f0b0", "yellow": "#ffd56a",
                  "blue": "#9a8cf5", "magenta": "#cb52ec", "cyan": "#7fe4ec", "white": "#a872f2" }
    }
  },
  "light": {
    "mPrimary": "#7b2fe0", "mOnPrimary": "#f3ecfd",
    "mSecondary": "#b23bd0", "mOnSecondary": "#f3ecfd",
    "mTertiary": "#d44e9e", "mOnTertiary": "#f3ecfd",
    "mError": "#e03a63", "mOnError": "#f3ecfd",
    "mSurface": "#f3ecfd", "mOnSurface": "#2a1750",
    "mSurfaceVariant": "#e5d8f7", "mOnSurfaceVariant": "#5a4684",
    "mOutline": "#c3aee8", "mShadow": "#ddcff0",
    "mHover": "#e0d0f5", "mOnHover": "#2a1750",
    "terminal": {
      "foreground": "#2a1750", "background": "#e5d8f7",
      "selectionFg": "#2a1750", "selectionBg": "#c3aee8",
      "cursorText": "#e5d8f7", "cursor": "#7b2fe0",
      "normal": { "black": "#5a4684", "red": "#e03a63", "green": "#1f9d6b", "yellow": "#b5851d",
                  "blue": "#5a3fd0", "magenta": "#b23bd0", "cyan": "#1d8a99", "white": "#c3aee8" },
      "bright": { "black": "#7a66a4", "red": "#e03a63", "green": "#1f9d6b", "yellow": "#b5851d",
                  "blue": "#5a3fd0", "magenta": "#b23bd0", "cyan": "#1d8a99", "white": "#e0d0f5" }
    }
  }
}
NOCTALIA_EOF
then
    NEED_RELOGIN=1; RELOGIN_RAZONES+=("colorscheme de Noctalia")
fi

# settings.json de Noctalia: se parte del repo, se aplican los parches (scheme
# fijo "Horus Project", sin colores de wallpaper, y las rutas de wallpaper/avatar
# reescritas a la carpeta REAL del repo, $SCRIPT_DIR, donde viven Wallpapers/ y
# PFP/). Usar $SCRIPT_DIR en vez de una ruta fija evita romper si el usuario no
# es "kyu" (VM, ISO) y mantiene todo dentro de ~/Documentos/Configs en tu equipo.
# Se escribe SOLO si el resultado difiere, así queda idempotente.
if [ -f "$CONFIG_DIR/noctalia/settings.json" ]; then
    _ns_tmp=$(mktemp)
    cp "$CONFIG_DIR/noctalia/settings.json" "$_ns_tmp"
    sed -i -e 's/"predefinedScheme": *"[^"]*"/"predefinedScheme": "Horus Project"/' \
           -e 's/"useWallpaperColors": *true/"useWallpaperColors": false/' \
           -e 's/"use12hourFormat": *false/"use12hourFormat": true/' \
           -e "s#/home/kyu/Horus-Project/Wallpapers#$SCRIPT_DIR/Wallpapers#g" \
           -e "s#/home/kyu/Horus-Project/PFP#$SCRIPT_DIR/PFP#g" \
           "$_ns_tmp"
    # Backup de la versión previa solo si de verdad vamos a pisarla con algo distinto.
    if [ -f "$NOCTALIA_SETTINGS" ] && ! diff -q "$_ns_tmp" "$NOCTALIA_SETTINGS" &>/dev/null; then
        mkdir -p "$BACKUP_DIR/noctalia"
        cp "$NOCTALIA_SETTINGS" "$BACKUP_DIR/noctalia/settings.json" && _backup_hecho=1
    fi
    if write_if_changed "$NOCTALIA_SETTINGS" "settings.json de Noctalia (scheme + rutas)" < "$_ns_tmp"; then
        NEED_RELOGIN=1; RELOGIN_RAZONES+=("settings de Noctalia")
    fi
    rm -f "$_ns_tmp"
else
    nota "config/noctalia/settings.json no está en el paquete; se omite."
fi

# --- Forzar a Noctalia a re-aplicar el scheme ---
# Editar el archivo del scheme en disco NO basta: Noctalia muestra la paleta ya
# generada/cacheada. 'darkMode toggle' x2 vuelve al mismo modo y regenera la
# paleta desde el scheme (workaround oficial). Solo si Noctalia está corriendo.
if command -v qs >/dev/null 2>&1 && qs -c noctalia-shell ipc call darkMode toggle >/dev/null 2>&1; then
    sleep 0.4; qs -c noctalia-shell ipc call darkMode toggle >/dev/null 2>&1 || true
    did "Noctalia: paleta regenerada desde el scheme 'Horus Project'."
else
    nota "Noctalia no respondió al IPC (¿no está corriendo?); al entrar a la sesión re-aplica el scheme en Ajustes → Color Scheme, o corre dos veces: qs -c noctalia-shell ipc call darkMode toggle"
fi

# --- Steam: el override .desktop y el wrapper anti-pantalla-negra se movieron a
#     la sección «steam» (necesita sudo para /usr/local/bin; no encaja en esta
#     sección sin privilegios). Ver sec_steam o: setup_master.sh --solo=steam

# --- Fastfetch: logo (ojo de Horus) + config, desde branding/ ---
# Fuente unica: branding/horus-ascii.txt (placeholders $1/$2) y
# branding/config.jsonc (colores base morados; horus-theme los rota al tema).
mkdir -p "$HOME/.config/fastfetch"
write_if_changed "$HOME/.config/fastfetch/logo.txt" "Logo ASCII de fastfetch" \
    < "$SCRIPT_DIR/branding/horus-ascii.txt"
write_if_changed "$HOME/.config/fastfetch/config.jsonc" "Config de fastfetch" \
    < "$SCRIPT_DIR/branding/config.jsonc"
python3 << 'PYEOF' | write_if_changed "$HOME/.config/fastfetch/config.jsonc" "Config de fastfetch"
import os, json, sys
config={"$schema":"https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo":{"source":"~/.config/fastfetch/logo.txt","type":"file","padding":{"right":4}},
  "display":{"color":{"title":"default","keys":"38;2;200;166;249","output":"default","separator":"default"},"percent":{"color":{"green":"38;2;200;166;249","yellow":"38;2;200;166;249","red":"38;2;200;166;249"}}},
  "modules":[{"type":"os","key":"OS","format":"Horus"},"host","kernel","uptime","packages",
    "shell","display","wm","theme","font","cursor","terminal","terminalfont","cpu","gpu",
    "memory","swap",{"type":"disk","folders":"/"},{"type":"localip","showIpv4":True},
    "battery","locale"]}
sys.stdout.write(json.dumps(config,indent=2))
PYEOF
# El alias de colores era redundante: config.jsonc ya fija color-keys y
# color-title. Si una corrida vieja lo dejó en ~/.bashrc, se retira aquí
# (solo la línea EXACTA que este script añadía; un alias custom no se toca).
if grep -qxF "alias fastfetch='fastfetch --color-keys 35 --color-title 95'" ~/.bashrc 2>/dev/null; then
    sed -i "/^alias fastfetch='fastfetch --color-keys 35 --color-title 95'\$/d" ~/.bashrc
    did "Alias redundante de fastfetch retirado de ~/.bashrc (config.jsonc ya trae los colores)."
fi

# --- Prompt minimalista (quita el [usuario@host dir]$ por defecto de bash) ---
# El prompt lo arma bash con la variable PS1; foot solo lo dibuja, no puede
# quitarlo por su cuenta. Se fija al FINAL de ~/.bashrc para PISAR el default del
# sistema. Guard por marca '# horus-prompt' => idempotente (no se reañade en cada
# corrida). Queda vacío; si lo quieres mínimo en vez de vacío, cambia PS1='' por
# PS1='$ ' (o lo que sea) en el heredoc de abajo.
if grep -q '# horus-prompt' ~/.bashrc 2>/dev/null; then
    skip "Prompt minimalista ya estaba en ~/.bashrc."
else
    cat >> ~/.bashrc << 'BASHRC_PS1_EOF'

# horus-prompt
PS1=''
BASHRC_PS1_EOF
    did "Prompt minimalista (PS1) añadido a ~/.bashrc."
fi
}

# SECCIÓN «launcher» — LIMPIEZA DE APPS VISIBLES (ocultar .desktop)
sec_launcher() {
# Oculta del lanzador entradas .desktop que NO son apps de usuario, con override
# a nivel usuario: un .desktop propio en ~/.local/share/applications/ con el MISMO
# nombre y NoDisplay/Hidden=true pisa al del sistema. No desinstala nada, sobrevive
# updates y es reversible (borras el override). Mismo método que usamos en la ISO
# para esconder Plasma.
#
# Para sumar/quitar: edita el array OCULTAR con el NOMBRE EXACTO del .desktop (sin
# ruta ni extension). Si un nombre no coincide con uno real, el override no hace
# nada (crea una entrada oculta fantasma, inofensiva). Para ver los nombres reales
# de lo que hoy aparece en tu lanzador:
#   for d in /usr/share/applications ~/.local/share/applications; do
#     for f in "$d"/*.desktop; do [ -f "$f" ] || continue
#       grep -qiE '^(NoDisplay|Hidden)=true' "$f" && continue
#       printf '%-40s %s\n' "$(basename "$f")" "$(grep -m1 '^Name=' "$f" | cut -d= -f2-)"
#     done; done | sort -u
local APPDIR="$HOME/.local/share/applications"
local MARK="X-Kyu-Launcher-Hide=1"
mkdir -p "$APPDIR"

# Visibles (por NO estar en la lista): VSCodium, ONLYOFFICE, VLC, PCManFM-Qt
# (gestor) + flatpak Sober y Zen (AUR). Todo lo de abajo se oculta.
local -a OCULTAR=(
    # --- no son apps / utilerias de sistema ---
    avahi-discover bssh bvnc        # navegadores Avahi (Zeroconf/SSH/VNC)
    qv4l2 qvidcap                   # utilerias de camara V4L2
    electron36                      # runtime de Electron
    foot footclient foot-server     # terminal foot (se abre con Mod+Return) y extras
    xfce4-about                     # "Acerca de Xfce" (si quedo libxfce4ui)
    qt6ct                           # config de paleta Qt (corre: qt6ct)
    xarchiver                       # PCManFM-Qt lo invoca por comando (Archiver=
                                    # en settings.conf); ya no aplica el veto de la
                                    # era Thunar, que detectaba archivadores por .desktop
    btop                            # monitor TUI
    micro vim                       # editores de terminal
    # --- distro CachyOS ---
    cachyos-hello cachyos-pi
    org.cachyos.KernelManager org.cachyos.scx-manager
    # --- fuera del launcher minimo (siguen instaladas; corren desde terminal) ---
    firefox                         # segundo navegador
    org.gnome.Nautilus              # "Archivos" GNOME (queda PCManFM-Qt como gestor)
    org.gnome.Meld                  # diff (corre: meld)
    org.pulseaudio.pavucontrol      # control de volumen avanzado
    com.shellyorg.shelly            # Shelly
    # --- gaming / hardware: no son de uso diario ---
    io.github.benjamimgois.goverlay # GUI de MangoHud (corre: goverlay)
    lstopo chwd                     # topología de hardware / detección de drivers
)

# 1) Reconciliar: limpiar overrides previos de esta seccion (marcados) y los de
#    versiones anteriores (Hidden=true sin Exec real), para no dejar basura.
local f
for f in "$APPDIR"/*.desktop; do
    [ -f "$f" ] || continue
    if grep -qF "$MARK" "$f" 2>/dev/null; then rm -f "$f"; continue; fi
    if grep -qiE '^(Hidden|NoDisplay)=true' "$f" && ! grep -qiE '^Exec=' "$f"; then rm -f "$f"; fi
done

# 2) Crear los overrides de la lista actual.
local _d
for _d in "${OCULTAR[@]}"; do
    printf '[Desktop Entry]\nType=Application\nName=%s\nNoDisplay=true\n%s\n' \
        "$_d" "$MARK" > "$APPDIR/$_d.desktop"
    chmod 644 "$APPDIR/$_d.desktop"
done
update-desktop-database "$APPDIR" 2>/dev/null || true
did "Launcher: ${#OCULTAR[@]} entradas ocultas (solo apps de uso visibles)."

# 3) Anclados de Noctalia: el LAUNCHER se vacia; el DOCK (pinnedStatic) se fija a la
#    lista de uso, en orden. Zen se detecta por su .desktop (cambia entre versiones).
local NSET="$HOME/.config/noctalia/settings.json"
if [ -f "$NSET" ]; then
    local _r
    _r=$(python3 - "$NSET" <<'PYEOF'
import json,sys,glob,os
p=sys.argv[1]
try: d=json.load(open(p))
except Exception: print("err"); sys.exit()

def find_id(*pats):
    for dd in ["/usr/share/applications", os.path.expanduser("~/.local/share/applications"),
               "/var/lib/flatpak/exports/share/applications",
               os.path.expanduser("~/.local/share/flatpak/exports/share/applications")]:
        for pat in pats:
            for f in sorted(glob.glob(os.path.join(dd, pat))):
                b=os.path.basename(f)
                if b.endswith(".desktop"): return b[:-8]
    return None

zen = find_id("zen.desktop","zen-browser.desktop","zen*.desktop") or "zen"
DOCK = [zen, "steam",
        "onlyoffice-desktopeditors", "codium", "pcmanfm-qt", "org.vinegarhq.Sober"]

ch=[False]
def walk(o):
    if isinstance(o,dict):
        if 'pinnedApps' in o and o.get('pinnedStatic'):          # dock
            if o['pinnedApps'] != DOCK: o['pinnedApps']=DOCK; ch[0]=True
        elif o.get('pinnedApps') and not o.get('pinnedStatic'):  # launcher
            o['pinnedApps']=[]; ch[0]=True
        for v in o.values(): walk(v)
    elif isinstance(o,list):
        for v in o: walk(v)
walk(d)
if ch[0]:
    json.dump(d,open(p,'w'),indent=2,ensure_ascii=False); print("cambiado")
else: print("ok")
PYEOF
)
    case "$_r" in
        cambiado) did "Anclados: launcher vacío y dock fijado (zen, steam, onlyoffice, vscodium, archivos, sober)." ;;
        ok)       skip "Anclados: ya estaban como se quieren." ;;
        *)        nota "No pude procesar settings.json de Noctalia (anclados sin tocar)." ;;
    esac
else
    nota "settings.json de Noctalia ausente; anclados sin tocar."
fi
}

# SECCIÓN «gtk» — GTK / ICONOS / GESTOR DE ARCHIVOS / PORTAL
sec_gtk() {

# Carpetas por tema: las genera horus-theme (overlay Horus-Folders, hereda de
# Papirus-Dark) al aplicar el tema; aqui solo se deja la base segura Papirus-Dark.
apply_gtk_key "$GTK3_CONF" "gtk-icon-theme-name" "Papirus-Dark"
apply_gtk_key "$GTK3_CONF" "gtk-application-prefer-dark-theme" "1"
apply_gtk_key "$GTK4_CONF" "gtk-icon-theme-name" "Papirus-Dark"
apply_gtk_key "$GTK4_CONF" "gtk-application-prefer-dark-theme" "1"
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null || true

# Tema GTK Catppuccin Mocha Mauve (autodetecta el nombre real de la carpeta)
DARK_THEME=""
for d in /usr/share/themes/* "$HOME"/.themes/*; do
    [ -d "$d" ] || continue; b=$(basename "$d")
    echo "$b" | grep -qiE 'catppuccin.*mocha.*mauve' && { DARK_THEME="$b"; break; }
done
[ -z "$DARK_THEME" ] && [ -d /usr/share/themes/adw-gtk3-dark ] && DARK_THEME="adw-gtk3-dark"
if [ -n "$DARK_THEME" ]; then
    _gtk_prev=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
    apply_gtk_key "$GTK3_CONF" "gtk-theme-name" "$DARK_THEME"
    apply_gtk_key "$GTK4_CONF" "gtk-theme-name" "$DARK_THEME"
    gsettings set org.gnome.desktop.interface gtk-theme "$DARK_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
    if [ "$_gtk_prev" = "$DARK_THEME" ]; then
        skip "Tema GTK ya era $DARK_THEME."
    else
        did "Tema GTK aplicado: $DARK_THEME"; NEED_RELOGIN=1; RELOGIN_RAZONES+=("tema GTK")
    fi
fi

# PCManFM-Qt como gestor por defecto
command -v xdg-mime &>/dev/null && xdg-mime default pcmanfm-qt.desktop inode/directory
MIMEAPPS="$HOME/.config/mimeapps.list"; touch "$MIMEAPPS"
_fm_prev=$(grep -c "^inode/directory=pcmanfm-qt.desktop" "$MIMEAPPS" 2>/dev/null || echo 0)
if grep -q "^\[Default Applications\]" "$MIMEAPPS" 2>/dev/null; then
    grep -q "^inode/directory=" "$MIMEAPPS" \
        && sed -i "s|^inode/directory=.*|inode/directory=pcmanfm-qt.desktop|" "$MIMEAPPS" \
        || sed -i "/^\[Default Applications\]/a inode/directory=pcmanfm-qt.desktop" "$MIMEAPPS"
else
    printf "\n[Default Applications]\ninode/directory=pcmanfm-qt.desktop\n" >> "$MIMEAPPS"
fi
systemctl --user restart xdg-desktop-portal-gtk xdg-desktop-portal 2>/dev/null || true
if [ "${_fm_prev:-0}" -ge 1 ]; then
    skip "PCManFM-Qt ya era el gestor por defecto."
else
    did "PCManFM-Qt fijado como gestor de archivos por defecto."
fi

# Paleta Qt: qt6ct.conf lleva la RUTA ABSOLUTA al esquema (por eso no viaja en
# el deploy de configs; el esquema colors/horus.conf sí). horus-theme lo
# regenera al cambiar tema; esto cubre corridas --solo=gtk sin tema al final.
write_if_changed "$HOME/.config/qt6ct/qt6ct.conf" "qt6ct.conf (Fusion + esquema Horus)" << QTEOF
[Appearance]
color_scheme_path=$HOME/.config/qt6ct/colors/horus.conf
custom_palette=true
icon_theme=Papirus-Dark
style=Fusion
standard_dialogs=default
QTEOF
}

# SECCIÓN «cursor» — CURSOR MORADO (Bibata) — lo lento
sec_cursor() {
CURSOR_COLOR="#7a2be8"; CURSOR_THEME="Bibata-Modern-Purple"; CURSOR_SIZE=24
SOURCE_THEME="Bibata-Modern-Classic"; DEST="$HOME/.icons/$CURSOR_THEME"

# Recolorear cada cursor frame por frame es LO LENTO. Si ya esta generado, se
# salta el rebuild y solo se re-aplican settings (instantaneo). El tema/tamaño
# del cursor en Niri ya viene en el config.kdl desplegado: no se parchea aqui.
# Estado previo: ¿el tema ya está generado? ¿los settings ya apuntan a él?
# Esto es lo que evita el falso "cierra sesión por el cursor" cuando no cambió nada.
_cursor_generado=0; _cursor_settings_ok=0
[ -d "$DEST/cursors" ] && [ -n "$(ls -A "$DEST/cursors" 2>/dev/null)" ] && _cursor_generado=1
[ "$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")" = "$CURSOR_THEME" ] \
    && grep -q "XCURSOR_THEME=$CURSOR_THEME" "$HOME/.config/environment.d/cursor.conf" 2>/dev/null \
    && _cursor_settings_ok=1

if [ "$_cursor_generado" -eq 1 ]; then
    skip "Cursor '$CURSOR_THEME' ya generado (sin rebuild)."
else
    log "Generando cursor morado (tarda: recolorea cada cursor)..."
    SOURCE="/usr/share/icons/$SOURCE_THEME"
    if [ ! -d "$SOURCE" ]; then
        fallo "No está $SOURCE_THEME (¿falló bibata-cursor-theme?). Cursor omitido."
    else
        rm -rf "$DEST"; mkdir -p "$DEST/cursors"
        cp "$SOURCE/index.theme" "$DEST/index.theme"
        sed -i "s/Bibata Modern Classic/Bibata Modern Purple/g; s/Bibata-Modern-Classic/Bibata-Modern-Purple/g" "$DEST/index.theme"
        [ -f "$SOURCE/cursor.theme" ] && cp "$SOURCE/cursor.theme" "$DEST/cursor.theme"
        WORKDIR=$(mktemp -d)
        for cursor_file in "$SOURCE/cursors/"*; do
            name=$(basename "$cursor_file")
            if [ -L "$cursor_file" ]; then ln -sf "$(readlink "$cursor_file")" "$DEST/cursors/$name"; continue; fi
            # Guard del cd: si falla, xcur2png/magick correrían en el directorio
            # del cursor ANTERIOR y machacarían sus PNGs. Mejor saltar este cursor.
            if ! mkdir -p "$WORKDIR/$name" || ! cd "$WORKDIR/$name"; then
                nota "Cursor '$name' omitido (no se pudo crear su workdir)."
                continue
            fi
            xcur2png "$cursor_file" > /dev/null 2>&1
            for png in *.png; do
                [ -f "$png" ] && magick "$png" \( -clone 0 -fill "$CURSOR_COLOR" -colorize 100 \) \
                    \( -clone 0 \) -delete 0 -compose Screen -composite "$png"
            done
            config=$(ls *.conf 2>/dev/null | head -1)
            [ -n "$config" ] && xcursorgen "$config" "$DEST/cursors/$name" || cp "$cursor_file" "$DEST/cursors/$name"
        done
        cd "$SCRIPT_DIR" || cd "$HOME" || true; rm -rf "$WORKDIR"
        did "Cursor '$CURSOR_THEME' generado."
    fi
fi

# Cursor universal: GTK, XDG, env (XWayland/Qt/juegos), Flatpak
apply_gtk_key "$GTK3_CONF" "gtk-cursor-theme-name" "$CURSOR_THEME"
apply_gtk_key "$GTK3_CONF" "gtk-cursor-theme-size" "$CURSOR_SIZE"
apply_gtk_key "$GTK4_CONF" "gtk-cursor-theme-name" "$CURSOR_THEME"
apply_gtk_key "$GTK4_CONF" "gtk-cursor-theme-size" "$CURSOR_SIZE"
gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE" 2>/dev/null || true
mkdir -p "$HOME/.icons/default"
printf '[Icon Theme]\nName=Default\nInherits=%s\n' "$CURSOR_THEME" > "$HOME/.icons/default/index.theme"
mkdir -p "$HOME/.config/environment.d"
printf 'XCURSOR_THEME=%s\nXCURSOR_SIZE=%s\n' "$CURSOR_THEME" "$CURSOR_SIZE" > "$HOME/.config/environment.d/cursor.conf"
command -v flatpak &>/dev/null && flatpak override --user --filesystem="$HOME/.icons:ro" \
    --env=XCURSOR_THEME="$CURSOR_THEME" --env=XCURSOR_SIZE="$CURSOR_SIZE" 2>/dev/null
# Solo pedir re-login si el cursor se generó nuevo o si los settings no estaban.
# Si ya estaba todo (caso normal en re-corridas), no se reporta acción ni reinicio.
if [ "$_cursor_generado" -eq 0 ] || [ "$_cursor_settings_ok" -eq 0 ]; then
    NEED_RELOGIN=1; RELOGIN_RAZONES+=("cursor")
    [ "$_cursor_generado" -eq 1 ] && did "Cursor aplicado a GTK/env/Flatpak (settings actualizados)."
else
    skip "Cursor ya estaba aplicado (GTK/env/Flatpak)."
fi
}

# SECCIÓN «sddm» — SDDM Sugar-Dark (morado, español)
sec_sddm() {
    # Regla sudoers acotada: horus-theme recolorea SDDM sin pedir contraseña.
    # El helper es root:root en /usr/local/bin (ya desplegado por configs).
    echo "$USER ALL=(root) NOPASSWD: /usr/local/bin/horus-sddm-apply" | sudo tee /etc/sudoers.d/horus-sddm >/dev/null
    sudo chmod 440 /etc/sudoers.d/horus-sddm
    sudo visudo -c >/dev/null || { rm -f /etc/sudoers.d/horus-sddm; warn "sudoers horus-sddm invalido; removido."; }
local HORUS_THEME="sugar-dark-horus"; local THEME_SRC="$SCRIPT_DIR/$HORUS_THEME"; local THEME_DEST="/usr/share/sddm/themes/$HORUS_THEME"
_sddm_cambio=0

# Reloj 12h (AM/PM) en el greeter: la variable HourFormat del theme.conf (lo que
# hacía reloj_12h.sh). Se garantiza en el theme.conf del REPO ANTES del diff de
# abajo, así llega al instalado vía el deploy normal y queda idempotente: si ya
# está, es no-op; si falta, el deploy detecta el cambio y recopia. Toca el archivo
# del tema (no config/), igual que el script que reemplaza.
SDDM_HFMT='h:mm AP'   # 12h sin cero inicial + AM/PM (ej: 3:05 PM). Para "03:05" usa hh.
_sddm_hourformat() {  # $1 = theme.conf
    local f="$1"
    [ -f "$f" ] || return 0
    if grep -qE '^[[:space:]]*#?[[:space:]]*HourFormat=' "$f"; then
        sed -i -E "s|^[[:space:]]*#?[[:space:]]*HourFormat=.*|HourFormat=\"$SDDM_HFMT\"|" "$f"
    elif grep -q '^\[General\]' "$f"; then
        sed -i "/^\[General\]/a HourFormat=\"$SDDM_HFMT\"" "$f"
    else
        printf 'HourFormat="%s"\n' "$SDDM_HFMT" >> "$f"
    fi
}
[ -d "$THEME_SRC" ] && _sddm_hourformat "$THEME_SRC/theme.conf"
if [ -d "$THEME_SRC" ]; then
    if [ -d "$THEME_DEST" ] && sudo diff -rq "$THEME_SRC" "$THEME_DEST" &>/dev/null; then
        skip "Tema SDDM '$HORUS_THEME' ya estaba al día."
    else
        sudo rm -rf "$THEME_DEST"; sudo cp -r "$THEME_SRC" "$THEME_DEST" \
            && { did "Tema SDDM '$HORUS_THEME' desplegado."; _sddm_cambio=1; } \
            || fallo "No se pudo desplegar el tema SDDM."
    fi
else
    fallo "No se encontró '$THEME_SRC' (copia la carpeta del tema junto al script)."
    nota "SDDM quedará con el tema por defecto."
fi
sudo mkdir -p /etc/sddm.conf.d
if ! sudo grep -q "Current=$HORUS_THEME" /etc/sddm.conf.d/theme.conf 2>/dev/null; then
    sudo bash -c "printf '[Theme]\nCurrent=$HORUS_THEME\n' > /etc/sddm.conf.d/theme.conf" \
        && { did "SDDM apuntado a '$HORUS_THEME'."; _sddm_cambio=1; }
else
    skip "SDDM ya apuntaba a '$HORUS_THEME'."
fi
if systemctl is-enabled sddm &>/dev/null; then
    skip "Servicio SDDM ya habilitado."
else
    sudo systemctl enable sddm &>/dev/null \
        && { did "SDDM habilitado."; _sddm_cambio=1; } \
        || fallo "No se pudo habilitar sddm."
fi
# El greeter solo se ve al próximo arranque: pedir reinicio SOLO si algo cambió.
if [ "$_sddm_cambio" -eq 1 ]; then
    NEED_REBOOT=1; REBOOT_RAZONES+=("greeter SDDM nuevo/actualizado")
fi
}

# SECCIÓN «branding» — BRANDING KYU OS (systemd-boot / sdboot-manage)
# El título del menú NO es configurable de forma fiable en esta versión de
# sdboot-manage: 'autogen' lo deriva del nombre del kernel ("linux-cachyos" ->
# "Linux Cachyos"), ignorando ENTRY_TITLE. Por eso el branding va en dos frentes:
#   1) LINUX_OPTIONS lleva el silencio de ARRANQUE (negro): quiet/loglevel/
#      show_status. NOTA: el apagado NO se silencia por cmdline — systemd-shutdown
#      sube el nivel del kernel él mismo en su fase final (imprime el "killing
#      processes"), y eso es irreductible sin Plymouth. 'autogen' lo respeta en
#      cada update de kernel.
#      DEFAULT_ENTRY="manual" evita que pise 'default @saved'.
#   2) Un script propio (horus-title) reescribe el título a "Horus" y garantiza el
#      silencio; un hook de pacman (zzz-, corre DESPUÉS de sdboot-kernel-update.hook)
#      lo reaplica tras cada autogen.
# Además se desactiva Plymouth por completo (fuera del initramfs Y con
# plymouth-start.service enmascarado) para que no pinte logo durante el arranque.
sec_branding() {
SDB_CONF="/etc/sdboot-manage.conf"
if ! command -v sdboot-manage &>/dev/null || [ ! -f "$SDB_CONF" ]; then
    skip "Sin sdboot-manage en esta máquina (branding de arranque omitido)."
else
    _ts=$(date +%Y%m%d-%H%M%S)
    _cambio=0

    # --- 1. sdboot-manage.conf: silencio en LINUX_OPTIONS + DEFAULT_ENTRY=manual ---
    _opts='LINUX_OPTIONS="zswap.enabled=0 nowatchdog quiet loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 systemd.show_status=false"'
    if ! grep -qF "$_opts" "$SDB_CONF" 2>/dev/null; then
        sudo cp "$SDB_CONF" "${SDB_CONF}.bak-$_ts"
        if grep -qE '^[#[:space:]]*LINUX_OPTIONS=' "$SDB_CONF"; then
            sudo sed -i "s|^[#[:space:]]*LINUX_OPTIONS=.*|$_opts|" "$SDB_CONF"
        else
            echo "$_opts" | sudo tee -a "$SDB_CONF" >/dev/null
        fi
        _cambio=1
    fi
    if ! grep -qE '^DEFAULT_ENTRY="manual"' "$SDB_CONF"; then
        if grep -qE '^[#[:space:]]*DEFAULT_ENTRY=' "$SDB_CONF"; then
            sudo sed -i -E 's|^[#[:space:]]*DEFAULT_ENTRY=.*|DEFAULT_ENTRY="manual"|' "$SDB_CONF"
        else
            echo 'DEFAULT_ENTRY="manual"' | sudo tee -a "$SDB_CONF" >/dev/null
        fi
        _cambio=1
    fi

    # --- 2. Boot negro: Plymouth fuera del initramfs (solo si está presente) ---
    if grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf 2>/dev/null; then
        sudo cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak-$_ts"
        awk '
        /^HOOKS=/{
          s=$0; sub(/^HOOKS=\(/,"",s); sub(/\).*/,"",s)
          n=split(s,a,/[ \t]+/); o=""
          for(i=1;i<=n;i++) if(a[i]!="" && a[i]!="plymouth") o=(o==""?a[i]:o" "a[i])
          print "HOOKS=(" o ")"; next
        }
        {print}
        ' /etc/mkinitcpio.conf | sudo tee /etc/mkinitcpio.conf.kyu >/dev/null
        sudo mv /etc/mkinitcpio.conf.kyu /etc/mkinitcpio.conf
        if sudo mkinitcpio -P &>/dev/null; then
            did "Plymouth retirado del initramfs (arranque en negro)."
            NEED_REBOOT=1; REBOOT_RAZONES+=("plymouth fuera del initramfs")
        else
            fallo "mkinitcpio -P falló tras quitar plymouth; revisa el initramfs."
        fi
    fi

    # --- 2b. Boot negro: además, deshabilitar el servicio de Plymouth ---
    # Quitarlo del initramfs NO basta: CachyOS también lo arranca por systemd en la
    # fase del sistema. Se enmascara plymouth-start.service (idempotente; reversible
    # con 'sudo systemctl unmask plymouth-start.service').
    if pacman -Q plymouth &>/dev/null \
       && [ "$(systemctl is-enabled plymouth-start.service 2>/dev/null)" != "masked" ]; then
        if sudo systemctl mask plymouth-start.service &>/dev/null; then
            did "Plymouth deshabilitado (plymouth-start.service enmascarado)."
            NEED_REBOOT=1; REBOOT_RAZONES+=("plymouth deshabilitado")
        else
            fallo "No se pudo enmascarar plymouth-start.service."
        fi
    fi

    # --- 2c. Shutdown en negro: tema mínimo de Plymouth solo para el apagado ---
    # Plymouth quedó fuera del initramfs y su plymouth-start.service enmascarado, así
    # que el logo NO se ve al bootear. Pero los servicios de apagado
    # (plymouth-{poweroff,reboot,halt}.service, 'static') siguen activos y taparían los
    # mensajes de procesos deteniéndose. Se les da un tema negro liso (módulo script,
    # sin dibujar nada). set-default SIN -R a propósito: cambia solo el symlink que lee
    # el modo shutdown; NO regenera el initramfs, así el boot negro queda intacto.
    if pacman -Q plymouth &>/dev/null; then
        sudo install -Dm644 /dev/stdin /usr/share/plymouth/themes/horus-black/horus-black.plymouth <<'HORUSEOF'
[Plymouth Theme]
Name=Horus Black
Description=Pantalla negra, sin elementos
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/horus-black
ScriptFile=/usr/share/plymouth/themes/horus-black/horus-black.script
HORUSEOF
        sudo install -Dm644 /dev/stdin /usr/share/plymouth/themes/horus-black/horus-black.script <<'HORUSEOF'
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);
HORUSEOF
        if [ "$(plymouth-set-default-theme 2>/dev/null)" != "horus-black" ]; then
            sudo plymouth-set-default-theme horus-black &>/dev/null \
                && did "Apagado en negro: tema Plymouth 'horus-black' aplicado (solo shutdown)." \
                || fallo "No se pudo fijar el tema Plymouth horus-black."
        else
            skip "Tema Plymouth de apagado ya en 'horus-black'."
        fi
    fi

    # --- 3. Script de branding (título Horus + silencio garantizado) ---
    sudo tee /usr/local/bin/horus-title >/dev/null <<'HORUSEOF'
#!/bin/bash
# Reaplica branding Horus a las entradas de systemd-boot tras sdboot-manage:
#   - título "Horus" (sdboot-manage lo deriva del nombre del kernel; esto lo corrige)
#   - arranque silencioso (negro), sin tokens duplicados ni 'splash'
# Lo instala/reaplica el setup (sección branding) y el hook zzz-horus-branding.
set -u
# Distro base real desde os-release (ya sin identidad falsa): "Horus (CachyOS)"
BASE=$(. /etc/os-release 2>/dev/null; echo "${NAME:-Linux}")
SILENCIO=(quiet loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 systemd.show_status=false)
QUITAR=(splash)
shopt -s nullglob
for f in /boot/loader/entries/*.conf; do
  base=$(basename "$f" .conf)
  case "$base" in
    *lts*fallback*) t="Horus ($BASE, LTS, fallback)";;
    *lts*)          t="Horus ($BASE, LTS)";;
    *fallback*)     t="Horus ($BASE, fallback)";;
    *)              t="Horus ($BASE)";;
  esac
  if grep -q '^title' "$f"; then sed -i "s|^title.*|title $t|" "$f"
  else sed -i "1i title $t" "$f"; fi
  line=$(grep -m1 '^options' "$f" || true)
  [ -n "$line" ] || continue
  read -r -a toks <<< "${line#options}"
  out=()
  for tk in "${toks[@]}"; do
    skip=0
    for q in "${QUITAR[@]}" "${SILENCIO[@]}"; do [ "$tk" = "$q" ] && { skip=1; break; }; done
    [ "$skip" -eq 0 ] && out+=("$tk")
  done
  out+=("${SILENCIO[@]}")
  sed -i "s|^options.*|options ${out[*]}|" "$f"
done
HORUSEOF
    sudo chmod +x /usr/local/bin/horus-title

    # --- 4. Hook: reaplica el branding tras cada autogen (update de kernel) ---
    sudo mkdir -p /etc/pacman.d/hooks
    sudo tee /etc/pacman.d/hooks/zzz-horus-branding.hook >/dev/null <<'HORUSEOF'
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = usr/lib/modules/*/vmlinuz
Target = boot/vmlinuz*

[Action]
Description = Reaplicando branding Horus en el menu de arranque
When = PostTransaction
Exec = /usr/local/bin/horus-title
HORUSEOF

    # --- 5. Limpieza de intentos previos (branding viejo de systemd-boot/Limine) ---
    for h in 99-horus-branding.hook zz-horus-branding.hook; do
        sudo test -f "/etc/pacman.d/hooks/$h" && sudo rm -f "/etc/pacman.d/hooks/$h" && nota "Hook viejo de branding retirado: $h"
    done
    sudo test -f /usr/local/bin/horus-branding && sudo rm -f /usr/local/bin/horus-branding

    # --- 6. Aplicar ahora sobre las entradas existentes ---
    if sudo /usr/local/bin/horus-title; then
        if [ "$_cambio" -eq 1 ]; then
            did "Branding Horus aplicado (systemd-boot: título + boot negro)."
            NEED_REBOOT=1; REBOOT_RAZONES+=("branding de arranque")
        else
            skip "Branding Horus ya estaba aplicado."
        fi
    else
        fallo "horus-title falló; revisa /boot/loader/entries a mano."
    fi
fi
}

# SECCIÓN «steam» — FIX PANTALLA NEGRA DEL CLIENTE (CEF/Chromium)
# Steam NO lo instala este script (va por el instalador de CachyOS); todo aquí
# se aplica SOLO si Steam ya está presente. Si lo instalas después, corre:
#   setup_master.sh --solo=steam
#
# El cliente Steam moderno es 100% CEF (Chromium): el proceso 'steamwebhelper'
# dibuja TODA la ventana. En la iGPU Intel (Iris Xe / Tiger Lake) el proceso GPU
# de Chromium se cae y la ventana queda EN NEGRO. El flag -cef-disable-gpu lo
# evita, pero Steam es de INSTANCIA ÚNICA: el flag solo cuenta en el proceso que
# arranca PRIMERO. Las llamadas posteriores ('steam steam://rungameid/...', que
# es lo que lanzan los .desktop de los juegos) se reenvían por IPC a la instancia
# viva y SUS flags se ignoran. Por eso, si arrancas un JUEGO en frío sin abrir
# antes el cliente, Steam levanta SIN el flag, el CEF se rompe, y al abrir luego
# el cliente sale negro.
#
# Fix de raíz: un wrapper en /usr/local/bin/steam (precede a /usr/bin en el PATH)
# que ANTEPONE -cef-disable-gpu a CUALQUIER invocación de 'steam'. Da igual qué
# .desktop arranque primero —cliente o juego—: el flag siempre está. Cubre además
# los .desktop que Steam REGENERA solo (por eso es mejor que editar cada acceso a
# mano), y pacman nunca toca /usr/local/bin, así que sobrevive a los updates del
# paquete steam.
sec_steam() {
if ! command -v steam &>/dev/null && ! pacman -Qq steam &>/dev/null; then
    skip "Steam no instalado; sección steam omitida (instálalo y corre: setup_master.sh --solo=steam)."
else
    # --- 1. Wrapper de sistema: -cef-disable-gpu en TODA invocación de steam ---
    # Apunta SIEMPRE al binario real por ruta absoluta (/usr/bin/steam): si usara
    # 'command -v steam' se hallaría a sí mismo y entraría en bucle infinito.
    _wrap_tmp=$(mktemp)
    cat > "$_wrap_tmp" <<'STEAMWRAP_EOF'
#!/usr/bin/env bash
# Wrapper de Steam para Horus — antepone -cef-disable-gpu a toda invocación de
# 'steam' para evitar el crash del proceso GPU de Chromium (CEF) en la iGPU Intel,
# que deja el cliente EN NEGRO al arrancar en frío desde el .desktop de un juego.
# Steam es de instancia única: basta con garantizar que SIEMPRE arranque con el
# flag. Idempotente: si la llamada ya lo trae, no lo duplica.
REAL=/usr/bin/steam
for a in "$@"; do
    [ "$a" = "-cef-disable-gpu" ] && exec "$REAL" "$@"
done
exec "$REAL" -cef-disable-gpu "$@"
STEAMWRAP_EOF
    if [ ! -f /usr/local/bin/steam ] || ! cmp -s "$_wrap_tmp" /usr/local/bin/steam; then
        [ -f /usr/local/bin/steam ] && sudo cp -a /usr/local/bin/steam "/usr/local/bin/steam.bak-$(date +%Y%m%d-%H%M%S)"
        sudo install -m755 "$_wrap_tmp" /usr/local/bin/steam
        hash -r 2>/dev/null || true
        did "Wrapper /usr/local/bin/steam instalado (cliente arranca con CEF-GPU off)."
    else
        skip "Wrapper /usr/local/bin/steam ya estaba al día."
    fi
    rm -f "$_wrap_tmp"

    # --- 2. PATH: el wrapper solo gana si /usr/local/bin precede a /usr/bin ---
    # En CachyOS es el default (/etc/profile); se avisa si no se cumple en la
    # sesión que corre el setup.
    if ! printf '%s\n' "$PATH" | tr ':' '\n' | grep -qxF /usr/local/bin; then
        nota "PATH no incluye /usr/local/bin: el wrapper no se usará hasta corregirlo."
    elif [ "$(command -v steam)" != "/usr/local/bin/steam" ]; then
        nota "/usr/bin/steam tiene prioridad sobre el wrapper en este PATH; revisa el orden en /etc/profile."
    fi

    # --- 3. Override .desktop del CLIENTE (defensa redundante) ---
    # El wrapper ya cubre este caso; se mantiene por si una sesión rara no tuviera
    # /usr/local/bin delante. El flag explícito aquí lo absorbe el wrapper sin
    # duplicarlo. Solo toca $HOME (sin sudo).
    if write_if_changed "$HOME/.local/share/applications/steam.desktop" "Steam: override -cef-disable-gpu (cliente)" << 'STEAM_EOF'
[Desktop Entry]
Name=Steam
Comment=Steam (CEF GPU off - fix ventana negra en Wayland)
Exec=steam -cef-disable-gpu %U
Icon=steam
Terminal=false
Type=Application
Categories=Network;FileTransfer;Game;
MimeType=x-scheme-handler/steam;x-scheme-handler/steamlink;
StartupWMClass=Steam
Keywords=Valve;
STEAM_EOF
    then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
fi
}

# SECCIÓN «teclado» — RGB DEL TECLADO (regla udev ITE5570)
# El control RGB (horus-kbd-color) escribe al teclado por /dev/hidrawN. Sin permisos
# solo root puede hacerlo. Esta regla da acceso vía el grupo 'input' + el tag
# uaccess. DOS lecciones aprendidas a fuego, codificadas aquí:
#   • La regla DEBE numerarse <73 (es 60-...) para que el tag uaccess lo procese
#     73-seat-late.rules; con un número mayor, uaccess no surte efecto.
#   • El teclado interno es i2c-HID: la regla NUEVA solo toma efecto tras REINICIAR
#     ('udevadm trigger' no re-enumera el dispositivo interno). Por eso, si se
#     instala/cambia la regla, se marca NEED_REBOOT.
# El grupo 'input' + MODE=0660 es el respaldo por si uaccess fallara.
sec_teclado() {
    # Color del tema en el teclado ANTES del login (servicio de sistema).
    # @HOME@ se resuelve al usuario que instala; ver nota multiusuario en el wrapper.
    sed "s|@HOME@|$HOME|" "$SCRIPT_DIR/system/horus-kbd-boot.service" | sudo tee /etc/systemd/system/horus-kbd-boot.service >/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable horus-kbd-boot.service
    did "horus-kbd-boot.service instalado (teclado con tema en el login)."
    local src="$SCRIPT_DIR/udev/60-horus-kbd.rules"
    local dst="/etc/udev/rules.d/60-horus-kbd.rules"

    if [ ! -f "$src" ]; then
        nota "udev/60-horus-kbd.rules no está en el repo; RGB del teclado sin regla."
    elif sudo cmp -s "$src" "$dst" 2>/dev/null; then
        skip "Regla udev del teclado ya instalada y al día."
    else
        if sudo install -Dm 0644 "$src" "$dst"; then
            did "Regla udev del teclado -> $dst"
            sudo udevadm control --reload-rules 2>/dev/null
            sudo udevadm trigger --subsystem-match=hidraw 2>/dev/null || true
            # El teclado i2c interno no re-enumera en caliente: hace falta reiniciar.
            NEED_REBOOT=1; REBOOT_RAZONES+=("regla udev del teclado (re-enumerar i2c)")
            nota "El RGB del teclado tomará permisos tras REINICIAR."
        else
            fallo "No se pudo instalar la regla udev del teclado."
        fi
    fi

    # Respaldo de permisos: el usuario en el grupo 'input' (por si uaccess no aplica).
    if id -nG "$USER" | grep -qw input; then
        skip "Usuario ya en el grupo 'input'."
    elif sudo usermod -aG input "$USER"; then
        did "Usuario '$USER' agregado al grupo 'input'."
        NEED_REBOOT=1; REBOOT_RAZONES+=("alta en grupo input")
    else
        nota "No se pudo agregar al grupo 'input' (uaccess debería bastar igual)."
    fi
}

# SECCIÓN «recursos» — RECURSOS + BATERÍA
sec_recursos() {

# PFP y wallpapers: viven en el propio repo ($SCRIPT_DIR/PFP y $SCRIPT_DIR/
# Wallpapers) y el settings.json de Noctalia ya apunta ahí. Por eso NO se copian
# a ningún lado (antes se duplicaban a ~/Imágenes, fuera del repo). Solo se
# verifica que estén; si faltan, el wallpaper o el avatar no cargarían.
for d in PFP Wallpapers; do
    if [ -d "$SCRIPT_DIR/$d" ] && [ -n "$(ls -A "$SCRIPT_DIR/$d" 2>/dev/null)" ]; then
        skip "Recursos $d presentes en $SCRIPT_DIR/$d (Noctalia los lee de ahí)."
    else
        nota "Carpeta $d vacía o ausente en $SCRIPT_DIR; el wallpaper/avatar podría no cargar."
    fi
done

# Límite de carga de batería: asusd es dueño del umbral y lo reaplica en cada
# arranque y evento de AC, así que basta fijarlo una vez (sin servicio propio).
if [ "$DO_BATERIA" -eq 1 ]; then
    if ls /sys/class/power_supply/BAT*/charge_control_end_threshold &>/dev/null; then
        # Migración: retirar servicios propios (asusd los vuelve redundantes).
        for old in horus-bat-limit battery-charge-limit kyu-bat-limit; do
            if [ -f "/etc/systemd/system/$old.service" ]; then
                sudo systemctl disable --now "$old.service" &>/dev/null || true
                sudo rm -f "/etc/systemd/system/$old.service"
                did "Servicio de batería viejo retirado: $old.service."
            fi
        done
        sudo rm -f /usr/local/bin/horus-bat-limit
        _lim="$BAT_LIMIT"; if [ "$_lim" = "0" ]; then _lim=100; fi   # 0 = sin tope -> 100%
        if command -v asusctl &>/dev/null; then
            if asusctl battery limit "$_lim" &>/dev/null; then
                did "Límite de batería fijado en ${_lim}% (asusd)."
            else
                fallo "asusctl battery limit ${_lim} falló."
            fi
        else
            fallo "Falta asusctl para el límite de batería; instálalo (asusctl)."
        fi
    else
        nota "Este equipo no expone umbral de carga; límite de batería omitido."
    fi
else
    nota "Límite de batería omitido (--no-bateria)."
fi
}

# SECCIÓN «proyeccion» — UTILIDAD DE PROYECCIÓN (monitor externo / presentaciones)
sec_proyeccion() {
# Niri NO clona salidas de forma nativa: cada monitor es independiente. Lo
# robusto para presentar es EXTENDER y poner las slides en pantalla completa en
# el proyector (tú te quedas con tus notas en la laptop). El espejo real depende
# de wl-mirror y es frágil. Se deja un control único en ~/.local/bin/proyectar
# que maneja el externo en caliente vía IPC de Niri (no toca el config.kdl).
write_if_changed "$HOME/.local/bin/proyectar" "Utilidad de proyección ~/.local/bin/proyectar" << 'PROY_EOF'
#!/usr/bin/env python3
# Control de proyeccion / monitor externo en Niri
#
# Niri NO tiene espejo (mirror) nativo: cada salida es independiente y las
# ventanas no se clonan entre monitores. Lo robusto para presentar es EXTENDER
# y poner las slides en pantalla completa en el proyector; tu sigues con tus
# notas en la laptop. El "espejo real" depende de wl-mirror y es fragil (su
# ventana deja de refrescarse si pierde el foco). Por eso 'extender' es el modo
# por defecto y 'espejo' viene con advertencia.
#
# Uso:
#   proyectar              muestra el estado de las salidas (default)
#   proyectar extender     externo a la derecha del interno, escritorios separados
#   proyectar duplicar     clona la laptop en el proyector via wl-mirror (fragil)
#   proyectar externo      deja SOLO el proyector (apaga la pantalla interna)
#   proyectar interno      vuelve a SOLO la laptop (apaga externos)
#   proyectar toggle       alterna DUPLICAR <-> EXTENDIDO (keybind Mod+P)

import json
import os
import shutil
import subprocess
import sys


def niri_outputs():
    """Devuelve el dict de salidas que reporta niri por IPC (JSON)."""
    try:
        raw = subprocess.check_output(
            ["niri", "msg", "--json", "outputs"],
            text=True, stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        sys.exit("error: no encuentro 'niri'. ¿Estas dentro de una sesion Niri?")
    except subprocess.CalledProcessError:
        sys.exit("error: niri no respondio. ¿Estas dentro de una sesion Niri?")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        sys.exit("error: no pude leer la salida de 'niri msg --json outputs'.")


def is_internal(name):
    """La pantalla integrada de un laptop suele ser eDP-*, LVDS-* o DSI-*."""
    return name.upper().startswith(("EDP", "LVDS", "DSI"))


def split_outputs(outs):
    internal = [n for n in outs if is_internal(n)]
    external = [n for n in outs if not is_internal(n)]
    return internal, external


def msg_output(name, *args):
    subprocess.run(
        ["niri", "msg", "output", name, *args],
        check=False, stderr=subprocess.DEVNULL,
    )


def logical_width(out):
    """Ancho LOGICO (escalado) de una salida. Si esta apagada, estima desde su
    modo actual/preferido para poder posicionar la siguiente a su derecha."""
    lo = out.get("logical")
    if lo:
        return lo.get("width", 0)
    modes = out.get("modes", [])
    idx = out.get("current_mode")
    if idx is not None and 0 <= idx < len(modes):
        return modes[idx].get("width", 0)
    for m in modes:
        if m.get("is_preferred"):
            return m.get("width", 0)
    return modes[0].get("width", 0) if modes else 0


def modo_actual(out):
    modes = out.get("modes", [])
    idx = out.get("current_mode")
    if idx is None or not (0 <= idx < len(modes)):
        return "—"
    m = modes[idx]
    return "{}x{}@{:.0f}".format(m["width"], m["height"], m["refresh_rate"] / 1000)


def etiqueta(name, out):
    make = (out.get("make") or "").strip()
    model = (out.get("model") or "").strip()
    txt = (make + " " + model).strip()
    return txt or name


def notificar(titulo, cuerpo=""):
    """Notificacion de escritorio (Noctalia la captura via D-Bus freedesktop).
    Silenciosa si no esta libnotify: el toggle no debe tronar por eso."""
    if shutil.which("notify-send"):
        subprocess.run(
            ["notify-send", "-a", "Proyección", titulo, cuerpo],
            check=False, stderr=subprocess.DEVNULL,
        )


def _wlmirror_corriendo():
    """True si hay un wl-mirror vivo (es decir, estamos en modo DUPLICAR)."""
    return subprocess.run(
        ["pgrep", "-x", "wl-mirror"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode == 0


def _matar_wlmirror():
    """Corta cualquier espejo activo. Idempotente: si no hay, no pasa nada."""
    subprocess.run(
        ["pkill", "-x", "wl-mirror"], check=False,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def cmd_estado(outs):
    internal, external = split_outputs(outs)
    print("Salidas que ve Niri:\n")
    for name, out in outs.items():
        tipo = "interna" if is_internal(name) else "externa"
        on = out.get("logical") is not None
        estado = "ON " if on else "off"
        modo = modo_actual(out) if on else "—"
        print("  [{}] {:<12} ({:<7}) {:<14} {}".format(
            estado, name, tipo, modo, etiqueta(name, out)))
    if not external:
        print("\nSin monitor externo conectado. Enchufa el HDMI/DP y reintenta.")
    else:
        print("\n  proyectar duplicar   -> mismo contenido en el proyector (fragil)")
        print("  proyectar extender   -> escritorios separados")
        print("  proyectar externo    -> solo proyector")
        print("  proyectar interno    -> solo laptop")


def cmd_extender(outs):
    internal, external = split_outputs(outs)
    _matar_wlmirror()  # si venimos de duplicar, salimos de ahi
    if not external:
        sys.exit("Sin externo conectado. Enchufa el cable primero.")
    intern_name = internal[0] if internal else None
    if intern_name:
        msg_output(intern_name, "on")
        msg_output(intern_name, "position", "set", "0", "0")
        x = logical_width(outs[intern_name])
    else:
        x = 0
    for ext in external:
        msg_output(ext, "on")
        msg_output(ext, "position", "set", str(x), "0")
        x += logical_width(outs[ext])
    destino = ", ".join(external)
    print("Listo: pantalla extendida. {} a la derecha de {}.".format(
        destino, intern_name or "x=0"))
    print("Para presentar: abre/mueve las slides al proyector y ponlas en")
    print("pantalla completa. Tu te quedas con tus notas en la laptop.")


def cmd_externo(outs):
    internal, external = split_outputs(outs)
    _matar_wlmirror()  # si venimos de duplicar, salimos de ahi
    if not external:
        sys.exit("Sin externo conectado.")
    for ext in external:
        msg_output(ext, "on")
        msg_output(ext, "position", "set", "0", "0")
    for intern_name in internal:
        msg_output(intern_name, "off")
    print("Solo proyector: la pantalla de la laptop quedo apagada.")
    print("Para volver:  proyectar interno")


def cmd_interno(outs):
    internal, external = split_outputs(outs)
    _matar_wlmirror()  # si venimos de duplicar, salimos de ahi
    for ext in external:
        msg_output(ext, "off")
    for intern_name in internal:
        msg_output(intern_name, "on")
        msg_output(intern_name, "position", "set", "0", "0")
    print("De vuelta a solo la pantalla interna.")


def cmd_duplicar(outs):
    """Espejo: el proyector muestra lo MISMO que la laptop, vía wl-mirror en
    pantalla completa sobre el externo. Se lanza en SEGUNDO PLANO para que el
    keybind no se quede colgado. OJO: en Niri el espejo se congela si su ventana
    pierde el foco (peor con NVIDIA); para slides 'extender' es mas fiable.
    Cualquier otro modo (extender/interno/externo) o el toggle lo corta solo."""
    internal, external = split_outputs(outs)
    if not external:
        sys.exit("Sin externo conectado. Enchufa el cable primero.")
    if not internal:
        sys.exit("No detecte pantalla interna que clonar.")
    if not shutil.which("wl-mirror"):
        sys.exit("Falta wl-mirror. Instalalo:  paru -S wl-mirror")
    src, dst = internal[0], external[0]
    _matar_wlmirror()  # evita apilar dos espejos
    msg_output(src, "on")
    msg_output(dst, "on")
    # -b screencopy: Niri NO implementa export-dmabuf de wlroots; sin forzarlo,
    # wl-mirror tarda en hacer fallback. --fullscreen-output lo deja a pantalla
    # completa en el proyector. start_new_session lo desliga del proceso del
    # keybind para que siga vivo tras devolver el control.
    subprocess.Popen(
        ["wl-mirror", "-b", "screencopy", "--fullscreen-output", dst, src],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    print("Duplicando la laptop en {}.".format(dst))


def _proyeccion_activa(outs):
    """¿Hay proyección encendida? True si wl-mirror vive (duplicado) o si algún
    externo está encendido (extendido / solo-externo)."""
    if _wlmirror_corriendo():
        return True
    _, external = split_outputs(outs)
    return any(outs[e].get("logical") is not None for e in external)


def cmd_toggle(outs):
    """Mod+P: enciende/apaga la proyección. Funciona HAYA O NO proyector. Si no hay
    externo —o si ya había proyección— cae a SOLO INTERNO (siempre posible, nunca
    exige el cable). Si hay externo y no había proyección, empieza a DUPLICAR.
    Siempre notifica. (Para extender en vez de duplicar: 'proyectar extender'.)"""
    internal, external = split_outputs(outs)
    try:
        if not external or _proyeccion_activa(outs):
            cmd_interno(outs)   # solo laptop: corre aunque no haya externo
            if not external:
                notificar("Proyección — solo laptop", "No hay proyector conectado.")
            else:
                notificar("Proyección — solo laptop", "Proyección apagada.")
        else:
            cmd_duplicar(outs)
            notificar("Proyección — duplicado",
                      "Mismo contenido en {}. Se congela si tocas la laptop.".format(
                          ", ".join(external)))
    except SystemExit as e:
        notificar("Proyección — no se pudo", str(e) or "Error al cambiar de modo.")
        raise


ACCIONES = {
    "": cmd_estado, "estado": cmd_estado, "status": cmd_estado,
    "extender": cmd_extender, "extend": cmd_extender,
    "externo": cmd_externo, "solo-externo": cmd_externo,
    "interno": cmd_interno, "reset": cmd_interno,
    "espejo": cmd_duplicar, "duplicar": cmd_duplicar, "mirror": cmd_duplicar,
    "toggle": cmd_toggle, "alternar": cmd_toggle,
}


def main():
    arg = sys.argv[1].lower() if len(sys.argv) > 1 else "estado"
    fn = ACCIONES.get(arg)
    if fn is None:
        sys.exit("Comando desconocido: {}\n"
                 "Usa: proyectar [estado|extender|duplicar|externo|interno|toggle]".format(arg))
    fn(niri_outputs())


if __name__ == "__main__":
    main()
PROY_EOF
chmod +x "$HOME/.local/bin/proyectar" 2>/dev/null || true
}

# EJECUCIÓN DE LAS SECCIONES SELECCIONADAS

# SECCIÓN «flatpak» — utilidades Flatpak + remoto Flathub
sec_flatpak() {
    if command -v flatpak &>/dev/null || pacman -Qq flatpak &>/dev/null; then
        skip "Flatpak ya estaba instalado."
    else
        sudo pacman -S --needed --noconfirm flatpak && did "Flatpak instalado."
    fi
    if flatpak remotes 2>/dev/null | grep -q '^flathub'; then
        skip "Remoto Flathub ya configurado."
    else
        sudo flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo \
            && did "Remoto Flathub agregado."
    fi
}

# SECCIÓN «sistema» — servicios y reglas de system/ (antes huérfanos del setup)
sec_sistema() {
    local sysd="${HORUS_DIR:-$HOME/Horus-Project}/system"
    # 1) power-hook (root): dGPU y ventiladores atados al perfil de energía
    if [ -f "$sysd/horus-power-hook" ]; then
        sudo install -m755 "$sysd/horus-power-hook" /usr/local/bin/horus-power-hook
        sudo install -m644 "$sysd/horus-power-hook.service" /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable --now horus-power-hook.service &>/dev/null \
            && did "horus-power-hook desplegado y activo." || warn "horus-power-hook no arrancó."
    fi
    # 2) keyd: config del repo (fuente de verdad; horus-sync captura cambios en vivo)
    if [ -f "$sysd/keyd-default.conf" ]; then
        sudo pacman -S --needed --noconfirm keyd &>/dev/null
        sudo install -Dm644 "$sysd/keyd-default.conf" /etc/keyd/default.conf
        sudo systemctl enable --now keyd &>/dev/null; sudo keyd reload &>/dev/null
        did "keyd con config del repo."
    fi
    # 3) gpu-watch (usuario): dGPU de sesión en rendimiento+AC (el script lo pone configs/)
    if [ -f "$sysd/horus-gpu-watch.service" ]; then
        install -Dm644 "$sysd/horus-gpu-watch.service" "$HOME/.config/systemd/user/horus-gpu-watch.service"
        systemctl --user daemon-reload
        systemctl --user enable --now horus-gpu-watch &>/dev/null && did "horus-gpu-watch activo."
    fi
    # 4) Sober: override del .desktop exportado (fix launcher + URIs roblox://)
    #    Clave: conservar %u (sin él los links roblox:// abren Sober sin destino)
    local sober="$HOME/.local/share/flatpak/exports/share/applications/org.vinegarhq.Sober.desktop"
    if [ -f "$sober" ]; then
        local dst="$HOME/.local/share/applications/org.vinegarhq.Sober.desktop"
        mkdir -p "$HOME/.local/share/applications"
        sed 's| --file-forwarding | |; s|@@u %u @@|%u|' "$sober" > "$dst"
        grep -q 'x-scheme-handler/roblox' "$dst" || echo 'MimeType=x-scheme-handler/roblox;' >> "$dst"
        xdg-mime default org.vinegarhq.Sober.desktop x-scheme-handler/roblox
        update-desktop-database "$HOME/.local/share/applications" &>/dev/null
        did "Sober: .desktop con %u + handler roblox:// registrado."
    fi
    # 5) Noctalia en español: los toasts de perfil de energía tienen los nombres
    #    hardcodeados en inglés en el QML (no pasan por Assets/Translations).
    #    Parche de 3 cadenas + hook que lo reaplica tras cada update del paquete
    #    (mismo patrón que el branding de systemd-boot). Idempotente: aplicado,
    #    los patrones ingleses ya no matchean.
    sudo tee /usr/local/bin/horus-noctalia-es >/dev/null <<'NOCTAEOF'
#!/usr/bin/env bash
# horus-noctalia-es — ajusta los toasts de perfil de energía de Noctalia segun
# el idioma persistido en ~/.config/horus/lang. Lo reaplica el hook tras updates.
#   es -> nombres en español · en -> nombres en inglés (upstream).
#   El fix del ICONO se aplica SIEMPRE (es independiente del idioma).
set -u
F=/etc/xdg/quickshell/noctalia-shell/Services/Power/PowerProfileService.qml
[ -f "$F" ] || exit 0
# Idioma: el hook corre como root; el archivo vive en el HOME del usuario real.
_home=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
LANG_H=$(cat "${_home:-$HOME}/.config/horus/lang" 2>/dev/null || echo es)   # fallback: es
# Fix del ICONO del toast (valido en cualquier idioma): upstream deriva la clave
# del icono del NOMBRE del perfil; con nombres traducidos la clave no existe y
# cae a la calavera. getIcon() ya devuelve la clave correcta siempre.
sed -i 's|profileName.toLowerCase().replace(" ", "")|root.getIcon()|' "$F"
# Nombres: solo en español. En 'en' se dejan los del upstream (no se tocan).
if [ "$LANG_H" = "es" ]; then
    sed -i 's|return "Performance";|return "Rendimiento";|; s|return "Balanced";|return "Equilibrado";|; s|return "Power saver";|return "Ahorro de energía";|' "$F"
fi
NOCTAEOF
    sudo chmod +x /usr/local/bin/horus-noctalia-es
    sudo mkdir -p /etc/pacman.d/hooks
    sudo tee /etc/pacman.d/hooks/zzz-horus-noctalia-es.hook >/dev/null <<'NOCTAEOF'
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = noctalia-shell

[Action]
Description = Reaplicando traduccion de toasts de Noctalia (Horus)
When = PostTransaction
Exec = /usr/local/bin/horus-noctalia-es
NOCTAEOF
    sudo /usr/local/bin/horus-noctalia-es && did "Toasts de Noctalia en español (parche + hook de pacman)."
}

# SECCIÓN «zen» — tema Horus para Zen (chrome, prefs, extensiones)
#   policies.json -> /opt/zen-browser-bin/distribution (sudo)
#   user.js + CSS -> todos los perfiles de ~/.zen (nombres con espacios)
#   Dark Reader (config/zen/darkreader-horus.json) se IMPORTA a mano.
sec_zen() {
    local src="${HORUS_DIR:-$HOME/Horus-Project}/config/zen"
    local zen_dir="$HOME/.zen" ini="$HOME/.zen/profiles.ini"
    local zen_install="" c
    for c in /opt/zen-browser-bin "$HOME/.tarball-installations/zen" /opt/zen "$HOME/.zen-browser"; do
        [ -d "$c" ] && zen_install="$c" && break
    done
    if [ -z "$zen_install" ]; then
        skip "Zen no instalado; sección zen omitida (instala zen-browser-bin y corre --solo=zen)."
        return 0
    fi
    local dest="$zen_install/distribution"
    if [ -f "$dest/policies.json" ] && cmp -s "$src/policies.json" "$dest/policies.json"; then
        skip "policies.json de Zen ya estaba al día."
    else
        sudo mkdir -p "$dest" && sudo cp -f "$src/policies.json" "$dest/policies.json" \
            && did "policies.json de Zen desplegado (extensiones + telemetría)."
    fi
    if [ ! -f "$ini" ]; then
        nota "Zen sin perfil aún. Abre Zen una vez y corre: horus-solo zen."
        return 0
    fi
    local perfiles=() rel dir count=0
    mapfile -t perfiles < <(awk '/^\[Profile/{i=1;next}/^\[/{i=0} i&&/^Path=/{sub(/^Path=/,"");sub(/\r$/,"");print}' "$ini")
    for rel in "${perfiles[@]}"; do
        case "$rel" in /*) dir="$rel";; *) dir="$zen_dir/$rel";; esac
        [ -d "$dir" ] || continue
        mkdir -p "$dir/chrome"
        cp -f "$src/userChrome.css"  "$dir/chrome/userChrome.css"
        cp -f "$src/userContent.css" "$dir/chrome/userContent.css"
        cp -f "$src/user.js"         "$dir/user.js"
        count=$((count+1))
    done
    if [ "$count" -gt 0 ]; then
        did "Tema Horus desplegado en $count perfil(es) de Zen."
        nota "Dark Reader: importa config/zen/darkreader-horus.json (Manage settings → Import)."
    else
        nota "Ningún perfil de Zen en disco; abre Zen y reintenta."
    fi
}

# SECCIÓN «sesion» — TECLA POWER → BLOQUEO / TAPA → IGNORAR
# Drop-in de logind: la tecla power BLOQUEA (en vez de apagar) y el cierre de
# tapa se IGNORA (nada se suspende; lo que corra sigue corriendo). Niri cede la
# tecla power con 'disable-power-key-handling' (input.kdl); logind emite la señal
# Lock y horus-lock-listener (autostart) muestra el lockscreen de Noctalia. Aplica
# al reiniciar (logind lee el drop-in al boot).
sec_sesion() {
    sudo install -Dm644 /dev/stdin /etc/systemd/logind.conf.d/10-horus-lock.conf <<'HORUSEOF'
# Horus — la tecla power BLOQUEA; el cierre de tapa se IGNORA (nada se suspende).
[Login]
HandlePowerKey=lock
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HORUSEOF
    did "logind: tecla power → bloqueo, cierre de tapa ignorado (aplica al reiniciar)."
    nota "Tapa cerrada + rendimiento + dGPU activa = menos disipación (el A16 ventila por teclado/trasera). Vigila temperaturas si dejas carga de GPU con la tapa cerrada."
}

# SECCIÓN «rendimiento» — RENDIMIENTO GRÁFICO (GPU híbrida)
# Solo aplica si hay GPU dedicada. Instala herramientas de cambio/monitoreo
# (supergfxctl, nvtop) y deja que horus-power arme las curvas de ventilador + el
# hook de energía. Todo va con guardas: si algo falta, avisa y sigue.
sec_rendimiento() {
    if ! lspci 2>/dev/null | grep -qi nvidia; then
        skip "Sin GPU dedicada; rendimiento gráfico omitido."
        return 0
    fi
    instala_repo nvtop
    instala_aur supergfxctl
    local KP=""
    command -v horus-power &>/dev/null && KP="horus-power"
    [ -z "$KP" ] && [ -x "$HOME/.local/bin/horus-power" ] && KP="$HOME/.local/bin/horus-power"
    if [ -n "$KP" ]; then
        if "$KP" setup; then
            did "horus-power setup aplicado (curvas de ventilador + hook de energía)."
        else
            nota "horus-power setup no completó; revísalo a mano con: horus-power setup"
        fi
    else
        nota "horus-power aún no está en PATH; corre 'horus-solo configs' y reintenta esta sección."
    fi
}

# SECCIÓN «gaming» — MINECRAFT BEDROCK (mcpelauncher) + shader Newb opcional
sec_gaming() {
    local MCPE="io.mrarm.mcpelauncher"

    # 1) mcpelauncher por flathub (user) — mismo idiom que el resto de flatpaks
    if flatpak info --user "$MCPE" &>/dev/null; then
        skip "mcpelauncher ya instalado ($MCPE)."
    else
        flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null
        if flatpak install --user --noninteractive flathub "$MCPE"; then
            did "mcpelauncher instalado ($MCPE)."
        else
            fallo "No se pudo instalar mcpelauncher ($MCPE)."
            return
        fi
    fi

    # 2) Shader Newb (OPCIONAL, por detección). Necesita: (a) mcpelauncher abierto
    #    una vez (crea su data dir) y (b) un newb-classic*.mcpack en ~/Descargas o
    #    ~/Documentos (NO va al repo: licencia). Sin (a) o (b): launcher pelón + nota.
    local mcpe_data="$HOME/.var/app/$MCPE/data/mcpelauncher"
    local mcpack; mcpack=$(ls -1t "$HOME/Descargas"/newb-classic*.mcpack "$HOME/Documentos"/newb-classic*.mcpack 2>/dev/null | head -1)
    if [ ! -d "$mcpe_data" ]; then
        nota "Shader Newb pendiente: abre mcpelauncher una vez, luego corre  horus-mc-shaders"
    elif [ -z "$mcpack" ]; then
        nota "Shader Newb pendiente: deja un newb-classic*.mcpack en ~/Descargas y corre  horus-mc-shaders"
    elif [ -x "$HOME/.local/bin/horus-mc-shaders" ] && "$HOME/.local/bin/horus-mc-shaders" "$mcpack"; then
        did "Shader Newb aplicado en mcpelauncher (pack: $(basename "$mcpack"))."
    else
        nota "Shader Newb no aplicado; corre manualmente:  horus-mc-shaders"
    fi
}

_idx=1
for _t in "${SELECCION[@]}"; do
    section "[$_idx/${#SELECCION[@]}] ${SEC_DESC[$_t]}"
    "sec_$_t"
    _idx=$((_idx+1))
done

# ── Aplicar el tema elegido en el asistente (si hubo y no es preview) ──
# horus-theme ya quedó desplegado por la sección configs; aplica niri/teclado
# (y foot/colorscheme cuando esa pieza esté activa). Si el hot-reload no corre
# (p.ej. fuera de Niri), igual deja la config escrita para el próximo login.
if [ "${HORUS_PREVIEW:-0}" -eq 0 ] && [ -n "${HORUS_THEME:-}" ] && [ "${HORUS_THEME}" != "__custom__" ]; then
    if [ -x "$HOME/.local/bin/horus-theme" ]; then
        section "Tema: $HORUS_THEME"
        if HORUS_FIRST=1 "$HOME/.local/bin/horus-theme" "$HORUS_THEME"; then
            did "Tema '$HORUS_THEME' aplicado."
        else
            nota "No se pudo aplicar el tema automáticamente; corre: horus-theme \"$HORUS_THEME\""
        fi
    fi
fi

# RESUMEN (construido desde lo que DE VERDAD pasó, no texto fijo)
section "Resumen de esta corrida"
echo ""

if [ "${#CAMBIOS[@]}" -gt 0 ]; then
    echo -e "  ${GREEN}━━ Se hizo (${#CAMBIOS[@]}) ━━${NC}"
    for c in "${CAMBIOS[@]}"; do echo -e "  ${GREEN}[+]${NC} $c"; done
    echo ""
fi
if [ "${#YA_OK[@]}" -gt 0 ]; then
    echo -e "  ${PURPLE}━━ Ya estaba (${#YA_OK[@]}) ━━${NC}"
    for c in "${YA_OK[@]}"; do echo -e "  ${PURPLE}[=]${NC} $c"; done
    echo ""
fi
# (El recap de «Avisos» se quitó a pedido; los [i] informativos siguen saliendo
#  en vivo durante la corrida, solo ya no se reagrupan aquí.)
if [ "${#FALLOS[@]}" -gt 0 ]; then
    echo -e "  ${RED}━━ Fallos (${#FALLOS[@]}) ━━${NC}"
    for f in "${FALLOS[@]}"; do echo -e "  ${RED}[x]${NC} $f"; done
    echo ""
fi
[ "$_backup_hecho" -eq 1 ] && echo -e "  ${YELLOW}⤿ Backup de configs previas:${NC} $BACKUP_DIR\n"

# ── Pasos siguientes: SOLO si hace falta una acción MANUAL aparte del reinicio.
# Un reinicio ya aplica todo (incluido el re-login), así que el caso "solo hace
# falta reiniciar" NO abre esta sección: se resuelve con la leyenda final de abajo.
# Por eso solo aparece cuando hay re-login pendiente y NO se va a reiniciar.
if [ "$NEED_REBOOT" -eq 0 ] && [ "$NEED_RELOGIN" -eq 1 ]; then
    _r=$(printf '%s\n' "${RELOGIN_RAZONES[@]}" | sort -u | paste -sd',' -); _r="${_r//,/, }"
    echo -e "  ${PURPLE}━━ Pasos siguientes ━━${NC}"
    echo -e "  ${YELLOW}•${NC} Cierra sesión y entra de nuevo para aplicar: $_r"
    echo -e "      (en caliente: Niri relee su config solo; reinicia Noctalia con  ${PURPLE}qs -c noctalia-shell${NC})"
    echo ""
fi

# ── Logs: justo antes de la leyenda de reinicio; si no hay reinicio, quedan casi
#    al final (el veredicto es siempre la última línea).
echo -e "  ${PURPLE}•${NC} Log de esta corrida: $LOG_FILE"
echo -e "  ${PURPLE}•${NC} Atajo al último:     $LOG_DIR/setup-latest.log"

# ── ¿Primera corrida COMPLETA? Se decide por HORUS_SETUP_PREVIO (capturado al inicio):
#    si horus-start NO existía, el setup nunca había corrido aquí. En --solo no aplica.
_primera=0
[ -z "$SOLO_RAW" ] && [ "$HORUS_SETUP_PREVIO" -eq 0 ] && _primera=1

# ── Leyenda de reinicio: solo si hace falta Y no vamos a reiniciar solos abajo.
[ "$NEED_REBOOT" -eq 1 ] && [ "$_primera" -eq 0 ] && \
    echo -e "  ${YELLOW}Hace falta reiniciar para que se apliquen los cambios.${NC}  →  ${PURPLE}sudo reboot${NC}"

# ── Veredicto final: todo bien, o qué faltó.
echo ""
if [ "${#FALLOS[@]}" -eq 0 ]; then
    echo -e "  ${GREEN}✓ Todo se instaló correctamente, sin fallos.${NC}"
else
    echo -e "  ${RED}✗ Terminó con ${#FALLOS[@]} fallo(s); revisa la sección «Fallos» de arriba.${NC}"
fi
echo ""

# ── Solo en la PRIMERA corrida (horus-start no existía): reinicio inmediato, con 10 s
#    para cancelar. Como horus-start ya quedó desplegado, las próximas no reinician.
if [ "$_primera" -eq 1 ]; then
    echo -e "  ${YELLOW}Primera instalación: reinicio automático en 10 s para aplicar todo.${NC}"
    echo -e "  ${PURPLE}(Ctrl+C para cancelar.)${NC}"
    for i in $(seq 10 -1 1); do printf '\r  Reiniciando en %2d s...  ' "$i"; sleep 1; done
    printf '\n'
    sudo reboot
fi

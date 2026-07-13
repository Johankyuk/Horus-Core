#!/usr/bin/env bash
# Capa de interfaz (gum) del instalador de Horus Project.
#   Se SOURCEA desde setup_master.sh y desde preview/ui-preview.sh,
#   para que ambos usen exactamente la misma UI.
#   Expone horus_wizard: idioma → modo → paquetes → tema → resumen → confirmar.
#   Setea variables globales (HORUS_LANG, HORUS_MODE, HORUS_PKGS, HORUS_THEME) y
#   devuelve 0 (confirmado) o 1 (cancelado).
#   Lee HORUS_SDBOOT (0 si NO hay systemd-boot) para avisar del branding.
#   Si HORUS_UI_PREVIEW=1: no instala gum solo, y el cierre dice "preview".

# ── Paleta Horus ─────────────────────────────────────────────
KUI_PRIM="#8b45f7"; KUI_DEEP="#6d11d0"; KUI_SEC="#c44fe6"
KUI_SUB="#a784dd";  KUI_DIM="#7d5fb0";  KUI_TXT="#e9ddff"

# ── Envoltorios de gum con el tema ──────────────────────────
_kui_choose()  { gum choose  --cursor.foreground "$KUI_PRIM" --header.foreground "$KUI_SUB" --selected.foreground "$KUI_SEC" "$@"; }
_kui_confirm() { gum confirm --selected.background "$KUI_PRIM" --selected.foreground "#ffffff" --prompt.foreground "$KUI_SUB" "$@"; }
_kui_title()   { gum style --border double --border-foreground "$KUI_DEEP" --foreground "$KUI_PRIM" --bold --padding "0 3" --margin "1 0" "$@"; }
_kui_step()    { gum style --foreground "$KUI_DEEP" --bold "  $1"; }
_kui_note()    { gum style --foreground "$KUI_DIM" "  $1"; }
_kui_hint()    { gum style --foreground "#f3ecff" --bold "  $1"; }   # pista legible (casi blanca)

# ── Textos (ES / EN) ─────────────────────────────────────────
declare -A KS
_kui_load_strings() {
  if [[ "$HORUS_LANG" == "es" ]]; then
    KS[header]="Horus Project · Instalador"
    KS[s1]="1 · Modo de instalación"; KS[modeq]="¿Cómo quieres instalar Horus Project?"
    KS[full]="Completa — todo el setup, sin preguntar"
    KS[custom]="Personalizada — eliges paquete por paquete (recomendada)"
    KS[min]="Mínima — solo el núcleo"
    KS[s2]="2 · Paquetes"
    KS[core]="El núcleo siempre se instala (Niri · Noctalia · foot · SDDM · configs · atajos)."
    KS[pick]="Marca con x · Enter para confirmar · Ctrl+A para todos."
    KS[pkgq]="Marca los extras:"
    KS[cos]="Cosméticos — color por tema (cursor · GTK · focus-ring)"
    KS[apps]="Apps — oficina · multimedia · navegador · Steam"
    KS[gaming]="Gaming — Minecraft Bedrock + shader Newb"
    KS[s3]="3 · Tema"
    KS[themen]="Recolorea Noctalia, foot, Niri, wallpaper, cursor y teclado."
    KS[themeq]="Elige un tema (o ninguno):"
    KS[town]="Tema propio (lo defines tú)"; KS[tnone]="Sin tema (morado base)"
    KS[rmode]="Modo:   "; KS[rlang]="Idioma: "; KS[rtheme]="Tema:   "; KS[rpkgs]="Extras: "
    KS[rcore]="solo núcleo"
    KS[cfq]="¿Aplicar esta instalación?"
    KS[cancel]="Cancelado. No se modificó nada."
    KS[sdbootw]="Este equipo no usa systemd-boot: la instalación completa omitirá el branding de arranque; el resto se instala igual."
    KS[prevend]="PREVIEW — no se instaló ni cambió nada."
  else
    KS[header]="Horus Project · Installer"
    KS[s1]="1 · Install mode"; KS[modeq]="How do you want to install Horus Project?"
    KS[full]="Full — the whole setup, no questions"
    KS[custom]="Custom — pick package by package (recommended)"
    KS[min]="Minimal — core only"
    KS[s2]="2 · Packages"
    KS[core]="The core is always installed (Niri · Noctalia · foot · SDDM · configs · shortcuts)."
    KS[pick]="Toggle with x · Enter to confirm · Ctrl+A for all."
    KS[pkgq]="Check the extras:"
    KS[cos]="Cosmetics — per-theme color (cursor · GTK · focus-ring)"
    KS[apps]="Apps — office · media · browser · Steam"
    KS[gaming]="Gaming — Minecraft Bedrock + Newb shader"
    KS[s3]="3 · Theme"
    KS[themen]="Recolors Noctalia, foot, Niri, wallpaper, cursor and keyboard."
    KS[themeq]="Pick a theme (or none):"
    KS[town]="Custom theme (you define it)"; KS[tnone]="No theme (base purple)"
    KS[rmode]="Mode:   "; KS[rlang]="Lang:   "; KS[rtheme]="Theme:  "; KS[rpkgs]="Extras: "
    KS[rcore]="core only"
    KS[cfq]="Apply this installation?"
    KS[cancel]="Cancelled. Nothing was changed."
    KS[sdbootw]="This machine doesn't use systemd-boot: the full install will skip boot branding; everything else installs the same."
    KS[prevend]="PREVIEW — nothing installed or changed."
  fi
}

# Opciones de tema (display por idioma) y su clave canónica para horus-theme
_kui_theme_options() {
  if [[ "$HORUS_LANG" == "es" ]]; then
    printf '%s\n' "Morado" "Azul eléctrico" "Azul rey" "Rosa brillante" "Rosa pálido" "Amarillo" "Naranja" "Rojo" "Gris" "${KS[tnone]}"
  else
    printf '%s\n' "Purple" "Electric blue" "Royal blue" "Bright pink" "Pale pink" "Yellow" "Orange" "Red" "Gray" "${KS[tnone]}"
  fi
}
_kui_theme_key() {  # display elegido → clave canónica (la que entiende horus-theme), "__custom__" o "" (sin tema)
  case "$1" in
    Morado|Purple)                    printf 'Morado' ;;
    "Azul eléctrico"|"Electric blue")  printf 'Azul eléctrico' ;;
    "Azul rey"|"Royal blue")          printf 'Azul rey' ;;
    "Rosa brillante"|"Bright pink")    printf 'Rosa brillante' ;;
    "Rosa pálido"|"Pale pink")        printf 'Rosa pálido' ;;
    Amarillo|Yellow)                  printf 'Amarillo' ;;
    Naranja|Orange)                   printf 'Naranja' ;;
    Rojo|Red)                         printf 'Rojo' ;;
    Gris|Gray)                        printf 'Gris' ;;
    "${KS[town]}")                    printf '__custom__' ;;
    *)                                 printf '' ;;
  esac
}

# Asegurar gum (en instalación real lo instala; en preview solo avisa)
_kui_ensure_gum() {
  command -v gum >/dev/null 2>&1 && return 0
  if [ "${HORUS_UI_PREVIEW:-0}" = "1" ]; then
    echo "Esta preview necesita 'gum':  sudo pacman -S gum"; return 1
  fi
  echo "Preparando el instalador (instalando 'gum')..."
  sudo pacman -S --needed --noconfirm gum >/dev/null 2>&1
  command -v gum >/dev/null 2>&1
}

# ── El asistente ─────────────────────────────────────────────
horus_wizard() {
  _kui_ensure_gum || { echo "No se pudo preparar gum; no se puede continuar con el asistente."; return 1; }

  # Estado (globales, sin 'local', para que setup_master las vea)
  HORUS_LANG=""; HORUS_LANG_NAME=""; HORUS_MODE=""; HORUS_THEME=""; HORUS_PKGS=()
  : "${HORUS_SDBOOT:=1}"

  # Paso 0 — idioma PRIMERO (pantalla neutra)
  clear
  _kui_title "Horus Project · Installer / Instalador"
  local _pick
  _pick=$(_kui_choose --header "Language / Idioma:" "English" "Español") || return 1
  if [[ "$_pick" == "Español" ]]; then HORUS_LANG="es"; HORUS_LANG_NAME="Español"; else HORUS_LANG="en"; HORUS_LANG_NAME="English"; fi
  _kui_load_strings

  # A partir de aquí todo en el idioma elegido
  clear
  _kui_title "${KS[header]}"
  [ "$HORUS_SDBOOT" = "0" ] && _kui_note "⚠ ${KS[sdbootw]}"
  echo

  # Paso 1 — modo
  _kui_step "${KS[s1]}"
  local _modo
  _modo=$(_kui_choose --header "${KS[modeq]}" "${KS[full]}" "${KS[custom]}" "${KS[min]}") || return 1
  case "$_modo" in
    "${KS[full]}")   HORUS_MODE="full"   ;;
    "${KS[custom]}") HORUS_MODE="custom" ;;
    "${KS[min]}")    HORUS_MODE="min"    ;;
  esac
  echo

  # Paso 2 — paquetes (solo personalizada)
  if [[ "$HORUS_MODE" == "custom" ]]; then
    _kui_step "${KS[s2]}"
    _kui_note "${KS[core]}"
    _kui_hint "${KS[pick]}"
    local _opc=("${KS[cos]}" "${KS[apps]}" "${KS[gaming]}")
    local _sel=(); mapfile -t _sel < <(_kui_choose --no-limit --header "${KS[pkgq]}" --selected "${KS[cos]}" "${_opc[@]}")
    local x
    for x in "${_sel[@]}"; do
      case "$x" in
        "${KS[cos]}")    HORUS_PKGS+=("cosmeticos") ;;
        "${KS[apps]}")   HORUS_PKGS+=("apps") ;;
        "${KS[gaming]}") HORUS_PKGS+=("gaming") ;;
      esac
    done
    echo
  fi

  # Paso 3 — tema
  _kui_step "${KS[s3]}"
  _kui_note "${KS[themen]}"
  local _topts=(); mapfile -t _topts < <(_kui_theme_options)
  local _tpick
  _tpick=$(_kui_choose --header "${KS[themeq]}" "${_topts[@]}") || return 1
  HORUS_THEME="$(_kui_theme_key "$_tpick")"
  echo

  # Resumen
  local _modname="$HORUS_MODE"; case "$HORUS_MODE" in
    full)   _modname="${KS[full]%% —*}"   ;;
    custom) _modname="${KS[custom]%% —*}" ;;
    min)    _modname="${KS[min]%% —*}"    ;;
  esac
  local RES="${KS[rmode]} ${_modname}
${KS[rlang]} ${HORUS_LANG_NAME}
${KS[rtheme]} ${_tpick}"
  if [[ "$HORUS_MODE" == "custom" ]]; then
    if [ ${#HORUS_PKGS[@]} -gt 0 ]; then
      RES+=$'\n'"${KS[rpkgs]} $(printf '%s, ' "${HORUS_PKGS[@]}" | sed 's/, $//')"
    else
      RES+=$'\n'"${KS[rpkgs]} ${KS[rcore]}"
    fi
  fi
  gum style --border rounded --border-foreground "$KUI_PRIM" --padding "1 2" --margin "1 0" --foreground "$KUI_TXT" "$RES"

  # Confirmar
  if [ "${HORUS_UI_PREVIEW:-0}" = "1" ]; then
    _kui_confirm "${KS[cfq]}" || true
    gum style --foreground "$KUI_DIM" --italic "  ${KS[prevend]}"
    return 0
  fi
  _kui_confirm "${KS[cfq]}" || { echo; gum style --foreground "$KUI_SUB" "  ${KS[cancel]}"; return 1; }
  # Persistir idioma elegido (fuente de verdad para horus-noctalia-es y su hook).
  mkdir -p "$HOME/.config/horus" && printf '%s\n' "$HORUS_LANG" > "$HOME/.config/horus/lang"
  return 0
}

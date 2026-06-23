# ============================================================================
#  SECCION: zen   (pegar dentro de setup_master.sh)
#  sudo=0  red=0
#
#  REGISTRO EN EL DISPATCHER — agrega 'zen' a los 4 arrays, MISMO indice:
#     SECCIONES+=("zen")
#     SEC_DESC+=("Navegador Zen: tema Horus, prefs y extensiones")
#     SEC_SUDO+=(0)
#     SEC_RED+=(0)
#
#  Si tu dispatcher invoca por otro patron (case, _$sec...), renombra la
#  funcion para que calce. Fuente: ${KYU_OS_DIR}/config/zen/
# ============================================================================

seccion_zen() {
    local dry="${DRY_RUN:-0}"
    local src="${KYU_OS_DIR}/config/zen"
    local zen_dir="$HOME/.zen"
    local ini="$zen_dir/profiles.ini"

    # --- policies.json a la instalacion (con sudo si es /opt) ---
    local zen_install="" c
    for c in "/opt/zen-browser-bin" "$HOME/.tarball-installations/zen" "/opt/zen" "$HOME/.zen-browser"; do
        [ -d "$c" ] && zen_install="$c" && break
    done
    if [ -z "$zen_install" ]; then
        echo "  [zen] sin instalacion de Zen; salto policies"
    else
        local dest="$zen_install/distribution"
        if [ "$dry" = "1" ]; then
            echo "  [zen][dry] policies.json -> $dest/"
        elif mkdir -p "$dest" 2>/dev/null && [ -w "$dest" ]; then
            cp -f "$src/policies.json" "$dest/policies.json"
            echo "  [zen] policies.json -> $dest/"
        else
            sudo mkdir -p "$dest"
            sudo cp -f "$src/policies.json" "$dest/policies.json"
            echo "  [zen] policies.json -> $dest/ (sudo)"
        fi
    fi

    # --- user.js + CSS a TODOS los perfiles (nombres con espacios incluidos) ---
    if [ ! -f "$ini" ]; then
        echo "  [zen] sin profiles.ini; abre Zen una vez y re-corre: kyu-solo zen"
        echo "✓ zen (parcial)"; return 0
    fi

    local perfiles=() rel dir count=0
    mapfile -t perfiles < <(awk '
        /^\[Profile/{inp=1; next}
        /^\[/{inp=0}
        inp && /^Path=/ { sub(/^Path=/,""); sub(/\r$/,""); print }
    ' "$ini")

    for rel in "${perfiles[@]}"; do
        case "$rel" in
            /*) dir="$rel" ;;
            *)  dir="$zen_dir/$rel" ;;
        esac
        [ -d "$dir" ] || continue
        if [ "$dry" = "1" ]; then
            echo "  [zen][dry] -> $dir"
        else
            mkdir -p "$dir/chrome"
            cp -f "$src/userChrome.css"  "$dir/chrome/userChrome.css"
            cp -f "$src/userContent.css" "$dir/chrome/userContent.css"
            cp -f "$src/user.js"         "$dir/user.js"
            echo "  [zen] -> $dir"
        fi
        count=$((count+1))
    done

    [ "$count" -eq 0 ] && { echo "  [zen] ningun perfil en disco"; echo "✓ zen (parcial)"; return 0; }
    echo "✓ zen ($count perfil/es)"
    # darkreader-horus.json se importa a mano en Dark Reader (no es desplegable por archivo)
}

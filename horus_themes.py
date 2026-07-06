#!/usr/bin/env python3
# horus_themes.py — Motor de temas de Horus  (v2)
#   Genera familias de tema rotando el TONO de la paleta base "Morada"
#   en espacio OKLCH (conserva luz y croma de cada color), con tres
#   correcciones de limpieza:
#     1) Compensacion de luz en la banda calida (amarillo/lima/naranja
#        necesitan mas luz que el morado para leerse bien).
#     2) Terminal ANSI anclado: los tonos semanticos (rojo/verde/azul...)
#        NO rotan, asi `ls`/git/errores siguen significando lo mismo.
#     3) Ajuste fino por tema (v2): cada tema puede pedir un delta de luz
#        global (gateado a L>0.35, para no lavar los fondos casi-negros)
#        y un factor de croma. Esto permite distinguir variantes del mismo
#        tono —p.ej. "Azul electrico" (claro+saturado) vs "Azul rey"
#        (profundo) o "Rosa brillante" vs "Rosa palido" (desaturado).
#   Fuente unica de color: de aqui salen los valores para Noctalia, foot,
#   Niri, SDDM, cursor, fastfetch y el wallpaper SVG. Sin dependencias.
import math, json

# ── OKLab / OKLCH (sin dependencias) ─────────────────────────
def _s2l(c): return c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4
def _l2s(c): return c*12.92 if c <= 0.0031308 else 1.055*(c**(1/2.4))-0.055
def _hx(h):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16)/255 for i in (0, 2, 4))
def _xh(r, g, b):
    f = lambda x: max(0, min(255, round(x*255))); return '#%02x%02x%02x' % (f(r), f(g), f(b))
def _rl(r, g, b):
    r, g, b = _s2l(r), _s2l(g), _s2l(b)
    l = (0.4122214708*r+0.5363325363*g+0.0514459929*b)**(1/3)
    m = (0.2119034982*r+0.6806995451*g+0.1073969566*b)**(1/3)
    s = (0.0883024619*r+0.2817188376*g+0.6299787005*b)**(1/3)
    return (0.2104542553*l+0.793617785*m-0.0040720468*s,
            1.9779984951*l-2.428592205*m+0.4505937099*s,
            0.0259040371*l+0.7827717662*m-0.808675766*s)
def _lr(L, a, b):
    l = (L+0.3963377774*a+0.2158037573*b)**3
    m = (L-0.1055613458*a-0.0638541728*b)**3
    s = (L-0.0894841775*a-1.291485548*b)**3
    return (_l2s(4.0767416621*l-3.3077115913*m+0.2309699292*s),
            _l2s(-1.2684380046*l+2.6097574011*m-0.3413193965*s),
            _l2s(-0.0041960863*l-0.7034186147*m+1.707614701*s))
def _lch(h):
    L, a, b = _rl(*_hx(h)); return (L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360)
def _hlc(L, C, H):
    a = C*math.cos(math.radians(H)); b = C*math.sin(math.radians(H)); return _xh(*_lr(L, a, b))

# ── Correccion 1: compensacion de luz en banda calida ────────
# Campana centrada en H≈100 (amarillo-lima), escalada por croma para
# que solo afecte acentos saturados, no las superficies casi-negras.
def _warm(L, C, H):
    if L < 0.35: return L          # surfaces/sombras casi-negras NO se tocan
    d = abs(((H-100+180) % 360)-180)
    bell = max(0.0, 1-(d/58.0)**2)
    return min(0.97, L + 0.20*bell*min(1.0, C/0.11))

# ── Correccion 3 (v2): delta de luz por tema, gateado igual que _warm ──
def _luz(L, dL):
    if dL == 0 or L < 0.35: return L   # no tocar fondos casi-negros
    return max(0.0, min(0.97, L + dL))

def _rot(hexc, dh, gray=False, dL=0.0, fC=1.0):
    L, C, H = _lch(hexc)
    if gray: return _hlc(_luz(L, dL), 0.0, 0)
    H2 = (H+dh) % 360
    L2 = _luz(_warm(L, C*fC, H2), dL)
    return _hlc(L2, C*fC, H2)

# ── Paleta base MORADA (lo que hoy vive en setup_master.sh) ───
MORADA = {
    "mPrimary": "#7a2be8", "mOnPrimary": "#140622",
    "mSecondary": "#b340e0", "mTertiary": "#df54a6", "mError": "#f5567a",
    "mSurface": "#140622", "mOnSurface": "#a872f2",
    "mSurfaceVariant": "#1e0c3a", "mOnSurfaceVariant": "#9568d8",
    "mOutline": "#482a92", "mShadow": "#070210", "mHover": "#2a1350",
    "termFg": "#e8dcff", "termBg": "#160a28",
    "termSelFg": "#a872f2", "termSelBg": "#482a92", "termCursor": "#7a2be8",
}
# Correccion 2: tonos ANSI semanticos anclados (NO rotan en ningun tema).
# Solo black/white (neutros) se tintan por tema.
ANSI_FIJOS = {
    "red": "#f5567a", "green": "#5ee6a0", "yellow": "#f5c453",
    "blue": "#7d6ff5", "magenta": "#b340e0", "cyan": "#5fd6e0",
    "redBright": "#ff7492", "greenBright": "#74f0b0", "yellowBright": "#ffd56a",
    "blueBright": "#9a8cf5", "magentaBright": "#cb52ec", "cyanBright": "#7fe4ec",
}
ANSI_NEUTROS = {"black": "#2a1350", "white": "#9568d8",
                "blackBright": "#482a92", "whiteBright": "#a872f2"}

# ── Mini-paleta del WALLPAPER SVG (horus_wallpaper2.svg) ──────
# Rampa de luz del primary (cielo + 6 capas de montaña) + glow calido.
# Se rota con el MISMO Δ del tema para que el fondo acompañe a la UI.
WALLPAPER = {
    "#b484f0": "wCielo0", "#8b45f7": "wCielo1", "#482490": "wCielo2",
    "#18092b": "wBase",   "#6c30c0": "wCapaB",  "#54249c": "wCapaC",
    "#3c0c6c": "wCapaD",  "#200c39": "wCapaE",  "#d86c54": "wGlow",
}

# ── Registro de temas (v2): nombre -> (color_central, Δluz, factor_croma) ──
# El tono del color central define el Δrotacion. Δluz y croma afinan la
# variante. Agregar/ajustar un tema = 1 linea.
TEMAS = {
    "Morado":          ("#7a2be8", 0.00, 1.00),  # base violeta (oscurecido ya horneado en MORADA)
    "Azul electrico":  ("#1e90ff", 0.05, 1.06),  # claro, vivo, cyan-ish
    "Azul rey":        ("#3538cd", -0.03, 1.02),  # profundo, hacia indigo
    "Rosa brillante":  ("#ff2e9a", 0.00, 1.06),  # hot pink saturado
    "Rosa palido":     ("#ff6fb5", 0.06, 0.52),  # mismo tono, desaturado y claro
    "Amarillo":        ("#f5c211", 0.00, 1.00),
    "Naranja":         ("#ff8a1f", 0.00, 1.00),
    "Rojo":            ("#ec3450", 0.00, 1.00),
    "Verde oscuro":    ("#2d8659", -0.03, 0.72),  # esmeralda profundo, apagado
    "Verde lima":      ("#b8e01e", 0.06, 1.08),   # lima acido, hacia amarillo
}
# "Gris" es especial (croma 0); se construye aparte.

def construir(nombre):
    """Devuelve la paleta completa (UI + terminal + wallpaper) de un tema."""
    base_h = _lch(MORADA["mPrimary"])[2]
    todo = dict(MORADA)
    todo.update({v: k for k, v in WALLPAPER.items()})  # añade roles wallpaper

    if nombre == "Gris":
        pal = {k: _rot(v, 0, gray=True) for k, v in MORADA.items()}
        pal.update({k: _rot(v, 0, gray=True) for k, v in ANSI_NEUTROS.items()})
        pal.update({k: _rot(v, 0, gray=True) for k, v in ANSI_FIJOS.items()})
        pal.update({role: _rot(hexc, 0, gray=True) for hexc, role in WALLPAPER.items()})
        return pal

    central, dL, fC = TEMAS[nombre]
    dh = (_lch(central)[2] - base_h) % 360
    pal = {k: _rot(v, dh, dL=dL, fC=fC) for k, v in MORADA.items()}
    pal.update({k: _rot(v, dh, dL=dL, fC=fC) for k, v in ANSI_NEUTROS.items()})  # neutros se tintan
    pal.update(ANSI_FIJOS)                                                        # semanticos anclados
    pal.update({role: _rot(hexc, dh, dL=dL, fC=fC)                                # wallpaper acompaña
                for hexc, role in WALLPAPER.items()})
    return pal

def lista_temas():
    return list(TEMAS) + ["Gris"]

# ── Modo CLARO: paleta por tema (superficies claras, texto oscuro) ──
def _oscurece(hexc, Lmax=0.50):
    """Baja la luz de un color para que lea sobre fondo claro."""
    L, C, H = _lch(hexc)
    return _hlc(min(L, Lmax), C, H)

def construir_light(nombre):
    """Paleta de MODO CLARO del tema: superficies claras + texto oscuro, con
    los acentos del MISMO tono del tema (oscurecidos para contraste). Los ANSI
    semanticos se oscurecen para leer sobre fondo claro (siguen significando
    lo mismo: rojo=error, verde=ok...)."""
    gray = (nombre == "Gris")
    H = 0.0 if gray else _lch(construir(nombre)["mPrimary"])[2]
    c = lambda L, Cr: _hlc(L, 0.0 if gray else Cr, 0.0 if gray else H)
    pal = {
        "mPrimary":          c(0.52, 0.160),
        "mOnPrimary":        c(0.99, 0.010),
        "mSecondary":        c(0.55, 0.130),
        "mTertiary":         c(0.58, 0.120),
        "mError":            "#c0263f",
        "mSurface":          c(0.975, 0.010),
        "mOnSurface":        c(0.22, 0.045),
        "mSurfaceVariant":   c(0.92, 0.020),
        "mOnSurfaceVariant": c(0.42, 0.040),
        "mOutline":          c(0.70, 0.030),
        "mShadow":           c(0.80, 0.008),
        "mHover":            c(0.90, 0.030),
        "termFg":            c(0.25, 0.040),
        "termBg":            c(0.970, 0.008),
        "termSelFg":         c(0.18, 0.050),
        "termSelBg":         c(0.86, 0.040),
        "termCursor":        c(0.50, 0.160),
    }
    # ANSI para fondo claro: semanticos oscurecidos; neutros invertidos.
    for k, v in ANSI_FIJOS.items():
        pal[k] = _oscurece(v, 0.58 if k.endswith("Bright") else 0.50)
    pal["black"]       = c(0.30, 0.030)
    pal["white"]       = c(0.72, 0.020)
    pal["blackBright"] = c(0.45, 0.030)
    pal["whiteBright"] = c(0.85, 0.015)
    return pal

if __name__ == "__main__":
    todos = {n: construir(n) for n in lista_temas()}
    print(json.dumps(todos, indent=2, ensure_ascii=False))


# ── API para el aplicador horus-theme ───────────────────────────
def _params(nombre):
    """(dh, dL, fC) del tema. Gris se marca con dh=None."""
    if nombre == "Gris":
        return (None, 0.0, 0.0)
    central, dL, fC = TEMAS[nombre]
    base_h = _lch(MORADA["mPrimary"])[2]
    return ((_lch(central)[2] - base_h) % 360, dL, fC)

def rotar_hex(hexc, nombre):
    """Rota UN color con los parametros del tema. Para parchear archivos de
    UI (Niri, SDDM, cursor, Zen) donde el color es decorativo."""
    dh, dL, fC = _params(nombre)
    if dh is None:                       # Gris
        return _rot(hexc, 0, gray=True)
    return _rot(hexc, dh, dL=dL, fC=fC)


# ── Folders de Thunar/Papirus por tema ───────────────────────────
# 9 temas mapean a una familia que Papirus YA trae (papirus-folders solo la
# activa). Los dos verdes no tienen equivalente (Papirus trae un unico verde
# oliva), asi que se recolorean al hex del tema en un overlay hijo.


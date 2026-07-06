# branding

Branding visual de Horus. Sin identidad falsa: `os-release` y compañía
quedan intactos — esto es un post-install sobre la distro, no una distro.

- `horus-ascii.txt` — logo (ojo de Horus) para fastfetch, con placeholders
  `$1`/`$2` que el config colorea en dos tonos.
- `config.jsonc` — config base de fastfetch. `horus-theme` la rota a los
  colores del tema activo y la instala junto con el logo en
  `~/.config/fastfetch/`.

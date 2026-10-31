#!/usr/bin/env bash
# nimbus-osd — teclas multimedia → OSD in-situ de nimbus-bar (F3-T10).
# Uso: nimbus-osd.sh volume-up|volume-down|mute|brightness-up|brightness-down
# Ajusta el canal real y avisa a la barra por DBus:
#   qdbus6 org.nimbus.OSD /OSD org.nimbus.OSD.show volume 0.70
# Sin barra (qdbus falla) igual ajusta el canal; exit 1 con contexto.
#
# Binding real (ruta existente de Plasma, nada inventado): Ajustes del
# sistema → Teclado → Atajos → Añadir nuevo → Orden, p.ej.
#   `nimbus-osd.sh volume-up` con disparador XF86AudioRaiseVolume.
# Tabla de disparadores (keysyms XKB estándar que Plasma entrega al atajo):
#   volume-up      XF86AudioRaiseVolume
#   volume-down    XF86AudioLowerVolume
#   mute           XF86AudioMute
#   brightness-up  XF86MonBrightnessUp
#   brightness-down XF86MonBrightnessDown
set -u

usage() {
  echo "Uso: nimbus-osd.sh volume-up|volume-down|mute|brightness-up|brightness-down" >&2
  exit 1
}
[ $# -eq 1 ] || usage

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "nimbus-osd: falta '$1'; instálalo o usa el otro canal (wpctl/pactl, brightnessctl)" >&2
    exit 1
  }
}

osd_show() {
  # Avisa a la barra; si no está, solo avisa (el canal ya se ajustó).
  qdbus6 org.nimbus.OSD /OSD org.nimbus.OSD.show "$1" "$2" 2>/dev/null || \
    echo "nimbus-osd: barra no disponible en DBus (canal ajustado igual)" >&2
}

vol_value() {
  # Eco 0..1 del volumen actual (wpctl, fallback pactl %).
  local out
  out="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -m1 -o '[0-9]*%' || echo "")"
  if [[ "$out" == *"%"* ]]; then
    awk -v n="${out//[^0-9]/}" 'BEGIN { printf "%.2f", n / 100 }'
  else
    echo "$out" | grep -m1 -o '[0-9]*\.[0-9]*' || echo "0.50"
  fi
}

bri_value() {
  # Eco 0..1 del brillo actual (brightnessctl -m, fallback sysfs).
  local out d cur max
  out="$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d ' %')"
  if [ -n "$out" ]; then
    awk -v n="$out" 'BEGIN { printf "%.2f", n / 100 }'
    return
  fi
  d="$(ls -d /sys/class/backlight/* 2>/dev/null | head -1 || true)"
  if [ -n "$d" ]; then
    cur="$(cat "$d/brightness")"; max="$(cat "$d/max_brightness")"
    awk -v c="$cur" -v m="$max" 'BEGIN { printf "%.2f", c / m }'
  else
    echo "nimbus-osd: sin canal de brillo (ni brightnessctl ni /sys/class/backlight)" >&2
    echo "0.50"
  fi
}

case "$1" in
  volume-up)
    need wpctl || need pactl
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ 2>/dev/null \
      || pactl set-sink-volume @DEFAULT_SINK@ +5%
    osd_show volume "$(vol_value)" ;;
  volume-down)
    need wpctl || need pactl
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- 2>/dev/null \
      || pactl set-sink-volume @DEFAULT_SINK@ -5%
    osd_show volume "$(vol_value)" ;;
  mute)
    need wpctl || need pactl
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null \
      || pactl set-sink-mute @DEFAULT_SINK@ toggle
    osd_show volume "$(vol_value)" ;;
  brightness-up)
    need brightnessctl
    brightnessctl set +5% >/dev/null
    osd_show brightness "$(bri_value)" ;;
  brightness-down)
    need brightnessctl
    brightnessctl set 5%- >/dev/null
    osd_show brightness "$(bri_value)" ;;
  *) usage ;;
esac

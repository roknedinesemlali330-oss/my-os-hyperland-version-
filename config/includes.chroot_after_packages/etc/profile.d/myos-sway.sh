# Environment for the MyOS desktop session (works inside virtual machines too).
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER_ALLOW_SOFTWARE=1
export QT_QUICK_BACKEND=software
export QS_ICON_THEME=Papirus
export MOZ_ENABLE_WAYLAND=1

# On the first console (tty1): start Hyprland.
# If Hyprland fails to start, fall back to sway so the system is still usable.
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  if Hyprland -c /etc/myos/hyprland.conf; then
    exit 0
  else
    exec sway
  fi
fi

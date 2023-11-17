#!/bin/sh
# shebang for shellcheck

[ "$XDG_SESSION_TYPE" = "wayland" ] || return 0

IM_MODULE=''
DEFAULT_FCITX='fcitx'
DEFAULT_IM_MODULE="$DEFAULT_FCITX"

for im_module in "$GTK_IM_MODULE" "$QT_IM_MODULE" "$SDL_IM_MODULE"; do
  [ -z "$im_module" ] && continue
  [ -n "$IM_MODULE" ] && break
  IM_MODULE="$im_module"
done

if [ -z "$IM_MODULE" ] && echo "$XMODIFIERS" | grep -q '@im=fcitx'; then
  IM_MODULE="$DEFAULT_FCITX"
fi

if [ -z "$IM_MODULE" ]; then
  echo "WARNING: No IM module found! Using $DEFAULT_IM_MODULE..."
  IM_MODULE="$DEFAULT_IM_MODULE"
fi

export GTK_IM_MODULE="$IM_MODULE" QT_IM_MODULE="$IM_MODULE" SDL_IM_MODULE="$IM_MODULE"

if echo "$IM_MODULE" | grep -q '^fcitx' && ! echo "$XMODIFIERS" | grep -q '@im'; then
  export XMODIFIERS="@im=$DEFAULT_IM_MODULE:$XMODIFIERS"
fi

#!/bin/sh

set -eu

BASE_DIR='build'

DOWNLOAD_DIR="$BASE_DIR/raw"
EXTRACT_DIR="$BASE_DIR/raw"
CONTRIB_DIR="$BASE_DIR/contrib"
REPACK_DIR="$BASE_DIR/repack"
BUILD_DIR="$BASE_DIR/dist"

INT_CDN='https://wdl1.pcfg.cache.wpscdn.com'

LIBFREETYPE6_DEB_URL='https://snapshot.debian.org/archive/debian/20220702T033910Z/pool/main/f/freetype/libfreetype6_2.10.4%2Bdfsg-1%2Bdeb11u1_amd64.deb'
LIBFREETYPE6_DEB_FILE="$CONTRIB_DIR/$(basename "$LIBFREETYPE6_DEB_URL")"
EXTRACT_PATH_LIBFREETYPE6="$EXTRACT_DIR/libfreetype6"

BIN_PATH='/usr/bin'
REAL_BIN_PATH='/opt/kingsoft/wps-office/office6'
L10N_PATH="$REAL_BIN_PATH/mui"
TEMPLATES_PATH='/opt/kingsoft/wps-office/templates'
CTRL_PATH='/DEBIAN'

MUI_VERSION_SUFFIX='mui'
PREFIXED_VERSION_SUFFIX='prefixed'
KDEDARK_VERSION_SUFFIX='kdedark'
FCITX5XWAYLAND_VERSION_SUFFIX='fcitx5xwayland'
BOLD_VERSION_SUFFIX='bold'

VALID_VER_SUFFIX_REGEX="^(\+($MUI_VERSION_SUFFIX|$PREFIXED_VERSION_SUFFIX|$KDEDARK_VERSION_SUFFIX|$FCITX5XWAYLAND_VERSION_SUFFIX|$BOLD_VERSION_SUFFIX))+$"

mkdir -p $DOWNLOAD_DIR $EXTRACT_DIR $REPACK_DIR $BUILD_DIR

# shellcheck disable=SC2034
load_source() {
  ### $1: force fetch remote? (default: 0)
  ### RETURN 0: not updated or use lock file
  ### RETURN 1: updated
  force=${1:-0}

  previous_source_lock=$(cat .source.lock || echo)
  CHN_DEB_URL=$(echo "$previous_source_lock" | head -n 2 | tail -n 1 | sed 's/CHN: //')

  if [ "$force" -eq 0 ] && [ -n "$CHN_DEB_URL" ] && echo "$CHN_DEB_URL" | grep -Pq '^https?://'; then
    echo "Loaded previous source lock."
    fetched=0
  else
    # CHN: https://wps-linux-personal.wpscdn.cn/wps/download/ep/Linux2019/11664/wps-office_11.1.0.11664_amd64.deb
    # INT: https://wdl1.pcfg.cache.wpscdn.com/wpsdl/wpsoffice/download/linux/11664/wps-office_11.1.0.11664.XA_amd64.deb
    echo 'Fetching latest version...'
    download_page=$(curl -sL 'https://linux.wps.cn')
    CHN_DEB_URL=$(echo "$download_page" | grep -Po '(?<=href=").+?(?=".*Deb.*X64)')
    fetched=1
  fi

  LATEST_VERSION=$(echo "$CHN_DEB_URL" | grep -Po '(?<=_)[\d.]+(?=_)')
  LATEST_BUILD=$(echo "$LATEST_VERSION" | grep -Po '(?<=\.)\d+$')
  INT_DEB_URL="$INT_CDN/wpsdl/wpsoffice/download/linux/$LATEST_BUILD/wps-office_$LATEST_VERSION.XA_amd64.deb"

  SOURCE_LOCK=$(printf '%s\nCHN: %s\nINT: %s' "$LATEST_VERSION" "$CHN_DEB_URL" "$INT_DEB_URL")

  echo "Latest version: $LATEST_VERSION"
  echo "CHN deb url: $CHN_DEB_URL"
  echo "INT deb url: $INT_DEB_URL"

  if [ -z "$LATEST_VERSION" ] || [ -z "$CHN_DEB_URL" ] || [ -z "$INT_DEB_URL" ]; then
    echo 'Invalid parsed source! Aborting...'
    exit 1
  fi

  updated=0
  if [ "$SOURCE_LOCK" = "$previous_source_lock" ]; then
    if [ "$fetched" -eq 1 ]; then
      echo "No new version found."
    fi
  else
    if [ "$fetched" -eq 1 ]; then
      updated=1
    else
      echo "Invalid source lock! Aborting..."
      exit 1
    fi
  fi

  if [ "$updated" -eq 1 ]; then
    rm -f .source.lock
    echo "$SOURCE_LOCK" >.source.lock
  fi

  CHN_DEB_FILENAME="$(basename "$CHN_DEB_URL")"
  INT_DEB_FILENAME="$(basename "$INT_DEB_URL")"
  CHN_DEB_TRIPLE="$(echo "$CHN_DEB_FILENAME" | grep -iPo '^.+(?=\.deb$)')"
  INT_DEB_TRIPLE="$(echo "$INT_DEB_FILENAME" | grep -iPo '^.+(?=\.deb$)')"
  CHN_DEB_PKG_NAME="$(echo "$CHN_DEB_TRIPLE" | grep -Po '^[a-zA-Z\d\-+]+(?=_)')"
  INT_DEB_PKG_NAME="$(echo "$INT_DEB_TRIPLE" | grep -Po '^[a-zA-Z\d\-+]+(?=_)')"
  CHN_DEB_VER="$(echo "$CHN_DEB_TRIPLE" | grep -Po '(?<=_)[a-zA-Z\d\-+.]+(?=_)')"
  INT_DEB_VER="$(echo "$INT_DEB_TRIPLE" | grep -Po '(?<=_)[a-zA-Z\d\-+.]+(?=_)')"
  CHN_DEB_ARCH="$(echo "$CHN_DEB_TRIPLE" | grep -Po '(?<=_)[a-zA-Z\d]+$')"
  INT_DEB_ARCH="$(echo "$INT_DEB_TRIPLE" | grep -Po '(?<=_)[a-zA-Z\d]+$')"
  CHN_DEB_FILE="$DOWNLOAD_DIR/$CHN_DEB_FILENAME"
  INT_DEB_FILE="$DOWNLOAD_DIR/$INT_DEB_FILENAME"
  EXTRACT_PATH_CHN="$EXTRACT_DIR/$CHN_DEB_TRIPLE"
  EXTRACT_PATH_INT="$EXTRACT_DIR/$INT_DEB_TRIPLE"
  return $updated
}

download() {
  # $1: url
  # $2: file path
  if which aria2c >/dev/null; then
    aria2c -c -j8 -x8 -s8 -d "$(dirname "$2")" -o "$(basename "$2")" "$1"
  else
    wget -q -c --tries=10 --show-progress --progress=bar:force:noscroll -O "$2" "$1"
  fi
}

extract() {
  ### $1: file path
  ### $2: extract path
  echo "Extracting $1 to $2..."

  if [ ! -f "$1" ]; then
    echo "File $1 not found!"
    exit 1
  fi

  if [ -d "$2" ]; then
    echo "Path $2 already exists, skipping..."
    return 0
  fi

  # extract
  mkdir -p "$2"
  dpkg-deb -R "$1" "$2/"

  echo "Extracted $1 to $2."
}

download_and_extract() {
  ### $1: url
  ### $2: file path
  ### $3: extract path
  download "$1" "$2"
  extract "$2" "$3"
}

init_repack() {
  ### $1: base path
  ### $2: repack path
  echo "Initializing repack $2 from $1..."
  rm -rf "$2"
  mkdir -p "$2"
  # create hard links
  cp -alT "$1/" "$2"
  echo "Initialized repack $2 from $1."
}

inject_l10n() {
  ### $1: repack path without l10n files
  if [ -d "$EXTRACT_PATH_CHN" ]; then
    :
  elif [ -f "$CHN_DEB_FILE" ]; then
    extract "$CHN_DEB_FILE" "$EXTRACT_PATH_CHN"
  else
    download_and_extract "$CHN_DEB_URL" "$CHN_DEB_FILE" "$EXTRACT_PATH_CHN"
  fi

  echo "Injecting l10n from $EXTRACT_PATH_CHN to $1..."

  rm -rf "$1$L10N_PATH"
  cp -al "$EXTRACT_PATH_CHN$L10N_PATH" "$1$L10N_PATH"

  rm -rf "$1$TEMPLATES_PATH"
  cp -al "$EXTRACT_PATH_CHN$TEMPLATES_PATH" "$1$TEMPLATES_PATH"

  echo "Injected l10n from $EXTRACT_PATH_CHN to $1."
}

prefix_cmd() {
  ### $1: repack path
  echo "Prefixing all commands in $1..."

  for componet in "et" "wpp"; do
    path_bin="$BIN_PATH/$componet"
    new_path_bin="$BIN_PATH/wps$componet"
    desktop_file="/usr/share/applications/wps-office-$componet.desktop"
    desktop_file_opt="/opt/kingsoft/wps-office/desktops/wps-office-$componet.desktop"
    if [ -f "$1$path_bin" ]; then
      echo "Prefixing $path_bin to $new_path_bin..."
      mv "$1$path_bin" "$1$new_path_bin"
      sed -i "s#$path_bin#$new_path_bin#g" "$1$desktop_file" "$1$desktop_file_opt"
    else
      echo "File $path_bin not found!"
      exit 1
    fi
  done

  echo "Prefixed all commands in $1."
}

workaround_kde_dark() {
  ### $1: repack path
  echo "Working around KDE dark theme in $1..."
  for componet in "$1$BIN_PATH"/*; do
    if [ -f "$componet" ]; then
      echo "Working around KDE dark theme for $componet..."
      sed -i "1a\export XDG_CURRENT_DESKTOP=GNOME GTK_THEME=Default" "$componet"
    fi
  done
  echo "Worked around KDE dark theme in $1."
}

workaround_fcitx5_xwayland() {
  ### $1: repack path
  script_name='fcitx5xwayland.sh'
  script_path="$REAL_BIN_PATH/$script_name"
  echo "Working around Fcitx5 on XWayland in $1..."
  cp "src/$script_name" "$1$script_path"
  for componet in "$1$BIN_PATH"/*; do
    if [ -f "$componet" ]; then
      echo "Working around Fcitx5 on XWayland for $componet..."
      sed -i "1a\. '$script_path'" "$componet"
    fi
  done
  echo "Worked around Fcitx5 on XWayland in $1."
}

workaround_bold() {
  ### $1: repack path
  if [ -d "$EXTRACT_PATH_LIBFREETYPE6" ]; then
    :
  elif [ -f "$LIBFREETYPE6_DEB_FILE" ]; then
    extract "$LIBFREETYPE6_DEB_FILE" "$EXTRACT_PATH_LIBFREETYPE6"
  else
    download_and_extract "$LIBFREETYPE6_DEB_URL" "$LIBFREETYPE6_DEB_FILE" "$EXTRACT_PATH_LIBFREETYPE6"
  fi
  echo "Working around bold font in $1..."
  cp -al "$EXTRACT_PATH_LIBFREETYPE6/usr/lib/x86_64-linux-gnu"/* "$1$REAL_BIN_PATH/"
  sed -i '/ks_check_library_version libfreetype.so.6/d' "$1$CTRL_PATH/postinst"
  echo "Worked around bold font in $1."
}

build() {
  ### $1: package version suffix (e.g. "-repack" will result in "1.0-repack")
  ### $2: repack path
  echo "Building $2..."

  if [ ! -d "$2" ]; then
    echo "Repack path $2 not found!"
    exit 1
  fi

  # inject version suffix
  sed -i "/^Version:/ s/$/$1/" "$2/DEBIAN/control"
  # build package
  dpkg-deb --root-owner-group -b "$2/" "$BUILD_DIR"

  echo "Built $2."
}

repack_target() {
  ### $1: base pkg, INT or CHN
  ### $2: patches to apply, e.g. +patch1+patch2+patch3
  echo "Repacking target $1 with patches $2..."
  if [ "$1" != 'INT' ] && [ "$1" != 'CHN' ]; then
    echo "Invalid target $1!"
    exit 1
  fi
  if ! echo "$2" | grep -Pq "$VALID_VER_SUFFIX_REGEX"; then
    echo "Invalid patches $2!"
    exit 1
  fi

  deb_url=$(eval "echo \$${1}_DEB_URL")
  deb_file=$(eval "echo \$${1}_DEB_FILE")
  extract_path=$(eval "echo \$EXTRACT_PATH_${1}")

  deb_pkg_name=$(eval "echo \$${1}_DEB_PKG_NAME")
  deb_ver=$(eval "echo \$${1}_DEB_VER")
  deb_arch=$(eval "echo \$${1}_DEB_ARCH")

  repack_path="$REPACK_DIR/${deb_pkg_name}_${deb_ver}${2}_${deb_arch}"

  if [ -d "$extract_path" ]; then
    :
  elif [ -f "$deb_file" ]; then
    extract "$deb_file" "$extract_path"
  else
    download_and_extract "$deb_url" "$deb_file" "$extract_path"
  fi

  init_repack "$extract_path" "$repack_path"
  for patch in $(echo "$2" | grep -Po '(?<=\+)\w+(?=\+|$)'); do
    case "$patch" in
    "$MUI_VERSION_SUFFIX") inject_l10n "$repack_path" ;;
    "$PREFIXED_VERSION_SUFFIX") prefix_cmd "$repack_path" ;;
    "$KDEDARK_VERSION_SUFFIX") workaround_kde_dark "$repack_path" ;;
    "$FCITX5XWAYLAND_VERSION_SUFFIX") workaround_fcitx5_xwayland "$repack_path" ;;
    "$BOLD_VERSION_SUFFIX") workaround_bold "$repack_path" ;;
    *)
      echo "Invalid patch $patch!"
      exit 1
      ;;
    esac
  done
  build "$2" "$repack_path"
}

stage_init() {
  ### $@: stage list, e.g. 1 2 3 6 7 8, or i_am_a_stage i_am_another_stage
  STAGES="$*"
}

stage() {
  ### $1: stage
  ### RET: 0 if stage should be skipped, 1 otherwise
  ### Usage: stage $1 || cmd
  if [ -z "$STAGES" ]; then
    return 1
  elif echo "$STAGES" | grep -Pq "(?<=^|\s)$1(?=\s|$)"; then
    return 1
  else
    return 0
  fi
}

wait_task() {
  ### $1: pid
  if waitpid -V >/dev/null 2>&1; then
    waitpid -e "$1"
  else
    while kill -0 "$1" >/dev/null 2>&1; do
      sleep 0.5
    done
  fi
}

repack_task() {
  ### $1: pid of prerequisite, 0 if no prerequisite
  ### $2: stage base to add
  ### $3: target
  ### $4: suffix base to add (optional)
  [ "$1" -eq 0 ] || wait_task "$1" || true
  stage_base="$2"
  if [ -n "${4:-}" ]; then
    stage "$((stage_base + 1))" || repack_target "$3" "${4:-}"
    stage_base="$((stage_base + 1))"
  fi
  stage "$((stage_base + 1))" || repack_target "$3" "${4:-}+$PREFIXED_VERSION_SUFFIX"
  stage "$((stage_base + 2))" || repack_target "$3" "${4:-}+$KDEDARK_VERSION_SUFFIX"
  stage "$((stage_base + 3))" || repack_target "$3" "${4:-}+$FCITX5XWAYLAND_VERSION_SUFFIX"
  stage "$((stage_base + 4))" || repack_target "$3" "${4:-}+$BOLD_VERSION_SUFFIX"
  stage "$((stage_base + 5))" || repack_target "$3" "${4:-}+$PREFIXED_VERSION_SUFFIX+$KDEDARK_VERSION_SUFFIX"
  stage "$((stage_base + 6))" || repack_target "$3" "${4:-}+$PREFIXED_VERSION_SUFFIX+$FCITX5XWAYLAND_VERSION_SUFFIX"
  stage "$((stage_base + 7))" || repack_target "$3" "${4:-}+$PREFIXED_VERSION_SUFFIX+$BOLD_VERSION_SUFFIX"
  stage "$((stage_base + 8))" || repack_target "$3" "${4:-}+$KDEDARK_VERSION_SUFFIX+$FCITX5XWAYLAND_VERSION_SUFFIX"
  stage "$((stage_base + 9))" || repack_target "$3" "${4:-}+$KDEDARK_VERSION_SUFFIX+$BOLD_VERSION_SUFFIX"
  stage "$((stage_base + 10))" || repack_target "$3" "${4:-}+$FCITX5XWAYLAND_VERSION_SUFFIX+$BOLD_VERSION_SUFFIX"
  stage "$((stage_base + 11))" || repack_target "$3" "${4:-}+$PREFIXED_VERSION_SUFFIX+$KDEDARK_VERSION_SUFFIX+$FCITX5XWAYLAND_VERSION_SUFFIX"
  stage "$((stage_base + 12))" || repack_target "$3" "${4:-}+$PREFIXED_VERSION_SUFFIX+$KDEDARK_VERSION_SUFFIX+$BOLD_VERSION_SUFFIX"
  stage "$((stage_base + 13))" || repack_target "$3" "${4:-}+$PREFIXED_VERSION_SUFFIX+$FCITX5XWAYLAND_VERSION_SUFFIX+$BOLD_VERSION_SUFFIX"
  stage "$((stage_base + 14))" || repack_target "$3" "${4:-}+$KDEDARK_VERSION_SUFFIX+$FCITX5XWAYLAND_VERSION_SUFFIX+$BOLD_VERSION_SUFFIX"
  stage "$((stage_base + 15))" || repack_target "$3" "${4:-}+$PREFIXED_VERSION_SUFFIX+$KDEDARK_VERSION_SUFFIX+$FCITX5XWAYLAND_VERSION_SUFFIX+$BOLD_VERSION_SUFFIX"
}

main() {
  ### $@: stage list
  stage_per_task=15

  stage_init "$@"

  load_source "$(stage -1)" || true # if stage -1 is specified, force fetch remote, otherwise use local

  stage 0 || download_and_extract "$LIBFREETYPE6_DEB_URL" "$LIBFREETYPE6_DEB_FILE" "$EXTRACT_PATH_LIBFREETYPE6" &
  stage 0 && pid_download_libfreetype6=0 || pid_download_libfreetype6=$!
  stage 0 || download_and_extract "$INT_DEB_URL" "$INT_DEB_FILE" "$EXTRACT_PATH_INT" &
  stage 0 && pid_download_int=0 || pid_download_int=$!
  stage 0 || download_and_extract "$CHN_DEB_URL" "$CHN_DEB_FILE" "$EXTRACT_PATH_CHN" &
  stage 0 && pid_download_chn=0 || pid_download_chn=$!

  [ "$pid_download_libfreetype6" -eq 0 ] || wait "$pid_download_libfreetype6" || true

  # build INT packages immediately after INT deb is downloaded
  repack_task "$pid_download_int" 0 'INT' &

  # build CHN packages immediately after CHN deb is downloaded
  repack_task "$pid_download_chn" "$stage_per_task" 'CHN' &

  # wait for INT & CHN download to finish in order to build INT+mui packages
  stage 0 || wait "$pid_download_int" "$pid_download_chn"

  # build INT+mui packages immediately after INT & CHN deb is downloaded
  repack_task 0 "$((stage_per_task * 2))" 'INT' "+$MUI_VERSION_SUFFIX" &

  # wait for all tasks
  wait
}

abort() {
  echo "Aborting..."
  jobs -l
  pkill -s0
}
trap abort INT

if [ "$#" -eq 0 ]; then
  main
  cp -al build/raw/*.deb build/dist/
else
  main "$@"
fi

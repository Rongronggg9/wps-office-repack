#!/bin/sh

set -eu

BASE_DIR='build'

DOWNLOAD_DIR="$BASE_DIR/raw"
EXTRACT_DIR="$BASE_DIR/raw"
REPACK_DIR="$BASE_DIR/repack"
BUILD_DIR="$BASE_DIR/dist"

INT_CDN='https://wdl1.pcfg.cache.wpscdn.com'

L10N_PATH='/opt/kingsoft/wps-office/office6/mui/zh_CN'

REPACK_VERSION_POSTFIX='repack'
REPACK_PREFIXED_VERSION_POSTFIX='repack+prefixed'

mkdir -p $DOWNLOAD_DIR $EXTRACT_DIR $REPACK_DIR $BUILD_DIR

detach_hard_link() {
  ### $1: file path
  cp -a "$1" "$1.tmp"
  mv -f "$1.tmp" "$1"
}

fetch_source() {
  # CHN: https://wps-linux-personal.wpscdn.cn/wps/download/ep/Linux2019/11664/wps-office_11.1.0.11664_amd64.deb
  # INT: https://wdl1.pcfg.cache.wpscdn.com/wpsdl/wpsoffice/download/linux/11664/wps-office_11.1.0.11664.XA_amd64.deb
  echo 'Fetching latest version...'
  DOWNLOAD_PAGE=$(curl -sL 'https://linux.wps.cn')
  CHN_DEB_URL=$(echo "$DOWNLOAD_PAGE" | grep -Po '(?<=href=").*?(?=".*Deb.*X64)')
  LATEST_VERSION=$(echo "$CHN_DEB_URL" | grep -Po '(?<=_)[\d.]+(?=_)')
  LATEST_BUILD=$(echo "$LATEST_VERSION" | grep -Po '(?<=\.)\d+$')
  INT_DEB_URL="$INT_CDN/wpsdl/wpsoffice/download/linux/$LATEST_BUILD/wps-office_$LATEST_VERSION.XA_amd64.deb"

  echo "Latest version: $LATEST_VERSION"

  PREVIOUS_VERSION=$(cat .curr_version)
  if [ "$LATEST_VERSION" = "$PREVIOUS_VERSION" ]; then
    echo "No new version found."
    exit 0
  fi

  CHN_DEB_FILE="$DOWNLOAD_DIR/chn_${LATEST_VERSION}.deb"
  INT_DEB_FILE="$DOWNLOAD_DIR/int_${LATEST_VERSION}.deb"
}

download() {
  # $1: url
  # $2: file path
  if [ ! -f "$2" ]; then
    wget -q --show-progress --progress=bar:force:noscroll -O "$2" "$1"
  else
    echo "$2 already exists, skipping..."
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
  ### $1: raw path with l10n files
  ### $2: repack path without l10n files
  echo "Injecting l10n from $1 to $2..."

  if [ ! -d "$1" ]; then
    echo "Raw path $1 not found!"
    exit 1
  fi

  if [ ! -d "$2" ]; then
    echo "Repack path $2 not found!"
    exit 1
  fi

  mkdir -p "$2$L10N_PATH"
  cp -al "$1$L10N_PATH" "$2$L10N_PATH"

  echo "Injected l10n from $1 to $2..."
}

prefix_cmd() {
  ### $1: repack path
  echo "Prefixing all commands in $1..."

  for componet in "et" "wpp"; do
    path_bin="/usr/bin/$componet"
    new_path_bin="/usr/bin/wps$componet"
    desktop_file="/usr/share/applications/wps-office-$componet.desktop"
    if [ -f "$1$path_bin" ]; then
      echo "Prefixing $path_bin to $new_path_bin..."
      mv "$1$path_bin" "$1$new_path_bin"
      detach_hard_link "$1$desktop_file"
      sed -i "s#$path_bin#$new_path_bin#g" "$1$desktop_file"
    else
      echo "File $path_bin not found!"
      exit 1
    fi
  done

  echo "Prefixed all commands in $1."
}

build() {
  ### $1: package version postfix (e.g. "repack" will result in "1.0-repack")
  ### $2: repack path
  echo "Building $2..."

  if [ ! -d "$2" ]; then
    echo "Repack path $2 not found!"
    exit 1
  fi

  detach_hard_link "$2/DEBIAN/control"
  # inject version postfix
  sed -i "/^Version:/ s/$/-$1/" "$2/DEBIAN/control"
  # build package
  dpkg-deb -z9 -b "$2/" "$BUILD_DIR"

  echo "Built $2."
}

post() {
  echo "$LATEST_VERSION" >.curr_version
}

fetch_source

EXTRACT_PATH_CHN="$EXTRACT_DIR/chn_$LATEST_VERSION"
EXTRACT_PATH_INT="$EXTRACT_DIR/int_$LATEST_VERSION"

download_and_extract "$INT_DEB_URL" "$INT_DEB_FILE" "$EXTRACT_PATH_INT" &
download_and_extract "$CHN_DEB_URL" "$CHN_DEB_FILE" "$EXTRACT_PATH_CHN" &
wait

REPACK_PATH="$REPACK_DIR/$LATEST_VERSION-$REPACK_VERSION_POSTFIX"
REPACK_PREFIXED_PATH="$REPACK_DIR/$LATEST_VERSION-$REPACK_PREFIXED_VERSION_POSTFIX"

init_repack "$EXTRACT_PATH_INT" "$REPACK_PATH"
inject_l10n "$EXTRACT_PATH_CHN" "$REPACK_PATH"

init_repack "$REPACK_PATH" "$REPACK_PREFIXED_PATH"
prefix_cmd "$REPACK_PREFIXED_PATH"

# no need to parallelize build, it is already multi-threaded
build "$REPACK_VERSION_POSTFIX" "$REPACK_PATH"
build "$REPACK_PREFIXED_VERSION_POSTFIX" "$REPACK_PREFIXED_PATH"

post

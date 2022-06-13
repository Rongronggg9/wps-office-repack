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

mkdir -p $DOWNLOAD_DIR $EXTRACT_DIR $REPACK_DIR $BUILD_DIR

download() {
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

  echo "Downloading CHN deb..."
  if [ ! -f "$CHN_DEB_FILE" ]; then
    wget --progress=dot:giga -O "$CHN_DEB_FILE" "$CHN_DEB_URL"
  else
    echo "CHN deb already exists, skipping..."
  fi

  echo "Downloading INT deb..."
  if [ ! -f "$INT_DEB_FILE" ]; then
    wget --progress=dot:giga -O "$INT_DEB_FILE" "$INT_DEB_URL"
  else
    echo "INT deb already exists, skipping..."
  fi

  echo "Done."
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

  echo "Done."
}

init_repack() {
  ### $1: base path
  ### $2: repack path
  echo "Initializing repack $2..."
  rm -rf "$2"
  mkdir -p "$2"
  # create hard links
  cp -alT "$1/" "$2"
  echo "Done."
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

  echo "Done."
}

build() {
  ### $1: package version postfix (e.g. "repack" will result in "1.0-repack")
  ### $2: repack path
  echo "Building $2..."

  if [ ! -d "$2" ]; then
    echo "Repack path $2 not found!"
    exit 1
  fi

  # detach hard link
  mv "$2/DEBIAN/control" "$2/DEBIAN/control.orig"
  cp -a "$2/DEBIAN/control.orig" "$2/DEBIAN/control"
  # inject version postfix
  sed -i "/^Version:/ s/$/-$1/" "$2/DEBIAN/control"
  # build package
  dpkg-deb -z9 -b "$2/" "$BUILD_DIR"

  echo "Done."
}

post() {
  echo "$LATEST_VERSION" > .curr_version
}

download
echo

EXTRACT_PATH_CHN="$EXTRACT_DIR/chn_$LATEST_VERSION"
EXTRACT_PATH_INT="$EXTRACT_DIR/int_$LATEST_VERSION"

extract "$CHN_DEB_FILE" "$EXTRACT_PATH_CHN"
echo

extract "$INT_DEB_FILE" "$EXTRACT_PATH_INT"
echo

REPACK_PATH="$REPACK_DIR/$LATEST_VERSION-$REPACK_VERSION_POSTFIX"

init_repack "$EXTRACT_PATH_INT" "$REPACK_PATH"
echo

inject_l10n "$EXTRACT_PATH_CHN" "$REPACK_PATH"
echo

build "$REPACK_VERSION_POSTFIX" "$REPACK_PATH"
echo

post

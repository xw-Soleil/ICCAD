#!/usr/bin/env bash
set -euo pipefail

BASE="https://apod.nasa.gov/apod"
SAVE_DIR="$HOME/Pictures/APOD"
LOG_DIR="$HOME/.cache/apod"
LOG_FILE="$LOG_DIR/apod.log"

mkdir -p "$SAVE_DIR" "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"
}

# get images
extract_image_url_from_page() {
  local page_url="$1"
  local html rel

  html="$(wget -qO- "$page_url" || true)"
  [[ -n "$html" ]] || return 1

  # find href large image
  rel="$(printf '%s\n' "$html" \
    | grep -Eio 'href="image/[^"]+\.(jpg|jpeg|png)"' \
    | head -n1 | cut -d'"' -f2 || true)"

  # find src image if not find href image
  if [[ -z "$rel" ]]; then
    rel="$(printf '%s\n' "$html" \
      | grep -Eio 'src="image/[^"]+\.(jpg|jpeg|png)"' \
      | head -n1 | cut -d'"' -f2 || true)"
  fi

  [[ -n "$rel" ]] || return 1
  printf '%s/%s\n' "$BASE" "$rel"
}

set_wallpaper_gnome() {
  local file_path="$1"
  local abs uri
  abs="$(realpath "$file_path")"
  uri="file://$abs"

  gsettings set org.gnome.desktop.background picture-uri "$uri"
  gsettings set org.gnome.desktop.background picture-uri-dark "$uri"
  gsettings set org.gnome.desktop.background picture-options "zoom" >/dev/null 2>&1 || true
}

main() {
  local max_back=14
  local back yy mmdd page imgurl fname out date_prefix

  for back in $(seq 0 "$max_back"); do
    yy="$(date -d "today - $back day" +%y)"
    mmdd="$(date -d "today - $back day" +%m%d)"
    page="$BASE/ap191130.html"

    imgurl="$(extract_image_url_from_page "$page" || true)"
    if [[ -z "$imgurl" ]]; then
      log "No image found on $page (maybe video day). Trying earlier..."
      continue
    fi

    fname="$(basename "$imgurl")"
    date_prefix="$(date -d "today - $back day" +%F)"
    out="$SAVE_DIR/${date_prefix}_${fname}"

    # download
    if wget -q -O "$out" "$imgurl"; then
      log "Downloaded: $out"
      # set wallpaper
      set_wallpaper_gnome "$out"
      log "Wallpaper set to: $out"
      echo "OK: saved $out and set as wallpaper"
      return 0
    else
      log "Download failed for $imgurl. Trying earlier..."
    fi
  done

  log "ERROR: No suitable image found in last $max_back days."
  echo "ERROR: no suitable image found" >&2
  return 1
}

main "$@"

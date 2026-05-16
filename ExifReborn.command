#!/bin/bash

# ANSI barvy
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear

echo "=================================================="
echo "     ExifReborn for WhatsApp & iMazing            "
echo "=================================================="
echo

# Kontrola exiftool
if ! command -v exiftool >/dev/null 2>&1; then
  echo -e "${RED}❌ exiftool není nainstalovaný.${NC}"
  echo
  echo "Instalace přes Homebrew:"
  echo "brew install exiftool"
  echo
  exit 1
fi

# Pracovní složka
FOLDER="$(cd "$(dirname "$0")" && pwd)"

DONE="$FOLDER/DONE"
ERROR="$FOLDER/ERROR"

mkdir -p "$DONE"
mkdir -p "$ERROR"

echo "📂 Pracovní složka:"
echo "$FOLDER"
echo

# GPS dotaz
read -rp "Chceš přidat GPS lokaci? [a/n]: " add_gps

if [[ "$add_gps" =~ ^[Aa]$ ]]; then
  read -rp "GPS Latitude (např. 50.0755): " gps_lat
  read -rp "Latitude Ref (N/S): " gps_lat_ref
  read -rp "GPS Longitude (např. 14.4378): " gps_lon
  read -rp "Longitude Ref (E/W): " gps_lon_ref
  USE_GPS=true
else
  USE_GPS=false
fi

echo
echo "=================================================="

success=0
fail=0
total=0

process_file() {

  local file="$1"
  local filename
  filename=$(basename "$file")

  local ext
  ext="${filename##*.}"
  ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

  datetime=""
  new_name="$filename"

  #
  # iMazing format:
  # 2023-07-29 10 17 23 - P K - IMG_0545.heic
  #
  if [[ "$filename" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})[[:space:]]([0-9]{2})[[:space:]]([0-9]{2})[[:space:]]([0-9]{2}) ]]; then

    year=${BASH_REMATCH[1]}
    month=${BASH_REMATCH[2]}
    day=${BASH_REMATCH[3]}
    hour=${BASH_REMATCH[4]}
    minute=${BASH_REMATCH[5]}
    second=${BASH_REMATCH[6]}

    datetime="${year}:${month}:${day} ${hour}:${minute}:${second}"

    # pokus o obnovení původního názvu
    original=$(echo "$filename" | sed -E 's/^.* - ([^ ]+\.[A-Za-z0-9]+)$/\1/')

    if [[ "$original" != "$filename" ]]; then
      new_name="$original"
    fi

  #
  # WhatsApp / PHOTO / VIDEO format
  #
  elif [[ "$filename" =~ (PHOTO|VIDEO)-([0-9]{4})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2}) ]]; then

    year=${BASH_REMATCH[2]}
    month=${BASH_REMATCH[3]}
    day=${BASH_REMATCH[4]}
    hour=${BASH_REMATCH[5]}
    minute=${BASH_REMATCH[6]}
    second=${BASH_REMATCH[7]}

    datetime="${year}:${month}:${day} ${hour}:${minute}:${second}"
  fi

  #
  # Datum nenalezeno
  #
  if [[ -z "$datetime" ]]; then
    echo -e "${RED}❌ Nelze rozpoznat datum:${NC} $filename"
    mv "$file" "$ERROR/" 2>/dev/null
    ((fail++))
    return
  fi

  echo
  echo -e "${YELLOW}⏱ Nastavuji:${NC} $datetime"
  echo "$filename"

  #
  # GPS argumenty
  #
  if [[ "$USE_GPS" = true ]]; then
    gps_args=(
      -GPSLatitude="$gps_lat"
      -GPSLatitudeRef="$gps_lat_ref"
      -GPSLongitude="$gps_lon"
      -GPSLongitudeRef="$gps_lon_ref"
    )
  else
    gps_args=()
  fi

  #
  # FOTO
  #
  if [[ "$ext" =~ ^(jpg|jpeg|png|heic|heif|webp|tiff)$ ]]; then

    exiftool -overwrite_original \
      -P \
      -DateTimeOriginal="$datetime" \
      -CreateDate="$datetime" \
      -ModifyDate="$datetime" \
      -FileModifyDate="$datetime" \
      -ImageDescription="Taken from WhatsApp, fixed with ExifReborn" \
      "${gps_args[@]}" \
      "$file"

  #
  # VIDEO
  #
  elif [[ "$ext" =~ ^(mp4|mov|avi|mkv|mts)$ ]]; then

    exiftool -overwrite_original \
      -P \
      -CreateDate="$datetime" \
      -ModifyDate="$datetime" \
      -TrackCreateDate="$datetime" \
      -TrackModifyDate="$datetime" \
      -MediaCreateDate="$datetime" \
      -MediaModifyDate="$datetime" \
      -FileModifyDate="$datetime" \
      "$file"

  else
    echo -e "${RED}❌ Nepodporovaný soubor:${NC} $filename"
    mv "$file" "$ERROR/" 2>/dev/null
    ((fail++))
    return
  fi

  #
  # macOS Finder datum vytvoření
  #
  touch -t "$(date -j -f "%Y:%m:%d %H:%M:%S" "$datetime" +"%Y%m%d%H%M.%S")" "$file"

  #
  # Přejmenování
  #
  if [[ "$new_name" != "$filename" ]]; then

    target="$(dirname "$file")/$new_name"

    if [[ ! -e "$target" ]]; then
      mv "$file" "$target"
      file="$target"
      echo -e "${GREEN}📝 Obnoven původní název:${NC} $new_name"
    fi
  fi

  #
  # Přesun do DONE
  #
  mv "$file" "$DONE/" 2>/dev/null

  echo -e "${GREEN}✅ Hotovo${NC}"

  ((success++))
}

export -f process_file

#
# Hledání souborů
#
while IFS= read -r file; do

  if [[ "$file" == "$DONE"* ]] || [[ "$file" == "$ERROR"* ]]; then
    continue
  fi

  ((total++))

  process_file "$file"

done < <(find "$FOLDER" -type f \( \
  -iname "*.jpg" -o \
  -iname "*.jpeg" -o \
  -iname "*.png" -o \
  -iname "*.heic" -o \
  -iname "*.heif" -o \
  -iname "*.webp" -o \
  -iname "*.tiff" -o \
  -iname "*.mp4" -o \
  -iname "*.mov" -o \
  -iname "*.avi" -o \
  -iname "*.mkv" -o \
  -iname "*.mts" \
\))

echo
echo "=================================================="
echo "📊 SOUHRN"
echo "=================================================="
echo -e "${GREEN}Úspěšně:${NC} $success"
echo -e "${RED}Chyby:${NC} $fail"
echo "Celkem: $total"
echo "=================================================="
echo

echo "⚠️ Pokud Finder stále ukazuje dnešní datum:"
echo "macOS může blokovat změnu creation date."
echo
echo "Povol Terminalu Full Disk Access:"
echo "Nastavení systému → Soukromí a zabezpečení → Úplný přístup k disku"
echo

read -rp "Stiskni ENTER pro ukončení..."
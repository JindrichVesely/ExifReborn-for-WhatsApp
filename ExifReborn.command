#!/bin/bash

# ANSI barvy
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logo
clear
echo "=================================================="
echo "           ExifReborn for WhatsApp                "
echo "              by JindrichVesely                   "
echo "=================================================="
echo
echo

# Kontrola exiftool
if ! command -v exiftool >/dev/null 2>&1; then
  echo -e "${RED}❌ exiftool není nainstalovaný.${NC}"
  echo "Navštiv https://exiftool.org nebo použij:"
  echo "  brew install exiftool  (pokud máš Homebrew)"
  exit 1
fi

# 📂 Pracovní složka = aktuální adresář skriptu
FOLDER="$(cd "$(dirname "$0")" && pwd)"
echo "Složka: $FOLDER"

# Dotaz na GPS lokaci
read -rp "Chceš přidat GPS lokaci do EXIFu? [a/n]: " add_gps

if [[ "$add_gps" =~ ^[Aa]$ ]]; then
  read -rp "Zadej zeměpisnou šířku (např. 50.0755): " gps_lat
  read -rp "Směr šířky (N/S): " gps_lat_ref
  read -rp "Zadej zeměpisnou délku (např. 14.4378): " gps_lon
  read -rp "Směr délky (E/W): " gps_lon_ref
  USE_GPS=true
else
  USE_GPS=false
fi

# Pomocné složky
DONE="$FOLDER/Done"
ERROR="$FOLDER/Error"

# Statistiky pomocí dočasného souboru
TMPFILE="/tmp/exifreborn_$$.tmp"
echo "0 0 0" > "$TMPFILE"  # total success fail

# Přípony
EXTENSIONS="\( -iname \"*.jpg\" -o -iname \"*.jpeg\" -o -iname \"*.png\" -o -iname \"*.heic\" -o -iname \"*.heif\" -o -iname \"*.webp\" -o -iname \"*.tiff\" -o -iname \"*.mp4\" -o -iname \"*.mov\" -o -iname \"*.avi\" -o -iname \"*.mkv\" -o -iname \"*.mts\" \)"

# Zpracování souborů
eval find "\"$FOLDER\"" -type f $EXTENSIONS ! -path "\"$DONE/*\"" ! -path "\"$ERROR/*\"" | while read -r file; do
  read total success fail < "$TMPFILE"
  ((total++))
  filename=$(basename "$file")

  if [[ "$filename" =~ (PHOTO|VIDEO)-([0-9]{4})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2}) ]]; then
    year=${BASH_REMATCH[2]}
    month=${BASH_REMATCH[3]}
    day=${BASH_REMATCH[4]}
    hour=${BASH_REMATCH[5]}
    minute=${BASH_REMATCH[6]}
    second=${BASH_REMATCH[7]}
    datetime="$year:$month:$day $hour:$minute:$second"

    ext="${file##*.}"
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    # GPS argumenty
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

    if [[ "$ext_lower" =~ ^(jpg|jpeg|png|heic|heif|webp|tiff)$ ]]; then
      exiftool -overwrite_original \
        -DateTimeOriginal="$datetime" \
        -CreateDate="$datetime" \
        -ImageDescription="Taken from WhatsApp, fixed with ExifReborn" \
        "${gps_args[@]}" \
        "$file"
    elif [[ "$ext_lower" =~ ^(mp4|mov|avi|mkv|mts)$ ]]; then
      exiftool -overwrite_original \
        -MediaCreateDate="$datetime" \
        -CreateDate="$datetime" \
        -ModifyDate="$datetime" \
        "$file"
    else
      echo -e "${RED}❌ Nepodporovaný typ: $filename${NC}"
      mkdir -p "$ERROR"
      mv "$file" "$ERROR/"
      ((fail++))
      echo "$total $success $fail" > "$TMPFILE"
      continue
    fi

    if [[ $? -eq 0 ]]; then
      mkdir -p "$DONE"
      mv "$file" "$DONE/"
      echo -e "${GREEN}✅ Zpracováno: $filename${NC}"
      ((success++))
    else
      mkdir -p "$ERROR"
      mv "$file" "$ERROR/"
      echo -e "${RED}❌ Chyba při zpracování: $filename${NC}"
      ((fail++))
    fi
  else
    echo -e "${RED}⚠️ Neplatný název (žádné datum): $filename${NC}"
    mkdir -p "$ERROR"
    mv "$file" "$ERROR/"
    ((fail++))
  fi

  echo "$total $success $fail" > "$TMPFILE"
done

# Výpis souhrnu
read total success fail < "$TMPFILE"
rm -f "$TMPFILE"

if (( total > 0 )); then
  percent_success=$((success * 100 / total))
  percent_fail=$((fail * 100 / total))
else
  percent_success=0
  percent_fail=0
fi

echo
echo "================== 🔚 SOUHRN =================="
echo -e " Celkem nalezeno:    ${total}"
echo -e "${GREEN} Úspěšně zpracováno: ${success} (${percent_success}%)${NC}"
echo -e "${RED} Chybných:           ${fail} (${percent_fail}%)${NC}"
echo "=============================================="

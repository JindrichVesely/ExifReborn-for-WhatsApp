# ExifReborn for WhatsApp

An automatic tool to fix EXIF metadata (date, time, and optionally GPS coordinates) in photos and videos downloaded from WhatsApp.  
Restores original metadata overwritten by WhatsApp during media downloads.

---

## Features

- Automatically parses date and time from file names  
- Edits EXIF metadata for photos and media creation dates for videos  
- Supports common photo and video formats:  
  - Photos: `.jpg`, `.jpeg`, `.png`, `.heic`, `.heif`, `.webp`, `.tiff`  
  - Videos: `.mp4`, `.mov`, `.avi`, `.mkv`, `.mts`  
- Color-coded terminal output for success and error  
- Automatically moves processed files to `Done/` folder  
- Moves failed files to `Error/` folder for easy review  
- Optional GPS geotagging support  
- Summary report at the end with counts of successes and failures

---

## Requirements

- macOS or Linux (with minor path adjustments)  
- [ExifTool](https://exiftool.org) installed and available in your PATH

On macOS, install via Homebrew:

```bash
brew install exiftool

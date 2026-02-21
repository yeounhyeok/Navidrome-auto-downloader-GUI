#!/bin/bash

# --- [Navidrome Configuration] ---
# Read from environment variables (injected via Docker Compose)
ND_URL="${ND_URL}"
ND_USER="${ND_USER}"
ND_PASS="${ND_PASS}"
# ---------------------------------

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 \"Folder_Name\" \"Youtube_URL\""
    exit 1
fi

FOLDER_NAME="$1"
URL=$(echo "$2" | sed 's/\\//g')
# Mount path inside Docker (Default value)
BASE_DIR="${BASE_DIR:-/music}"
TARGET_DIR="$BASE_DIR/$FOLDER_NAME"

echo "------------------------------------------"
echo "Process Start: $FOLDER_NAME"

# Save URL to a file for future updates
mkdir -p "$TARGET_DIR"
echo "$URL" > "$TARGET_DIR/playlist_url.txt"

# 1~3. Download Logic
# No sudo needed as it runs as root inside Docker
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || exit
yt-dlp -x --audio-format mp3 --audio-quality 0 \
    --embed-metadata --embed-thumbnail --convert-thumbnails jpg \
    --download-archive "downloaded.txt" \
    --parse-metadata "playlist_index:%(track_number)s" \
    --replace-in-metadata "title" " \(?Official (Video|Audio|Music Video|M/V)\)?" "" \
    -o "%(playlist_index)s - %(title)s.%(ext)s" \
    "$URL"

# 4. Playlist & Permission
# Create m3u playlist
ls -1v *.mp3 2>/dev/null > "${FOLDER_NAME}.m3u"

# Set permissions (Might not be needed depending on Docker env, ignore on failure)
chown -R 1000:1000 "$TARGET_DIR" 2>/dev/null || true
chmod -R 755 "$TARGET_DIR" 2>/dev/null || true

# 5. Navidrome API Rescan Request
echo "Sending Rescan Request to Navidrome..."
# Generate auth parameters compliant with Subsonic API
SALT=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
TOKEN=$(echo -n "${ND_PASS}${SALT}" | md5sum | cut -d' ' -f1)

SCAN_URL="${ND_URL}/rest/startScan.view?u=${ND_USER}&t=${TOKEN}&s=${SALT}&v=1.16.1&c=yt-script"

# Call API (Discard output to /dev/null)
curl -s "$SCAN_URL" > /dev/null

if [ $? -eq 0 ]; then
    echo "Rescan triggered successfully!"
else
    echo "Failed to trigger rescan."
fi

echo "------------------------------------------"
echo "All tasks completed: $TARGET_DIR"

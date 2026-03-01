#!/bin/bash

# --- [Navidrome Configuration] ---
# Read from environment variables (injected via Docker Compose)
ND_URL="${ND_URL}"
ND_USER="${ND_USER}"
ND_PASS="${ND_PASS}"
# ---------------------------------

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 \"Folder_Name\" \"Youtube_URL\" [sync_delete]"
    exit 1
fi

FOLDER_NAME="$1"
URL=$(echo "$2" | sed 's/\\//g')
SYNC_DELETE="${3:-false}"
MIGRATE="${4:-false}"

# Migrate mode forces sync_delete on
if [ "$MIGRATE" = "true" ]; then
    SYNC_DELETE="true"
fi
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

# Migrate mode: rename old files using embedded YouTube ID, pre-register correct ones
if [ "$MIGRATE" = "true" ]; then
    echo "Smart migration: scanning playlist metadata..."
    rm -f downloaded.txt .id_map.txt

    SCAN_TMP=$(mktemp)
    yt-dlp \
        --skip-download \
        --replace-in-metadata "uploader" "(?i)\s*-\s*topic$" "" \
        --parse-metadata "title:(?P<artist>[^【】「」『』\[]+?)\s*[-–—]\s*(?P<title>.+)" \
        --parse-metadata "title:\[(?P<artist>[^\]]+)\]\s*(?P<title>.+)" \
        --parse-metadata "title:(?P<artist>[^「『\s][^「『]*?)\s*[「『](?P<title>[^」』]+)[」』]" \
        --parse-metadata "title:【(?P<artist>[^】]+)】\s*(?P<title>.+)" \
        --replace-in-metadata "title" "【[^】]*】" "" \
        --replace-in-metadata "title" "「[^」]*」" "" \
        --replace-in-metadata "title" "『[^』]*』" "" \
        --replace-in-metadata "title" "\s*[\(\[（【]\s*(?:Official\s+)?(?:Audio|Video|Music\s*Video|MV|M/V|Lyric\s*Video|Visualizer|Live|Official)\s*[\)\]）】]" "" \
        --replace-in-metadata "title" "^\s+" "" \
        --replace-in-metadata "title" "\s+$" "" \
        --print-to-file "%(id)s	%(artist,uploader)s - %(title)s.mp3" "$SCAN_TMP" \
        "$URL" 2>/dev/null

    echo "Matching existing files by embedded metadata (no re-download)..."
    python3 - "$SCAN_TMP" << 'PYEOF'
import sys, os, subprocess, json, re

scan_file = sys.argv[1]

# Load expected: video_id -> new_filename
id_map = {}
with open(scan_file) as f:
    for line in f:
        line = line.rstrip('\n')
        if '\t' in line:
            vid, fname = line.split('\t', 1)
            if vid:
                id_map[vid] = fname

pre_count = rename_count = 0

for mp3file in sorted(f for f in os.listdir('.') if f.endswith('.mp3')):
    # Read embedded metadata to find YouTube video ID
    result = subprocess.run(
        ['ffprobe', '-v', 'quiet', '-print_format', 'json', '-show_format', mp3file],
        capture_output=True, text=True
    )
    try:
        tags = json.loads(result.stdout).get('format', {}).get('tags', {})
    except Exception:
        continue

    vid = None
    for key in ['PURL', 'purl', 'comment', 'COMMENT', 'description']:
        match = re.search(r'(?:v=|youtu\.be/)([A-Za-z0-9_-]{11})', str(tags.get(key, '')))
        if match:
            vid = match.group(1)
            break

    if not vid or vid not in id_map:
        continue

    expected = id_map[vid]

    if mp3file == expected:
        print(f"  OK (kept): {mp3file}")
        pre_count += 1
    elif not os.path.exists(expected):
        os.rename(mp3file, expected)
        print(f"  Renamed: {mp3file}")
        print(f"      --> {expected}")
        rename_count += 1
    else:
        # New-name file already exists, old file will be cleaned as orphan
        continue

    with open('downloaded.txt', 'a') as af:
        af.write(f"youtube {vid}\n")
    with open('.id_map.txt', 'a') as af:
        af.write(f"{vid}\t{expected}\n")

print(f"Result: {pre_count} kept, {rename_count} renamed. Remaining will be downloaded.")
PYEOF

    rm -f "$SCAN_TMP"
fi
yt-dlp \
    -x \
    --audio-format mp3 \
    --audio-quality 0 \
    --embed-metadata \
    --embed-thumbnail \
    --convert-thumbnails jpg \
    --download-archive "downloaded.txt" \
    --add-metadata \
    --replace-in-metadata "uploader" "(?i)\s*-\s*topic$" "" \
    --parse-metadata "title:(?P<artist>[^【】「」『』\[]+?)\s*[-–—]\s*(?P<title>.+)" \
    --parse-metadata "title:\[(?P<artist>[^\]]+)\]\s*(?P<title>.+)" \
    --parse-metadata "title:(?P<artist>[^「『\s][^「『]*?)\s*[「『](?P<title>[^」』]+)[」』]" \
    --parse-metadata "title:【(?P<artist>[^】]+)】\s*(?P<title>.+)" \
    --replace-in-metadata "title" "【[^】]*】" "" \
    --replace-in-metadata "title" "「[^」]*」" "" \
    --replace-in-metadata "title" "『[^』]*』" "" \
    --replace-in-metadata "title" "\s*[\(\[（【]\s*(?:Official\s+)?(?:Audio|Video|Music\s*Video|MV|M/V|Lyric\s*Video|Visualizer|Live|Official)\s*[\)\]）】]" "" \
    --replace-in-metadata "title" "^\s+" "" \
    --replace-in-metadata "title" "\s+$" "" \
    --print-to-file "%(id)s	%(artist,uploader)s - %(title)s.mp3" ".id_map.txt" \
    -o "%(artist,uploader)s - %(title)s.%(ext)s" \
    "$URL"

# 4. Sync-delete: remove tracks no longer in the playlist
if [ "$SYNC_DELETE" = "true" ]; then
    echo ""
    echo "Checking for tracks removed from playlist..."

    CURRENT_IDS_FILE=$(mktemp)
    yt-dlp --flat-playlist --print "%(id)s" "$URL" 2>/dev/null > "$CURRENT_IDS_FILE"

    if [ -s "$CURRENT_IDS_FILE" ]; then
        deleted_count=0
        NEW_MAP=$(mktemp)

        # Process entries tracked in .id_map.txt
        if [ -f ".id_map.txt" ]; then
            while IFS="	" read -r video_id filename; do
                [ -z "$video_id" ] && continue
                if grep -qxF "$video_id" "$CURRENT_IDS_FILE"; then
                    printf '%s\t%s\n' "$video_id" "$filename" >> "$NEW_MAP"
                else
                    if [ -f "$filename" ]; then
                        rm "$filename"
                        echo "  Deleted: $filename"
                        deleted_count=$((deleted_count + 1))
                    else
                        echo "  WARNING: File not found on disk (skipped): $filename"
                    fi
                    grep -v "^youtube ${video_id}$" downloaded.txt > /tmp/_arch_$$.txt \
                        && mv /tmp/_arch_$$.txt downloaded.txt || true
                fi
            done < ".id_map.txt"
            mv "$NEW_MAP" .id_map.txt
        fi

        # Delete orphaned mp3 files: on disk but not in the kept id_map entries
        # Guard: only run if id_map exists, otherwise we have no info and cannot safely delete
        if [ -f ".id_map.txt" ] && [ -s ".id_map.txt" ]; then
            for mp3file in *.mp3; do
                [ -f "$mp3file" ] || continue
                if ! grep -qF "	${mp3file}" .id_map.txt 2>/dev/null; then
                    rm "$mp3file"
                    echo "  Deleted orphan: $mp3file"
                    deleted_count=$((deleted_count + 1))
                fi
            done
        fi

        echo "Sync complete: deleted ${deleted_count} removed track(s)."
    else
        echo "Failed to fetch playlist. Sync skipped."
    fi

    rm -f "$CURRENT_IDS_FILE"
fi

# 5. Playlist & Permission
# Create m3u playlist
ls -1v *.mp3 2>/dev/null > "${FOLDER_NAME}.m3u"

# Set permissions (Might not be needed depending on Docker env, ignore on failure)
chown -R 1000:1000 "$TARGET_DIR" 2>/dev/null || true
chmod -R 755 "$TARGET_DIR" 2>/dev/null || true

# 6. Navidrome API Rescan Request
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

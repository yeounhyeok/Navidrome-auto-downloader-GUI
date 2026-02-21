#!/bin/bash

# --- [Navidrome Configuration] ---
# 환경변수에서 읽어옴 (Docker Compose에서 주입)
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
# Docker 내부 마운트 경로 (기본값)
BASE_DIR="${BASE_DIR:-/music}"
TARGET_DIR="$BASE_DIR/$FOLDER_NAME"

echo "------------------------------------------"
echo "Process Start: $FOLDER_NAME"

# 1~3. 다운로드 로직
# Docker 내부에서는 보통 root로 실행되므로 sudo 제거
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
# m3u 생성
ls -1v *.mp3 2>/dev/null > "${FOLDER_NAME}.m3u"

# 권한 설정 (Docker 환경에 따라 필요 없을 수 있음, 실패시 무시)
chown -R 1000:1000 "$TARGET_DIR" 2>/dev/null || true
chmod -R 755 "$TARGET_DIR" 2>/dev/null || true

# 5. Navidrome API Rescan Request
echo "Sending Rescan Request to Navidrome..."
# Subsonic API 규격에 맞는 인증 파라미터 생성
SALT=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
TOKEN=$(echo -n "${ND_PASS}${SALT}" | md5sum | cut -d' ' -f1)

SCAN_URL="${ND_URL}/rest/startScan.view?u=${ND_USER}&t=${TOKEN}&s=${SALT}&v=1.16.1&c=yt-script"

# API 호출 (결과는 /dev/null로 버림)
curl -s "$SCAN_URL" > /dev/null

if [ $? -eq 0 ]; then
    echo "Rescan triggered successfully!"
else
    echo "Failed to trigger rescan."
fi

echo "------------------------------------------"
echo "All tasks completed: $TARGET_DIR"

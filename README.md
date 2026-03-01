# Navidrome Auto Downloader GUI 🎵

이 프로젝트는 [Navidrome](https://www.navidrome.org/) 사용자를 위한 **자동 음악 다운로드 및 라이브러리 스캔 도구**입니다.
웹 인터페이스(GUI)를 통해 YouTube / YouTube Music의 앨범·플레이리스트 URL을 입력하고, 음악을 다운로드한 후 Navidrome 서버에 자동으로 스캔 요청을 보낼 수 있습니다.

This project is an **automated music downloader and library scanner** for [Navidrome](https://www.navidrome.org/) users.
Users can easily input a YouTube (or YouTube Music) album/playlist URL via a web interface (GUI), download the music, and automatically send a scan request to the Navidrome server.

---

## 🏗️ Architecture

이 시스템은 Docker 컨테이너 내에서 Flask 웹 서버와 Shell Script를 결합하여 동작합니다.

The system operates by combining a Flask web server and Shell Script within a Docker container.

```ascii
+----------------+      +-------------------------+      +----------------------+
|  User Browser  | <--> |   Docker Container      | <--> |  External Services   |
+----------------+      | (Web App + Downloader)  |      +----------------------+
| - Input Form   |      | +---------------------+ |      | - YouTube (Download) |
| - Log Viewer   |      | | Python Web Server   | |      |                      |
|                |      | | (Flask App)         | |      | - Navidrome API      |
+----------------+      | +----------+----------+ |      |   (Rescan)           |
                        |            |            |      +----------------------+
                        |            v            |
                        | +---------------------+ |      +----------------------+
                        | | Shell Script        | |      |  Host Volume Mount   |
                        | | (download_music.sh) | | ---> | /mnt/usb/media/Musics|
                        | +----------+----------+ |      +----------------------+
                        |            |            |
                        |            v            |
                        | +---------------------+ |
                        | | Tools: yt-dlp,      | |
                        | | ffmpeg, curl        | |
                        | +---------------------+ |
                        +-------------------------+
```

---

## ✨ Features

### 기본 기능 (Core)

1. **스마트 폴더 관리 (Smart Folder Management)**
   - 마운트된 볼륨을 스캔해 기존 폴더를 드롭다운으로 제공
   - 폴더 선택 시 이전에 사용한 YouTube URL 자동 입력 및 잠금

2. **고급 메타데이터 추출 (Advanced Metadata Extraction)**
   - `【Artist】Title`, `Artist - Title`, `Artist「Title」`, `[Artist] Title` 등 다양한 유튜브 제목 형식 자동 파싱
   - YouTube Music **Topic 채널** 자동 인식 (`pt. adamzik - Topic` → `pt. adamzik`)
   - Official Audio/Video, MV 등 불필요한 suffix 자동 제거
   - 파일명: `아티스트 - 제목.mp3`

3. **중복 방지 (Duplicate Prevention)**
   - `downloaded.txt` 아카이브로 이미 받은 곡 스킵
   - 같은 URL로 재실행하면 새로 추가된 곡만 다운로드

4. **플레이리스트 & 라이브러리 갱신 (Playlist & Rescan)**
   - `.m3u` 파일 자동 생성
   - 완료 후 Navidrome API 자동 스캔 요청

### 추가 기능 (Advanced)

5. **삭제 동기화 (Sync Delete)**
   - 체크박스 활성화 시, 유튜브 재생목록에서 제거된 곡을 로컬에서도 자동 삭제
   - `.id_map.txt`로 video ID ↔ 파일명 추적
   - `.id_map.txt` 없을 경우 삭제 보호 (안전 가드)

6. **스마트 마이그레이션 (Smart Migration)**
   - 구형식 파일명(`001 - 【제목】.mp3` 등)을 **재다운로드 없이** 새 형식으로 자동 변환
   - mp3에 임베딩된 YouTube URL(`PURL` ID3 태그)을 `ffprobe`로 읽어 video ID 추출 → 매핑 → 이름 변경
   - 이미 올바른 이름의 파일은 유지, 없거나 이름이 바뀐 곡만 새로 다운로드
   - 구형식 고아 파일 자동 정리

---

## 🚀 Getting Started

### Prerequisites

- [Docker](https://www.docker.com/) & [Docker Compose](https://docs.docker.com/compose/)

### Installation & Run

#### Option 1: Use Docker Image (Recommended)

별도의 빌드 과정 없이 GitHub Container Registry에 올라온 이미지를 바로 사용할 수 있습니다.

You can use the image directly from the GitHub Container Registry without building it yourself.

1. **`docker-compose.yml` 작성 (Create `docker-compose.yml`)**
   ```yaml
   services:
     navidrome-downloader:
       image: ghcr.io/yeounhyeok/navidrome-auto-downloader-gui:latest
       container_name: navidrome-downloader
       ports:
         - "5000:5000"
       volumes:
         - /path/to/your/music:/music
       env_file:
         - .env
       restart: unless-stopped
   ```

2. **환경 변수 설정 (Configure Environment Variables)**

   `.env.example` 파일을 복사하여 `.env`를 생성하고 Navidrome 정보를 입력하세요.

   ```bash
   wget https://raw.githubusercontent.com/yeounhyeok/Navidrome-auto-downloader-GUI/main/.env.example -O .env
   vi .env
   ```

3. **실행 (Run)**
   ```bash
   docker-compose up -d
   ```

4. **업데이트 (Update)**
   ```bash
   docker-compose pull
   docker-compose up -d
   docker image prune -f
   ```

#### Option 2: Build Manually (Developer)

1. **클론 (Clone)**
   ```bash
   git clone https://github.com/yeounhyeok/Navidrome-auto-downloader-GUI.git
   cd Navidrome-auto-downloader-GUI
   ```

2. **환경 설정 (Configuration)**
   ```bash
   cp .env.example .env
   vi .env
   ```

3. **실행 (Run)**
   ```bash
   docker-compose up --build -d
   ```

4. **접속 (Access)**

   웹 브라우저에서 `http://localhost:5000`으로 접속합니다.

---

## 📝 Usage

### 기본 다운로드

1. **Folder Name**: 드롭다운에서 기존 폴더 선택, 또는 `-- Create New Folder --` 선택 후 이름 입력
2. **YouTube URL**: 다운로드할 유튜브 동영상/재생목록 URL 입력 (기존 폴더는 자동 입력)
3. **Start Download**: 클릭 후 하단 로그 창에서 진행 상황 확인
4. 완료 시 Navidrome 라이브러리 자동 갱신

### 삭제 동기화

- **"재생목록에서 제거된 곡을 로컬에서도 삭제"** 체크박스를 켜고 다운로드 실행
- 재생목록에서 빠진 곡의 mp3 파일과 m3u 항목이 자동 제거됨
- 처음 사용 시 `.id_map.txt` 추적 파일이 생성되며, 이후 실행부터 완전 동작

### 스마트 마이그레이션

구형식 파일명(예: `001 - 【Ado】ビバリウム（Official Audio）.mp3`)을 최신 형식으로 변환:

1. 폴더 선택 후 **"스마트 마이그레이션"** 버튼 클릭
2. 확인 후 자동 실행:
   - mp3에 임베딩된 YouTube ID를 읽어 이름 변경 (재다운로드 없음)
   - 이미 올바른 이름의 파일은 유지
   - 변환 불가한 파일은 재다운로드
   - 구형식 파일은 자동 삭제

---

## 📁 폴더 내부 구조 (Directory Structure)

다운로드 완료 후 각 음악 폴더는 다음과 같이 구성됩니다:

```
/music/
└── artist-name/
    ├── Artist - Track Title.mp3     # 음악 파일
    ├── artist-name.m3u              # 플레이리스트
    ├── playlist_url.txt             # 재실행을 위한 URL 저장
    ├── downloaded.txt               # yt-dlp 다운로드 아카이브
    └── .id_map.txt                  # video ID ↔ 파일명 추적 (삭제 동기화용)
```

---

## 🛠️ Tech Stack

- **Backend**: Python 3.11 (Flask)
- **Frontend**: HTML5, JavaScript (Fetch API, SSE)
- **Core Tools**: Bash, yt-dlp, ffmpeg, curl
- **Infrastructure**: Docker (Alpine Linux)

## 📄 License

MIT License

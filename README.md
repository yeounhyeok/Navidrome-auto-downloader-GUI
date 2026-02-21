# Navidrome Auto Downloader GUI 🎵

이 프로젝트는 [Navidrome](https://www.navidrome.org/) 사용자를 위한 **자동 음악 다운로드 및 라이브러리 스캔 도구**입니다.
사용자는 웹 인터페이스(GUI)를 통해 간편하게 YouTube(또는 YouTube Music)의 앨범/플레이리스트 URL을 입력하고, 음악을 다운로드한 후 Navidrome 서버에 자동으로 스캔 요청을 보낼 수 있습니다.

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

## ✨ Features (Pipeline)

이 프로젝트의 핵심 로직은 `download_music.sh` 스크립트에 있으며, 다음과 같은 5단계 파이프라인으로 동작합니다:
The core logic of this project lies in the `download_music.sh` script, which operates in a 5-step pipeline:

1. **입력 및 준비 (Input & Preparation)**:
   - 사용자로부터 **폴더명(앨범/아티스트)**과 **YouTube URL(플레이리스트 또는 단일 곡)**을 입력받습니다.
   - Receives **Folder Name (Album/Artist)** and **YouTube URL (Playlist or Single Track)** from the user.

2. **경로 자동 설정 (Auto Path Configuration)**:
   - Navidrome이 마운트된 경로(`BASE_DIR`) 하위에 지정한 폴더명으로 디렉토리를 생성하고 이동합니다.
   - Creates a directory with the specified folder name under the path where Navidrome is mounted (`BASE_DIR`) and navigates to it.

3. **지능형 다운로드 & 태깅 (Intelligent Download & Tagging with `yt-dlp`)**:
   - 고음질 MP3로 추출하며, 앨범 아트(썸네일)와 메타데이터를 자동으로 삽입합니다.
   - Extracts high-quality MP3s and automatically embeds album art (thumbnails) and metadata.
   - 트랙 번호, 아티스트 정보 등을 깔끔하게 정리하여 Navidrome이 완벽하게 인식하도록 돕습니다.
   - Cleanly organizes track numbers, artist info, etc., ensuring perfect recognition by Navidrome.

4. **플레이리스트 생성 (Playlist Creation - `.m3u`)**:
   - 다운로드된 파일들을 기반으로 `.m3u` 플레이리스트 파일을 자동으로 생성합니다.
   - Automatically generates an `.m3u` playlist file based on the downloaded files.
   - Navidrome에서 별도의 설정 없이 바로 플레이리스트로 인식됩니다.
   - Recognized immediately as a playlist in Navidrome without additional configuration.

5. **Navidrome 자동 갱신 (Navidrome Auto Rescan)**:
   - 모든 작업이 완료되면 Navidrome API를 호출하여 라이브러리 스캔(Rescan)을 요청합니다.
   - Calls the Navidrome API to request a library scan (Rescan) once all tasks are completed.
   - 사용자는 별도로 '새로고침'을 누를 필요 없이 즉시 추가된 음악을 감상할 수 있습니다.
   - Users can enjoy the added music immediately without needing to manually refresh.

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
       # Load environment variables from .env file
       env_file:
         - .env
       restart: unless-stopped
   ```

2. **환경 변수 설정 (Configure Environment Variables)**
   `.env.example` 파일을 복사하여 `.env` 파일을 생성하고, 본인의 Navidrome 정보를 입력하세요.
   Copy the `.env.example` file to `.env` and fill in your Navidrome details.

   ```bash
   # Download .env.example if you don't have the repo
   wget https://raw.githubusercontent.com/yeounhyeok/Navidrome-auto-downloader-GUI/main/.env.example -O .env
   
   # Edit .env file
   vi .env
   ```

3. **실행 (Run)**
   ```bash
   docker-compose up -d
   ```

#### Option 2: Build Manually (Developer)

1. **리포지토리 클론 (Clone Repository)**
   ```bash
   git clone https://github.com/yeounhyeok/Navidrome-auto-downloader-GUI.git
   cd Navidrome-auto-downloader-GUI
   ```

2. **환경 설정 (Configuration)**
   `.env.example` 파일을 `.env`로 복사하여 설정을 완료하세요.
   Copy `.env.example` to `.env` and configure your settings.

   ```bash
   cp .env.example .env
   vi .env
   ```

   `docker-compose.yml`에서 볼륨 경로를 수정하세요.
   Modify volume paths in `docker-compose.yml`.

   ```yaml
   volumes:
     - /path/to/your/music:/music
   ```

3. **실행 (Run)**
   ```bash
   docker-compose up --build -d
   ```

4. **접속 (Access)**
   웹 브라우저에서 `http://localhost:5000`으로 접속합니다.
   Access `http://localhost:5000` in your web browser.

---

## 📝 Usage

1. **Folder Name**: 앨범이나 아티스트 이름을 입력합니다. (예: `NewJeans - Get Up`)
   - Enter the album or artist name. This will be the folder name.
2. **YouTube URL**: 다운로드할 YouTube 동영상 또는 재생목록 URL을 입력합니다.
   - Enter the YouTube video or playlist URL to download.
3. **Start Download**: 버튼을 누르면 다운로드가 시작되며, 하단 로그 창에서 진행 상황을 확인할 수 있습니다.
   - Click the button to start downloading. You can check the progress in the log window below.
4. 완료되면 `Process finished` 메시지가 뜨고, Navidrome에서 자동으로 라이브러리가 갱신됩니다.
   - Once completed, a `Process finished` message appears, and the Navidrome library is automatically updated.

---

## 🛠️ Tech Stack

- **Backend**: Python (Flask)
- **Frontend**: HTML5, JavaScript (Fetch API for streaming logs)
- **Core Tools**: Bash Script, yt-dlp, ffmpeg, curl
- **Infrastructure**: Docker

## 📄 License

MIT License

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
   - **폴더 관리 (Folder Management)**: 마운트된 볼륨을 자동으로 스캔하여 기존 폴더 목록을 드롭다운으로 제공합니다. 새 폴더를 생성하거나 기존 폴더를 선택할 수 있습니다.
   - **스마트 URL (Smart URL Recall)**: 기존 폴더를 선택하면 이전에 사용했던 YouTube URL이 자동으로 입력되고 잠금 처리되어, 실수 없이 간편하게 업데이트할 수 있습니다.
   - **Folder Management**: Scans mounted volumes to provide a dropdown of existing folders. You can create a new folder or select an existing one.
   - **Smart URL Recall**: Selecting an existing folder automatically fills and locks the previously used YouTube URL, ensuring error-free updates.

2. **자동화 파이프라인 (Automated Pipeline)**
   - **경로 생성 (Path Creation)**: Navidrome 마운트 경로에 자동으로 폴더를 생성합니다.
   - **메타데이터 (Metadata)**: `yt-dlp`를 사용하여 썸네일, 아티스트, 앨범 정보를 임베딩합니다.
   - **중복 방지 (Duplicate Prevention)**: `downloaded.txt` 파일에 다운로드 기록을 저장하여, 이미 받은 곡은 건너뛰고 새로운 곡만 다운로드합니다. 따라서 유튜브 플레이리스트에 곡이 추가되었을 때, 동일한 URL로 다시 실행하면 **추가된 곡만 자동으로 다운로드**됩니다.
   - **플레이리스트 (Playlist)**: `.m3u` 파일을 자동 생성하여 Navidrome에서 즉시 인식 가능합니다.
   - **라이브러리 갱신 (Rescan)**: 작업 완료 후 Navidrome API를 호출하여 라이브러리를 자동 스캔합니다.

   - **Path Creation**: Automatically creates folders in the Navidrome mount path.
   - **Metadata**: Uses `yt-dlp` to embed thumbnails, artist, and album info.
   - **Duplicate Prevention**: Records download history in `downloaded.txt` to skip already downloaded tracks. You can simply re-run the same playlist URL to **download only the newly added tracks**.
   - **Playlist**: Automatically generates `.m3u` files for instant Navidrome recognition.
   - **Rescan**: Triggers a Navidrome library scan via API upon completion.

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

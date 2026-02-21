# Navidrome Auto Downloader GUI 🎵

이 프로젝트는 [Navidrome](https://www.navidrome.org/) 사용자를 위한 **자동 음악 다운로드 및 라이브러리 스캔 도구**입니다.

사용자는 웹 인터페이스(GUI)를 통해 간편하게 YouTube(또는 YouTube Music)의 앨범/플레이리스트 URL을 입력하고, 음악을 다운로드한 후 Navidrome 서버에 자동으로 스캔 요청을 보낼 수 있습니다.

---

## 🏗️ Architecture

이 시스템은 Docker 컨테이너 내에서 Flask 웹 서버와 Shell Script를 결합하여 동작합니다.

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

## ✨ Features

- **웹 기반 GUI**: 복잡한 터미널 명령어 없이 브라우저에서 간편하게 조작
- **고음질 다운로드**: `yt-dlp`를 사용하여 YouTube에서 고음질 오디오 추출 (MP3)
- **메타데이터 자동 정리**: 앨범 아트, 트랙 번호, 아티스트 정보 등을 자동으로 태깅
- **Navidrome 연동**: 다운로드 완료 후 Navidrome 서버에 자동으로 스캔 요청 전송 (Subsonic API)
- **실시간 로그**: 다운로드 진행 상황을 웹 화면에서 실시간으로 확인 가능
- **Docker 지원**: `docker-compose`를 통해 간편하게 배포 및 실행

---

## 🚀 Getting Started

### Prerequisites

- [Docker](https://www.docker.com/) & [Docker Compose](https://docs.docker.com/compose/)

### Installation & Run

1. **리포지토리 클론**
   ```bash
   git clone https://github.com/yeounhyeok/Navidrome-auto-downloader-GUI.git
   cd Navidrome-auto-downloader-GUI
   ```

2. **환경 설정 (`docker-compose.yml`)**
   `docker-compose.yml` 파일을 열어 Navidrome 접속 정보와 볼륨 경로를 수정하세요.
   ```yaml
   environment:
     - ND_URL=http://10.0.1.1:4533      # Navidrome 주소
     - ND_USER=your_username            # Navidrome 사용자 ID
     - ND_PASS=your_password            # Navidrome 비밀번호
     - BASE_DIR=/music                  # 컨테이너 내부 음악 저장 경로
   volumes:
     - /path/to/your/music:/music       # 호스트의 실제 음악 폴더 경로
   ```

3. **실행**
   ```bash
   docker-compose up --build -d
   ```

4. **접속**
   웹 브라우저에서 `http://localhost:5000`으로 접속합니다.

---

## 📝 Usage

1. **Folder Name**: 앨범이나 아티스트 이름을 입력합니다. (예: `NewJeans - Get Up`)
   - 이 이름으로 폴더가 생성됩니다.
2. **YouTube URL**: 다운로드할 YouTube 동영상 또는 재생목록 URL을 입력합니다.
3. **Start Download**: 버튼을 누르면 다운로드가 시작되며, 하단 로그 창에서 진행 상황을 확인할 수 있습니다.
4. 완료되면 `Process finished` 메시지가 뜨고, Navidrome에서 자동으로 라이브러리가 갱신됩니다.

---

## 🛠️ Tech Stack

- **Backend**: Python (Flask)
- **Frontend**: HTML5, JavaScript (Fetch API for streaming logs)
- **Core Tools**: Bash Script, yt-dlp, ffmpeg, curl
- **Infrastructure**: Docker

## 📄 License

MIT License

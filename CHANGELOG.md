# Changelog

## [Unreleased]

### 🐳 Infrastructure
- **Docker 이미지 경량화**: `python:3.11-slim` (Debian) → `python:3.11-alpine` 전환
  - `atomicparsley` 제거 (mp3 썸네일은 ffmpeg가 직접 처리)
  - 예상 이미지 크기: ~1GB → ~350MB
- `bash`, `coreutils` 명시적 설치 (alpine 호환성)

### 🎵 메타데이터 추출 개선 (Metadata Extraction)
- 다양한 유튜브 제목 형식 자동 파싱 지원:
  - `【Artist】Title` (일본어 이중꺾쇠)
  - `Artist - Title` / `Artist – Title` / `Artist — Title` (dash 3종)
  - `[Artist] Title` (ASCII 대괄호)
  - `Artist「Title」` / `Artist『Title』` (일본어 낫표)
- **YouTube Music Topic 채널** 자동 처리: `pt. adamzik - Topic` → `pt. adamzik`
  - 기존: `--parse-metadata "uploader:%(artist)s"` 가 YouTube Music의 기본 artist 메타데이터를 덮어쓰는 문제 수정
  - 변경: `--replace-in-metadata "uploader" "(?i)\s*-\s*topic$" ""` 로 uploader 정리만 수행
- 제목에서 불필요한 suffix 제거 패턴 확장:
  - `(Official Audio/Video/MV/M/V/Lyric Video/Visualizer/Live)` — 소/대괄호, 전각괄호 모두 대응
- 파일명 형식 변경: `%(playlist_index)s - %(title)s` → `%(artist,uploader)s - %(title)s`
  - `%(artist,uploader)s`: artist가 비어있으면 uploader로 자동 fallback

### 🔄 삭제 동기화 기능 추가 (Sync Delete)
- **UI**: "재생목록에서 제거된 곡을 로컬에서도 삭제" 체크박스 추가 (기본: 해제)
- **동작**:
  - 다운로드 완료 후 `--flat-playlist`로 현재 재생목록 ID 조회
  - `.id_map.txt`(video ID ↔ 파일명 맵)와 비교하여 제거된 곡의 mp3 삭제
  - `downloaded.txt` 아카이브에서도 해당 항목 제거
  - `.id_map.txt`에 없는 고아 파일(맵 추적 이전 다운로드 등)도 함께 정리
  - m3u 자동 갱신
- **안전 가드**: `.id_map.txt`가 없거나 비어있을 경우 고아 삭제 건너뜀 (전체 삭제 방지)
- **추적 파일**: 다운로드 시 `--print-to-file "%(id)s\t%(artist,uploader)s - %(title)s.mp3" .id_map.txt` 로 맵 자동 구축

### 🚀 스마트 마이그레이션 기능 추가 (Smart Migration)
- **UI**: "스마트 마이그레이션" 버튼 추가 (보라색)
- **동작**:
  1. `--skip-download`로 플레이리스트 전체 메타데이터 스캔
  2. 기존 mp3 파일의 임베딩된 `PURL` ID3 태그에서 YouTube video ID 추출 (`ffprobe`)
  3. video ID → 새 파일명 매핑으로 이름 변경 (**재다운로드 없음**)
  4. 이미 올바른 이름의 파일은 그대로 유지
  5. 매핑 실패 파일만 yt-dlp로 새로 다운로드
  6. 구형식 고아 파일 자동 삭제 (sync delete 강제 활성)
- **목적**: `001 - 【Ado】ビバリウム（Official Audio）.mp3` 같은 구형식 파일을 `Ado - ビバリウム.mp3` 형식으로 재다운로드 없이 일괄 전환

### 🔧 백엔드 API 추가 (Backend)
- `POST /reset`: 선택한 폴더의 `downloaded.txt`, `.id_map.txt` 삭제 (추적 초기화)
- `POST /download`: `sync_delete`, `migrate` 파라미터 추가

### 🐛 버그 수정 (Bug Fixes)
- sync delete 시 `.id_map.txt`가 없는 상태에서 고아 파일 루프가 실행되어 모든 mp3가 삭제되던 치명적 버그 수정
- sync delete의 `grep -qF`를 `grep -qxF`로 변경 (부분 문자열 오매칭 방지)
- YouTube Music Topic 채널 영상의 artist 메타데이터가 uploader로 덮어씌워지던 문제 수정

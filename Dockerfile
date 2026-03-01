FROM python:3.11-alpine

RUN apk add --no-cache \
    ffmpeg \
    curl \
    bash \
    coreutils

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN chmod +x download_music.sh

EXPOSE 5000

CMD ["python", "app.py"]

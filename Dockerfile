FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    atomicparsley \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code and shell script
COPY . .

# Make the shell script executable
RUN chmod +x download_music.sh

# Expose the port
EXPOSE 5000

# Run the application
CMD ["python", "app.py"]

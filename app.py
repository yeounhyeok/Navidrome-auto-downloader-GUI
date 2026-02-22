from flask import Flask, render_template, request, Response, stream_with_context, jsonify
import subprocess
import os
import threading
import time
import json

app = Flask(__name__)

# Base directory for music (should match docker-compose volume)
BASE_DIR = os.environ.get('BASE_DIR', '/music')

# Global state for background task
class TaskManager:
    def __init__(self):
        self.is_running = False
        self.logs = []
        self.process = None

task_manager = TaskManager()

def run_download_task(cmd):
    """Background task to run the shell script and capture logs."""
    task_manager.is_running = True
    task_manager.logs = [] # Clear logs for new run
    
    try:
        task_manager.logs.append(f"Executing: {' '.join(cmd)}\n")
        
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        task_manager.process = process
        
        for line in process.stdout:
            task_manager.logs.append(line)
            
        process.wait()
        task_manager.logs.append(f"\nProcess finished with exit code {process.returncode}")
        
    except Exception as e:
        task_manager.logs.append(f"\nError occurred: {str(e)}\n")
        
    finally:
        task_manager.is_running = False
        task_manager.process = None

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/folders', methods=['GET'])
def get_folders():
    folders = []
    if os.path.exists(BASE_DIR):
        for entry in os.scandir(BASE_DIR):
            if entry.is_dir():
                url_file_path = os.path.join(entry.path, 'playlist_url.txt')
                url = ""
                if os.path.exists(url_file_path):
                    try:
                        with open(url_file_path, 'r') as f:
                            url = f.read().strip()
                    except:
                        pass
                folders.append({'name': entry.name, 'url': url})
    return jsonify(folders)

@app.route('/download', methods=['POST'])
def download():
    if task_manager.is_running:
        return jsonify({"status": "error", "message": "A download task is already running."}), 409

    folder_name = request.form.get('folder_name')
    new_folder_name = request.form.get('new_folder_name')
    youtube_url = request.form.get('youtube_url')
    
    # Use new folder name if provided, otherwise use selected folder
    target_folder = new_folder_name if new_folder_name else folder_name
    
    if not target_folder or not youtube_url:
        return jsonify({"status": "error", "message": "Missing arguments"}), 400

    # Prepare command
    cmd = ['./download_music.sh', target_folder, youtube_url]
    
    # Start background thread
    thread = threading.Thread(target=run_download_task, args=(cmd,))
    thread.daemon = True # Ensure thread doesn't block app exit
    thread.start()

    return jsonify({"status": "started", "message": "Download started in background."})

@app.route('/stream')
def stream():
    def event_stream():
        initial_index = 0
        while True:
            # Check if there are new logs to send
            if initial_index < len(task_manager.logs):
                # Get all new lines
                new_lines = task_manager.logs[initial_index:]
                for line in new_lines:
                    # Send as Server-Sent Event (SSE)
                    # We use JSON to safely handle newlines and special characters
                    yield f"data: {json.dumps(line)}\n\n"
                initial_index += len(new_lines)
            
            # If task is finished and we've sent all logs, send a completion signal
            if not task_manager.is_running and initial_index >= len(task_manager.logs):
                yield "data: \"[DONE]\"\n\n"
                break
            
            time.sleep(0.5) # Polling interval

    return Response(stream_with_context(event_stream()), mimetype='text/event-stream')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

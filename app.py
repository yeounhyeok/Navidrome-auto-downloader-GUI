from flask import Flask, render_template, request, Response, stream_with_context, jsonify
import subprocess
import os
import threading
import time
import json
import signal
import sys

app = Flask(__name__)

# Base directory for music (should match docker-compose volume)
BASE_DIR = os.environ.get('BASE_DIR', '/music')

# Global state for background task
class TaskManager:
    def __init__(self):
        self.is_running = False
        self.logs = [] # Keep logs in memory for UI
        self.process = None

task_manager = TaskManager()

def run_download_task(cmd):
    """Background task to run the shell script, output to Docker logs (stdout), and capture for UI."""
    task_manager.is_running = True
    task_manager.logs = [] # Clear logs for new run
    
    start_msg = f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Executing: {' '.join(cmd)}\n"
    print(start_msg.strip(), flush=True) # To Docker Logs
    task_manager.logs.append(start_msg)  # To UI
    
    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            start_new_session=True # Create new process group
        )
        task_manager.process = process
        
        for line in process.stdout:
            print(line.strip(), flush=True) # To Docker Logs
            task_manager.logs.append(line)  # To UI
            
        process.wait()
        end_msg = f"\n[{time.strftime('%Y-%m-%d %H:%M:%S')}] Process finished with exit code {process.returncode}"
        print(end_msg.strip(), flush=True) # To Docker Logs
        task_manager.logs.append(end_msg)  # To UI
        
    except Exception as e:
        err_msg = f"\n[{time.strftime('%Y-%m-%d %H:%M:%S')}] Error occurred: {str(e)}\n"
        print(err_msg.strip(), flush=True) # To Docker Logs
        task_manager.logs.append(err_msg)  # To UI
        
    finally:
        task_manager.is_running = False
        task_manager.process = None

def stop_download_task():
    """Stops the currently running download task."""
    if task_manager.process and task_manager.process.poll() is None:
        try:
            # Kill the process group to ensure all child processes (like yt-dlp) are also killed
            os.killpg(os.getpgid(task_manager.process.pid), signal.SIGTERM)
            stop_msg = f"\n[{time.strftime('%Y-%m-%d %H:%M:%S')}] !!! Process group stopped by user !!!\n"
            print(stop_msg.strip(), flush=True) # To Docker Logs
            task_manager.logs.append(stop_msg)  # To UI
            return True
        except ProcessLookupError:
            return False
    return False

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

@app.route('/stop', methods=['POST'])
def stop():
    if not task_manager.is_running:
        return jsonify({"status": "error", "message": "No task is running."}), 400
    
    if stop_download_task():
        return jsonify({"status": "stopped", "message": "Download task stopped."})
    else:
        return jsonify({"status": "error", "message": "Failed to stop task or task already finished."}), 500

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

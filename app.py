from flask import Flask, render_template, request, Response, stream_with_context, jsonify
import subprocess
import os

app = Flask(__name__)

# Base directory for music (should match docker-compose volume)
BASE_DIR = os.environ.get('BASE_DIR', '/music')

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
    folder_name = request.form.get('folder_name')
    new_folder_name = request.form.get('new_folder_name')
    youtube_url = request.form.get('youtube_url')
    
    # Use new folder name if provided, otherwise use selected folder
    target_folder = new_folder_name if new_folder_name else folder_name
    
    if not target_folder or not youtube_url:
        return "Missing arguments", 400

    def generate():
        # Execute the shell script
        cmd = ['./download_music.sh', target_folder, youtube_url]
        
        yield f"Executing: {' '.join(cmd)}\n"
        
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        
        for line in process.stdout:
            yield line
            
        process.wait()
        yield f"\nProcess finished with exit code {process.returncode}"

    return Response(stream_with_context(generate()), mimetype='text/plain')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

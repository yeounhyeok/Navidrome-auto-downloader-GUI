from flask import Flask, render_template, request, Response, stream_with_context
import subprocess
import os

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/download', methods=['POST'])
def download():
    folder_name = request.form.get('folder_name')
    youtube_url = request.form.get('youtube_url')
    
    if not folder_name or not youtube_url:
        return "Missing arguments", 400

    def generate():
        # Execute the shell script
        cmd = ['./download_music.sh', folder_name, youtube_url]
        
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

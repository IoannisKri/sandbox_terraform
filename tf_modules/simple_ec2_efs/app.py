from flask import Flask
import socket
app = Flask(__name__)

@app.route('/')
def hello():
    """Super simple web app"""
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    return f'<h1>Hello from {local_ip}</hi>' \
    '</br>' \
    '<img src="https://media-exp1.licdn.com/dms/image/C4D0BAQHM8LHIlT8bPg/company-logo_200_200/0/1579540524617?e=2147483647&amp;v=beta&amp;t=lH82SsqDovD4WtOs5TZzT57uTgYr5mdVbfpWVIZjhTw" jsaction="load:XAeZkd;" jsname="HiaYvf" class="n3VNCb KAlRDb" alt="Machine Learning Reply GmbH | LinkedIn" data-noaft="1" style="width: 176px; height: 176px; margin: 0px;">'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
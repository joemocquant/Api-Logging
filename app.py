from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/v1/hello-world')
def hello_world():
    return jsonify({'message': 'hello world'}) 

if __name__ == "__main__":
    app.run("0.0.0.0")

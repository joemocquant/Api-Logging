from flask import Flask, request, Response, abort
from redis import Redis
from time import time
import json
import pickle

app = Flask(__name__)
redis = Redis(host='redis', port=6379)


def log_request(endpoint):
	ip = request.remote_addr
	timestamp = int(str(time()).split('.')[0])
	record = pickle.dumps({'ip': ip, 'timestamp': timestamp})
	redis.rpush(endpoint, record)
	redis.sadd('endpoints', endpoint)


def formatResponse(js):
	res = Response(json.dumps(js), mimetype='application/json')
	return res




@app.route('/v1/hello-world')

def hello_world():
	log_request('hello-world')
	return formatResponse({'message': 'hello world'})



@app.route('/v1/logs')

def logs():
	log_request('logs')
	endpoints = redis.smembers('endpoints')

	logs = []
	for ep in endpoints:
		records = redis.lrange(ep, 0, -1)
		logs.append({'endpoint': ep, 'logs': map(pickle.loads, records)})

	return formatResponse({'logset': logs})



@app.route('/v1/hello-world/logs')

def hello_world_logs():
	log_request('hello-world/logs')
	records = redis.lrange('hello-world', 0, -1)
	return formatResponse({"logs": map(pickle.loads, records)})



@app.route('/<path:path>')

def catch_all(path):
	log_request(path)
	abort(404)

if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)

from flask import Flask, request, Response, abort
from redis import Redis
from time import time
import json
import pickle

app = Flask(__name__)
redis = Redis(host='redis', port=6379)
api_version = 1

def log_request(endpoint):
    ip = request.remote_addr
    timestamp = int(str(time()).split('.')[0])
    record = pickle.dumps({'ip': ip, 'timestamp': timestamp})
    redis.rpush(endpoint, record)
    redis.sadd('endpoints', endpoint)

def format_response(js):
    res = Response(json.dumps(js), mimetype='application/json')
    return res


@app.route('/v' + str(api_version) + '/logs')
def logs():
    log_request('logs')
    endpoints = redis.smembers('endpoints')

    logs = []
    for ep in endpoints:
        records = redis.lrange(ep, 0, -1)
        logs.append({'endpoint': ep, 'logs': map(pickle.loads, records)})

    return format_response({'logset': logs})


@app.route('/v' + str(api_version) + '/<endpoint>')
def endpoint_request(endpoint):
    log_request(endpoint)
    return format_response({'message': endpoint})


@app.route('/v' + str(api_version) + '/<endpoint>/logs')
def endpoint_request_logs(endpoint):
    log_request(endpoint + '/logs')
    records = redis.lrange(endpoint, 0, -1)
    return format_response({"logs": map(pickle.loads, records)})


@app.route('/<path:path>')
def catch_all(path):
    log_request(path)
    abort(404)


if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)

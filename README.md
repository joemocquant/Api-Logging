# Api-Logging
Simple API + Logging

Install: docker-compose up

API:

curl -i http://xxx.xxx.xxx.xxx:5000/v1/hello-world
<br>
curl -i http://xxx.xxx.xxx.xxx:5000/v1/logs
<br>
curl -i http://xxx.xxx.xxx.xxx:5000/v1/hello-world/logs

Web Interface:

optional parameters:
- aggregate: level aggregate in seconds
- apiversion: api version
- endpoint: endpoint logs to display
<br>
<br>
http://xxx.xxx.xxx.xxx
<br>
http://xxx.xxx.xxx.xxx?aggregate=120
<br>
http://xxx.xxx.xxx.xxx?aggregate=180&apiversion=1&endpoint=hello-world

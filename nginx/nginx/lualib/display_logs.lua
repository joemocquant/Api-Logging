local http = require "resty.http"
local upstream = require "ngx.upstream"
local cjson = require "cjson"


local function getIp()
	local servers = upstream.get_servers("api")
	local addr = (servers[1])["addr"]
	local ip = string.sub(addr, 1, string.find(addr, ":") - 1)
	return  ip
end

local function getJson()
	local httpc = http.new()
	local res, err = httpc:request_uri("http://" .. getIp() .. ":5000/v1/logs", 
										{method = "GET", headers = {["Content-Type"] = "application/json",}})

	httpc:close()
	return res.body
end

function compare(a , b)
  return a[1] > b[1]
end

local function buildTable(entry)
	local logs = {}
	for k, record in pairs(entry["logs"]) do
		table.insert(logs, {record["timestamp"], entry["endpoint"], record["ip"]})
	end

	return logs
end

function printRawLogs(table, title)

	ngx.say("<table><th colspan='3'>", title, " (raw)</th>")
	ngx.say("<tr class='title'><td>Timestamp</td><td>Endpoint</td><td>IP</td></tr>")

	for k, v in pairs(table) do
		ngx.say("<tr><td>", os.date("%y/%m/%d %H:%M:%S", v[1]), "</td><td>", v[2], "</td><td>", v[3], "</td></tr>")
	end
	
	ngx.say("</table>")
end

local value = cjson.decode(getJson())
local logset = value["logset"]

local logs = {}
local hwl
for k, entry in pairs(logset) do
	local endpoint  = entry["endpoint"]
	
	if endpoint == "hello-world" then
		hwl = buildTable(entry)
	end

	for k, record in pairs(entry["logs"]) do
		table.insert(logs, {record["timestamp"], endpoint, record["ip"]})
	end
end

table.sort(logs, compare)
table.sort(hwl, compare)


ngx.header.content_type = "text/html"

ngx.say("<html><head><title>API Access Logs</title><link rel='stylesheet' type='text/css' href='style.css'></head></head><body>")

printRawLogs(logs, "/v1/logs")
printRawLogs(hwl, "hello-world/logs")

ngx.say("</body></html>")

return ngx.exit(ngx.HTTP_OK)  

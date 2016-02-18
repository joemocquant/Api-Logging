local http = require "resty.http"
local upstream = require "ngx.upstream"
local cjson = require "cjson"

local function getIp()

	local servers = upstream.get_servers("api")
	local addr = (servers[1])["addr"]
	local ip = string.sub(addr, 1, string.find(addr, ":") - 1)
	return  ip
end

local function getJson(url)

	local httpc = http.new()
	local res, err = httpc:request_uri(url, {method = "GET",
											headers = {["Content-Type"] = "application/json",}})

	httpc:close()
	return res.body
end

local function compare(a , b)
  return a[1] > b[1]
end

local function buildRawTables(logset)

	local logs = {}
	logs["/v1/logs"] = {}

	for k, entry in pairs(logset) do
		local endpoint = entry["endpoint"]
		
		local tab = {}
		for k, record in pairs(entry["logs"]) do
			table.insert(tab, {record["timestamp"], endpoint, record["ip"]})
		end

		if endpoint == "hello-world" then
			logs["/v1/hello-world/logs"] = tab
		end

		for k, record in pairs(tab) do
			table.insert(logs["/v1/logs"], record)
		end
	end

	table.sort(logs["/v1/logs"], compare)
	table.sort(logs["/v1/hello-world/logs"], compare)

	return logs
end

-- level: number of seconds for aggregate
local function buildAggregateLogs(tab, level)

	local aggregate = {}
	for k, record in pairs(tab) do

		local timestamp = record[1]
		local timeLeveled = math.floor(timestamp / level)

		local ips = aggregate[timeLeveled]
        if ips then

        	if ips[2][record[3]] then
        		ips[2][record[3]] = ips[2][record[3]] + 1
        	else
        		ips[2][record[3]] = 1
        	end
        else
        	aggregate[timeLeveled] = {timeLeveled, {[record[3]] = 1}}
        end
	end

	aggregateSorted = {}
	for t, records in pairs(aggregate) do
		table.insert(aggregateSorted, records)
	end

	table.sort(aggregateSorted, compare)

	return aggregateSorted
end

local function rawTableHtml(tab, title)

	local str = "<table class='raw'><th colspan='3'>" .. title .. "</th>"
	str = str .. "<tr class='title'>" .. 
					"<td>Timestamp</td>" .. 
					"<td>Endpoint</td>" .. 
					"<td>IP</td>" .. 
				"</tr>"

	for k, v in pairs(tab) do
		str = str .. "<tr>" ..
						"<td>" .. os.date("%y/%m/%d %H:%M:%S", v[1]) .. "</td>" ..
						"<td>" .. v[2] .. "</td>" .. 
						"<td>" .. v[3] .. "</td>" ..
					 "</tr>"
	end
	
	str = str .. "</table>"
	return str
end

local function aggregateTableHtml(tab, level, title)

	local str = "<table class='aggregate'>" .. 
					"<th colspan='2'>" .. title .. "</th>"
	str = str .. 		"<tr class='aggregate_title'>" .. 
							"<td>IP</td>" .. 
							"<td>Count</td>" .. 
						"</tr>"

	for k, records in pairs(tab) do

		local timestamp = os.date("%y/%m/%d %H:%M:%S", records[1] * level)
		str = str .. "<th class='aggregate_title' colspan='2'>" .. timestamp .. "</th>"


		for ip, count in pairs(records[2]) do
			str = str .. "<tr>" ..
							"<td>" .. ip .. "</td>" .. 
							"<td>" .. count .. "</td>" ..
					 	 "</tr>"
		end
	end

	str = str .. "</table>"
	return str
end

local function generateLogsHtml()

	local level = 60 -- 60s (minute aggregte level)
	local rawJson = cjson.decode(getJson("http://" .. getIp() .. ":5000/v1/logs"))
	local rawTables = buildRawTables(rawJson["logset"])

	local rawTableLogs = rawTables["/v1/logs"]
	local rawTableHelloWorldLogs = rawTables["/v1/hello-world/logs"]

	local aggregateLogs = buildAggregateLogs(rawTableLogs, level)
	local aggregateHelloWorldLogs = buildAggregateLogs(rawTableHelloWorldLogs, level)

	local html = "<html>" .. 
					"<head>" ..
						"<title>API Access Logs</title>" .. 
						"<link rel='stylesheet' type='text/css' href='style.css'>" .. 
					"</head>" ..
					"<body>"

	html = html .. rawTableHtml(rawTableLogs, "/v1/logs (raw)") .. 
				   aggregateTableHtml(aggregateLogs, level, "/v1/logs (aggregate)") ..

				   rawTableHtml(rawTableHelloWorldLogs, "/v1/hello-world/logs (raw)") ..
				   aggregateTableHtml(aggregateHelloWorldLogs, level, "/v1/hello-world/logs (aggregate)")

	html = html .. "</body></html>"

	ngx.header.content_type = "text/html"
	ngx.say(html)
	return ngx.exit(ngx.HTTP_OK)
end

generateLogsHtml()

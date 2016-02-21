local http = require "resty.http"
local upstream = require "ngx.upstream"
local cjson = require "cjson"

local displaylogs = {}

local function get_ip()

    local servers = upstream.get_servers("api")
    local addr = (servers[1])["addr"]
    local ip = string.sub(addr, 1, string.find(addr, ":") - 1)
    return  ip
end

local function get_json(url)

    local httpc = http.new()
    httpc:set_timeout(100)

    local hd = {["Content-Type"] = "application/json"}
    local res, err = httpc:request_uri(url, {method = "GET", headers = hd})

    httpc:close()

    if not res then
        ngx.say("failed to request API: ", err)
        return ngx.exit(ngx.HTTP_OK)
    end

    ngx.status = res.status
    return res.body
end

local function compare(a , b)
  return a[1] > b[1]
end

local function build_raw_tables(logset, apiVersion, endpoint)

    local logs = {}
    local logsPath = "/v" .. apiVersion .. "/logs"
    local endpointLogsPath = "/v" .. apiVersion .. "/" .. endpoint .. "/logs"

    logs[logsPath] = {}
    logs[endpointLogsPath] = {}

    for k, entry in pairs(logset) do
        local ep = entry["endpoint"]

        local tab = {}
        for k, record in pairs(entry["logs"]) do
            table.insert(tab, {record["timestamp"], ep, record["ip"]})
        end

        if ep == endpoint then
            logs[endpointLogsPath] = tab
        end

        for k, record in pairs(tab) do
            table.insert(logs[logsPath], record)
        end
    end

    table.sort(logs[logsPath], compare)
    table.sort(logs[endpointLogsPath], compare)

    return logs
end

local function build_aggregate_logs_tables(tab, aggregateLevel)

    local aggregate = {}
    for k, record in pairs(tab) do

        local timestamp = record[1]
        local timeLeveled = math.floor(timestamp / aggregateLevel)

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

local function build_raw_table_html(tab, title)

    local str = "<table class='raw'>" ..
                    "<th class='title' colspan='3'>" .. title .. "</th>"
    str = str ..        "<tr class='sub_title'>" ..
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

local function build_aggregate_table_html(tab, aggregateLevel, title)

    local str = "<table class='aggregate'>" ..
                    "<th class='title' colspan='2'>" .. title .. "</th>"
    str = str ..        "<tr class='sub_title'>" ..
                            "<td>IP</td>" ..
                            "<td>#</td>" ..
                        "</tr>"

    for k, records in pairs(tab) do

        local beginDate = os.date("%y/%m/%d %H:%M:%S", records[1] * aggregateLevel)
        local endDate = os.date("%y/%m/%d %H:%M:%S", (records[1] + 1) * aggregateLevel)
        local range = beginDate .. " - " .. endDate
        str = str .. "<th class='range' colspan='2'>" .. range .. "</th>"

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

function displaylogs.generate_logs_html(aggregateLevel, apiVersion, endpoint)

    local logsPath = "/v" .. apiVersion .. "/logs"
    local endpointLogsPath = "/v" .. apiVersion .. "/" .. endpoint .. "/logs"

    local rawJson = cjson.decode(get_json("http://" .. get_ip() .. ":5000" .. logsPath))
    local rawTables = build_raw_tables(rawJson["logset"], apiVersion, endpoint)

    local rawTableLogs = rawTables[logsPath]
    local rawTableEndpointLogs = rawTables[endpointLogsPath]

    local aggregateLogs = build_aggregate_logs_tables(rawTableLogs, aggregateLevel)
    local aggregateEndpointLogs = build_aggregate_logs_tables(rawTableEndpointLogs, aggregateLevel)

    local html = "<html>" ..
                    "<head>" ..
                        "<title>API Access Logs</title>" ..
                        "<link rel='stylesheet' type='text/css' href='style.css'>" ..
                    "</head>" ..
                    "<body>"

    html = html .. build_raw_table_html(rawTableLogs, logsPath .. " (raw)") ..
                   build_aggregate_table_html(aggregateLogs, aggregateLevel, logsPath .. " (aggregate)") ..

                   build_raw_table_html(rawTableEndpointLogs, endpointLogsPath .. " (raw)") ..
                   build_aggregate_table_html(aggregateEndpointLogs, aggregateLevel, endpointLogsPath .. " (aggregate)")

    html = html .. "</body></html>"

    ngx.header.content_type = "text/html"
    ngx.say(html)

    return ngx.exit(ngx.HTTP_OK)
end

return displaylogs

local cjson = require "cjson"
--/opt/openresty/nginx/lualib/resty
local http = require "resty.http"
local httpc = http.new()

local upstream = require "ngx.upstream"
local servers = upstream.get_servers("api")
local ipport = (servers[1])["addr"]

ip = string.sub(ipport, 1, string.find(ipport, ":") - 1)

local res, err = httpc:request_uri("http://" .. ip .. ":5000/v1/logs", 
									{method = "GET", headers = {["Content-Type"] = "application/json",}
                                  })


-- TODO html table

ngx.say(res.body)

ngx.status = ngx.HTTP_OK
ngx.header.content_type = "application/json; charset=utf-8"
return ngx.exit(ngx.HTTP_OK)  

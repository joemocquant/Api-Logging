FROM ficusio/openresty:latest

RUN wget https://github.com/pintsized/lua-resty-http/archive/master.zip
RUN unzip master.zip
RUN mkdir /opt/openresty/nginx/lualib/resty
RUN cp lua-resty-http-master/lib/resty/*.lua /opt/openresty/nginx/lualib/resty/
RUN rm -rf master.zip lua-resty-http-master

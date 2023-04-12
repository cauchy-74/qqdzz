#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"
 
local channels = {}

s.resp.subscribe = function(source, channel, func_table)
    ERROR("[msgserver]：subscribe ==>> " .. channel)
    -- local sql = string.format("insert into Message (channel) values (%s);", channel)
    -- skynet.send("mysql", "lua", "query", sql)
    -- 感觉这里不需要插入，而且表的字段三not null。这样插不进去

    if not channels[channel] then 
        channels[channel] = {} 
    end

    local handler = load(func_table.func)

    table.insert(channels[channel], handler)
    return true
end

s.resp.unsubscribe = function(source, channel, func_table)
    ERROR("[msgserver]：unsubscribe ==>> " .. channel)
    local sql = string.format("delete from Message channel = %s;", channel)
    skynet.send("mysql", "lua", "query", sql)

    local handler = load(func_table.func)

    if channels[channel] then 
        if not handler then 
            channels[channel] = nil 
        else 
            for i, v in ipairs(channels[channel]) do 
                if v == handler then 
                    table.remove(channels[channel], i)
                    break
                end
            end
        end
    end
end

-- sql语句，插入要是string -> %s。不能是table。
-- 可以编码成string在插入，！要用！mysql.quote_sql_str
s.resp.publish = function(source, channel, message)
    ERROR("[msgserver]：publish ==>> " .. channel)
    local sql = string.format("insert into Message (channel, message, time) values (%s, %s, '%s');", mysql.quote_sql_str(channel), mysql.quote_sql_str(cjson.encode(message)), os.date("%Y-%m-%d %H:%M:%S", os.time()))

    skynet.send("mysql", "lua", "query", sql)
end

local function update(dt)
    ERROR("[msgserver]：update ~~~~ ")
    local str_time = os.date("%Y-%m-%d %H:%M:%S", os.time())
    local sql = string.format("select * from Message where time >= '%s';", str_time) -- 日期格式数据用''
    local result = skynet.call("mysql", "lua", "query", sql)

    for _, row in ipairs(result) do 
        local channel = row.channel
        local message = row.message 
        if channels[channel] then 
            for _, handler in ipairs(channels[channel]) do 
                INFO("[msgserver]：=> " .. channel)
                handler(channel, message)
            end
        end
    end
end

local function loop() 
    -- 基于时间轮的定时器，单位10毫秒
    skynet.timeout(10 * 100, function() -- 10s
        update() 
        loop()
    end) 
end

s.init = function()
    skynet.fork(loop) 
end

s.start(...)

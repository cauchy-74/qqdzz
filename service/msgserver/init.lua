#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"
 
local channels = {}

s.resp.subscribe = function(source, channel, user_id, func_table)
    ERROR("[msgserver]：subscribe ==>> " .. channel)
    -- local sql = string.format("insert into Message (channel) values (%s);", channel)
    -- skynet.send("mysql", "lua", "query", sql)
    -- 感觉这里不需要插入，而且表的字段三not null。这样插不进去

    if not channels[channel] then 
        channels[channel] = {} 
    end

    if not channels[channel][user_id] then 
        channels[channel][user_id] = {} 
    end

    local handler = load(func_table.func)

    table.insert(channels[channel][tonumber(user_id)], handler)
    return true
end

s.resp.unsubscribe = function(source, channel, user_id, func_table)
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
-- message = { type; from; to; msg; other; }
s.resp.publish = function(source, channel, message)
    ERROR("[msgserver]：publish ==>> " .. channel)
    local sql = string.format("insert into Message (channel, message, time) values (%s, %s, '%s');", mysql.quote_sql_str(channel), mysql.quote_sql_str(cjson.encode(message)), os.date("%Y-%m-%d %H:%M:%S", os.time()))

    skynet.send("mysql", "lua", "query", sql)
end

local function msg_user_to_user(channel, message)
    local from = tonumber(message.from)
    local to   = tonumber(message.to) 
    local result = skynet.call("agentmgr", "lua", "get_online_id", to)
    if result and channels[channel][to] then 
        local handler = channels[channel][to]
        handler(channel, message)
    else 

    end
end

local function update(dt)
    ERROR("[msgserver]：update ~~~~ ")
    local str_time = os.date("%Y-%m-%d %H:%M:%S", os.time())
    local sql = string.format("select * from Message where time >= '%s';", str_time) -- 日期格式数据用''
    local result = skynet.call("mysql", "lua", "query", sql)

    for _, row in ipairs(result) do 
        local channel = row.channel
        local message = row.message 
        
        local from = tonumber(message.from)
        local to   = tonumber(message.to) 
        
        if from ~= 0 then -- 用户消息
            if to ~= 0 then -- 发给用户
                msg_user_to_user(channel, message)
            else  -- 发给系统
            end
        elseif from == 0 then -- 系统消息
            -- 
        end
    end
end

local mails = {} 
local mail_count = 0

s.resp.recv_mail = function(source, msgJS)
    mail_count = mail_count + 1
    mails[mail_count] = msgJS -- 插进缓存表mails

    local msg = cjson.decode(msgJS)

    local sql = string.format("insert into MailInfo (`from`, `to`, `time`, `channel`, `content`) values (%d, %d, '%s', %d, %s);", msg.from, msg.to, msg.time, msg.channel, mysql.quote_sql_str(msg.message))
    local res = skynet.call("mysql", "lua", "query", sql) -- 插进mysql

    if not res then 
        ERROR("NOT INSERT !!!")
    end
end

-- 邮件轮询发送
local function mail_cache_loop()
    local del_index_record = {} -- 记录要删除的下标邮件

    for id, msgJS in pairs(mails) do 
        local msg = cjson.decode(msgJS) 
        local to = msg.to

        local online = skynet.call("agentmgr", "lua", "get_online_id", to)
        if online then -- 如果在线
            local node = skynet.call("agentmgr", "lua", "get_user_node", to) 
            local agent = skynet.call("agentmgr", "lua", "get_user_agent", to) 

            s.send(node, agent, "recv_mail", msgJS)

            -- 删除mysql中的这封邮件
            local sql = string.format("delete from MailInfo where `from` = %d and `to` = %d and `time` = '%s';", msg.from, msg.to, msg.time)
            skynet.send("mysql", "lua", "query", sql)

            table.insert(del_index_record, id)
        end
    end

    -- 删除已经发送的邮件
    for _, v in pairs(del_index_record) do 
        mails[v] = nil
    end
    del_index_record = nil
end

local function loop() 
    -- 基于时间轮的定时器，单位10毫秒
    skynet.timeout(3 * 100, function() -- 10s
        mail_cache_loop()
        loop()
    end) 
end

s.init = function()
    skynet.fork(loop) 
end

s.start(...)

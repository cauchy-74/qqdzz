#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"
 
local channels = {} -- 对应频道不同玩家的{index,node,agent}
local index_callbackFunc = 0 -- 唯一索引

local update_last_time = os.time()

local mail_loop_time = 300 -- 邮件轮询时长间隔
local chat_loop_time = 200 -- 订阅轮询时长间隔
local chat_loop_time_s = chat_loop_time / 100 -- 2s
local clear_loop_time= 3000-- 邮件清理

-- 获取唯一回调函数索引
s.resp.get_index = function(source)
    index_callbackFunc = index_callbackFunc + 1
    return index_callbackFunc
end

-- 由于service封装，参数不能是function
s.resp.subscribe = function(source, channel, msgJS)
    -- INFO("[msgserver]：subscribe ==>> " .. channel)

    if not channels[channel] then 
        channels[channel] = {} 
    end

    table.insert(channels[channel], msgJS)
    return true
end

s.resp.unsubscribe = function(source, channel, msgJS)
    -- INFO("[msgserver]：unsubscribe ==>> " .. channel)

    if channels[channel] then 
        if not msgJS or msgJS == nil then 
            channels[channel] = nil 
        else 
            for i, v in ipairs(channels[channel]) do 
                if v == msgJS then 
                    table.remove(channels[channel], i)
                    break
                end
            end
        end
    end
    return true
end

-- sql语句，插入要是string -> %s。不能是table。
-- 可以编码成string在插入，！要用！mysql.quote_sql_str
-- message = { type; from; to; msg; other; }
s.resp.publish = function(source, channel, message)
    INFO("[msgserver]：publish ==>> " .. channel)

    local timestamp = os.time()
    local time = os.date("%Y-%m-%d %H:%M:%S", timestamp)

    -- 所有消息先统一存在Message表中，之后分类
    local sql = string.format("insert into Message (`channel`, `message`, `time`, `timestamp`) values (%s, %s, '%s', %d);", mysql.quote_sql_str(channel), mysql.quote_sql_str(message), time, timestamp)
    skynet.send("mysql", "lua", "query", sql)

    return true
end

-- 订阅的更新发布。
-- 目前想法：维护一个上一次的发布时间
-- 每次选择该段时间内的新消息进行发送
local function update(dt)
    -- INFO("[msgserver]：update ~~~~ ")
    -- local now = os.date("%Y-%m-%d %H:%M:%S", os.time())
    local now = os.time()
    local sql = string.format("select * from Message where `timestamp` > %d and `timestamp` <= %d;", update_last_time - chat_loop_time_s, now - chat_loop_time_s) -- 消息延迟

    update_last_time = now -- 必须立即更新
    local result = skynet.call("mysql", "lua", "query", sql)

    if result then 
        for _, row in ipairs(result) do 
            local channel = row.channel
            local message = row.message 
            
            for _, msgJS in pairs(channels[channel]) do
                local msg = cjson.decode(msgJS)
                s.send(msg.node, msg.agent, "callback", msg.index, channel, message)  
            end
        end
    end

    -- update_last_time = now
end

-- 订阅者模式
-----------------------------------------------
-- 邮件系统

s.mails = {} 
s.mail_count = 0 -- 需要在服务启动时更新为max(id)

s.resp.recv_mail = function(source, msgJS)
    s.mail_count = s.mail_count + 1
    local msg = cjson.decode(msgJS)
    msg.user_id = msg.to -- user_id 应该是 to
    msg.mail_id = tonumber(s.mail_count)  -- 给邮件打上唯一标识mail_id
    msg.is_read = false 
    msg.is_rewarded = false 
    msg.title = ""
    local msgJS = cjson.encode(msg)

    s.mails[s.mail_count] = msgJS -- 插进缓存表mails

    local msg = cjson.decode(msgJS)

    -- 数据库中的id应该也同步为这里的s.mail_count
    local sql = string.format("insert into MailInfo (`from`, `to`, `time`, `channel`, `message`) values (%d, %d, '%s', %d, %s);", msg.from, msg.to, msg.time, msg.channel, mysql.quote_sql_str(msg.message))
    local res = skynet.call("mysql", "lua", "query", sql) -- 插进mysql

    if not res then 
        ERROR("NOT INSERT !!!")
    end
end

-- 邮件轮询发送
local function mail_cache_loop()
    local del_index_record = {} -- 记录要删除的下标邮件

    for id, msgJS in pairs(s.mails) do 
        local msg = cjson.decode(msgJS) 
        local to = msg.to

        local online = skynet.call("agentmgr", "lua", "get_online_id", to)
        if online then -- 如果在线
            -- 获取用户所在节点，代理
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
        s.mails[v] = nil
    end
    del_index_record = nil
end

local function clear()
    local sql = string.format("select count(*) as num from Message;"); 
    local res = skynet.call("mysql", "lua", "query", sql)

    if res then 
        if res[1].num > 300 then -- 大于300条数据 clear
            local sql = string.format("delete from Message where `timestamp` < %d;", os.time()); 
            skynet.send("mysql", "lua", "query", sql)
        end
    end
end

local function mail_loop() 
    -- 基于时间轮的定时器，单位10毫秒
    local online = skynet.call("agentmgr", "lua", "get_online_count")
    skynet.timeout(mail_loop_time, function() -- 10s
        if online > 0 then 
            mail_cache_loop()
        end
        mail_loop()
    end) 
end

local function subscribe_loop() 
    local online = skynet.call("agentmgr", "lua", "get_online_count")
    skynet.timeout(chat_loop_time, function()
        if online > 0 then 
            update()
        end
        subscribe_loop() 
    end)
end

local function clear_loop()
    local online = skynet.call("agentmgr", "lua", "get_online_count")
    skynet.timeout(clear_loop_time, function()
        if online > 0 then 
            clear()
        end
        clear_loop()
    end)
end

s.init = function()
    -- 邮件id的置位：MailInfo中id的最大值
    local sql = string.format("select MAX(id) from MailInfo;") 
    local result = skynet.call("mysql", "lua", "query", sql)
    for i, row in ipairs(result) do
        for column_name, column_value in pairs(row) do 
            s.mail_count = tonumber(column_value)
        end
    end

    skynet.fork(mail_loop) 
    skynet.fork(subscribe_loop)
    skynet.fork(clear_loop)
end

s.start(...)

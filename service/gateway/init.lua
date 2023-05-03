#!/usr/local/bin/lua

--[[
--  1. client conn msg: 连接信息
--  2. aleady login player msg: 玩家信息
--]]

local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local socket = require "skynet.socket"

local conns = {} -- [fd] = conn 
local players = {} -- [playerid] = gateplayer

-- 连接类
function conn() 
    local m = {
        fd = nil, 
        playerid = nil,
    }
    return m
end 

-- 玩家类
function gateplayer() 
    local m = {
        playerid = nil, 
        agent = nil, 
        conn = nil,
        token = math.random(1, 99999999), -- 掉线重连的标识码
        lost_conn_time = nil, -- 记录最后一次断开连接的时间
        msgcache = {}, -- 未发送的消息缓存
    }
    return m
end 

-- [[
--      gateway 双向查找
--          1. client->: socket->fd->conn->playerid->player->agent
--          2. agent->: id->playerid->gateplayer->conn->fd->client
-- ]]

-- decode
-- "login,101,123" -> cmd=login, msg={"login" "101" "123"}
local str_unpack = function(msgstr) 
    local msg = {} 

    --[[
    while true do 
        local arg, rest = string.match(msgstr, "(.-) (.*)")
        if arg then 
            msgstr = rest 
            table.insert(msg, arg)
        else 
            table.insert(msg, msgstr)
            break
        end 
    end 
    ]]

    -- 2023年4月15日0时15分：更换新方式进行解析指令。
    -- 书上那个用string.match真垃圾
    for w in string.gmatch(msgstr, "(%S+)") do 
        table.insert(msg, w)
    end

    return msg[1], msg
end 

-- encode
local str_pack = function(cmd, msg)
    return table.concat(msg, ",").."\r\n"
end 

local disconnect = function(fd) 
    local c = conns[fd]
    if not c then 
        return 
    end 

    local playerid = c.playerid 
    -- 还没完成登录
    if not playerid then 
        return 
    else 
        -- 在游戏中
        -- 与登出流程不同，客户端掉线，gateway不触发掉线请求（向agentmgr -> reqkick）
        -- 掉线仅仅取消玩家 gplayer 和旧连接 conn 的关联
        local gplayer = players[playerid] 
        gplayer.conn = nil 

        -- 防止客户端不再发起重连导致的资源占用，开启定时器
        -- 300 * 100 -> 5分钟强制下线
        skynet.timeout(300 * 100, function()
            if gplayer.conn ~= nil then 
                return 
            end 
            -- local msgBS = reqt:encode({}) -- 应该写一个面向响应的消息
            local reason = "断线超时"
            skynet.call("agentmgr", "lua", "reqkick", playerid, reason)
        end)
    end 
end

local process_reconnect = function(fd, msg)
    local playerid = tonumber(msg[2]) 
    local token = tonumber(msg[3])

    local conn = conns[fd]
    if not conn then 
        ERROR("[gateway" .. s.id .. "]：重连失败，连接池conn不存在fd = %s连接", fd)
        return 
    end 
    local gplayer = players[playerid]
    if not gplayer then 
        ERROR("[gateway" .. s.id .. "]：重连失败，用户列表players不存在playerid = %s用户", playerid)
        return 
    end 
    if gplayer.conn then 
        ERROR("[gateway" .. s.id .. "]：重连失败，用户连接conn未断开")
        return 
    end
    if gplayer.token ~= token then 
        ERROR("[gateway" .. s.id .. "]：重连失败，用户令牌不匹配")
    end 
    -- 绑定
    gplayer.conn = conn 
    conn.playerid = playerid 
    -- 回应
    s.resp.send_by_fd(nil, fd, { "reconnect", 0, "重连成功"})
    -- 发送缓存消息
    for i, cmsg in ipairs(gplayer.msgcache) do 
        s.resp.send_by_fd(nil, fd, cmsg)
    end
    gplayer.msgcache = {}
end

local process_msg = function(fd, msgstr) 
    local cmd, msg = str_unpack(msgstr)

    -- 判断无指令应该放在前面，避免下面的..连接错误。nil。
    if type(cmd) ~= "string" or cmd == "" or cmd == "nil" then 
        return 
    end

    INFO("[gateway" .. s.id .. "]：收到来自fd = " .. fd .. "的消息" ..  "【" .. table.concat(msg, ",") .. "】" .. "，执行的指令是" .. "[ " .. cmd .. " ]")

    local conn = conns[fd]
    local playerid = conn.playerid 
    -- [[ 想到一个问题：id维护的是当前网关下的conn中的id，如果从别的网关登录，别的节点登录呢？ ]]
        
    -- 处理重连消息 客户端client自己发reconnect
    if cmd == "reconnect" then 
        process_reconnect(fd, msg)
        return 
    end
        
    if not playerid then -- "login", "register"
        -- 如果未登录
        -- 随机选择一个同节点的login服务转发消息
         
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1, #nodecfg.login)
        -- 随机选择login服务
        local login = "login" .. loginid 

        if msg[4] == nil then -- 可以允许用户自己指定id，之后肯定需要调整，维护一个递增的id
            table.insert(msg, math.random(1, 999999)) -- msg.useid
        end

        local msgBS = request:encode(msg)
         
        INFO("[gateway" .. s.id .. "]：" .. "该连接fd = " .. fd .. "尚未登录账号")
        INFO("[gateway" .. s.id .. "]：" .. "随机选择节点" .. login .. "登录")
        
        skynet.send(login, "lua", "client", fd, cmd, msgBS)
    else 
        -- 如已登录，消息转发给对应的agent
        
        local gplayer = players[playerid]
        local agent = gplayer.agent 
        local msgBS = request:encode(msg)
        
        INFO("[gateway" .. s.id .. "]：" .. "该用户id = " .. playerid .. "已经登录，现命令cmd = [ " .. cmd .. " ]" .. "发送给代理节点agent = " .. agent .. "处理")

        skynet.send(agent, "lua", "client", cmd, msgBS)
    end 
end 

local process_buff = function(fd, readbuff) 
    while true do 
        local msgstr, rest = string.match(readbuff, "(.-)\r\n(.*)")
        if msgstr then 
            readbuff = rest 
            process_msg(fd, msgstr)
        else 
            return readbuff
        end 
    end 
end 

-- 每一条连接接收数据处理
-- 协议格式 : cmd, arg1, arg2, ...#
local recv_loop = function(fd)
    socket.start(fd)
    INFO("[gateway" .. s.id .. "]：socket连接成功fd = " .. fd .. "，监听用户ing~")
    local readbuff = "" 
    while true do 
        local recvstr = socket.read(fd)
        if recvstr then 
            readbuff = readbuff .. recvstr -- 造成gc负担
            readbuff = process_buff(fd, readbuff)
            -- process_buff : 处理数据,返回剩余未处理数据
        else 
            INFO("[gateway" .. s.id .. "]：socket关闭fd = " .. fd)
            disconnect(fd)
            socket.close(fd)
            return 
        end 
    end 
end 

local connect = function(fd, addr)
    if closing then -- admin通知要关停
        return 
    end
    
    INFO("[gateway" .. s.id .. "]：监听到来自addr = " .. addr .. "的连接,连接fd = " .. fd)
    local c = conn() 
    conns[fd] = c 
    c.fd = fd 
    skynet.fork(recv_loop, fd) -- 发起协程
end 

-- skynet.newservice() 传参过来

function s.init() 
    local node = skynet.getenv("node")
    local nodecfg = runconfig[node]

    -- !!! 被 s.id 是字符串给坑了 ！！！
    local port = nodecfg.gateway[tonumber(s.id)].port

    local listenfd = socket.listen("0.0.0.0", port)
    INFO("[gateway" .. s.id .."]：监听socket启动，ip=0.0.0.0, port="..port)
    socket.start(listenfd, connect)
end 

-- 用于login服务的消息转发，msg发给指定fd的客户端
s.resp.send_by_fd = function(source, fd, msgJS) 
    if not conns[fd] then 
        return 
    end 

    -- local buff = str_pack(msg[1], msgJS)
    INFO("[gateway" .. s.id .. "]：发送消息【" .. tostring(msgJS) .. "】给fd = " .. fd .. "的客户端")
    socket.write(fd, tostring(msgJS))
    socket.write(fd, '\n')
end 

-- 用于agent消息转发，msg发给指定玩家id的客户端
s.resp.send = function(source, playerid, msgJS) -- cjson
    -- 这里也被tonumber坑了！！！！！！！！！！！！
    local gplayer = players[tonumber(playerid)] 
    if gplayer == nil then 
        return 
    end 
    local c = gplayer.conn 
    if c == nil then -- 掉线了维护玩家的消息缓存
        table.insert(gplayer.msgcache, msgJS)
        local len = #gplayer.msgcache 
        if len > 500 then -- 超过500条，强制下线
            skynet.call("agentmgr", "lua", "reqkick", playerid, "gate消息缓存过多")
        end 
        return 
    end 
    s.resp.send_by_fd(nil, c.fd, msgJS)
end 

-- login通知gateway，将client关联agent， fd关联playerid
-- [[
--      source: 消息发送方
--      fd:     客户端连接标识
--      playerid:已登录玩家id 
--      agent:  角色代理服务id
--
--      return: bool, 增加一个返回绑定玩家的令牌
-- ]]
s.resp.sure_agent = function(source, fd, playerid, agent)
    local conn = conns[fd]
    if not conn then -- 登录过程中下线了
        skynet.call("agentmgr", "lua", "reqkick", playerid, "未完成登录即下线")
        return false, -1 
    end 

    conn.playerid = playerid 
    
    local gplayer = gateplayer() 
    gplayer.playerid = playerid 
    gplayer.agent = agent 
    gplayer.conn = conn 
    players[playerid] = gplayer 

    return true, gplayer.token
end 

s.resp.kick = function(source, playerid) 
    playerid = tonumber(playerid)

    local gplayer = players[playerid]
    if not gplayer then 
        return 
    end 
    
    ERROR("[gateway]：执行[ kick ]指令，断开与玩家" .. playerid .. "的连接")

    local c = gplayer.conn 
    players[playerid] = nil 
    if not c then 
        return 
    end 
    conns[c.fd] = nil 
    disconnect(c.fd)
    socket.close(c.fd)
end 

local closing = false

s.resp.shutdown = function()
    closing = true
end

s.start(...)

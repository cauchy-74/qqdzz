#!/usr/local/bin/lua

--[[
--  1. client conn msg: 连接信息
--  2. aleady login player msg: 玩家信息
--]]

local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local socket = require "skynet.socket"

conns = {} -- [fd] = conn 
players = {} -- [playerid] = gateplayer

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
    }
    return m
end 

-- [[
--      gateway 双向查找
--          1. client->: socket->fd->conn->playerid->player->agent
--          2. agent->: id->playerid->gateplayer->conn->fd->client
-- ]]

-- decode
-- "login,101,123" -> cmd=login, msg={"login","101","123"}
local str_unpack = function(msgstr) 
    local msg = {} 
    while true do 
        local arg, rest = string.match(msgstr, "(.-),(.*)")
        if arg then 
            msgstr = rest 
            table.insert(msg, arg)
        else 
            table.insert(msg, msgstr)
            break
        end 
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
        players[playerid] = nil 
        local reason = "断线"
        skynet.call("agentmgr", "lua", "reqkick", playerid, reason)
    end 
end

local process_msg = function(fd, msgstr) 
    local cmd, msg = str_unpack(msgstr)
    skynet.error("recv " .. fd .. " [" .. cmd .. "] {" .. table.concat(msg, ",") .. "}" )

    local conn = conns[fd]
    local playerid = conn.playerid 

    if not playerid then 
        -- 如果未登录
        -- 随机选择一个同节点的login服务转发消息
        

        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1, #nodecfg.login)
        -- 随机选择login服务
        local login = "login" .. loginid 

        skynet.error("[ gateway ]: not login ", " choose ", login)

        skynet.send(login, "lua", "client", fd, cmd, msg)

    else 
        -- 如已登录，消息转发给对应的agent

        skynet.error(" [ gateway ]: aleady login ")

        local gplayer = players[playerid]
        local agent = gplayer.agent 
        
        skynet.error("agent = ", agent, " playerid = ", playerid)

        skynet.send(agent, "lua", "client", cmd, msg)
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
    skynet.error("socket connected " .. fd)
    local readbuff = "" 
    while true do 
        local recvstr = socket.read(fd)
        if recvstr then 
            readbuff = readbuff .. recvstr -- 造成gc负担
            readbuff = process_buff(fd, readbuff)
            -- process_buff : 处理数据,返回剩余未处理数据
        else 
            skynet.error("socket close " .. fd)
            disconnect(fd)
            socket.close(fd)
            return 
        end 
    end 
end 

local connect = function(fd, addr)
    print("connect from " .. addr .. " " .. fd)
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
    skynet.error("Listen socket: ", "0.0.0.0", port)
    socket.start(listenfd, connect)
end 

-- 用于login服务的消息转发，msg发给指定fd的客户端
s.resp.send_by_fd = function(source, fd, msg) 
    if not conns[fd] then 
        return 
    end 

    local buff = str_pack(msg[1], msg)

    skynet.error("send " .. fd .. " [" .. msg[1] .. "] { " .. table.concat(msg, ",") .. " }") 

    socket.write(fd, buff) 
end 

-- 用于agent消息转发，msg发给指定玩家id的客户端
s.resp.send = function(source, playerid, msg)
    -- 这里也被tonumber坑了！！！！！！！！！！！！
    local gplayer = players[tonumber(playerid)] 
    if gplayer == nil then 
        return 
    end 
    local c = gplayer.conn 
    if c == nil then 
        return 
    end 
    s.resp.send_by_fd(nil, c.fd, msg)
end 

-- login通知gateway，将client关联agent， fd关联playerid
-- [[
--      source: 消息发送方
--      fd:     客户端连接标识
--      playerid:已登录玩家id 
--      agent:  角色代理服务id
-- ]]
s.resp.sure_agent = function(source, fd, playerid, agent)
    local conn = conns[fd]
    if not conn then -- 登录过程中下线了
        skynet.call("agentmgr", "lua", "reqkick", playerid, "未完成登录即下线")
        return false
    end 

    conn.playerid = playerid 
    
    local gplayer = gateplayer() 
    gplayer.playerid = playerid 
    gplayer.agent = agent 
    gplayer.conn = conn 
    players[playerid] = gplayer 

    return true
end 

s.resp.kick = function(source, playerid) 
    local gplayer = players[playerid]
    if not gplayer then 
        return 
    end 
    
    local c = gplayer.conn 
    players[playerid] = nil 
    if not c then 
        return 
    end 
    conns[c.fd] = nil 
    disconnect(c.fd)
    socket.close(c.fd)
end 

s.start(...)

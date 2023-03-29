#!/usr/local/bin/lua

--[[
--      client->: login,123,456
--      resp  ->: login,0,登录成功
--
--      登录服务：
--          1. 校验用户名和密码
--          2. 给agentmgr发送reqlogin，请求登录
--          3. 给gate发送sure_agent
--          4. 成功执行，login服务打印"login succ"
--]]

local skynet = require "skynet"
local s = require "service"

s.client = {} -- 存放客户端消息处理方法

s.client.login = function(fd, msg, source) 
    -- 采取玩家输入id和pw，id若是平台账号，那么服务端需要对应id；pw在此默认123
    local playerid = tonumber(msg[2]) 
    local pw = tonumber(msg[3]) -- 123 
    local gate = source -- 转发消息的gateway 服务 
    local agent -- pagent那里必须传出来

    node = skynet.getenv("node") 
    if pw ~= 123 then 
        return { "login", 1, "密码错误" }
    else 
        -- 向agentmgr发起请求
        local isok, pagent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gate) 
        agent = pagent

        if not isok then 
            return { "login", 1, "请求mgr失败" }
        end 
    end 
    -- 回应gate
    local isok = skynet.call(gate, "lua", "sure_agent", fd, playerid, agent) 
    if not isok then 
        return { "login", 1, "gate注册失败" }
    end 
    skynet.error("[ login ]: login succ " .. playerid)
    return { "login", 0, "登录成功" }
end 

--[[
--      source: 消息发送方，比如某个gateway 
--      fd:     客户端连接标识，由gateway发过来
--      cmd, msg:协议名和协议对象
--]]
s.resp.client = function(source, fd, cmd, msg) 
    if s.client[cmd] then 
        local ret_msg = s.client[cmd](fd, msg, source)
        skynet.send(source, "lua", "send_by_fd", fd, ret_msg)
    else 
        skynet.error("s.resp.client fail", cmd)
    end 
end 

s.start(...)

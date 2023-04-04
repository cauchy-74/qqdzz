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

s.client.register = function(fd, msgBS, source)
    local msg = request:decode("CMD.RegisterRequest", msgBS)  

    local sql = "insert into UserInfo (user_id, data) values (?, ?)"

    local res = skynet.call("mysql", "lua", "execute", sql, msg.userid, mysql.quote_sql_str(msgBS)) 
    
    if res then 
        return { "register", 0, "成功注册" }
    else 
        return { "register", 1, "注册失败" }
    end
end

s.client.login = function(fd, msgBS, source) 
    -- 采取玩家输入id和pw，id若是平台账号，那么服务端需要对应id；pw在此默认123

    local msg = request:decode("CMD.LoginRequest", msgBS) -- { username = "", password = "", userid =  }

    local playerid = msg.userid 
    local playername = msg.username
    local pw = msg.password

    local gate = source -- 转发消息的gateway 服务 
    local agent -- pagent那里必须传出来

    node = skynet.getenv("node") 
    if pw ~= "123" then 
        return { "login", 1, -1, "密码错误" }
    else 
        -- 向agentmgr发起请求
        local isok, pagent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gate) 
        agent = pagent

        if not isok then 
            return { "login", 1, -1, "请求mgr失败" }
        end 
    end 
    -- 回应gate
    local isok, key = skynet.call(gate, "lua", "sure_agent", fd, playerid, agent) 
    
    if not isok then 
        return { "login", 1, key, "gate注册失败" }
    end 

    INFO("[login" .. s.id .. "]: 登录成功 => 用户id：" .. playerid)
    return { "login", 0, key, "登录成功" }
end 

--[[
--      source: 消息发送方，比如某个gateway 
--      fd:     客户端连接标识，由gateway发过来
--      cmd, msg:协议名和协议对象
--]]
s.resp.client = function(source, fd, cmd, msgBS) 
    if s.client[cmd] then 
        local ret_msg = s.client[cmd](fd, msgBS, source)
        skynet.send(source, "lua", "send_by_fd", fd, ret_msg)
    else 
        INFO("[login" .. s.id .. "]: resp.client中找不到[ " .. cmd .. " ]的方法")
    end 
end 

s.start(...)

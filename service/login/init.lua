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
    local msg, types = request:decode("CMD.RegisterRequest", msgBS)  
    
    local sql = string.format("insert into UserInfo (user_id, data) values(%d, %s);", msg.userid, mysql.quote_sql_str(msgBS))
    
    local res = skynet.call("mysql", "lua", "query", sql)
    
    if res then 
        return { "register", 0, "成功注册" }
    else 
        return { "register", 1, "注册失败" }
    end
end

s.client.login = function(fd, msgBS, source) 

    local msg = request:decode("CMD.LoginRequest", msgBS) -- { username = "", password = "", userid =  }

    local sql = string.format("select * from UserInfo where user_id = %d;", msg.userid)
    local res = skynet.call("mysql", "lua", "query", sql)

    -- 账号未注册
    if type(res[1]) ~= "table" then -- 这样判断是由于res返回值找不出问题，这样能判断先用着
        return { "login", 1, -1, "账号未注册" }
    end

    local playerid = msg.userid 
    local playername = msg.username
    local pw = msg.password

    local gate = source -- 转发消息的gateway 服务 
    local agent -- pagent那里必须传出来

    node = skynet.getenv("node") 

    -- 拿到查询的data，decode后判断密码是否有误
    local upw = request:decode("CMD.RegisterRequest", res[1].data)
    if  pw ~= upw.password then 
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

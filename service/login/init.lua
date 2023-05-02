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

    local user_info = {
        user_id = msg.userid, 
        username = msg.username, 
        password = msg.password, 
        email = msg.email, 
        level = 1, 
        experience = 0,
        coin = 0, 
    }
     
    local data = pb.encode("UserInfo", user_info)
    
    local sql = string.format("insert into UserInfo (user_id, data) values(%d, %s);", msg.userid, mysql.quote_sql_str(data))
    
    local res = skynet.call("mysql", "lua", "query", sql)
    
    if res then 
        return json_format({code = "register", status = "success", message = "Already written to the database", data = { id = user_info.user_id, username = user_info.username, password = user_info.password }})
    else 
        return json_format({code = "register", status = "failed", message = "Database not working"})
    end
end

s.client.login = function(fd, msgBS, source) 
    local msg = request:decode("CMD.LoginRequest", msgBS) -- { username = "", password = "", userid =  }

    local sql = string.format("select * from UserInfo where user_id = %d;", msg.userid)
    local res = skynet.call("mysql", "lua", "query", sql)

    -- 账号未注册
    if type(res[1]) ~= "table" then -- 这样判断是由于res返回值找不出问题，这样能判断先用着
        return json_format({code = "login", status = "failed", message = "Account not register"})
    end

    local playerid = msg.userid 
    local playername = msg.username
    local pw = msg.password

    local gate = source -- 转发消息的gateway 服务 
    local agent -- pagent那里必须传出来

    node = skynet.getenv("node") 

    -- 拿到查询的data，decode后判断密码是否有误
    local user_info = pb.decode("UserInfo", res[1].data)

    if  pw ~= user_info.password then 
        return json_format({code = "login", status = "failed", message = "wrong password"})
    else 
        -- 向agentmgr发起请求
        local isok, pagent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gate) 
        agent = pagent

        if not isok then 
            return json_format({code = "login", status = "failed", message = "failed to request agentmgr"})
        end 
    end 
    -- 回应gate
    local isok, token = skynet.call(gate, "lua", "sure_agent", fd, playerid, agent) 
    
    if not isok then 
        return json_format({code = "login", status = "failed", message = "gateway authentication failed"})
    end 

    INFO("[login" .. s.id .. "]: 登录成功 => 用户id：" .. playerid)

    s.send(node, agent, "sure_gate", gate)

    return json_format({code = "login", status = "success", message = "Already login!", data = {token = token}})
end 

--[[
--      source: 消息发送方，比如某个gateway 
--      fd:     客户端连接标识，由gateway发过来
--      cmd, msg:协议名和协议对象
--]]
s.resp.client = function(source, fd, cmd, msgBS) 
    if s.client[cmd] then 
        local ret_msg = s.client[cmd](fd, msgBS, source)
        if ret_msg and type(ret_msg) ~= "boolean" then 
            skynet.send(source, "lua", "send_by_fd", fd, ret_msg)
        end
    else 
        INFO("[login" .. s.id .. "]: resp.client中找不到[ " .. cmd .. " ]的方法")
    end 
end 

s.start(...)

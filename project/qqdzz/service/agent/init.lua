#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"

s.client = {} 
s.gate = nil 

require "scene" -- 由于这个模块用到了s.client，所以要在s.client定义之后在导入

s.resp.client = function(source, cmd, msg)
    s.gate = source -- 保存玩家对应gateway的id，后续多文件分模块存放代码。可让agent的所有模块获得该值
    if s.client[cmd] then 
        local ret_msg = s.client[cmd]( msg, source )
        if ret_msg then 
            skynet.send(source, "lua", "send", s.id, ret_msg)
        end 
    else 
        -- 一个连接连续输入login，那么会输出这里。
        -- 会走到gateway的else中，向agent而不是login服务发消息。 
        -- login函数在agent中不存在，即s.client[login]=nil
        skynet.error("s.resp.client fail ", cmd)
    end 
end 

s.client.work = function(msg)
    -- [[ work,100 ]] -- 协议名，金币数量
    skynet.error(" [ work start ] ")
    s.data.coin = s.data.coin + 1 
    return { "work", s.data.coin }
end 

-- 客户端掉线
s.resp.kick = function(source) 
    s.leave_scene()  -- 向场景服务请求退出
    -- 这里需要保存用户数据
    skynet.sleep(200)
end 

s.resp.exit = function(source)
    skynet.exit()
end 

s.resp.send = function(source, msg) 
    skynet.send(s.gate, "lua", "send", s.id, msg)
end

s.init = function() 
    skynet.sleep(200)

    s.data = {
        coin = 100, 
        hp = 200, 
    }
end 


--[[
--      agentmgr: s.call(node, "nodemgr", "newservice", "agent", "agent", playerid)
--
--      nodemgr: skynet.newservice("agent", playerid)
--
--      agent: start("agent", playerid) -> s.name="agent", s.id=playerid
--]]
s.start(...)

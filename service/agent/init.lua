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
        ERROR("[agent]：调用resp.client方法[ " .. cmd .. " ]失败，该方法不存在")
    end 
end 

s.client.work = function(msg)
    -- [[ work,100 ]] -- 协议名，金币数量
    INFO("[agent]：开始[ work ]")
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

-- 通过时间戳获得天数
function get_day(timestamp)
    -- os.time(): 1970.1.1 8:00 -> now
    local day = (timestamp + 3600 * 8) / (3600 * 24) 
    return math.ceil(day)
end

-- 下面定点开启活动代码应该不写在agent中，做一个示例
-- 1970.1.1 -> week4 
-- 周四20:40点为界
function get_week_by_thu2040(timestamp)
    local week = (timestamp + 3600 * 8 - 3600 * 20 - 40 * 60) / (3600 * 24 * 7)
    return math.ceil(week)
end
-- 开启服务器从数据库读取
-- 关闭时应保存
local last_check_time = 1582935650 
-- 每隔一小段时间执行
function timer() 
    local last = get_week_by_thu2040(last_check_time)
    local now = get_week_by_thu2040(os.time())
    last_check_time = os.time() 
    if now > last then 
        open_activity() -- 开启活动
    end
end

s.init = function() 
    -- 模拟数据从数据库加载
    s.data = {
        coin = 100, 
        last_login_time = 1582725978
    }
    local last_day = get_day(s.data.last_login_time)
    local day = get_day(os.time())

    s.data.last_login_time = os.time() -- update
    -- 判断每天第一次登录
    if day > last_day then 
        -- first_login_day()
    end
end 


--[[
--      agentmgr: s.call(node, "nodemgr", "newservice", "agent", "agent", playerid)
--
--      nodemgr: skynet.newservice("agent", playerid)
--
--      agent: start("agent", playerid) -> s.name="agent", s.id=playerid
--]]
s.start(...)

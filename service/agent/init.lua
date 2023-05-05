#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"
local sharetable = require "skynet.sharetable"

s.client = {} 
s.callbackFunc = {} -- [index_callbackFunc] = callback_func
s.msgJS = {} -- [channel] = msgJS:{index,node,agent} 存储index对应回调函数设置的JSON包:look unsubscribe
s.gate = nil -- resp.sure_gate 登录即认证网关 
s.node = nil
local global_table = nil

require "mail"
require "scene" 
require "friend"
require "chat"

s.resp.client = function(source, cmd, msgBS)
    if s.client[cmd] then 
        local ret_msg = s.client[cmd]( msgBS, source )
        if ret_msg and type(ret_msg) ~= "boolean" then 
            skynet.send(source, "lua", "send", s.id, ret_msg)
        end 
    else 
        -- 一个连接连续输入login，那么会输出这里。
        -- 会走到gateway的else中，向agent而不是login服务发消息。 
        -- login函数在agent中不存在，即s.client[login]=nil
        ERROR("[agent]：调用resp.client方法[ " .. cmd .. " ]失败，该方法不存在")
    end 
end 

s.client.view = function(msgBS, source)
    if check_in_scene() then return end
    local user_info = s.data

    return json_format({ code = "view", status = "success", data = {user_id = user_info.user_id, username = user_info.username, password = user_info.password, email = user_info.email, level = user_info.level, coin = user_info.coin, experience = user_info.experience, last_login_time = os.date("%Y-%m-%d %H:%M:%S", user_info.last_login_time)} })

end

s.client.work = function(msgBS, source)
    if check_in_scene() then return end
    -- [[ work,100 ]] -- 协议名，金币数量
    INFO("[agent]：开始[ work ]")
    s.data.coin = s.data.coin + 1
    return json_format({code = "work", status = "success", message = "coin += 1", data = {coin = s.data.coin}})
end 

-- 保存数据，可以玩家主动保存
s.client.save_data = function(msgBS, source) 
    if check_in_scene() then return end

    local user_info = pb.encode("UserInfo", s.data)
    local sql = string.format("update UserInfo set data = %s where user_id = %d;", mysql.quote_sql_str(user_info), s.data.user_id)
    local res = skynet.call("mysql", "lua", "query", sql)
    if not res then 
        return json_format({code = "save_data", status = "failed", message = "Database update failed"})
    end

    return json_format({code = "save_data", status = "success", message = "Successfully update data"})
end

-- 主动离线
s.client.exit = function(msgBS, source)
    ERROR("[agent]：exit")
    skynet.send("agentmgr", "lua", "reqkick", s.id, "主动离线")
end

-- 客户端掉线
s.resp.kick = function(source) 
    if check_in_scene() then -- 在场景中，由场景回调数据保存，并退出
        s.client.leave_scene(nil)
    else -- 手动保存
        s.client.save_data(nil, nil)
    end
end 

s.resp.exit = function(source)
    skynet.exit()
end 

s.resp.send = function(source, msgJS) 
    skynet.send(s.gate, "lua", "send", s.id, msgJS)
end

-- 拿到login服务的认证该代理agent的网关信息
s.resp.sure_gate = function(source, gate)
    s.gate = gate 
end

-- 游戏场景退出的数据保存
s.resp.save_data = function(source, score)
    s.data.experience = s.data.experience + score 
    while s.data.experience >= s.data.level * 10 do
        s.data.experience = s.data.experience - s.data.level * 10 
        s.data.level = s.data.level + 1
        s.resp.send(nil, json_format({_cmd = "upgrade", message = string.format("Congratulations on upgrading to level [%d] !", s.data.level) })) 
    end
    
    s.data.coin = s.data.coin + score * 10
    s.client.save_data() 
end

-- 订阅模式下，回调索引映射的函数
s.resp.callback = function(source, index, channel, message)
    if not index or index == nil then 
        return nil
    end
    s.callbackFunc[index](channel, message)
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

function first_login_day()
    INFO("[agent]：检测到当天首次登录~~~")
    s.data.experience = s.data.experience + 1 
end

-- 游戏大厅回调索引映射函数
local game_center_handle = function(channel, message)
    s.resp.send(nil, cjson.encode({message}))
end

-- 游戏场景回调索引映射函数
local game_scene_handle = function(channel, message) 
    s.resp.send(nil, cjson.encode({message})) 
end

-- 获取唯一index回调映射
local function get_index()
    local res = skynet.call("msgserver", "lua", "get_index")
    return res
end

-- 通过channel返回对应回调函数
local function channel_to_callbackFunc(channel)
    if channel == "game_center" then 
        return game_center_handle
    end
    if string.find(channel, "scene") then -- st, ed
        return game_scene_handle 
    end
end

function subscribe(channel) 
    if not s.msgJS[channel] then 
        local index = get_index()
        s.callbackFunc[index] = channel_to_callbackFunc(channel)
        s.msgJS[channel] = cjson.encode({ index = index, node = s.node, agent = skynet.self() })
    end
    ERROR(string.format("subcribe channel = %s", channel))
    skynet.send("msgserver", "lua", "subscribe", channel, s.msgJS[channel])
end

function unsubscribe(channel) 
    if not s.msgJS[channel] then return end
    ERROR(string.format("unsubcribe channel = %s", channel))
    skynet.send("msgserver", "lua", "unsubscribe", channel, s.msgJS[channel])
end

s.init = function() 
    s.node = skynet.getenv("node")
    global_table = global_table or sharetable.query("global_table")
    s.status = global_table.STATUS.CENTER -- 不用send，agentmgr已经同步

    local sql = string.format("select * from UserInfo where user_id = %d;", s.id)
    local res = skynet.call("mysql", "lua", "query", sql)
    local user_info = pb.decode("UserInfo", res[1].data)
    
    -- 玩家信息初始化到cache: s.data
    s.data = {
        user_id = user_info.user_id,
        username = user_info.username,
        password = user_info.password, 
        email = user_info.email,
        level = user_info.level, 
        experience = user_info.experience, 
        coin = user_info.coin, 
        last_login_time = user_info.last_login_time,
    }
    
    local last_day = get_day(s.data.last_login_time)
    local day = get_day(os.time())

    s.data.last_login_time = os.time() -- update

    -- 判断每天第一次登录
    if day > last_day then 
        first_login_day()
    end

    -- 玩家邮件初始化cache: s.mail_message, s.mail_count
    local sql = string.format("select * from UserMail where `user_id` = %d;", s.id)
    local result = skynet.call("mysql", "lua", "query", sql)

    for i, v in pairs(result) do 
        local msgJS = cjson.encode(v)
        -- 一个问题就是：is_read, is_rewarded存进mysql 
        -- 会是0,而不是false; 可以考虑在这里修改，暂时不管
        table.insert(s.mail_message, msgJS)
        s.mail_count = s.mail_count + 1
    end

    -- 订阅频道
    -- ps: skynet.send中pack参数不能serialize type function 
    -- 序列化会转二进制，丢失upvalue
    --  1. string.dump(func) -> load(func)()
    subscribe("game_center")
end 

s.start(...)
--[[
--      agentmgr: s.call(node, "nodemgr", "newservice", "agent", "agent", playerid)
--
--      nodemgr: skynet.newservice("agent", playerid)
--
--      agent: start("agent", playerid) -> s.name="agent", s.id=playerid
--]]

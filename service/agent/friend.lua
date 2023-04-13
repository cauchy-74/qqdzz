#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"

-- { 加好友用法：add_friend friend_id message }
-- { proto:      friend_id, message, user_id }
s.client.add_friend = function(msgBS) 
    local msg = request:decode("CMD.AddFriendRequest", msgBS) 
    msg.user_id = s.id 

    --[[
    local online = skynet.call("agentmgr", "lua", "get_online_id", msg.friend_id)

    if online then -- 对方在线
        local node = skynet.call("agentmgr", "lua", "get_user_node", msg.friend_id) 
        local agent = skynet.call("agentmgr", "lua", "get_user_agent", msg.friend_id)
        ERROR("node = " .. node .. " agent = " .. agent)
        if node and agent then
            s.send(node, agent, "reqaddfriend", pb.encode("CMD.AddFriendRequest", msg))
        end
    else -- 对方不在线 
         
    end
    ]]
    local t = {
        from = s.id, 
        to = msg.friend_id, 
        message = msg.message, 
        time = os.date("%Y-%m-%d %H:%M:%S", os.time()),
        channel = CHANNEL.ADD_FRIEND_REQ
    }  
    local msgJS = cjson.encode(t) 
    skynet.send("msgserver", "lua", "recv_mail", msgJS)
    return nil
end

-- 删除好友
s.client.del_friend = function(msgBS)
    local msg = request:decode("CMD.DelFriendRequest", msgBS)
    local data = { type = "del_friend", from = s.id, to = msg.friend_id, msg = "del friend"}
    skynet.send("msgserver", "lua", "publish", "friend", data)
    return nil
end

-- 询问是否是好友
s.client.is_friend = function(msgBS)
    local msg = request:decode("CMD.IsFriendRequest", msgBS) 
    local friend_id = tonumber(msg.friend_id)

    local sql = string.format("select * from FriendInfo where user_id = %d and friend_id = %d;", s.id, friend_id)
    local res = skynet.call("mysql", "lua", "query", sql)
    if res and res[1] then 
        s.send(s.node, s.gate, "send", s.id, cjson.encode({ "yes, is friend!" }))
    end
end

-- 先放着
s.resp.reqaddfriend = function(source, msgBS) 
    local msg = pb.decode("CMD.AddFriendRequest", msgBS)
    INFO("[agent]：用户" .. s.id .. "收到来自用户" .. msg.user_id .. "的新邮件~~~") 

    s.send(s.node, s.gate, "send", s.id, cjson.encode({ "receive a new mail~~~" }))

    local msgJS = cjson.encode({
        [1] = { mail_type = CHANNEL.ADD_FRIEND_REQ },
        [2] = { from = msg.user_id },
        [3] = { title = "add_friend" },
        [4] = { content = msg.message },
        [5] = { time = os.date("%Y-%m-%d %H:%M:%S", os.time()) }
    })

    table.insert(s.mail_message, msgJS)
end

-- 处理加好友请求 
-- yes / no 
-- insert mysql
function mail_friend_handle(msgJS)
    local msg = cjson.decode(msgJS)
    local message = msg.message
    local from = msg.from 
    local to = msg.to

    if message == "yes" or message == "YES" or message == "Yes" then 
        local sql1 = string.format("insert into FriendInfo (user_id, friend_id) values (%d, %d);", from, to)
        local sql2 = string.format("insert into FriendInfo (user_id, friend_id) values (%d, %d);", to, from)
        skynet.send("mysql", "lua", "query", sql1) 
        skynet.send("mysql", "lua", "query", sql2) 

    elseif message == "no" or message == "No" or message == "NO" then 
        
    end
end

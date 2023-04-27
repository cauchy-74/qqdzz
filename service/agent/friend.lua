#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"

-- { 加好友用法：add_friend friend_id message }
-- { proto:      friend_id, message, user_id }
s.client.add_friend = function(msgBS) 
    local msg = request:decode("CMD.AddFriendRequest", msgBS) 
    msg.user_id = s.id 

    local is_friend_msgBS = request:encode({"is_friend", msg.friend_id})
    if s.client.is_friend(is_friend_msgBS) then 
        s.resp.send(nil, json_format({code = "add_friend", status = "false", message = "Already be friends"}))
        return nil
    end

    local t = {
        from = s.id, 
        to = msg.friend_id, 
        message = msg.message, 
        time = os.date("%Y-%m-%d %H:%M:%S", os.time()),
        channel = MAIL_CHANNEL.ADD_FRIEND_REQ
    }  
    local msgJS = cjson.encode(t) 
    skynet.send("msgserver", "lua", "recv_mail", msgJS)
    return nil
end

-- 删除好友
s.client.del_friend = function(msgBS)
    local msg = request:decode("CMD.DelFriendRequest", msgBS)

    local is_friend_msgBS = request:encode({"is_friend", msg.friend_id})
    if not s.client.is_friend(is_friend_msgBS) then 
        s.resp.send(nil, json_format({code = "del_friend", status = "failed", message = "You are not friend!"}))
        return nil
    end

    local sql = string.format("delete from FriendInfo where user_id = %d and friend_id = %d;", s.id, msg.friend_id)
    skynet.send("mysql", "lua", "query", sql)
    local sql = string.format("delete from FriendInfo where user_id = %d and friend_id = %d;", msg.friend_id, s.id)
    skynet.send("mysql", "lua", "query", sql)

    s.resp.send(nil, json_format({code = "del_friend", status = "success", message = "OK~, Be a stranger~"}))
    return nil 
end

-- 询问是否是好友
s.client.is_friend = function(msgBS)
    local msg = request:decode("CMD.IsFriendRequest", msgBS) 
    local friend_id = tonumber(msg.friend_id)

    local sql = string.format("select * from FriendInfo where user_id = %d and friend_id = %d;", s.id, friend_id)
    local res = skynet.call("mysql", "lua", "query", sql)
    if res and res[1] then 
        return true
    end
    return false
end

-- 好友列表查看
s.client.list_friend = function(msgBS)
    local sql = string.format("select * from FriendInfo where user_id = %d;", s.id)
    local result = skynet.call("mysql", "lua", "query", sql)

    local ret = {code = "list_friend", status = "success", message = "", data = {}}

    if result then 
        ret.message = "There are your friends"
        for _, row in ipairs(result) do
            ret.data[_] = row.friend_id 
        end
    else 
        ret.message = "No friends~"
        ret.data = nil
    end
    s.resp.send(nil, json_format(ret))
end

-- 先放着
s.resp.reqaddfriend = function(source, msgBS) 
    local msg = pb.decode("CMD.AddFriendRequest", msgBS)
    INFO("[agent]：用户" .. s.id .. "收到来自用户" .. msg.user_id .. "的新邮件~~~") 

    s.send(s.node, s.gate, "send", s.id, cjson.encode({ "receive a new mail~~~" }))

    local msgJS = cjson.encode({
        [1] = { mail_type = MAIL_CHANNEL.ADD_FRIEND_REQ },
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

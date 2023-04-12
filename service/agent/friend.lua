#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

s.client.add_friend = function(msgBS) 
    local msg = request:decode("CMD.AddFriendRequest", msgBS) 
    local data = { type = "add_friend", user_id = s.id, friend_id = msg.friend_id, msg = "add friend"}
    skynet.send("msgserver", "lua", "publish", "friend", data) 
end

s.client.del_friend = function(msgBS)
    local msg = request:decode("CMD.DelFriendRequest", msgBS)
    local data = { type = "del_friend", user_id = s.id, friend_id = msg.friend_id, msg = "del friend"}
    skynet.send("msgserver", "lua", "publish", "friend", data)
end

s.client.sure_friend = function(msgBS)
    local msg = request:decode("CMD.SureFriendResponse", msgBS)
    local data = { type = "sure_friend", user_id = s.id, friend_id = msg.friend_id, msg = msg.message}
    skynet.send("msgserver", "lua", "publish", "friend", data)
end



#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"

-- 聊天功能 0:大厅/场景； 1~:好友
-- proto: { obj_id, message, channel }
s.client.chat = function(msgBS)
    local msg = request:decode("CMD.ChatRequest", msgBS)
    local obj_id = msg.obj_id

    -- 指令id优先于message，nil无用
    if obj_id == 0 or obj_id == nil then 
        -- channel: 大厅全部; 游戏中的房间全部
        
        if s.sname == nil then 
            -- game_center: 游戏大厅
            local str = string.format("『ID: %d』: %s", tonumber(s.id), msg.message)
            skynet.send("msgserver", "lua", "publish", "game_center", str)  
        else
            -- sceneid: 游戏场景
            local str = string.format("『ID: %d』: %s", tonumber(s.id), msg.message)
            skynet.send("msgserver", "publish", s.sname, str)
        end

    else -- 指定好友私聊
        -- 判断好友关系
        local is_friend_msgBS = request:encode({ "is_friend", obj_id })
        if not s.client.is_friend(is_friend_msgBS) then
            return nil
        end
        
        -- 发送给对方
        -- 感觉应该整合到msgserver中，先这样写把
        
        -- 判断对方是否在线： 之后加数据库写成离线
        local online = skynet.call("agentmgr", "lua", "get_online_id", obj_id)
        ERROR(tostring(online))
        if not online then 
            s.resp.send(nil, cjson.encode({ "friend is not online" })) 
            return nil
        end

        local str = string.format("『Recv Msg from %d』: %s", tonumber(s.id), msg.message)
        local node = skynet.call("agentmgr", "lua", "get_user_node", obj_id)
        local agent = skynet.call("agentmgr", "lua", "get_user_agent", obj_id)

        s.send(node, agent, "send", cjson.encode({ str }))

        --[[ 邮件形式发送
        local msg = { "mail_send", obj_id, msg.message, MAIL_CHANNEL.NORMAL, s.id }
        local msgBS = request:encode(msg) 
        s.client.mail_send(msgBS)
        ]]
    end
end

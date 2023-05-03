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
        
        if not check_in_scene() then 
            -- game_center: 游戏大厅
            local str = string.format("『ID: %d』: %s", tonumber(s.id), msg.message)
            skynet.send("msgserver", "lua", "publish", "game_center", str)  
        else
            -- sceneid: 游戏场景
            local str = string.format("【%s】『ID: %d』: %s", s.sname, tonumber(s.id), msg.message)
            skynet.send("msgserver", "lua", "publish", s.sname, str)
        end

    else -- 指定好友私聊
        -- 判断好友关系
        local is_friend_msgBS = request:encode({ "is_friend", obj_id })
        if not s.client.is_friend(is_friend_msgBS) then
            s.resp.send(nil, json.format({code = "chat", status = "failed", message = "No, You are not friend" }))
            return nil
        end
        
        -- 发送给对方
        -- 感觉应该整合到msgserver中，先这样写把
        
        -- 判断对方是否在线： 之后加数据库写成离线
        local online = skynet.call("agentmgr", "lua", "get_online_id", obj_id)

        -- 拿到消息，对象的node，agent
        local str = string.format("『Recv Msg from %d』: %s", tonumber(s.id), msg.message)
        local node = skynet.call("agentmgr", "lua", "get_user_node", obj_id)
        local agent = skynet.call("agentmgr", "lua", "get_user_agent", obj_id)

        -- 拿到FriendChat表的小id和大id
        local lowid, upid = tonumber(s.id), tonumber(obj_id)
        if lowid > upid then 
            lowid, upid = upid, lowid
        end

        local timestamp = os.time()
        local time = os.date("%Y-%m-%d %H:%M:%S", timestamp)

        local sql = string.format("insert into FriendChat (lowid, upid, time, timestamp, message) values (%d, %d, '%s', %d, %s);", lowid, upid, time, timestamp, mysql.quote_sql_str(str))
        skynet.send("mysql", "lua", "query", sql)

        if online then  -- 在线直接发过去
            s.send(node, agent, "send", cjson.encode({ str }))
        end
    end
end

-- 查看聊天列表
-- 使用：{ "list_chat", 0/1~ }
-- proto: { list_type }
s.client.list_chat = function(msgBS)
    local msg = request:decode("CMD.ListChatRequest", msgBS)
    local list_type = msg.list_type
    local chats = {} -- 聊天记录表
    local sort_chats = {} -- 排序后的记录表
    -- 这个记录表，可以优化为缓存。但是不想麻烦了

    if list_type == nil or list_type == 0 then 
        -- 大厅   -> Message
        local sql = string.format("select * from Message where timestamp >= %d;", os.time() - 60 * 10) -- 查看过去10分钟的记录
        local result = skynet.call("mysql", "lua", "query", sql)
        if result then 
            for _, row in ipairs(result) do 
                local timestamp = row.timestamp 
                local time = row.time 
                local message = row.message 
                chats[timestamp] = cjson.encode({ [1] = time, [2] = message })
            end
        end
    else 
        -- 好友 1~ -> FriendChat
        local lowid, upid = tonumber(s.id), tonumber(list_type)
        if lowid > upid then 
            lowid, upid = upid, lowid
        end
        
        local sql = string.format("select * from FriendChat where lowid = %d and upid = %d;", lowid, upid) 
        local result = skynet.call("mysql", "lua", "query", sql)
        if result then 
            for _, row in ipairs(result) do 
                local timestamp = row.timestamp
                local time = row.time 
                local msg = row.message 
                chats[timestamp] = cjson.encode({ [1] = time, [2] = msg })
            end
        end
    end

    -- 对chats表，作顺序输出
    for i, v in pairs(chats) do 
        table.insert(sort_chats, i)
    end
    table.sort(sort_chats)

    for _, timestamp in ipairs(sort_chats) do 
        s.resp.send(nil, chats[timestamp]) 
    end
    
    chats = nil
end

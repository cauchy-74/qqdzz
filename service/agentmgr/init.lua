#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"
local sharetable = require "skynet.sharetable"

-- [[ 保存各玩家的节点信息和状态 ]]

--[[ -- 也不成功
sharetable.loadstring("global_table", [[
local global_table = {
    STATUS = {
        LOGIN = 1, 
        CENTER = 2, 
        GAME = 3, 
        LOGOUT = 4,
    }
}
]]--)

local global_table = {
    STATUS = {
        LOGIN = 1, 
        CENTER = 2, 
        GAME = 3, 
        LOGOUT = 4,
    }
}

s.init = function() 
    -- sharetable.loadfile("sharetable.lua") -- 不会阿！
    sharetable.loadtable("global_table", global_table)
end

-- 玩家列表
local players = {} -- [playerid] = mgrplayer

-- 玩家类
function mgrplayer() 
    local m = {
        playerid = nil, 
        node = nil, 
        agent = nil, 
        status = nil, 
        gate = nil, 
    }
    return m
end 

s.resp.reqkick = function(source, playerid, reason) 
    local playerid = tonumber(playerid) -- 转为下标数字

    local mplayer = players[playerid] 
    if not mplayer then 
        return false 
    end 

    if not (mplayer.status == global_table.STATUS.GAME or mplayer.status == global_table.STATUS.CENTER) then 
        return false
    end

    local pnode = mplayer.node 
    local pagent = mplayer.agent 
    local pgate = mplayer.gate 
    mplayer.status = global_table.STATUS.LOGOUT 
    s.send(pnode, pagent, "modify_status", mplayer.status)

    s.call(pnode, pagent, "kick") -- call 保证所有动作完全执行结束, save_data, leave_scene... 
    s.send(pnode, pagent, "exit") 
    s.send(pnode, pgate, "kick", playerid) 
    players[playerid] = nil 

    return true 
end 

s.resp.reqlogin = function(source, playerid, node, gate)
    playerid = tonumber(playerid) 

    local mplayer = players[playerid]
    -- 登录过程禁止顶替
    if mplayer and mplayer.status == global_table.STATUS.LOGOUT then 
        ERROR("[agentmgr]：方法[resp.reqlogin]调用，用户id = " .. playerid .. "状态status = LOGOUT")
        return false 
    end 

    if mplayer and mplayer.status == global_table.STATUS.LOGIN then 
        ERROR("[agentmgr]：方法[resp.reqlogin]调用，用户id = " .. playerid .. "状态status = LOGIN")
        return false 
    end 

    -- 在线, 顶替
    if mplayer then 
        local pnode = mplayer.node 
        local pagent = mplayer.agent 
        local pgate = mplayer.gate 
        mplayer.status = global_table.STATUS.LOGOUT 
        s.send(pnode, pagent, "modify_status", mplayer.status)

        s.call(pnode, pagent, "kick") 
        s.send(pnode, pagent, "exit")
        s.send(pnode, pgate, "send", playerid, json_format({code = "kick", status = "true", message = "Be replaced~~~"}))  -- statuc->true
        s.call(pnode, pgate, "kick", playerid)
    end 

    -- 上线
    local player = mgrplayer() 
    player.playerid = playerid 
    player.node = node 
    player.gate = gate 
    player.agent = nil 
    player.status = global_table.STATUS.LOGIN 
    players[playerid] = player 

    -- send只是发，call会等待回应 -> nodemgr: return srv
    local agent = s.call(node, "nodemgr", "newservice", "agent", "agent", playerid) 
    player.agent = agent 
    player.status = global_table.STATUS.CENTER 
    -- 无需同步，

    return true, agent
end 


-- 将num数量玩家踢下线
s.resp.shutdown = function(source, num)
    -- 当前玩家数
    local count = s.resp.get_online_count()    
    local n = 0
    for playerid, player in pairs(players) do 
        skynet.fork(s.resp.reqkick, nil, playerid, "close server")
        n = n + 1
        if n >= num then 
            break
        end
    end
    -- 等待玩家下线
    while true do 
        skynet.sleep(200)
        local new_count = s.resp.get_online_count() 
        ERROR("[agentmgr]：方法[shutdown]调用，当前在线玩家online = " .. new_count) 
        if new_count <= 0 or new_count <= count - num then 
            return new_count
        end
    end
end

-- 获取在线人数
s.resp.get_online_count = function(source) 
    local count = 0
    for playerid, player in pairs(players) do 
        count = count + 1
    end
    return count
end

-- 修改玩家状态
s.resp.modify_status = function(source, id, status)
    id = tonumber(id)
    players[id].status = status 
    ERROR(string.format("[agentmgr]：player [%d] status modify to %s", id, status))
end

-- 获取玩家状态
s.resp.get_online_id = function(source, id)
    local id = tonumber(id)
    if players[id] == nil then return false end 
    return players[id].status
end

-- 获取玩家所在节点
s.resp.get_user_node = function(source, id)
    local id = tonumber(id)
    if not players[id] then return nil end 
    return players[id].node
end

-- 获取玩家所在代理
s.resp.get_user_agent = function(source, id)
    local id = tonumber(id)
    if not players[id] then return nil end
    return players[id].agent
end

-- 获取玩家所在网关
s.resp.get_user_gate = function(source, id)
    local id = tonumber(id)
    if not players[id] then return nil end
    return players[id].gate
end

s.start(...)

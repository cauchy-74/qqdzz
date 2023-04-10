#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"

-- [[
--      保存各玩家的节点信息和状态
-- ]]

-- 登录中，游戏中，登出中
STATUS = {
    LOGIN = 2, 
    GAME = 3, 
    LOGOUT = 4, 
}

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
    playerid = tonumber(playerid) -- 转为下标数字

    local mplayer = players[playerid] 
    if not mplayer then 
        return false 
    end 

    if mplayer.status ~= STATUS.GAME then 
        return false 
    end 

    local pnode = mplayer.node 
    local pagent = mplayer.agent 
    local pgate = mplayer.gate 
    mplayer.status = STATUS.LOGOUT 

    s.call(pnode, pagent, "kick") 
    s.send(pnode, pagent, "exit") 
    s.send(pnode, pgate, "kick", playerid) 
    players[playerid] = nil 

    return true 
end 

s.resp.reqlogin = function(source, playerid, node, gate)
    local mplayer = players[playerid]
    -- 登录过程禁止顶替
    if mplayer and mplayer.status == STATUS.LOGOUT then 
        ERROR("[agentmgr]：方法[resp.reqlogin]调用，用户id = " .. playerid .. "状态status = LOGOUT")
        return false 
    end 

    if mplayer and mplayer.status == STATUS.LOGIN then 
        ERROR("[agentmgr]：方法[resp.reqlogin]调用，用户id = " .. playerid .. "状态status = LOGIN")
        return false 
    end 

    -- 在线, 顶替
    if mplayer then 
        local pnode = mplayer.node 
        local pagent = mplayer.agent 
        local pgate = mplayer.gate 
        mplayer.status = STATUS.LOGOUT 
        s.call(pnode, pagent, "kick") 
        s.send(pnode, pagent, "exit")
        s.send(pnode, pgate, "send", playerid, { "kick", "顶替下线" }) 
        s.call(pnode, pgate, "kick", playerid)
    end 

    -- 上线
    local player = mgrplayer() 
    player.playerid = playerid 
    player.node = node 
    player.gate = gate 
    player.agent = nil 
    player.status = STATUS.LOGIN 
    players[playerid] = player 

    -- send只是发，call会等待回应 -> nodemgr: return srv
    local agent = s.call(node, "nodemgr", "newservice", "agent", "agent", playerid) 
    player.agent = agent 
    player.status = STATUS.GAME 

    return true, agent
end 

-- 获取在线人数
function get_online_count() 
    local count = 0
    for playerid, player in pairs(players) do 
        count = count + 1
    end
    return count
end

-- 将num数量玩家踢下线
s.resp.shutdown = function(source, num)
    -- 当前玩家数
    local count = get_online_count()    
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
        local new_count = get_online_count() 
        ERROR("[agentmgr]：方法[resp.shutdown]调用，当前在线玩家online = " .. new_count) 
        if new_count <= 0 or new_count <= count - num then 
            return new_count
        end
    end
end

s.start(...)

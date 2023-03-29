#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

-- [[
--          scene模块
--      用于agent与scene之间的连接,通信
--      处理agent的战斗逻辑（后续开发邮件，成就也要新建文件）
--      每个文件处理一项功能
-- ]]

s.snode = nil -- scene_node 
s.sname = nil -- scene_id 

-- 随机选择节点，agent应尽可能进入同节点。所以模拟数倍
local function random_scene()
    -- 选择node
    local nodes = {} 
    for i, v in pairs(runconfig.scene) do 
        table.insert(nodes, i) 
        if runconfig.scene[mynode] then 
            table.insert(nodes, mynode)
        end
    end

    local idx = math.random( 1, #nodes ) 
    local scenenode = nodes[idx]
    -- 具体场景
    local scenelist = runconfig.scene[scenenode] 
    local idx = math.random( 1, #scenelist ) 
    local sceneid = scenelist[idx]
    return scenenode, sceneid
end

-- [[
--      1. s.snode: 对应场景节点； s.sname: 对应场景名字
--      2. random_scene(): 随机一个场景服务
--      3. 向scene发送enter
-- ]]
s.client.enter = function(msg)
    if s.sname then 
        return { "enter", 1, "已在场景" }
    end

    local snode, sid = random_scene()
    local sname = "scene" .. sid 
    local isok = s.call(snode, sname, "enter", s.id, mynode, skynet.self())
    if not isok then 
        return { "enter", 1, "进入失败" }
    end 
    s.snode = snode 
    s.sname = sname 
    return nil 
end

s.client.shift = function(msg)
    if not s.name then 
        return 
    end 
    local x = msg[2] or 0 
    local y = msg[3] or 0 
    s.call(s.snode, s.name, "shift", s.id, x, y)
end

s.leave_scene = function() 
    if not s.name then 
        return 
    end 
    s.call(s.snode, s.sname, "leave", s.id) -- s.id这里不清楚是哪个模块的id，按实际应该是playerid
    s.snode = nil 
    s.sname = nil
end

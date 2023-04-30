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
s.client.enter_scene = function(msgBS)
    if s.sname then 
        return json_format({code = "enter_scene", status = "failed", message = "Already in the scene"}) 
    end

    local msg = request:decode("CMD.EnterSceneRequest", msgBS)

    local snode, sid
    -- 不存在的字段，在request中，置为了字符串nil
    if msg.sceneid ~= "nil" then 
        -- 如果指定了场景：默认本节点
        snode, sid = mynode, msg.sceneid
    else
        snode, sid = random_scene()
    end

    local sname = "scene" .. sid 
    local isok = s.call(snode, sname, "enter_scene", tonumber(s.id), mynode, skynet.self())
    if not isok then 
        return json_format({code = "enter_scene", status = "failed", message = "Enter scene failed!"}) 
    end 
    s.snode = snode 
    s.sname = sname 
    INFO("[agent/scene]：成功进入场景[" .. s.sname .. "]")

    return json_format({code = "enter_scene", status = "success", message = "Enter into scene~"}) 
end

local move = function(toward)
    if not s.sname then 
        return nil
    end 
    s.send(s.snode, s.sname, "move", tonumber(s.id), tonumber(toward))
end

s.client.w = function(msgBS)
    move(1) 
end
s.client.s = function(msgBS)
    move(2)
end
s.client.a = function(msgBS)
    move(3)
end
s.client.d = function(msgBS)
    move(4)
end
s.client.c = function(msgBS)
    local msg = request:decode("CMD.cRequest", msgBS)
    if msg.range and msg.range ~= 0 then 
        -- 1~: 全局视野 
        return s.call(s.snode, s.sname, "get_ALL", tonumber(s.id))
    end
    return s.call(s.snode, s.sname, "get_AOI", tonumber(s.id))
end

s.client.m = function(msgBS)
    local msg = request:decode("CMD.mRequest", msgBS)
    if msg.range and msg.range ~= 0 then 
        -- 1~: 全局可视化地图
        return s.call(s.snode, s.sname, "get_map", tonumber(s.id))
    end
    return s.call(s.snode, s.sname, "get_map_AOI", tonumber(s.id))
end

s.client.leave_scene = function(msgBS) 
    if not s.sname then 
        return json_format({code = "leave_scene", status = "failed", message = "Not in any scene"})
    end 
    
    local msg = request:decode("CMD.LeaveSceneRequest", msgBS)

    if msg.sceneid ~= "nil" and ("scene" .. msg.sceneid) ~= s.sname then 
        return json_format({code = "leave_scene", status = "failed", message = "Not in any scene"})
    end

    local isok = s.call(s.snode, s.sname, "leave_scene", tonumber(s.id))

    if not isok then 
        return json_format({code = "leave_scene", status = "failed", message = "leave scene failed!"})
    end

    s.snode = nil 
    s.sname = nil
    return json_format({code = "leave_scene", status = "success", message = "leave scene~"})
end


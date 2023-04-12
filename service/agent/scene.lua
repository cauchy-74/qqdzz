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
        return cjson.encode({
            [1] = {msg_type = "enter_scene_resp"}, 
            [2] = {success = "false"}, 
            [3] = {msg = "already in the scene"}, 
        })
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
    local isok = s.call(snode, sname, "enter_scene", s.id, mynode, skynet.self())
    if not isok then 
        return cjson.encode({
            [1] = {msg_type = "enter_scene_resp"}, 
            [2] = {success = "false"}, 
            [3] = {msg = "enter scene failed"}, 
        })
    end 
    s.snode = snode 
    s.sname = sname 
    INFO("[agent/scene]：成功进入场景[" .. s.sname .. "]")

    return cjson.encode({
        [1] = {msg_type = "enter_scene_resp"}, 
        [2] = {success = "true"}, 
        [3] = {msg = "enter scene success"}, 
    })
end

s.client.shift = function(msg)
    if not s.sname then 
        return nil
    end 
    local x = msg[2] or 0 
    local y = msg[3] or 0 
    s.call(s.snode, s.sname, "shift", s.id, x, y)

    return cjson.encode({
        [1] = {msg_type = "shift_resp"}, 
        [2] = {success = "true"}, 
        [3] = {msg = "shift"}, 
    })
end

s.client.leave_scene = function(msgBS) 
    if not s.sname then 
        return cjson.encode({
            [1] = {msg_type = "leave_scene_resp"}, 
            [2] = {success = "false"}, 
            [3] = {msg = "not in scene"}, 
        })
    end 
    
    local msg = request:decode("CMD.LeaveSceneRequest", msgBS)

    if msg.sceneid ~= "nil" and ("scene" .. msg.sceneid) ~= s.sname then 
        return cjson.encode({
            [1] = {msg_type = "leave_scene_resp"}, 
            [2] = {success = "false"}, 
            [3] = {msg = "not in scene"}, 
        })
    end

    local isok = s.call(s.snode, s.sname, "leave_scene", s.id)

    if not isok then 
        return cjson.encode({
            [1] = {msg_type = "leave_scene_resp"}, 
            [2] = {success = "false"}, 
            [3] = {msg = "leave scene failed"}, 
        })
    end

    s.snode = nil 
    s.sname = nil
    return cjson.encode({
        [1] = {msg_type = "leave_scene_resp"}, 
        [2] = {success = "true"}, 
        [3] = {msg = "leave scene success"}, 
    })
end


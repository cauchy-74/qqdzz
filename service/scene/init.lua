#!/usr/local/bin/lua

local skynet = require "skynet"
local cluster = require "skynet.cluster"
local s = require "service"

require "AOI" -- Area of Interst, + collision
require "visual" -- 可视化地图

space = {
    entities = {}, -- id 
    grid = {} -- entity
}
walk = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}

local food_maxid = 0 
food_count = 0 -- collision 对食物计数
foods = {} -- [-id] = food 

local ball_count = 0
balls = {} -- [playerid] = ball 

-- 小球类
function ball() 
    local m = {
        playerid = nil,  -- 玩家id
        node = nil,      -- 所处节点
        agent = nil,     -- 代理id
        x = math.random( 1, 20 ), 
        y = math.random( 1, 50 ), 
        size = 1,        -- 尺寸
        hp = 1,
        score = 0,
        speedx = 0,      -- 移速
        speedy = 0, 
    }
    setmetatable(m, entity)
    return m
end

-- 辅助方法，收集所有小球，构建balllist协议
local function balllist_msg() 
    local msg = { _cmd = "balllist", data = {} } 
    for i, v in pairs(balls) do 
        local player_info = {}
        table.insert( player_info, v.playerid )
        table.insert( player_info, v.x )
        table.insert( player_info, v.y )
        table.insert( player_info, v.size )
        local str_player_info = "(" .. table.concat(player_info, ", ") .. ")" 
        table.insert(msg.data, str_player_info)
    end 
    return json_format(msg)
end 

-- 食物类
function food()
    local m = {
        id = nil, 
        x = math.random( 0, 20 ), 
        y = math.random( 0, 50 ), 
    }
    setmetatable(m, entity)
    return m
end 

-- 辅助方法，收集所有食物，构建foodlist协议
local function foodlist_msg()
    local msg = { _cmd = "foodlist", data = {} }
    for i, v in pairs(foods) do 
        local food_info = {}
        table.insert( food_info, v.id )
        table.insert( food_info, v.x )
        table.insert( food_info, v.y )
        local str_food_info = "(" .. table.concat(food_info, ", ") .. ")"
        table.insert(msg.data, str_food_info)
    end 
    return json_format(msg)
end 

-- 广播
function broadcast(msg)
    msg = cjson.encode(msg)
    for i, v in pairs(balls) do 
        s.send(v.node, v.agent, "send", msg)
    end 
end 

--[[
--      1. 判断能否进入
--      2. 创建对象
--      3. 向其他玩家广播enter协议（broadcast）
--      4. 存入balls 
--      5. 回应成功信息（enter） 
--      6. 向玩家发送战场信息（balllist，foodlist）协议
--]]
s.resp.enter_scene = function(source, playerid, node, agent) 
    playerid = tonumber(playerid)
    if balls[playerid] then 
        ERROR("balls exist the ball")
        return false
    end 

    -- 初始化
    local b = ball() 
    b.playerid = playerid 
    b.node = node 
    b.agent = agent 
    b.id = b.playerid

    -- 广播
    local msg = string.format("player [%d] enter_scene~", playerid)
    local entermsg = { message = msg } 
    broadcast(entermsg)
    -- 记录
    balls[playerid] = b
    -- 插入地图
    add_entity_grid(b)
    -- 插入全局视野
    add_entity_entities(b)
    -- AOI 
    update_entity_AOI(b)
    -- 统计玩家数
    ball_count = ball_count + 1

    -- 回应
    local ret_msg = json_format({code = "enter_scene", status = "success", message = "Successfully entered!"})
    s.send(b.node, b.agent, "send", ret_msg) 

    -- 发战场信息
    s.send(b.node, b.agent, "send", foodlist_msg())
    s.send(b.node, b.agent, "send", balllist_msg())
    return true
end 

-- leave退出协议
s.resp.leave_scene = function(source, playerid) 
    playerid = tonumber(playerid)
    if not balls[playerid] then 
        return false
    end 
    -- 删除全局视野
    del_entity_entities(balls[playerid])
    -- 格子中删除实体
    del_entity_grid(balls[playerid])
    -- 玩家数-1
    ball_count = ball_count - 1
    -- 数据保存 
    s.send(balls[playerid].node, balls[playerid].agent, "save_data", balls[playerid].score) 
    -- 删除balls维护的ball
    balls[playerid] = nil 

    local msg = string.format("player [%d] conduct cmd: [leave_scene]~", playerid)
    local leavemsg = { message = msg } 
    broadcast(leavemsg)
    
    -- 场景销毁
    if ball_count == 0 then 
        cluster.reload()
    end

    return true
end 

-- move移动方向协议
s.resp.move = function(source, playerid, toward)
    local b = balls[playerid] 
    if not b then 
        return false 
    end 
    b:moveto(toward)
    return true
end 

-- 移动逻辑：主循环0.2秒调用一次，路程=速度x时间
-- 广播move协议给所有客户端
function move_update() 
    for i, v in pairs(balls) do 
        v.x = v.x + v.speedx * 0.2 
        v.y = v.y + v.speedy * 0.2 
        if v.speedx ~= 0 or v.speedy ~= 0 then 
            local msg = { "move", v.playerid, v.x, v.y } 
            broadcast(msg)
        end 
    end
end 

-- [[
--      生成食物
--      1. 判断总量，限制28
--      2. 控制时间，（1,100）>=98才可以生成，概率1/50,0.2秒执行一次，所以10秒一个事务
--      3. addfood协议，并更新foods, food_maxid, food_count
-- ]]
function food_update()
    if food_count > 50 then 
        return 
    end 

    if math.random( 1, 100 ) < 98 then 
        return 
    end 

    food_maxid = food_maxid + 1
    food_count = food_count + 1
    local f = food() 
    f.id = -food_maxid
    foods[f.id] = f 

    -- 插入地图
    add_entity_grid(f)

    -- 插入全局视野
    add_entity_entities(f)

    -- 触发视野 
    update_entity_AOI(f)

    local msg = { "addfood", f.id, f.x, f.y } 
    broadcast(msg)
end

-- 吞下食物：eat协议（ball.id, food.id, ball.size）
function eat_update() 
    for pid, b in pairs(balls) do 
        for fid, f in pairs(foods) do 
            if (b.x - f.x)^2 + (b.y - f.y)^2 < b.size^2 then 
                b.size = b.size + 1
                food_count = food_count - 1
                local msg = { "eat", b.playerid, fid, b.size } 
                broadcast(msg)
                foods[fid] = nil
            end
        end
    end
end

function update(frame)
    food_update() 
    -- move_update() 
    -- eat_update() 
    -- 碰撞检测
    -- -- 交由移动逻辑处理，这里只做判断
    -- 分裂
end 

s.init = function()
    INFO("[scene" .. s.id .. "]：已创建！")
    skynet.fork(function()
        -- 保存帧率执行 -- 追帧
        -- 等待时间waittime=0.2-执行时间 [3.13.6书上]
        local stime = skynet.now() 
        local frame = 0 
        while true do 
            frame = frame + 1
            local isok, err = pcall(update, frame)
            if not isok then 
                ERROR(err)
            end
            local etime = skynet.now() 
            local waittime = frame * 20 - (etime - stime)
            if waittime <= 0 then 
                waittime = 2
            end 
            skynet.sleep(waittime)
        end
    end)
end

s.start(...)

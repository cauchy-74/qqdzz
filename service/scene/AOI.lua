#!/usr/local/bin/lua

local s = require "service"

-- 实体
-- id > 0: player 
-- id < 0: food
entity = { id = nil, AOI = {} }
entity.__index = entity

function entity:on_death()
    s.send(self.node, self.agent, "send", json_format({ _cmd = "on_death", message = "Game Over!" }))
    s.send(self.node, self.agent, "leave_scene")

    -- s.resp.leave_scene(nil, self.id)
    -- 出现的问题是，不调度client的主动离场，会有属性未能维护。s.sname,s.snode,subscribe等。所以需要调代理用户的离场回调
end

function entity:get_sight()
    return cjson.encode(self.AOI)
end

-- 视野可见触发，对自己AOI区域操作
function entity:on_enter_sight(id)
    if self.id < 0 or self.id == id then return end
    -- 遍历一边，不在视野范围内才加入
    -- 避免重复加
    for _, v in pairs(self.AOI) do 
        if v == id then 
            return 
        end 
    end
    table.insert(self.AOI, id) -- 暂时先加入，而不区分方向
end

-- 视野不可见触发
function entity:on_leave_sight(id)
    if self.id < 0 or self.id == id then return end
    for i = #self.AOI, 1, -1 do 
        if self.AOI[i] == id then 
            table.remove(self.AOI, i) 
            break
        end
    end
end

-- 格子中可见的触发
function on_enter_grid(x, y, e)
    if not space.grid[x] or not space.grid[x][y] then return end
    for _, v in ipairs(space.grid[x][y]) do 
        v:on_enter_sight(e.id)
        e:on_enter_sight(v.id)
    end
end

-- 格子中不可见的触发
function on_leave_grid(x, y, e)
    if not space.grid[x] or not space.grid[x][y] then return end
    for _, v in ipairs(space.grid[x][y]) do 
        e:on_leave_sight(v.id)
        v:on_leave_sight(e.id)
    end
end

function entity:moveto(toward)
    -- toward: 1-w; 2-s; 3-a; 4-d;
    local dx, dy = walk[toward][1], walk[toward][2]
    if self.x + dx < 1 then return end
    if self.x + dx > 30 then return end
    if self.y + dy < 1 then return end
    if self.y + dy > 50 then return end

    -- 保持连续性移动 (略)
    if toward <= 2 then -- w, s
        for y = -1, 1 do 
            on_enter_grid(self.x + 2 * dx, self.y + y, self)
            on_leave_grid(self.x - dx, self.y + y, self)
        end
    elseif toward <= 4 then -- a, d
        for x = -1, 1 do 
            on_enter_grid(self.x + x, self.y + 2 * dy, self)
            on_leave_grid(self.x + x, self.y - dy, self)
        end
    end 
    del_entity_grid(self)
    self.x = self.x + dx 
    self.y = self.y + dy 
    add_entity_grid(self)
end

local function collision(x, y) 
    local have_ball = false
    for i = #space.grid[x][y], 1, -1 do 
        if space.grid[x][y][i].id > 0 then 
            have_ball = true 
            break
        end 
    end
    -- 没球
    if have_ball == false then return end

    -- 统计球和食物
    local ball_table = {}
    local ball_num = 0 
    local food_table = {}
    local food_num = 0

    for i, v in pairs(space.grid[x][y]) do 
        if v.id < 0 then -- food 
            food_num = food_num + 1
            table.insert(food_table, v)
        elseif v.id > 0 then 
            ball_num = ball_num + 1
            table.insert(ball_table, v)
        end
    end

    -- 所有ball的AOI清空食物
    for _, ball in ipairs(ball_table) do 
        for _, food in ipairs(food_table) do 
            ball:on_leave_sight(food.id)
        end 
    end
    -- 食物清空
    for _, food in ipairs(food_table) do 
        del_entity_grid(food)
        del_entity_entities(food)
    end
    food_count = food_count - food_num -- init.中小球数

    -- 有球，先把得分给第一个球
    local ball = space.grid[x][y][1]
    ball.score = ball.score + food_num

    -- 就一个球
    if ball_num < 2 then return end 

    ERROR("Attack each other ~~")
    -- 两个球以上
    -- 目前规则：有人-1HP，即- ball_num-1滴血
    for _, v in pairs(ball_table) do 
        v.hp = v.hp - ball_num + 1
        if v.hp <= 0 then 
            v:on_death()
        end
    end
end

-- 实体加入格子
function add_entity_grid(e)
    if not space.grid[e.x] then 
        space.grid[e.x] = {}
    end 
    if not space.grid[e.x][e.y] then 
        space.grid[e.x][e.y] = {}
    end
    table.insert(space.grid[e.x][e.y], e)
    collision(e.x, e.y)
end

-- 从格子删除实体
function del_entity_grid(e)
    for i, v in ipairs(space.grid[e.x][e.y]) do
        if v == e then 
            table.remove(space.grid[e.x][e.y], i)
            break
        end
    end
end

function add_entity_entities(e)
    table.insert(space.entities, e.id)
end

-- 删除全局视野
function del_entity_entities(e)
    for i = 1, #space.entities do 
        if space.entities[i] == e.id then
            table.remove(space.entities, i)
            break 
        end
    end
end

-- 实体创建的AOI的刷新
function update_entity_AOI(e)
    e.AOI = {}
    for x = -1, 1 do 
        for y = -1, 1 do 
            on_enter_grid(e.x + x, e.y + y, e)
        end
    end
end

s.resp.get_AOI = function(source, playerid)
    local b = balls[playerid] 
    if not b then 
        return nil
    end 
    return b:get_sight() 
end

s.resp.get_ALL = function(source, playerid)
    return cjson.encode({ data = { now = {balls[playerid].x, balls[playerid].y }, space.entities}}) 
end

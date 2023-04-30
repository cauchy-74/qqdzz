#!/usr/local/bin/lua

local s = require "service"

-- 实体
-- id > 0: player 
-- id < 0: food
entity = { id = nil, AOI = {} }
entity.__index = entity

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
    on_leave_grid(self.x, self.y, self)
    self.x = self.x + dx 
    self.y = self.y + dy 
    on_enter_grid(self.x, self.y, self)
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
end

-- 从格子删除实体
function del_entity_grid(e)
    for i = 1, #space.grid[e.x][e.y] do
        if space.grid[e.x][e.y] == e then 
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
        if space.entities[i] == playerid then
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

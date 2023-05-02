#!/usr/local/bin/lua

local s = require "service"

local map = {}

local char_map = {
    [0] = " ",-- 空地 
    [1] = "*",-- 自己 
    [2] = "o",-- 食物 
    [3] = "x" -- 敌人
}

local map_row = 20
local map_col = 50

-- 返回当前格子对应的char的id:char_map
local function char_type_from_grid(x, y, playerid)
    if not space.grid[x] then return 0 end
    if not space.grid[x][y] then return 0 end
    local grid_table = space.grid[x][y]
    is_food = false
    is_player = false
    is_mine = false 
    for _, v in pairs(grid_table) do 
        if v.id > 0 then is_player = true end 
        if v.id < 0 then is_food = true end
        if v.id == playerid then is_mine = true end
        if is_food or is_mine then 
            break -- 食物，或自己
        end
    end
    if is_food then return 2 end
    if is_mine then return 1 end
    if is_player then return 3 end
    return 0
end

-- 地图刷新
local function update_map(playerid)
    for i = 1, map_row do 
        if not map[i] then map[i] = {} end
        for j = 1, map_col do 
            local char = char_map[char_type_from_grid(i, j, playerid)] 
            map[i][j] = char
        end
    end
end

-- 地图转string
local function map_to_string(playerid)
    update_map(playerid)
    local map_str = ""
    for i = 1, map_col + 2 do map_str = map_str .. '-' end 
    map_str = map_str .. '\n'

    for i = 1, map_row do 
        local str = "|" 
        for j = 1, map_col do 
            str = str .. map[i][j]
        end
        str = str .. "|\n"
        map_str = map_str .. str
    end

    for i = 1, map_col + 2 do map_str = map_str .. '-' end 
    map_str = map_str .. '\n'

    return map_str
end

-- get_map 回调，返回全局map
s.resp.get_map = function(source, playerid) 
    playerid = tonumber(playerid)

    -- skynet.fork ??? -- 处理字符串
    -- 这里返回不要用json，会'\n'字符显示
    return map_to_string(playerid)
end

-- get_map_AOI 回调，返回AOI区域
s.resp.get_map_AOI = function(source, playerid)
    playerid = tonumber(playerid)

    return map_to_string(playerid)
end

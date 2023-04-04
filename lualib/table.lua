#!/usr/local/bin/lua

local mt = {} 

function mt:new()
    local obj = { __index = self }
    return setmetatable(obj, obj)
end

return mt

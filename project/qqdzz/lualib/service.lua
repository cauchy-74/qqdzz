#!/usr/local/bin/lua

local skynet = require "skynet"
local cluster = require "skynet.cluster"

local M = {
    name = "", -- 服务类型
    id = 0, -- 服务编号
    exit = nil,  -- 回调方法
    init = nil,  -- 回调方法
    resp = {}, -- 存放消息处理方法
}

local dispatch = function(session, address, cmd, ...)
    local fun = M.resp[cmd]
    if not fun then 
        skynet.ret()
        return 
    end
     
    -- xpcall : 安全调用fun,出错给traceback
    local ret = table.pack(xpcall(fun, traceback, address, ...))
    local isok = ret[1] -- 第二个参数开始三fun返回值
     
    if not isok then 
        Skynet.ret()
        return 
    end 
     
    -- unpack 从2开始拿到,在返回给发送方
    skynet.retpack(table.unpack(ret, 2))
end 

function init()
    skynet.dispatch("lua", dispatch)
    if M.init then 
        M.init()
    end 
end 

function M.start(name, id, ...)
    M.name = name 
    M.id = id 
    skynet.start(init)
end 

function traceback(err)
    skynet.error(tostring(err))
    skynet.error(debug.traceback())
end 

function M.call(node, srv, ...)
    local mynode = skynet.getenv("node")
    if node == mynode then 
        return skynet.call(srv, "lua", ...)
    else 
        return cluster.call(node, srv, ...)
    end 
end 

function M.send(node, srv, ...)
    local mynode = skynet.getenv("node")
    if node == mynode then 
        return skynet.send(srv, "lua", ...)
    else 
        return cluster.send(node, srv, ...)
    end 
end 

return M

--[[
--      执行流程:
--          1. s = require "service"; s.start() [服务脚本]
--          2. start() [封装层 here]
--          3. skynet.start() [Skynet]
--          4. init() [封装层]
--          5. s.init() [服务脚本]
--]]

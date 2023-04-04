#!/usr/local/bin/lua

local skynet = require "skynet"
local cluster = require "skynet.cluster"
request = require "request" -- lua模块自定义的使用Command.proto

mysql = require "skynet.db.mysql"
-- 添加协议模块的导入
pb = require "pb"
pb.loadfile("./proto/Command.pb")
pb.loadfile("./storage/storage.pb")

local function skylog(str, color)
    return function(...)
        skynet.error(string.format("%s%s%s\x1b[0m", color, str, ...))
    end
end

DEBUG = skylog("【DEBUG】", "\x1b[34m") -- blue
INFO = skylog("【INFO】", "\x1b[37m") -- white
WARNING = skylog("【WARNING】", "\x1b[32m") -- green
ERROR = skylog("【ERROR】", "\x1b[31m") --red 

local M = {
    name = "", -- 服务类型
    id = 0, -- 服务编号
    exit = nil,  -- 回调方法
    init = nil,  -- 回调方法
    resp = {}, -- 存放消息处理方法
    request = request, -- 协议表
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
        skynet.ret()
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
--          3. skynet.start() [skynet]
--          4. init() [封装层]
--          5. s.init() [服务脚本]
--]]

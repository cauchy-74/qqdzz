#!/usr/local/bin/lua

--[[
--      请阅读：
--          1. 这份文件是百万在线书上给的例子，但是运行不通。
--          2. 做一个思路的记录，文档保留。
--          3. 改用gpt提供的思路方法：见Pmain1.lua
--]]

local skynet = require "skynet"
local socketdriver = require "skynet.socket"
local netpack = require "skynet.netpack"

function process_connect(fd, addr)
    skynet.error("new conn fd: " .. fd .. " addr: " .. addr)
    socketdriver.start(fd)
end

function process_close(fd)
    skynet.error("close fd: " .. fd)
end

function process_error(fd, err)
    skynet.error("error fd: " .. fd .. " error: " .. err)
end

function process_warning(fd, size)
    skynet.error("warning fd: " .. fd .. " size: " .. size)
end

function process_msg(fd, msg, sz)
    local str = netpack.tostring(msg, sz) -- c语言数据转lua
    skynet.error("recv from fd: " .. fd .. " str: " .. str)
end

function process_more()
    for fd, msg, sz in netpack.pop, queue do 
        skynet.fork(process_msg, fd, msg, sz)
    end
end

local queue 

-- 解码底层传来的 SOCKET 类型消息
function socket_unpack(msg, sz) 
    return netpack.filter(queue, msg, sz)
end

-- 处理底层传来的 SOCKET 类型消息
function socket_dispatch(_, _, q, types, ...)
    skynet.error("socket_dispatch type " .. (types or nil)) 
    queue = q -- userdata,定义在C编写的netpack模块中。关闭监听需要netpack.clear(queue)释放内存
    if types == "open" then  -- 新连接
        process_connect(...)
    elseif types == "data" then  -- 刚好有一条完整消息
        process_msg(...)
    elseif types == "more" then -- 多条消息
        process_more(...)
    elseif types == "close" then -- 连接关闭
        process_close(...)
    elseif types == "error" then  -- 发生错误
        process_error(...)
    elseif types == "warning" then -- 缓冲区积累数据过多
        process_warning(...)
    end
end

skynet.start(function()
    -- 注册 socket 类型消息 
    skynet.register_protocol({
        name = "socket", 
        id = skynet.PTYPE_SOCKET,
        unpack = socket_unpack, 
        dispatch = socket_dispatch,
    }) -- assert问题，---------------找不出那有问题
    -- 注册 lua 类型消息（skynet.dispatch）
    -- 开启监听
    local listenfd = socketdriver.listen("0.0.0.0", 8888)
    socketdriver.start(listenfd)

    -- [[
    --      socketdriver.nodelay(listenfd) -- 禁用Nagle算法
    --      Nagle:默认开启，发送端多次发送小数据包，会积攒到一定数量在组成大的数据包发送。『节省数据流量（每个TCP都要包含额外信息），增加延迟』
    -- ]]
end)


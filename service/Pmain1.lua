#!/usr/local/bin/lua

local skynet = require "skynet"
local socket = require "skynet.socket"
local netpack = require "skynet.netpack"

-- 定义消息队列和消息类型
--local queue = {}
--local types = {
--    [skynet.PTYPE_SOCKET] = {
--        [netpack.BEGIN] = "open",
--        [netpack.DATA] = "data",
--        [netpack.MORE] = "more",
--        [netpack.END] = "close",
--        [netpack.ERROR] = "error"
--    }
--}

-- 处理网络传输相关的消息
--local function socket_dispatch(msg_type, session, source, msg) 
--    local t, p, sz = netpack.filter(msg, sz)
--    if not t then return end 
--
--    local msg_type = types[t][p]
--    if not msg_type then 
--        skynet.error("Unknown socket message type", t, p)
--        return 
--    end
--    
--    -- 将消息类型和消息数据存入队列
--    table.insert(queue, { msg_type, session, source, msg })
--end

-- 注册 skynet.PTYPE_SOCKET类型协议
--skynet.register_protocol {
--    name = "socket", 
--    id = skynet.PTYPE_SOCKET, 
--    pack = skynet.pack, 
--    unpack = skynet.unpack, 
--    dispatch = function() 
--        local cnt = 0 
--        while true do 
--            local msg = table.remove(queue, 1)
--            if not msg then 
--                break
--            end
--            local msg_type, session, source, msg = unpack(msg)
--            socket_dispatch(msg_type, session, source, msg)
--            cnt = cnt + 1
--            if cnt >= 10000 then  -- 处理一定数量的消息让出控制权，避免阻塞协程
--                cnt = 0
--                skynet.yield()
--            end
--        end
--    end
--}

local queue = {} 

local function handle_message(queue, types, data, sz, session)
    if types == netpack.MESSAGE then 
    elseif types == netpack.OPEN then 
    elseif types == netpack.ERROR then 
    elseif types == netpack.CLOSE then 
    end
end

local function socket_dispatch(queue, fd, msg_type, msg, sz)
    local str = netpack.tostring(msg, sz)
    local types, session, source, msg = netpack.unpack(str)

    assert(msg_type == socket.data)
    handle_message(queue, types, msg, #msg, session)
end

skynet.start(function()

    -- 向Skynet网络服务注册名SOCKET的服务，用于处理网络传输相关的消息
    skynet.dispatch("lua", function(session, address, cmd, ...)
        skynet.ret(skynet.pack("Hello skynet"))
    end) 

    skynet.register_protocol {
        name = "socket",
        id = skynet.PTYPE_SOCKET, 
        unpack = function(msg, sz)
        return netpack.filter(queue, msg, sz)
    end, 
        dispatch = function(_, _, fd, msg_type, msg, sz)
            socket_dispatch(queue, fd, msg_type, msg, sz)
        end
    }

    local address = "0.0.0.0:8888"
    local listenfd = socket.listen(address)
    
    socket.start(listenfd, function(fd, addr)
        socket.start(fd)
    end)

end)

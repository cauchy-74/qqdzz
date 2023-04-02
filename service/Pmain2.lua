local skynet = require "skynet"
local socket = require "skynet.socket"
local netpack = require "skynet.netpack"

local queue = {}  -- 消息队列

local function dispatch_message(queue, types, str, sz)
    netpack.filter(queue, types, str, sz, function(type, data, sz)
        if type == netpack.MESSAGE then
            -- 处理网络消息
            skynet.error("recv:", netpack.tostring(data, sz))
        elseif type == netpack.OPEN then
            -- 处理连接建立
            skynet.error("socket connect from ", skynet.addrinfo(source))
        elseif type == netpack.ERROR then
            -- 处理网络错误
            skynet.error("socket error:", skynet.addrinfo(source))
        elseif type == netpack.CLOSE then
            -- 处理连接关闭
            skynet.error("socket close:", skynet.addrinfo(source))
        end
    end)
end

local function socket_dispatch(queue, fd, msg_type, msg, sz)
    local str = netpack.tostring(msg, sz)
    local types, session, source, msg = netpack.pop(str)

    assert(msg_type == socket.data) -- 仅处理socket data消息类型
    dispatch_message(queue, types, msg, #msg)
end

skynet.start(function()

    skynet.register_protocol {
        name = "socket", 
        pack = function(msg) 
            return netpack.pack(msg)
        end, 
        unpack = function(msg, sz) 
            return netpack.unpack(msg, sz)
        end,
        dispatch = function(_, _, msg) 
           local msg_type, session, source, msg = skynet.unpack(msg) 
        end
    }

    local address = "0.0.0.0:8888"
    local listen_fd = socket.listen(address)
    skynet.error("Listen socket :", address)

    socket.start(listen_fd , function(fd, addr)
        -- 新连接建立
        skynet.error("connect from " .. addr)
        socket.start(fd)  -- 开始处理网络数据
    end, socket_dispatch, queue)  -- 传入socket_dispatch和队列参数
end)


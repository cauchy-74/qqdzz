#!/usr/local/bin/lua

local skynet = require "skynet"
local socket = require "skynet.socket"
local s = require "service"
local runconfig = require "runconfig"

require "skynet.manager"

-- 遍历所有节点上的所有网关
function shutdown_gate()
    for node, _ in pairs(runconfig.cluster) do 
        ERROR(string.format("node ===>>> %s", node))
        local nodecfg = runconfig[node]
        for i, v in pairs(nodecfg.gateway or {}) do 
            local name = "gateway" .. i
            s.call(node, name, "shutdown")
        end

    end
end

-- 向agentmgr发起shutdown请求，并返回当前在线人数
-- 参数3可调节，sleep可调节
-- “缓缓”踢下玩家
function shutdown_agent()
    local anode = runconfig.agentmgr.node 
    while true do 
        local online_num = s.call(anode, "agentmgr", "shutdown", 3) 
        if online_num <= 0 then 
            break 
        end 
        skynet.sleep(100)
    end
end

function stop() 
    -- [[
    --      1. 阻止玩家连入：gateway
    --      2. 所有玩家下线：agent
    --      3. 保存全局数据：
    --      4. 关闭节点
    -- ]]
    shutdown_gate()  
    shutdown_agent()
    -- ... 
    skynet.abort() -- 结束skynet进程
    return "OK"
end

function connect(fd, addr) 
    socket.start(fd)
    socket.write(fd, "Please enter cmd\r\n")
    local cmd = socket.readline(fd, "\r\n")
    if cmd == "stop" then 
        stop() 
    else 
        -- send email to players
        --
    end
end

s.init = function() 
    local listenfd = socket.listen("0.0.0.0", 8888)
    socket.start(listenfd, connect)
end 

s.start(...)

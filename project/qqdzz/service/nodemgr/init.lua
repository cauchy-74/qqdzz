#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"

s.resp.newservice = function(source, name, ...)
    -- agentmgr中，call(node, "nodemgr", "newservice", "agent", "agent", playerid) 
    -- name = "agent"
    -- srv.name = "agent"
    -- srv.id = playerid
    local srv = skynet.newservice(name, ...) 
    return srv
end 

s.start(...)

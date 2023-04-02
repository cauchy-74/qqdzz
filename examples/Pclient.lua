#!/usr/local/bin/lua

package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua;examples/?.lua"
local socket = require "client.socket"


local fd = socket.connect("127.0.0.1", 8888)
socket.usleep(100000)

local bytes = string.pack(">Hc13", 13, "login,101,123")
socket.send(fd, bytes)
socket.usleep(100000)
socket.close(fd)

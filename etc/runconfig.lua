#!/usr/local/bin/lua

--[[
--  描述服务端的拓扑结构
--]]

return {
    cluster = { -- 指明服务端包含两个节点,需要通信,地址
        -- node2 = "127.0.0.1:7772",
        node1 = "127.0.0.1:7771", 
    }, 
    
    agentmgr = { -- 全局唯一的agentmgr服务位于node1
        node = "node1",
    }, 

    scene = { -- node1 开启编号1,2的两个战斗场景服务
        node1 = { 1001, 1002, 1003 },
        node2 = { 1004, 1005 }, 
    }, 

    admin = {
        node1 = { 8888 },
    },

    node1 = {
        gateway = {
            [1] = { port = 8001 }, 
            [2] = { port = 8002 }, 
            [3] = { port = 8003 }, 
            [4] = { port = 8004 }, 
            [5] = { port = 8005 }, 
        },

        login = {
            [1] = {},
            [2] = {},
        },
    },

    node2 = {
        gateway = {
            [6] = { port = 8011 },
            [7] = { port = 8022 },
            [8] = { port = 8033 },
        },

        login = {
            [3] = {},
            [4] = {},
        },
    },
}

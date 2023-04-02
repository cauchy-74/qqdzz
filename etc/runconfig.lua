#!/usr/local/bin/lua

--[[
--  描述服务端的拓扑结构
--]]

return {
    cluster = { -- 指明服务端包含两个节点,需要通信,地址
        node1 = "127.0.0.1:7771", 
        -- node2 = "127.0.0.1:7772",
    }, 
    
    agentmgr = { -- 全局唯一的agentmgr服务位于node1
        node = "node1" 
    }, 

    scene = { -- node1 开启编号1,2的两个战斗场景服务
        node1 = {1001},  -- 1002
        -- node2 = {1003}, 
    }, 

    node1 = {
        gateway = {
            [1] = { port = 8001 }, 
            [2] = { port = 8002 }, 
        },

        login = {
            [1] = {},
            [2] = {},
        },
    },

    node2 = {
        gateway = {
            [1] = { port = 8011 },
            [2] = { port = 8022 },
        },

        login = {
            [1] = {},
            [2] = {},
        },
    },
}

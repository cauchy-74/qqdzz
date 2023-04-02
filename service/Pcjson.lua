#!/usr/local/bin/lua

local skynet = require "skynet"
local cjson = require "cjson"

function test1()
    local msg = {
        _cmd = "balllist", 
        balls = {
            [1] = { id = 102, x = 10, y = 20, s },
            [2] = { id = 103, x = 10, y = 30, s }, 
        }
    }  
    local buff = cjson.encode(msg)
    print(buff)
end

function test2() 
    local buff = 
    [[   
        {
            "_cmd": "enter", 
            "playerid": 101, 
            "x": 10, 
            "y": 20,
            "size": 1
        }
    ]]
    local isok, msg = pcall(cjson.decode, buff)
    if isok then 
        print(msg._cmd) 
        print(msg.playerid)
    else 
        print("error")
    end
end

function json_pack(cmd, msg)
    --[[ 消息长，协议名长，协议名，协议体 ]]
    msg._cmd = cmd 
    local body = cjson.encode(msg) 
    local namelen = string.len(cmd)
    local bodylen = string.len(body)
    local len = namelen + bodylen + 2 
    local format = string.format("> i2 i2 c%d c%d", namelen, bodylen)
    local buff = string.pack(format, len, namelen, cmd, body)
    return buff
end

function json_unpack(buff)
    local len = string.len(buff) 
    local namelen_format = string.format("> i2 c%d", len - 2)
    local namelen, other = string.unpack(namelen_format, buff)
    local bodylen = len - 2 - namelen 
    local format = string.format("> c%d c%d", namelen, bodylen)
    local isok, msg = string.unpack(format, other)
    if not isok or not msg or not msg._cmd or not cmd == msg._cmd then 
        print("error")
        return 
    end 
    return cmd, msg
end

function test3()
    local msg = {
        _cmd = "playerinfo", 
        coin = 100, 
        bag = {
            [1] = { 1001, 1 }, 
            [2] = { 1005, 5 }
        }, 
    }
    -- encode
    local buff_with_len = json_pack("playerinfo", msg)
    local len = string.len(buff_with_len)
    print("len :", len)
    print(buff_with_len)

    --decode 
    local format = string.format(">i2 c%d", len - 2)
    local _, buff = string.unpack(format, buff_with_len)
    local cmd, umsg = json_unpack(buff)
    print("cmd: " .. cmd)
    print("coin: " .. umsg.coin)
    print("sword: " .. umsg.bag[1][2])
end

local pb = require "pb"

function test4() 
    pb.loadfile("./proto/login.pb")
    local msg = {
        id = 101, 
        pw = "123456",
    }
    -- encode
    local buff = pb.encode("cauchy.Login", msg)
    print("len: " .. string.len(buff))
    -- decode
    local umsg = pb.decode("cauchy.Login", buff)
    print("id: " .. umsg.id)
    print("pw: " .. umsg.pw)
end

local mysql = require "skynet.db.mysql"
local db -- 放这里连接会报错，coroutine外部调用

function test5() 
    pb.loadfile("./storage/playerdata.pb") 

    db = mysql.connect ({
        host = "127.0.0.1", 
        port = 3306, 
        database = "test_db", 
        user = "root", 
        password = "root",
        max_packet_size = 1024 * 1024, -- 数据包最大字节数
        on_connect = nil, -- 连接成功的回调函数
    })

    local playerdata = {
        playerid = 1, 
        coin = 2, 
        name = "Tom",
        level = 3, 
        last_login_time = os.time(), 
    }
    local data = pb.encode("playerdata.BaseInfo", playerdata)
    print("len: " .. string.len(data))
    -- local sql = string.format("insert into baseinfo (playerid, data) values (%d, %s);", tonumber(playerdata.playerid), mysql.quote_sql_str(data))

    local sql = string.format("select * from baseinfo where playerid = 1;")

    local res = db:query(sql)

    local data = res[1].data
    local udata = pb.decode("playerdata.BaseInfo", data)
    if res.err then 
        print("error: " .. res.err)
    else 
        print(udata.coin)
        print("ok")
    end

    -- close connect
    db:disconnect()
end

function test6() 
    
end

skynet.start(function()
    -- test1()
    -- test2()
    -- test3()
    -- test4()
    test5()
end)

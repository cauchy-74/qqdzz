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
    pb.loadfile("./storage/UserInfo.pb") 

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
        user_id = 1, 
        username = "Tom",
        password = "123",
        email = "123@qq.com",
        level = 3, 
        experience = 6,
        coin = 2, 
        last_login_time = os.time(), 
    }
    
    db:query("create table UserInfo(user_id int, username varchar(255));")

    -- local data = pb.encode("UserInfo", playerdata)
    -- print("len: " .. string.len(data))
    local sql = string.format("insert into UserInfo (user_id, username) values (%d, %s);", tonumber(playerdata.user_id), playerdata.username)

    -- local sql = string.format("select * from baseinfo where playerid = 1;")

    local res = db:query(sql)
    skynet.error("++++++++++++++++++++++++++++")

    -- local data = res[1].data
    -- local udata = pb.decode("playerdata.BaseInfo", data)
    
    if res.err then 
        print("error: " .. res.err)
    else 
        print(udata.coin)
        print("ok")
    end

    -- close connect
    db:disconnect()
end

local mt = {}

function test6() 
    pb.loadfile("./proto/Command.pb") 
    local request = require "request"

    local MsgType = pb.enum("CMD.Request.CommandType", "REGISTER")
    print(MsgType)

    local msg_login = "CMD.LoginRequest"
    local package, messagename, _ = pb.type(msg_login)
    print(package, messagename, _)

    for name, number, type in pb.fields("CMD.LoginRequest") do 
        print (name, number, type)
    end

    require "service"
    ERROR("-----------------------------")

    local cmd = {
        "login", 
        "123",
        "123"
    }

    local login = {
        username = "cauchy", 
        password = "123",
    }

    local r = pb.encode("CMD.LoginRequest", login)

    local Req = {
        type = 0, 
        data = r, 
    }

    local rr = pb.encode("CMD.Request", Req)
    local m = pb.decode("CMD.Request", rr)
    local mm = pb.decode("CMD.LoginRequest", m.data)
    INFO(mm.username)

    local encode = request:encode(cmd)
    INFO(encode)
    local m = request:decode("CMD.LoginRequest", encode)
    INFO(m["username"])
end

function test7() 
    require "service"

    skynet.dispatch("lua", function(session, source, command, ...)
        INFO(session)
        INFO(source)
        INFO(command)
    end)

    local socket = require "skynet.socket"
    local listenfd = socket.listen("127.0.0.1", 8888)
    socket.start(listenfd, function(listenfd) 
        ERROR(listenfd)
        --[[
        -- skynet.send() -> socket
        skynet.dispatch("socket", function(_, _, id, _, cmd)
            skynet.error(id, cmd)
            if cmd == "start" then 
                INFO(cmd)
            elseif cmd == "stop\n" then 
                socket.close(listenfd)
            end
        end) 
        ]]
        skynet.fork(function(listenfd)
            socket.start(listenfd)
            while true do 
                local s = socket.read(listenfd)
                ERROR(s)
                skynet.send(skynet.self(), "lua", s)
                if not s then 
                    socket.close(listenfd)
                    return 
                end
            end
        end, listenfd)
    end)
end

function test8() 
    require "service"
    db = mysql.connect ({
        host = "127.0.0.1", 
        port = 3306, 
        database = "test_db", 
        user = "root", 
        password = "root",
        max_packet_size = 1024 * 1024, -- 数据包最大字节数
        on_connect = nil, -- 连接成功的回调函数
    })
    
    local s = db:query("select * from UserInfo;")
    ERROR(s[2].data)

    local l = {
        "login",
        "123", 
        "123",
    }
    request = require "request"
    local data = request:encode(l)

    -- local sql = "insert into UserInfo(user_id, data) values(3, '1234567');"
    -- local res = db:execute(sql)
        
    -- ERROR(res)

    -- local res = db:query("insert into UserInfo(user_id, data) values(3, '1234567');")
    -- ERROR(res) 

    -- local sql = "insert into UserInfo ('user_id', 'data') values (?, ?)"
    
    --[[
    local sql = "insert into X values (?)"
    local stmt = db:prepare(sql)
    stmt:bind(1, "cauchy")
    -- stmt:bind(2, data)
    stmt:execute()
    ]]

    -- db:execute(sql, 2, "123")

    -- local sql = string.format("insert into UserInfo values(%d, %s);", 2, mysql.quote_sql_str(data))
    -- db:execute(sql)

    -- db:close()
    ERROR("+++++")
end

skynet.start(function()
    -- test1()
    -- test2()
    -- test3()
    -- test4()
    test5()
    -- test6()
    -- test7()
    --test8()
end)

#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"

-- 获取邮件表大小
local function get_mail_count()
    local cnt = 0
    for _, v in pairs(s.mail_message) do 
        cnt = cnt + 1
    end
    return cnt
end

local temp = nil

-- 邮件表进行下标重分配
-- 感觉这样实现有问题的：如果多个邮件到来，遍历顺序还是有问题。还有一些其他问题！
local function remake_message()
    temp = {}
    local cnt = get_mail_count()
    if s.mail_count ~= cnt then -- 说明有新邮件
        for id, msgJS in pairs(s.mail_message) do 
            temp[tonumber(id)] = msgJS
        end
        s.mail_message = temp 
        temp = nil
        s.mail_count = cnt
    end
end

-- 查看邮件
-- view_mail 0/1
s.client.view_mail = function(msgBS)
    local msg = request:decode("CMD.ViewMailRequest", msgBS)
    local mail_id = tonumber(msg.mail_id) -- 查看的邮件id, 此id非数据库中的唯一标识id
    -- 这是动态的id，cache中

    remake_message()

    -- 默认view_mail不带参数or是0,就是查看所有邮件
    -- 这种全局查看，判定为打开邮件系统。作为供选择的界面，不参与查看具体那一封邮件
    if mail_id == nil or mail_id == 0 then 
        for id, msgJS in pairs(s.mail_message) do
            s.send(s.node, s.gate, "send", s.id, cjson.encode({ mail_id = id })) 
            s.send(s.node, s.gate, "send", s.id, msgJS) 
        end
    elseif mail_id <= s.mail_count then 
        -- 具体查看某邮件，需要修改当前邮件的属性。is_read, is_rewarded
        
        local mail = cjson.decode(s.mail_message[mail_id]) -- 拿到这封邮件
        local mail_id = mail.mail_id -- 拿到邮件的mysql中的唯一标识id，即random的id
        mail.is_read = true 
        mail.is_rewarded = true -- 默认查看就算领取奖励

        local msgBS = pb.encode("MailInfo", mail)
        local sql = string.format("select * from UserMail where user_id = %d;", s.id)
        local result = s.call("mysql", "lua", "query", sql) 
        for i, v in pairs(result) do 
            if pb.decode("MailInfo", v).mail_id == mail_id then 
                local sql = string.format("delete from UserMail where = %s;", v)
                s.send("mysql", "lua", "query", sql) 

                local sql = string.format("insert into UserMail values(%d, %s);", s.id, mysql.quote_sql_str(msgBS))
                s.send("mysql", "lua", "query", sql) 
                break
            end
        end
        s.send(s.node, s.gate, "send", s.id, mail)
    end

    return nil
end

-- 邮件发送
-- { to, message, channel, from }
s.client.mail_send = function(msgBS)
    local msg = request:decode("CMD.MailSendRequest", msgBS)  
    if not msg.channel then 
        msg.channel = CHANNEL.NORMAL 
    end
    if not msg.from then 
        msg.from = tonumber(s.id)
    end
    
    msg.time = os.date("%Y-%m-%d %H:%M:%S", os.time())
    local msgJS = cjson.encode(msg)
    skynet.send("msgserver", "lua", "recv_mail", msgJS) 
    return nil
end

-- 邮件回复用法：{ mail_reply mail_id message }
-- { to, message }
s.client.mail_reply = function(msgBS)
    local msg = request:decode("CMD.MailReplyRequest", msgBS)
    local mail_id = tonumber(msg.mail_id)
    local message = msg.message

    local mail = cjson.decode(s.mail_message[mail_id])
    local from = tonumber(mail.from)

    -- 封装回发的消息
    local t = {
        from = s.id,
        to = mail.from,
        message = message,
        time = os.date("%Y-%m-%d %H:%M:%S", os.time())
    }
    
    -- 对消息类型做判断
    if mail.channel == CHANNEL.NORMAL then 
        t.channel = CHANNEL.NORMAL
    elseif mail.channel == CHANNEL.ADD_FRIEND_REQ then 
        t.channel = CHANNEL.ADD_FRIEND_RESP 
        mail_friend_handle(cjson.encode(t))
    end

    local msgJS = cjson.encode(t)
    skynet.send("msgserver", "lua", "recv_mail", msgJS) 
    return nil
end

-- 用户的收邮件回调
s.resp.recv_mail = function(source, msgJS)
    ERROR("[mail]：用户" .. s.id .. "收到新邮件~")
    local msg = cjson.decode(msgJS)
    msg.mail_id = math.random(1, 999999999); -- 随机一个邮件唯一标识id，用于数据库的存储，能够鉴定邮件是否匹配(cache and mysql)
    -- 问题就是，邮件id重复，无关紧要，之后处理。这里随机值挺大的。
    msg.is_read = false 
    msg.is_rewarded = false 

    local msgJS = cjson.encode(msg)
    table.insert(s.mail_message, msgJS) -- 插入cache

    ------------------------------
    local msgBS = pb.encode("MailInfo", msg)
    local sql = string.format("insert into UserMail values(%d, %s);", s.id, mysql.quote_sql_str(msgBS))
    skynet.send("mysql", "lua", "query", sql) -- 插入 mysql

    local JS = cjson.encode {
        [1] = { "[received a new email]" }
    }
    s.send(s.node, s.gate, "send", s.id, JS)
end

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
    local mail_id = tonumber(msg.mail_id) -- 查看的邮件id

    remake_message()

    -- 默认view_mail不带参数or是0,就是查看所有邮件
    if mail_id == nil or mail_id == 0 then 
        for id, msgJS in pairs(s.mail_message) do
            s.send(s.node, s.gate, "send", s.id, cjson.encode({ mail_id = id })) 
            s.send(s.node, s.gate, "send", s.id, msgJS) 
        end
    elseif mail_id <= s.mail_count then 
        s.send(s.node, s.gate, "send", s.id, s.mail_message[mail_id])
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
    table.insert(s.mail_message, msgJS) 
    local JS = cjson.encode {
        [1] = { "recv a mail~~~" }
    }
    s.send(s.node, s.gate, "send", s.id, JS)
end

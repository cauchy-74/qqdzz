#!/usr/local/bin/lua

local skynet = require "skynet"
local s = require "service"

s.mail_message = {} -- msgJS
s.mail_count = 0

MAIL_CHANNEL = {
    NORMAL = 1, 
    ADD_FRIEND_RESP = 2, 
    ADD_FRIEND_REQ = 3,
}

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
    if s.mail_count ~= cnt then -- 说明邮件数不匹配
        for id, msgJS in pairs(s.mail_message) do 
            temp[tonumber(id)] = msgJS
        end
        s.mail_message = temp 
        temp = nil
        s.mail_count = cnt
    end
end

-- 查看邮件
-- mail_view 0/1
s.client.mail_view = function(msgBS)
    local msg = request:decode("CMD.MailViewRequest", msgBS)
    local mail_id = tonumber(msg.mail_id) -- 查看的邮件id, 此id非数据库中的唯一标识mail_id
    -- 这是动态的id，cache中

    remake_message()

    -- 默认mail_view不带参数or是0,就是查看所有邮件
    -- 这种全局查看，判定为打开邮件系统。作为供选择的界面，不参与查看具体那一封邮件
    if mail_id == nil or mail_id == 0 then 
        for id, msgJS in pairs(s.mail_message) do
            s.send(s.node, s.gate, "send", s.id, cjson.encode({ mail_id = id })) 
            s.send(s.node, s.gate, "send", s.id, msgJS) 
        end
    elseif mail_id <= s.mail_count then 
        -- 具体查看某邮件，需要修改当前邮件的属性。is_read, is_rewarded
        
        local mail = cjson.decode(s.mail_message[mail_id]) -- 拿到这封邮件
        mail.is_read = true 
        mail.is_rewarded = true -- 默认查看就算领取奖励
        s.mail_message[mail_id] = cjson.encode(mail)

        
        local sql = string.format("update UserMail set `is_read` = true, `is_rewarded` = true where `user_id` = %d and `mail_id` = %d;", mail.user_id, mail.mail_id)
        skynet.send("mysql", "lua", "query", sql)

        s.send(s.node, s.gate, "send", s.id, cjson.encode(mail))
    end

    return nil
end

-- 邮件发送
-- { to, message, channel, from }
s.client.mail_send = function(msgBS)
    local msg = request:decode("CMD.MailSendRequest", msgBS)  
    if not msg.channel then 
        msg.channel = MAIL_CHANNEL.NORMAL 
    end

    -- 如果from 存在 即伪造发邮件者
    if not msg.from or msg.from == 0 then 
        msg.from = tonumber(s.id)
    end
    
    msg.time = os.date("%Y-%m-%d %H:%M:%S", os.time())
    local msgJS = cjson.encode(msg)
    skynet.send("msgserver", "lua", "recv_mail", msgJS) 
    return true
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
    if mail.channel == MAIL_CHANNEL.NORMAL then 
        t.channel = MAIL_CHANNEL.NORMAL
    elseif mail.channel == MAIL_CHANNEL.ADD_FRIEND_REQ then 
        t.channel = MAIL_CHANNEL.ADD_FRIEND_RESP 
        mail_friend_handle(cjson.encode(t)) -- 调度friend模块的处理邮件好友请求
    end

    local msgJS = cjson.encode(t)
    skynet.send("msgserver", "lua", "recv_mail", msgJS) 
    return nil
end

-- 用户删除邮件 0/1 
s.client.mail_del = function(msgBS) 
    local msg = request:decode("CMD.MailDelRequest", msgBS) 
    local cache_mail_id = tonumber(msg.mail_id)

    -- 删除全部邮件
    if cache_mail_id == nil or cache_mail_id == 0 then 
        local sql = string.format("delete from UserMail where `user_id` = %d;", s.id)
        skynet.send("mysql", "lua", "query", sql)
        
        s.mail_count = 0 
        s.mail_message = nil 
        s.mail_message = {}
        return true
    end

    local mail = cjson.decode(s.mail_message[cache_mail_id])
    local mysql_mail_id = tonumber(mail.mail_id)

    local sql = string.format("delete from UserMail where `user_id` = %d and `mail_id` = %d;", s.id, mysql_mail_id)
    skynet.send("mysql", "lua", "query", sql)

    s.mail_count = s.mail_count - 1
    s.mail_message[cache_mail_id] = nil 
    return true
end

-- 用户的收邮件回调
s.resp.recv_mail = function(source, msgJS)
    ERROR("[mail]：用户" .. s.id .. "收到新邮件~")
    local msg = cjson.decode(msgJS)
    table.insert(s.mail_message, msgJS) -- 插入cache

    local sql = string.format("insert into UserMail (`user_id`, `mail_id`, `from`, `to`, `title`, `message`, `channel`, `is_read`, `is_rewarded`, `time`) values(%d, %d, %d, %d, %s, %s, %d, %s, %s, '%s');", 
    msg.user_id, msg.mail_id, msg.from, msg.to, mysql.quote_sql_str(msg.title), mysql.quote_sql_str(msg.message), msg.channel, msg.is_read, msg.is_rewarded, msg.time)
    skynet.send("mysql", "lua", "query", sql) -- 插入 mysql

    local JS = cjson.encode {
        [1] = { "[received a new email]" }
    }
    s.send(s.node, s.gate, "send", s.id, JS)
end

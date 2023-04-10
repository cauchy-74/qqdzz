#!/usr/local/bin/lua

local pb = require "pb"

local messageType = {
    login = 0, 
    register = 1, 
    enter_scene = 2,
    leave_scene = 3, 
    create_scene = 4, 
    end_game = 5, 
    chat_message = 6, 
    invite_to_game = 7, 
    block_user = 8, 
    unblock_user = 9, 
    add_friend = 10, 
    del_friend = 11,

    error = 504,
}

local messageProto = {
    [messageType.login] = "LoginRequest", 
    [messageType.register] = "RegisterRequest", 
    [messageType.enter_scene] = "EnterSceneRequest", 
    [messageType.leave_scene] = "LeaveSceneRequest", 
    [messageType.create_scene] = "CreateSceneRequest", 
    [messageType.end_game] = "EndGameRequest", 
    [messageType.chat_message] = "ChatMessageRequest", 
    [messageType.invite_to_game] = "InviteToGameRequest", 
    [messageType.block_user] = "BlockUserRequest", 
    [messageType.unblock_user] = "UnblockUserRequest", 
    [messageType.add_friend] = "AddFriendRequest", 
    [messageType.del_friend] = "DelFriendRequest", 

    [messageType.error] = "ErrorRequest",
}

local mt = {} 

-- 根据命令类型获取消息类型
-- para: "login"
-- return: 0
function mt:getMessageType(commandType)
    if not self.messageType[commandType] then 
        return self.messageType["error"]
    end
    return self.messageType[commandType]
end

-- 根据消息类型获取消息结构体
-- para: 0  
-- return: "LoginRequest"
function mt:getMessageProto(commandType)
    return self.messageProto[self:getMessageType(commandType)]
end

-- para: { login 123 123 }
-- return: "CMD.LoginRequest"
function mt:parseMessage(messageTable)
    return "CMD." .. self:getMessageProto(messageTable[1])
end

-- 创建消息结构体
-- para: "CMD.LoginRequest", { "login", "123", "123" }
-- return: { username = "123", password = "123" }
function mt:createMessage(messageType, messageTable)
    local message = {} -- proto结构需要按用户提交的格式来统一

    for name, id, types in pb.fields(messageType) do 
        -- 由于使用时，不存在的字段nil不能判断，直接是空的
        -- 所以这里不存在的字段:
        -- int32: math.mininteger 极小值 
        -- string: 都置为字符串空"nil"
        if not messageTable[id + 1] then 
            if types == "int32" then 
                message[name] = math.mininteger
            elseif types == "string" then
                message[name] = "nil"
            end
        else
            message[name] = messageTable[id + 1]
        end
    end
    return message
end

-- para: { "login", "123", "123" }
-- return: 编码好的二进制
function mt:encode(messageTable)
    local messageType = self:parseMessage(messageTable)
    local message = self:createMessage(messageType, messageTable)
    local bytes = pb.encode(messageType, message)
    local request = {
        type = self:getMessageType(messageTable), 
        data = bytes
    }
    return pb.encode("CMD.Request", request)
end

-- para: "CMD.LoginRequest", 二进制数据Data 
-- return: msg, msgtype;  { username = "123",password = "123" }, 504
function mt:decode(messageType, messageData) 
    local request = pb.decode("CMD.Request", messageData) 
    local msg = pb.decode(messageType, request.data) 
    return msg, request.type
end

local request = {
    messageType = messageType, 
    messageProto = messageProto,
}

setmetatable(request, { __index = mt })

return request

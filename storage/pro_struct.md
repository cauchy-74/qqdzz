1. 用户信息(UserInfo.proto) -- USER

message UserInfo {
    string user_id = 1;  // 用户ID
    string username = 2;  // 用户名
    string password = 3;  // 用户密码
    string email = 4;  // 邮箱
    int32 level = 5;  // 等级
    int32 experience = 6;  // 经验值
    int32 coin = 7;  // 金币数量
}

2. 球球信息(BallInfo.proto) -- BALL

message BallInfo {
    string ball_id = 1;  // 球ID
    string user_id = 2;  // 球所属用户ID
    string ball_name = 3;  // 球的名称
    int32 ball_level = 4;  // 球的等级
    int32 ball_experience = 5;  // 球的经验值
    int32 ball_attack = 6;  // 球的攻击力
    int32 ball_defense = 7;  // 球的防御力
    int32 ball_speed = 8;  // 球的速度
    int32 ball_hp = 9;  // 球的生命值
    int32 ball_mp = 10;  // 球的魔法值
    string ball_texture = 11;  // 球的贴图
}

3. 地图信息(MapInfo.proto) -- MAP

message MapInfo {
    string map_id = 1;  // 地图ID
    string map_name = 2;  // 地图名称
    int32 map_width = 3;  // 地图宽度
    int32 map_height = 4;  // 地图高度
    repeated string brick_texture = 5;  // 砖块贴图列表
    repeated string obstacle_texture = 6;  // 障碍物贴图列表
}


4. 游戏房间信息(GameRoom.proto) -- GAMEROOM

message GameRoom {
    string room_id = 1;  // 房间ID
    string room_name = 2;  // 房间名称
    string map_id = 3;  // 地图ID
    repeated UserInfo player_list = 4;  // 玩家列表
    int32 room_status = 5;  // 房间状态（0：等待中，1：游戏中，2：已结束）
    int32 max_players = 6;  // 最大玩家数量
}

5. 游戏房间状态信息(GameRoomState.proto) -- GAMEROOMSTATE

message GameRoomState {
    string room_id = 1;  // 房间ID
    int32 round_time = 2;  // 当前回合时间
    int32 round_left_time = 3;  // 当前回合剩余时间
    repeated BallInfo ball_list = 4;  // 球列表
    repeated UserInfo player_list = 5;  // 玩家列表
    int32 game_status = 6;  // 游戏状态（0：未开始，1：进行中，2：已结束）
}

6. 游戏玩家状态信息(GamePlayerState.proto) -- GAMEPLAYERSTATE

message GamePlayerState {
    string user_id = 1; // 玩家ID
    string ball_id = 2; // 使用的球ID
    int32 x = 3; // 玩家所在位置x坐标
    int32 y = 4; // 玩家所在位置y坐标
    int32 hp = 5; // 玩家生命值
    int32 mp = 6; // 玩家魔法值
    int32 score = 7; // 玩家得分
    int32 kill_num = 8; // 玩家击杀数量
    int32 death_num = 9; // 玩家死亡数量
    repeated string skill_list = 10; // 玩家技能列表
}

7. 游戏战斗状态信息(GameBattleState.proto) -- GAMEBATTLESTATE

message GameBattleState {
    string room_id = 1; // 房间ID
    repeated GamePlayerState player_state_list = 2; // 玩家状态列表
}

8. 邮件信息(MailInfo.proto) -- MAIL

message MailInfo {
    string mail_id = 1;  // 邮件ID
    string sender_id = 2;  // 发件人ID
    string receiver_id = 3;  // 收件人ID
    string mail_title = 4;  // 邮件标题
    string mail_content = 5;  // 邮件内容
    int32 mail_type = 6;  // 邮件类型（1：系统邮件，2：好友邮件）
    bool is_read = 7;  // 是否已读
    bool is_rewarded = 8;  // 是否已领取奖励
    int32 send_time = 9;  // 发送时间
}

9. 好友信息(FriendInfo.proto) -- FRIEND

message FriendInfo {
    string friend_id = 1;  // 好友ID
    string friend_name = 2;  // 好友名字
    string friend_avatar = 3;  // 好友头像
    int32 friend_level = 4;  // 好友等级
    int32 friend_vip_level = 5;  // 好友VIP等级
    bool is_online = 6;  // 是否在线
}

10. 聊天信息(ChatMessage.proto) -- CHAT

message ChatMessage {
    string sender_id = 1;  // 发送者ID
    string receiver_id = 2;  // 接收者ID
    string message_content = 3;  // 消息内容
    int32 message_type = 4;  // 消息类型（1：文字消息，2：表情消息，3：语音消息）
    int32 send_time = 5;  // 发送时间
}

11. 设置信息(SettingInfo.proto) -- SETTING

message SettingInfo {
    string user_id = 1;  // 用户ID
    bool is_sound_on = 2;  // 是否开启声音
    bool is_music_on = 3;  // 是否开启音乐
    bool is_vibration_on = 4;  // 是否开启震动
    bool is_notification_on = 5;  // 是否开启通知
}














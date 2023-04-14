
þ
UserInfo.proto"ã
UserInfo
user_id (RuserId
username (	Rusername
password (	Rpassword
email (	Remail
level (Rlevel

experience (R
experience
coin (Rcoin&
last_login_time (RlastLoginTimebproto3
Ž
GamePlayerState.proto"ì
GamePlayerState
user_id (	RuserId
ball_id (	RballId
x (Rx
y (Ry
hp (Rhp
mp (Rmp
score (Rscore
kill_num (RkillNum
	death_num	 (RdeathNum

skill_list
 (	R	skillListbproto3
 
GameBattleState.protoGamePlayerState.proto"h
GameBattleState
room_id (	RroomId<
player_state_list (2.GamePlayerStateRplayerStateListbproto3
ô
BallInfo.proto"Ù
BallInfo
ball_id (	RballId
user_id (	RuserId
	ball_name (	RballName

ball_level (R	ballLevel'
ball_experience (RballExperience
ball_attack (R
ballAttack!
ball_defense (RballDefense

ball_speed (R	ballSpeed
ball_hp	 (RballHp
ball_mp
 (RballMp!
ball_texture (	RballTexturebproto3
Ò
ChatMessage.proto"´
ChatMessage
	sender_id (	RsenderId
receiver_id (	R
receiverId'
message_content (	RmessageContent!
message_type (RmessageType
	send_time (RsendTimebproto3
á
MapInfo.proto"Ç
MapInfo
map_id (	RmapId
map_name (	RmapName
	map_width (RmapWidth

map_height (R	mapHeight#
brick_texture (	RbrickTexture)
obstacle_texture (	RobstacleTexturebproto3
ö
FriendInfo.proto"Ù

FriendInfo
	friend_id (	RfriendId
friend_name (	R
friendName#
friend_avatar (	RfriendAvatar!
friend_level (RfriendLevel(
friend_vip_level (RfriendVipLevel
	is_online (RisOnlinebproto3
ð
GameRoom.protoUserInfo.proto"Å
GameRoom
room_id (	RroomId
	room_name (	RroomName
map_id (	RmapId*
player_list (2	.UserInfoR
playerList
room_status (R
roomStatus
max_players (R
maxPlayersbproto3
Ú
SettingInfo.proto"¼
SettingInfo
user_id (	RuserId
is_sound_on (R	isSoundOn
is_music_on (R	isMusicOn&
is_vibration_on (RisVibrationOn,
is_notification_on (RisNotificationOnbproto3
¤
GameRoomState.protoUserInfo.protoBallInfo.proto"ä
GameRoomState
room_id (	RroomId

round_time (R	roundTime&
round_left_time (RroundLeftTime&
	ball_list (2	.BallInfoRballList*
player_list (2	.UserInfoR
playerList
game_status (R
gameStatusbproto3
ú
MailInfo.proto"ß
MailInfo
mail_id (RmailId
from (Rfrom
to (Rto
title (	Rtitle
message (	Rmessage
channel (Rchannel
is_read (RisRead
is_rewarded (R
isRewarded
time	 (	Rtimebproto3
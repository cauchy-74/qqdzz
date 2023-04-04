#!/bin/bash

protoc --descriptor_set_out=storage.pb UserInfo.proto GameBattleState.proto BallInfo.proto ChatMessage.proto MapInfo.proto FriendInfo.proto GamePlayerState.proto GameRoom.proto SettingInfo.proto GameRoomState.proto MailInfo.proto

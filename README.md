# 《球球大作战》
基于Skynet框架开发服务端 

## 通信协议 

|    通信协议    |                 基本语法                  |                           功能&bug                           |
| :------------: | :---------------------------------------: | :----------------------------------------------------------: |
|    注册    |   【register username password user_id】   |                    用户ID目前需要自己指定，且 ID >= 1                    |
|    登录    | 【login username password user_id email】 |        用户名不需要匹配，但密码和ID匹配；邮箱可选择写        |
|    查看    |                 【view】                  |                         显示玩家信息                         |
|    工作    |                 【work】                  |                            金币+1                            |
|          |                                            |                                                              |
|  加好友  |          【add_friend friend_id】          |                            加好友                            |
|  删好友  |          【del_friend friend_id】          |                            删好友                            |
| 好友列表 |              【list_friend】               |                         查看好友列表                         |
|          |                                            |                                                              |
| 查看邮件 |           【mail_view mail_id】            | 查看邮件；mailid是0或不输入则是查看全部邮件（查看单封邮件前最好先执行） |
| 发送邮件 | 【mail_send user_id message channel from】 | 发送邮件；对方ID和消息内容，后两参数默认（channel：0普通消息，1加好友消息）；from：该参数可以伪造发送者ID？ |
| 邮件回复 |       【mail_reply mail_id message】       | 回复指定邮件；需要先查看全部邮件，然后使用邮件ID指定回复；例如：收到加好友邮件，回复message是yes，则能成功加上 |
| 邮件删除 |            【mail_del mail_id】            |    删除邮件；（mail_id：0或空 删除全部邮件，非0其它邮件）    |
|          |                                            |                                                              |
|   聊天   |          【chat obj_id message】           |     指定对象聊天；（obj_id：0大厅/游戏房间，非0好友ID）      |
| 聊天列表 | 【list_chat list_type】 | 查看聊天列表；（list_type：0大厅，非0好友ID） |
|              |                               |                                                              |
| 断线重连 | 【reconnect user_id token】 | 令牌是最近一次登录（存在挤号，后来居上），服务器返回的token值 |
| 进入游戏 |          【enter_scene scene_id】          |         场景ID可选择写（1001 1002 1003）；默认会随机进入         |
| 退出游戏 |          【leave_scene scene_id】          |                        场景ID可选择写                        |
| 数据保存 |               【save_data】                |                       实时保存玩家数据                       |
|   退出   |                  【exit】                  |                           退出游戏                           |
|          |                                            |                                                              |
| 管理员 | 【stop】 | 终止服务器; port: 8888 |
|              |                               |                                                              |
|移动|【w、s、a、d】|上下左右移动|
|地图|【m range】|全局地图；range忽略|
|周围|【c range】|查看AOI区域；range：0或空，则显示九宫格范围的实体ID，range >= 1，则显示当前地图中所有实体ID|
||||


----------------------------




## 项目配置

## etc

配置文件夹

1. **config.node**
> 记录节点的相关信息

2. **runconfig.lua**
> 全局的运行配置，项目的拓扑结构

## luaclib

C模块文件夹 

1. **cjson.so**
> cjson 
> 轻量级json解析器和生成器，快速解析生成json格式的数据，使用简单，代码量小，方便集成。
2. **pb.so**
> protobuf 
> Google开发的数据序列化和反序列化工具，高效将结构化数据进行编码和解码。protobuf生成的二进制数据体积小，解析快，能够在网络传输和存储场景中提高效率。支持多种编成语言，方便实现跨语言的数据交换。使用IDL（Interface Description Language）描述数据结构，方便扩展和修改数据结构。

## lualib

lua模块

1. **service.lua**
> 服务的模板文件
> 实现了基础的服务功能：    
> (1). 服务类表：M = { name, id, exit, init, resp }      
> (2). M.start(name, id, ...)：newservice创建服务，会进入该封装的start方法中，设置基础属性，调用skynet.start(init)  。    
> (3). init()：全局的初始化方法，在新建的服务中可自定义M.init()初始化方法。并且在此函数中设定了消息分发方法dispatch。      
> (4). dispatch(session, address, cmd, ...)：模块的消息分发处理机制，调用M.resp\[cmd\]方法，并返回调用方法后的返回值给发送方。    
> (5). M.call(node, srv, ...)；M.send(node, srv, ...)：重写call和node方法，便于在不同节点间的通信调用。    


2. **request.lua**
> 指令请求封装模块，用于解析【cmd para1 para2 ...】


## proto 

用于存放通信协议的描述文件

## storage

用于“存储数据”的描述文件

## service

服务模块

1. **main.lua**  
> 项目启动文件，用于服务的启动，调度。  

### agent

> 代理服务  

1. **init.lua**   
> 实现基础的用户执行命令方法cmd，和回调方法。    

2. **scene.lua**   
> 场景功能模块; 在init.lua中导入：require "scene"     

3. **mail.lua**
> 邮件功能模块

4. **friend.lua**
> 好友功能模块

5. **chat.lua**
> 聊天功能模块

### agentmgr

> 全局管理代理服务   

1. **init.lua**   
> login成功返回agent代理，即动态开启agent代理服务。   

### gateway

> 网关服务  

1. **init.lua**  

> 实现client端连接与代理服务agent的双向认证。  

### login 
> 登录服务  

1. **login.lua**  
> 完成登录操作，向agentmgr发起登录请求，拿到agent代理后，通过sure_agent回调给网关完成fd与agent的绑定，并设置好agent的属性：gate等。


### scene 

> 场景服务  

1. **init.lua**  

> 维护场景元素：小球ball和食物food      
> 实现广播（broadcast）方法：用于给所有玩家发送消息。回调玩家agent的send方法。      
> 实现回调方法：（enter; shift; leave; ）    
> 实现保持帧率执行，每0.2s调度（move_update; food_update; eat_update; ）    

2. **AOI.lua**
> 实现玩家的AOI（Area of Interest)
> 食物的检测碰撞，玩家的碰撞逻辑基于AOI优化
> AOI算法的实现：九宫格算法

3. **visual.lua**
> 可视化地图

### nodemgr

> 节点管理服务  

1. **init.lua**  

> 新启agent服务，并返回该服务。  

### mysql

> 数据库服务 

1. **init.lua**

> 维护数据库连接池


### msgserver 

> 消息分发服务 

1. **init.lua**

> 订阅者模式 & 邮件系统

### admin 

> 管理员服务


------

# 数据库设计

## 用户信息表（UserInfo）
|  Field  | Type | Null | Key  | Default | Extra |
| :-----: | :--: | :--: | :--: | :-----: | :---: |
| user_id | int  |  NO  | PRI  |  NULL   |       |
|  data   | blob | YES  |      |  NULL   |       |


## 邮件信息表（MailInfo）
|  Field  |   Type   | Null | Key  | Default |     Extra      |
| :-----: | :------: | :--: | :--: | :-----: | :------------: |
|   id    |   int    |  NO  | PRI  |  NULL   | auto_increment |
|  from   |   int    |  NO  | MUL  |  NULL   |                |
|   to    |   int    |  NO  | MUL  |  NULL   |                |
|  time   | datetime |  NO  |      |  NULL   |                |
| channel |   int    | YES  |      |  NULL   |                |
| message |   text   | YES  |      |  NULL   |                |

## 好友信息表（FriendInfo）
|   Field   | Type | Null | Key  | Default |     Extra      |
| :-------: | :--: | :--: | :--: | :-----: | :------------: |
|    id     | int  |  NO  | PRI  |  NULL   | auto_increment |
|  user_id  | int  |  NO  | MUL  |  NULL   |                |
| friend_id | int  |  NO  | MUL  |  NULL   |                |
| chat_msg  | blob | YES  |      |  NULL   |                |

## 用户邮件表（UserMail）
|    Field    |     Type     | Null | Key  | Default | Extra |
| :---------: | :----------: | :--: | :--: | :-----: | :---: |
|   user_id   |     int      |  NO  | PRI  |  NULL   |       |
|   mail_id   |     int      |  NO  |      |  NULL   |       |
|    from     |     int      |  NO  |      |  NULL   |       |
|     to      |     int      |  NO  |      |  NULL   |       |
|    title    | varchar(100) | YES  |      |  NULL   |       |
|   message   |     text     | YES  |      |  NULL   |       |
|   channel   |     int      |  NO  |      |  NULL   |       |
|   is_read   |  tinyint(1)  | YES  |      |  NULL   |       |
| is_rewarded |  tinyint(1)  | YES  |      |  NULL   |       |
|    time     |   datetime   |  NO  |      |  NULL   |       |

## 好友聊天表（FriendChat）
|   Field   |   Type   | Null | Key  | Default |     Extra      |
| :-------: | :------: | :--: | :--: | :-----: | :------------: |
|    id     |   int    |  NO  | PRI  |  NULL   | auto_increment |
|   lowid   |   int    |  NO  |      |  NULL   |                |
|   upid    |   int    |  NO  |      |  NULL   |                |
|   time    | datetime |  NO  |      |  NULL   |                |
| timestamp |   int    |  NO  |      |  NULL   |                |
|  message  |   text   | YES  |      |  NULL   |                |


## 消息表（Message）
|   Field   |    Type     | Null | Key  | Default |     Extra      |
| :-------: | :---------: | :--: | :--: | :-----: | :------------: |
|    id     |    Type     |  NO  | PRI  |  NULL   | auto_increment |
|  channel  | varchar(50) |  NO  |      |  NULL   |                |
|  message  |    text     |  NO  |      |  NULL   |                |
|   time    |  datetime   |  NO  |      |  NULL   |                |
| timestamp |     int     |  NO  | MUL  |  NULL   |                |





----------------------

# 版本迭代   

## version:1.0:   

### 完善游戏功能   

> 1. 场景实体碰撞检测   
    **内容：** 使用AOI九宫格算法，完成了场景内部玩家吃食物、玩家简易碰撞的逻辑。    

> 2. 服务模块隔离      
    **内容：** 实现大厅和游戏的逻辑独立。    

### 存在的问题    

> 1. 不支持多节点    
    **内容：** BUG：同时启动node1,node2会造成服务名的重复，管理员进行服务关闭时逻辑先后顺序的不同会有问题。大概率是agentmgr仍是单点。    

### 开发思路   

> 1. 游戏运行逻辑：由telnet代替客户端连接，gateway服务监听端口。有连接到来，仅允许register和login指令，交由login服务处理。登录后，agentmgr服务会通过nodemgr新建代理agent匹配给当前client。接下来的逻辑（指令）全部交由agent服务处理，agent服务中划分不同模块，char、mail、friend、scene等模块，处理不同的指令。游戏指令需要和scene服务交互，通过 `指令->状态` 的方案，由scene服务完成所有的逻辑处理。   

> 2. 目前的邮件消息，聊天消息交由msgserver模块处理。都是做简单的定时轮询处理，聊天消息根据不同订阅频道发布不同内容，容易嵌入不同的应用场景。分隔游戏大厅和游戏场景的逻辑模块，通过subscribe和unsubscribe完成不同场景的channel需求。   
   
> 3. 所有的数据存储都通过mysql连接池完成。   

----



## version:0.2:   

### 添加功能：  

> 1. 添加邮件系统    
    **内容：** msgserver服务，内部包含订阅者模式，暂时提供玩家聊天功能。邮件功能：开启定时器，对维护的邮件缓存表定时查看，如果该邮件发送对象上线了，就发送给玩家。       
    **问题：** 轮询式遍历目前所有未发送的邮件，资源开销大。       
 
> 2. 添加好友系统    
    **内容：** friend.lua模块，通过邮件系统发送给玩家好友请求邮件。玩家可通过回复邮件操作，附带消息msg：yes,no来选择。除此还有基础好友功能，见协议部分。       

> 3. 实现基础聊天功能   
    **内容：** chat.lua模块，通过给上线用户订阅channel，实现点对点聊天，和大厅聊天功能。    

> 4. 实现部分数据库操作, 完成数据的可持久化    
    **内容：** 添加了UserInfo, UserMail, FriendInfo, FriendChat, Message, MailInfo等表用于数据落盘。     

### 遇到的问题：     

> 1. 聊天的信息丢失    
    **解决：** 做延时处理，x时刻发出的消息标记为x时刻，但x时刻轮询的消息查询，查询的是x-y时刻的消息。y时间段之后，就能查询到x时刻的消息，在进行广播。由于查询是时间段，满足左开右闭的查询，注意更新上一个时间点，即左端点需要及时更新。    

> 2. 回调函数的闭包不成功    
    **问题：** 在订阅者模式中，本打算用回调函数完成功能。但是skyent.send函数会序列化为二进制数据发送，尽管使用了string.dump,load函数，但是函数闭包出错了。原因是二进制下传输，会丢失掉函数的upvalue等内部维护的状态信息。     
    **解决：** 通过msgserver服务维护全局回调函数索引，然后在本agent服务内也对应维护该索引（需要msgserver服务回调获得该索引值）。传递回调函数，即转为传递索引，然后本服务内通过索引拿到要调用的函数，自然该函数所有上值都存在，并且能获得本服务所有信息。即使用s.resp.send跟对应客户端client通信。     
   

  

-----



## version:0.1:  

### 存在的问题:  

> 1. 登录协议返回之前（agentmgr：s.call(node, "nodemgr", "newservice", "agent", "agent", playerid)还未返回），客户端已经下线，但此时agentmgr记录是“LOGIN”状态，这样下线请求不会被执行，除非再次登入踢下线，否则agent一直存在。  
    **解决：** gateway 与 agent 之间偶尔发送心跳协议，若检测客户端连接已断开，则请求下线。 

> 2. agentmgr是单点，会成为系统瓶颈。    
    **解决：** 开启多个agentmgr，玩家id为索引分开处理。 

> 3. move协议广播量大，造成跨节点通信负载压力。   
    **解决：** 匹配时尽量匹配同节点服务，特殊玩法才跨节点。 

> 4. gateway在Lua层处理字符串协议，Lua层输入缓冲区效率低，增加GC（内存垃圾回收机制）负担。    
    **解决：** 使用Skynet提供的netpack模块高效处理。

> 5. 场景服务广播量大。     
    **解决：** AOI（Area of Interest）算法优化。只需把玩家附件的小球和食物广播给他即可。

> 6. 食物碰撞计算量大。    
    **解决：** 1. 四叉树算法优化。 2. 交由客户端进行碰撞检测，服务端做校验。

> 7. 登出过程，agent会收到kick和exit消息，分别用于保存和退出。若在之间agent收到了其他服务发来的消息，导致属性更改不被存档。  
    **解决：** 给agent添加状态，若处于kick状态下，不处理任何消息。

> 8. 未作数据库操作。  
    **解决：** 对于大量玩家，可以对数据库做分库分表，用redis做一层缓存。

> 9. 服务端稳定运行的前提是所有Skynet节点都能稳定运行，且维持稳定网络通信。因此所有节点应当部署在同一局域网。  

------------------




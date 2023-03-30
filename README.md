# 《球球大作战》
基于Skynet框架开发服务端 
## 项目配置

## etc
配置文件夹
1. **config.node**
> 记录节点的相关信息
2. **runconfig.lua**
> 全局的运行配置，项目的拓扑结构

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


## service

服务模块

1. **main.lua**
> 项目启动文件，用于服务的启动，调度。

### agent

> 代理服务

1. **init.lua** 

> 实现基础的用户执行命令方法cmd，和回调方法。  
> s.client.work; （ 执行用户 \[work\] 命令）
> s.resp.client; s.resp.kick; s.resp.exit; s.resp.send;  （ client用于分派用户命令执行，kick下线,exit退出,send与gateway通信。）

2. **scene.lua**

> 场景功能模块，在init.lua中导入：require "scene"  
> 添加了用户的命令功能，s.client.enter;  s.client.shift; （进入场景；移动）
> 实现了random_scene()局域方法，随机选取场景节点。
> 实现了leave_scene()模块方法，用于退出场景，需要发送leave请求给scene节点完成退出。




### agentmgr

> 全局管理代理服务

1. **init.lua**
> 目前实现reqkick和reqlogin两个回调方法。  
> login成功返回agent代理，即动态开启agent代理服务。

### gateway

> 网关服务

1. **init.lua**

> 实现client端连接与代理服务agent的双向认证。

### login 
> 登录服务

1. **login.lua**
> 完成登录操作，向agentmgr发起登录请求，拿到agent代理后，通过sure_agent回调给网关完成fd与agent的绑定。



### scene 

> 场景服务

1. **init.lua**

> 维护场景元素：小球ball和食物food    
> 实现广播（broadcast）方法：用于给所有玩家发送消息。回调玩家agent的send方法。    
> 实现回调方法：（enter; shift; leave; ）  
> 实现保持帧率执行，每0.2s调度（move_update; food_update; eat_update; ）  


### nodemgr

> 节点管理服务

1. **init.lua**

> 新启agent服务，并返回该服务。




------

# 版本的不足

## version:0.1:

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
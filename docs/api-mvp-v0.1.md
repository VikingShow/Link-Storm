# Link Storm MVP API v0.1

当前 API 是零依赖 Node.js 原型，用于验证推荐闭环。

启动：

```bash
npm run dev:api
```

服务地址：

```text
http://localhost:8787
```

## GET /health

健康检查。

响应：

```json
{
  "status": "ok",
  "service": "link-storm-api",
  "version": "0.1.0"
}
```

## GET /api/feed

根据城市、主题和角色返回情报推荐。

查询参数：

```text
city: 城市，默认 深圳
topics: 逗号分隔主题，例如 AI智能体,机器人
role: 用户角色，例如 founder/developer/investor/manager/operator
limit: 返回数量，默认 8
```

示例：

```text
GET /api/feed?city=深圳&topics=AI智能体,机器人&role=developer&limit=3
```

响应字段：

```text
userContext: 当前用户上下文
strategy: 推荐策略，目前为 rule_based_zero_llm
items: 情报卡片
stopCard: 知而行之行动卡
```

推荐卡包含：

```text
标题
一句话结论
关键信号
为什么重要
下一步建议
来源
主题标签
城市标签
推荐分
推荐理由
相关活动
```

## GET /api/activities

根据城市和主题返回活动推荐。

示例：

```text
GET /api/activities?city=深圳&topics=AI智能体&role=developer
```

## POST /api/feedback

保存用户反馈。当前 MVP 只写入内存，后续接数据库。

请求示例：

```json
{
  "userId": "demo-user",
  "targetType": "intelligence",
  "targetId": "intel_ai_agent_001",
  "actionType": "save"
}
```

常见 actionType：

```text
view
open_source
save
hide
add_to_calendar
click_register
capture_idea
finish_today
```

## 当前限制

1. 数据来自 `data/seed`，还没有接真实采集。
2. 反馈只保存在内存中，服务重启会丢失。
3. 推荐使用规则评分，不依赖大模型。
4. 没有鉴权，不能直接用于生产环境。

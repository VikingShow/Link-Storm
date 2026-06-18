# Link Storm 技术调研与可行方案 v0.1

日期：2026-06-09  
范围：高质量内容获取、本地活动获取、定位与地理服务、推荐系统、记忆系统、MVP 技术架构

## 1. 结论摘要

Link Storm 不应该依赖单一新闻源或单一活动平台。可行方案是建立一个“可信来源库 + 自动采集 + AI 结构化 + 人工校准 + 用户反馈”的闭环。

第一版建议采用：

1. 内容源：RSS/API/白名单网页采集/人工投喂混合。
2. 活动源：平台 API + 主办方官网/园区/政府/高校页面采集 + 商务合作。
3. 定位：鸿蒙端只默认获取城市级定位，精确定位只在“附近活动”场景临时使用。
4. 推荐：先做规则 + 内容向量 + 行为权重的混合推荐，数据量上来后再加入协同过滤。
5. 记忆：把用户兴趣、行为、显式反馈、城市、角色和主题偏好做成可解释画像，不做黑盒长期追踪。

核心原则：先保证内容质量，再做自动化规模。

## 2. 高质量内容从哪里来

### 2.1 内容源分层

建议把内容源分成 5 层，不同层级有不同可信度和处理策略。

#### A 类：一手官方源

优先级最高。

来源包括：

1. 公司官网、新闻中心、博客。
2. 产品更新日志。
3. 开源项目 release、GitHub Trending、项目公告。
4. 研究机构、实验室、大学官网。
5. 政府、园区、工信、发改、商务等政策发布页面。
6. 投资机构 portfolio news、被投企业动态。

适合发现：

1. 产品发布。
2. 技术突破。
3. 政策变化。
4. 园区扶持。
5. 企业合作。
6. 招聘扩张。
7. 融资和并购信号。

优点：可信、原始、低噪声。  
缺点：分散、格式不统一、更新频率不稳定。

#### B 类：RSS/Newsletter 源

RSS 是第一版最适合的采集方式之一。RSS 2.0 是成熟的内容分发格式，官方规范说明它是 Web 内容聚合格式，结构稳定，适合自动化拉取。

可用对象：

1. 科技媒体 RSS。
2. 行业博客 RSS。
3. 公司博客 RSS。
4. Substack/Newsletter 公开源。
5. GitHub release feed。
6. arXiv、论文和技术博客 feed。

优点：合法性和稳定性比页面爬取更好。  
缺点：中文优质源 RSS 覆盖有限，需要补充网页采集。

#### C 类：新闻与情报 API

可作为补充源，不作为唯一内容源。

可调研选项：

1. NewsAPI：官方文档提供 Top headlines 和 Everything 等端点，适合英文新闻聚合。
2. GDELT：适合全球新闻和事件监测，可用于趋势发现。
3. Event Registry：偏新闻情报和事件检测，适合做事件聚合。
4. mediastack：提供实时新闻 API，适合补充海外新闻。
5. Bing/搜索类 API：适合发现网页，但需要注意成本和许可。

适合用途：

1. 补充全球英文信号。
2. 做事件交叉验证。
3. 发现同一事件的多来源报道。
4. 做热点初筛。

不适合用途：

1. 直接把 API 结果作为产品内容流。
2. 完全依赖新闻 API 判断“高价值”。
3. 直接复制全文入库。

#### D 类：白名单网页采集

这是中文场景必须做的一层。

采集对象：

1. 36 氪、虎嗅等媒体页面的公开链接和摘要。
2. 企业官网新闻中心。
3. 园区、协会、政府活动公告。
4. 大厂开发者社区。
5. 高校创新创业学院、产业研究院页面。
6. 主办方活动详情页。

注意：

1. 遵守 robots.txt 和平台服务条款。
2. 尽量只保存标题、摘要、结构化元数据、链接和必要片段。
3. 产品内优先跳转原文，不做侵权搬运。
4. 高价值来源进入白名单，低质来源降权或剔除。

#### E 类：人工投喂和运营精选

第一版必须保留人工入口。

来源包括：

1. 运营人员录入。
2. 用户提交链接。
3. 领域顾问推荐。
4. 企业/主办方提交活动。
5. 微信群、朋友圈、公众号链接池。

原因：真正高质量信息经常不在开放 API 里，尤其是本地产业活动、闭门路演、企业开放日。

## 3. 内容处理链路

### 3.1 总链路

```text
来源注册
-> 定时采集
-> URL 规范化
-> 正文/元数据提取
-> 语言与领域识别
-> 实体抽取
-> 去重与事件聚合
-> AI 结构化摘要
-> 价值评分
-> 人工审核
-> 发布与推荐
-> 用户反馈回流
```

### 3.2 采集模块

建议建 `source_registry` 表维护来源。

字段：

```text
id
name
source_type: rss/api/web/manual
base_url
fetch_url
domain
language
topics
trust_score
fetch_interval_minutes
parser_type
robots_policy
status
last_fetched_at
```

不同 source_type 的处理方式：

```text
rss: feed parser 定时拉取
api: 调用第三方 API，保存返回元数据
web: 白名单页面采集 + 正文提取
manual: 后台录入
```

### 3.3 正文与元数据提取

优先级：

1. JSON-LD / Open Graph / schema.org。
2. RSS item 字段。
3. 页面正文抽取。
4. AI 辅助抽取。

对于活动页面，优先识别 schema.org/Event。Schema.org 的 Event 类型包含事件时间、地点、组织者、票务等字段，适合做活动结构化。

### 3.4 去重与事件聚合

不能让用户看到 10 条重复新闻。需要把多篇报道聚合成一个“事件”。

去重策略：

1. URL canonical 去重。
2. 标题归一化后做相似度判断。
3. SimHash/MinHash 做近重复检测。
4. embedding 语义相似度聚类。
5. 实体 + 时间 + 事件类型辅助判断。

事件聚合字段：

```text
event_cluster_id
main_title
event_type
entities
first_seen_at
last_seen_at
source_count
primary_source_url
related_source_urls
confidence
```

### 3.5 结构化摘要

每条情报都生成固定结构：

```text
one_line_conclusion
key_signals
why_it_matters
affected_roles
next_actions
related_topics
related_cities
related_companies
source_evidence
```

技术实现：

1. LLM 使用结构化输出，避免自由文本乱飘。
2. 后端用 JSON Schema 校验。
3. 失败则进入人工审核队列。
4. 摘要中必须保留来源链接和证据片段。

OpenAI 官方 Structured Outputs 支持按开发者提供的 JSON Schema 输出，适合这类“新闻转结构化情报”的任务。批量处理可用 Batch API 降低离线任务成本，但第一版也可以用普通队列。

## 4. 什么叫“高质量内容”

### 4.1 不靠单一模型判断

“高质量”不能只靠 AI 打分。建议使用多因子评分。

```text
content_score =
  source_trust_score * 0.18
+ information_density * 0.16
+ novelty_score * 0.14
+ industry_impact_score * 0.16
+ actionability_score * 0.14
+ user_interest_match * 0.10
+ local_opportunity_match * 0.06
- marketing_penalty * 0.10
- duplication_penalty * 0.08
- clickbait_penalty * 0.06
```

### 4.2 评分解释

source_trust_score：

```text
官方发布 > 主流媒体 > 垂直媒体 > 普通自媒体 > 未知来源
```

information_density：

```text
是否包含具体数据、公司、人物、时间、地点、政策、产品、融资金额、技术参数。
```

novelty_score：

```text
是否是新事件，而不是旧闻翻炒。
```

industry_impact_score：

```text
是否会影响行业方向、供应链、融资、政策、招聘、技术路线。
```

actionability_score：

```text
用户看完是否能做下一步动作：报名、学习、联系、收藏、跟进、试用、投递、拜访。
```

marketing_penalty：

```text
明显软文、招商广告、课程销售、无实质信息的“圆满举办”降权。
```

### 4.3 人工校准机制

第一阶段建议每天人工审核 20 到 50 条候选内容，最终发布 5 到 8 条。

审核动作：

1. 通过。
2. 改写。
3. 降权。
4. 屏蔽来源。
5. 标记软文。
6. 标记重复。

这些动作反过来训练评分规则。

## 5. 本地活动从哪里来

### 5.1 活动源分层

#### A 类：活动平台 API

海外可用性更明确：

1. Luma API：官方文档提供日历事件列表接口，但需要 Luma Plus，适合订阅特定 calendar 的活动。
2. Meetup API：官方提供 API 文档，可搜索 groups/events，适合海外技术社区。
3. Eventbrite API：官方 API 可获取活动详情和组织者相关活动；但 Event Search by Location 官方文档标注已在 2019-12-12 关闭，因此不能把它作为“按城市全量搜活动”的可靠入口。

国内平台：

1. 活动行公开页面可用于用户跳转和人工筛选；其商业活动系统页面提到活动数据 API 接口和私有化部署，说明更可能通过商务合作获得稳定接口。
2. 互动吧等平台没有明显稳定公开 API，第一版不应强依赖。

结论：国内活动平台要准备商务合作和白名单采集两条路线，不能假设存在免费开放 API。

#### B 类：主办方官方源

这是最值得做的来源。

来源包括：

1. 大厂开发者社区活动页。
2. 云厂商活动页。
3. 园区和孵化器活动公告。
4. 政府/协会/商会活动通知。
5. 高校创新创业学院、技术社群页面。
6. 投资机构 Demo Day 页面。
7. 加速器、联合办公空间、产业园公众号。

优点：质量高，和 Link Storm 用户更匹配。  
缺点：格式分散，需要白名单配置和人工维护。

#### C 类：网页结构化数据

很多活动页会包含：

1. schema.org/Event JSON-LD。
2. Open Graph。
3. 页面中的时间、地点、主办方、票务链接。

采集策略：

```text
先解析 JSON-LD Event
-> 再解析 meta 标签
-> 再用规则抽取时间地点
-> 最后用 LLM 做补充结构化
```

#### D 类：用户和主办方提交

需要做“提交活动”入口。

提交后不要立即发布，进入审核：

```text
活动标题
主办方
时间
地点
报名链接
领域标签
适合人群
推荐理由
联系人
```

运营审核后入库。这条路能逐步建立自有活动供给。

### 5.2 活动采集链路

```text
活动源注册
-> 定时采集
-> 活动结构化
-> 地点地理编码
-> 主办方识别
-> 质量评分
-> 去重合并
-> 人工审核
-> 发布
```

### 5.3 活动去重

活动重复比新闻更麻烦，因为同一活动可能同时出现在活动行、公众号、主办方官网。

去重键：

```text
normalized_title
start_time
city
venue
organizer
registration_url
```

相似规则：

```text
标题相似度 > 0.85
且开始时间差 < 2 小时
且城市相同
则认为候选重复
```

### 5.4 活动质量评分

```text
activity_score =
  organizer_trust_score * 0.20
+ topic_match_score * 0.16
+ speaker_quality_score * 0.12
+ agenda_clarity_score * 0.12
+ registration_integrity_score * 0.10
+ location_relevance_score * 0.10
+ time_fit_score * 0.08
+ intelligence_link_score * 0.08
- pure_marketing_penalty * 0.12
- missing_info_penalty * 0.08
- duplicate_penalty * 0.06
```

高质量活动特征：

1. 主办方真实且可验证。
2. 时间地点明确。
3. 有完整议程。
4. 有真实嘉宾或机构。
5. 报名链路正常。
6. 与用户关注主题相关。
7. 与近期情报有连接。

低质量活动特征：

1. 标题夸张。
2. 全程卖课。
3. 无明确地点或时间。
4. 主办方不可查。
5. 重复铺量。
6. 报名链接异常。

## 6. 定位与地理服务

### 6.1 鸿蒙端定位策略

默认只使用城市级定位。

推荐权限策略：

1. 首次启动不强制要定位。
2. 用户进入“附近活动”时请求定位。
3. 默认请求 approximate/city 级定位。
4. 用户点击“按距离排序”时再请求精确定位。
5. 精确坐标只用于本次附近活动查询，不长期保存。

华为 Location Kit 支持融合 GNSS、Wi-Fi、基站等定位能力，可用于获取设备位置。产品上应优先手动城市选择 + 城市级定位，降低隐私成本。

### 6.2 地理编码和距离计算

活动入库时需要把地址转成经纬度。

可选方案：

1. 高德 Web 服务 API：提供地理编码、逆地理编码、关键字搜索、周边搜索等能力，适合中国大陆地址处理。
2. 腾讯位置服务/百度地图：可作为备选。
3. PostGIS：后端做距离查询、城市范围过滤、地理索引。

建议第一版：

```text
前端：HarmonyOS Location Kit 获取城市或经纬度
后端：PostgreSQL + PostGIS 存活动坐标
地理编码：高德 Web 服务 API
```

活动距离查询：

```sql
SELECT *
FROM activities
WHERE city = :city
  AND start_time >= now()
ORDER BY ST_Distance(location, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326))
LIMIT 50;
```

### 6.3 地图/POI 的边界

地图 API 能帮我们做：

1. 地址转经纬度。
2. 经纬度转城市。
3. 距离计算。
4. 场馆校验。
5. POI 补全。

地图 API 不能直接解决：

1. 哪些活动值得参加。
2. 哪些企业论坛正在举办。
3. 活动议程和质量判断。

所以活动源仍然要靠活动平台、主办方官网、园区/政府/协会、高校等页面。

## 7. 推荐系统设计

### 7.1 第一版不要做复杂深度学习推荐

MVP 的数据量不够，冷启动严重。第一版应该做可解释的混合推荐：

```text
规则召回 + 标签匹配 + 向量相似 + 行为加权 + 人工精选
```

这样能快速上线，也便于调试。

### 7.2 用户画像

用户画像分 5 类。

#### 显式画像

用户主动填写：

```text
城市
角色：创业者/开发者/投资人/企业管理者/学生/研究员
关注主题
关注行业
推送频率
是否愿意参加线下活动
```

#### 隐式画像

用户行为产生：

```text
查看
停留
打开来源
收藏
不感兴趣
加入日程
点击报名
分享
完成知而行之动作
```

#### 短期兴趣

最近 1 到 7 天兴趣，用于推荐当前热点。

```text
recent_topic_weights
recent_entity_weights
recent_city_weights
```

#### 长期兴趣

最近 30 到 180 天兴趣，用于稳定推荐。

```text
long_term_topic_weights
role_preference
activity_preference
source_preference
```

#### 负反馈画像

非常重要。

```text
blocked_topics
blocked_sources
blocked_activity_types
marketing_sensitivity
max_daily_push_count
```

### 7.3 召回层

每次给用户生成候选内容时，先从多个召回通道取候选。

```text
R1 今日高分情报
R2 用户关注主题
R3 用户城市相关
R4 用户最近阅读相似
R5 近期热点事件
R6 人工精选
R7 与已收藏内容相似
R8 附近高质量活动
```

每个通道最多取 20 到 50 条，然后合并去重。

### 7.4 排序层

情报排序公式：

```text
rank_score =
  content_score * 0.30
+ user_topic_match * 0.20
+ novelty_score * 0.12
+ freshness_score * 0.10
+ local_opportunity_match * 0.10
+ diversity_bonus * 0.08
+ actionability_score * 0.08
- fatigue_penalty * 0.10
- seen_penalty * 0.20
```

活动排序公式：

```text
rank_score =
  activity_score * 0.28
+ user_topic_match * 0.20
+ city_distance_score * 0.14
+ time_fit_score * 0.12
+ role_match_score * 0.10
+ intelligence_link_score * 0.08
- marketing_penalty * 0.12
- schedule_conflict_penalty * 0.08
```

### 7.5 多样性控制

首页 5 到 8 条情报不能全是同一主题。

规则：

1. 同一事件 cluster 只展示 1 条。
2. 同一来源最多 2 条。
3. 同一主题最多 3 条。
4. 至少保留 1 条本地机会。
5. 至少保留 1 条用户长期关注主题。
6. 如果有高分活动，插入情报流中的行动卡。

### 7.6 推荐解释

每条推荐必须能解释。

示例：

```text
推荐原因：
你关注「AI 智能体」
这条内容来自可信官方源
与深圳本周 2 场开发者活动相关
过去 24 小时已有 5 个来源报道同一事件
```

解释字段入库：

```text
recommendation_reasons: string[]
matched_topics: string[]
matched_user_signals: string[]
matched_activity_ids: string[]
```

## 8. 记忆系统设计

### 8.1 记忆不是聊天记录仓库

Link Storm 的记忆系统应该服务于推荐和行动，不应该无限保存用户隐私。

记忆分三层：

```text
偏好记忆：用户明确选择和长期行为
情境记忆：近期关注、当前城市、当前任务
行动记忆：收藏、日程、报名、实践任务
```

### 8.2 记忆数据表

#### user_interest_profile

```text
user_id
topic_weights: jsonb
entity_weights: jsonb
role_tags: text[]
city
activity_type_weights: jsonb
source_weights: jsonb
updated_at
```

#### user_memory_items

```text
id
user_id
memory_type: preference/context/action/negative
subject_type: topic/entity/source/activity/content
subject_id
summary
weight
confidence
expires_at
created_at
updated_at
```

#### user_action_log

```text
id
user_id
action_type
target_type
target_id
topic_tags
entity_tags
city
dwell_seconds
created_at
```

#### recommendation_impressions

```text
id
user_id
target_type
target_id
rank_position
rank_score
reasons
shown_at
clicked_at
feedback
```

### 8.3 记忆更新规则

行为权重建议：

```text
不感兴趣: -5
屏蔽来源: -8
快速划过: -1
普通查看: +1
停留超过 30 秒: +2
打开来源: +3
收藏: +5
加入日程: +6
点击报名: +8
完成实践任务: +10
```

时间衰减：

```text
短期兴趣半衰期：7 天
长期兴趣半衰期：60 天
负反馈半衰期：180 天，屏蔽类不自动衰减
```

### 8.4 记忆可见与可控

用户应该能看到和修改记忆。

“我的兴趣”页面展示：

```text
你最近更关注：
AI 智能体 +32
机器人 +18
跨境出海 +11

你不太想看：
泛营销课程
无地点线上课
重复融资快讯
```

用户可操作：

1. 增加主题。
2. 降低主题。
3. 删除历史。
4. 关闭个性化。
5. 只使用城市和显式兴趣推荐。

## 9. 知而行之与停止机制

### 9.1 停止不是强制打断

设计目标不是禁止用户继续看，而是在信息消费达到一定阈值后，把用户引导到行动。

触发条件：

```text
连续看满 20 条
或同一主题连续看 8 条
或阅读超过 8 分钟但没有任何行动
或用户主动点击“今天看到这里”
```

### 9.2 停止页推荐逻辑

停止页不展示更多新闻，而展示行动。

行动候选：

```text
学习材料
实践任务
附近活动
主题收藏
日程提醒
主办方/公司关注
```

生成规则：

```text
如果有附近活动：优先推荐活动
如果无活动但有高质量学习材料：推荐学习
如果用户是开发者：推荐实践任务
如果用户是投资/管理者：推荐公司/政策跟踪
```

示例：

```text
你已经连续阅读 8 条「AI 智能体」内容。
现在更值得做一个小行动：

1. 加入本周深圳 AI Agent 沙龙
2. 阅读 OpenAI Agents 指南
3. 用 Dify/Coze 搭一个客服 Agent
4. 收藏今天的 3 条关键信号
```

## 10. 灵感捕捉：语音、手写与文档笔记

### 10.1 功能定位

用户在看情报、活动、主题雷达或知而行之页面时，应该能随时记录自己的想法。

这个模块建议命名为 `Capture`，产品上可以叫“灵感捕捉”或“边看边记”。

核心目标：

```text
看到信息
-> 立刻记录想法
-> 自动关联上下文
-> 后续加工成文字、行动项、主题笔记
```

### 10.2 多端默认交互

同一套应用、同一套数据模型，根据设备形态和窗口尺寸选择默认捕捉方式。

```text
手机：优先语音
平板：优先写字板
PC/二合一：优先文档笔记
```

用户仍然可以手动切换：

```text
语音
手写
文字
```

判断策略：

```text
device_type + window_size_class + input_capability
```

示例：

1. 手机窄屏：底部弹出录音面板。
2. 平板横屏：右侧打开手写面板。
3. 二合一/PC：右侧打开文档编辑器。
4. 小窗口模式：降级为底部抽屉。

HarmonyOS 的“一次开发，多端部署”适合这种设计。布局上用断点、栅格、媒体查询、自适应布局和响应式布局，业务上复用同一个 CaptureService。

### 10.3 手机端：语音记录

#### 第一版能力

第一版必须能先保存原始语音，不依赖语音识别。

流程：

```text
用户点击/长按麦克风
-> 请求麦克风权限
-> 开始录音
-> 停止录音
-> 保存音频文件
-> 创建 capture 记录
-> 关联当前情报/活动/主题
-> 上传或本地暂存
```

本地录音可用 HarmonyOS 媒体/音频能力。HarmonyOS 文档中心中 Audio Kit 提供音频播放和录制接口，Media Kit 也提供录制相关能力；实际实现时可根据 DevEco Studio 当前 API 版本选择 AudioCapturer 或 AVRecorder。

#### 第二版能力：语音转文字

华为 Core Speech Kit 提供语音识别能力，可将实时语音或音频文件转换为文字。官方说明中短语音模式不超过 60 秒，长语音模式不超过 8 小时，支持 pcm 音频文件或实时语音转文字。

落地策略：

```text
优先接 Core Speech Kit
如果设备/地区/权限/额度不可用，则只保存音频
如果转写失败，保留原音频并允许后续重试
```

是否免费：

1. 目前公开产品页能确认有 Core Speech Kit 语音识别能力。
2. 免费额度、商业计费、地区限制需要在华为开发者控制台开通服务时确认。
3. 产品设计上不能假设永久免费。
4. MVP 应设计为“有转写更好，没有转写也能用”。

转写状态：

```text
pending
processing
done
failed
unsupported
```

### 10.4 平板端：写字板

#### 第一版能力

第一版建议做“笔迹保存”，不强制做手写识别。

流程：

```text
用户点击笔按钮
-> 打开写字板
-> 记录触控/手写笔轨迹
-> 保存矢量笔迹
-> 生成预览图
-> 关联当前上下文
```

可行技术：

1. ArkUI Canvas 或 ArkGraphics 2D 绘制笔迹。
2. 触控事件记录坐标、压力、时间戳。
3. 有手写笔能力时，记录 pen/stylus 输入特征。
4. 保存 stroke JSON 和预览 PNG。

笔迹数据示例：

```json
{
  "strokes": [
    {
      "color": "#111111",
      "width": 3,
      "points": [
        { "x": 12, "y": 48, "t": 1717850000, "pressure": 0.7 }
      ]
    }
  ]
}
```

#### 第二版能力：手写识别

如果后续能接入系统手写识别或第三方 OCR/手写识别，再把笔迹转换为文本。

MVP 不建议把手写识别作为阻塞项，因为：

1. 手写识别准确率受字迹影响大。
2. 接口可用性和设备能力需要实测。
3. 保存笔迹本身已经能满足“随时记下来”的核心体验。

### 10.5 PC/二合一端：文档笔记

二合一和 PC 场景下，用户更可能有键盘和更大屏幕，适合直接写成结构化文字。

交互：

```text
点击文档按钮
-> 右侧打开编辑面板
-> 支持标题、正文、清单
-> 可插入当前情报摘要
-> 可插入来源链接
-> 保存为主题笔记
```

第一版编辑能力：

1. 标题。
2. 正文。
3. 待办清单。
4. 引用当前情报/活动。
5. 自动保存。

第二版增强：

1. Markdown 快捷输入。
2. AI 整理成行动计划。
3. 多条 capture 合并成主题笔记。
4. 导出为文档。

### 10.6 Capture 数据模型

#### captures

```text
id
user_id
capture_type: audio/handwriting/text
title
raw_text
processed_text
summary
status
source_context_type: intelligence/activity/topic/stop_page
source_context_id
topic_tags
city
device_type
created_at
updated_at
```

#### capture_assets

```text
id
capture_id
asset_type: audio/stroke_json/preview_image/attachment
storage_url
local_uri
mime_type
duration_seconds
size_bytes
transcription_status
created_at
```

#### capture_actions

```text
id
capture_id
action_type: todo/calendar/follow_up/question/contact
title
description
due_at
status
created_at
updated_at
```

### 10.7 上下文关联

每条记录都必须保存创建时的上下文。

```text
当前情报 id
当前活动 id
当前主题
当前城市
当前推荐理由
当前页面
当前时间
```

原因：用户后续看到一条语音或手写笔记时，必须知道当时是在看什么。

示例：

```text
用户在“机器人供应链在华东升温”情报页录了一段语音。
系统自动关联：
主题：机器人、智能制造
城市：上海、苏州
来源：某公司融资新闻
相关活动：上海机器人开发者沙龙
```

### 10.8 AI 加工流程

后台任务：

```text
capture_created
-> 如果是音频：尝试转写
-> 如果是手写：生成预览，后续可尝试识别
-> 如果是文字：直接进入整理
-> 提取主题和实体
-> 生成标题
-> 提取行动项
-> 写入用户记忆
```

加工结果：

```text
标题
摘要
相关主题
相关公司/活动
行动项
问题清单
是否加入知而行之任务
```

### 10.9 权限与隐私

需要显式请求：

```text
麦克风权限
本地文件/媒体保存权限
云同步授权
```

隐私原则：

1. 录音默认只对用户本人可见。
2. 用户可以选择仅本地保存。
3. 上传云端前明确提示。
4. 删除 capture 时同时删除音频、笔迹和转写文本。
5. 语音转写需要单独说明可能调用云端服务。

### 10.10 MVP 建议

第一版做：

1. 手机录音保存。
2. 平板写字板保存笔迹和预览。
3. PC/二合一文本笔记。
4. 自动关联当前情报/活动/主题。
5. 后台预留转写状态。

第二版做：

1. 接 Core Speech Kit 做语音转文字。
2. AI 生成标题和行动项。
3. 多条记录合并成主题笔记。
4. 把行动项接入知而行之任务和日程。

## 11. 技术架构建议

### 11.1 MVP 架构

```text
HarmonyOS App
  -> API Gateway
  -> App Backend
  -> PostgreSQL + PostGIS + pgvector
  -> Redis
  -> Search Index
  -> Worker Queue
  -> Crawler/Fetcher
  -> AI Processing Service
  -> Admin Console
```

### 11.2 推荐技术栈

后端：

```text
Node.js/NestJS 或 Python/FastAPI
```

数据库：

```text
PostgreSQL
PostGIS：地理位置和距离查询
pgvector：内容 embedding 和相似推荐
Redis：缓存、队列、限流
```

搜索：

```text
MVP：PostgreSQL full-text + pgvector
中期：Meilisearch hybrid search 或 Elasticsearch/OpenSearch
大规模：Qdrant/Milvus 独立向量库
```

选择理由：

1. pgvector 官方支持在 Postgres 中存储和检索向量，支持 HNSW/IVFFlat 等索引，MVP 足够。
2. Meilisearch 支持关键词和语义混合搜索，适合后续做内容搜索。
3. Milvus/Qdrant 适合数据量和并发上来后的独立向量检索。

### 11.3 任务队列

任务类型：

```text
fetch_source
parse_article
parse_activity
extract_entities
generate_summary
score_content
dedupe_cluster
geocode_activity
build_daily_digest
send_push
```

第一版可用：

```text
BullMQ + Redis
或 Celery + Redis
```

### 11.4 管理后台

必须做一个轻量后台。

功能：

1. 来源管理。
2. 候选内容列表。
3. 情报审核。
4. 活动审核。
5. 评分解释查看。
6. 手动发布。
7. 屏蔽来源。
8. 用户反馈查看。

没有后台，内容质量无法稳定。

## 12. 推送系统

鸿蒙端可接入华为 Push Kit。华为 Push Kit 官方说明支持 HarmonyOS，并提供多种推送样式、人群划分、自动推送等能力。

推送策略：

```text
每日情报：每天 8:30
活动提醒：活动前 1 天、前 2 小时
即时推送：只给高价值重大事件
```

限制：

```text
每天主动推送最多 2 条
低分内容不推送
用户可关闭情报推送，仅保留活动提醒
```

## 13. 合规与风险

### 13.1 内容版权

原则：

1. 不复制全文。
2. 保存标题、摘要、元数据和必要证据片段。
3. 提供原文链接。
4. 对商业来源优先谈合作。
5. 对禁止采集来源不抓取。

### 13.2 用户隐私

原则：

1. 默认保存城市，不保存精确位置。
2. 精确位置只在附近活动查询时临时使用。
3. 用户可删除历史和画像。
4. 推荐理由可解释。
5. 不将用户个人行为出售给第三方。

### 13.3 录音、手写与笔记隐私

风险：

1. 语音中可能包含敏感个人信息。
2. 活动现场录音可能涉及他人声音。
3. 云端转写可能引入数据合规要求。
4. 手写笔记可能包含商业信息。

应对：

1. 默认私有。
2. 明确麦克风授权。
3. 支持仅本地保存。
4. 支持用户彻底删除。
5. 云端转写前明确说明。
6. 后台不把 capture 内容用于公开推荐池。

### 13.4 活动真实性

风险：

1. 虚假活动。
2. 卖课活动。
3. 过期活动。
4. 地点错误。
5. 报名链接失效。

应对：

1. 报名链接定时探活。
2. 活动前自动复查。
3. 主办方可信度评分。
4. 用户举报入口。
5. 高风险活动不推送。

## 14. 第一版落地计划

### 14.1 第 1 阶段：数据底座

目标：能人工维护来源、内容、活动。

交付：

1. PostgreSQL 数据表。
2. 来源注册表。
3. 情报表。
4. 活动表。
5. 用户行为表。
6. 后台录入和审核。

### 14.2 第 2 阶段：采集与结构化

目标：每天自动产生候选池。

交付：

1. RSS 采集。
2. 白名单网页采集。
3. 正文抽取。
4. 活动页结构化。
5. AI 摘要和标签。
6. 人工审核队列。

### 14.3 第 3 阶段：推荐与记忆

目标：让不同用户看到不同结果。

交付：

1. 用户显式兴趣。
2. 行为记录。
3. 规则推荐。
4. 向量相似推荐。
5. 推荐解释。
6. 负反馈。

### 14.4 第 4 阶段：鸿蒙闭环

目标：形成“情报 -> 活动 -> 日程 -> 提醒 -> 反馈”的闭环。

交付：

1. 鸿蒙端定位。
2. 附近活动。
3. 加入系统日程。
4. Push Kit 推送。
5. 知而行之停止页。
6. 我的兴趣和记忆管理。

### 14.5 第 5 阶段：灵感捕捉

目标：让用户能在阅读过程中随时记录想法。

交付：

1. 手机语音记录。
2. 平板写字板。
3. PC/二合一文档笔记。
4. Capture 数据表。
5. 上下文自动关联。
6. 语音转写状态预留。
7. AI 整理任务预留。

## 15. 推荐的第一版数据源清单

### 15.1 情报源

先建 50 到 100 个白名单源：

1. AI 公司官网和博客。
2. 云厂商开发者博客。
3. 机器人公司官网。
4. 出海服务公司博客。
5. 投资机构动态。
6. 政府/园区政策页面。
7. 36 氪、虎嗅、机器之心、量子位等媒体公开页面/RSS。
8. GitHub release / trending 相关源。
9. arXiv / Papers with Code / Hugging Face blog 等技术源。

### 15.2 活动源

先建 100 个活动来源：

1. 活动行搜索页和重点主办方页。
2. 大厂开发者社区活动页。
3. 深圳/上海/北京/杭州/广州重点园区页面。
4. 高校创新创业学院页面。
5. 投资机构 Demo Day 页面。
6. Luma 公开 calendar。
7. Meetup 技术组。
8. Eventbrite 重点 organizer 页面。
9. 主办方提交入口。

## 16. 技术取舍建议

### 16.1 最务实方案

```text
PostgreSQL + PostGIS + pgvector
Node.js/NestJS
BullMQ + Redis
Playwright/HTTP fetcher
Readability/trafilatura 正文抽取
LLM 结构化摘要
轻量管理后台
HarmonyOS ArkTS App
```

这是成本和复杂度最平衡的方案。

### 16.2 不建议第一版做

1. 不建议自研复杂深度推荐模型。
2. 不建议全网爬取。
3. 不建议完全自动发布。
4. 不建议长期保存精确定位。
5. 不建议一开始做社交和评论。
6. 不建议接太多第三方 API，先把数据质量跑通。

## 17. 外部资料与验证链接

1. NewsAPI 文档：https://newsapi.org/docs/endpoints
2. mediastack 文档：https://mediastack.com/documentation
3. Event Registry：https://www.eventregistry.org/
4. Luma API：https://help.luma.com/p/luma-api
5. Luma List Events：https://docs.luma.com/reference/get_v1-calendar-list-events
6. Eventbrite Events API：https://www.eventbrite.com/platform/docs/events
7. Eventbrite Location Search deprecated：https://www.eventbrite.com/platform/docs/by-location
8. Meetup API：https://www.meetup.com/api/schema/
9. RSS 2.0 规范：https://cyber.harvard.edu/rss/rss.html
10. Schema.org Event：https://schema.org/Event
11. 华为 Location Kit：https://developer.huawei.com/consumer/cn/sdk/location-kit
12. 华为 Push Kit：https://developer.huawei.com/consumer/cn/hms/huawei-pushkit/
13. HarmonyOS Calendar Kit 日程管理：https://developer.harmonyos.cool/docs/dev/app-dev/application-services/calendar-kit/calendarmanager-event-developer/
14. 高德 Web 服务 API：https://developer.amap.com/api/webservice/summary
15. 高德搜索服务 API：https://developer.amap.com/api/webservice/guide/api/search/
16. pgvector：https://github.com/pgvector/pgvector
17. Meilisearch Hybrid Search：https://www.meilisearch.com/docs/learn/ai_powered_search/difference_full_text_ai_search
18. OpenAI Structured Outputs：https://platform.openai.com/docs/guides/structured-outputs
19. OpenAI Batch API：https://platform.openai.com/docs/guides/batch/
20. 华为 Core Speech Kit：https://developer.huawei.com/consumer/cn/sdk/core-speech-kit
21. HarmonyOS Audio 录制文档：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/audio-fast-recording
22. HarmonyOS 文档中心媒体能力：https://developer.huawei.com/consumer/cn/doc/
23. HarmonyOS 一次开发多端部署：https://developer.harmonyos.cool/docs/dev/app-dev/multi-device/bpta-multi-device-overview/
24. HarmonyOS 布局基础：https://developer.harmonyos.cool/docs/design/general-design-basics/layout/layout-basics/

# 数据库 Schema

本目录包含**智能健康管理平台与饮食推荐系统**的数据库脚本。

## 文件说明

| 文件 | 用途 |
|------|------|
| `schema.sql`    | MySQL 8.x 生产/测试环境 DDL |
| `schema-pg.sql` | PostgreSQL 14+ 生产/测试环境 DDL |
| `schema-h2.sql` | H2（内存模式）开发/单测 DDL |
| `data.sql`      | MySQL 演示种子数据（开发/演示专用，勿用于生产） |

---

## 数据表概览

```
users                    — 用户基本信息（账号、体征、健康目标）
user_profiles            — 用户画像与偏好（口味、忌口、宏量目标、近期均值）
health_data              — 每日健康数据（步数、心率、血压、睡眠、饮水）
food_items               — 食材与营养成分库（每 100 g 宏量 + 微量元素）
diet_records             — 用户饮食记录（餐次、份量、营养计算值）
recipes                  — 食谱库（步骤、营养、难度、健康目标标签）
recipe_ingredients       — 食谱与食材的关联（用量）
health_recommendations   — 健康建议（运动/饮食/睡眠/补水/医疗，规则或 AI 生成）
community_posts          — 社区帖子（分类、审核状态）
post_comments            — 帖子评论（支持嵌套回复）
post_likes               — 帖子点赞（去重）
user_favorite_recipes    — 用户收藏食谱
recipe_recommendations   — 食谱推荐历史与用户反馈
chat_sessions            — AI 对话会话（消息、工具调用轨迹）
```

### 视图

| 视图 | 说明 |
|------|------|
| `v_daily_nutrition`   | 用户当日各餐营养汇总（热量、蛋白质、脂肪、碳水、纤维） |
| `v_health_weekly_avg` | 近 7 日健康数据均值（步数、心率、睡眠、消耗热量、饮水） |

---

## 实体关系摘要

```
users (1) ─── (1)  user_profiles
users (1) ─── (N)  health_data
users (1) ─── (N)  diet_records
users (1) ─── (N)  health_recommendations
users (1) ─── (N)  community_posts
users (1) ─── (N)  post_comments
users (1) ─── (N)  post_likes
users (1) ─── (N)  user_favorite_recipes
users (1) ─── (N)  recipe_recommendations
users (1) ─── (N)  chat_sessions

recipes   (1) ─── (N)  recipe_ingredients  ─── (N) food_items
recipes   (1) ─── (N)  recipe_recommendations
recipes   (1) ─── (N)  user_favorite_recipes

community_posts (1) ─── (N)  post_comments
community_posts (1) ─── (N)  post_likes
```

---

## 快速开始

### MySQL

```bash
mysql -u root -p < db/schema.sql
# 可选：导入演示数据
mysql -u root -p < db/data.sql
```

### PostgreSQL

```bash
psql -U postgres -d health_platform -f db/schema-pg.sql
```

### Spring Boot（H2 开发模式）

在 `application-dev.yml` 中配置：

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:health;MODE=MySQL;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE
    driver-class-name: org.h2.Driver
  sql:
    init:
      schema-locations: classpath:db/schema-h2.sql
      mode: always
```

---

## 安全说明

- 密码字段 `password_hash` 存储 **BCrypt** 哈希，原始明文不落库。
- `raw_data` 字段保留原始设备数据用于回溯，数据展示时需脱敏。
- 验证码、限流计数器等短生命周期数据由 **Redis** 管理，不在此建表。
- 健康建议内容（尤其 `MEDICAL` 类型）须附加免责声明，不构成医疗建议。

-- ============================================================
-- 智能健康管理平台与饮食推荐系统 — MySQL 数据库 Schema
-- 适用数据库：MySQL 8.x
-- 字符集：utf8mb4  排序规则：utf8mb4_unicode_ci
-- ============================================================

CREATE DATABASE IF NOT EXISTS health_platform
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE health_platform;

-- ============================================================
-- 1. 用户表 (users)
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '用户ID',
    username      VARCHAR(50)  NOT NULL                COMMENT '用户名（唯一）',
    email         VARCHAR(100) NOT NULL                COMMENT '邮箱（唯一）',
    password_hash VARCHAR(255) NOT NULL                COMMENT 'BCrypt 密码哈希',
    phone         VARCHAR(20)  DEFAULT NULL            COMMENT '手机号（可选，唯一）',
    -- 个人档案
    age           TINYINT UNSIGNED DEFAULT NULL        COMMENT '年龄',
    gender        ENUM('MALE','FEMALE','OTHER') DEFAULT NULL COMMENT '性别',
    height_cm     DECIMAL(5,2) DEFAULT NULL            COMMENT '身高（cm）',
    weight_kg     DECIMAL(5,2) DEFAULT NULL            COMMENT '体重（kg）',
    -- 健康目标
    health_goal   ENUM(
                      'LOSE_WEIGHT',
                      'GAIN_WEIGHT',
                      'MAINTAIN',
                      'BUILD_MUSCLE',
                      'IMPROVE_HEALTH'
                  ) DEFAULT 'MAINTAIN'                COMMENT '健康目标',
    -- 账号状态
    role          ENUM('USER','ADMIN') NOT NULL DEFAULT 'USER' COMMENT '角色',
    enabled       TINYINT(1) NOT NULL DEFAULT 1        COMMENT '账号是否启用',
    email_verified TINYINT(1) NOT NULL DEFAULT 0       COMMENT '邮箱是否已验证',
    -- 时间戳
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP  COMMENT '创建时间',
    updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                      ON UPDATE CURRENT_TIMESTAMP      COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_username (username),
    UNIQUE KEY uq_users_email    (email),
    UNIQUE KEY uq_users_phone    (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='用户基本信息';

-- ============================================================
-- 2. 用户画像 / 偏好表 (user_profiles)
--    与 users 一对一
-- ============================================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id              BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id         BIGINT NOT NULL                COMMENT '关联用户ID',
    -- 口味与饮食习惯（JSON 数组）
    flavor_prefs    JSON   DEFAULT NULL            COMMENT '口味偏好，如 ["辣","甜"]',
    diet_habits     JSON   DEFAULT NULL            COMMENT '饮食习惯，如 ["低碳","素食"]',
    allergies       JSON   DEFAULT NULL            COMMENT '过敏源，如 ["花生","贝类"]',
    avoidances      JSON   DEFAULT NULL            COMMENT '忌口，如 ["猪肉","酒"]',
    -- 目标数据
    target_weight_kg  DECIMAL(5,2) DEFAULT NULL    COMMENT '目标体重（kg）',
    target_calories   INT          DEFAULT NULL    COMMENT '每日目标热量（kcal）',
    target_protein_g  DECIMAL(6,2) DEFAULT NULL    COMMENT '每日目标蛋白质（g）',
    target_fat_g      DECIMAL(6,2) DEFAULT NULL    COMMENT '每日目标脂肪（g）',
    target_carbs_g    DECIMAL(6,2) DEFAULT NULL    COMMENT '每日目标碳水（g）',
    -- 近期均值（定时任务更新）
    avg_steps_7d      INT          DEFAULT NULL    COMMENT '近7日平均步数',
    avg_sleep_h_7d    DECIMAL(4,2) DEFAULT NULL    COMMENT '近7日平均睡眠（h）',
    avg_calories_in_7d  INT        DEFAULT NULL    COMMENT '近7日平均热量摄入（kcal）',
    avg_calories_out_7d INT        DEFAULT NULL    COMMENT '近7日平均热量消耗（kcal）',
    avg_heart_rate_7d   INT        DEFAULT NULL    COMMENT '近7日平均心率（bpm）',
    -- 时间戳
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                        ON UPDATE CURRENT_TIMESTAMP COMMENT '画像最后更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uq_user_profiles_user_id (user_id),
    CONSTRAINT fk_user_profiles_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='用户画像与偏好';

-- ============================================================
-- 3. 健康数据表 (health_data)
-- ============================================================
CREATE TABLE IF NOT EXISTS health_data (
    id              BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id         BIGINT NOT NULL                COMMENT '关联用户ID',
    record_date     DATE   NOT NULL                COMMENT '记录日期',
    -- 运动数据
    steps           INT          DEFAULT NULL      COMMENT '步数',
    calories_burned INT          DEFAULT NULL      COMMENT '消耗热量（kcal）',
    -- 心血管指标
    heart_rate      SMALLINT     DEFAULT NULL      COMMENT '心率（bpm）',
    systolic_bp     SMALLINT     DEFAULT NULL      COMMENT '收缩压（mmHg）',
    diastolic_bp    SMALLINT     DEFAULT NULL      COMMENT '舒张压（mmHg）',
    -- 睡眠与水分
    sleep_hours     DECIMAL(4,2) DEFAULT NULL      COMMENT '睡眠时长（h）',
    water_ml        INT          DEFAULT NULL      COMMENT '饮水量（ml）',
    -- 数据来源
    data_source     ENUM('MANUAL','DEVICE','IMPORT') NOT NULL DEFAULT 'MANUAL'
                                                   COMMENT '数据来源',
    raw_data        JSON DEFAULT NULL              COMMENT '原始设备数据（保留用于回溯）',
    -- 时间戳
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    UNIQUE KEY uq_health_data_user_date (user_id, record_date),
    INDEX idx_health_data_user_id   (user_id),
    INDEX idx_health_data_date      (record_date),
    CONSTRAINT fk_health_data_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='每日健康数据记录';

-- ============================================================
-- 4. 食材 / 营养成分表 (food_items)
-- ============================================================
CREATE TABLE IF NOT EXISTS food_items (
    id              BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    name            VARCHAR(100) NOT NULL           COMMENT '食材名称',
    alias           VARCHAR(200) DEFAULT NULL       COMMENT '别名（逗号分隔）',
    category        VARCHAR(50)  DEFAULT NULL       COMMENT '分类，如 蔬菜/水果/肉类',
    tags            JSON         DEFAULT NULL       COMMENT '标签，如 ["低糖","高蛋白"]',
    -- 每 100g 营养成分
    calories_per100g   DECIMAL(7,2) DEFAULT NULL    COMMENT '热量（kcal/100g）',
    protein_per100g    DECIMAL(7,2) DEFAULT NULL    COMMENT '蛋白质（g/100g）',
    fat_per100g        DECIMAL(7,2) DEFAULT NULL    COMMENT '脂肪（g/100g）',
    carbs_per100g      DECIMAL(7,2) DEFAULT NULL    COMMENT '碳水化合物（g/100g）',
    fiber_per100g      DECIMAL(7,2) DEFAULT NULL    COMMENT '膳食纤维（g/100g）',
    sodium_per100g     DECIMAL(7,2) DEFAULT NULL    COMMENT '钠（mg/100g）',
    potassium_per100g  DECIMAL(7,2) DEFAULT NULL    COMMENT '钾（mg/100g）',
    magnesium_per100g  DECIMAL(7,2) DEFAULT NULL    COMMENT '镁（mg/100g）',
    -- 过敏与忌口标记
    allergen_flags  JSON         DEFAULT NULL       COMMENT '过敏原标记，如 ["花生","坚果"]',
    -- 元数据
    data_source     VARCHAR(100) DEFAULT NULL       COMMENT '营养数据来源',
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                        ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    INDEX idx_food_items_name (name),
    INDEX idx_food_items_category (category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='食材及营养成分库';

-- ============================================================
-- 5. 饮食记录表 (diet_records)
-- ============================================================
CREATE TABLE IF NOT EXISTS diet_records (
    id              BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id         BIGINT NOT NULL                COMMENT '关联用户ID',
    food_item_id    BIGINT DEFAULT NULL            COMMENT '关联食材ID（可为空，支持自由输入）',
    meal_time       DATETIME NOT NULL              COMMENT '用餐时间',
    meal_type       ENUM('BREAKFAST','LUNCH','DINNER','SNACK') NOT NULL
                                                   COMMENT '餐次类型',
    food_name       VARCHAR(100) NOT NULL          COMMENT '食物名称（可覆盖food_item名称）',
    food_desc       VARCHAR(500) DEFAULT NULL      COMMENT '食物描述',
    serving_amount  DECIMAL(7,2) DEFAULT NULL      COMMENT '份量数值',
    serving_unit    VARCHAR(20)  DEFAULT NULL      COMMENT '份量单位，如 g/ml/份',
    -- 营养信息（按实际份量计算）
    calories        DECIMAL(7,2) DEFAULT NULL      COMMENT '热量（kcal）',
    protein_g       DECIMAL(7,2) DEFAULT NULL      COMMENT '蛋白质（g）',
    fat_g           DECIMAL(7,2) DEFAULT NULL      COMMENT '脂肪（g）',
    carbs_g         DECIMAL(7,2) DEFAULT NULL      COMMENT '碳水化合物（g）',
    fiber_g         DECIMAL(7,2) DEFAULT NULL      COMMENT '膳食纤维（g）',
    -- 时间戳
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    INDEX idx_diet_records_user_id   (user_id),
    INDEX idx_diet_records_meal_time (meal_time),
    INDEX idx_diet_records_user_date (user_id, meal_time),
    CONSTRAINT fk_diet_records_user      FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_diet_records_food_item FOREIGN KEY (food_item_id)
        REFERENCES food_items (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='用户饮食记录';

-- ============================================================
-- 6. 食谱表 (recipes)
-- ============================================================
CREATE TABLE IF NOT EXISTS recipes (
    id              BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    name            VARCHAR(150) NOT NULL          COMMENT '食谱名称',
    description     TEXT         DEFAULT NULL      COMMENT '食谱描述',
    steps           JSON         DEFAULT NULL      COMMENT '制作步骤（有序 JSON 数组）',
    prep_time_min   SMALLINT     DEFAULT NULL      COMMENT '准备时间（分钟）',
    cook_time_min   SMALLINT     DEFAULT NULL      COMMENT '烹饪时间（分钟）',
    servings        TINYINT      DEFAULT 1         COMMENT '份数',
    difficulty      ENUM('EASY','MEDIUM','HARD') DEFAULT 'EASY' COMMENT '难度',
    -- 每份营养（基于 servings）
    calories_per_serving  DECIMAL(7,2) DEFAULT NULL COMMENT '每份热量（kcal）',
    protein_per_serving   DECIMAL(7,2) DEFAULT NULL COMMENT '每份蛋白质（g）',
    fat_per_serving       DECIMAL(7,2) DEFAULT NULL COMMENT '每份脂肪（g）',
    carbs_per_serving     DECIMAL(7,2) DEFAULT NULL COMMENT '每份碳水（g）',
    fiber_per_serving     DECIMAL(7,2) DEFAULT NULL COMMENT '每份纤维（g）',
    sodium_per_serving    DECIMAL(7,2) DEFAULT NULL COMMENT '每份钠（mg）',
    -- 健康目标标签
    health_goal_tags JSON DEFAULT NULL             COMMENT '适合的健康目标，如 ["减重","心脏健康"]',
    allergen_flags   JSON DEFAULT NULL             COMMENT '含有的过敏原',
    -- 时间戳
    created_by      BIGINT   DEFAULT NULL          COMMENT '创建者用户ID（NULL 表示系统内置）',
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                        ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    INDEX idx_recipes_difficulty (difficulty),
    INDEX idx_recipes_created_by (created_by),
    CONSTRAINT fk_recipes_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='食谱库';

-- ============================================================
-- 7. 食谱食材关联表 (recipe_ingredients)
--    一个食谱对应多个食材，多对多
-- ============================================================
CREATE TABLE IF NOT EXISTS recipe_ingredients (
    id           BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    recipe_id    BIGINT NOT NULL               COMMENT '食谱ID',
    food_item_id BIGINT NOT NULL               COMMENT '食材ID',
    amount       DECIMAL(8,2) DEFAULT NULL     COMMENT '用量数值',
    unit         VARCHAR(20)  DEFAULT NULL     COMMENT '用量单位，如 g/ml/个',
    note         VARCHAR(200) DEFAULT NULL     COMMENT '备注，如 "切丁"、"焯水"',
    PRIMARY KEY (id),
    UNIQUE KEY uq_recipe_ingredient (recipe_id, food_item_id),
    CONSTRAINT fk_ri_recipe    FOREIGN KEY (recipe_id)    REFERENCES recipes    (id) ON DELETE CASCADE,
    CONSTRAINT fk_ri_food_item FOREIGN KEY (food_item_id) REFERENCES food_items (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='食谱与食材的关联（用量）';

-- ============================================================
-- 8. 健康建议表 (health_recommendations)
-- ============================================================
CREATE TABLE IF NOT EXISTS health_recommendations (
    id              BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id         BIGINT NOT NULL                COMMENT '关联用户ID',
    title           VARCHAR(200) NOT NULL          COMMENT '建议标题',
    content         TEXT         NOT NULL          COMMENT '建议内容',
    rec_type        ENUM(
                        'EXERCISE',
                        'DIET',
                        'SLEEP',
                        'HYDRATION',
                        'MEDICAL'
                    ) NOT NULL                     COMMENT '建议类型',
    priority        TINYINT NOT NULL DEFAULT 5     COMMENT '优先级（1 最高，10 最低）',
    is_active       TINYINT(1) NOT NULL DEFAULT 1  COMMENT '是否有效',
    source          ENUM('RULE','AI') DEFAULT 'RULE' COMMENT '建议来源',
    -- 时间戳
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    expires_at      DATETIME DEFAULT NULL           COMMENT '建议过期时间',
    PRIMARY KEY (id),
    INDEX idx_hr_user_id   (user_id),
    INDEX idx_hr_rec_type  (rec_type),
    INDEX idx_hr_is_active (is_active),
    CONSTRAINT fk_hr_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='健康建议';

-- ============================================================
-- 9. 社区帖子表 (community_posts)
-- ============================================================
CREATE TABLE IF NOT EXISTS community_posts (
    id          BIGINT NOT NULL AUTO_INCREMENT  COMMENT '主键',
    user_id     BIGINT NOT NULL                 COMMENT '作者用户ID',
    title       VARCHAR(300) NOT NULL           COMMENT '标题',
    content     TEXT         NOT NULL           COMMENT '正文内容',
    category    ENUM(
                    'HEALTH_TIPS',
                    'DIET_EXPERIENCE',
                    'EXERCISE_DIARY',
                    'SUCCESS_STORY',
                    'OTHER'
                ) NOT NULL DEFAULT 'OTHER'      COMMENT '分类',
    status      ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'APPROVED'
                                                COMMENT '审核状态',
    like_count    INT NOT NULL DEFAULT 0        COMMENT '点赞数',
    comment_count INT NOT NULL DEFAULT 0        COMMENT '评论数（冗余，定期同步）',
    -- 时间戳
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    INDEX idx_cp_user_id  (user_id),
    INDEX idx_cp_category (category),
    INDEX idx_cp_status   (status),
    INDEX idx_cp_created  (created_at),
    CONSTRAINT fk_cp_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='社区帖子';

-- ============================================================
-- 10. 帖子评论表 (post_comments)
-- ============================================================
CREATE TABLE IF NOT EXISTS post_comments (
    id          BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    post_id     BIGINT NOT NULL               COMMENT '帖子ID',
    user_id     BIGINT NOT NULL               COMMENT '评论者用户ID',
    parent_id   BIGINT DEFAULT NULL           COMMENT '父评论ID（NULL 为一级评论）',
    content     TEXT   NOT NULL               COMMENT '评论内容',
    status      ENUM('APPROVED','REJECTED') NOT NULL DEFAULT 'APPROVED'
                                              COMMENT '审核状态',
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    INDEX idx_pc_post_id   (post_id),
    INDEX idx_pc_user_id   (user_id),
    INDEX idx_pc_parent_id (parent_id),
    CONSTRAINT fk_pc_post   FOREIGN KEY (post_id)   REFERENCES community_posts (id) ON DELETE CASCADE,
    CONSTRAINT fk_pc_user   FOREIGN KEY (user_id)   REFERENCES users           (id) ON DELETE CASCADE,
    CONSTRAINT fk_pc_parent FOREIGN KEY (parent_id) REFERENCES post_comments   (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='帖子评论';

-- ============================================================
-- 11. 帖子点赞表 (post_likes)
-- ============================================================
CREATE TABLE IF NOT EXISTS post_likes (
    post_id    BIGINT NOT NULL COMMENT '帖子ID',
    user_id    BIGINT NOT NULL COMMENT '点赞用户ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '点赞时间',
    PRIMARY KEY (post_id, user_id),
    INDEX idx_pl_user_id (user_id),
    CONSTRAINT fk_pl_post FOREIGN KEY (post_id) REFERENCES community_posts (id) ON DELETE CASCADE,
    CONSTRAINT fk_pl_user FOREIGN KEY (user_id) REFERENCES users           (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='帖子点赞（去重）';

-- ============================================================
-- 12. 用户收藏食谱表 (user_favorite_recipes)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_favorite_recipes (
    user_id    BIGINT NOT NULL COMMENT '用户ID',
    recipe_id  BIGINT NOT NULL COMMENT '食谱ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '收藏时间',
    PRIMARY KEY (user_id, recipe_id),
    CONSTRAINT fk_ufr_user   FOREIGN KEY (user_id)   REFERENCES users   (id) ON DELETE CASCADE,
    CONSTRAINT fk_ufr_recipe FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='用户收藏的食谱';

-- ============================================================
-- 13. 食谱推荐历史表 (recipe_recommendations)
--     记录系统每次向用户推送的推荐结果
-- ============================================================
CREATE TABLE IF NOT EXISTS recipe_recommendations (
    id          BIGINT NOT NULL AUTO_INCREMENT  COMMENT '主键',
    user_id     BIGINT NOT NULL                 COMMENT '用户ID',
    recipe_id   BIGINT NOT NULL                 COMMENT '推荐食谱ID',
    strategy    ENUM('RULE','COLLABORATIVE','CONTENT','HYBRID','AI')
                NOT NULL DEFAULT 'RULE'         COMMENT '推荐策略',
    score       DECIMAL(5,4) DEFAULT NULL       COMMENT '推荐得分（0-1）',
    reason      VARCHAR(500) DEFAULT NULL       COMMENT '推荐原因（简短说明）',
    -- 用户反馈
    feedback    ENUM('ADOPTED','IGNORED','DISLIKED') DEFAULT NULL COMMENT '用户反馈',
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '推荐时间',
    PRIMARY KEY (id),
    INDEX idx_rr_user_id   (user_id),
    INDEX idx_rr_recipe_id (recipe_id),
    INDEX idx_rr_created   (created_at),
    CONSTRAINT fk_rr_user   FOREIGN KEY (user_id)   REFERENCES users   (id) ON DELETE CASCADE,
    CONSTRAINT fk_rr_recipe FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='食谱推荐历史与用户反馈';

-- ============================================================
-- 14. AI 对话会话表 (chat_sessions)
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_sessions (
    id              BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id         BIGINT NOT NULL               COMMENT '关联用户ID',
    title           VARCHAR(200) DEFAULT NULL     COMMENT '会话标题（自动生成或用户命名）',
    messages        JSON         DEFAULT NULL     COMMENT '消息列表（含摘要/历史）',
    model_info      VARCHAR(100) DEFAULT NULL     COMMENT '使用的模型标识',
    tool_calls_log  JSON         DEFAULT NULL     COMMENT '工具调用轨迹',
    audit_flag      TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否已审计标记',
    -- 时间戳
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                        ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    INDEX idx_cs_user_id  (user_id),
    INDEX idx_cs_updated  (updated_at),
    CONSTRAINT fk_cs_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='AI 对话会话';

-- ============================================================
-- 15. 限流计数 / 验证码等由 Redis 管理，此处不建表
-- ============================================================

-- ============================================================
-- 视图：用户当日营养汇总 (v_daily_nutrition)
-- ============================================================
CREATE OR REPLACE VIEW v_daily_nutrition AS
SELECT
    user_id,
    DATE(meal_time)                AS record_date,
    SUM(calories)                  AS total_calories,
    SUM(protein_g)                 AS total_protein_g,
    SUM(fat_g)                     AS total_fat_g,
    SUM(carbs_g)                   AS total_carbs_g,
    SUM(fiber_g)                   AS total_fiber_g,
    COUNT(*)                       AS meal_count
FROM diet_records
GROUP BY user_id, DATE(meal_time);

-- ============================================================
-- 视图：近 7 日健康数据均值 (v_health_weekly_avg)
-- ============================================================
CREATE OR REPLACE VIEW v_health_weekly_avg AS
SELECT
    user_id,
    AVG(steps)           AS avg_steps,
    AVG(heart_rate)      AS avg_heart_rate,
    AVG(sleep_hours)     AS avg_sleep_hours,
    AVG(calories_burned) AS avg_calories_burned,
    AVG(water_ml)        AS avg_water_ml,
    MAX(record_date)     AS latest_record_date
FROM health_data
WHERE record_date >= CURDATE() - INTERVAL 7 DAY
GROUP BY user_id;

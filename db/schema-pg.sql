-- ============================================================
-- 智能健康管理平台与饮食推荐系统 — PostgreSQL Schema
-- 适用版本：PostgreSQL 14+
-- ============================================================

-- 可选：创建独立 Schema（适合多租户或命名空间隔离）
-- CREATE SCHEMA IF NOT EXISTS health_platform;
-- SET search_path TO health_platform;

-- ============================================================
-- 扩展
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid(), crypt()
-- 如需向量检索（RAG），启用 pgvector：
-- CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================
-- 枚举类型
-- ============================================================
DO $$ BEGIN
    CREATE TYPE gender_type AS ENUM ('MALE', 'FEMALE', 'OTHER');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE health_goal_type AS ENUM (
        'LOSE_WEIGHT', 'GAIN_WEIGHT', 'MAINTAIN', 'BUILD_MUSCLE', 'IMPROVE_HEALTH'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE user_role_type AS ENUM ('USER', 'ADMIN');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE data_source_type AS ENUM ('MANUAL', 'DEVICE', 'IMPORT');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE meal_type AS ENUM ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE difficulty_type AS ENUM ('EASY', 'MEDIUM', 'HARD');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE rec_type AS ENUM (
        'EXERCISE', 'DIET', 'SLEEP', 'HYDRATION', 'MEDICAL'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE rec_source_type AS ENUM ('RULE', 'AI');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE post_category_type AS ENUM (
        'HEALTH_TIPS', 'DIET_EXPERIENCE', 'EXERCISE_DIARY', 'SUCCESS_STORY', 'OTHER'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE moderation_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE rec_strategy_type AS ENUM (
        'RULE', 'COLLABORATIVE', 'CONTENT', 'HYBRID', 'AI'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE feedback_type AS ENUM ('ADOPTED', 'IGNORED', 'DISLIKED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- 1. 用户表 (users)
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id              BIGSERIAL         PRIMARY KEY,
    username        VARCHAR(50)       NOT NULL UNIQUE,
    email           VARCHAR(100)      NOT NULL UNIQUE,
    password_hash   VARCHAR(255)      NOT NULL,
    phone           VARCHAR(20)       UNIQUE,
    -- 个人档案
    age             SMALLINT          CHECK (age BETWEEN 1 AND 150),
    gender          gender_type,
    height_cm       NUMERIC(5,2)      CHECK (height_cm > 0),
    weight_kg       NUMERIC(5,2)      CHECK (weight_kg > 0),
    -- 健康目标
    health_goal     health_goal_type  NOT NULL DEFAULT 'MAINTAIN',
    -- 账号状态
    role            user_role_type    NOT NULL DEFAULT 'USER',
    enabled         BOOLEAN           NOT NULL DEFAULT TRUE,
    email_verified  BOOLEAN           NOT NULL DEFAULT FALSE,
    -- 时间戳
    created_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  users                IS '用户基本信息';
COMMENT ON COLUMN users.password_hash  IS 'BCrypt 密码哈希';
COMMENT ON COLUMN users.health_goal    IS '用户健康目标';

-- ============================================================
-- 2. 用户画像 / 偏好表 (user_profiles)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id                   BIGSERIAL    PRIMARY KEY,
    user_id              BIGINT       NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
    -- 偏好（JSONB 支持 GIN 索引查询）
    flavor_prefs         JSONB        DEFAULT NULL,
    diet_habits          JSONB        DEFAULT NULL,
    allergies            JSONB        DEFAULT NULL,
    avoidances           JSONB        DEFAULT NULL,
    -- 目标
    target_weight_kg     NUMERIC(5,2),
    target_calories      INT,
    target_protein_g     NUMERIC(6,2),
    target_fat_g         NUMERIC(6,2),
    target_carbs_g       NUMERIC(6,2),
    -- 近7日均值（定时任务更新）
    avg_steps_7d         INT,
    avg_sleep_h_7d       NUMERIC(4,2),
    avg_calories_in_7d   INT,
    avg_calories_out_7d  INT,
    avg_heart_rate_7d    INT,
    -- 时间戳
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE user_profiles IS '用户画像与偏好';

-- ============================================================
-- 3. 健康数据表 (health_data)
-- ============================================================
CREATE TABLE IF NOT EXISTS health_data (
    id              BIGSERIAL        PRIMARY KEY,
    user_id         BIGINT           NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    record_date     DATE             NOT NULL,
    -- 运动
    steps           INT              CHECK (steps >= 0),
    calories_burned INT              CHECK (calories_burned >= 0),
    -- 心血管
    heart_rate      SMALLINT         CHECK (heart_rate BETWEEN 20 AND 300),
    systolic_bp     SMALLINT         CHECK (systolic_bp BETWEEN 50 AND 300),
    diastolic_bp    SMALLINT         CHECK (diastolic_bp BETWEEN 30 AND 200),
    -- 睡眠与水分
    sleep_hours     NUMERIC(4,2)     CHECK (sleep_hours BETWEEN 0 AND 24),
    water_ml        INT              CHECK (water_ml >= 0),
    -- 来源
    data_source     data_source_type NOT NULL DEFAULT 'MANUAL',
    raw_data        JSONB            DEFAULT NULL,
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, record_date)
);

COMMENT ON TABLE health_data IS '每日健康数据记录';

CREATE INDEX IF NOT EXISTS idx_health_data_user_id   ON health_data (user_id);
CREATE INDEX IF NOT EXISTS idx_health_data_date      ON health_data (record_date);

-- ============================================================
-- 4. 食材 / 营养成分表 (food_items)
-- ============================================================
CREATE TABLE IF NOT EXISTS food_items (
    id                  BIGSERIAL    PRIMARY KEY,
    name                VARCHAR(100) NOT NULL,
    alias               VARCHAR(200),
    category            VARCHAR(50),
    tags                JSONB        DEFAULT NULL,
    -- 每 100g 营养成分
    calories_per100g    NUMERIC(7,2),
    protein_per100g     NUMERIC(7,2),
    fat_per100g         NUMERIC(7,2),
    carbs_per100g       NUMERIC(7,2),
    fiber_per100g       NUMERIC(7,2),
    sodium_per100g      NUMERIC(7,2),
    potassium_per100g   NUMERIC(7,2),
    magnesium_per100g   NUMERIC(7,2),
    -- 过敏
    allergen_flags      JSONB        DEFAULT NULL,
    data_source         VARCHAR(100),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE food_items IS '食材及营养成分库';

CREATE INDEX IF NOT EXISTS idx_food_items_name     ON food_items (name);
CREATE INDEX IF NOT EXISTS idx_food_items_category ON food_items (category);
CREATE INDEX IF NOT EXISTS idx_food_items_tags     ON food_items USING GIN (tags);

-- ============================================================
-- 5. 饮食记录表 (diet_records)
-- ============================================================
CREATE TABLE IF NOT EXISTS diet_records (
    id              BIGSERIAL    PRIMARY KEY,
    user_id         BIGINT       NOT NULL REFERENCES users      (id) ON DELETE CASCADE,
    food_item_id    BIGINT       REFERENCES food_items (id) ON DELETE SET NULL,
    meal_time       TIMESTAMPTZ  NOT NULL,
    meal_type       meal_type    NOT NULL,
    food_name       VARCHAR(100) NOT NULL,
    food_desc       VARCHAR(500),
    serving_amount  NUMERIC(7,2),
    serving_unit    VARCHAR(20),
    -- 营养（按实际份量）
    calories        NUMERIC(7,2),
    protein_g       NUMERIC(7,2),
    fat_g           NUMERIC(7,2),
    carbs_g         NUMERIC(7,2),
    fiber_g         NUMERIC(7,2),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE diet_records IS '用户饮食记录';

CREATE INDEX IF NOT EXISTS idx_diet_records_user_id   ON diet_records (user_id);
CREATE INDEX IF NOT EXISTS idx_diet_records_meal_time ON diet_records (meal_time);
CREATE INDEX IF NOT EXISTS idx_diet_records_user_date ON diet_records (user_id, meal_time);

-- ============================================================
-- 6. 食谱表 (recipes)
-- ============================================================
CREATE TABLE IF NOT EXISTS recipes (
    id                    BIGSERIAL        PRIMARY KEY,
    name                  VARCHAR(150)     NOT NULL,
    description           TEXT,
    steps                 JSONB            DEFAULT NULL,
    prep_time_min         SMALLINT         CHECK (prep_time_min >= 0),
    cook_time_min         SMALLINT         CHECK (cook_time_min >= 0),
    servings              SMALLINT         NOT NULL DEFAULT 1 CHECK (servings > 0),
    difficulty            difficulty_type  NOT NULL DEFAULT 'EASY',
    -- 每份营养
    calories_per_serving  NUMERIC(7,2),
    protein_per_serving   NUMERIC(7,2),
    fat_per_serving       NUMERIC(7,2),
    carbs_per_serving     NUMERIC(7,2),
    fiber_per_serving     NUMERIC(7,2),
    sodium_per_serving    NUMERIC(7,2),
    -- 标签
    health_goal_tags      JSONB  DEFAULT NULL,
    allergen_flags        JSONB  DEFAULT NULL,
    -- 元数据
    created_by            BIGINT REFERENCES users (id) ON DELETE SET NULL,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE recipes IS '食谱库';

CREATE INDEX IF NOT EXISTS idx_recipes_difficulty        ON recipes (difficulty);
CREATE INDEX IF NOT EXISTS idx_recipes_health_goal_tags  ON recipes USING GIN (health_goal_tags);

-- ============================================================
-- 7. 食谱食材关联表 (recipe_ingredients)
-- ============================================================
CREATE TABLE IF NOT EXISTS recipe_ingredients (
    id           BIGSERIAL    PRIMARY KEY,
    recipe_id    BIGINT       NOT NULL REFERENCES recipes    (id) ON DELETE CASCADE,
    food_item_id BIGINT       NOT NULL REFERENCES food_items (id) ON DELETE CASCADE,
    amount       NUMERIC(8,2),
    unit         VARCHAR(20),
    note         VARCHAR(200),
    UNIQUE (recipe_id, food_item_id)
);

COMMENT ON TABLE recipe_ingredients IS '食谱与食材的关联（用量）';

-- ============================================================
-- 8. 健康建议表 (health_recommendations)
-- ============================================================
CREATE TABLE IF NOT EXISTS health_recommendations (
    id          BIGSERIAL        PRIMARY KEY,
    user_id     BIGINT           NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    title       VARCHAR(200)     NOT NULL,
    content     TEXT             NOT NULL,
    rec_type    rec_type         NOT NULL,
    priority    SMALLINT         NOT NULL DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    is_active   BOOLEAN          NOT NULL DEFAULT TRUE,
    source      rec_source_type  NOT NULL DEFAULT 'RULE',
    created_at  TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    expires_at  TIMESTAMPTZ
);

COMMENT ON TABLE health_recommendations IS '健康建议';

CREATE INDEX IF NOT EXISTS idx_hr_user_id   ON health_recommendations (user_id);
CREATE INDEX IF NOT EXISTS idx_hr_is_active ON health_recommendations (is_active);

-- ============================================================
-- 9. 社区帖子表 (community_posts)
-- ============================================================
CREATE TABLE IF NOT EXISTS community_posts (
    id            BIGSERIAL          PRIMARY KEY,
    user_id       BIGINT             NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    title         VARCHAR(300)       NOT NULL,
    content       TEXT               NOT NULL,
    category      post_category_type NOT NULL DEFAULT 'OTHER',
    status        moderation_status  NOT NULL DEFAULT 'APPROVED',
    like_count    INT                NOT NULL DEFAULT 0 CHECK (like_count >= 0),
    comment_count INT                NOT NULL DEFAULT 0 CHECK (comment_count >= 0),
    created_at    TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE community_posts IS '社区帖子';

CREATE INDEX IF NOT EXISTS idx_cp_user_id  ON community_posts (user_id);
CREATE INDEX IF NOT EXISTS idx_cp_category ON community_posts (category);
CREATE INDEX IF NOT EXISTS idx_cp_status   ON community_posts (status);
CREATE INDEX IF NOT EXISTS idx_cp_created  ON community_posts (created_at DESC);

-- ============================================================
-- 10. 帖子评论表 (post_comments)
-- ============================================================
CREATE TABLE IF NOT EXISTS post_comments (
    id          BIGSERIAL         PRIMARY KEY,
    post_id     BIGINT            NOT NULL REFERENCES community_posts (id) ON DELETE CASCADE,
    user_id     BIGINT            NOT NULL REFERENCES users           (id) ON DELETE CASCADE,
    parent_id   BIGINT            REFERENCES post_comments            (id) ON DELETE SET NULL,
    content     TEXT              NOT NULL,
    status      moderation_status NOT NULL DEFAULT 'APPROVED',
    created_at  TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE post_comments IS '帖子评论';

CREATE INDEX IF NOT EXISTS idx_pc_post_id   ON post_comments (post_id);
CREATE INDEX IF NOT EXISTS idx_pc_parent_id ON post_comments (parent_id);

-- ============================================================
-- 11. 帖子点赞表 (post_likes)
-- ============================================================
CREATE TABLE IF NOT EXISTS post_likes (
    post_id    BIGINT      NOT NULL REFERENCES community_posts (id) ON DELETE CASCADE,
    user_id    BIGINT      NOT NULL REFERENCES users           (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

COMMENT ON TABLE post_likes IS '帖子点赞（去重）';

-- ============================================================
-- 12. 用户收藏食谱表 (user_favorite_recipes)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_favorite_recipes (
    user_id    BIGINT      NOT NULL REFERENCES users   (id) ON DELETE CASCADE,
    recipe_id  BIGINT      NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, recipe_id)
);

COMMENT ON TABLE user_favorite_recipes IS '用户收藏的食谱';

-- ============================================================
-- 13. 食谱推荐历史表 (recipe_recommendations)
-- ============================================================
CREATE TABLE IF NOT EXISTS recipe_recommendations (
    id          BIGSERIAL          PRIMARY KEY,
    user_id     BIGINT             NOT NULL REFERENCES users   (id) ON DELETE CASCADE,
    recipe_id   BIGINT             NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    strategy    rec_strategy_type  NOT NULL DEFAULT 'RULE',
    score       NUMERIC(5,4)       CHECK (score BETWEEN 0 AND 1),
    reason      VARCHAR(500),
    feedback    feedback_type,
    created_at  TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE recipe_recommendations IS '食谱推荐历史与用户反馈';

CREATE INDEX IF NOT EXISTS idx_rr_user_id  ON recipe_recommendations (user_id);
CREATE INDEX IF NOT EXISTS idx_rr_created  ON recipe_recommendations (created_at DESC);

-- ============================================================
-- 14. AI 对话会话表 (chat_sessions)
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_sessions (
    id              BIGSERIAL    PRIMARY KEY,
    user_id         BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    title           VARCHAR(200),
    messages        JSONB        DEFAULT NULL,
    model_info      VARCHAR(100),
    tool_calls_log  JSONB        DEFAULT NULL,
    audit_flag      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE chat_sessions IS 'AI 对话会话';

CREATE INDEX IF NOT EXISTS idx_cs_user_id ON chat_sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_cs_updated ON chat_sessions (updated_at DESC);

-- ============================================================
-- 触发器：自动更新 updated_at 字段
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DO $$ DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'users', 'user_profiles', 'food_items',
        'recipes', 'community_posts', 'chat_sessions'
    ]
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS trg_%1$s_updated_at ON %1$s;
             CREATE TRIGGER trg_%1$s_updated_at
             BEFORE UPDATE ON %1$s
             FOR EACH ROW EXECUTE FUNCTION set_updated_at();',
            t
        );
    END LOOP;
END $$;

-- ============================================================
-- 视图：用户当日营养汇总 (v_daily_nutrition)
-- ============================================================
CREATE OR REPLACE VIEW v_daily_nutrition AS
SELECT
    user_id,
    meal_time::DATE                AS record_date,
    SUM(calories)                  AS total_calories,
    SUM(protein_g)                 AS total_protein_g,
    SUM(fat_g)                     AS total_fat_g,
    SUM(carbs_g)                   AS total_carbs_g,
    SUM(fiber_g)                   AS total_fiber_g,
    COUNT(*)                       AS meal_count
FROM diet_records
GROUP BY user_id, meal_time::DATE;

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
WHERE record_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY user_id;

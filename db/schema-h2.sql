-- ============================================================
-- 智能健康管理平台与饮食推荐系统 — H2 Schema（开发 / 测试）
-- H2 与 MySQL 模式兼容（MODE=MySQL）；建议在 Spring Boot
-- application-dev.yml 中配置：
--   spring.datasource.url: jdbc:h2:mem:health;MODE=MySQL;
--                          DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE
--   spring.sql.init.schema-locations: classpath:db/schema-h2.sql
-- ============================================================

-- ============================================================
-- 1. 用户表 (users)
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id              BIGINT          NOT NULL AUTO_INCREMENT,
    username        VARCHAR(50)     NOT NULL,
    email           VARCHAR(100)    NOT NULL,
    password_hash   VARCHAR(255)    NOT NULL,
    phone           VARCHAR(20)     DEFAULT NULL,
    age             TINYINT         DEFAULT NULL,
    gender          VARCHAR(10)     DEFAULT NULL,        -- MALE / FEMALE / OTHER
    height_cm       DECIMAL(5,2)    DEFAULT NULL,
    weight_kg       DECIMAL(5,2)    DEFAULT NULL,
    health_goal     VARCHAR(20)     NOT NULL DEFAULT 'MAINTAIN',
    role            VARCHAR(10)     NOT NULL DEFAULT 'USER',
    enabled         BOOLEAN         NOT NULL DEFAULT TRUE,
    email_verified  BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT uq_users_email    UNIQUE (email),
    CONSTRAINT uq_users_phone    UNIQUE (phone)
);

-- ============================================================
-- 2. 用户画像 / 偏好表 (user_profiles)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id                   BIGINT       NOT NULL AUTO_INCREMENT,
    user_id              BIGINT       NOT NULL,
    flavor_prefs         CLOB         DEFAULT NULL,   -- JSON 用 CLOB 存储
    diet_habits          CLOB         DEFAULT NULL,
    allergies            CLOB         DEFAULT NULL,
    avoidances           CLOB         DEFAULT NULL,
    target_weight_kg     DECIMAL(5,2) DEFAULT NULL,
    target_calories      INT          DEFAULT NULL,
    target_protein_g     DECIMAL(6,2) DEFAULT NULL,
    target_fat_g         DECIMAL(6,2) DEFAULT NULL,
    target_carbs_g       DECIMAL(6,2) DEFAULT NULL,
    avg_steps_7d         INT          DEFAULT NULL,
    avg_sleep_h_7d       DECIMAL(4,2) DEFAULT NULL,
    avg_calories_in_7d   INT          DEFAULT NULL,
    avg_calories_out_7d  INT          DEFAULT NULL,
    avg_heart_rate_7d    INT          DEFAULT NULL,
    updated_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uq_user_profiles_user_id UNIQUE (user_id),
    CONSTRAINT fk_user_profiles_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
);

-- ============================================================
-- 3. 健康数据表 (health_data)
-- ============================================================
CREATE TABLE IF NOT EXISTS health_data (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    user_id         BIGINT       NOT NULL,
    record_date     DATE         NOT NULL,
    steps           INT          DEFAULT NULL,
    calories_burned INT          DEFAULT NULL,
    heart_rate      SMALLINT     DEFAULT NULL,
    systolic_bp     SMALLINT     DEFAULT NULL,
    diastolic_bp    SMALLINT     DEFAULT NULL,
    sleep_hours     DECIMAL(4,2) DEFAULT NULL,
    water_ml        INT          DEFAULT NULL,
    data_source     VARCHAR(10)  NOT NULL DEFAULT 'MANUAL',   -- MANUAL / DEVICE / IMPORT
    raw_data        CLOB         DEFAULT NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uq_health_data_user_date UNIQUE (user_id, record_date),
    CONSTRAINT fk_health_data_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
);

-- ============================================================
-- 4. 食材 / 营养成分表 (food_items)
-- ============================================================
CREATE TABLE IF NOT EXISTS food_items (
    id                  BIGINT       NOT NULL AUTO_INCREMENT,
    name                VARCHAR(100) NOT NULL,
    alias               VARCHAR(200) DEFAULT NULL,
    category            VARCHAR(50)  DEFAULT NULL,
    tags                CLOB         DEFAULT NULL,
    calories_per100g    DECIMAL(7,2) DEFAULT NULL,
    protein_per100g     DECIMAL(7,2) DEFAULT NULL,
    fat_per100g         DECIMAL(7,2) DEFAULT NULL,
    carbs_per100g       DECIMAL(7,2) DEFAULT NULL,
    fiber_per100g       DECIMAL(7,2) DEFAULT NULL,
    sodium_per100g      DECIMAL(7,2) DEFAULT NULL,
    potassium_per100g   DECIMAL(7,2) DEFAULT NULL,
    magnesium_per100g   DECIMAL(7,2) DEFAULT NULL,
    allergen_flags      CLOB         DEFAULT NULL,
    data_source         VARCHAR(100) DEFAULT NULL,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);

-- ============================================================
-- 5. 饮食记录表 (diet_records)
-- ============================================================
CREATE TABLE IF NOT EXISTS diet_records (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    user_id         BIGINT       NOT NULL,
    food_item_id    BIGINT       DEFAULT NULL,
    meal_time       TIMESTAMP    NOT NULL,
    meal_type       VARCHAR(10)  NOT NULL,   -- BREAKFAST / LUNCH / DINNER / SNACK
    food_name       VARCHAR(100) NOT NULL,
    food_desc       VARCHAR(500) DEFAULT NULL,
    serving_amount  DECIMAL(7,2) DEFAULT NULL,
    serving_unit    VARCHAR(20)  DEFAULT NULL,
    calories        DECIMAL(7,2) DEFAULT NULL,
    protein_g       DECIMAL(7,2) DEFAULT NULL,
    fat_g           DECIMAL(7,2) DEFAULT NULL,
    carbs_g         DECIMAL(7,2) DEFAULT NULL,
    fiber_g         DECIMAL(7,2) DEFAULT NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_diet_records_user      FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_diet_records_food_item FOREIGN KEY (food_item_id)
        REFERENCES food_items (id) ON DELETE SET NULL
);

-- ============================================================
-- 6. 食谱表 (recipes)
-- ============================================================
CREATE TABLE IF NOT EXISTS recipes (
    id                    BIGINT       NOT NULL AUTO_INCREMENT,
    name                  VARCHAR(150) NOT NULL,
    description           CLOB         DEFAULT NULL,
    steps                 CLOB         DEFAULT NULL,
    prep_time_min         SMALLINT     DEFAULT NULL,
    cook_time_min         SMALLINT     DEFAULT NULL,
    servings              TINYINT      NOT NULL DEFAULT 1,
    difficulty            VARCHAR(10)  NOT NULL DEFAULT 'EASY',  -- EASY / MEDIUM / HARD
    calories_per_serving  DECIMAL(7,2) DEFAULT NULL,
    protein_per_serving   DECIMAL(7,2) DEFAULT NULL,
    fat_per_serving       DECIMAL(7,2) DEFAULT NULL,
    carbs_per_serving     DECIMAL(7,2) DEFAULT NULL,
    fiber_per_serving     DECIMAL(7,2) DEFAULT NULL,
    sodium_per_serving    DECIMAL(7,2) DEFAULT NULL,
    health_goal_tags      CLOB         DEFAULT NULL,
    allergen_flags        CLOB         DEFAULT NULL,
    created_by            BIGINT       DEFAULT NULL,
    created_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_recipes_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE SET NULL
);

-- ============================================================
-- 7. 食谱食材关联表 (recipe_ingredients)
-- ============================================================
CREATE TABLE IF NOT EXISTS recipe_ingredients (
    id           BIGINT       NOT NULL AUTO_INCREMENT,
    recipe_id    BIGINT       NOT NULL,
    food_item_id BIGINT       NOT NULL,
    amount       DECIMAL(8,2) DEFAULT NULL,
    unit         VARCHAR(20)  DEFAULT NULL,
    note         VARCHAR(200) DEFAULT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_recipe_ingredient UNIQUE (recipe_id, food_item_id),
    CONSTRAINT fk_ri_recipe    FOREIGN KEY (recipe_id)    REFERENCES recipes    (id) ON DELETE CASCADE,
    CONSTRAINT fk_ri_food_item FOREIGN KEY (food_item_id) REFERENCES food_items (id) ON DELETE CASCADE
);

-- ============================================================
-- 8. 健康建议表 (health_recommendations)
-- ============================================================
CREATE TABLE IF NOT EXISTS health_recommendations (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    user_id     BIGINT       NOT NULL,
    title       VARCHAR(200) NOT NULL,
    content     CLOB         NOT NULL,
    rec_type    VARCHAR(12)  NOT NULL,    -- EXERCISE / DIET / SLEEP / HYDRATION / MEDICAL
    priority    TINYINT      NOT NULL DEFAULT 5,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    source      VARCHAR(5)   NOT NULL DEFAULT 'RULE',   -- RULE / AI
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at  TIMESTAMP    DEFAULT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_hr_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
);

-- ============================================================
-- 9. 社区帖子表 (community_posts)
-- ============================================================
CREATE TABLE IF NOT EXISTS community_posts (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    user_id       BIGINT       NOT NULL,
    title         VARCHAR(300) NOT NULL,
    content       CLOB         NOT NULL,
    category      VARCHAR(20)  NOT NULL DEFAULT 'OTHER',
    status        VARCHAR(10)  NOT NULL DEFAULT 'APPROVED',
    like_count    INT          NOT NULL DEFAULT 0,
    comment_count INT          NOT NULL DEFAULT 0,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_cp_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
);

-- ============================================================
-- 10. 帖子评论表 (post_comments)
-- ============================================================
CREATE TABLE IF NOT EXISTS post_comments (
    id          BIGINT      NOT NULL AUTO_INCREMENT,
    post_id     BIGINT      NOT NULL,
    user_id     BIGINT      NOT NULL,
    parent_id   BIGINT      DEFAULT NULL,
    content     CLOB        NOT NULL,
    status      VARCHAR(10) NOT NULL DEFAULT 'APPROVED',
    created_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_pc_post   FOREIGN KEY (post_id)   REFERENCES community_posts (id) ON DELETE CASCADE,
    CONSTRAINT fk_pc_user   FOREIGN KEY (user_id)   REFERENCES users           (id) ON DELETE CASCADE,
    CONSTRAINT fk_pc_parent FOREIGN KEY (parent_id) REFERENCES post_comments   (id) ON DELETE SET NULL
);

-- ============================================================
-- 11. 帖子点赞表 (post_likes)
-- ============================================================
CREATE TABLE IF NOT EXISTS post_likes (
    post_id    BIGINT    NOT NULL,
    user_id    BIGINT    NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (post_id, user_id),
    CONSTRAINT fk_pl_post FOREIGN KEY (post_id) REFERENCES community_posts (id) ON DELETE CASCADE,
    CONSTRAINT fk_pl_user FOREIGN KEY (user_id) REFERENCES users           (id) ON DELETE CASCADE
);

-- ============================================================
-- 12. 用户收藏食谱表 (user_favorite_recipes)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_favorite_recipes (
    user_id    BIGINT    NOT NULL,
    recipe_id  BIGINT    NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, recipe_id),
    CONSTRAINT fk_ufr_user   FOREIGN KEY (user_id)   REFERENCES users   (id) ON DELETE CASCADE,
    CONSTRAINT fk_ufr_recipe FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
);

-- ============================================================
-- 13. 食谱推荐历史表 (recipe_recommendations)
-- ============================================================
CREATE TABLE IF NOT EXISTS recipe_recommendations (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    user_id     BIGINT       NOT NULL,
    recipe_id   BIGINT       NOT NULL,
    strategy    VARCHAR(15)  NOT NULL DEFAULT 'RULE',
    score       DECIMAL(5,4) DEFAULT NULL,
    reason      VARCHAR(500) DEFAULT NULL,
    feedback    VARCHAR(10)  DEFAULT NULL,   -- ADOPTED / IGNORED / DISLIKED
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_rr_user   FOREIGN KEY (user_id)   REFERENCES users   (id) ON DELETE CASCADE,
    CONSTRAINT fk_rr_recipe FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
);

-- ============================================================
-- 14. AI 对话会话表 (chat_sessions)
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_sessions (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    user_id         BIGINT       NOT NULL,
    title           VARCHAR(200) DEFAULT NULL,
    messages        CLOB         DEFAULT NULL,
    model_info      VARCHAR(100) DEFAULT NULL,
    tool_calls_log  CLOB         DEFAULT NULL,
    audit_flag      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_cs_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
);

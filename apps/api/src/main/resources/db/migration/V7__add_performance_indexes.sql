-- V7: 添加缺失的性能优化索引
-- 针对高频查询场景优化

-- 评论状态索引（管理后台按状态筛选）
CREATE INDEX IF NOT EXISTS idx_comments_status ON comments(status);

-- 评论用户索引（用户活动查询）
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id);

-- 点赞内容索引（内容详情点赞检查）
CREATE INDEX IF NOT EXISTS idx_likes_content_id ON likes(content_id);

-- 浏览记录内容索引（内容详情浏览去重检查）
CREATE INDEX IF NOT EXISTS idx_views_content_id ON view_records(content_id);

-- AI 会话用户索引（用户会话查询）
CREATE INDEX IF NOT EXISTS idx_ai_sessions_user_id ON ai_chat_sessions(user_id);

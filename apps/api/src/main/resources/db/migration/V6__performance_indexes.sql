-- 性能索引补充
-- media_assets.content_id 缺索引导致列表页全表扫描
CREATE INDEX idx_media_assets_content_id_created ON media_assets(content_id, created_at ASC);

-- users.created_at 管理端排序
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- content_tags 反向索引（按标签查内容）
CREATE INDEX idx_content_tags_tag_id ON content_tags(tag_id);

-- 全文搜索 trigram 索引（加速 LIKE '%keyword%' 查询）
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_contents_title_trgm ON contents USING gin (title gin_trgm_ops);
CREATE INDEX idx_contents_body_trgm ON contents USING gin (body_markdown gin_trgm_ops);

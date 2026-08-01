-- 将 slug 唯一约束改为部分唯一索引，仅约束未删除的行，
-- 使软删除后的 slug 可以被新内容复用。
ALTER TABLE contents DROP CONSTRAINT IF EXISTS contents_slug_key;
CREATE UNIQUE INDEX uq_contents_slug_active ON contents(slug) WHERE deleted_at IS NULL;

-- 为 refresh_tokens 添加 family_id 列，支持令牌族撤销（replay attack 检测）。
ALTER TABLE refresh_tokens ADD COLUMN family_id UUID;
CREATE INDEX idx_refresh_tokens_family_id ON refresh_tokens(family_id) WHERE family_id IS NOT NULL;

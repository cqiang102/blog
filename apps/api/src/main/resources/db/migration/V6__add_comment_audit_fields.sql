-- 添加评论 AI 审查字段
ALTER TABLE comments ADD COLUMN audit_status VARCHAR(20);
ALTER TABLE comments ADD COLUMN audit_reason TEXT;

-- 更新 status 约束，新增 PENDING 和 BLOCKED 状态
ALTER TABLE comments DROP CONSTRAINT IF EXISTS comments_status_check;
ALTER TABLE comments ADD CONSTRAINT comments_status_check
    CHECK (status IN ('VISIBLE', 'PENDING', 'BLOCKED', 'DELETED'));

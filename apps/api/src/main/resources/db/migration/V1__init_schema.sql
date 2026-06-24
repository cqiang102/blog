CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email CITEXT UNIQUE NOT NULL,
    password_hash TEXT,
    nickname VARCHAR(80) NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    blog_url TEXT,
    role VARCHAR(20) NOT NULL DEFAULT 'USER' CHECK (role IN ('USER', 'ADMIN')),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'DISABLED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE oauth_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(20) NOT NULL CHECK (provider IN ('GITHUB', 'QQ')),
    provider_user_id VARCHAR(120) NOT NULL,
    provider_username VARCHAR(120),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (provider, provider_user_id)
);
CREATE UNIQUE INDEX ux_oauth_accounts_user_provider ON oauth_accounts(user_id, provider);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE verification_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    code VARCHAR(10) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_verification_codes_email ON verification_codes(email, created_at DESC);

CREATE TABLE contents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(180) NOT NULL,
    slug VARCHAR(220) UNIQUE NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('ARTICLE', 'IMAGE', 'VIDEO')),
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
    summary TEXT,
    body_markdown TEXT,
    cover_media_id UUID,
    pinned BOOLEAN NOT NULL DEFAULT false,
    like_count BIGINT NOT NULL DEFAULT 0,
    view_count BIGINT NOT NULL DEFAULT 0,
    comment_count BIGINT NOT NULL DEFAULT 0,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_contents_status_published_at ON contents(status, published_at DESC);
CREATE INDEX idx_contents_pinned ON contents(pinned) WHERE pinned = true;
CREATE INDEX idx_contents_type ON contents(type);
CREATE INDEX idx_contents_deleted_at ON contents(deleted_at) WHERE deleted_at IS NOT NULL;

CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(60) UNIQUE NOT NULL,
    slug VARCHAR(80) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE content_tags (
    content_id UUID NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (content_id, tag_id)
);

CREATE TABLE media_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID REFERENCES contents(id) ON DELETE SET NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('IMAGE', 'VIDEO', 'FILE')),
    bucket VARCHAR(120) NOT NULL,
    object_key TEXT NOT NULL,
    public_url TEXT,
    filename VARCHAR(240),
    content_type VARCHAR(120),
    byte_size BIGINT,
    width INT,
    height INT,
    duration_seconds INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE contents
    ADD CONSTRAINT fk_contents_cover_media
    FOREIGN KEY (cover_media_id) REFERENCES media_assets(id) ON DELETE SET NULL;

CREATE TABLE comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'VISIBLE' CHECK (status IN ('VISIBLE', 'PENDING', 'BLOCKED', 'DELETED')),
    audit_status VARCHAR(20),
    audit_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_comments_content_created ON comments(content_id, created_at DESC);
CREATE INDEX idx_comments_status ON comments(status);
CREATE INDEX idx_comments_user_id ON comments(user_id);

CREATE TABLE likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (content_id, user_id)
);
CREATE INDEX idx_likes_content_id ON likes(content_id);
CREATE INDEX idx_likes_user_created ON likes(user_id, created_at DESC);

CREATE TABLE view_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL REFERENCES contents(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    anonymous_id VARCHAR(120),
    ip_hash VARCHAR(160),
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_views_content_id ON view_records(content_id);
CREATE INDEX idx_views_user_created ON view_records(user_id, created_at DESC);
CREATE UNIQUE INDEX ux_view_records_content_user
    ON view_records(content_id, user_id)
    WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX ux_view_records_content_anonymous
    ON view_records(content_id, anonymous_id)
    WHERE user_id IS NULL AND anonymous_id IS NOT NULL;

CREATE TABLE friends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(80) NOT NULL,
    avatar_url TEXT,
    intro TEXT,
    site_url TEXT NOT NULL,
    visible BOOLEAN NOT NULL DEFAULT true,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ai_chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(160),
    deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ai_sessions_user_id ON ai_chat_sessions(user_id);
CREATE INDEX idx_ai_sessions_user_deleted ON ai_chat_sessions(user_id, deleted) WHERE deleted = false;

CREATE TABLE ai_chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES ai_chat_sessions(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('USER', 'ASSISTANT', 'TOOL', 'SYSTEM')),
    content TEXT NOT NULL,
    tool_name VARCHAR(120),
    tool_payload JSONB,
    prompt_tokens INT,
    completion_tokens INT,
    deleted BOOLEAN NOT NULL DEFAULT false,
    audit_status VARCHAR(20),
    audit_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ai_messages_session_created ON ai_chat_messages(session_id, created_at);
CREATE INDEX idx_ai_messages_session_deleted ON ai_chat_messages(session_id, deleted) WHERE deleted = false;

CREATE TABLE ai_daily_quotas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    quota_date DATE NOT NULL,
    question_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, quota_date)
);

CREATE TABLE knowledge_docs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(180) NOT NULL,
    source_type VARCHAR(40) NOT NULL DEFAULT 'MANUAL',
    source_ref TEXT,
    body TEXT,
    enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE knowledge_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    doc_id UUID REFERENCES knowledge_docs(id) ON DELETE CASCADE,
    content_id UUID REFERENCES contents(id) ON DELETE CASCADE,
    chunk_index INT NOT NULL,
    content TEXT NOT NULL,
    embedding VECTOR(768),
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (doc_id, chunk_index),
    CONSTRAINT knowledge_chunks_exactly_one_source CHECK ((doc_id IS NOT NULL) <> (content_id IS NOT NULL))
);
CREATE INDEX idx_knowledge_chunks_content_id ON knowledge_chunks(content_id);
CREATE INDEX idx_knowledge_chunks_embedding ON knowledge_chunks USING hnsw (embedding vector_cosine_ops);

CREATE TABLE spring_ai_chat_memory (
    conversation_id VARCHAR(256) NOT NULL,
    content TEXT NOT NULL,
    type VARCHAR(64) NOT NULL,
    "timestamp" TIMESTAMPTZ NOT NULL DEFAULT now(),
    sequence_id BIGSERIAL NOT NULL,
    PRIMARY KEY (conversation_id, sequence_id)
);
CREATE INDEX idx_chat_memory_conversation_id ON spring_ai_chat_memory(conversation_id);
CREATE INDEX spring_ai_chat_memory_conversation_id_timestamp_idx
    ON spring_ai_chat_memory(conversation_id, "timestamp");

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(120) NOT NULL,
    resource_type VARCHAR(80),
    resource_id UUID,
    detail JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);

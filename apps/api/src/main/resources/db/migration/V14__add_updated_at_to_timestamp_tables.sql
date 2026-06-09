-- V14: Add updated_at column to tables that only had created_at
-- These tables are now managed by AggregateRoot which requires both timestamps

ALTER TABLE oauth_accounts ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE refresh_tokens ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE media_assets ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE likes ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE view_records ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE ai_chat_messages ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE knowledge_chunks ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE audit_logs ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

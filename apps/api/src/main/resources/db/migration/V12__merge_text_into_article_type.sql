-- 将 contents 表中 type 为 TEXT 的记录更新为 ARTICLE
-- TEXT 和 ARTICLE 在逻辑上等价，统一使用 ARTICLE
UPDATE contents SET type = 'ARTICLE' WHERE type = 'TEXT';

WITH ranked_accounts AS (
    SELECT
        id,
        row_number() OVER (
            PARTITION BY user_id, provider
            ORDER BY created_at, id
        ) AS row_num
    FROM oauth_accounts
)
DELETE FROM oauth_accounts
WHERE id IN (
    SELECT id
    FROM ranked_accounts
    WHERE row_num > 1
);

CREATE UNIQUE INDEX ux_oauth_accounts_user_provider
    ON oauth_accounts (user_id, provider);

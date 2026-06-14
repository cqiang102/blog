WITH ranked_user_views AS (
    SELECT
        id,
        row_number() OVER (
            PARTITION BY content_id, user_id
            ORDER BY created_at, id
        ) AS row_num
    FROM view_records
    WHERE user_id IS NOT NULL
)
DELETE FROM view_records
WHERE id IN (
    SELECT id
    FROM ranked_user_views
    WHERE row_num > 1
);

WITH ranked_anonymous_views AS (
    SELECT
        id,
        row_number() OVER (
            PARTITION BY content_id, anonymous_id
            ORDER BY created_at, id
        ) AS row_num
    FROM view_records
    WHERE user_id IS NULL
      AND anonymous_id IS NOT NULL
)
DELETE FROM view_records
WHERE id IN (
    SELECT id
    FROM ranked_anonymous_views
    WHERE row_num > 1
);

CREATE UNIQUE INDEX ux_view_records_content_user
    ON view_records (content_id, user_id)
    WHERE user_id IS NOT NULL;

CREATE UNIQUE INDEX ux_view_records_content_anonymous
    ON view_records (content_id, anonymous_id)
    WHERE user_id IS NULL
      AND anonymous_id IS NOT NULL;

UPDATE contents AS content
SET like_count = (
        SELECT count(*)
        FROM likes
        WHERE likes.content_id = content.id
    ),
    view_count = (
        SELECT count(*)
        FROM view_records
        WHERE view_records.content_id = content.id
    ),
    comment_count = (
        SELECT count(*)
        FROM comments
        WHERE comments.content_id = content.id
          AND comments.status = 'VISIBLE'
    );

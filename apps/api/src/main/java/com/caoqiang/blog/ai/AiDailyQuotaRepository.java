package com.caoqiang.blog.ai;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 每日 AI 配额 Repository。
 * <p>
 * 提供配额实体的 CRUD 操作，支持按用户 ID 和日期查询配额记录。
 */
public interface AiDailyQuotaRepository extends JpaRepository<AiDailyQuota, UUID> {

    /**
     * 根据用户 ID 和配额日期查找配额记录。
     *
     * @param userId    用户 ID
     * @param quotaDate 配额日期
     * @return 匹配的配额记录
     */
    Optional<AiDailyQuota> findByUserIdAndQuotaDate(UUID userId, LocalDate quotaDate);
}

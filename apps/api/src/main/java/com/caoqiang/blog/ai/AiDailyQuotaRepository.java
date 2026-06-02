package com.caoqiang.blog.ai;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AiDailyQuotaRepository extends JpaRepository<AiDailyQuota, UUID> {

    Optional<AiDailyQuota> findByUserIdAndQuotaDate(UUID userId, LocalDate quotaDate);
}

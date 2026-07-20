package com.caoqiang.blog.auth.domain.repository;

import com.caoqiang.blog.auth.domain.model.VerificationCode;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 邮箱验证码数据访问层
 * 提供对 verification_codes 表的 CRUD 操作及自定义查询方法。
 * 位于博客系统的认证模块，是验证码持久化的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>继承 Spring Data JPA - 自动实现基本的 CRUD 操作</li>
 *   <li>自定义查询 - 支持按邮箱和使用状态查询验证码</li>
 *   <li>排序查询 - 支持按创建时间排序，获取最新的验证码</li>
 * </ul>
 *
 * @author blog-mimo
 */
public interface VerificationCodeRepository extends JpaRepository<VerificationCode, UUID> {

    /**
     * 查询指定邮箱最新的未使用验证码
     *
     * @param email 邮箱地址
     * @param used  使用状态（通常为 false）
     * @return 包含验证码的 Optional，如果不存在则为空
     */
    Optional<VerificationCode> findFirstByEmailAndUsedOrderByCreatedAtDesc(String email, boolean used);

    /**
     * 查询指定邮箱最新的验证码（包括已使用的）
     *
     * @param email 邮箱地址
     * @return 包含验证码的 Optional，如果不存在则为空
     */
    Optional<VerificationCode> findFirstByEmailOrderByCreatedAtDesc(String email);
}

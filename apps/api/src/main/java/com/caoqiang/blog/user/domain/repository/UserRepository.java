package com.caoqiang.blog.user.domain.repository;

import com.caoqiang.blog.user.domain.model.User;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 用户数据访问层
 * <p>
 * 继承 {@link JpaRepository} 提供基本 CRUD 操作，
 * 继承 {@link JpaSpecificationExecutor} 支持动态查询条件。
 * <p>
 * 提供基于邮箱的查询方法，用于用户认证和邮箱唯一性校验。
 */
public interface UserRepository extends JpaRepository<User, UUID>, JpaSpecificationExecutor<User> {

    /**
     * 根据邮箱查找用户
     *
     * @param email 用户邮箱
     * @return 用户 Optional，可能为空
     */
    Optional<User> findByEmail(String email);

    /**
     * 检查邮箱是否已存在
     *
     * @param email 用户邮箱
     * @return 如果邮箱已存在返回 true
     */
    boolean existsByEmail(String email);

    /**
     * 检查邮箱是否已被其他用户使用（排除指定 ID）
     * <p>
     * 用于用户更新邮箱时的唯一性校验。
     *
     * @param email 用户邮箱
     * @param id    排除的用户 ID
     * @return 如果邮箱已被其他用户使用返回 true
     */
    boolean existsByEmailAndIdNot(String email, UUID id);

    @Query("""
            select u.id from User u
            where lower(u.email) like lower(concat('%', :query, '%'))
               or lower(u.nickname) like lower(concat('%', :query, '%'))
            """)
    List<UUID> findIdsMatchingIdentity(@Param("query") String query);
}

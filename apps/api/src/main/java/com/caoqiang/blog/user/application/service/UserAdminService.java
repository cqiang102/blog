package com.caoqiang.blog.user.application.service;

import com.caoqiang.blog.user.application.dto.AdminUserRequest;
import com.caoqiang.blog.user.application.dto.AdminUserResponse;
import com.caoqiang.blog.user.application.dto.ChangePasswordRequest;
import com.caoqiang.blog.user.application.dto.OAuthAccountResponse;
import com.caoqiang.blog.user.application.dto.SetPasswordRequest;
import com.caoqiang.blog.user.application.dto.UpdateProfileRequest;
import com.caoqiang.blog.user.application.dto.UserProfileResponse;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.model.UserStatus;
import com.caoqiang.blog.user.domain.repository.UserRepository;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.util.EmailNormalizer;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 管理端用户服务
 * <p>
 * 提供管理员对用户的 CRUD 操作，包括：
 * <ul>
 *   <li>用户列表查询（支持按关键词、角色、状态筛选）</li>
 *   <li>用户详情查看</li>
 *   <li>用户信息更新（角色、状态等）</li>
 *   <li>用户禁用操作</li>
 * </ul>
 * <p>
 * 包含安全防护：管理员不能禁用自己或移除自己的管理员权限。
 */
@Service
public class UserAdminService {

    /** 最大分页大小限制 */
    private static final int MAX_PAGE_SIZE = 100;

    /** 用户数据访问层 */
    private final UserRepository userRepository;
    /** 个人资料服务，用于生成预签名头像 URL */
    private final ProfileService profileService;

    public UserAdminService(UserRepository userRepository, ProfileService profileService) {
        this.userRepository = userRepository;
        this.profileService = profileService;
    }

    /**
     * 获取用户列表（分页、筛选）
     *
     * @param page   页码，从 0 开始
     * @param size   每页大小，最大 100
     * @param query  搜索关键词（匹配邮箱或昵称）
     * @param role   角色筛选条件
     * @param status 状态筛选条件
     * @return 用户列表分页响应
     */
    @Transactional(readOnly = true)
    public PageResponse<AdminUserResponse> list(int page, int size, String query, Role role, UserStatus status) {
        Page<User> result = userRepository.findAll(
                filters(query, role, status),
                pageRequest(page, size)
        );
        return new PageResponse<>(
                result.getContent().stream()
                        .map(u -> AdminUserResponse.from(u, profileService.generatePresignedAvatarUrl(u.getAvatarUrl())))
                        .toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    /**
     * 获取用户详情
     *
     * @param id 用户 ID
     * @return 用户详情响应 DTO
     * @throws BusinessException 如果用户不存在
     */
    @Transactional(readOnly = true)
    public AdminUserResponse detail(UUID id) {
        User user = findUser(id);
        return AdminUserResponse.from(user, profileService.generatePresignedAvatarUrl(user.getAvatarUrl()));
    }

    /**
     * 更新用户信息（管理员操作）
     * <p>
     * 更新用户的邮箱、昵称、头像、简介、博客 URL、角色和状态。
     * 邮箱变更时检查唯一性。
     *
     * @param currentUser 当前操作管理员
     * @param id          目标用户 ID
     * @param request     更新请求体
     * @return 更新后的用户详情响应 DTO
     * @throws BusinessException 如果邮箱已被使用或尝试修改自身权限
     */
    @Transactional
    public AdminUserResponse update(AuthenticatedUser currentUser, UUID id, AdminUserRequest request) {
        User user = findUser(id);
        Role role = request.role();
        UserStatus status = request.status();
        // 防止管理员修改自己的权限或状态
        guardSelfAccess(currentUser, user, role, status);

        // 规范化邮箱并检查唯一性
        String email = EmailNormalizer.normalize(request.email());
        if (userRepository.existsByEmailAndIdNot(email, id)) {
            throw new BusinessException(HttpStatus.CONFLICT, "邮箱已被使用");
        }

        // 应用管理员更新
        user.applyAdminUpdate(
                email,
                request.nickname().trim(),
                clean(request.avatarUrl()),
                clean(request.bio()),
                clean(request.blogUrl()),
                role,
                status
        );
        return AdminUserResponse.from(user, profileService.generatePresignedAvatarUrl(user.getAvatarUrl()));
    }

    /**
     * 禁用用户（管理员操作）
     * <p>
     * 将用户状态设置为 DISABLED，用户将无法登录。
     *
     * @param currentUser 当前操作管理员
     * @param id          目标用户 ID
     * @throws BusinessException 如果尝试禁用自己
     */
    @Transactional
    public void disable(AuthenticatedUser currentUser, UUID id) {
        User user = findUser(id);
        // 防止管理员禁用自己
        guardSelfAccess(currentUser, user, user.getRole(), UserStatus.DISABLED);
        user.applyAdminUpdate(
                user.getEmail(),
                user.getNickname(),
                user.getAvatarUrl(),
                user.getBio(),
                user.getBlogUrl(),
                user.getRole(),
                UserStatus.DISABLED
        );
    }

    /**
     * 根据 ID 查找用户
     *
     * @param id 用户 ID
     * @return 用户实体
     * @throws BusinessException 如果用户不存在
     */
    private User findUser(UUID id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "用户不存在"));
    }

    /**
     * 安全防护：防止管理员修改自己的角色或状态
     * <p>
     * 如果目标用户是当前用户，则必须保持 ADMIN 角色和 ACTIVE 状态。
     *
     * @param currentUser 当前操作管理员
     * @param targetUser  目标用户
     * @param role        请求中的角色
     * @param status      请求中的状态
     * @throws BusinessException 如果尝试修改自身权限或状态
     */
    private void guardSelfAccess(AuthenticatedUser currentUser, User targetUser, Role role, UserStatus status) {
        // 如果不是修改自己，直接放行
        if (!targetUser.getId().equals(currentUser.id())) {
            return;
        }
        // 修改自己时，必须保持 ADMIN 角色和 ACTIVE 状态
        if (role != Role.ADMIN || status != UserStatus.ACTIVE) {
            throw new BusinessException(HttpStatus.FORBIDDEN, "不能禁用自己或移除自己的管理员权限");
        }
    }

    /**
     * 构建用户查询条件
     * <p>
     * 支持按关键词（邮箱或昵称）、角色、状态进行筛选。
     *
     * @param query  搜索关键词
     * @param role   角色筛选条件
     * @param status 状态筛选条件
     * @return JPA Specification 查询条件
     */
    private Specification<User> filters(String query, Role role, UserStatus status) {
        return (root, ignored, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            // 关键词搜索：匹配邮箱或昵称
            if (StringUtils.hasText(query)) {
                String pattern = "%" + query.trim().toLowerCase() + "%";
                predicates.add(criteriaBuilder.or(
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("email")), pattern),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("nickname")), pattern)
                ));
            }
            // 角色筛选
            if (role != null) {
                predicates.add(criteriaBuilder.equal(root.get("role"), role));
            }
            // 状态筛选
            if (status != null) {
                predicates.add(criteriaBuilder.equal(root.get("status"), status));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }

    /**
     * 构建分页请求
     * <p>
     * 页码最小为 0，每页大小在 1 到 100 之间，按创建时间降序排序。
     *
     * @param page 页码
     * @param size 每页大小
     * @return JPA PageRequest
     */
    private PageRequest pageRequest(int page, int size) {
        return PageRequest.of(
                Math.max(0, page),
                Math.max(1, Math.min(size, MAX_PAGE_SIZE)),
                Sort.by(Sort.Direction.DESC, "createdAt")
        );
    }

    /**
     * 清理字符串值
     * <p>
     * 如果字符串有内容则 trim 后返回，否则返回 null。
     *
     * @param value 原始字符串
     * @return 清理后的字符串或 null
     */
    private String clean(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }
}

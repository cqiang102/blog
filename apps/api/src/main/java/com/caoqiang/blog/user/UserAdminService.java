package com.caoqiang.blog.user;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.auth.EmailNormalizer;
import com.caoqiang.blog.auth.Role;
import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.common.PageResponse;
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

@Service
public class UserAdminService {

    private static final int MAX_PAGE_SIZE = 100;

    private final UserRepository userRepository;

    public UserAdminService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminUserResponse> list(int page, int size, String query, Role role, UserStatus status) {
        Page<User> result = userRepository.findAll(
                filters(query, role, status),
                pageRequest(page, size)
        );
        return new PageResponse<>(
                result.getContent().stream().map(AdminUserResponse::from).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    @Transactional(readOnly = true)
    public AdminUserResponse detail(UUID id) {
        return AdminUserResponse.from(findUser(id));
    }

    @Transactional
    public AdminUserResponse update(AuthenticatedUser currentUser, UUID id, AdminUserRequest request) {
        User user = findUser(id);
        Role role = request.role();
        UserStatus status = request.status();
        guardSelfAccess(currentUser, user, role, status);

        String email = EmailNormalizer.normalize(request.email());
        if (userRepository.existsByEmailAndIdNot(email, id)) {
            throw new BusinessException(HttpStatus.CONFLICT, "邮箱已被使用");
        }

        user.applyAdminUpdate(
                email,
                request.nickname().trim(),
                clean(request.avatarUrl()),
                clean(request.bio()),
                clean(request.blogUrl()),
                role,
                status
        );
        return AdminUserResponse.from(user);
    }

    @Transactional
    public void disable(AuthenticatedUser currentUser, UUID id) {
        User user = findUser(id);
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

    private User findUser(UUID id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "用户不存在"));
    }

    private void guardSelfAccess(AuthenticatedUser currentUser, User targetUser, Role role, UserStatus status) {
        if (!targetUser.getId().equals(currentUser.id())) {
            return;
        }
        if (role != Role.ADMIN || status != UserStatus.ACTIVE) {
            throw new BusinessException(HttpStatus.FORBIDDEN, "不能禁用自己或移除自己的管理员权限");
        }
    }

    private Specification<User> filters(String query, Role role, UserStatus status) {
        return (root, ignored, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (StringUtils.hasText(query)) {
                String pattern = "%" + query.trim().toLowerCase() + "%";
                predicates.add(criteriaBuilder.or(
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("email")), pattern),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("nickname")), pattern)
                ));
            }
            if (role != null) {
                predicates.add(criteriaBuilder.equal(root.get("role"), role));
            }
            if (status != null) {
                predicates.add(criteriaBuilder.equal(root.get("status"), status));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }

    private PageRequest pageRequest(int page, int size) {
        return PageRequest.of(
                Math.max(0, page),
                Math.max(1, Math.min(size, MAX_PAGE_SIZE)),
                Sort.by(Sort.Direction.DESC, "createdAt")
        );
    }

    private String clean(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }
}

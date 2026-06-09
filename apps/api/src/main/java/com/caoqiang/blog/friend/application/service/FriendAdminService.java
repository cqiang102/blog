package com.caoqiang.blog.friend.application.service;

import com.caoqiang.blog.friend.domain.model.Friend;
import com.caoqiang.blog.friend.domain.repository.FriendRepository;
import com.caoqiang.blog.friend.application.dto.FriendRequest;
import com.caoqiang.blog.friend.application.dto.FriendResponse;

import com.caoqiang.blog.shared.exception.BusinessException;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 管理端友链服务
 * <p>
 * 提供管理员对友链的 CRUD 操作，包括：
 * <ul>
 *   <li>友链列表查询（按排序权重和创建时间排序）</li>
 *   <li>创建新友链</li>
 *   <li>更新友链信息</li>
 *   <li>删除友链</li>
 * </ul>
 * <p>
 * 所有写操作均使用事务管理，确保数据一致性。
 */
@Service
public class FriendAdminService {

    /** 友链数据访问层 */
    private final FriendRepository friendRepository;

    public FriendAdminService(FriendRepository friendRepository) {
        this.friendRepository = friendRepository;
    }

    /**
     * 获取所有友链列表
     * <p>
     * 按排序权重升序、创建时间降序排列。
     *
     * @return 友链响应列表
     */
    @Transactional(readOnly = true)
    public List<FriendResponse> list() {
        return friendRepository.findAllByOrderBySortOrderAscCreatedAtDesc()
                .stream()
                .map(FriendResponse::from)
                .toList();
    }

    /**
     * 创建新友链
     *
     * @param request 友链请求体
     * @return 创建后的友链响应 DTO
     */
    @Transactional
    public FriendResponse create(FriendRequest request) {
        Friend friend = new Friend(
                request.name().trim(),
                clean(request.avatarUrl()),
                clean(request.intro()),
                request.siteUrl().trim(),
                request.visible(),
                request.sortOrder()
        );
        return FriendResponse.from(friendRepository.save(friend));
    }

    /**
     * 更新友链信息
     *
     * @param id      友链 ID
     * @param request 友链请求体
     * @return 更新后的友链响应 DTO
     * @throws BusinessException 如果友链不存在
     */
    @Transactional
    public FriendResponse update(UUID id, FriendRequest request) {
        Friend friend = friendRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "朋友不存在"));
        friend.update(
                request.name().trim(),
                clean(request.avatarUrl()),
                clean(request.intro()),
                request.siteUrl().trim(),
                request.visible(),
                request.sortOrder()
        );
        return FriendResponse.from(friend);
    }

    /**
     * 删除友链
     *
     * @param id 友链 ID
     * @throws BusinessException 如果友链不存在
     */
    @Transactional
    public void delete(UUID id) {
        if (!friendRepository.existsById(id)) {
            throw new BusinessException(HttpStatus.NOT_FOUND, "朋友不存在");
        }
        friendRepository.deleteById(id);
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

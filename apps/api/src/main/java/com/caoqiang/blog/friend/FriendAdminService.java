package com.caoqiang.blog.friend;

import com.caoqiang.blog.common.BusinessException;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class FriendAdminService {

    private final FriendRepository friendRepository;

    public FriendAdminService(FriendRepository friendRepository) {
        this.friendRepository = friendRepository;
    }

    @Transactional(readOnly = true)
    public List<FriendResponse> list() {
        return friendRepository.findAllByOrderBySortOrderAscCreatedAtDesc()
                .stream()
                .map(FriendResponse::from)
                .toList();
    }

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

    @Transactional
    public void delete(UUID id) {
        if (!friendRepository.existsById(id)) {
            throw new BusinessException(HttpStatus.NOT_FOUND, "朋友不存在");
        }
        friendRepository.deleteById(id);
    }

    private String clean(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }
}

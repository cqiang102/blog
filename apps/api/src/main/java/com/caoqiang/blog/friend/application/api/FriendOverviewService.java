package com.caoqiang.blog.friend.application.api;

import com.caoqiang.blog.friend.domain.repository.FriendRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FriendOverviewService {

    private final FriendRepository friendRepository;

    public FriendOverviewService(FriendRepository friendRepository) {
        this.friendRepository = friendRepository;
    }

    @Transactional(readOnly = true)
    public long countFriends() {
        return friendRepository.count();
    }
}

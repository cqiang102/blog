package com.caoqiang.blog.friend;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FriendService {

    private final FriendRepository friendRepository;

    public FriendService(FriendRepository friendRepository) {
        this.friendRepository = friendRepository;
    }

    @Transactional(readOnly = true)
    public List<FriendResponse> randomVisible() {
        List<Friend> friends = new ArrayList<>(friendRepository.findByVisibleTrueOrderBySortOrderAscCreatedAtDesc());
        Collections.shuffle(friends);
        return friends.stream().map(FriendResponse::from).toList();
    }
}

package com.caoqiang.blog.friend;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FriendRepository extends JpaRepository<Friend, UUID> {

    List<Friend> findByVisibleTrueOrderBySortOrderAscCreatedAtDesc();

    List<Friend> findAllByOrderBySortOrderAscCreatedAtDesc();
}

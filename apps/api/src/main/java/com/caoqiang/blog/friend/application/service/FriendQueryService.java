package com.caoqiang.blog.friend.application.service;

import com.caoqiang.blog.friend.domain.model.Friend;
import com.caoqiang.blog.friend.domain.repository.FriendRepository;
import com.caoqiang.blog.friend.application.dto.FriendResponse;
import com.caoqiang.blog.content.application.api.ContentMediaService;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 友链服务
 * <p>
 * 处理友链的业务逻辑，提供友链查询功能。
 * <p>
 * 主要职责：
 * <ul>
 *   <li>获取随机排序的可见友链列表</li>
 * </ul>
 * <p>
 * 友链默认按排序权重和创建时间排序，随机化后返回给前端。
 */
@Service
public class FriendQueryService {

    /** 友链数据访问层 */
    private final FriendRepository friendRepository;
    private final ContentMediaService contentMediaService;

    public FriendQueryService(FriendRepository friendRepository, ContentMediaService contentMediaService) {
        this.friendRepository = friendRepository;
        this.contentMediaService = contentMediaService;
    }

    /**
     * 获取随机排序的可见友链列表
     * <p>
     * 查询所有可见友链，随机排序后返回。
     * 用于首页或侧边栏展示，增加友链曝光的随机性。
     *
     * @return 随机排序的友链响应列表
     */
    @Transactional(readOnly = true)
    public List<FriendResponse> randomVisible() {
        // 查询所有可见友链，按排序权重和创建时间排序
        List<Friend> friends = new ArrayList<>(friendRepository.findByVisibleTrueOrderBySortOrderAscCreatedAtDesc());
        // 随机打乱顺序
        Collections.shuffle(friends);
        return friends.stream()
                .map(friend -> FriendResponse.from(friend, contentMediaService::resolveUrl))
                .toList();
    }
}

package com.caoqiang.blog.shared.domain.event.user;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.UUID;

/**
 * 用户创建事件
 * <p>
 * 当新用户注册时发布此事件。
 * 包含用户的基本信息，可用于：
 * <ul>
 *   <li>发送欢迎邮件</li>
 *   <li>初始化用户配置</li>
 *   <li>记录审计日志</li>
 * </ul>
 */
public class UserCreatedEvent extends DomainEvent {

    /** 用户 ID */
    private final UUID userId;

    /** 用户邮箱 */
    private final String email;

    /** 用户昵称 */
    private final String nickname;

    /**
     * 创建用户创建事件
     *
     * @param userId   用户 ID
     * @param email    用户邮箱
     * @param nickname 用户昵称
     */
    public UserCreatedEvent(UUID userId, String email, String nickname) {
        this.userId = userId;
        this.email = email;
        this.nickname = nickname;
    }

    public UUID getUserId() {
        return userId;
    }

    public String getEmail() {
        return email;
    }

    public String getNickname() {
        return nickname;
    }
}

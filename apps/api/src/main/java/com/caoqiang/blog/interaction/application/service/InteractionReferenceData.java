package com.caoqiang.blog.interaction.application.service;

import com.caoqiang.blog.content.application.api.ContentInteractionService;
import com.caoqiang.blog.content.application.api.ContentInteractionSnapshot;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;

@Component
public class InteractionReferenceData {

    private final ContentInteractionService contentInteractionService;
    private final UserAccountService userAccountService;

    public InteractionReferenceData(
            ContentInteractionService contentInteractionService, UserAccountService userAccountService) {
        this.contentInteractionService = contentInteractionService;
        this.userAccountService = userAccountService;
    }

    public Map<UUID, ContentInteractionSnapshot> contents(Collection<UUID> ids) {
        return contentInteractionService.findByIds(ids).stream()
                .collect(Collectors.toMap(ContentInteractionSnapshot::id, Function.identity(), (a, b) -> a));
    }

    public Map<UUID, IdentityUser> users(Collection<UUID> ids) {
        return userAccountService.findByIds(ids).stream()
                .collect(Collectors.toMap(IdentityUser::id, Function.identity(), (a, b) -> a));
    }

    public ContentInteractionSnapshot content(Map<UUID, ContentInteractionSnapshot> contents, UUID id) {
        return contents.getOrDefault(id, new ContentInteractionSnapshot(id, "[已删除的内容]", 0, 0, 0));
    }

    public IdentityUser user(Map<UUID, IdentityUser> users, UUID id) {
        return users.getOrDefault(id, new IdentityUser(id, null, "已注销用户", null, null, null, null, Role.USER, false));
    }

    public String avatarUrl(IdentityUser user) {
        return contentInteractionService.resolveMediaUrl(user.avatarUrl());
    }

    /**
     * 批量解析用户头像 URL，按 userId 去重，避免 N+1 预签名调用。
     */
    public Map<UUID, String> avatarUrls(Map<UUID, IdentityUser> users) {
        Map<UUID, String> result = new HashMap<>(users.size());
        for (IdentityUser user : users.values()) {
            result.put(user.id(), contentInteractionService.resolveMediaUrl(user.avatarUrl()));
        }
        return result;
    }
}

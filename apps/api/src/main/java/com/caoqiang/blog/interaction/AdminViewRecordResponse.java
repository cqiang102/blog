package com.caoqiang.blog.interaction;

import com.caoqiang.blog.user.User;
import java.time.Instant;
import java.util.UUID;

public record AdminViewRecordResponse(
        UUID id,
        UUID contentId,
        String contentTitle,
        UUID userId,
        String userNickname,
        String userEmail,
        String anonymousId,
        String ipHash,
        String userAgent,
        Instant createdAt
) {

    public static AdminViewRecordResponse from(ViewRecord viewRecord) {
        User user = viewRecord.getUser();
        return new AdminViewRecordResponse(
                viewRecord.getId(),
                viewRecord.getContent().getId(),
                viewRecord.getContent().getTitle(),
                user == null ? null : user.getId(),
                user == null ? null : user.getNickname(),
                user == null ? null : user.getEmail(),
                viewRecord.getAnonymousId(),
                viewRecord.getIpHash(),
                viewRecord.getUserAgent(),
                viewRecord.getCreatedAt()
        );
    }
}

package com.caoqiang.blog.interaction.application.service;

import com.caoqiang.blog.content.application.api.ContentInteractionService;
import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.repository.CommentRepository;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CommentAuditResultService {

    private final CommentRepository commentRepository;
    private final ContentInteractionService contentInteractionService;

    public CommentAuditResultService(
            CommentRepository commentRepository, ContentInteractionService contentInteractionService) {
        this.commentRepository = commentRepository;
        this.contentInteractionService = contentInteractionService;
    }

    @Transactional
    public void apply(UUID commentId, CommentStatus auditStatus, String auditReason) {
        commentRepository.findByIdForUpdate(commentId).ifPresent(comment -> {
            CommentStatus previousStatus = comment.getStatus();
            comment.setAuditResult(auditStatus, auditReason);
            syncCommentCount(comment, previousStatus);
        });
    }

    private void syncCommentCount(Comment comment, CommentStatus previousStatus) {
        if (previousStatus == CommentStatus.VISIBLE && !comment.isVisible()) {
            contentInteractionService.incrementCommentCount(comment.getContentId(), -1);
        } else if (previousStatus != CommentStatus.VISIBLE && comment.isVisible()) {
            contentInteractionService.incrementCommentCount(comment.getContentId(), 1);
        }
    }
}

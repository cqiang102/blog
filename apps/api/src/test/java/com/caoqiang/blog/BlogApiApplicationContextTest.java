package com.caoqiang.blog;

import com.caoqiang.blog.ai.AiChatMessageRepository;
import com.caoqiang.blog.ai.AiChatSessionRepository;
import com.caoqiang.blog.ai.AiDailyQuotaRepository;
import com.caoqiang.blog.ai.KnowledgeChunkRepository;
import com.caoqiang.blog.ai.KnowledgeDocRepository;
import com.caoqiang.blog.audit.AuditLogRepository;
import com.caoqiang.blog.auth.OAuthAccountRepository;
import com.caoqiang.blog.auth.RefreshTokenRepository;
import com.caoqiang.blog.content.ContentRepository;
import com.caoqiang.blog.content.MediaAssetRepository;
import com.caoqiang.blog.content.TagRepository;
import com.caoqiang.blog.friend.FriendRepository;
import com.caoqiang.blog.interaction.CommentRepository;
import com.caoqiang.blog.interaction.LikeRepository;
import com.caoqiang.blog.interaction.ViewRecordRepository;
import com.caoqiang.blog.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.redisson.api.RedissonClient;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@ActiveProfiles({"local", "nodb"})
class BlogApiApplicationContextTest {

    @MockitoBean
    private UserRepository userRepository;

    @MockitoBean
    private RefreshTokenRepository refreshTokenRepository;

    @MockitoBean
    private OAuthAccountRepository oauthAccountRepository;

    @MockitoBean
    private ContentRepository contentRepository;

    @MockitoBean
    private MediaAssetRepository mediaAssetRepository;

    @MockitoBean
    private TagRepository tagRepository;

    @MockitoBean
    private FriendRepository friendRepository;

    @MockitoBean
    private CommentRepository commentRepository;

    @MockitoBean
    private LikeRepository likeRepository;

    @MockitoBean
    private ViewRecordRepository viewRecordRepository;

    @MockitoBean
    private AiChatSessionRepository aiChatSessionRepository;

    @MockitoBean
    private AiChatMessageRepository aiChatMessageRepository;

    @MockitoBean
    private AiDailyQuotaRepository aiDailyQuotaRepository;

    @MockitoBean
    private KnowledgeDocRepository knowledgeDocRepository;

    @MockitoBean
    private KnowledgeChunkRepository knowledgeChunkRepository;

    @MockitoBean
    private AuditLogRepository auditLogRepository;

    @MockitoBean
    private EmbeddingModel embeddingModel;

    @MockitoBean
    private ChatClient chatClient;

    @MockitoBean
    private RedissonClient redissonClient;

    @Test
    void contextLoadsWithoutDatabaseForDiagnostics() {
    }
}

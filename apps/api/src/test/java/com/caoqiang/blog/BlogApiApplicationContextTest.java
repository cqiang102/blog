package com.caoqiang.blog;

import com.caoqiang.blog.ai.AiChatMessageRepository;
import com.caoqiang.blog.ai.AiChatSessionRepository;
import com.caoqiang.blog.ai.AiDailyQuotaRepository;
import com.caoqiang.blog.auth.RefreshTokenRepository;
import com.caoqiang.blog.content.ContentRepository;
import com.caoqiang.blog.interaction.CommentRepository;
import com.caoqiang.blog.interaction.LikeRepository;
import com.caoqiang.blog.interaction.ViewRecordRepository;
import com.caoqiang.blog.user.UserRepository;
import org.junit.jupiter.api.Test;
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
    private ContentRepository contentRepository;

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

    @Test
    void contextLoadsWithoutDatabaseForDiagnostics() {
    }
}

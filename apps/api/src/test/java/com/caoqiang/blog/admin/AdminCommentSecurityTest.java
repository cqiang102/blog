package com.caoqiang.blog.admin;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.caoqiang.blog.ai.AiChatMessageRepository;
import com.caoqiang.blog.ai.AiChatSessionRepository;
import com.caoqiang.blog.ai.AiDailyQuotaRepository;
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
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles({"local", "nodb"})
class AdminCommentSecurityTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserRepository userRepository;

    @MockitoBean
    private RefreshTokenRepository refreshTokenRepository;

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

    @Test
    void userCannotAccessAdminComments() throws Exception {
        mockMvc.perform(get("/api/v1/admin/comments").with(user("reader").roles("USER")))
                .andExpect(status().isForbidden());
    }

    @Test
    void userCannotAccessAdminLikes() throws Exception {
        mockMvc.perform(get("/api/v1/admin/likes").with(user("reader").roles("USER")))
                .andExpect(status().isForbidden());
    }

    @Test
    void userCannotAccessAdminViews() throws Exception {
        mockMvc.perform(get("/api/v1/admin/views").with(user("reader").roles("USER")))
                .andExpect(status().isForbidden());
    }

    @Test
    void userCannotAccessAdminUsers() throws Exception {
        mockMvc.perform(get("/api/v1/admin/users").with(user("reader").roles("USER")))
                .andExpect(status().isForbidden());
    }
}

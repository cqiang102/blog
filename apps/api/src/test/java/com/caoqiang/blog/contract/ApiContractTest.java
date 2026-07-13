package com.caoqiang.blog.contract;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.caoqiang.blog.ai.chat.application.dto.AiChatRequest;
import com.caoqiang.blog.ai.chat.application.service.AiChatService;
import com.caoqiang.blog.ai.chat.infrastructure.web.AiChatController;
import com.caoqiang.blog.auth.application.dto.IssuedAuthSession;
import com.caoqiang.blog.auth.application.service.AuthService;
import com.caoqiang.blog.auth.application.service.JwtService;
import com.caoqiang.blog.auth.application.service.OAuthLoginCodeService;
import com.caoqiang.blog.auth.application.service.VerificationService;
import com.caoqiang.blog.auth.infrastructure.web.AuthController;
import com.caoqiang.blog.auth.infrastructure.web.RefreshTokenCookieService;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.content.application.dto.AdminContentRequest;
import com.caoqiang.blog.content.application.dto.AdminContentResponse;
import com.caoqiang.blog.content.application.dto.AdminMediaResponse;
import com.caoqiang.blog.content.application.service.ContentAdminService;
import com.caoqiang.blog.content.application.service.MediaAdminService;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.infrastructure.web.AdminContentController;
import com.caoqiang.blog.content.infrastructure.web.AdminMediaController;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.exception.GlobalExceptionHandler;
import com.caoqiang.blog.user.application.api.UserProfileResponse;
import jakarta.servlet.http.Cookie;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.core.MethodParameter;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

class ApiContractTest {

    @Test
    void refreshTokenEndpointKeepsEnvelopeAndTokenShape() throws Exception {
        AuthService authService = mock(AuthService.class);
        AuthController controller = new AuthController(
                authService,
                mock(VerificationService.class),
                mock(JwtService.class),
                mock(OAuthLoginCodeService.class),
                refreshTokenCookieService(),
                "github-client",
                "http://localhost:3000"
        );
        UUID userId = UUID.randomUUID();
        when(authService.refresh("refresh-token")).thenReturn(new IssuedAuthSession(
                "access-token",
                "refresh-token-next",
                Instant.parse("2026-06-20T06:00:00Z"),
                new UserProfileResponse(
                        userId,
                        "reader@example.com",
                        "读者",
                        null,
                        null,
                        null,
                        Role.USER,
                        true
                )
        ));

        mockMvc(controller)
                .perform(post("/api/v1/auth/refresh")
                        .cookie(new Cookie(RefreshTokenCookieService.COOKIE_NAME, "refresh-token")))
                .andExpect(status().isOk())
                .andExpect(header().string("Set-Cookie", org.hamcrest.Matchers.allOf(
                        org.hamcrest.Matchers.containsString("blog_refresh_token=refresh-token-next"),
                        org.hamcrest.Matchers.containsString("HttpOnly"),
                        org.hamcrest.Matchers.containsString("SameSite=Lax"))))
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").value("ok"))
                .andExpect(jsonPath("$.data.accessToken").value("access-token"))
                .andExpect(jsonPath("$.data.refreshToken").doesNotExist())
                .andExpect(jsonPath("$.data.user.id").value(userId.toString()))
                .andExpect(jsonPath("$.data.user.role").value("USER"));

        verify(authService).refresh("refresh-token");
    }

    @Test
    void logoutRevokesRefreshTokenAndExpiresCookie() throws Exception {
        AuthService authService = mock(AuthService.class);
        AuthController controller = new AuthController(
                authService,
                mock(VerificationService.class),
                mock(JwtService.class),
                mock(OAuthLoginCodeService.class),
                refreshTokenCookieService(),
                "github-client",
                "http://localhost:3000"
        );

        mockMvc(controller)
                .perform(post("/api/v1/auth/logout")
                        .cookie(new Cookie(RefreshTokenCookieService.COOKIE_NAME, "refresh-token")))
                .andExpect(status().isOk())
                .andExpect(header().string("Set-Cookie", org.hamcrest.Matchers.allOf(
                        org.hamcrest.Matchers.containsString("blog_refresh_token="),
                        org.hamcrest.Matchers.containsString("Max-Age=0"),
                        org.hamcrest.Matchers.containsString("HttpOnly"))))
                .andExpect(jsonPath("$.success").value(true));

        verify(authService).revokeRefreshToken("refresh-token");
    }

    @Test
    void refreshWithoutCookieIsRejectedAsUnauthorized() throws Exception {
        AuthService authService = mock(AuthService.class);
        AuthController controller = new AuthController(
                authService,
                mock(VerificationService.class),
                mock(JwtService.class),
                mock(OAuthLoginCodeService.class),
                refreshTokenCookieService(),
                "github-client",
                "http://localhost:3000"
        );

        mockMvc(controller)
                .perform(post("/api/v1/auth/refresh"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void adminContentPublishEndpointKeepsPublishedContentContract() throws Exception {
        ContentAdminService service = mock(ContentAdminService.class);
        AdminContentController controller = new AdminContentController(service);
        UUID contentId = UUID.randomUUID();
        when(service.create(any(AdminContentRequest.class))).thenReturn(new AdminContentResponse(
                contentId,
                "发布契约",
                "publish-contract",
                ContentType.ARTICLE,
                ContentStatus.PUBLISHED,
                "契约摘要",
                "# 正文",
                false,
                null,
                null,
                0,
                List.of(),
                0,
                0,
                0,
                Instant.parse("2026-06-20T06:10:00Z"),
                null,
                List.of()
        ));

        mockMvc(controller)
                .perform(post("/api/v1/admin/contents")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "发布契约",
                                  "slug": "publish-contract",
                                  "type": "ARTICLE",
                                  "status": "PUBLISHED",
                                  "summary": "契约摘要",
                                  "bodyMarkdown": "# 正文",
                                  "pinned": false,
                                  "publishedAt": "2026-06-20T06:10:00Z",
                                  "tagSlugs": [],
                                  "mediaUrls": []
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").value(contentId.toString()))
                .andExpect(jsonPath("$.data.title").value("发布契约"))
                .andExpect(jsonPath("$.data.type").value("ARTICLE"))
                .andExpect(jsonPath("$.data.status").value("PUBLISHED"))
                .andExpect(jsonPath("$.data.slug").value("publish-contract"));

        verify(service).create(any(AdminContentRequest.class));
    }

    @Test
    void adminMediaUploadEndpointKeepsMultipartContract() throws Exception {
        MediaAdminService service = mock(MediaAdminService.class);
        AdminMediaController controller = new AdminMediaController(service);
        UUID mediaId = UUID.randomUUID();
        when(service.upload(isNull(), eq(MediaAssetType.IMAGE), any(MultipartFile.class)))
                .thenReturn(new AdminMediaResponse(
                        mediaId,
                        null,
                        null,
                        MediaAssetType.IMAGE,
                        "blog-media",
                        "uploads/cover.png",
                        "http://localhost:9000/blog-media/uploads/cover.png",
                        "cover.png",
                        "image/png",
                        3L,
                        null,
                        null,
                        null,
                        false,
                        Instant.parse("2026-06-20T06:20:00Z")
                ));
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "cover.png",
                "image/png",
                new byte[] {1, 2, 3}
        );

        mockMvc(controller)
                .perform(multipart("/api/v1/admin/media-assets/upload")
                        .file(file)
                        .param("type", "IMAGE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").value(mediaId.toString()))
                .andExpect(jsonPath("$.data.type").value("IMAGE"))
                .andExpect(jsonPath("$.data.filename").value("cover.png"))
                .andExpect(jsonPath("$.data.publicUrl")
                        .value("http://localhost:9000/blog-media/uploads/cover.png"));

        verify(service).upload(isNull(), eq(MediaAssetType.IMAGE), any(MultipartFile.class));
    }

    @Test
    void aiStreamEndpointKeepsSseContract() throws Exception {
        AiChatService service = mock(AiChatService.class);
        AiChatController controller = new AiChatController(service);
        AuthenticatedUser currentUser = new AuthenticatedUser(
                UUID.randomUUID(),
                "reader@example.com",
                "读者",
                Role.USER
        );
        SseEmitter emitter = new SseEmitter(30_000L);
        when(service.streamChat(eq(currentUser), any(AiChatRequest.class))).thenReturn(emitter);

        mockMvc(controller, authenticatedUserResolver(currentUser))
                .perform(post("/api/v1/ai/chat/stream")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"message":"帮我总结最新文章"}
                                """))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_EVENT_STREAM))
                .andExpect(request().asyncStarted());

        emitter.complete();
        verify(service).streamChat(eq(currentUser), any(AiChatRequest.class));
    }

    private static MockMvc mockMvc(Object controller) {
        return MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    private static RefreshTokenCookieService refreshTokenCookieService() {
        return new RefreshTokenCookieService(new BlogProperties());
    }

    private static MockMvc mockMvc(
            Object controller,
            HandlerMethodArgumentResolver argumentResolver
    ) {
        return MockMvcBuilders
                .standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler())
                .setCustomArgumentResolvers(argumentResolver)
                .build();
    }

    private static HandlerMethodArgumentResolver authenticatedUserResolver(
            AuthenticatedUser user
    ) {
        return new HandlerMethodArgumentResolver() {
            @Override
            public boolean supportsParameter(MethodParameter parameter) {
                return parameter.hasParameterAnnotation(AuthenticationPrincipal.class)
                        && parameter.getParameterType().equals(AuthenticatedUser.class);
            }

            @Override
            public Object resolveArgument(
                    MethodParameter parameter,
                    ModelAndViewContainer mavContainer,
                    NativeWebRequest webRequest,
                    WebDataBinderFactory binderFactory
            ) {
                return user;
            }
        };
    }
}

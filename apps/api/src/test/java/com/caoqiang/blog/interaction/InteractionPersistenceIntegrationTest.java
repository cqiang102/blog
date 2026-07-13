package com.caoqiang.blog.interaction;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.model.Like;
import com.caoqiang.blog.interaction.domain.model.ViewRecord;
import com.caoqiang.blog.interaction.domain.repository.CommentRepository;
import com.caoqiang.blog.interaction.domain.repository.LikeRepository;
import com.caoqiang.blog.interaction.domain.repository.ViewRecordRepository;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
class InteractionPersistenceIntegrationTest {

    private static final DockerImageName POSTGRES_IMAGE = DockerImageName
            .parse("pgvector/pgvector:pg18")
            .asCompatibleSubstituteFor("postgres");

    @Container
    private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(POSTGRES_IMAGE)
            .withDatabaseName("blog")
            .withUsername("blog")
            .withPassword("blog");

    @DynamicPropertySource
    static void databaseProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.jpa.hibernate.ddl-auto", () -> "validate");
        registry.add("spring.flyway.enabled", () -> "true");
    }

    @Autowired
    private CommentRepository commentRepository;
    @Autowired
    private LikeRepository likeRepository;
    @Autowired
    private ViewRecordRepository viewRecordRepository;
    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void persistsAndQueriesInteractionRecordsUsingScalarForeignKeys() {
        UUID contentId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();
        jdbcTemplate.update(
                """
                INSERT INTO users (id, email, nickname, role, status, created_at, updated_at)
                VALUES (?, 'interaction@example.com', 'Interaction Test', 'USER', 'ACTIVE', now(), now())
                """,
                userId
        );
        jdbcTemplate.update(
                """
                INSERT INTO contents (id, title, slug, type, status, created_at, updated_at)
                VALUES (?, 'Interaction Content', 'interaction-content', 'ARTICLE', 'PUBLISHED', now(), now())
                """,
                contentId
        );

        Comment comment = commentRepository.saveAndFlush(new Comment(contentId, userId, "hello"));
        Like like = likeRepository.saveAndFlush(new Like(contentId, userId));
        ViewRecord view = viewRecordRepository.saveAndFlush(
                new ViewRecord(contentId, userId, null, "ip-hash", "JUnit")
        );

        assertThat(commentRepository.findByContentIdAndStatusOrderByCreatedAtDesc(
                contentId, CommentStatus.VISIBLE, PageRequest.of(0, 10)
        )).contains(comment);
        assertThat(likeRepository.findByContentIdAndUserId(contentId, userId)).contains(like);
        assertThat(viewRecordRepository.findByIdAndUserId(view.getId(), userId)).contains(view);
        assertThat(comment.getContentId()).isEqualTo(contentId);
        assertThat(comment.getUserId()).isEqualTo(userId);
        assertThat(like.getContentId()).isEqualTo(contentId);
        assertThat(view.getUserId()).isEqualTo(userId);
    }
}

package com.caoqiang.blog;

import com.caoqiang.blog.support.PostgresRepositoryIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.testcontainers.junit.jupiter.Testcontainers;

/** Verifies that the complete application graph can be created with the migrated schema. */
@SpringBootTest(properties = {"blog.admin.bootstrap.enabled=false", "spring.task.scheduling.enabled=false"})
@Testcontainers(disabledWithoutDocker = true)
class ApplicationContextIntegrationTest extends PostgresRepositoryIntegrationTest {

    @Test
    void contextLoads() {
        // SpringBootTest fails before this method when any production bean cannot be wired.
    }
}

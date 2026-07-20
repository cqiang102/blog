package com.caoqiang.blog.audit;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.audit.domain.model.AuditAction;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class AuditActionTest {

    @ParameterizedTest
    @CsvSource({
        "create, CREATE",
        "upload, CREATE",
        "softDelete, DELETE",
        "deleteLike, DELETE",
        "restore, UPDATE",
        "disable, UPDATE",
        "setCover, UPDATE",
        "reindexFailedChunks, UPDATE",
        "getIndexStatus, READ",
        "indexStatus, READ",
        "likes, READ",
        "views, READ",
        "futureAdminMutation, UPDATE"
    })
    void mapsEveryAdminMethodNameWithoutThrowing(String methodName, AuditAction expected) {
        assertThat(AuditAction.fromMethodName(methodName)).isEqualTo(expected);
    }
}

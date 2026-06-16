package com.caoqiang.blog.shared;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.shared.exception.GlobalExceptionHandler;
import com.caoqiang.blog.shared.response.ApiResponse;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import org.springframework.web.server.ResponseStatusException;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void preservesResponseStatusExceptionStatusAndMessage() {
        ResponseEntity<ApiResponse<Void>> response = handler.handleResponseStatusException(
                new ResponseStatusException(HttpStatus.BAD_REQUEST, "OAuth state 无效或已过期")
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().message()).isEqualTo("OAuth state 无效或已过期");
    }

    @Test
    void mapsMissingStaticResourceToNotFound() {
        ResponseEntity<ApiResponse<Void>> response = handler.handleNotFound(
                new NoResourceFoundException(HttpMethod.GET, "/api/v1/auth/missing", "")
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().message()).isEqualTo("接口不存在");
    }

    @Test
    void mapsDatabaseConstraintConflictToConflict() {
        ResponseEntity<ApiResponse<Void>> response = handler.handleDataIntegrityViolation(
                new DataIntegrityViolationException("duplicate key")
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().message()).isEqualTo("数据已存在或发生冲突");
    }
}

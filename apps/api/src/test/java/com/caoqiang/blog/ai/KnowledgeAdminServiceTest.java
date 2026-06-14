package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.knowledge.application.dto.KnowledgeDocRequest;
import com.caoqiang.blog.ai.knowledge.application.dto.KnowledgeDocResponse;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeDoc;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeSourceType;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeDocRepository;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeAdminService;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeIndexService;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class KnowledgeAdminServiceTest {

    @Mock
    private KnowledgeDocRepository knowledgeDocRepository;

    @Mock
    private KnowledgeChunkRepository knowledgeChunkRepository;

    @Mock
    private KnowledgeIndexService knowledgeIndexService;

    @Test
    void createTrimsTextAndKeepsEnabledFlag() {
        KnowledgeAdminService service = new KnowledgeAdminService(
                knowledgeDocRepository,
                knowledgeChunkRepository,
                knowledgeIndexService
        );
        KnowledgeDocRequest request = new KnowledgeDocRequest(
                " 关于我 ",
                KnowledgeSourceType.MANUAL,
                "  profile  ",
                "  这是个人介绍  ",
                true
        );
        when(knowledgeDocRepository.save(org.mockito.ArgumentMatchers.any(KnowledgeDoc.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        KnowledgeDocResponse response = service.create(request);

        assertThat(response.title()).isEqualTo("关于我");
        assertThat(response.sourceRef()).isEqualTo("profile");
        assertThat(response.body()).isEqualTo("这是个人介绍");
        assertThat(response.enabled()).isTrue();
    }

    @Test
    void updateRejectsMissingDoc() {
        UUID id = UUID.randomUUID();
        KnowledgeAdminService service = new KnowledgeAdminService(
                knowledgeDocRepository,
                knowledgeChunkRepository,
                knowledgeIndexService
        );
        KnowledgeDocRequest request = new KnowledgeDocRequest(
                "关于我",
                KnowledgeSourceType.MANUAL,
                null,
                null,
                true
        );
        when(knowledgeDocRepository.findById(id)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.update(id, request))
                .isInstanceOfSatisfying(BusinessException.class, error -> {
                    assertThat(error.status()).isEqualTo(HttpStatus.NOT_FOUND);
                    assertThat(error.getMessage()).isEqualTo("知识库文档不存在");
                });
    }

    @Test
    void deleteRemovesExistingDoc() {
        UUID id = UUID.randomUUID();
        KnowledgeAdminService service = new KnowledgeAdminService(
                knowledgeDocRepository,
                knowledgeChunkRepository,
                knowledgeIndexService
        );
        when(knowledgeDocRepository.existsById(id)).thenReturn(true);

        service.delete(id);

        verify(knowledgeChunkRepository).deleteByDocId(id);
        verify(knowledgeDocRepository).deleteById(id);
    }
}

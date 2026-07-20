package com.caoqiang.blog.shared;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.shared.util.PageUtils;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

class PageUtilsTest {

    private static final Sort SORT = Sort.by(Sort.Direction.DESC, "createdAt");

    @Test
    void clampsInvalidPageAndSize() {
        PageRequest request = PageUtils.of(-3, 0, 25, SORT);

        assertThat(request.getPageNumber()).isZero();
        assertThat(request.getPageSize()).isOne();
        assertThat(request.getSort()).isEqualTo(SORT);
    }

    @Test
    void capsOversizedPage() {
        PageRequest request = PageUtils.of(2, 100, 25, SORT);

        assertThat(request.getPageNumber()).isEqualTo(2);
        assertThat(request.getPageSize()).isEqualTo(25);
    }
}

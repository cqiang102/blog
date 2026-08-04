package com.caoqiang.blog.content.infrastructure.storage;

import com.caoqiang.blog.content.application.port.MediaStorageProvisioner;
import com.caoqiang.blog.shared.exception.BusinessException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

/**
 * Qiniu Kodo provisioner.
 *
 * <p>空间在七牛控制台/API 中预创建（lacia-public / lacia-private），这里只校验配置，
 * 让配置缺失或拼写错误时快速失败。</p>
 */
@Component
public class QiniuMediaStorageProvisioner implements MediaStorageProvisioner {

    private static final Logger log = LoggerFactory.getLogger(QiniuMediaStorageProvisioner.class);

    private final String publicBucket;
    private final String publicDomain;

    public QiniuMediaStorageProvisioner(
            @Value("${dromara.x-file-storage.qiniu-kodo[0].bucket-name:lacia-public}") String publicBucket,
            @Value("${dromara.x-file-storage.qiniu-kodo[0].domain:}") String publicDomain) {
        this.publicBucket = publicBucket;
        this.publicDomain = publicDomain;
    }

    @Override
    public void ensureReady() {
        if (!StringUtils.hasText(publicBucket) || !StringUtils.hasText(publicDomain)) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "文件存储配置不完整");
        }
        log.info("Qiniu Kodo 存储就绪: bucket={}, domain={}", publicBucket, publicDomain);
    }
}

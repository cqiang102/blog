package com.caoqiang.blog.config;

import org.dromara.x.file.storage.core.FileInfo;
import org.dromara.x.file.storage.core.recorder.FileRecorder;
import org.dromara.x.file.storage.core.upload.FilePartInfo;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * NoOp 文件记录器实现
 * <p>
 * 仅打印日志，不持久化文件信息。
 * 项目使用 MediaAsset 实体自行管理文件元数据，因此不需要 x-file-storage 的默认数据库记录功能。
 * </p>
 */
@Component
public class NoOpFileRecorder implements FileRecorder {

    private static final Logger log = LoggerFactory.getLogger(NoOpFileRecorder.class);

    @Override
    public boolean save(FileInfo fileInfo) {
        log.debug("FileRecorder.save - 文件上传记录: platform={}, size={}", fileInfo.getPlatform(), fileInfo.getSize());
        return true;
    }

    @Override
    public void update(FileInfo fileInfo) {
        log.debug("FileRecorder.update - 文件更新记录: platform={}", fileInfo.getPlatform());
    }

    @Override
    public FileInfo getByUrl(String url) {
        log.debug("FileRecorder.getByUrl - 查询文件记录");
        return null;
    }

    @Override
    public boolean delete(String url) {
        log.debug("FileRecorder.delete - 删除文件记录");
        return true;
    }

    @Override
    public void saveFilePart(FilePartInfo filePartInfo) {
        log.debug("FileRecorder.saveFilePart - 保存分片信息: partNumber={}", filePartInfo.getPartNumber());
    }

    @Override
    public void deleteFilePartByUploadId(String uploadId) {
        log.debug("FileRecorder.deleteFilePartByUploadId - 删除分片信息");
    }
}

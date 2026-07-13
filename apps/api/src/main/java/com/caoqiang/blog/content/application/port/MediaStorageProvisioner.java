package com.caoqiang.blog.content.application.port;

/**
 * Prepares the object storage required by content media operations.
 */
public interface MediaStorageProvisioner {

    void ensureReady();
}

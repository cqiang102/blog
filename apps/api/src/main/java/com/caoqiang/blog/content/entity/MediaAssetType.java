package com.caoqiang.blog.content.entity;

/**
 * 媒体资源类型枚举。
 * <p>
 * 定义媒体资源的分类，用于上传时的类型推断和前端展示差异化处理。
 */
public enum MediaAssetType {

    /** 图片类型（jpg、jpeg、png、gif、webp 等） */
    IMAGE,

    /** 视频类型（mp4、webm、mov 等） */
    VIDEO,

    /** 通用文件类型（不匹配图片和视频时的默认类型） */
    FILE
}

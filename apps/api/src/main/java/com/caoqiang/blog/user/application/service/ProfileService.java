package com.caoqiang.blog.user.application.service;

import com.caoqiang.blog.content.application.api.ContentMediaService;
import com.caoqiang.blog.content.application.api.ContentMediaUpload;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.UploadedFile;
import com.caoqiang.blog.shared.util.PasswordPolicy;
import com.caoqiang.blog.user.application.api.UserProfileResponse;
import com.caoqiang.blog.user.application.dto.ChangePasswordRequest;
import com.caoqiang.blog.user.application.dto.OAuthAccountResponse;
import com.caoqiang.blog.user.application.dto.SetPasswordRequest;
import com.caoqiang.blog.user.application.dto.UpdateProfileRequest;
import com.caoqiang.blog.user.application.port.OAuthAccountPort;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 个人资料服务
 * <p>
 * 处理用户个人资料的业务逻辑，包括：
 * <ul>
 *   <li>获取当前用户资料</li>
 *   <li>更新个人资料（昵称、头像、简介等）</li>
 *   <li>修改密码</li>
 *   <li>上传头像</li>
 * </ul>
 * <p>
 * 所有写操作均使用事务管理，确保数据一致性。
 */
@Service
public class ProfileService {

    private static final Logger log = LoggerFactory.getLogger(ProfileService.class);
    private static final long MAX_AVATAR_BYTES = 5L * 1024 * 1024;

    /** 用户数据访问层 */
    private final UserRepository userRepository;
    /** 密码编码器，用于密码加密和验证 */
    private final PasswordEncoder passwordEncoder;
    /** OAuth 账户数据访问层 */
    private final OAuthAccountPort oauthAccountPort;
    /** 系统时钟 */
    private final Clock clock;
    /** 媒体服务，用于统一 URL 解析 */
    private final ContentMediaService contentMediaService;
    /** 头像引用写入器，用短事务更新用户资料 */
    private final ProfileAvatarWriter profileAvatarWriter;

    public ProfileService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            OAuthAccountPort oauthAccountPort,
            Clock clock,
            ContentMediaService contentMediaService,
            ProfileAvatarWriter profileAvatarWriter) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.oauthAccountPort = oauthAccountPort;
        this.clock = clock;
        this.contentMediaService = contentMediaService;
        this.profileAvatarWriter = profileAvatarWriter;
    }

    /**
     * 获取当前用户个人资料
     *
     * @param currentUser 当前认证用户
     * @return 用户资料响应 DTO
     */
    @Transactional(readOnly = true)
    public UserProfileResponse getProfile(AuthenticatedUser currentUser) {
        User user = findActiveUser(currentUser);
        return UserProfileResponse.from(user, generatePresignedAvatarUrl(user.getAvatarUrl()));
    }

    /**
     * 更新当前用户个人资料
     * <p>
     * 仅更新请求中非空的字段。邮箱变更必须走独立的验证码确认流程，
     * 当前资料接口拒绝直接修改邮箱。
     *
     * @param currentUser 当前认证用户
     * @param request     更新资料请求体
     * @return 更新后的用户资料响应 DTO
     * @throws BusinessException 如果新邮箱已被其他用户使用
     */
    @Transactional
    public UserProfileResponse update(AuthenticatedUser currentUser, UpdateProfileRequest request) {
        User user = findActiveUser(currentUser);
        if (StringUtils.hasText(request.email())
                && !user.getEmail().equalsIgnoreCase(request.email().trim())) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "更换邮箱需先完成新邮箱验证");
        }

        // 更新用户资料字段
        user.updateProfile(
                user.getEmail(),
                StringUtils.hasText(request.nickname()) ? request.nickname().trim() : user.getNickname(),
                contentMediaService.normalizeForPersistence(request.avatarUrl()),
                request.bio(),
                request.blogUrl());
        return UserProfileResponse.from(user, generatePresignedAvatarUrl(user.getAvatarUrl()));
    }

    /**
     * 修改当前用户密码
     * <p>
     * 验证旧密码正确后，将密码更新为新密码。
     * 仅支持已设置密码的本地账号，OAuth 账号需先设置密码。
     *
     * @param currentUser 当前认证用户
     * @param request     修改密码请求体，包含旧密码和新密码
     * @throws BusinessException 如果账号未设置密码或旧密码不正确
     */
    @Transactional
    public void changePassword(AuthenticatedUser currentUser, ChangePasswordRequest request) {
        User user = findActiveUser(currentUser);

        // 检查用户是否已设置密码（OAuth 用户可能未设置）
        if (user.getPasswordHash() == null) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "该账号未设置密码，请通过 OAuth 登录后设置");
        }

        // 验证旧密码
        if (!passwordEncoder.matches(request.oldPassword(), user.getPasswordHash())) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "旧密码不正确");
        }

        // 加密并保存新密码
        PasswordPolicy.validate(request.newPassword());
        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
    }

    /**
     * 设置密码（用于 OAuth 用户首次设置密码）
     * <p>
     * 仅允许未设置密码的用户调用，设置后即可使用密码登录。
     *
     * @param currentUser 当前认证用户
     * @param request     设置密码请求体，仅包含新密码
     * @throws BusinessException 如果用户已设置密码
     */
    @Transactional
    public void setPassword(AuthenticatedUser currentUser, SetPasswordRequest request) {
        User user = findActiveUser(currentUser);

        // 检查用户是否已设置密码
        if (user.getPasswordHash() != null) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "已设置密码，请使用修改密码功能");
        }

        // 加密并保存新密码
        PasswordPolicy.validate(request.newPassword());
        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
    }

    /**
     * 上传并更新用户头像
     * <p>
     * 上传图片到对象存储，然后更新用户头像 URL。
     *
     * @param currentUser 当前认证用户
     * @param file        上传的图片文件
     * @return 更新后的用户资料响应
     */
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public UserProfileResponse uploadAndUpdateAvatar(AuthenticatedUser currentUser, UploadedFile file) {
        findActiveUser(currentUser);
        ContentMediaUpload upload = storeAvatar(file);
        try {
            String avatarUrl = contentMediaService.portableStoragePath(upload.objectKey());
            String resolvedAvatarUrl = generatePresignedAvatarUrl(avatarUrl);
            User user = profileAvatarWriter.updateAvatar(currentUser.id(), avatarUrl);
            return UserProfileResponse.from(user, resolvedAvatarUrl);
        } catch (RuntimeException exception) {
            deleteUploadedMediaQuietly(upload, "failed profile update");
            throw exception;
        }
    }

    /**
     * 获取当前用户绑定的 OAuth 账户列表
     *
     * @param currentUser 当前认证用户
     * @return OAuth 账户响应列表
     */
    @Transactional(readOnly = true)
    public List<OAuthAccountResponse> getOAuthAccounts(AuthenticatedUser currentUser) {
        return oauthAccountPort.findByUserId(currentUser.id()).stream()
                .map(OAuthAccountResponse::from)
                .toList();
    }

    /**
     * 解绑指定的 OAuth 账户
     * <p>
     * 仅允许已设置密码的用户解绑 OAuth 账户，OAuth-only 用户需先设置密码。
     *
     * @param currentUser 当前认证用户
     * @param provider    要解绑的 OAuth 提供者
     * @throws BusinessException 如果用户未设置密码或未绑定该提供者
     */
    @Transactional
    public void unbindOAuthAccount(AuthenticatedUser currentUser, String provider) {
        User user = findActiveUser(currentUser);

        // OAuth-only 用户（无密码）不能解绑
        if (user.getPasswordHash() == null) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "请先设置密码后再解绑");
        }

        if (!StringUtils.hasText(provider) || !oauthAccountPort.remove(currentUser.id(), provider)) {
            throw new BusinessException(HttpStatus.NOT_FOUND, "未绑定该账号");
        }
    }

    private AvatarFormat detectAvatarFormat(UploadedFile file) {
        byte[] header;
        try (var input = file.openStream()) {
            header = input.readNBytes(12);
        } catch (IOException exception) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "无法读取头像文件");
        }

        if (startsWith(header, new byte[] {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF})) {
            return new AvatarFormat(".jpg", "image/jpeg");
        }
        if (startsWith(header, new byte[] {(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A})) {
            return new AvatarFormat(".png", "image/png");
        }
        String ascii = new String(header, StandardCharsets.US_ASCII);
        if (ascii.startsWith("GIF87a") || ascii.startsWith("GIF89a")) {
            return new AvatarFormat(".gif", "image/gif");
        }
        if (ascii.startsWith("RIFF")
                && ascii.length() >= 12
                && ascii.substring(8, 12).equals("WEBP")) {
            return new AvatarFormat(".webp", "image/webp");
        }
        throw new BusinessException(HttpStatus.BAD_REQUEST, "仅支持 JPEG、PNG、GIF 或 WebP 图片");
    }

    private boolean startsWith(byte[] value, byte[] prefix) {
        if (value.length < prefix.length) {
            return false;
        }
        for (int i = 0; i < prefix.length; i++) {
            if (value[i] != prefix[i]) {
                return false;
            }
        }
        return true;
    }

    /**
     * 生成头像的预签名 URL（委托给 MediaAdminService 统一处理）。
     *
     * @param avatarUrl 原始头像 URL
     * @return 预签名 URL 或原 URL
     */
    public String generatePresignedAvatarUrl(String avatarUrl) {
        return contentMediaService.resolveUrl(avatarUrl);
    }

    public String normalizeAvatarUrlForPersistence(String avatarUrl) {
        return contentMediaService.normalizeForPersistence(avatarUrl);
    }

    private ContentMediaUpload storeAvatar(UploadedFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "请选择要上传的图片");
        }
        if (file.size() > MAX_AVATAR_BYTES) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "头像文件不能超过 5MB");
        }

        AvatarFormat format = detectAvatarFormat(file);
        String path = "avatars/" + LocalDate.now(clock).format(DateTimeFormatter.ofPattern("yyyy/MM/dd")) + "/";
        String filename = "avatar_" + clock.instant().toEpochMilli() + format.extension();
        return contentMediaService.upload(file, path, filename, format.contentType());
    }

    private void deleteUploadedMediaQuietly(ContentMediaUpload upload, String reason) {
        try {
            contentMediaService.delete(upload);
        } catch (Exception exception) {
            log.error(
                    "Failed to clean up uploaded avatar after {}: platform={}, objectKey={}",
                    reason,
                    upload.platform(),
                    upload.objectKey(),
                    exception);
        }
    }

    /**
     * 查找活跃用户，如果用户不存在或非活跃状态则抛出异常
     *
     * @param currentUser 当前认证用户
     * @return 用户实体
     * @throws BusinessException 如果用户不存在或非活跃状态
     */
    private User findActiveUser(AuthenticatedUser currentUser) {
        return userRepository
                .findById(currentUser.id())
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }

    private record AvatarFormat(String extension, String contentType) {}
}

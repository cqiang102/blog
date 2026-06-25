package com.caoqiang.blog.user.application.service;

import com.caoqiang.blog.user.application.dto.AdminUserRequest;
import com.caoqiang.blog.user.application.dto.AdminUserResponse;
import com.caoqiang.blog.user.application.dto.ChangePasswordRequest;
import com.caoqiang.blog.user.application.dto.OAuthAccountResponse;
import com.caoqiang.blog.user.application.dto.SetPasswordRequest;
import com.caoqiang.blog.user.application.dto.UpdateProfileRequest;
import com.caoqiang.blog.user.application.dto.UserProfileResponse;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.model.UserStatus;
import com.caoqiang.blog.user.domain.repository.UserRepository;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.util.PasswordPolicy;
import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import com.caoqiang.blog.auth.domain.repository.OAuthAccountRepository;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import com.caoqiang.blog.shared.exception.BusinessException;
import org.dromara.x.file.storage.core.FileInfo;
import org.dromara.x.file.storage.core.FileStorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Date;
import java.util.List;

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
    /** 文件存储服务 */
    private final FileStorageService fileStorageService;
    /** OAuth 账户数据访问层 */
    private final OAuthAccountRepository oauthAccountRepository;
    /** 系统时钟 */
    private final Clock clock;
    /** MinIO platform 名称 */
    private final String platform;
    /** 媒体服务，用于统一 URL 解析 */
    private final com.caoqiang.blog.content.application.service.MediaAdminService mediaAdminService;

    public ProfileService(UserRepository userRepository, PasswordEncoder passwordEncoder,
                          FileStorageService fileStorageService, OAuthAccountRepository oauthAccountRepository,
                          Clock clock, @Value("${dromara.x-file-storage.default-platform}") String platform,
                          com.caoqiang.blog.content.application.service.MediaAdminService mediaAdminService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.fileStorageService = fileStorageService;
        this.oauthAccountRepository = oauthAccountRepository;
        this.clock = clock;
        this.platform = platform;
        this.mediaAdminService = mediaAdminService;
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
                mediaAdminService.normalizeStorageUrlForPersistence(request.avatarUrl()),
                request.bio(),
                request.blogUrl()
        );
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
     * 上传用户头像
     * <p>
     * 将图片文件上传到对象存储，返回可访问的 URL。
     * 文件保存路径: avatars/{yyyy/MM/dd}/filename
     *
     * @param file 上传的图片文件
     * @return 头像访问 URL
     * @throws BusinessException 如果文件为空或上传失败
     */
    @Transactional(readOnly = true)
    public String uploadAvatar(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "请选择要上传的图片");
        }
        if (file.getSize() > MAX_AVATAR_BYTES) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "头像文件不能超过 5MB");
        }

        AvatarFormat format = detectAvatarFormat(file);
        String path = "avatars/" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd")) + "/";
        String filename = "avatar_" + System.currentTimeMillis() + format.extension();

        mediaAdminService.ensureUploadStorageReady();
        FileInfo fileInfo = fileStorageService.of(file)
                .setPath(path)
                .setSaveFilename(filename)
                .setContentType(format.contentType())
                .upload();

        return mediaAdminService.portableStoragePath(fileInfo.getPath() + fileInfo.getFilename());
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
    @Transactional
    public UserProfileResponse uploadAndUpdateAvatar(AuthenticatedUser currentUser, MultipartFile file) {
        String avatarUrl = uploadAvatar(file);
        User user = findActiveUser(currentUser);
        user.setAvatarUrl(avatarUrl);
        return UserProfileResponse.from(user, generatePresignedAvatarUrl(avatarUrl));
    }

    /**
     * 获取当前用户绑定的 OAuth 账户列表
     *
     * @param currentUser 当前认证用户
     * @return OAuth 账户响应列表
     */
    @Transactional(readOnly = true)
    public List<OAuthAccountResponse> getOAuthAccounts(AuthenticatedUser currentUser) {
        List<OAuthAccount> accounts = oauthAccountRepository.findByUserId(currentUser.id());
        return accounts.stream()
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
    public void unbindOAuthAccount(AuthenticatedUser currentUser, OAuthProvider provider) {
        User user = findActiveUser(currentUser);

        // OAuth-only 用户（无密码）不能解绑
        if (user.getPasswordHash() == null) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "请先设置密码后再解绑");
        }

        OAuthAccount account = oauthAccountRepository.findByUserIdAndProvider(currentUser.id(), provider)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "未绑定该账号"));

        oauthAccountRepository.delete(account);
    }

    private AvatarFormat detectAvatarFormat(MultipartFile file) {
        byte[] header;
        try (var input = file.getInputStream()) {
            header = input.readNBytes(12);
        } catch (IOException exception) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "无法读取头像文件");
        }

        if (startsWith(header, new byte[] {
                (byte) 0xFF, (byte) 0xD8, (byte) 0xFF
        })) {
            return new AvatarFormat(".jpg", "image/jpeg");
        }
        if (startsWith(header, new byte[] {
                (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
        })) {
            return new AvatarFormat(".png", "image/png");
        }
        String ascii = new String(header, StandardCharsets.US_ASCII);
        if (ascii.startsWith("GIF87a") || ascii.startsWith("GIF89a")) {
            return new AvatarFormat(".gif", "image/gif");
        }
        if (ascii.startsWith("RIFF") && ascii.length() >= 12 && ascii.substring(8, 12).equals("WEBP")) {
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
        return mediaAdminService.resolveUrl(avatarUrl);
    }

    public String normalizeAvatarUrlForPersistence(String avatarUrl) {
        return mediaAdminService.normalizeStorageUrlForPersistence(avatarUrl);
    }

    /**
     * 查找活跃用户，如果用户不存在或非活跃状态则抛出异常
     *
     * @param currentUser 当前认证用户
     * @return 用户实体
     * @throws BusinessException 如果用户不存在或非活跃状态
     */
    private User findActiveUser(AuthenticatedUser currentUser) {
        return userRepository.findById(currentUser.id())
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }

    private record AvatarFormat(String extension, String contentType) {
    }
}

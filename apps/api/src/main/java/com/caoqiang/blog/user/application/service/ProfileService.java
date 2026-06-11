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
import com.caoqiang.blog.shared.util.EmailNormalizer;
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

    public ProfileService(UserRepository userRepository, PasswordEncoder passwordEncoder,
                          FileStorageService fileStorageService, OAuthAccountRepository oauthAccountRepository,
                          Clock clock, @Value("${dromara.x-file-storage.default-platform}") String platform) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.fileStorageService = fileStorageService;
        this.oauthAccountRepository = oauthAccountRepository;
        this.clock = clock;
        this.platform = platform;
    }

    /**
     * 获取当前用户个人资料
     *
     * @param currentUser 当前认证用户
     * @return 用户资料响应 DTO
     */
    @Transactional(readOnly = true)
    public UserProfileResponse me(AuthenticatedUser currentUser) {
        User user = findActiveUser(currentUser);
        return UserProfileResponse.from(user, generatePresignedAvatarUrl(user.getAvatarUrl()));
    }

    /**
     * 更新当前用户个人资料
     * <p>
     * 仅更新请求中非空的字段，邮箱变更时检查唯一性。
     *
     * @param currentUser 当前认证用户
     * @param request     更新资料请求体
     * @return 更新后的用户资料响应 DTO
     * @throws BusinessException 如果新邮箱已被其他用户使用
     */
    @Transactional
    public UserProfileResponse update(AuthenticatedUser currentUser, UpdateProfileRequest request) {
        User user = findActiveUser(currentUser);
        // 规范化邮箱，如果请求中提供了新邮箱则使用，否则保留原邮箱
        String newEmail = StringUtils.hasText(request.email())
                ? EmailNormalizer.normalize(request.email())
                : user.getEmail();

        // 检查邮箱唯一性（仅当邮箱变更时）
        if (!user.getEmail().equalsIgnoreCase(newEmail) && userRepository.existsByEmail(newEmail)) {
            throw new BusinessException(HttpStatus.CONFLICT, "邮箱已被使用");
        }

        // 更新用户资料字段
        user.updateProfile(
                newEmail,
                StringUtils.hasText(request.nickname()) ? request.nickname().trim() : user.getNickname(),
                request.avatarUrl(),
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

        String contentType = file.getContentType();
        if (contentType == null || !contentType.startsWith("image/")) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "仅支持上传图片文件");
        }

        String path = "avatars/" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd")) + "/";
        String filename = "avatar_" + System.currentTimeMillis() + getExtension(file.getOriginalFilename());

        FileInfo fileInfo = fileStorageService.of(file)
                .setPath(path)
                .setSaveFilename(filename)
                .setContentType(contentType)
                .upload();

        return fileInfo.getUrl();
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

    /**
     * 获取文件扩展名（包含点号）
     *
     * @param filename 文件名
     * @return 扩展名，如 ".jpg"，无扩展名时返回空字符串
     */
    private String getExtension(String filename) {
        if (filename == null) return "";
        int dot = filename.lastIndexOf('.');
        return dot >= 0 ? filename.substring(dot) : "";
    }

    /**
     * 生成头像的预签名 URL
     * <p>
     * 如果头像 URL 为空或不是 MinIO 存储的文件，直接返回原 URL。
     * 否则生成有效期 7 天的预签名 URL。
     *
     * @param avatarUrl 原始头像 URL
     * @return 预签名 URL 或原 URL
     */
    public String generatePresignedAvatarUrl(String avatarUrl) {
        if (!StringUtils.hasText(avatarUrl)) {
            return avatarUrl;
        }

        // 如果 URL 已经包含预签名参数，先去除
        int queryIndex = avatarUrl.indexOf('?');
        if (queryIndex > 0 && avatarUrl.contains("X-Amz-Algorithm")) {
            avatarUrl = avatarUrl.substring(0, queryIndex);
        }

        try {
            // 从 URL 中提取 objectKey
            // URL 格式: http://localhost:9000/uploads/avatars/2026/06/04/avatar_xxx.jpg
            // base-path 是 uploads/，所以 path 应该是 avatars/2026/06/04/
            String basePath = "uploads/";
            int basePathIndex = avatarUrl.indexOf(basePath);
            if (basePathIndex < 0) {
                log.info("头像 URL 不包含 uploads/ 路径: {}", avatarUrl);
                return avatarUrl;
            }

            // 提取 uploads/ 后面的部分作为 path
            String afterBasePath = avatarUrl.substring(basePathIndex + basePath.length());
            
            // 分离 path 和 filename
            int lastSlash = afterBasePath.lastIndexOf('/');
            if (lastSlash < 0) {
                log.info("无法从 URL 中解析路径: {}", avatarUrl);
                return avatarUrl;
            }
            
            // path 是最后一个 / 前面的部分（包含 /）
            String path = afterBasePath.substring(0, lastSlash + 1);
            // filename 是最后一个 / 后面的部分
            String filename = afterBasePath.substring(lastSlash + 1);

            log.info("解析头像 URL: path={}, filename={}", path, filename);

            FileInfo fileInfo = new FileInfo();
            fileInfo.setPlatform(platform);
            fileInfo.setPath(path);
            fileInfo.setFilename(filename);
            fileInfo.setUrl(avatarUrl);

            LocalDateTime expiry = LocalDateTime.now(clock).plusDays(7);
            Date expiryDate = Date.from(expiry.atZone(ZoneId.systemDefault()).toInstant());
            String presignedUrl = fileStorageService.generatePresignedUrl(fileInfo, expiryDate);
            
            if (presignedUrl == null) {
                log.warn("生成预签名 URL 返回 null，原 URL: {}", avatarUrl);
                return avatarUrl;
            }
            
            log.info("生成预签名 URL 成功: {} -> {}", avatarUrl, presignedUrl);
            return presignedUrl;
        } catch (Exception e) {
            log.error("生成预签名 URL 失败: {}", e.getMessage(), e);
            return avatarUrl;
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
        return userRepository.findById(currentUser.id())
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }
}

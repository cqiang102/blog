package com.caoqiang.blog.user.application.api;

import com.caoqiang.blog.user.domain.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserOverviewService {

    private final UserRepository userRepository;

    public UserOverviewService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public long countUsers() {
        return userRepository.count();
    }
}

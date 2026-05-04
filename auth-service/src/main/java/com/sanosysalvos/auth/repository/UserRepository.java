package com.sanosysalvos.auth.repository;

import com.sanosysalvos.auth.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    Optional<User> findByVerificationToken(String token);

    @Modifying
    @Query("UPDATE User u SET u.failedAttempts = u.failedAttempts + 1 WHERE u.id = :id")
    void incrementFailedAttempts(UUID id);

    @Modifying
    @Query("UPDATE User u SET u.failedAttempts = 0 WHERE u.id = :id")
    void resetFailedAttempts(UUID id);

    @Modifying
    @Query("UPDATE User u SET u.isLocked = true WHERE u.id = :id")
    void lockAccount(UUID id);
}

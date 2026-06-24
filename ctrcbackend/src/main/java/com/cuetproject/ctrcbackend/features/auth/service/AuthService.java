package com.cuetproject.ctrcbackend.features.auth.service;

import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.cuetproject.ctrcbackend.exception.DuplicateResourceException;
import com.cuetproject.ctrcbackend.exception.ResourceNotFoundException;
import com.cuetproject.ctrcbackend.exception.UnauthorizedException;
import com.cuetproject.ctrcbackend.exception.ValidationException;
import com.cuetproject.ctrcbackend.features.auth.dto.AuthResponse;
import com.cuetproject.ctrcbackend.features.auth.dto.LoginRequest;
import com.cuetproject.ctrcbackend.features.auth.dto.SignUpRequest;
import com.cuetproject.ctrcbackend.features.auth.dto.UserResponse;
import com.cuetproject.ctrcbackend.features.auth.model.User;
import com.cuetproject.ctrcbackend.features.auth.repository.UserRepository;

import lombok.extern.slf4j.Slf4j;

/**
 * Authentication Service
 *
 * This service contains business logic for authentication and user management.
 *
 * Key responsibilities: - User registration (signup) - User login - Password
 * validation - Email uniqueness checks - Token generation (would be JWT in real
 * app)
 *
 * Transaction Management:
 *
 * @Transactional annotations ensure database operations are atomic. - REQUIRED
 * (default): Use existing transaction or create new one - REQUIRES_NEW: Always
 * create a new transaction - ISOLATION_READ_COMMITTED: Default isolation level
 *
 * Why transactions matter: - If signup fails halfway, user is not saved to
 * database - Ensures data consistency across multiple operations - Handles
 * deadlocks and concurrent access safely
 */
@Slf4j
@Service
public class AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    /**
     * User Registration (Sign Up)
     *
     * Process: 1. Validate request data (email format, password length, etc.)
     * 2. Check if email already exists 3. Validate password confirmation 4.
     * Hash password using BCrypt 5. Save user to database 6. Return
     * AuthResponse with token and user details
     *
     * @Transactional ensures the entire operation is atomic: If any step fails,
     * the entire transaction is rolled back
     *
     * @param request SignUpRequest with name, email, password
     * @return AuthResponse with JWT token and user details
     * @throws DuplicateResourceException if email already exists
     * @throws ValidationException if validation fails
     */
    @Transactional(
            propagation = Propagation.REQUIRED,
            isolation = Isolation.READ_COMMITTED,
            rollbackFor = Exception.class
    )
    public AuthResponse signup(SignUpRequest request) {
        log.info("Processing signup for email: {}", request.getEmail());

        // Validate passwords match
        if (!request.getPassword().equals(request.getConfirmPassword())) {
            throw new ValidationException("confirmPassword", "Passwords do not match");
        }

        // Check if email already exists
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new DuplicateResourceException("User", "email", request.getEmail());
        }

        try {
            // Create new user object with address and image_url automatically set to null
            User user = User.builder()
                    .user_id(java.util.UUID.randomUUID().toString()) // Generate unique UUID
                    .name(request.getName())
                    .email(request.getEmail())
                    .password(passwordEncoder.encode(request.getPassword())) // Hash password
                    .address(null) // auto null during signup
                    .image_url(null) // auto null during signup
                    .build();

            // Save to database (JDBC)
            User savedUser = userRepository.save(user);
            log.info("User registered successfully with id: {}", savedUser.getUser_id());

            // Generate token (simplified - in production, use JWT)
            String token = generateToken(savedUser.getUser_id());

            // Return response
            return AuthResponse.builder()
                    .token(token)
                    .tokenType("Bearer")
                    .expiresIn(86400000L) // 24 hours in milliseconds
                    .user(UserResponse.fromUser(savedUser))
                    .message("User registered successfully")
                    .build();

        } catch (Exception e) {
            log.error("Error during signup for email: {}", request.getEmail(), e);
            throw new RuntimeException("Failed to register user: " + e.getMessage(), e);
        }
    }

    /**
     * User Login (Sign In)
     *
     * Process: 1. Find user by email 2. Verify password matches hashed password
     * in database 3. Check if user is active 4. Generate token 5. Return
     * AuthResponse
     *
     * @param request LoginRequest with email and password
     * @return AuthResponse with JWT token and user details
     * @throws ResourceNotFoundException if user not found
     * @throws UnauthorizedException if password is incorrect
     */
    @Transactional(readOnly = true) // Read-only transaction for login
    public AuthResponse login(LoginRequest request) {
        log.info("Processing login for email: {}", request.getEmail());

        try {
            // Find user by email
            Optional<User> userOptional = userRepository.findByEmail(request.getEmail());
            User user = userOptional.orElseThrow(()
                    -> new ResourceNotFoundException("User", "email", request.getEmail())
            );

            // Verify password
            if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
                log.warn("Invalid password attempt for email: {}", request.getEmail());
                throw new UnauthorizedException("Invalid email or password");
            }

            log.info("User logged in successfully: {}", request.getEmail());

            // Generate token
            String token = generateToken(user.getUser_id());

            // Return response
            return AuthResponse.builder()
                    .token(token)
                    .tokenType("Bearer")
                    .expiresIn(86400000L) // 24 hours in milliseconds
                    .user(UserResponse.fromUser(user))
                    .message("Login successful")
                    .build();

        } catch (ResourceNotFoundException | UnauthorizedException e) {
            throw e;
        } catch (Exception e) {
            log.error("Error during login for email: {}", request.getEmail(), e);
            throw new RuntimeException("Failed to login: " + e.getMessage(), e);
        }
    }

    /**
     * Get user by ID
     *
     * @param userId User ID
     * @return UserResponse with user details (password excluded)
     * @throws ResourceNotFoundException if user not found
     */
    @Transactional(readOnly = true)
    public UserResponse getUserById(String userId) {
        log.info("Fetching user by id: {}", userId);

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", userId));

        return UserResponse.fromUser(user);
    }

    /**
     * Change user password
     *
     * Process: 1. Find user 2. Verify old password matches 3. Validate new
     * password != old password 4. Hash and save new password
     *
     * @param userId User ID
     * @param oldPassword Current password
     * @param newPassword New password
     * @throws ResourceNotFoundException if user not found
     * @throws UnauthorizedException if old password is incorrect
     * @throws ValidationException if validation fails
     */
    @Transactional(
            propagation = Propagation.REQUIRED,
            isolation = Isolation.SERIALIZABLE // Highest isolation for security operation
    )
    public void changePassword(String userId, String oldPassword, String newPassword) {
        log.info("Attempting password change for user: {}", userId);

        // Find user
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", userId));

        // Verify old password
        if (!passwordEncoder.matches(oldPassword, user.getPassword())) {
            throw new UnauthorizedException("Old password is incorrect");
        }

        // Validate new password != old password
        if (oldPassword.equals(newPassword)) {
            throw new ValidationException("newPassword", "New password must be different from old password");
        }

        // Hash and save new password
        String hashedPassword = passwordEncoder.encode(newPassword);
        userRepository.updatePassword(userId, hashedPassword);

        log.info("Password changed successfully for user: {}", userId);
    }

    /**
     * Update user profile
     *
     * @param userId User ID
     * @param user User object with updated data
     * @return Updated UserResponse
     * @throws ResourceNotFoundException if user not found
     */
    @Transactional
    public UserResponse updateProfile(String userId, User user) {
        log.info("Updating profile for user: {}", userId);

        // Verify user exists
        User existingUser = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", userId));

        // Update only non-null fields
        if (user.getName() != null) {
            existingUser.setName(user.getName());
        }
        if (user.getAddress() != null) {
            existingUser.setAddress(user.getAddress());
        }
        if (user.getImage_url() != null) {
            existingUser.setImage_url(user.getImage_url());
        }

        userRepository.update(existingUser);

        log.info("Profile updated successfully for user: {}", userId);
        return UserResponse.fromUser(existingUser);
    }

    /**
     * Delete user account
     *
     * @param userId User ID
     * @throws ResourceNotFoundException if user not found
     */
    @Transactional
    public void deleteAccount(String userId) {
        log.info("Deleting account for user: {}", userId);

        // Verify user exists
        userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", userId));

        // Hard delete
        userRepository.deleteById(userId);

        log.info("Account deleted for user: {}", userId);
    }

    /**
     * Simplified token generation In production, use JWT with expiration,
     * signing key, and claims
     *
     * This is a placeholder for JWT token generation Real implementation would
     * use libraries like jjwt or java-jwt
     *
     * @param userId User ID
     * @return Token string
     */
    private String generateToken(String userId) {
        // Placeholder token generation
        // In production, implement proper JWT token generation
        return "token_" + userId + "_" + System.currentTimeMillis();
    }
}

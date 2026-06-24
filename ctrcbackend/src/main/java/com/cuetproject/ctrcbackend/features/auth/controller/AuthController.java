package com.cuetproject.ctrcbackend.features.auth.controller;

import com.cuetproject.ctrcbackend.features.auth.dto.AuthResponse;
import com.cuetproject.ctrcbackend.features.auth.dto.LoginRequest;
import com.cuetproject.ctrcbackend.features.auth.dto.UserResponse;
import com.cuetproject.ctrcbackend.features.auth.service.AuthService;

import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.cuetproject.ctrcbackend.features.auth.dto.SignUpRequest;

/**
 * Authentication Controller
 *
 * REST API endpoints for authentication and user management.
 *
 * Base URL: /api/auth
 *
 * All endpoints use proper HTTP methods and status codes: - POST: Create new
 * resource (signup, login) - GET: Retrieve resource - PUT/PATCH: Update
 * resource - DELETE: Delete resource
 *
 * Status codes: - 200 OK: Successful GET, PUT, PATCH - 201 CREATED: Successful
 * POST - 400 BAD REQUEST: Validation failed - 401 UNAUTHORIZED: Authentication
 * failed - 404 NOT FOUND: Resource not found - 409 CONFLICT: Resource already
 * exists - 500 INTERNAL SERVER ERROR: Server error
 *
 * Request validation:
 *
 * @Valid annotation triggers validation of request DTOs Validation errors are
 * caught by GlobalExceptionHandler
 */
@Slf4j
@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*", maxAge = 3600) // Allow CORS for Flutter frontend
public class AuthController {

    @Autowired
    private AuthService authService;

    /**
     * POST /api/auth/signup Register a new user
     *
     * Request body: { "name": "John Doe", "email": "john@example.com",
     * "password": "password123", "confirmPassword": "password123", "age": 25 }
     *
     * Success response (201 CREATED): { "token": "token_123_456789",
     * "tokenType": "Bearer", "expiresIn": 86400000, "user": { "id": 1, "name":
     * "John Doe", "email": "john@example.com", "age": 25, "status": "ACTIVE",
     * "createdAt": "2026-06-06T16:41:00", "updatedAt": "2026-06-06T16:41:00" },
     * "message": "User registered successfully" }
     *
     * Error responses: - 400 BAD REQUEST: Validation failed - 409 CONFLICT:
     * Email already exists
     *
     * @param request SignUpRequest with validation annotations
     * @return AuthResponse with token and user details
     */
    @PostMapping("/signup")
    public ResponseEntity<AuthResponse> signup(@Valid @RequestBody SignUpRequest request) {
        log.info("Signup request received for email: {}", request.getEmail());

        AuthResponse response = authService.signup(request);

        log.info("Signup successful for email: {}", request.getEmail());
        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }

    /**
     * POST /api/auth/login Authenticate user and return JWT token
     *
     * Request body: { "email": "john@example.com", "password": "password123" }
     *
     * Success response (200 OK): { "token": "token_123_456789", "tokenType":
     * "Bearer", "expiresIn": 86400000, "user": { "id": 1, "name": "John Doe",
     * "email": "john@example.com", "age": 25, "status": "ACTIVE", "createdAt":
     * "2026-06-06T16:41:00", "updatedAt": "2026-06-06T16:41:00" }, "message":
     * "Login successful" }
     *
     * Error responses: - 400 BAD REQUEST: Validation failed - 401 UNAUTHORIZED:
     * Invalid credentials or inactive account - 404 NOT FOUND: User not found
     *
     * @param request LoginRequest with email and password
     * @return AuthResponse with token and user details
     */
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        log.info("Login request received for email: {}", request.getEmail());

        AuthResponse response = authService.login(request);

        log.info("Login successful for email: {}", request.getEmail());
        return ResponseEntity.ok(response);
    }

    /**
     * GET /api/auth/user/{userId} Get user profile by ID
     *
     * @param userId User ID
     * @return UserResponse with user details (without password)
     */
    @GetMapping("/user/{userId}")
    public ResponseEntity<UserResponse> getUserById(@PathVariable String userId) {
        log.info("Fetching user profile for userId: {}", userId);

        UserResponse response = authService.getUserById(userId);

        return ResponseEntity.ok(response);
    }

    /**
     * POST /api/auth/change-password Change user password
     *
     * Request body: { "userId": 1, "oldPassword": "oldPassword123",
     * "newPassword": "newPassword456" }
     *
     * @param userId User ID
     * @param oldPassword Current password
     * @param newPassword New password
     * @return Success message
     */
    @PostMapping("/change-password")
    public ResponseEntity<?> changePassword(
            @RequestParam String userId,
            @RequestParam String oldPassword,
            @RequestParam String newPassword) {

        log.info("Change password request for userId: {}", userId);

        authService.changePassword(userId, oldPassword, newPassword);

        return ResponseEntity.ok(new AuthResponse(
                null, null, null, null, "Password changed successfully"
        ));
    }

    /**
     * POST /api/auth/delete-account Delete user account (soft delete)
     *
     * @param userId User ID
     * @return Success message
     */
    @PostMapping("/delete-account")
    public ResponseEntity<?> deleteAccount(@RequestParam String userId) {
        log.info("Delete account request for userId: {}", userId);

        authService.deleteAccount(userId);

        return ResponseEntity.ok(new AuthResponse(
                null, null, null, null, "Account deleted successfully"
        ));
    }

    /**
     * GET /api/auth/health Health check endpoint Useful for monitoring if the
     * service is running
     *
     * @return Simple health check message
     */
    @GetMapping("/health")
    public ResponseEntity<?> healthCheck() {
        return ResponseEntity.ok(new AuthResponse(
                null, null, null, null, "Auth service is running"
        ));
    }
}

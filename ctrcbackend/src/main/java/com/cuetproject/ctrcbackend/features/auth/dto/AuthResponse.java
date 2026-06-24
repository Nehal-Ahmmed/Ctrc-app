package com.cuetproject.ctrcbackend.features.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

/**
 * Authentication Response DTO
 * 
 * This DTO is sent back to the frontend after successful login/signup.
 * It includes:
 * - JWT token for subsequent API calls
 * - User details (without password)
 * - Token type and expiration
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuthResponse {
    
    /**
     * JWT access token for API authentication
     * Frontend should include this in Authorization header: "Bearer {token}"
     */
    private String token;
    
    /**
     * Type of token (usually "Bearer")
     */
    private String tokenType;
    
    /**
     * Token expiration time in milliseconds from now
     */
    private Long expiresIn;
    
    /**
     * User information (without password for security)
     */
    private UserResponse user;
    
    /**
     * Success message
     */
    private String message;
}

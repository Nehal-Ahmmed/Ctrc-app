package com.cuetproject.ctrcbackend.features.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

/**
 * User Response DTO
 * 
 * This DTO is used to send user information to the frontend.
 * It NEVER includes the password field for security reasons.
 * 
 * Use this DTO in all API responses that need to return user data.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserResponse {
    
    /**
     * User's unique identifier
     */
    private String user_id;
    
    /**
     * User's email address
     */
    private String email;
    
    /**
     * User's full name
     */
    private String name;
    
    /**
     * User's profile image URL (optional)
     */
    private String image_url;
    
    /**
     * User's address
     */
    private String address;
    
    /**
     * Static method to convert User model to UserResponse
     * This ensures we never accidentally expose the password
     */
    public static UserResponse fromUser(com.cuetproject.ctrcbackend.features.auth.model.User user) {
        return UserResponse.builder()
                .user_id(user.getUser_id())
                .email(user.getEmail())
                .name(user.getName())
                .image_url(user.getImage_url())
                .address(user.getAddress())
                .build();
    }
}

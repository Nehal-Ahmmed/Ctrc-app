package com.cuetproject.ctrcbackend.features.auth.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * User Model - Plain Java POJO (NOT a JPA Entity)
 * 
 * This class represents a user in the system.
 * It uses Lombok annotations to reduce boilerplate code.
 * 
 * NO JPA annotations like @Entity, @Table, @Id, @Column are used.
 * This is raw SQL territory - we control everything!
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User {
    
    /**
     * Unique user identifier
     */
    private String user_id;
    
    /**
     * User's email address (UNIQUE constraint in database)
     */
    private String email;
    
    /**
     * User's full name
     */
    private String name;
    
    /**
     * User's password (hashed using BCrypt in service layer)
     * Never expose this to frontend!
     */
    private String password;
    
    /**
     * User's profile image URL (optional)
     */
    private String image_url;
    
    /**
     * User's address
     */
    private String address;
}

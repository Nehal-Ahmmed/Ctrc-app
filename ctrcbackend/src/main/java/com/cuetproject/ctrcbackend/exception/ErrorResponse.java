package com.cuetproject.ctrcbackend.exception;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * ErrorResponse DTO
 * 
 * Standardized error response format sent to clients.
 * All API errors use this structure for consistency.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ErrorResponse {
    
    /**
     * Timestamp when the error occurred
     */
    private LocalDateTime timestamp;
    
    /**
     * HTTP status code (e.g., 404, 400, 500)
     */
    private int status;
    
    /**
     * Short error code/name (e.g., "Not Found", "Validation Error")
     */
    private String error;
    
    /**
     * Detailed error message for the client
     */
    private String message;
    
    /**
     * API path that caused the error
     */
    private String path;
    
    /**
     * Validation errors per field (only for validation errors)
     * Example: {"email": "Email already exists", "password": "Too short"}
     */
    private Map<String, String> validationErrors;
}

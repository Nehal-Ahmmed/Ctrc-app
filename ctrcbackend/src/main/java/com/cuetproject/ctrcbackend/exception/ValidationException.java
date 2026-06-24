package com.cuetproject.ctrcbackend.exception;

/**
 * ValidationException
 * 
 * Thrown when business logic validation fails.
 * For example: passwords don't match, invalid password format, etc.
 * Results in HTTP 400 Bad Request
 */
public class ValidationException extends RuntimeException {
    
    private String field;
    
    public ValidationException(String message) {
        super(message);
    }
    
    public ValidationException(String field, String message) {
        super(message);
        this.field = field;
    }
    
    public String getField() {
        return field;
    }
}

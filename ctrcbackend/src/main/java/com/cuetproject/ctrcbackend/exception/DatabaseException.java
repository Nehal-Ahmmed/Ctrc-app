package com.cuetproject.ctrcbackend.exception;

/**
 * DatabaseException
 * 
 * Thrown when a database operation fails.
 * Wraps SQLException and other database-related exceptions.
 * Results in HTTP 500 Internal Server Error
 */
public class DatabaseException extends RuntimeException {
    
    public DatabaseException(String message) {
        super(message);
    }
    
    public DatabaseException(String message, Throwable cause) {
        super(message, cause);
    }
}

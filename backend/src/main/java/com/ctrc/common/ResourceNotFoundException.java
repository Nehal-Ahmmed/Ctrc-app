package com.ctrc.common;

// thrown when a requested resource does not exist, e.g. report id not found
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String message) {
        super(message);
    }
}

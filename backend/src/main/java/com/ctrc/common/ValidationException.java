package com.ctrc.common;

// thrown when input data fails business validation, e.g. duplicate email
public class ValidationException extends RuntimeException {

    public ValidationException(String message) {
        super(message);
    }
}

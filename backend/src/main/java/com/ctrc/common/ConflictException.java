package com.ctrc.common;

// thrown when a request conflicts with existing state, e.g. duplicate vote
public class ConflictException extends RuntimeException {

    public ConflictException(String message) {
        super(message);
    }
}

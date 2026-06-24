package com.cuetproject.ctrcbackend;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class UserControllerTest {

    @GetMapping("/home")
    Map<String, String> home() {
        return Map.of("message", "Welcome to CTRC");
    }
}

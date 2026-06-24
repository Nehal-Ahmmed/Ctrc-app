package com.cuetproject.ctrcbackend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Security Configuration
 * 
 * This class provides Bean configurations for security-related components.
 * 
 * PasswordEncoder:
 * - BCryptPasswordEncoder: Industry standard for password hashing
 * - Never stores passwords in plain text
 * - Uses adaptive hashing with salt
 * - Strength parameter determines computation cost (10-12 recommended)
 * 
 * Why BCrypt?
 * - Intentionally slow to resist brute force attacks
 * - Includes automatic salt generation
 * - Salted password hashing prevents rainbow table attacks
 * 
 * How it works:
 * 1. Raw password: "password123"
 * 2. BCrypt hashing: "$2a$10$hash......" (includes salt + hash)
 * 3. Storage: Store only the hashed version in database
 * 4. Verification: BCrypt.matches(rawPassword, hashedPassword)
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    /**
     * Security Filter Chain
     *
     * Permits:
     * - /home            → test endpoint (public)
     * - /api/auth/**     → signup & login (public)
     * - /actuator/**     → health checks (public)
     *
     * Everything else requires authentication.
     */
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable) // Disable CSRF for REST API
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/home", "/api/auth/**", "/actuator/**").permitAll()
                .anyRequest().authenticated()
            );
        return http.build();
    }

    /**
     * Password Encoder Bean
     *
     * BCryptPasswordEncoder strength = 10 means:
     * - 2^10 = 1024 iterations
     * - Each password hash takes ~200ms to compute
     * - Increases exponentially if attacker tries brute force
     *
     * @return PasswordEncoder bean configured with BCrypt
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(10);
    }
}

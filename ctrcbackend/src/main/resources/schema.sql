/**
 * CTRC Database Schema
 * 
 * This file contains all SQL statements required to set up the database.
 * Execute this script in MySQL Workbench to create the database and tables.
 * 
 * Database: ctrc_db
 * Encoding: UTF-8
 * 
 * Concepts demonstrated:
 * - AUTO_INCREMENT: Automatic ID generation
 * - UNIQUE constraint: Ensures email uniqueness
 * - INDEX: Improves query performance
 * - FOREIGN KEY: Maintains referential integrity
 * - TIMESTAMP: Automatic date-time handling
 */

-- ==========================================
-- CREATE DATABASE
-- ==========================================

CREATE DATABASE IF NOT EXISTS ctrcdb
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE ctrcdb;

-- ==========================================
-- USERS TABLE
-- ==========================================

/**
 * Users Table
 * 
 * Stores user account information.
 * 
 * Important columns:
 * - user_id: Primary key (UUID string)
 * - email: UNIQUE - ensures no duplicate emails
 * - password: Stores hashed password (BCrypt)
 * - image_url: Profile photo URL (optional)
 * - address: User's physical address
 */
CREATE TABLE IF NOT EXISTS users (
    user_id VARCHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID primary key',
    
    email VARCHAR(100) NOT NULL UNIQUE COMMENT 'User email (UNIQUE constraint)',
    
    name VARCHAR(100) NOT NULL COMMENT 'User full name',
    
    password VARCHAR(255) NOT NULL COMMENT 'Hashed password using BCrypt',
    
    image_url VARCHAR(500) COMMENT 'Profile image URL',
    
    address VARCHAR(255) COMMENT 'User address',
    
    INDEX idx_email (email) COMMENT 'Index on email for faster lookups'
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='User accounts table - no JPA, raw SQL only';

-- ==========================================
-- CREATE INDEXES
-- ==========================================

/**
 * Indexes improve query performance by creating a sorted data structure.
 * 
 * Without index: SELECT query scans ALL rows (Full Table Scan)
 * With index: SELECT query uses B-tree structure (much faster)
 * 
 * Tradeoff:
 * - Pro: Faster SELECT queries
 * - Con: Slower INSERT/UPDATE/DELETE (index must also be updated)
 * 
 * Best practice: Index on frequently queried columns
 */

-- Already created with table definition above, but showing the concept:
-- CREATE INDEX idx_email ON users(email);
-- CREATE INDEX idx_status ON users(status);
-- CREATE INDEX idx_created_at ON users(created_at);

-- ==========================================
-- SAMPLE DATA (For Testing)
-- ==========================================

/**
 * Sample test data with pre-hashed passwords
 * 
 * Password hashing explained:
 * - Plain password: "password123"
 * - BCrypt hash: $2a$10$... (includes salt + iterations count)
 * - Never store plain passwords!
 * 
 * These are example BCrypt hashes. Generate your own using:
 * - Online tool: https://bcrypt-generator.com/ (NOT for production!)
 * - Java: BCryptPasswordEncoder.encode("password123")
 * 
 * IMPORTANT: These hashes are for testing only!
 * Never use example passwords in production!
 */

-- Delete existing test data (optional)
-- TRUNCATE TABLE users;

-- Insert sample users for testing
-- Password: "password123" (hashed)
-- user_id uses UUID format for String-based primary keys
INSERT INTO users (user_id, name, email, password, image_url, address) 
VALUES 
  (UUID(), 'John Doe', 'john@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/KFm', NULL, '123 Main Street'),
  (UUID(), 'Jane Smith', 'jane@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/KFm', NULL, '456 Oak Avenue'),
  (UUID(), 'Bob Wilson', 'bob@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/KFm', NULL, '789 Pine Road');

-- ==========================================
-- VERIFY DATA
-- ==========================================

/**
 * Verify the table was created correctly and contains data
 * Execute these queries to verify:
 */

-- Check table structure
-- DESCRIBE users;

-- Count total users
-- SELECT COUNT(*) as total_users FROM users;

-- List all users
-- SELECT id, name, email, age, status, created_at FROM users ORDER BY created_at DESC;

-- Find user by email
-- SELECT * FROM users WHERE email = 'john@example.com';

-- ==========================================
-- PERFORMANCE INSIGHTS
-- ==========================================

/**
 * Query Performance Explained:
 * 
 * 1. Full Table Scan (SLOW):
 *    SELECT * FROM users WHERE email = 'john@example.com';
 *    Without index, this scans ALL rows
 *    Time complexity: O(n)
 * 
 * 2. Index Scan (FAST):
 *    With index on email, uses B-tree lookup
 *    Time complexity: O(log n)
 *    Result: 100x-1000x faster on large tables!
 * 
 * 3. Checking Query Execution Plan:
 *    EXPLAIN SELECT * FROM users WHERE email = 'john@example.com';
 *    Shows: rows examined, type (range/index/etc)
 */

-- ==========================================
-- BACKUP STRATEGY
-- ==========================================

/**
 * Backup this database regularly:
 * 
 * Using MySQL Workbench:
 * 1. Right-click database -> Export Dump
 * 2. Select schema and data options
 * 3. Save as SQL file
 * 
 * Using command line:
 * mysqldump -u root -p ctrc_db > ctrc_db_backup.sql
 * 
 * Restore from backup:
 * mysql -u root -p ctrc_db < ctrc_db_backup.sql
 */

-- ==========================================
-- END OF SCHEMA
-- ==========================================

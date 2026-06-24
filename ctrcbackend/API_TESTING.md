# API Testing Guide

## Quick Start - Test All Endpoints

### Prerequisites
- Application running on http://localhost:8080
- MySQL database with schema initialized
- Postman installed (or use curl commands below)

---

## Using Postman (Recommended)

### 1. Create New Request

In Postman:
1. Click "New" → "Request"
2. Give it a name (e.g., "Signup")
3. Select method (POST, GET, etc.)
4. Enter URL
5. Select "Body" tab
6. Choose "raw" and select "JSON"
7. Paste request body
8. Click "Send"

---

## Using cURL (Command Line)

### On Windows PowerShell

```powershell
$body = @{
    name = "Test User"
    email = "test@example.com"
    password = "password123"
    confirmPassword = "password123"
    age = 25
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:8080/api/auth/signup" `
    -Method POST `
    -Headers @{"Content-Type" = "application/json"} `
    -Body $body
```

---

## Test Cases

### Test 1: Health Check

**Endpoint**: GET /api/auth/health

**Purpose**: Verify backend is running

**Postman**:
- Method: GET
- URL: http://localhost:8080/api/auth/health

**cURL**:
```bash
curl http://localhost:8080/api/auth/health
```

**Expected Response** (200 OK):
```json
{
  "message": "Auth service is running"
}
```

---

### Test 2: Signup - Success Case

**Endpoint**: POST /api/auth/signup

**Purpose**: Register a new user

**Postman**:
- Method: POST
- URL: http://localhost:8080/api/auth/signup
- Body (JSON):
```json
{
  "name": "Alice Johnson",
  "email": "alice@example.com",
  "password": "SecurePass123",
  "confirmPassword": "SecurePass123",
  "age": 28
}
```

**cURL**:
```bash
curl -X POST http://localhost:8080/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "password": "SecurePass123",
    "confirmPassword": "SecurePass123",
    "age": 28
  }'
```

**Expected Response** (201 CREATED):
```json
{
  "token": "token_4_1717681500000",
  "tokenType": "Bearer",
  "expiresIn": 86400000,
  "user": {
    "id": 4,
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "age": 28,
    "photoUrl": null,
    "status": "ACTIVE",
    "createdAt": "2026-06-06T16:45:00",
    "updatedAt": "2026-06-06T16:45:00"
  },
  "message": "User registered successfully"
}
```

---

### Test 3: Signup - Validation Error (Missing Required Field)

**Purpose**: Test request validation

**Body**:
```json
{
  "name": "Bob",
  "email": "invalid-email",
  "password": "short",
  "confirmPassword": "short",
  "age": 10
}
```

**Expected Response** (400 BAD REQUEST):
```json
{
  "timestamp": "2026-06-06T16:45:00",
  "status": 400,
  "error": "Validation Error",
  "message": "Request validation failed",
  "validationErrors": {
    "email": "Email should be valid",
    "password": "Password must be between 6 and 100 characters",
    "age": "Age must be at least 13"
  },
  "path": "/api/auth/signup"
}
```

---

### Test 4: Signup - Duplicate Email (409 Conflict)

**Purpose**: Test duplicate email handling

**Body** (use email from previous signup):
```json
{
  "name": "Another User",
  "email": "alice@example.com",
  "password": "password123",
  "confirmPassword": "password123",
  "age": 30
}
```

**Expected Response** (409 CONFLICT):
```json
{
  "timestamp": "2026-06-06T16:45:00",
  "status": 409,
  "error": "Conflict",
  "message": "User already exists with email: alice@example.com",
  "path": "/api/auth/signup"
}
```

---

### Test 5: Signup - Password Mismatch

**Purpose**: Test password validation

**Body**:
```json
{
  "name": "Charlie Brown",
  "email": "charlie@example.com",
  "password": "password123",
  "confirmPassword": "different456",
  "age": 25
}
```

**Expected Response** (400 BAD REQUEST):
```json
{
  "timestamp": "2026-06-06T16:45:00",
  "status": 400,
  "error": "Validation Error",
  "message": "Passwords do not match",
  "path": "/api/auth/signup"
}
```

---

### Test 6: Login - Success Case

**Endpoint**: POST /api/auth/login

**Purpose**: Authenticate user and get token

**Body**:
```json
{
  "email": "alice@example.com",
  "password": "SecurePass123"
}
```

**Expected Response** (200 OK):
```json
{
  "token": "token_4_1717681600000",
  "tokenType": "Bearer",
  "expiresIn": 86400000,
  "user": {
    "id": 4,
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "age": 28,
    "photoUrl": null,
    "status": "ACTIVE",
    "createdAt": "2026-06-06T16:45:00",
    "updatedAt": "2026-06-06T16:45:00"
  },
  "message": "Login successful"
}
```

---

### Test 7: Login - Invalid Password

**Purpose**: Test authentication failure

**Body**:
```json
{
  "email": "alice@example.com",
  "password": "WrongPassword"
}
```

**Expected Response** (401 UNAUTHORIZED):
```json
{
  "timestamp": "2026-06-06T16:45:00",
  "status": 401,
  "error": "Unauthorized",
  "message": "Invalid email or password",
  "path": "/api/auth/login"
}
```

---

### Test 8: Login - User Not Found

**Purpose**: Test error handling for non-existent user

**Body**:
```json
{
  "email": "nonexistent@example.com",
  "password": "password123"
}
```

**Expected Response** (404 NOT FOUND):
```json
{
  "timestamp": "2026-06-06T16:45:00",
  "status": 404,
  "error": "Not Found",
  "message": "User not found with email: nonexistent@example.com",
  "path": "/api/auth/login"
}
```

---

### Test 9: Get User Profile

**Endpoint**: GET /api/auth/user/{userId}

**Purpose**: Fetch user details

**URL**: http://localhost:8080/api/auth/user/4

**Expected Response** (200 OK):
```json
{
  "id": 4,
  "name": "Alice Johnson",
  "email": "alice@example.com",
  "age": 28,
  "photoUrl": null,
  "status": "ACTIVE",
  "createdAt": "2026-06-06T16:45:00",
  "updatedAt": "2026-06-06T16:45:00"
}
```

---

### Test 10: Get Non-Existent User

**URL**: http://localhost:8080/api/auth/user/999

**Expected Response** (404 NOT FOUND):
```json
{
  "timestamp": "2026-06-06T16:45:00",
  "status": 404,
  "error": "Not Found",
  "message": "User not found with id: 999",
  "path": "/api/auth/user/999"
}
```

---

## Database Verification

### Check Data in MySQL Workbench

1. Open MySQL Workbench
2. Connect to your MySQL server
3. Expand `ctrc_db` → Tables → `users`
4. Right-click → "Select Rows - Limit 1000"
5. You should see all created users

### Verify User Was Created

```sql
-- Query to verify signup worked
SELECT id, name, email, status, created_at FROM users 
WHERE email = 'alice@example.com';

-- Verify password was hashed (not plain text)
SELECT id, email, password FROM users WHERE email = 'alice@example.com';
-- Password should look like: $2a$10$... (BCrypt hash)
```

---

## Test Scenarios Workflow

### Scenario 1: Complete User Journey

1. ✅ Signup with new email
2. ✅ Verify user in database
3. ✅ Login with correct password
4. ✅ Get user profile
5. ✅ Verify token is returned

### Scenario 2: Error Handling

1. ✅ Try signup with invalid email (should fail validation)
2. ✅ Try signup with short password (should fail validation)
3. ✅ Try signup with mismatched passwords (should fail)
4. ✅ Try signup with duplicate email (should fail with 409)
5. ✅ Try login with wrong password (should fail with 401)
6. ✅ Try get user with invalid ID (should fail with 404)

### Scenario 3: Database Consistency

1. ✅ Insert 3 new users via API
2. ✅ Verify all 3 appear in database
3. ✅ Verify timestamps are set correctly
4. ✅ Verify passwords are hashed (BCrypt)
5. ✅ Verify status is "ACTIVE" by default

---

## Common Issues & Solutions

### Issue: "Connection refused"
- Ensure MySQL is running
- Ensure application is running on port 8080

### Issue: 400 Bad Request with validation errors
- Check all required fields are provided
- Check field formats match requirements
- Check password confirmation matches password

### Issue: 409 Conflict (Email exists)
- Use a unique email for testing
- Or delete the existing user from database

### Issue: 401 Unauthorized (Wrong password)
- Verify you're entering the same password used during signup
- Remember passwords are case-sensitive

### Issue: 404 Not Found (User doesn't exist)
- Verify the user ID exists in database
- Check if you're using the correct user ID from signup response

---

## Performance Testing

### Load Test with Multiple Users

Create 100 users quickly:

```bash
# PowerShell script to create 100 users
for ($i = 1; $i -le 100; $i++) {
    $body = @{
        name = "User $i"
        email = "user$i@example.com"
        password = "password123"
        confirmPassword = "password123"
        age = 20 + $i % 50
    } | ConvertTo-Json
    
    Invoke-WebRequest -Uri "http://localhost:8080/api/auth/signup" `
        -Method POST `
        -Headers @{"Content-Type" = "application/json"} `
        -Body $body -ErrorAction SilentlyContinue
}
```

Then verify in database:
```sql
SELECT COUNT(*) as total_users FROM users;
```

---

## API Response Codes Reference

| Status | Meaning | Example Scenario |
|--------|---------|------------------|
| **200** | OK | Login successful, Get user |
| **201** | Created | Signup successful |
| **400** | Bad Request | Invalid email format, password too short |
| **401** | Unauthorized | Wrong password, inactive account |
| **404** | Not Found | User doesn't exist |
| **409** | Conflict | Email already registered |
| **500** | Server Error | Database connection failed |

---

## Next Steps

- Implement JWT token validation
- Add API rate limiting
- Add user profile update endpoint
- Add password change endpoint
- Add user search/filtering
- Add pagination to user list endpoints
- Implement soft delete (status change instead of hard delete)
- Add audit logging for all operations

---

**Happy Testing!** 🧪

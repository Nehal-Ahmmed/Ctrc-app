package com.cuetproject.ctrcbackend.features.auth.repository;

import com.cuetproject.ctrcbackend.features.auth.model.User;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.sql.PreparedStatement;
import java.sql.Types;
import java.util.List;
import java.util.Optional;

@Repository
public class UserRepository {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private final RowMapper<User> userRowMapper = (rs, rowNum) -> User.builder()
            .user_id(rs.getString("user_id"))
            .email(rs.getString("email"))
            .name(rs.getString("name"))
            .password(rs.getString("password"))
            .image_url(rs.getString("image_url"))
            .address(rs.getString("address"))
            .build();

    public User save(User user) throws DataAccessException {
        String sql = "INSERT INTO users (user_id, email, name, password, image_url, address) VALUES (?, ?, ?, ?, ?, ?)";
        try {
            jdbcTemplate.update(connection -> {
                PreparedStatement ps = connection.prepareStatement(sql);
                ps.setString(1, user.getUser_id());
                ps.setString(2, user.getEmail());
                ps.setString(3, user.getName());
                ps.setString(4, user.getPassword());
                // Nullable: store SQL NULL if not provided
                if (user.getImage_url() != null) {
                    ps.setString(5, user.getImage_url());
                } else {
                    ps.setNull(5, Types.VARCHAR);
                }
                if (user.getAddress() != null) {
                    ps.setString(6, user.getAddress());
                } else {
                    ps.setNull(6, Types.VARCHAR);
                }
                return ps;
            });
            return user;
        } catch (DataAccessException e) {
            throw new DataAccessException("Failed to save user: " + e.getMessage(), e) {
            };
        }
    }

    public Optional<User> findById(String id) {
        String sql = "SELECT user_id, email, name, password, image_url, address FROM users WHERE user_id = ?";
        try {
            User user = jdbcTemplate.queryForObject(sql, userRowMapper, id);
            return Optional.ofNullable(user);
        } catch (EmptyResultDataAccessException e) {
            return Optional.empty();
        } catch (DataAccessException e) {
            throw new DataAccessException("Failed to find user by id: " + e.getMessage(), e) {
            };
        }
    }

    public Optional<User> findByEmail(String email) {
        String sql = "SELECT user_id, email, name, password, image_url, address FROM users WHERE email = ?";
        try {
            User user = jdbcTemplate.queryForObject(sql, userRowMapper, email);
            return Optional.ofNullable(user);
        } catch (EmptyResultDataAccessException e) {
            return Optional.empty();
        } catch (DataAccessException e) {
            throw new DataAccessException("Failed to find user by email: " + e.getMessage(), e) {
            };
        }
    }

    public List<User> findAll(int limit, int offset) {
        String sql = "SELECT user_id, email, name, password, image_url, address FROM users ORDER BY name ASC LIMIT ? OFFSET ?";
        try {
            return jdbcTemplate.query(sql, userRowMapper, limit, offset);
        } catch (DataAccessException e) {
            throw new DataAccessException("Failed to fetch all users: " + e.getMessage(), e) {
            };
        }
    }

    public long getTotalCount() {
        String sql = "SELECT COUNT(*) FROM users";
        try {
            Integer count = jdbcTemplate.queryForObject(sql, Integer.class);
            return count != null ? count : 0;
        } catch (DataAccessException e) {
            throw new DataAccessException("Failed to get user count: " + e.getMessage(), e) {
            };
        }
    }

    public int update(User user) {
        String sql = "UPDATE users SET name = ?, email = ?, image_url = ?, address = ? WHERE user_id = ?";
        try {
            return jdbcTemplate.update(sql,
                    user.getName(),
                    user.getEmail(),
                    user.getImage_url(),
                    user.getAddress(),
                    user.getUser_id()
            );
        } catch (DataAccessException e) {
            throw new DataAccessException("Failed to update user: " + e.getMessage(), e) {
            };
        }
    }

    public int updatePassword(String userId, String hashedPassword) {
        String sql = "UPDATE users SET password = ? WHERE user_id = ?";
        try {
            return jdbcTemplate.update(sql, hashedPassword, userId);
        } catch (DataAccessException e) {
            throw new DataAccessException("Failed to update password: " + e.getMessage(), e) {
            };
        }
    }

    public int deleteById(String id) {
        String sql = "DELETE FROM users WHERE user_id = ?";
        try {
            return jdbcTemplate.update(sql, id);
        } catch (DataAccessException e) {
            throw new DataAccessException("Failed to delete user: " + e.getMessage(), e) {
            };
        }
    }

    public boolean existsByEmail(String email) {
        String sql = "SELECT COUNT(*) FROM users WHERE email = ?";
        try {
            Integer count = jdbcTemplate.queryForObject(sql, Integer.class, email);
            return count != null && count > 0;
        } catch (DataAccessException e) {
            throw new DataAccessException("Failed to check if email exists: " + e.getMessage(), e) {
            };
        }
    }

    public List<User> searchByName(String searchTerm) {
        String sql = "SELECT user_id, email, name, password, image_url, address FROM users WHERE name LIKE ? ORDER BY name ASC";
        try {
            return jdbcTemplate.query(sql, userRowMapper, "%" + searchTerm + "%");
        } catch (DataAccessException e) {
            throw new DataAccessException("Failed to search users by name: " + e.getMessage(), e) {
            };
        }
    }

    public int[] batchInsert(List<User> users) {
        String sql = "INSERT INTO users (user_id, email, name, password, image_url, address) VALUES (?, ?, ?, ?, ?, ?)";
        try {
            int[] result = new int[users.size()];
            int index = 0;
            for (User user : users) {
                jdbcTemplate.update(connection -> {
                    PreparedStatement ps = connection.prepareStatement(sql);
                    ps.setString(1, user.getUser_id());
                    ps.setString(2, user.getEmail());
                    ps.setString(3, user.getName());
                    ps.setString(4, user.getPassword());
                    // Nullable: store SQL NULL if not provided
                    if (user.getImage_url() != null) {
                        ps.setString(5, user.getImage_url());
                    } else {
                        ps.setNull(5, Types.VARCHAR);
                    }
                    if (user.getAddress() != null) {
                        ps.setString(6, user.getAddress());
                    } else {
                        ps.setNull(6, Types.VARCHAR);
                    }
                    return ps;
                });
                result[index++] = 1;
            }
            return result;
        } catch (DataAccessException e) {
            throw new DataAccessException("Failed to batch insert users: " + e.getMessage(), e) {
            };
        }
    }
}

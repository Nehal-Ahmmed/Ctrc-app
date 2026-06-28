package com.ctrc.location;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.util.List;
import java.util.Optional;

@Repository
public class LocationDaoImpl implements LocationDao {

    private final JdbcTemplate jdbcTemplate;

    public LocationDaoImpl(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    private static final RowMapper<Location> ROW_MAPPER = (rs, rowNum) -> {
        Location location = new Location();
        location.setLocationId(rs.getLong("location_id"));
        location.setLongitude(rs.getDouble("longitude"));
        location.setLatitude(rs.getDouble("latitude"));
        location.setAddress(rs.getString("address"));
        location.setCity(rs.getString("city"));
        return location;
    };

    @Override
    public Long insert(Location location) {
        String sql = "insert into location (longitude, latitude, address, city) values (?, ?, ?, ?)";
        KeyHolder keyHolder = new GeneratedKeyHolder();

        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            ps.setDouble(1, location.getLongitude());
            ps.setDouble(2, location.getLatitude());
            ps.setString(3, location.getAddress());
            ps.setString(4, location.getCity());
            return ps;
        }, keyHolder);

        return keyHolder.getKey().longValue();
    }

    @Override
    public Optional<Location> findById(Long locationId) {
        String sql = "select * from location where location_id = ?";
        List<Location> results = jdbcTemplate.query(sql, ROW_MAPPER, locationId);
        return results.isEmpty() ? Optional.empty() : Optional.of(results.get(0));
    }
}

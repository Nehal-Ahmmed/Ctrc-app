package com.ctrc.report;

import com.ctrc.location.Location;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.List;
import java.util.Optional;

@Repository
public class ReportDaoImpl implements ReportDao {

    private final JdbcTemplate jdbcTemplate;

    public ReportDaoImpl(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    private static final RowMapper<Report> ROW_MAPPER = (rs, rowNum) -> {
        Report report = new Report();
        report.setReportId(rs.getLong("report_id"));
        report.setUserId(rs.getLong("user_id"));
        report.setLocationId(rs.getLong("location_id"));
        report.setTitle(rs.getString("title"));
        report.setDescription(rs.getString("description"));
        report.setCategory(rs.getString("category"));
        report.setUpvoteCount(rs.getInt("upvote_count"));
        report.setDownvoteCount(rs.getInt("downvote_count"));

        Timestamp expiresAt = rs.getTimestamp("expires_at");
        if (expiresAt != null) {
            report.setExpiresAt(expiresAt.toLocalDateTime());
        }
        report.setCreatedAt(rs.getTimestamp("created_at").toLocalDateTime());
        return report;
    };

    // maps a report joined with its location row in one query
    private static final RowMapper<Report> ROW_MAPPER_WITH_LOCATION = (rs, rowNum) -> {
        Report report = ROW_MAPPER.mapRow(rs, rowNum);

        Location location = new Location();
        location.setLocationId(rs.getLong("location_id"));
        location.setLongitude(rs.getDouble("longitude"));
        location.setLatitude(rs.getDouble("latitude"));
        location.setAddress(rs.getString("loc_address"));
        location.setCity(rs.getString("city"));
        report.setLocation(location);

        return report;
    };

    @Override
    public Long insert(Report report) {
        String sql = "insert into report (user_id, location_id, title, description, category, "
                + "upvote_count, downvote_count, expires_at) values (?, ?, ?, ?, ?, 0, 0, ?)";
        KeyHolder keyHolder = new GeneratedKeyHolder();

        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, report.getUserId());
            ps.setLong(2, report.getLocationId());
            ps.setString(3, report.getTitle());
            ps.setString(4, report.getDescription());
            ps.setString(5, report.getCategory());
            if (report.getExpiresAt() != null) {
                ps.setTimestamp(6, Timestamp.valueOf(report.getExpiresAt()));
            } else {
                ps.setTimestamp(6, null);
            }
            return ps;
        }, keyHolder);

        return keyHolder.getKey().longValue();
    }

    @Override
    public Optional<Report> findById(Long reportId) {
        String sql = "select * from report where report_id = ?";
        List<Report> results = jdbcTemplate.query(sql, ROW_MAPPER, reportId);
        return results.isEmpty() ? Optional.empty() : Optional.of(results.get(0));
    }

    @Override
    public Optional<Report> findByIdWithLocation(Long reportId) {
        String sql = "select r.*, l.longitude, l.latitude, l.address as loc_address, l.city "
                + "from report r join location l on r.location_id = l.location_id "
                + "where r.report_id = ?";
        List<Report> results = jdbcTemplate.query(sql, ROW_MAPPER_WITH_LOCATION, reportId);
        return results.isEmpty() ? Optional.empty() : Optional.of(results.get(0));
    }

    @Override
    public List<Report> findAll() {
        String sql = "select r.*, l.longitude, l.latitude, l.address as loc_address, l.city "
                + "from report r join location l on r.location_id = l.location_id "
                + "order by r.created_at desc";
        return jdbcTemplate.query(sql, ROW_MAPPER_WITH_LOCATION);
    }
}

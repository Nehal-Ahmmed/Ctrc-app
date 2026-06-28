package com.ctrc.report;

import java.util.List;
import java.util.Optional;

public interface ReportDao {

    Long insert(Report report);

    Optional<Report> findById(Long reportId);

    // joined with location, used for feed and detail views
    Optional<Report> findByIdWithLocation(Long reportId);

    List<Report> findAll();
}

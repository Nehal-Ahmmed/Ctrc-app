package com.ctrc.report;

import com.ctrc.common.ResourceNotFoundException;
import com.ctrc.location.Location;
import com.ctrc.location.LocationDao;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ReportService {

    private final ReportDao reportDao;
    private final LocationDao locationDao;

    public ReportService(ReportDao reportDao, LocationDao locationDao) {
        this.reportDao = reportDao;
        this.locationDao = locationDao;
    }

    // creates the location row then the report row in one transaction
    @Transactional
    public Report createReport(CreateReportRequest request) {
        Location location = new Location();
        location.setLatitude(request.getLatitude());
        location.setLongitude(request.getLongitude());
        location.setAddress(request.getAddress());
        location.setCity(request.getCity());

        Long locationId = locationDao.insert(location);

        Report report = new Report();
        report.setUserId(request.getUserId());
        report.setLocationId(locationId);
        report.setTitle(request.getTitle());
        report.setDescription(request.getDescription());
        report.setCategory(request.getCategory());

        Long reportId = reportDao.insert(report);

        return reportDao.findByIdWithLocation(reportId)
                .orElseThrow(() -> new ResourceNotFoundException("report not found after creation"));
    }

    public Report getReportById(Long reportId) {
        return reportDao.findByIdWithLocation(reportId)
                .orElseThrow(() -> new ResourceNotFoundException("report not found with id " + reportId));
    }

    public List<Report> getAllReports() {
        return reportDao.findAll();
    }
}

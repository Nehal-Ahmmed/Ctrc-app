package com.ctrc.report;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

// request body for creating a new report
// user_id is temporary here until module 2 auth is ready, will be replaced
// by the authenticated user once login is wired up
public class CreateReportRequest {

    @NotNull(message = "is required")
    private Long userId;

    @NotBlank(message = "is required")
    private String title;

    private String description;

    @NotBlank(message = "is required")
    private String category;

    @NotNull(message = "is required")
    private Double latitude;

    @NotNull(message = "is required")
    private Double longitude;

    private String address;
    private String city;

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public Double getLatitude() {
        return latitude;
    }

    public void setLatitude(Double latitude) {
        this.latitude = latitude;
    }

    public Double getLongitude() {
        return longitude;
    }

    public void setLongitude(Double longitude) {
        this.longitude = longitude;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public String getCity() {
        return city;
    }

    public void setCity(String city) {
        this.city = city;
    }
}

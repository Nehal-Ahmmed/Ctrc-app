package com.ctrc.location;

import java.util.Optional;

public interface LocationDao {

    // inserts a location and returns the generated location_id
    Long insert(Location location);

    Optional<Location> findById(Long locationId);
}

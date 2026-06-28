# backend conventions

these rules apply to every module (user, location, report, subreport, incidentgroup, vote, comment).
follow them so the code stays consistent across all three of us.

## package structure

one package per feature, not per layer. each feature package holds its own controller, service, dao,
dao implementation, and model classes.

example for report:
```
com.ctrc.report
  report.java              (model, plain class with fields + getters/setters)
  reportcontroller.java
  reportservice.java
  reportdao.java            (interface)
  reportdaoimpl.java         (jdbctemplate implementation)
```

## response format

every endpoint returns `com.ctrc.common.apiresponse<t>`. use `apiresponse.success(data)` or
`apiresponse.error(message)`. do not return raw objects or raw strings directly.

## exceptions

throw these from service layer, never handle them manually in controllers:
- `resourcenotfoundexception` - id does not exist, becomes 404
- `validationexception` - bad input, becomes 400
- `conflictexception` - duplicate or conflicting state, becomes 409

`globalexceptionhandler` catches all of these automatically. controllers should stay thin,
just call the service and return the result.

## dao pattern with jdbctemplate

no jpa, no hibernate, no entity annotations. use plain `jdbctemplate` with a rowmapper per model.

example pattern:
```java
private final jdbctemplate jdbcTemplate;

private static final rowmapper<report> reportRowMapper = (rs, rowNum) -> {
    report report = new report();
    report.setReportId(rs.getLong("report_id"));
    report.setTitle(rs.getString("title"));
    return report;
};

public optional<report> findById(long id) {
    string sql = "select * from report where report_id = ?";
    list<report> results = jdbcTemplate.query(sql, reportRowMapper, id);
    return results.isEmpty() ? optional.empty() : optional.of(results.get(0));
}
```

## naming

- table and column names: snake_case, must match schema.sql exactly
- java classes, methods, variables: camelCase as usual
- rest endpoints: kebab-case, plural nouns, e.g. `/api/sub-reports`, `/api/incident-groups`

## comments

keep comments minimal and lowercase. only comment on things that are not obvious from the code itself.

## transactions

use `@transactional` on service methods that touch more than one table, e.g. creating a location
then a report in the same call. both must succeed or both must fail.

## before pushing

- pull latest main first
- test your endpoint locally (curl or postman) before committing
- do not commit `application.properties` with your real local db password, use a placeholder

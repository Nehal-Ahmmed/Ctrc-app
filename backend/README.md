# ctrc backend

spring boot + jdbc (no jpa) + mysql backend for the ctrc project.

## setup

1. create the database and tables:
```
mysql -u root -p < sql/schema.sql
```

2. update `src/main/resources/application.properties` with your local mysql username and password.
   do not commit your real password, keep the placeholder when pushing.

3. run the backend:
```
mvn spring-boot:run
```

4. confirm it works:
```
curl http://localhost:8089/api/health
```
should return `{"success":true,"data":"backend is running","message":null}`

## structure

one package per feature under `src/main/java/com/ctrc/`. see `CONVENTIONS.md` for the full
pattern every module should follow (controller, service, dao, daoimpl).

## notes

- server runs on port 8089, this matches what the flutter app already expects
- cors is open to all origins for now since this is a dev setup, tighten later if needed
- see `roadmap.md` for the full module and stage breakdown

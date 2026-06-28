-- ctrc database schema
-- matches the locked er diagram and relational mapping, do not change table/column names

create database if not exists ctrc_db;
use ctrc_db;

-- user table
create table user (
    user_id bigint auto_increment primary key,
    name varchar(100) not null,
    password varchar(255) not null,
    email varchar(150) not null unique,
    address varchar(255),
    image_url varchar(500),
    created_at timestamp default current_timestamp
);

-- location table
create table location (
    location_id bigint auto_increment primary key,
    longitude decimal(9,6) not null,
    latitude decimal(9,6) not null,
    address varchar(255),
    city varchar(100)
);

-- report table (main reports)
create table report (
    report_id bigint auto_increment primary key,
    user_id bigint not null,
    location_id bigint not null,
    title varchar(150) not null,
    description text,
    category varchar(50) not null,
    upvote_count int default 0,
    downvote_count int default 0,
    expires_at timestamp null,
    created_at timestamp default current_timestamp,
    foreign key (user_id) references user(user_id),
    foreign key (location_id) references location(location_id)
);

-- sub_report table (linked/child reports)
create table sub_report (
    sub_report_id bigint auto_increment primary key,
    user_id bigint not null,
    report_id bigint not null,
    location_id bigint not null,
    description text,
    dist_from_parent decimal(8,3),
    upvote_count int default 0,
    downvote_count int default 0,
    created_at timestamp default current_timestamp,
    foreign key (user_id) references user(user_id),
    foreign key (report_id) references report(report_id),
    foreign key (location_id) references location(location_id)
);

-- incident_group table
create table incident_group (
    group_id bigint auto_increment primary key,
    report_id bigint not null,
    description text,
    created_at timestamp default current_timestamp,
    foreign key (report_id) references report(report_id)
);

-- comment table, can attach to either a report or a sub_report, never both
create table comment (
    comment_id bigint auto_increment primary key,
    user_id bigint not null,
    report_id bigint null,
    sub_report_id bigint null,
    content text not null,
    created_at timestamp default current_timestamp,
    foreign key (user_id) references user(user_id),
    foreign key (report_id) references report(report_id),
    foreign key (sub_report_id) references sub_report(sub_report_id),
    constraint chk_comment_target check (
        (report_id is not null and sub_report_id is null) or
        (report_id is null and sub_report_id is not null)
    )
);

-- vote table, can attach to either a report or a sub_report, never both
create table vote (
    vote_id bigint auto_increment primary key,
    user_id bigint not null,
    report_id bigint null,
    sub_report_id bigint null,
    vote_type varchar(10) not null,
    voted_at timestamp default current_timestamp,
    foreign key (user_id) references user(user_id),
    foreign key (report_id) references report(report_id),
    foreign key (sub_report_id) references sub_report(sub_report_id),
    constraint chk_vote_target check (
        (report_id is not null and sub_report_id is null) or
        (report_id is null and sub_report_id is not null)
    ),
    constraint chk_vote_type check (vote_type in ('up', 'down'))
);

-- indexes for common lookups and duplicate vote checks
create index idx_report_location on report(location_id);
create index idx_report_user on report(user_id);
create index idx_subreport_report on sub_report(report_id);
create index idx_comment_report on comment(report_id);
create index idx_comment_subreport on comment(sub_report_id);
create unique index idx_vote_user_report on vote(user_id, report_id);
create unique index idx_vote_user_subreport on vote(user_id, sub_report_id);

CREATE USER app_name WITH SUPERUSER PASSWORD 'app_name';
CREATE DATABASE app_name_development OWNER app_name;
CREATE DATABASE app_name_test OWNER app_name;
CREATE DATABASE app_name_production OWNER app_name;

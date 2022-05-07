CREATE USER authn WITH SUPERUSER PASSWORD 'authn';
CREATE DATABASE authn_development OWNER authn;
CREATE DATABASE authn_test OWNER authn;
CREATE DATABASE authn_production OWNER authn;

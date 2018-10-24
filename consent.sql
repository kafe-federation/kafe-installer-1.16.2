create database consent DEFAULT CHARACTER SET utf8;

use consent;

CREATE TABLE consent (
    consent_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usage_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    hashed_user_id VARCHAR(80) NOT NULL,
    service_id VARCHAR(255) NOT NULL,
    attribute VARCHAR(80) NOT NULL,
    UNIQUE (hashed_user_id, service_id)
)default charset=utf8;


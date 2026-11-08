-- =====================================================================
--  SMART LOST & FOUND SYSTEM  —  01_schema.sql
--  Creates the database and the 8 core tables with keys and constraints.
--  Works on MySQL 8.0+ and MariaDB 10.4+ (XAMPP / MAMP / phpMyAdmin).
-- =====================================================================

CREATE DATABASE IF NOT EXISTS smart_lost_and_found
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE smart_lost_and_found;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS audit_logs, returns, matches, item_images, items, categories, users, locations;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. LOCATIONS  — buildings / department counters that hold items
-- ---------------------------------------------------------------------
CREATE TABLE locations (
  location_id        INT           NOT NULL AUTO_INCREMENT,
  building_name      VARCHAR(100)  NOT NULL,
  department_counter VARCHAR(100)  NOT NULL,
  room_number        VARCHAR(20)   NULL,
  hours              VARCHAR(100)  NULL COMMENT 'Counter operating hours, e.g. Mon-Fri 09:00-17:00',
  PRIMARY KEY (location_id),
  UNIQUE KEY uq_location (building_name, department_counter)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 2. USERS  — students/staff (USER) and counter admins (ADMIN)
-- ---------------------------------------------------------------------
CREATE TABLE users (
  user_id          INT                   NOT NULL AUTO_INCREMENT,
  university_email VARCHAR(100)          NOT NULL,
  password_hash    VARCHAR(255)          NOT NULL,
  role             ENUM('USER','ADMIN')  NOT NULL DEFAULT 'USER',
  location_id      INT                   NULL COMMENT 'Counter an ADMIN manages; NULL for students',
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_users_email (university_email),
  KEY idx_users_location (location_id),
  CONSTRAINT fk_users_location
    FOREIGN KEY (location_id) REFERENCES locations (location_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_users_email CHECK (university_email LIKE '%_@_%._%'),
  -- Every admin must be mapped to a counter
  CONSTRAINT chk_users_admin_location CHECK (role = 'USER' OR location_id IS NOT NULL)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 3. CATEGORIES  — Wallet, Phone, ID Card, Bag, ...
-- ---------------------------------------------------------------------
CREATE TABLE categories (
  category_id   INT           NOT NULL AUTO_INCREMENT,
  category_name VARCHAR(100)  NOT NULL,
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_category_name (category_name)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 4. ITEMS  — one table for both LOST reports and FOUND reports
--    status: FOUND -> AVAILABLE | RETURNED | EXPIRED
--            LOST  -> OPEN      | RETURNED | EXPIRED
--    (status and expiration_date are filled in by triggers on insert)
-- ---------------------------------------------------------------------
CREATE TABLE items (
  item_id             INT                   NOT NULL AUTO_INCREMENT,
  report_type         ENUM('LOST','FOUND')  NOT NULL,
  creator_user_id     INT                   NOT NULL,
  category_id         INT                   NOT NULL,
  event_location_id   INT                   NULL COMMENT 'Where it was lost / discovered',
  holding_location_id INT                   NULL COMMENT 'Counter currently holding a FOUND item',
  title               VARCHAR(150)          NOT NULL,
  color               VARCHAR(50)           NULL,
  public_description  TEXT                  NULL COMMENT 'Shown on the public feed',
  private_notes       TEXT                  NULL COMMENT 'Hidden verification details, staff only',
  event_date          DATE                  NOT NULL COMMENT 'Date lost / found',
  expiration_date     DATE                  NULL COMMENT 'Defaults to event_date + 90 days',
  status              VARCHAR(30)           NOT NULL DEFAULT 'AVAILABLE',
  PRIMARY KEY (item_id),
  KEY idx_items_feed (report_type, status, event_date),
  KEY idx_items_match (category_id, report_type, status),
  KEY idx_items_holding (holding_location_id),
  KEY idx_items_event_loc (event_location_id),
  KEY idx_items_creator (creator_user_id),
  CONSTRAINT fk_items_creator
    FOREIGN KEY (creator_user_id) REFERENCES users (user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_items_category
    FOREIGN KEY (category_id) REFERENCES categories (category_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_items_event_location
    FOREIGN KEY (event_location_id) REFERENCES locations (location_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_items_holding_location
    FOREIGN KEY (holding_location_id) REFERENCES locations (location_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_items_status CHECK (
       (report_type = 'FOUND' AND status IN ('AVAILABLE','RETURNED','EXPIRED'))
    OR (report_type = 'LOST'  AND status IN ('OPEN','RETURNED','EXPIRED'))
  ),
  -- A found item must physically sit at a counter
  CONSTRAINT chk_items_found_holding CHECK (report_type = 'LOST' OR holding_location_id IS NOT NULL),
  CONSTRAINT chk_items_dates CHECK (expiration_date IS NULL OR expiration_date >= event_date)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 5. ITEM_IMAGES  — photos; is_public = 0 keeps verification photos hidden
-- ---------------------------------------------------------------------
CREATE TABLE item_images (
  image_id  INT           NOT NULL AUTO_INCREMENT,
  item_id   INT           NOT NULL,
  image_url VARCHAR(255)  NOT NULL,
  is_public BOOLEAN       NOT NULL DEFAULT TRUE,
  PRIMARY KEY (image_id),
  KEY idx_images_item (item_id),
  CONSTRAINT fk_images_item
    FOREIGN KEY (item_id) REFERENCES items (item_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 6. MATCHES  — smart-matching results between a LOST and a FOUND item
-- ---------------------------------------------------------------------
CREATE TABLE matches (
  match_id      INT           NOT NULL AUTO_INCREMENT,
  lost_item_id  INT           NOT NULL,
  found_item_id INT           NOT NULL,
  match_score   DECIMAL(5,2)  NOT NULL COMMENT 'Percentage 0-100',
  notified      BOOLEAN       NOT NULL DEFAULT FALSE COMMENT 'Alert sent to the lost-report owner',
  PRIMARY KEY (match_id),
  UNIQUE KEY uq_match_pair (lost_item_id, found_item_id),
  KEY idx_matches_found (found_item_id),
  CONSTRAINT fk_matches_lost
    FOREIGN KEY (lost_item_id) REFERENCES items (item_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_matches_found
    FOREIGN KEY (found_item_id) REFERENCES items (item_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT chk_matches_score CHECK (match_score BETWEEN 0 AND 100)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 7. RETURNS  — verified in-person handovers at the counter
-- ---------------------------------------------------------------------
CREATE TABLE returns (
  return_id           INT       NOT NULL AUTO_INCREMENT,
  found_item_id       INT       NOT NULL,
  linked_lost_item_id INT       NULL,
  recipient_user_id   INT       NOT NULL,
  verifying_admin_id  INT       NOT NULL,
  verification_notes  TEXT      NULL COMMENT 'Summary of the proof shown by the claimant',
  handover_timestamp  DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (return_id),
  UNIQUE KEY uq_returns_found (found_item_id),          -- an item can only be handed over once
  UNIQUE KEY uq_returns_lost (linked_lost_item_id),
  KEY idx_returns_recipient (recipient_user_id),
  KEY idx_returns_admin (verifying_admin_id),
  CONSTRAINT fk_returns_found
    FOREIGN KEY (found_item_id) REFERENCES items (item_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_returns_lost
    FOREIGN KEY (linked_lost_item_id) REFERENCES items (item_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_returns_recipient
    FOREIGN KEY (recipient_user_id) REFERENCES users (user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_returns_admin
    FOREIGN KEY (verifying_admin_id) REFERENCES users (user_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 8. AUDIT_LOGS  — who did what to which item, and when
--    actor_user_id NULL = automatic system action (e.g. expiration)
-- ---------------------------------------------------------------------
CREATE TABLE audit_logs (
  log_id             INT       NOT NULL AUTO_INCREMENT,
  actor_user_id      INT       NULL,
  target_item_id     INT       NULL,
  action_description TEXT      NOT NULL,
  `timestamp`        DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (log_id),
  KEY idx_audit_actor (actor_user_id),
  KEY idx_audit_item (target_item_id),
  KEY idx_audit_time (`timestamp`),
  CONSTRAINT fk_audit_actor
    FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_audit_item
    FOREIGN KEY (target_item_id) REFERENCES items (item_id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE = InnoDB;

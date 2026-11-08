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
-- =====================================================================
--  SMART LOST & FOUND SYSTEM  —  02_logic.sql
--  Business rules for the 8-step workflow:
--    * Triggers   – enforce rules, set defaults, auto-match, audit log
--    * Procedures – one per workflow action (register, log, search, ...)
--    * Views      – public feed, admin inventory, notifications, history
--    * Event      – daily auto-expiration of old items
--
--  The app tells the database who is acting by setting @app_user_id
--  before an UPDATE (the procedures below do this for you). Audit-log
--  rows with actor_user_id = NULL are automatic system actions.
-- =====================================================================

USE smart_lost_and_found;

DROP TRIGGER IF EXISTS trg_items_before_insert;
DROP TRIGGER IF EXISTS trg_items_after_insert;
DROP TRIGGER IF EXISTS trg_items_before_update;
DROP TRIGGER IF EXISTS trg_items_after_update;
DROP TRIGGER IF EXISTS trg_returns_before_insert;
DROP TRIGGER IF EXISTS trg_returns_after_insert;
DROP PROCEDURE IF EXISTS sp_match_item;
DROP PROCEDURE IF EXISTS sp_register_user;
DROP PROCEDURE IF EXISTS sp_log_found_item;
DROP PROCEDURE IF EXISTS sp_report_lost_item;
DROP PROCEDURE IF EXISTS sp_search_feed;
DROP PROCEDURE IF EXISTS sp_get_notifications;
DROP PROCEDURE IF EXISTS sp_record_handover;
DROP PROCEDURE IF EXISTS sp_expire_items;
DROP EVENT IF EXISTS ev_daily_expire_items;

DELIMITER $$

-- =====================================================================
-- STEP 5 — SMART MATCHING
-- Compares one item against the opposite report type in the same category.
-- Score (max 100):
--   category match ........ 40  (required — other categories are skipped)
--   same color ............ 25
--   same event location ... 15
--   dates within 2 days ... 10  (within 7 days = 5)
--   title/description hit . 10
-- Matches >= 50 are stored; >= 70 count as "high" and are flagged notified.
-- =====================================================================
CREATE PROCEDURE sp_match_item(IN p_item_id INT)
BEGIN
  INSERT IGNORE INTO matches (lost_item_id, found_item_id, match_score, notified)
  SELECT c.lost_id, c.found_id, c.score, (c.score >= 70)
  FROM (
    SELECT l.item_id AS lost_id,
           f.item_id AS found_id,
           ( 40
           + CASE WHEN LOWER(TRIM(l.color)) = LOWER(TRIM(f.color)) THEN 25 ELSE 0 END
           + CASE WHEN l.event_location_id = f.event_location_id THEN 15 ELSE 0 END
           + CASE WHEN ABS(DATEDIFF(f.event_date, l.event_date)) <= 2 THEN 10
                  WHEN ABS(DATEDIFF(f.event_date, l.event_date)) <= 7 THEN 5
                  ELSE 0 END
           + CASE WHEN LOCATE(LOWER(l.title), LOWER(CONCAT_WS(' ', f.title, f.public_description))) > 0
                    OR LOCATE(LOWER(f.title), LOWER(CONCAT_WS(' ', l.title, l.public_description))) > 0
                  THEN 10 ELSE 0 END
           ) AS score
    FROM items l
    JOIN items f ON f.category_id = l.category_id
    WHERE l.report_type = 'LOST'  AND l.status = 'OPEN'
      AND f.report_type = 'FOUND' AND f.status = 'AVAILABLE'
      AND f.event_date >= l.event_date - INTERVAL 1 DAY   -- can't be found before it was lost
      AND (l.item_id = p_item_id OR f.item_id = p_item_id)
  ) AS c
  WHERE c.score >= 50;
END$$

-- =====================================================================
-- ITEMS TRIGGERS
-- =====================================================================

-- STEP 2 / STEP 4 — validate and fill defaults before a report is saved
CREATE TRIGGER trg_items_before_insert
BEFORE INSERT ON items
FOR EACH ROW
BEGIN
  DECLARE v_role     VARCHAR(10);
  DECLARE v_location INT;

  SELECT role, location_id INTO v_role, v_location
  FROM users WHERE user_id = NEW.creator_user_id;

  IF NEW.event_date > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'event_date cannot be in the future';
  END IF;

  IF NEW.report_type = 'FOUND' THEN
    -- Only counter admins log found items, so everything on the feed is in custody
    IF v_role IS NULL OR v_role <> 'ADMIN' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only counter admins can log FOUND items';
    END IF;
    IF NEW.holding_location_id IS NULL THEN
      SET NEW.holding_location_id = v_location;
    ELSEIF NEW.holding_location_id <> v_location THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Admins can only log items into their own counter';
    END IF;
    SET NEW.status = 'AVAILABLE';             -- instant publishing, no approval step
  ELSE
    -- Duplicate check: same user, same category/color/location, within 3 days
    IF EXISTS (
      SELECT 1 FROM items
      WHERE report_type = 'LOST' AND status = 'OPEN'
        AND creator_user_id = NEW.creator_user_id
        AND category_id = NEW.category_id
        AND LOWER(IFNULL(color, '')) = LOWER(IFNULL(NEW.color, ''))
        AND event_location_id <=> NEW.event_location_id
        AND ABS(DATEDIFF(event_date, NEW.event_date)) <= 3
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Duplicate lost report: you already have an open report for this item';
    END IF;
    SET NEW.holding_location_id = NULL;       -- lost items are not at a counter
    SET NEW.status = 'OPEN';
  END IF;

  IF NEW.expiration_date IS NULL THEN
    SET NEW.expiration_date = NEW.event_date + INTERVAL 90 DAY;
  END IF;
END$$

-- Audit the new report, then run smart matching against the other side
CREATE TRIGGER trg_items_after_insert
AFTER INSERT ON items
FOR EACH ROW
BEGIN
  INSERT INTO audit_logs (actor_user_id, target_item_id, action_description)
  VALUES (NEW.creator_user_id, NEW.item_id,
          CONCAT('Created ', NEW.report_type, ' report: ', NEW.title));

  CALL sp_match_item(NEW.item_id);
END$$

-- STEP 8 — status can only become RETURNED through a recorded handover
CREATE TRIGGER trg_items_before_update
BEFORE UPDATE ON items
FOR EACH ROW
BEGIN
  IF OLD.status = 'RETURNED' AND NEW.status <> 'RETURNED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Returned items are closed and cannot be reopened';
  END IF;

  IF NEW.status = 'RETURNED' AND OLD.status <> 'RETURNED' THEN
    IF NEW.report_type = 'FOUND'
       AND NOT EXISTS (SELECT 1 FROM returns WHERE found_item_id = NEW.item_id) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Record a handover in the returns table to mark an item RETURNED';
    END IF;
    IF NEW.report_type = 'LOST'
       AND NOT EXISTS (SELECT 1 FROM returns WHERE linked_lost_item_id = NEW.item_id) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Record a handover in the returns table to mark an item RETURNED';
    END IF;
  END IF;
END$$

-- Every status change is written to the audit log
CREATE TRIGGER trg_items_after_update
AFTER UPDATE ON items
FOR EACH ROW
BEGIN
  IF NOT (OLD.status <=> NEW.status) THEN
    INSERT INTO audit_logs (actor_user_id, target_item_id, action_description)
    VALUES (@app_user_id, NEW.item_id,
            CONCAT('Status changed from ', OLD.status, ' to ', NEW.status));
  END IF;
END$$

-- =====================================================================
-- RETURNS TRIGGERS  (STEP 6 + 7 — verification and handover)
-- =====================================================================
CREATE TRIGGER trg_returns_before_insert
BEFORE INSERT ON returns
FOR EACH ROW
BEGIN
  DECLARE v_type     VARCHAR(10);
  DECLARE v_status   VARCHAR(30);
  DECLARE v_holding  INT;
  DECLARE v_role     VARCHAR(10);
  DECLARE v_admin_loc INT;
  DECLARE v_owner    INT;

  SELECT report_type, status, holding_location_id INTO v_type, v_status, v_holding
  FROM items WHERE item_id = NEW.found_item_id;

  IF v_type IS NULL OR v_type <> 'FOUND' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'found_item_id must be a FOUND item';
  END IF;
  IF v_status <> 'AVAILABLE' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only AVAILABLE items can be handed over';
  END IF;

  SELECT role, location_id INTO v_role, v_admin_loc
  FROM users WHERE user_id = NEW.verifying_admin_id;

  IF v_role IS NULL OR v_role <> 'ADMIN' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'verifying_admin_id must be an ADMIN';
  END IF;
  IF v_admin_loc <> v_holding THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only the admin of the holding counter can hand this item over';
  END IF;

  IF NEW.linked_lost_item_id IS NOT NULL THEN
    SET v_type = NULL, v_status = NULL;
    SELECT report_type, status, creator_user_id INTO v_type, v_status, v_owner
    FROM items WHERE item_id = NEW.linked_lost_item_id;

    IF v_type IS NULL OR v_type <> 'LOST' OR v_status <> 'OPEN' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'linked_lost_item_id must be an OPEN lost report';
    END IF;
    IF v_owner <> NEW.recipient_user_id THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The linked lost report must belong to the recipient';
    END IF;
  END IF;
END$$

-- STEP 8 — close the found item (and linked lost report) after handover
CREATE TRIGGER trg_returns_after_insert
AFTER INSERT ON returns
FOR EACH ROW
BEGIN
  SET @app_user_id = NEW.verifying_admin_id;

  UPDATE items SET status = 'RETURNED'
  WHERE item_id = NEW.found_item_id
     OR item_id = NEW.linked_lost_item_id;

  INSERT INTO audit_logs (actor_user_id, target_item_id, action_description)
  VALUES (NEW.verifying_admin_id, NEW.found_item_id,
          CONCAT('Handover verified at counter; item returned to user #', NEW.recipient_user_id));
END$$

-- =====================================================================
-- STORED PROCEDURES — one per workflow action
-- =====================================================================

-- STEP 1 — register a user (pass a bcrypt hash from the app, never a plain password)
CREATE PROCEDURE sp_register_user(
  IN p_email         VARCHAR(100),
  IN p_password_hash VARCHAR(255),
  IN p_role          VARCHAR(10),
  IN p_location_id   INT
)
BEGIN
  INSERT INTO users (university_email, password_hash, role, location_id)
  VALUES (LOWER(TRIM(p_email)), p_password_hash, IFNULL(p_role, 'USER'),
          IF(IFNULL(p_role, 'USER') = 'ADMIN', p_location_id, NULL));
  SELECT LAST_INSERT_ID() AS new_user_id;
END$$

-- STEP 2 — counter admin logs a found item (+ optional photo)
CREATE PROCEDURE sp_log_found_item(
  IN p_admin_id          INT,
  IN p_category_id       INT,
  IN p_event_location_id INT,
  IN p_title             VARCHAR(150),
  IN p_color             VARCHAR(50),
  IN p_public_desc       TEXT,
  IN p_private_notes     TEXT,
  IN p_event_date        DATE,
  IN p_image_url         VARCHAR(255),
  IN p_image_is_public   BOOLEAN
)
BEGIN
  DECLARE v_item_id INT;
  SET @app_user_id = p_admin_id;

  INSERT INTO items (report_type, creator_user_id, category_id, event_location_id,
                     title, color, public_description, private_notes, event_date)
  VALUES ('FOUND', p_admin_id, p_category_id, p_event_location_id,
          p_title, p_color, p_public_desc, p_private_notes, IFNULL(p_event_date, CURDATE()));
  SET v_item_id = LAST_INSERT_ID();

  IF p_image_url IS NOT NULL THEN
    INSERT INTO item_images (item_id, image_url, is_public)
    VALUES (v_item_id, p_image_url, IFNULL(p_image_is_public, TRUE));
  END IF;

  SELECT v_item_id AS new_item_id,
         (SELECT COUNT(*) FROM matches WHERE found_item_id = v_item_id) AS matches_found,
         (SELECT COUNT(*) FROM matches WHERE found_item_id = v_item_id AND notified = 1) AS users_notified;
END$$

-- STEP 4 — user submits a lost report; returns any found items that already match
CREATE PROCEDURE sp_report_lost_item(
  IN p_user_id           INT,
  IN p_category_id       INT,
  IN p_event_location_id INT,
  IN p_title             VARCHAR(150),
  IN p_color             VARCHAR(50),
  IN p_description       TEXT,
  IN p_event_date        DATE
)
BEGIN
  DECLARE v_item_id INT;
  SET @app_user_id = p_user_id;

  INSERT INTO items (report_type, creator_user_id, category_id, event_location_id,
                     title, color, public_description, event_date)
  VALUES ('LOST', p_user_id, p_category_id, p_event_location_id,
          p_title, p_color, p_description, IFNULL(p_event_date, CURDATE()));
  SET v_item_id = LAST_INSERT_ID();

  SELECT v_item_id AS new_lost_item_id;

  -- Possible matches already sitting at a counter (public info only)
  SELECT m.match_score, f.item_id AS found_item_id, f.title, f.color,
         f.public_description, f.event_date AS found_date,
         CONCAT(hl.building_name, ' - ', hl.department_counter) AS pick_up_at,
         hl.room_number, hl.hours
  FROM matches m
  JOIN items f      ON f.item_id = m.found_item_id
  JOIN locations hl ON hl.location_id = f.holding_location_id
  WHERE m.lost_item_id = v_item_id
  ORDER BY m.match_score DESC;
END$$

-- STEP 3 — feed search with filters and pagination (pass NULL to skip a filter)
CREATE PROCEDURE sp_search_feed(
  IN p_keyword             VARCHAR(100),
  IN p_category_id         INT,
  IN p_holding_location_id INT,
  IN p_event_location_id   INT,
  IN p_color               VARCHAR(50),
  IN p_date_from           DATE,
  IN p_date_to             DATE,
  IN p_page                INT,
  IN p_page_size           INT
)
BEGIN
  DECLARE v_size   INT DEFAULT IFNULL(p_page_size, 10);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * IFNULL(p_page_size, 10);

  SELECT *
  FROM v_public_feed v
  WHERE (p_keyword IS NULL OR v.title LIKE CONCAT('%', p_keyword, '%')
                           OR v.public_description LIKE CONCAT('%', p_keyword, '%'))
    AND (p_category_id         IS NULL OR v.category_id = p_category_id)
    AND (p_holding_location_id IS NULL OR v.holding_location_id = p_holding_location_id)
    AND (p_event_location_id   IS NULL OR v.event_location_id = p_event_location_id)
    AND (p_color               IS NULL OR v.color = p_color)
    AND (p_date_from           IS NULL OR v.found_date >= p_date_from)
    AND (p_date_to             IS NULL OR v.found_date <= p_date_to)
  ORDER BY v.found_date DESC, v.item_id DESC
  LIMIT v_size OFFSET v_offset;
END$$

-- STEP 5 — a user's match alerts (counter location only, no private details)
CREATE PROCEDURE sp_get_notifications(IN p_user_id INT)
BEGIN
  SELECT * FROM v_match_notifications
  WHERE user_id = p_user_id
  ORDER BY match_score DESC;
END$$

-- STEP 6 + 7 — admin verifies proof in person and records the handover
CREATE PROCEDURE sp_record_handover(
  IN p_admin_id            INT,
  IN p_found_item_id       INT,
  IN p_recipient_user_id   INT,
  IN p_linked_lost_item_id INT,
  IN p_verification_notes  TEXT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
    INSERT INTO returns (found_item_id, linked_lost_item_id, recipient_user_id,
                         verifying_admin_id, verification_notes)
    VALUES (p_found_item_id, p_linked_lost_item_id, p_recipient_user_id,
            p_admin_id, p_verification_notes);
  COMMIT;

  SELECT LAST_INSERT_ID() AS new_return_id;
END$$

-- STEP 8 — expire unclaimed items past their expiration_date
CREATE PROCEDURE sp_expire_items()
BEGIN
  SET @app_user_id = NULL;                    -- logged as a SYSTEM action
  UPDATE items
  SET status = 'EXPIRED'
  WHERE status IN ('AVAILABLE', 'OPEN')
    AND expiration_date < CURDATE();
  SELECT ROW_COUNT() AS items_expired;
END$$

-- Runs sp_expire_items every night at 01:00
-- (needs the event scheduler: SET GLOBAL event_scheduler = ON;)
CREATE EVENT ev_daily_expire_items
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 HOUR)
DO CALL sp_expire_items()$$

DELIMITER ;

-- =====================================================================
-- VIEWS
-- =====================================================================

-- STEP 3 — public campus feed: AVAILABLE found items, no private notes
CREATE OR REPLACE VIEW v_public_feed AS
SELECT i.item_id,
       i.title,
       i.category_id,
       c.category_name,
       i.color,
       i.public_description,
       i.event_date            AS found_date,
       i.event_location_id,
       CONCAT(el.building_name, ' - ', el.department_counter) AS found_at,
       i.holding_location_id,
       hl.building_name        AS holding_building,
       hl.department_counter   AS holding_counter,
       hl.room_number          AS holding_room,
       hl.hours                AS counter_hours,
       i.expiration_date,
       (SELECT img.image_url FROM item_images img
         WHERE img.item_id = i.item_id AND img.is_public = 1
         ORDER BY img.image_id LIMIT 1) AS image_url
FROM items i
JOIN categories c      ON c.category_id  = i.category_id
JOIN locations hl      ON hl.location_id = i.holding_location_id
LEFT JOIN locations el ON el.location_id = i.event_location_id
WHERE i.report_type = 'FOUND'
  AND i.status = 'AVAILABLE';

-- STEP 6 — admin inventory per counter, including private verification notes
CREATE OR REPLACE VIEW v_admin_inventory AS
SELECT i.item_id,
       i.holding_location_id,
       CONCAT(hl.building_name, ' - ', hl.department_counter) AS holding_counter,
       i.title,
       c.category_name,
       i.color,
       i.public_description,
       i.private_notes,
       i.event_date,
       i.expiration_date,
       DATEDIFF(i.expiration_date, CURDATE()) AS days_until_expiry,
       i.status,
       u.university_email AS logged_by,
       (SELECT COUNT(*) FROM matches m WHERE m.found_item_id = i.item_id) AS match_count
FROM items i
JOIN categories c ON c.category_id  = i.category_id
JOIN locations hl ON hl.location_id = i.holding_location_id
JOIN users u      ON u.user_id      = i.creator_user_id
WHERE i.report_type = 'FOUND';

-- STEP 4 — open lost reports
CREATE OR REPLACE VIEW v_open_lost_reports AS
SELECT i.item_id,
       u.user_id,
       u.university_email AS reported_by,
       i.title,
       c.category_name,
       i.color,
       i.public_description,
       CONCAT(el.building_name, ' - ', el.department_counter) AS lost_near,
       i.event_date AS lost_date,
       i.expiration_date
FROM items i
JOIN users u           ON u.user_id     = i.creator_user_id
JOIN categories c      ON c.category_id = i.category_id
LEFT JOIN locations el ON el.location_id = i.event_location_id
WHERE i.report_type = 'LOST'
  AND i.status = 'OPEN';

-- STEP 5 — match alerts: tells the student WHERE to go, not private details
CREATE OR REPLACE VIEW v_match_notifications AS
SELECT m.match_id,
       u.user_id,
       u.university_email,
       l.item_id  AS lost_item_id,
       l.title    AS your_lost_item,
       f.item_id  AS found_item_id,
       f.title    AS found_item_title,
       m.match_score,
       CONCAT('A possible match for "', l.title, '" is being held at ',
              hl.building_name, ' - ', hl.department_counter,
              IFNULL(CONCAT(', room ', hl.room_number), ''),
              IFNULL(CONCAT(' (', hl.hours, ')'), ''),
              '. Bring your university ID and proof of ownership.') AS message
FROM matches m
JOIN items l      ON l.item_id = m.lost_item_id
JOIN items f      ON f.item_id = m.found_item_id
JOIN users u      ON u.user_id = l.creator_user_id
JOIN locations hl ON hl.location_id = f.holding_location_id
WHERE m.notified = 1
  AND l.status = 'OPEN'
  AND f.status = 'AVAILABLE';

-- STEP 7 — handover history
CREATE OR REPLACE VIEW v_return_history AS
SELECT r.return_id,
       r.handover_timestamp,
       f.item_id  AS found_item_id,
       f.title    AS item_title,
       CONCAT(hl.building_name, ' - ', hl.department_counter) AS counter,
       rec.university_email AS recipient,
       adm.university_email AS verified_by,
       r.linked_lost_item_id,
       r.verification_notes
FROM returns r
JOIN items f      ON f.item_id      = r.found_item_id
JOIN locations hl ON hl.location_id = f.holding_location_id
JOIN users rec    ON rec.user_id    = r.recipient_user_id
JOIN users adm    ON adm.user_id    = r.verifying_admin_id;

-- STEP 8 — readable audit trail
CREATE OR REPLACE VIEW v_audit_trail AS
SELECT a.log_id,
       a.`timestamp`,
       IFNULL(u.university_email, 'SYSTEM') AS actor,
       a.target_item_id,
       i.title AS item_title,
       a.action_description
FROM audit_logs a
LEFT JOIN users u ON u.user_id = a.actor_user_id
LEFT JOIN items i ON i.item_id = a.target_item_id;
-- =====================================================================
--  SMART LOST & FOUND SYSTEM  —  03_sample_data.sql
--  Demo data. Every account's password is: password123
--  (stored as a bcrypt hash, the same format PHP password_hash() makes)
--
--  Dates are relative to today so the feed always looks fresh.
--  Lost reports are inserted BEFORE found items so the matching
--  trigger fills the matches table automatically.
-- =====================================================================

USE smart_lost_and_found;

-- ---------------------------------------------------------------------
-- Locations (counters)
-- ---------------------------------------------------------------------
INSERT INTO locations (location_id, building_name, department_counter, room_number, hours) VALUES
(1, 'Main Library',         'Circulation Desk',            'G01',    'Mon-Fri 08:00-20:00'),
(2, 'Engineering Building', 'Engineering Faculty Office',  'E-105',  'Mon-Fri 09:00-17:00'),
(3, 'Student Union',        'Information Counter',         'SU-002', 'Mon-Sat 09:00-18:00'),
(4, 'Science Complex',      'Science Department Office',   'S-210',  'Mon-Fri 09:00-16:30'),
(5, 'Sports Centre',        'Reception',                   'SC-01',  'Daily 07:00-22:00');

-- ---------------------------------------------------------------------
-- Categories
-- ---------------------------------------------------------------------
INSERT INTO categories (category_id, category_name) VALUES
(1, 'Wallet'), (2, 'Phone'), (3, 'ID Card'), (4, 'Bag'), (5, 'Keys'),
(6, 'Laptop'), (7, 'Water Bottle'), (8, 'Headphones'), (9, 'Clothing'), (10, 'Umbrella');

-- ---------------------------------------------------------------------
-- Users: 4 counter admins + 6 students
-- ---------------------------------------------------------------------
INSERT INTO users (user_id, university_email, password_hash, role, location_id) VALUES
(1,  'admin.library@university.edu',     '$2y$12$P27xQlRxdbPStHzzRsdTXO/0zZOi/u5JURb1VRwf6IbxlQiHNs9jC', 'ADMIN', 1),
(2,  'admin.engineering@university.edu', '$2y$12$P27xQlRxdbPStHzzRsdTXO/0zZOi/u5JURb1VRwf6IbxlQiHNs9jC', 'ADMIN', 2),
(3,  'admin.union@university.edu',       '$2y$12$P27xQlRxdbPStHzzRsdTXO/0zZOi/u5JURb1VRwf6IbxlQiHNs9jC', 'ADMIN', 3),
(4,  'admin.science@university.edu',     '$2y$12$P27xQlRxdbPStHzzRsdTXO/0zZOi/u5JURb1VRwf6IbxlQiHNs9jC', 'ADMIN', 4),
(5,  'aung.min@student.university.edu',  '$2y$12$P27xQlRxdbPStHzzRsdTXO/0zZOi/u5JURb1VRwf6IbxlQiHNs9jC', 'USER',  NULL),
(6,  'may.thu@student.university.edu',   '$2y$12$P27xQlRxdbPStHzzRsdTXO/0zZOi/u5JURb1VRwf6IbxlQiHNs9jC', 'USER',  NULL),
(7,  'john.lee@student.university.edu',  '$2y$12$P27xQlRxdbPStHzzRsdTXO/0zZOi/u5JURb1VRwf6IbxlQiHNs9jC', 'USER',  NULL),
(8,  'sara.khan@student.university.edu', '$2y$12$P27xQlRxdbPStHzzRsdTXO/0zZOi/u5JURb1VRwf6IbxlQiHNs9jC', 'USER',  NULL),
(9,  'kyaw.zin@student.university.edu',  '$2y$12$P27xQlRxdbPStHzzRsdTXO/0zZOi/u5JURb1VRwf6IbxlQiHNs9jC', 'USER',  NULL),
(10, 'emily.tan@student.university.edu', '$2y$12$P27xQlRxdbPStHzzRsdTXO/0zZOi/u5JURb1VRwf6IbxlQiHNs9jC', 'USER',  NULL);

-- ---------------------------------------------------------------------
-- LOST reports from students (status -> OPEN, set by trigger)
-- ---------------------------------------------------------------------
INSERT INTO items (item_id, report_type, creator_user_id, category_id, event_location_id,
                   title, color, public_description, event_date) VALUES
(1, 'LOST', 5, 1, 1, 'Black leather wallet', 'Black', 'Lost my wallet in the 2nd floor study area.',        CURDATE() - INTERVAL 3 DAY),
(2, 'LOST', 6, 2, 2, 'Blue iPhone 14',       'Blue',  'Left my phone in a lecture hall, blue case.',       CURDATE() - INTERVAL 2 DAY),
(3, 'LOST', 7, 5, 5, 'Car keys with red tag','Silver','Keys dropped near the gym lockers.',                 CURDATE() - INTERVAL 5 DAY),
(4, 'LOST', 8, 4, 3, 'Grey backpack',        'Grey',  'Backpack with laptop sleeve, left at the food court.',CURDATE() - INTERVAL 10 DAY),
(5, 'LOST', 9, 8, 1, 'White AirPods case',   'White', 'AirPods Pro case, lost in the library.',            CURDATE() - INTERVAL 1 DAY);

-- ---------------------------------------------------------------------
-- FOUND items logged by counter admins (status -> AVAILABLE; matching runs)
-- ---------------------------------------------------------------------
INSERT INTO items (item_id, report_type, creator_user_id, category_id, event_location_id, holding_location_id,
                   title, color, public_description, private_notes, event_date) VALUES
(6,  'FOUND', 1, 1, 1, 1, 'Black leather wallet', 'Black',  'Black leather bifold wallet found in the study area.',
     'Blue keychain inside. Student ID of Aung Min, two bank cards, 20 dollars cash.', CURDATE() - INTERVAL 2 DAY),
(7,  'FOUND', 2, 2, 2, 2, 'Blue smartphone',      'Blue',   'Smartphone in a blue case, found in lecture hall E-201.',
     'Lock screen shows a photo of a cat. Crack in bottom-left corner.',             CURDATE() - INTERVAL 1 DAY),
(8,  'FOUND', 3, 5, 5, 3, 'Set of keys',          'Silver', 'Bunch of keys found outside the gym.',
     'Red tag that says "Home". Includes a Toyota car key.',                          CURDATE() - INTERVAL 4 DAY),
(9,  'FOUND', 3, 4, 3, 3, 'Black backpack',       'Black',  'Backpack found under a table at the food court.',
     'Contains a calculus textbook with initials S.K.',                              CURDATE() - INTERVAL 8 DAY),
(10, 'FOUND', 4, 6, 4, 4, 'Silver laptop',        'Silver', '13-inch silver laptop left in lab S-305.',
     'Sticker of a mountain on the lid. Serial ends in 7QX.',                        CURDATE() - INTERVAL 6 DAY),
(11, 'FOUND', 4, 3, 4, 4, 'Student ID card',      'White',  'University student ID card found in the corridor.',
     'Name on card: Emily Tan.',                                                     CURDATE() - INTERVAL 1 DAY),
(12, 'FOUND', 2, 7, 2, 2, 'Green water bottle',   'Green',  'Green insulated water bottle.',
     'Initials "KZ" scratched on the bottom.',                                       CURDATE() - INTERVAL 3 DAY),
(13, 'FOUND', 1, 10, 1, 1, 'Black umbrella',      'Black',  'Folding umbrella left at the entrance.',
     'Wooden handle, one broken spoke.',                                              CURDATE() - INTERVAL 100 DAY);

-- ---------------------------------------------------------------------
-- Images (is_public = 0 keeps verification photos staff-only)
-- ---------------------------------------------------------------------
INSERT INTO item_images (item_id, image_url, is_public) VALUES
(6,  'uploads/items/6_wallet_front.jpg',     1),
(6,  'uploads/items/6_wallet_inside.jpg',    0),
(7,  'uploads/items/7_phone_case.jpg',       1),
(8,  'uploads/items/8_keys.jpg',             1),
(9,  'uploads/items/9_backpack.jpg',         1),
(10, 'uploads/items/10_laptop.jpg',          1),
(10, 'uploads/items/10_laptop_sticker.jpg',  0),
(12, 'uploads/items/12_bottle.jpg',          1);

-- ---------------------------------------------------------------------
-- One completed handover: John Lee collected his keys at the Student Union
-- (trigger sets item 8 and lost report 3 to RETURNED and writes the audit log)
-- ---------------------------------------------------------------------
INSERT INTO returns (found_item_id, linked_lost_item_id, recipient_user_id, verifying_admin_id, verification_notes) VALUES
(8, 3, 7, 3, 'Claimant described the red "Home" tag and Toyota key. University ID checked.');

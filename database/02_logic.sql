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
DROP TRIGGER IF EXISTS trg_items_before_delete;
DROP TRIGGER IF EXISTS trg_items_after_delete;
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
DROP PROCEDURE IF EXISTS sp_delete_item;
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

-- Returned items are part of the handover history, so they can't be deleted
CREATE TRIGGER trg_items_before_delete
BEFORE DELETE ON items
FOR EACH ROW
BEGIN
  IF OLD.status = 'RETURNED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Returned items are part of the handover history and cannot be deleted';
  END IF;
END$$

-- Log the deletion. The item row is gone, so target_item_id stays NULL
-- and the title is kept in the description instead.
CREATE TRIGGER trg_items_after_delete
AFTER DELETE ON items
FOR EACH ROW
BEGIN
  INSERT INTO audit_logs (actor_user_id, target_item_id, action_description)
  VALUES (@app_user_id, NULL,
          CONCAT('Deleted ', OLD.report_type, ' report #', OLD.item_id, ': ', OLD.title));
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

-- Delete a lost report or found item. Only the user who created it may
-- delete it. Its images and matches are removed too (ON DELETE CASCADE).
CREATE PROCEDURE sp_delete_item(IN p_user_id INT, IN p_item_id INT)
BEGIN
  DECLARE v_creator INT;

  SELECT creator_user_id INTO v_creator FROM items WHERE item_id = p_item_id;

  IF v_creator IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Item not found';
  END IF;
  IF v_creator <> p_user_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only the person who created this report can delete it';
  END IF;

  SET @app_user_id = p_user_id;
  DELETE FROM items WHERE item_id = p_item_id;
  SELECT ROW_COUNT() AS items_deleted;
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

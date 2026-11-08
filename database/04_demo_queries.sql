-- =====================================================================
--  SMART LOST & FOUND SYSTEM  —  04_demo_queries.sql
--  Walk through the 8-step workflow. Run these one block at a time in
--  phpMyAdmin's SQL tab (select the smart_lost_and_found database first).
--  Run 03_sample_data.sql before this file.
-- =====================================================================

USE smart_lost_and_found;

-- ---------------------------------------------------------------------
-- STEP 1 — Registration and role assignment
-- ---------------------------------------------------------------------
CALL sp_register_user('new.student@student.university.edu',
                      '$2y$12$P27xQlRxdbPStHzzRsdTXO/0zZOi/u5JURb1VRwf6IbxlQiHNs9jC', 'USER', NULL);

SELECT u.user_id, u.university_email, u.role,
       CONCAT(l.building_name, ' - ', l.department_counter) AS manages_counter
FROM users u
LEFT JOIN locations l ON l.location_id = u.location_id;

-- ---------------------------------------------------------------------
-- STEP 2 — Admin logs a found item at their counter (published instantly)
--   Library admin (user 1) logs white earbuds -> auto-matches Kyaw Zin's lost report
-- ---------------------------------------------------------------------
CALL sp_log_found_item(1, 8, 1, 'White AirPods case', 'White',
                       'White earbuds case found on a library desk.',
                       'Engraved "KZ" on the back. Left earbud missing.',
                       CURDATE(), 'uploads/items/airpods.jpg', TRUE);

-- ---------------------------------------------------------------------
-- STEP 3 — Browse and filter the public feed
-- ---------------------------------------------------------------------
SELECT * FROM v_public_feed ORDER BY found_date DESC;

-- Page 1, 5 items per page, everything
CALL sp_search_feed(NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 5);

-- Black items held at the Main Library
CALL sp_search_feed(NULL, NULL, 1, NULL, 'Black', NULL, NULL, 1, 10);

-- Keyword search
CALL sp_search_feed('backpack', NULL, NULL, NULL, NULL, NULL, NULL, 1, 10);

-- ---------------------------------------------------------------------
-- STEP 4 — Lost report (returns found items that already match)
-- ---------------------------------------------------------------------
CALL sp_report_lost_item(10, 3, 4, 'Student ID card', 'White',
                         'Lost my student ID somewhere in the Science Complex.',
                         CURDATE() - INTERVAL 1 DAY);

-- ---------------------------------------------------------------------
-- STEP 5 — Smart matching results and notifications
-- ---------------------------------------------------------------------
SELECT m.match_id, l.title AS lost_item, f.title AS found_item, m.match_score, m.notified
FROM matches m
JOIN items l ON l.item_id = m.lost_item_id
JOIN items f ON f.item_id = m.found_item_id
ORDER BY m.match_score DESC;

SELECT * FROM v_match_notifications;

CALL sp_get_notifications(5);   -- Aung Min's alerts

-- ---------------------------------------------------------------------
-- STEP 6 — Admin checks the claimant's proof against the private notes
-- ---------------------------------------------------------------------
SELECT item_id, title, private_notes, status
FROM v_admin_inventory
WHERE holding_location_id = 1;   -- Main Library counter

-- ---------------------------------------------------------------------
-- STEP 7 — Secure handover (Aung Min collects the wallet at the library)
-- ---------------------------------------------------------------------
CALL sp_record_handover(1, 6, 5, 1, 'Described the blue keychain inside; university ID matched.');

SELECT * FROM v_return_history;

-- ---------------------------------------------------------------------
-- STEP 8 — Closure, expiration and audit trail
-- ---------------------------------------------------------------------
SELECT item_id, report_type, title, status FROM items WHERE item_id IN (1, 6);

CALL sp_expire_items();          -- the 100-day-old umbrella becomes EXPIRED

SELECT item_id, title, event_date, expiration_date, status
FROM items WHERE status = 'EXPIRED';

SELECT * FROM v_audit_trail ORDER BY log_id;

-- ---------------------------------------------------------------------
-- REPORTS
-- ---------------------------------------------------------------------
-- Items per counter by status
SELECT CONCAT(l.building_name, ' - ', l.department_counter) AS counter,
       SUM(i.status = 'AVAILABLE') AS available,
       SUM(i.status = 'RETURNED')  AS returned,
       SUM(i.status = 'EXPIRED')   AS expired
FROM locations l
LEFT JOIN items i ON i.holding_location_id = l.location_id AND i.report_type = 'FOUND'
GROUP BY l.location_id
ORDER BY l.location_id;

-- Most frequently lost categories
SELECT c.category_name, COUNT(*) AS total_reports
FROM items i JOIN categories c ON c.category_id = i.category_id
GROUP BY c.category_id
ORDER BY total_reports DESC;

-- Return rate
SELECT ROUND(100 * SUM(status = 'RETURNED') / COUNT(*), 1) AS return_rate_percent
FROM items WHERE report_type = 'FOUND';

-- =====================================================================
-- RULE TESTS — each of these SHOULD FAIL with a clear error message.
-- Remove the "-- " in front of one line to try it.
-- =====================================================================
-- A student cannot log a FOUND item:
-- INSERT INTO items (report_type, creator_user_id, category_id, title, event_date) VALUES ('FOUND', 5, 1, 'Wallet', CURDATE());

-- An admin cannot log into another counter:
-- INSERT INTO items (report_type, creator_user_id, category_id, holding_location_id, title, event_date) VALUES ('FOUND', 1, 1, 2, 'Wallet', CURDATE());

-- Duplicate lost report (May Thu already reported her blue phone):
-- CALL sp_report_lost_item(6, 2, 2, 'Blue phone', 'Blue', 'Again', CURDATE() - INTERVAL 1 DAY);

-- An item cannot be marked RETURNED without a handover record:
-- UPDATE items SET status = 'RETURNED' WHERE item_id = 7;

-- An item cannot be handed over twice:
-- CALL sp_record_handover(3, 8, 7, NULL, 'Second handover');

-- Only the holding counter's admin can hand an item over:
-- CALL sp_record_handover(2, 10, 8, NULL, 'Wrong counter');

-- An admin must be linked to a counter:
-- INSERT INTO users (university_email, password_hash, role) VALUES ('bad.admin@university.edu', 'x', 'ADMIN');

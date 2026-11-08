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

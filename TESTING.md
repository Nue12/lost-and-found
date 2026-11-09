# Testing Guide

This guide walks through every workflow in the Smart Lost & Found system, with the result you should see at each step. Use it to check the project still works after a change, or to rehearse the demo.

Each test has an ID (for example **T4.2**). If something fails, tell the group which test failed and what you saw instead.

- **Part A** tests the website. Do the sections in order, because later tests use data created by earlier ones.
- **Part B** tests the database rules directly in phpMyAdmin.
- **Part C** is a checklist to tick off.

---

## Before you start

1. **Reset the data.** In phpMyAdmin, click **Import** and import `database/smart_lost_and_found_full.sql` again. This puts back the original sample data.
   > Do this right before testing. The nightly expiry job runs at 01:00, so the 100-day-old umbrella (item 13) may already be EXPIRED if you imported the data on an earlier day. That would make T8.1 show nothing to expire.
2. **Start the website** as described in [SETUP.md](SETUP.md). Then open it:
   - XAMPP: http://localhost/smart_lost_and_found/web/
   - `php -S`: http://localhost:8000
3. **Use a private (incognito) window** when you change accounts, or click **Log out** first.

All demo accounts use the password **`password123`**.

| Short name | Email | Role | Counter |
|---|---|---|---|
| admin.library | admin.library@university.edu | Admin | Main Library – Circulation Desk |
| admin.engineering | admin.engineering@university.edu | Admin | Engineering Building – Faculty Office |
| admin.union | admin.union@university.edu | Admin | Student Union – Information Counter |
| admin.science | admin.science@university.edu | Admin | Science Complex – Department Office |
| aung.min | aung.min@student.university.edu | Student | |
| may.thu | may.thu@student.university.edu | Student | |
| john.lee | john.lee@student.university.edu | Student | |
| sara.khan | sara.khan@student.university.edu | Student | |
| kyaw.zin | kyaw.zin@student.university.edu | Student | |
| emily.tan | emily.tan@student.university.edu | Student | |

### What's in the sample data

| ID | Type | Title | Owner / counter | Status |
|---|---|---|---|---|
| 1 | LOST | Black leather wallet | aung.min | OPEN |
| 2 | LOST | Blue iPhone 14 | may.thu | OPEN |
| 3 | LOST | Car keys with red tag | john.lee | RETURNED |
| 4 | LOST | Grey backpack | sara.khan | OPEN |
| 5 | LOST | White AirPods case | kyaw.zin | OPEN |
| 6 | FOUND | Black leather wallet | Main Library | AVAILABLE |
| 7 | FOUND | Blue smartphone | Engineering | AVAILABLE |
| 8 | FOUND | Set of keys | Student Union | RETURNED (to john.lee) |
| 9 | FOUND | Black backpack | Student Union | AVAILABLE |
| 10 | FOUND | Silver laptop | Science Complex | AVAILABLE |
| 11 | FOUND | Student ID card | Science Complex | AVAILABLE |
| 12 | FOUND | Green water bottle | Engineering | AVAILABLE |
| 13 | FOUND | Black umbrella (100 days old) | Main Library | AVAILABLE (expires in T8.1) |

Matches already stored:

| Lost report | Found item | Score | Student alerted? |
|---|---|---|---|
| 1 Wallet (aung.min) | 6 Wallet | 100% | Yes |
| 2 iPhone (may.thu) | 7 Smartphone | 90% | Yes |
| 3 Keys (john.lee) | 8 Keys | 90% | Yes (already returned) |
| 4 Backpack (sara.khan) | 9 Backpack | 65% | No, because it's under 70% |

### How matching scores work

A match only counts when the lost and found items are in the **same category** (40 points). Then:

- Same color: 25 points
- Same location: 15 points
- Dates within 2 days: 10 points (within 7 days: 5 points)
- Title or description words in common: 10 points

Scores of **50% or more** are saved as matches. At **70% or more**, the student gets an alert.

A found item is **never** matched if it was found more than one day *before* the lost date, because it can't be found before it was lost. Keep this in mind when you choose dates for new test reports.

---

# Part A: Website tests

## 1. Registration and login (workflow step 1)

| ID | Steps | Expected result |
|---|---|---|
| T1.1 | Open the site while logged out. | You're sent to the **login** page. |
| T1.2 | Click **Create account**. Register `test.student@student.university.edu` with password `password123` twice. | "Account created. You can log in now." appears, and you're back on the login page. |
| T1.3 | Register `someone@gmail.com`. | Error: "Use your university email address (ending in university.edu)." |
| T1.4 | Register with the password `short`. | Error: "Password must be at least 8 characters." |
| T1.5 | Register with two passwords that are different. | Error: "Passwords do not match." |
| T1.6 | Register `aung.min@student.university.edu` again. | Error: "An account with that email already exists." |
| T1.7 | Log in as `test.student@…` with password `wrongpass`. | Error: "Incorrect email or password." |
| T1.8 | Log in as `test.student@…` with password `password123`. | You land on the **Feed**. The menu shows student links only (Feed, Report lost item, My reports), with no admin links. |
| T1.9 | In phpMyAdmin, open the `users` table. | The new account has role **USER**, an empty `location_id`, and a `password_hash` starting with `$2y$`. The real password isn't stored anywhere. |
| T1.10 | Log out, then log in as **admin.library**. | You land on **Inventory**. The menu also shows Log found item, Inventory, Lost reports and Activity. |

## 2. Access control

| ID | Steps | Expected result |
|---|---|---|
| T2.1 | Log out, then type `…/feed.php` into the address bar. | You're sent to the login page. |
| T2.2 | Log in as **aung.min**, then go to `…/admin_inventory.php`. | You're sent to the Feed with "That page is for counter admins only." Try `admin_log_found.php`, `admin_lost_reports.php`, `admin_handover.php?id=6` and `admin_activity.php` as well. |
| T2.3 | As **aung.min**, open `…/item.php?id=2` (may.thu's lost report). | "This item is not available." Students can only see their own lost reports. |
| T2.4 | As **aung.min**, open `…/item.php?id=8` (a returned item). | "This item is not available." Students only see found items that are still AVAILABLE. |

## 3. Browse the public feed (workflow step 3)

Log in as **aung.min**.

| ID | Steps | Expected result |
|---|---|---|
| T3.1 | Open **Feed** with no filters. | Only **AVAILABLE found items** appear: wallet, smartphone, backpack, laptop, ID card, water bottle and umbrella. The keys (returned) and the lost reports don't appear. |
| T3.2 | Type `laptop` in **Keyword** and search. | Only "Silver laptop" appears. |
| T3.3 | Set **Color** = Black. | Wallet, backpack and umbrella. |
| T3.4 | Set **Color** = Black and **Held at** = Main Library. | Wallet and umbrella. |
| T3.5 | Set **Category** = Phone. | Only the blue smartphone. |
| T3.6 | Set **Found at** = Science Complex. | Laptop and student ID card. |
| T3.7 | Set **From** to today's date. | Items found before today disappear. |
| T3.8 | Search for a keyword that doesn't exist, such as `zzzz`. | A "no items" message, not an error. |
| T3.9 | Click **Clear**. | All 7 items are back. |
| T3.10 | Open the **wallet** (item 6). | You see the public description, the front photo and the counter's name, room and hours. You **don't** see the private notes (the blue keychain) or the private "inside" photo. |
| T3.11 | (Pagination) Log in as an admin and log 3 more found items (see section 5), so there are 10 or more available items. Then open the Feed as a student. | 9 items per page, with Next and Previous links. |

> If photos show as broken images, that's expected for the sample data: the files in `03_sample_data.sql` are placeholder names. Photos you upload yourself in T5.3 will show.

## 4. Report a lost item and get matched immediately (workflow step 4)

Log in as **aung.min**.

| ID | Steps | Expected result |
|---|---|---|
| T4.1 | **Report lost item**: title `Silver laptop`, category **Laptop**, color `Silver`, location **Science Complex**, date **7 days ago**, description `13-inch laptop with a mountain sticker`. Submit. | Success. A **matching found item** appears straight away: "Silver laptop" at the Science Department Office, scoring **100%**. (With today's date there's no match, because the laptop was found 6 days ago, before you lost it.) |
| T4.2 | Submit **the same form again**. | Error: "Duplicate lost report: you already have an open report for this item." No second report is created. |
| T4.3 | Report with the date set to tomorrow. | Error: "Enter the date you lost it (not in the future)." |
| T4.4 | Report with no category or no title. | "Choose a category." / "Give the item a short title." |
| T4.5 | Report something nobody has found: title `Red scarf`, category **Clothing**, color `Red`. | Saved, with no matches shown. The report is OPEN. |
| T4.6 | Log in as **admin.science** (any admin works) and open **Lost reports**. | Every student's lost report from every location is listed, including aung.min's laptop and red scarf from T4.1 and T4.5. The menu link shows the number of open reports, for example "Lost reports (6)". |
| T4.7 | On **Lost reports**, look at the **Best match** column. | The laptop report shows **100%** with an **At your counter** badge, because admin.science's counter holds the laptop. The red scarf shows "None yet". |
| T4.8 | Log in as **admin.engineering** and open **Lost reports**. | The same reports appear. Now the **At your counter** badge is on may.thu's **Blue iPhone 14** instead of the laptop. |
| T4.9 | Try the **Open / Returned / Expired / All** tabs, then the **Keyword**, **Category** and **Lost near** filters. | john.lee's keys report appears under **Returned**. The filters narrow the list, and **Clear** resets them. |
| T4.10 | Click a report's title. | The report opens, showing who reported it and its possible matches. **‹ Back** returns to Lost reports. |

## 5. Admin logs a found item (workflow step 2)

Log in as **admin.library**.

| ID | Steps | Expected result |
|---|---|---|
| T5.1 | **Log found item**: title `White AirPods case`, category **Headphones**, color `White`, found at **Main Library**, date today, public description `White earbuds case found on a desk`, private notes `Engraved "KZ" on the back`. Submit. | You're taken to the new item's page with "Item logged and published to the feed. 1 matching lost report(s) found; 1 student(s) alerted." It matches kyaw.zin's lost report 5. |
| T5.2 | On that item page, look at the details. | As the holding admin, you see the **private notes** and a **matching lost reports** list with kyaw.zin's report. |
| T5.3 | Log another item, a `Blue umbrella` (category **Umbrella**, color `Blue`), and attach a **JPG or PNG photo** with "Show photo on the public feed" ticked. | The photo shows on the item page and on the Feed. A new file appears in `web/uploads/items/` with a random name. |
| T5.4 | Log an item with a photo but **untick** "Show photo on the public feed". | Students don't see the photo on the Feed or on the item page. admin.library still sees it. |
| T5.5 | Try uploading a `.txt` or `.pdf` renamed to `.jpg`. | Error: "Photos must be JPG, PNG or WebP." The file type is checked by its content, not its name. |
| T5.6 | Log an item with a date in the future. | Error: "Enter the date it was found (not in the future)." |
| T5.7 | Open the new item as **admin.engineering** (another counter). | The item shows, but **without** the private notes and private photos, because those are only for the counter holding it. |

## 6. Match alerts for students (workflow step 5)

| ID | Steps | Expected result |
|---|---|---|
| T6.1 | Log in as **aung.min** and open **My reports**. | Under **Match alerts**, the black leather wallet at **Main Library – Circulation Desk** with a **100%** score and a message telling you to bring your university ID. You also see your laptop report from T4.1. |
| T6.2 | Log in as **kyaw.zin** and open **My reports**. | An alert for the **White AirPods case** at Main Library (from T5.1). |
| T6.3 | Log in as **may.thu** and open **My reports**. | A 90% alert for the blue smartphone at the Engineering Faculty Office. |
| T6.4 | Log in as **sara.khan** and open **My reports**. | **No alert**. Her backpack match is only 65%, which is below the 70% alert level. Her lost report is still listed as OPEN. |
| T6.5 | Log in as **john.lee** and open **My reports**. | His keys report is **RETURNED**, and the keys appear under **Items you collected**. There's no alert, because returned items don't alert. |

## 7. Verify ownership and hand over (workflow steps 6 and 7)

Log in as **admin.library**.

| ID | Steps | Expected result |
|---|---|---|
| T7.1 | **Inventory** → **Hand over** on the black leather wallet (item 6). | The handover page shows the **private notes** (blue keychain, Aung Min's ID…), the private photo, and aung.min's matching lost report with its score. |
| T7.2 | Submit with an empty **Proof summary**. | Error: "Summarise the proof the claimant gave." |
| T7.3 | Submit without ticking **"I checked the claimant's university ID in person"**. | Error: "Confirm that you checked the claimant's university ID." |
| T7.4 | Enter claimant email `nobody@student.university.edu`. | Error: "No account uses that email. The claimant must register before collecting the item." |
| T7.5 | Choose aung.min's matching report, enter email `aung.min@student.university.edu`, proof `Described the blue keychain and showed student ID`, tick the box, and confirm. | "Handover recorded: "Black leather wallet" returned to aung.min@…". You land on the **Returned** tab and the wallet is listed there. |
| T7.6 | Open the **Available** tab. | The wallet is gone, and there's no **Hand over** button for it any more. |
| T7.7 | Type `…/admin_handover.php?id=6` again. | "That item is not available for handover at your counter." An item can only be handed over once. |
| T7.8 | Log in as **admin.engineering** and type `…/admin_handover.php?id=13` (the Main Library umbrella). | "That item is not available for handover at your counter." Only the counter holding an item can hand it over. |
| T7.9 | Log in as **aung.min** and open **My reports**. | The wallet alert has gone. The wallet report is **RETURNED**, and the wallet is listed under **Items you collected**. |
| T7.10 | Open the **Feed** as any student. | The wallet no longer appears. |
| T7.11 | (Handover without a lost report) As **admin.science**, hand over the **Student ID card** (item 11) to `emily.tan@student.university.edu` without choosing a lost report. | The handover succeeds. A lost report is optional, because some owners never filed one. |

## 8. Expiry, history and audit (workflow step 8)

Log in as **admin.library**.

| ID | Steps | Expected result |
|---|---|---|
| T8.1 | **Inventory** → **Run expiration now**. | "1 item(s) marked EXPIRED." The 100-day-old black umbrella moves to the **Expired** tab. |
| T8.2 | Click **Run expiration now** again. | "No items are past their expiration date." |
| T8.3 | Check the **Available / Returned / Expired / All** tabs. | The numbers in brackets add up, and each tab only lists items held at Main Library. |
| T8.4 | Open the **Feed** as a student. | The umbrella no longer appears. |
| T8.5 | Open **Activity**. | **Handover history** lists the wallet handover from T7.5 (recipient, admin, proof, time). The **Audit log** shows entries such as "Created FOUND report: …", "Status changed from AVAILABLE to RETURNED" and "Handover verified at counter…", each with the actor's email. The expiry from T8.1 shows the actor as **SYSTEM**. |
| T8.6 | In phpMyAdmin, open `items` and look at the expiration dates. | Every item has an `expiration_date` exactly **90 days after** its `event_date`, set automatically. |

## 9. Security checks

| ID | Steps | Expected result |
|---|---|---|
| T9.1 | Report a lost item titled `<script>alert(1)</script>`. | The title shows as plain text, and no popup appears. |
| T9.2 | Search the Feed for `' OR 1=1 --`. | No error, and no extra items. Queries use prepared statements. |
| T9.3 | In the browser dev tools, delete the hidden `csrf` input from any form and submit it. | The request is rejected. Every form has a CSRF token. |
| T9.4 | Click **Log out**, then press the browser's Back button and reload. | You're sent to the login page. |

---

# Part B: Database rule tests (phpMyAdmin)

These prove the **database itself** enforces the rules, even if someone bypasses the website.

1. Re-import `database/smart_lost_and_found_full.sql` to start clean.
2. Open the `smart_lost_and_found` database and click the **SQL** tab.
3. Run each block one at a time. Every **"should fail"** test must show an error with the message given.

`SET @app_user_id = …` tells the audit log who is acting.

### B1. Step-by-step happy path

```sql
-- Step 1: register a student
CALL sp_register_user('new.student@student.university.edu', '$2y$10$abcdefghijklmnopqrstuv', 'USER', NULL);

-- Step 2: admin.library (user 1) logs a found item at its own counter (location 1)
SET @app_user_id = 1;
CALL sp_log_found_item(1, 8, 1, 'White AirPods case', 'White',
     'White earbuds case', 'Engraved KZ', CURDATE(), NULL, 1);
-- Expected: new_item_id = 14, matches_found = 1, users_notified = 1

-- Step 3: public feed
SELECT * FROM v_public_feed;

-- Step 4: student aung.min (user 5) reports a lost laptop
SET @app_user_id = 5;
CALL sp_report_lost_item(5, 6, 4, 'Silver laptop', 'Silver', '13-inch laptop', CURDATE() - INTERVAL 7 DAY);
-- Expected: new lost item id, plus a second result listing found item 10 at 100%

-- Step 5: alerts for aung.min
CALL sp_get_notifications(5);

-- Steps 6 and 7: admin.library hands the wallet (6) to aung.min, linked to lost report 1
SET @app_user_id = 1;
CALL sp_record_handover(1, 6, 5, 1, 'Described blue keychain, ID checked');
SELECT item_id, status FROM items WHERE item_id IN (1, 6);   -- both RETURNED

-- Step 8: expiry, history and audit
CALL sp_expire_items();             -- items_expired = 1 (the umbrella)
SELECT * FROM v_return_history;
SELECT * FROM v_audit_trail ORDER BY log_id DESC LIMIT 20;
```

### B2. Rules that should fail

| ID | SQL | Expected error |
|---|---|---|
| B2.1 | `CALL sp_log_found_item(5, 1, 1, 'Wallet', 'Black', NULL, NULL, CURDATE(), NULL, 1);` | Only counter admins can log FOUND items |
| B2.2 | `INSERT INTO items (report_type, creator_user_id, category_id, holding_location_id, title, event_date) VALUES ('FOUND', 1, 1, 2, 'Pen', CURDATE());` | Admins can only log items into their own counter |
| B2.3 | `CALL sp_report_lost_item(6, 2, 2, 'Blue phone', 'Blue', NULL, CURDATE());` (may.thu already has an open report for this) | Duplicate lost report: you already have an open report for this item |
| B2.4 | `CALL sp_report_lost_item(6, 9, 1, 'Jacket', 'Red', NULL, CURDATE() + INTERVAL 1 DAY);` | event_date cannot be in the future |
| B2.5 | `UPDATE items SET status = 'RETURNED' WHERE item_id = 7;` | Record a handover in the returns table to mark an item RETURNED |
| B2.6 | `UPDATE items SET status = 'AVAILABLE' WHERE item_id = 8;` | Returned items are closed and cannot be reopened |
| B2.7 | `CALL sp_record_handover(1, 7, 6, NULL, 'test');` (item 7 is held by Engineering) | Only the admin of the holding counter can hand this item over |
| B2.8 | `CALL sp_record_handover(5, 7, 6, NULL, 'test');` (user 5 is a student) | verifying_admin_id must be an ADMIN |
| B2.9 | `CALL sp_record_handover(3, 8, 7, NULL, 'again');` (item 8 is already returned) | Only AVAILABLE items can be handed over |
| B2.10 | `CALL sp_record_handover(2, 2, 6, NULL, 'test');` (item 2 is a lost report) | found_item_id must be a FOUND item |
| B2.11 | `CALL sp_record_handover(2, 7, 5, 2, 'test');` (lost report 2 belongs to may.thu, not aung.min) | The linked lost report must belong to the recipient |
| B2.12 | `INSERT INTO users (university_email, password_hash, role) VALUES ('x@university.edu', 'h', 'ADMIN');` | Check constraint `chk_users_admin_location` is violated: an admin must have a counter |
| B2.13 | `INSERT INTO users (university_email, password_hash) VALUES ('aung.min@student.university.edu', 'h');` | Duplicate entry (the email must be unique) |
| B2.14 | `DELETE FROM locations WHERE location_id = 1;` | Cannot delete or update a parent row (a foreign key protects it) |
| B2.15 | `INSERT INTO matches (lost_item_id, found_item_id, match_score) VALUES (1, 6, 50);` | Duplicate entry (each lost/found pair is matched only once) |

> `database/04_demo_queries.sql` contains the same walkthrough plus more reports, if you prefer to open one file.

When you finish, **import `smart_lost_and_found_full.sql` again** to reset the data for the next person.

---

# Part C: Checklist

Copy this into your group chat or an issue and tick off each item.

**Website**
- [ ] 1. Registration and login (T1.1–T1.10)
- [ ] 2. Access control (T2.1–T2.4)
- [ ] 3. Feed, filters and item privacy (T3.1–T3.11)
- [ ] 4. Lost report, instant match, duplicate check, admin Lost reports page (T4.1–T4.10)
- [ ] 5. Log found item, photo upload, auto-match (T5.1–T5.7)
- [ ] 6. Match alerts, including the under-70% case (T6.1–T6.5)
- [ ] 7. Verification and handover (T7.1–T7.11)
- [ ] 8. Expiry, history and audit log (T8.1–T8.6)
- [ ] 9. Security (T9.1–T9.4)

**Database**
- [ ] B1. Happy path from step 1 to step 8
- [ ] B2. All 15 rule tests fail with the expected message

**After testing**
- [ ] Re-imported `smart_lost_and_found_full.sql`
- [ ] Deleted test photos from `web/uploads/items/` (keep `.gitkeep`)

# Smart Lost & Found System

A university lost-and-found system built in three layers:

| Layer | Folder | What it is |
|---|---|---|
| User interface | `web/` | PHP pages for students and counter admins |
| Backend logic | `database/02_logic.sql` | Triggers, stored procedures and views that enforce the workflow |
| Storage | `database/` | MySQL database with 8 linked tables (managed in phpMyAdmin) |

See [database/README.md](database/README.md) for the database design.

## Getting started

**Full step-by-step instructions for Windows and macOS are in [SETUP.md](SETUP.md).**

Short version:

1. Install XAMPP (Windows/macOS), or MySQL + PHP + phpMyAdmin with Homebrew (macOS).
2. Clone this repository. With XAMPP, clone it into the `htdocs` folder.
3. In phpMyAdmin, go to **Import** and import `database/smart_lost_and_found_full.sql`.
4. Open http://localhost/smart_lost_and_found/web/ (XAMPP), or run `php -S localhost:8000 -t web` and open http://localhost:8000.
5. If your MySQL password isn't empty, copy `web/config.local.example.php` to `web/config.local.php` and set it there.

## Demo accounts

All use the password `password123`.

| Role | Email | Counter |
|---|---|---|
| Admin | admin.library@university.edu | Main Library – Circulation Desk |
| Admin | admin.engineering@university.edu | Engineering Building – Faculty Office |
| Admin | admin.union@university.edu | Student Union – Information Counter |
| Admin | admin.science@university.edu | Science Complex – Department Office |
| Student | aung.min@student.university.edu | (has a 100% match waiting) |
| Student | may.thu@student.university.edu, john.lee@…, sara.khan@…, kyaw.zin@…, emily.tan@… | |

New users can register with any email ending in `university.edu`. Change this in `web/config.php`.

## Pages

| Page | Who | Workflow step |
|---|---|---|
| `register.php`, `login.php` | Everyone | 1. Registration and roles |
| `admin_log_found.php` | Admin | 2. Log found item (public description, private notes, photo) |
| `feed.php` | Everyone | 3. Feed with keyword, category, counter, location, color and date filters, plus pagination |
| `report_lost.php` | Student | 4. Lost report with duplicate check, showing matches immediately |
| `my_reports.php` | Student | 5. Match alerts naming the counter, plus your reports and collected items |
| `item.php` | Everyone | Item details. Private notes and photos are shown only to the holding counter's admin |
| `admin_handover.php` | Admin | 6 and 7. Check proof against private notes, then record the handover |
| `admin_inventory.php` | Admin | 8. Counter stock by status, with a "Run expiration now" button |
| `admin_lost_reports.php` | Admin | 4 and 5. Every student's lost report across campus, with the best match score and an "At your counter" badge |
| `admin_activity.php` | Admin | 8. Handover history and audit log |
| `delete_item.php` | Creator only | Deletes a lost report (student) or a found item (the admin who logged it). Returned items can't be deleted |

## Demo script (5 minutes)

1. Log in as **aung.min**. **My reports** shows a 100% match alert for the wallet at the Main Library.
2. On the **Feed**, filter Color = Black and Held at = Main Library.
3. Report a lost item that's already on the feed, for example "Silver laptop", Laptop, Silver, Science Complex, lost 7 days ago. A 100% match appears at once. Submit it again to see the duplicate check.
4. Log in as **admin.library**. Under **Inventory**, click **Hand over** on the wallet. You'll see the private note about the blue keychain. Choose Aung Min, enter the proof and confirm.
5. **Activity** now shows the handover and the audit trail. **Run expiration now** expires the 100-day-old umbrella.
6. Log in as **admin.library** again and **Log found item** with a photo. Matching students are alerted automatically.

To reset all demo data, import `smart_lost_and_found_full.sql` again.

To test every workflow step by step, follow [TESTING.md](TESTING.md).

## Security notes

- Passwords are stored with `password_hash()` (bcrypt) and checked with `password_verify()`.
- All queries use PDO prepared statements, and all output is escaped against XSS.
- Every form has a CSRF token. Admin pages check the role. The session ID is regenerated at login.
- Uploads only accept JPG, PNG or WebP (checked by file content), up to 5 MB, saved under random names.
- The database enforces the rules too, through triggers, so a request that skips the web pages still can't break them.

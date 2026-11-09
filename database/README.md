# Smart Lost & Found — Database (phpMyAdmin)

A MySQL/MariaDB database for the 8-step workflow and the 8-table ERD.

## Files

| File | What it does |
|---|---|
| `smart_lost_and_found_full.sql` | **Import this one.** It contains files 01 + 02 + 03 in order. |
| `01_schema.sql` | Creates the database and 8 tables with PKs, FKs, UNIQUE and CHECK constraints |
| `02_logic.sql` | Triggers, stored procedures, views and the daily expiry event |
| `03_sample_data.sql` | 5 counters, 10 categories, 4 admins, 6 students, 5 lost and 8 found items, 1 handover |
| `04_demo_queries.sql` | Walks through workflow steps 1–8, plus reports and rule tests (for your demo) |

All sample accounts use the password `password123`, stored as a bcrypt hash.

## How to import in phpMyAdmin

1. Start Apache and MySQL in XAMPP or MAMP, then open `http://localhost/phpmyadmin`.
2. Click the **Import** tab at the top. Don't select a database first, because the file creates `smart_lost_and_found` itself.
3. Choose `smart_lost_and_found_full.sql`, leave the format as **SQL**, and click **Import**.
4. The database appears in the left panel with 8 tables. Under its **Routines**, **Triggers**, **Events** and **Views** you'll see the logic.
5. To demo it, select the database, open the **SQL** tab, paste blocks from `04_demo_queries.sql` and click **Go**.
6. Optional: to turn on nightly auto-expiration, run `SET GLOBAL event_scheduler = ON;` in the SQL tab. You can always run `CALL sp_expire_items();` by hand instead.
7. To see the ERD inside phpMyAdmin, open the database, then **More → Designer**.

Importing again resets everything. The script drops and recreates the tables.

## Where each workflow step lives

| Step | Database objects |
|---|---|
| 1. Registration and roles | `users` (`role`, `location_id`), CHECK: an admin must have a counter, `sp_register_user` |
| 2. Admin logs found item | `trg_items_before_insert`: only ADMINs, only into their own counter, status defaults to AVAILABLE, expiry = +90 days. `sp_log_found_item` |
| 3. Feed and filters | `v_public_feed` (no private notes, public images only), `sp_search_feed` (filters and pagination) |
| 4. Lost report and duplicate check | `sp_report_lost_item`. Duplicate check in `trg_items_before_insert` (same user, category, color, location, within 3 days) |
| 5. Smart matching and alerts | `sp_match_item` runs automatically from `trg_items_after_insert`. Scores ≥ 50 are stored, and scores ≥ 70 set `notified`. `v_match_notifications`, `sp_get_notifications` |
| 6. Live verification | `v_admin_inventory` (with `private_notes`). `trg_returns_before_insert`: only the holding counter's admin, and only AVAILABLE items |
| 7. Counter handover | `sp_record_handover`, which inserts into `returns` (one handover per item), plus `v_return_history` |
| 8. Closure, expiry and audit | `trg_returns_after_insert` sets RETURNED. `trg_items_before_update` blocks RETURNED without a handover. `sp_expire_items` and `ev_daily_expire_items`. Every action goes to `audit_logs` (`v_audit_trail`) |
| Deleting a report | `sp_delete_item`: only the user who created the item. `trg_items_before_delete` blocks deleting RETURNED items. `trg_items_after_delete` writes the deletion to `audit_logs`. Images and matches are removed by `ON DELETE CASCADE` |

**Match score (out of 100):** same category 40 (required), same color 25, same event location 15, dates within 2 days 10 (within 7 days 5), title or description overlap 10.

**Status values:** FOUND items are `AVAILABLE`, `RETURNED` or `EXPIRED`. LOST reports are `OPEN`, `RETURNED` or `EXPIRED`.

**Audit actor:** the app sets `@app_user_id` before making changes (the procedures do this for you). A `NULL` actor means a system action, such as auto-expiration.

## Compatibility

Tested on MySQL (Homebrew). It's written for MySQL 8.0+ and MariaDB 10.4+, which covers XAMPP and MAMP. MySQL 5.7 imports it but silently ignores the CHECK constraints. The triggers still enforce the main rules.

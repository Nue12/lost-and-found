# Setup Guide

This guide gets the Smart Lost & Found project running on your own computer: the MySQL database, phpMyAdmin to view it, and the PHP website.

**Pick the option for your computer:**

| Your computer | Follow | Time |
|---|---|---|
| Windows | [Option A: XAMPP](#option-a-windows-with-xampp) | ~15 min |
| macOS, easiest | [Option B: XAMPP for macOS](#option-b-macos-with-xampp) | ~15 min |
| macOS, with Homebrew | [Option C: Homebrew](#option-c-macos-with-homebrew) | ~10 min |

All options end with the same result:

| What | Address |
|---|---|
| Website | Option A/B: http://localhost/smart_lost_and_found/web/ · Option C: http://localhost:8000 |
| phpMyAdmin | Option A/B: http://localhost/phpmyadmin · Option C: http://localhost:8080 |
| Database name | `smart_lost_and_found` |

Presenting with an admin laptop and a student laptop? See [Presenting from two computers](#presenting-from-two-computers).

---

## What you need

- **Git**, to download the project. Check with `git --version`. Download it from https://git-scm.com if you don't have it.
- **XAMPP** (Options A and B) or **Homebrew** (Option C). The steps below cover installing them.
- The project needs **PHP 8.1 or newer** and **MySQL 8.0+** or **MariaDB 10.4+**. Current XAMPP and Homebrew versions meet these.

---

## Option A: Windows with XAMPP

XAMPP bundles Apache (the web server), PHP, MariaDB (a MySQL-compatible database) and phpMyAdmin in one installer.

### A1. Install XAMPP
1. Download XAMPP for Windows with **PHP 8.2 or newer** from https://www.apachefriends.org.
2. Run the installer and keep the default folder `C:\xampp`.
3. Open the **XAMPP Control Panel** and click **Start** next to **Apache** and **MySQL**. Both should turn green.

### A2. Download the project into `htdocs`
Open **Command Prompt** and run:

```bat
cd C:\xampp\htdocs
git clone https://github.com/Nue12/lost-and-found.git smart_lost_and_found
```

The folder must be named `smart_lost_and_found`, so the website address below works. If the repository is private, ask the owner to add you as a collaborator first.

### A3. Create the database in phpMyAdmin
1. Open http://localhost/phpmyadmin.
2. Click the **Import** tab at the top. Don't select a database first, because the file creates it.
3. Click **Choose File** and select `C:\xampp\htdocs\smart_lost_and_found\database\smart_lost_and_found_full.sql`.
4. Scroll down and click **Import**.
5. `smart_lost_and_found` appears in the left panel with 8 tables.

### A4. Open the website
Go to http://localhost/smart_lost_and_found/web/ and log in with a [demo account](#demo-accounts).

XAMPP's default database login is `root` with no password, which matches the project's defaults, so there's nothing to configure.

---

## Option B: macOS with XAMPP

### B1. Install XAMPP
1. Download XAMPP for macOS with **PHP 8.2 or newer** from https://www.apachefriends.org. Choose the **Apple Silicon** version for M1/M2/M3/M4 Macs, or **Intel** otherwise.
2. Open the `.dmg` and drag XAMPP into Applications. If macOS blocks it, go to **System Settings → Privacy & Security** and click **Open Anyway**.
3. Open **XAMPP** (manager-osx). In the **Manage Servers** tab, start **Apache Web Server** and **MySQL Database**.

### B2. Download the project into `htdocs`
Open **Terminal** and run:

```bash
cd /Applications/XAMPP/htdocs
git clone https://github.com/Nue12/lost-and-found.git smart_lost_and_found
```

### B3. Create the database
Same as [step A3](#a3-create-the-database-in-phpmyadmin). The file is at `/Applications/XAMPP/htdocs/smart_lost_and_found/database/smart_lost_and_found_full.sql`.

### B4. Open the website
Go to http://localhost/smart_lost_and_found/web/.

> **Photo uploads fail with a permission error?** Run:
> `chmod -R 777 /Applications/XAMPP/htdocs/smart_lost_and_found/web/uploads`

> **Using MAMP instead of XAMPP?** Clone into `/Applications/MAMP/htdocs`. MAMP's database password is `root` and its port is `8889`, so [create a `config.local.php`](#using-a-different-database-password) with those values. The site is at http://localhost:8888/smart_lost_and_found/web/.

---

## Option C: macOS with Homebrew

This uses Homebrew's MySQL and PHP, with PHP's built-in web server. There's no Apache to configure.

### C1. Install the tools
Install Homebrew from https://brew.sh if you don't have it. Then run:

```bash
brew install mysql php phpmyadmin
brew services start mysql
```

`brew services start mysql` keeps MySQL running in the background, even after a restart.

### C2. Allow phpMyAdmin to log in as `root` with no password
A fresh Homebrew MySQL has a `root` user with **no password**. phpMyAdmin blocks that by default. This command allows it, and also sets the `blowfish_secret` phpMyAdmin needs for its login cookie:

```bash
sed -i '' -e "s/\['AllowNoPassword'\] = false/['AllowNoPassword'] = true/" -e "s/\$cfg\['blowfish_secret'\] = ''/\$cfg['blowfish_secret'] = '$(openssl rand -hex 16)'/" /opt/homebrew/etc/phpmyadmin.config.inc.php
```

Check that it worked:

```bash
grep AllowNoPassword /opt/homebrew/etc/phpmyadmin.config.inc.php
```

It should print `... = true;`.

> On an **Intel Mac**, Homebrew lives in `/usr/local`, not `/opt/homebrew`. Replace `/opt/homebrew` with `/usr/local` in every command in this section.

### C3. Download the project

```bash
cd ~/Documents
git clone https://github.com/Nue12/lost-and-found.git smart_lost_and_found
cd smart_lost_and_found
```

### C4. Create the database
Import from the terminal:

```bash
mysql -uroot < database/smart_lost_and_found_full.sql
```

Or start phpMyAdmin (step C5) and use **Import**, as in [step A3](#a3-create-the-database-in-phpmyadmin).

### C5. Start phpMyAdmin (Terminal tab 1)

```bash
php -S localhost:8080 -t /opt/homebrew/share/phpmyadmin
```

Open http://localhost:8080 and log in with username `root` and an empty password.

### C6. Start the website (Terminal tab 2)
Open a new Terminal tab (Cmd+T), go to the project folder, and run:

```bash
php -S localhost:8000 -t web
```

Open http://localhost:8000.

**Both tabs must stay open while you work.** Press Ctrl+C in a tab to stop that server. Next time, repeat only C5 and C6.

---

## Demo accounts

Every account's password is `password123`.

| Role | Email | Counter |
|---|---|---|
| Admin | `admin.library@university.edu` | Main Library – Circulation Desk |
| Admin | `admin.engineering@university.edu` | Engineering Building – Faculty Office |
| Admin | `admin.union@university.edu` | Student Union – Information Counter |
| Admin | `admin.science@university.edu` | Science Complex – Department Office |
| Student | `aung.min@student.university.edu` | Has a 100% match alert waiting |
| Student | `may.thu@`, `john.lee@`, `sara.khan@`, `kyaw.zin@`, `emily.tan@` + `student.university.edu` | |

You can also register a new student account with any email ending in `university.edu`.

---

## Seeing the database in phpMyAdmin

Click **smart_lost_and_found** in the left panel.

| To see | Go to |
|---|---|
| The 8 tables and their data | Click a table, then **Browse** |
| Columns, keys and constraints | Click a table, then **Structure** |
| The ER diagram | **More → Designer** (top menu) |
| Triggers | **Triggers** tab |
| Stored procedures | **Routines** tab |
| Daily expiry job | **Events** tab |
| Views (feed, inventory, etc.) | Listed under **Views** in the left panel |
| Run demo queries | **SQL** tab. Paste blocks from `database/04_demo_queries.sql` and click **Go** |

The website and phpMyAdmin use the same database. Anything you do on the site, like a lost report or a handover, appears in phpMyAdmin after a refresh.

**Optional:** the nightly auto-expiry only runs if the event scheduler is on. Run `SET GLOBAL event_scheduler = ON;` in the SQL tab. Otherwise use **Run expiration now** on the admin Inventory page.

---

## Using a different database password

The website connects with user `root`, no password, port `3306`. If your MySQL is different:

1. In the `web` folder, copy `config.local.example.php` to a new file named `config.local.php`.
2. Uncomment and edit the lines you need, for example:
   ```php
   define('DB_PASS', 'root');
   define('DB_PORT', 8889);
   ```

`config.local.php` is listed in `.gitignore`, so **your password is never uploaded to GitHub**, and teammates' settings don't clash. Don't edit `config.php` for your own machine.

---

## Resetting the data

Import `database/smart_lost_and_found_full.sql` again, the same way as during setup. It drops and recreates all tables with fresh sample data. Everyone on the team can reset whenever they want, because each person has their own local database.

## Changing the database (for the team)

The database is split into files that are easier to edit:

| File | Contents |
|---|---|
| `database/01_schema.sql` | Tables, keys, constraints |
| `database/02_logic.sql` | Triggers, procedures, views, event |
| `database/03_sample_data.sql` | Demo data |
| `database/04_demo_queries.sql` | Demo and test queries (not part of the install) |
| `database/smart_lost_and_found_full.sql` | **Generated:** 01 + 02 + 03 joined together |

After editing 01, 02 or 03, rebuild the full file so teammates get your change.

**macOS / Git Bash:**
```bash
cd database && cat 01_schema.sql 02_logic.sql 03_sample_data.sql > smart_lost_and_found_full.sql
```

**Windows PowerShell:**
```powershell
cd database; Get-Content 01_schema.sql, 02_logic.sql, 03_sample_data.sql | Set-Content -Encoding utf8 smart_lost_and_found_full.sql
```

Commit both the edited file and the rebuilt full file. Teammates then pull and re-import.

---

## Presenting from two computers

For the demo you can show the admin and the student at the same time, on two laptops. You **don't need hosting**. One laptop (the **server**) runs the database and the website, and the other laptop (the **guest**) opens the website through the network. Both laptops then use the same database, so when the admin logs a found item, the student laptop sees the match alert straight away.

The guest laptop doesn't need anything installed, just a browser.

### 1. Connect both laptops to the same network

Use a **phone hotspot**. University and café Wi-Fi often block laptops from connecting to each other, even when both are on the same network. Test the setup with the hotspot before presentation day.

### 2. Start the website on the server laptop

Do the normal setup from Option A, B or C on this laptop first. Then:

| Server laptop uses | What to do |
|---|---|
| XAMPP (Option A or B) | Start Apache and MySQL as usual. Apache already accepts connections from other computers. |
| Homebrew (Option C) | Start the website with `0.0.0.0` instead of `localhost` (see below). |

```bash
php -S 0.0.0.0:8000 -t web
```

> `localhost` means "this computer only", so other laptops can't connect to it. `0.0.0.0` accepts connections from the network too. Keep using `localhost` the rest of the time.

### 3. Find the server laptop's IP address

- **macOS:** run this in Terminal (use `en1` if `en0` prints nothing):
  ```bash
  ipconfig getifaddr en0
  ```
- **Windows:** run `ipconfig` in Command Prompt and copy the **IPv4 Address** of your Wi-Fi adapter.

It looks like `172.20.10.2` or `192.168.1.23`. The address can change each time you connect, so check it again on the day.

### 4. Allow the connection through the firewall

The first time the guest laptop connects, the server laptop may ask whether to allow incoming connections:

- **macOS:** click **Allow** for `php` or `httpd`.
- **Windows:** tick **Private networks** for *Apache HTTP Server* and click **Allow access**. If you connected to a hotspot, make sure Windows treats that network as **Private**: go to **Settings → Network & internet → Wi-Fi → (your network)** and choose **Private network**.

### 5. Open the website on the guest laptop

| Server laptop uses | Address on the guest laptop |
|---|---|
| XAMPP | `http://<IP>/smart_lost_and_found/web/` |
| Homebrew | `http://<IP>:8000` |

For example `http://192.168.1.23:8000`. Log in as a student on the guest laptop and as an admin on the server laptop.

### Suggested demo script

1. **Student laptop:** log in as `aung.min`. **My reports** shows a 100% match alert for the wallet at the Main Library.
2. **Admin laptop:** log in as `admin.library`. Go to **Inventory** and click **Hand over** on the wallet. Show the private notes, record the handover and confirm.
3. **Student laptop:** refresh **My reports**. The alert is gone and the wallet is listed under **Items you collected**.
4. **Student laptop:** log in as `kyaw.zin` (who lost white AirPods), and open **My reports**. There are no alerts yet.
5. **Admin laptop:** **Log found item**: `White AirPods case`, category Headphones, color White, found at Main Library, today. The page says one student was alerted.
6. **Student laptop:** refresh **My reports**. The new AirPods alert appears.

Re-import `smart_lost_and_found_full.sql` on the server laptop right before presenting, so the demo starts from clean data. [TESTING.md](TESTING.md) lists more scenarios.

### Backup plan: one laptop, two browsers

If the network doesn't work, both accounts can still be logged in at the same time on one laptop. Each browser keeps its own login, so use two different browsers, for example Chrome for the admin and Safari, Firefox or Edge for the student. A Chrome incognito window also works. Put the two windows side by side on the projector.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Website shows `SQLSTATE[HY000] [1045] Access denied` | Your MySQL password isn't empty. Create `config.local.php` ([see above](#using-a-different-database-password)). |
| `SQLSTATE[HY000] [2002] Connection refused` | MySQL isn't running. XAMPP: start MySQL in the control panel. Homebrew: `brew services start mysql`. MAMP: set port 8889 in `config.local.php`. |
| `Unknown database 'smart_lost_and_found'` | You haven't imported the SQL file yet ([step A3](#a3-create-the-database-in-phpmyadmin)). |
| phpMyAdmin: *"Login without a password is forbidden by configuration"* | Homebrew: redo [step C2](#c2-allow-phpmyadmin-to-log-in-as-root-with-no-password). XAMPP shouldn't show this. If it does, edit `C:\xampp\phpMyAdmin\config.inc.php` and set `AllowNoPassword` to `true`. |
| XAMPP MySQL won't start (port 3306 in use) | Another MySQL is already running. Stop it (for example in Windows **Services**, or `brew services stop mysql`), or change XAMPP's port and set `DB_PORT` in `config.local.php`. |
| XAMPP Apache won't start (port 80 in use) | Skype, IIS or another server is using port 80. Close it, or change Apache's port in XAMPP **Config → httpd.conf** (`Listen 8081`) and use http://localhost:8081/smart_lost_and_found/web/. |
| `Address already in use` when running `php -S` | That server is already running in another tab, or use a different port, e.g. `php -S localhost:8001 -t web`. |
| Import fails with an error about `DELIMITER` or a trigger | Make sure you import `smart_lost_and_found_full.sql` through the **Import** tab, not by pasting it into the SQL tab. |
| Blank page or `Parse error` | Your PHP is older than 8.1. Update XAMPP, or run `brew upgrade php`. |
| Photo upload fails | Make sure `web/uploads/items` exists and is writable (see the tip in [Option B](#b4-open-the-website)). |
| Page says *"Invalid form submission"* | Your session expired. Refresh the page and submit again. |
| Second laptop can't open the website (it keeps loading, then times out) | Check that both laptops are on the same network (a phone hotspot is safest) and that you used the server's current IP address. With Homebrew, start the server with `php -S 0.0.0.0:8000 -t web`, not `localhost`. Allow the connection through the firewall ([step 4](#4-allow-the-connection-through-the-firewall)). |
| Feed photos show category names instead of pictures | Normal: sample items have no image files. Photos you upload through **Log found item** display normally. |

## Project structure

```
smart_lost_and_found/
├── README.md              Project overview
├── SETUP.md               This guide
├── database/              SQL files (import smart_lost_and_found_full.sql)
└── web/                   PHP website
    ├── config.php         Default settings (don't edit for your machine)
    ├── config.local.example.php
    ├── includes/          Database connection, login checks, page layout
    ├── assets/style.css
    ├── uploads/items/     Uploaded photos (not committed)
    ├── feed.php, item.php, report_lost.php, my_reports.php        Student pages
    ├── admin_log_found.php, admin_inventory.php,
    │   admin_handover.php, admin_activity.php                     Admin pages
    └── login.php, register.php, logout.php, index.php
```

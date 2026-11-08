<?php
// ---------------------------------------------------------------------
// Default settings (XAMPP / Homebrew MySQL: user root, empty password).
//
// Don't edit this file for your own machine. Copy config.local.example.php
// to config.local.php and change the values there; that file is not
// committed to Git, so every teammate can have their own settings.
// ---------------------------------------------------------------------
if (is_file(__DIR__ . '/config.local.php')) {
    require __DIR__ . '/config.local.php';
}

defined('DB_HOST') || define('DB_HOST', '127.0.0.1');
defined('DB_PORT') || define('DB_PORT', 3306);
defined('DB_NAME') || define('DB_NAME', 'smart_lost_and_found');
defined('DB_USER') || define('DB_USER', 'root');
defined('DB_PASS') || define('DB_PASS', '');

// Only emails ending with this domain may register (students use a subdomain)
defined('UNIVERSITY_EMAIL_DOMAIN') || define('UNIVERSITY_EMAIL_DOMAIN', 'university.edu');

const FEED_PAGE_SIZE = 9;

// Uploaded item photos are stored here and saved in item_images.image_url
const UPLOAD_DIR = __DIR__ . '/uploads/items';
const UPLOAD_URL = 'uploads/items';
const UPLOAD_MAX_BYTES = 5 * 1024 * 1024;

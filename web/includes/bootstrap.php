<?php
declare(strict_types=1);

require __DIR__ . '/../config.php';

session_start();

// ---------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------
function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $dsn = 'mysql:host=' . DB_HOST . ';port=' . DB_PORT . ';dbname=' . DB_NAME . ';charset=utf8mb4';
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
    }
    return $pdo;
}

// Runs a stored procedure and returns every result set it produced
function call_procedure(string $sql, array $params = []): array
{
    $stmt = db()->prepare($sql);
    $stmt->execute($params);
    $results = [];
    do {
        if ($stmt->columnCount() > 0) {
            $results[] = $stmt->fetchAll();
        }
    } while ($stmt->nextRowset());
    $stmt->closeCursor();
    return $results;
}

// Turns database errors into messages a user can read.
// Business-rule errors raised by triggers (SIGNAL, error 1644) are shown as-is.
function db_error_message(PDOException $e): string
{
    $code = $e->errorInfo[1] ?? null;
    $text = $e->errorInfo[2] ?? '';
    if ($code === 1644) {
        return $text;
    }
    if ($code === 1062) {
        return 'That record already exists.';
    }
    if ($code === 3819 || $code === 4025) {
        return 'The data breaks a database rule: ' . $text;
    }
    error_log($e->getMessage());
    return 'Something went wrong while saving. Please try again.';
}

function categories(): array
{
    return db()->query('SELECT category_id, category_name FROM categories ORDER BY category_name')->fetchAll();
}

function locations(): array
{
    return db()->query('SELECT location_id, building_name, department_counter, room_number, hours
                        FROM locations ORDER BY building_name')->fetchAll();
}

// ---------------------------------------------------------------------
// Sessions, roles and CSRF
// ---------------------------------------------------------------------
function current_user(): ?array
{
    return $_SESSION['user'] ?? null;
}

function is_admin(): bool
{
    return (current_user()['role'] ?? '') === 'ADMIN';
}

function require_login(): array
{
    $user = current_user();
    if ($user === null) {
        redirect('login.php');
    }
    return $user;
}

function require_admin(): array
{
    $user = require_login();
    if ($user['role'] !== 'ADMIN') {
        flash('error', 'That page is for counter admins only.');
        redirect('feed.php');
    }
    return $user;
}

function csrf_field(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return '<input type="hidden" name="csrf" value="' . $_SESSION['csrf'] . '">';
}

function check_csrf(): void
{
    if (!hash_equals($_SESSION['csrf'] ?? '', $_POST['csrf'] ?? '')) {
        http_response_code(400);
        exit('Invalid form submission. Go back, refresh the page and try again.');
    }
}

// ---------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------
function e(mixed $value): string
{
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}

function redirect(string $url): never
{
    header('Location: ' . $url);
    exit;
}

function flash(string $type, string $message): void
{
    $_SESSION['flash'][] = ['type' => $type, 'message' => $message];
}

function take_flashes(): array
{
    $messages = $_SESSION['flash'] ?? [];
    unset($_SESSION['flash']);
    return $messages;
}

// Returns the URL if the photo exists on disk, otherwise null (sample data has no real files)
function image_src(?string $url): ?string
{
    if ($url === null || $url === '' || str_contains($url, '..')) {
        return null;
    }
    return is_file(__DIR__ . '/../' . $url) ? $url : null;
}

// Photo box: shows the image, or the fallback text (usually the category) when there is none
function photo_html(?string $url, string $fallback, string $class = ''): string
{
    $src = image_src($url);
    $inner = $src ? '<img src="' . e($src) . '" alt="" loading="lazy">' : e($fallback);
    return '<div class="photo ' . e($class) . '">' . $inner . '</div>';
}

function status_badge(string $status): string
{
    return '<span class="badge badge-' . strtolower(e($status)) . '">' . e($status) . '</span>';
}

function format_date(?string $date): string
{
    return $date ? date('j M Y', strtotime($date)) : '—';
}

function input(string $key, string $default = ''): string
{
    return trim((string)($_POST[$key] ?? $_GET[$key] ?? $default));
}

// Returns the value if it is a real YYYY-MM-DD date, otherwise ''
function valid_date(string $value): string
{
    $d = DateTime::createFromFormat('!Y-m-d', $value);
    return ($d && $d->format('Y-m-d') === $value) ? $value : '';
}

// Saves an uploaded photo and returns its URL, null when nothing was uploaded
function save_upload(string $field): ?string
{
    $file = $_FILES[$field] ?? null;
    if ($file === null || $file['error'] === UPLOAD_ERR_NO_FILE) {
        return null;
    }
    if ($file['error'] !== UPLOAD_ERR_OK || $file['size'] > UPLOAD_MAX_BYTES) {
        throw new RuntimeException('The photo could not be uploaded (max 5 MB).');
    }
    $types = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
    $mime = (new finfo(FILEINFO_MIME_TYPE))->file($file['tmp_name']);
    if (!isset($types[$mime])) {
        throw new RuntimeException('Photos must be JPG, PNG or WebP.');
    }
    if (!is_dir(UPLOAD_DIR)) {
        mkdir(UPLOAD_DIR, 0775, true);
    }
    $name = bin2hex(random_bytes(10)) . '.' . $types[$mime];
    if (!move_uploaded_file($file['tmp_name'], UPLOAD_DIR . '/' . $name)) {
        throw new RuntimeException('The photo could not be saved.');
    }
    return UPLOAD_URL . '/' . $name;
}

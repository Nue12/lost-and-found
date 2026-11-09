<?php
require __DIR__ . '/includes/bootstrap.php';
$user = require_login();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    redirect('index.php');
}
check_csrf();

$id = (int)input('id');
$stmt = db()->prepare('SELECT report_type, title FROM items WHERE item_id = ?');
$stmt->execute([$id]);
$item = $stmt->fetch();
$back = $item && $item['report_type'] === 'FOUND' ? 'admin_inventory.php' : 'my_reports.php';

// Remember the photos before the rows are deleted, so the files can be removed too
$imgStmt = db()->prepare('SELECT image_url FROM item_images WHERE item_id = ?');
$imgStmt->execute([$id]);
$imageUrls = $imgStmt->fetchAll(PDO::FETCH_COLUMN);

try {
    // sp_delete_item checks that this user created the item and that it isn't RETURNED
    call_procedure('CALL sp_delete_item(?, ?)', [$user['id'], $id]);
} catch (PDOException $e) {
    flash('error', db_error_message($e));
    redirect($item ? 'item.php?id=' . $id : $back);
}

foreach ($imageUrls as $url) {
    $path = __DIR__ . '/' . $url;
    // Only remove files that were uploaded through the app
    if (str_starts_with($url, UPLOAD_URL . '/') && is_file($path)) {
        unlink($path);
    }
}

flash('success', "Deleted \"{$item['title']}\".");
redirect($back);

<?php
/** @var string $pageTitle */
$user = current_user();
$current = basename($_SERVER['SCRIPT_NAME']);

function nav_link(string $href, string $label, string $current): string
{
    $active = $href === $current ? ' class="active"' : '';
    return '<a href="' . $href . '"' . $active . '>' . e($label) . '</a>';
}
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?= e($pageTitle) ?> · Smart Lost &amp; Found</title>
  <link rel="stylesheet" href="assets/style.css">
</head>
<body>
<header class="topbar">
  <div class="container topbar-inner">
    <a class="brand" href="<?= $user ? 'feed.php' : 'login.php' ?>">
      <span class="brand-mark">L&amp;F</span> Smart Lost &amp; Found
    </a>
    <?php if ($user): ?>
      <nav class="nav">
        <?= nav_link('feed.php', 'Feed', $current) ?>
        <?php if ($user['role'] === 'ADMIN'): ?>
          <?= nav_link('admin_log_found.php', 'Log found item', $current) ?>
          <?= nav_link('admin_inventory.php', 'Inventory', $current) ?>
          <?= nav_link('admin_activity.php', 'Activity', $current) ?>
        <?php else: ?>
          <?= nav_link('report_lost.php', 'Report lost item', $current) ?>
          <?= nav_link('my_reports.php', 'My reports', $current) ?>
        <?php endif; ?>
      </nav>
      <div class="user-box">
        <span class="user-email"><?= e($user['email']) ?>
          <?php if ($user['role'] === 'ADMIN'): ?><small><?= e($user['counter']) ?></small><?php endif; ?>
        </span>
        <form method="post" action="logout.php"><?= csrf_field() ?><button class="btn btn-ghost btn-sm">Log out</button></form>
      </div>
    <?php endif; ?>
  </div>
</header>
<main class="container">
<?php foreach (take_flashes() as $f): ?>
  <div class="alert alert-<?= e($f['type']) ?>"><?= e($f['message']) ?></div>
<?php endforeach; ?>

<?php
require __DIR__ . '/includes/bootstrap.php';
$user = require_login();

// ---------------------------------------------------------------------
// Filters (workflow step 3) — every filter is optional
// ---------------------------------------------------------------------
$filters = [
    'q'        => input('q'),
    'category' => input('category'),
    'holding'  => input('holding'),
    'found_at' => input('found_at'),
    'color'    => input('color'),
    'from'     => valid_date(input('from')),
    'to'       => valid_date(input('to')),
];
$page = max(1, (int)input('page', '1'));

$where = [];
$params = [];
if ($filters['q'] !== '') {
    $where[] = '(title LIKE ? OR public_description LIKE ?)';
    $params[] = '%' . $filters['q'] . '%';
    $params[] = '%' . $filters['q'] . '%';
}
if ($filters['category'] !== '') {
    $where[] = 'category_id = ?';
    $params[] = (int)$filters['category'];
}
if ($filters['holding'] !== '') {
    $where[] = 'holding_location_id = ?';
    $params[] = (int)$filters['holding'];
}
if ($filters['found_at'] !== '') {
    $where[] = 'event_location_id = ?';
    $params[] = (int)$filters['found_at'];
}
if ($filters['color'] !== '') {
    $where[] = 'color = ?';
    $params[] = $filters['color'];
}
if ($filters['from'] !== '') {
    $where[] = 'found_date >= ?';
    $params[] = $filters['from'];
}
if ($filters['to'] !== '') {
    $where[] = 'found_date <= ?';
    $params[] = $filters['to'];
}
$whereSql = $where ? 'WHERE ' . implode(' AND ', $where) : '';

$count = db()->prepare("SELECT COUNT(*) FROM v_public_feed $whereSql");
$count->execute($params);
$total = (int)$count->fetchColumn();
$pages = max(1, (int)ceil($total / FEED_PAGE_SIZE));
$page = min($page, $pages);
$offset = ($page - 1) * FEED_PAGE_SIZE;

$stmt = db()->prepare("SELECT * FROM v_public_feed $whereSql
                       ORDER BY found_date DESC, item_id DESC
                       LIMIT " . FEED_PAGE_SIZE . " OFFSET $offset");
$stmt->execute($params);
$items = $stmt->fetchAll();

$colors = db()->query("SELECT DISTINCT color FROM items
                       WHERE report_type = 'FOUND' AND status = 'AVAILABLE' AND color IS NOT NULL
                       ORDER BY color")->fetchAll(PDO::FETCH_COLUMN);
$categories = categories();
$locations = locations();

function page_url(int $page, array $filters): string
{
    return 'feed.php?' . http_build_query(array_filter($filters, 'strlen') + ['page' => $page]);
}

$pageTitle = 'Campus feed';
require __DIR__ . '/includes/header.php';
?>
<div class="page-head">
  <div>
    <h1>Found on campus</h1>
    <p class="muted"><?= $total ?> item<?= $total === 1 ? '' : 's' ?> waiting at a lost &amp; found counter. Every item is in staff custody.</p>
  </div>
  <?php if (!is_admin()): ?>
    <a class="btn" href="report_lost.php">Can't find yours? Report it</a>
  <?php endif; ?>
</div>

<form class="filters card" method="get">
  <label>Keyword
    <input type="search" name="q" value="<?= e($filters['q']) ?>" placeholder="wallet, laptop…">
  </label>
  <label>Category
    <select name="category">
      <option value="">All</option>
      <?php foreach ($categories as $c): ?>
        <option value="<?= $c['category_id'] ?>" <?= $filters['category'] == $c['category_id'] ? 'selected' : '' ?>><?= e($c['category_name']) ?></option>
      <?php endforeach; ?>
    </select>
  </label>
  <label>Held at
    <select name="holding">
      <option value="">Any counter</option>
      <?php foreach ($locations as $l): ?>
        <option value="<?= $l['location_id'] ?>" <?= $filters['holding'] == $l['location_id'] ? 'selected' : '' ?>><?= e($l['building_name']) ?></option>
      <?php endforeach; ?>
    </select>
  </label>
  <label>Found at
    <select name="found_at">
      <option value="">Anywhere</option>
      <?php foreach ($locations as $l): ?>
        <option value="<?= $l['location_id'] ?>" <?= $filters['found_at'] == $l['location_id'] ? 'selected' : '' ?>><?= e($l['building_name']) ?></option>
      <?php endforeach; ?>
    </select>
  </label>
  <label>Color
    <select name="color">
      <option value="">Any</option>
      <?php foreach ($colors as $color): ?>
        <option <?= $filters['color'] === $color ? 'selected' : '' ?>><?= e($color) ?></option>
      <?php endforeach; ?>
    </select>
  </label>
  <label>From
    <input type="date" name="from" value="<?= e($filters['from']) ?>">
  </label>
  <label>To
    <input type="date" name="to" value="<?= e($filters['to']) ?>">
  </label>
  <div class="actions">
    <button class="btn">Filter</button>
    <a class="btn btn-light" href="feed.php">Clear</a>
  </div>
</form>

<?php if (!$items): ?>
  <div class="card empty">
    No items match these filters.
    <?php if (!is_admin()): ?><br><a href="report_lost.php">Submit a lost report</a> and we'll alert you if it turns up.<?php endif; ?>
  </div>
<?php else: ?>
  <div class="grid">
    <?php foreach ($items as $item): ?>
      <a class="card item-card" href="item.php?id=<?= $item['item_id'] ?>">
        <?= photo_html($item['image_url'], $item['category_name']) ?>
        <div class="body">
          <h3><?= e($item['title']) ?></h3>
          <div class="chips">
            <span class="chip"><?= e($item['category_name']) ?></span>
            <?php if ($item['color']): ?><span class="chip"><?= e($item['color']) ?></span><?php endif; ?>
            <span class="chip">Found <?= format_date($item['found_date']) ?></span>
          </div>
          <p class="desc"><?= e($item['public_description']) ?></p>
          <div class="where">
            <strong>Pick up:</strong> <?= e($item['holding_building']) ?> · <?= e($item['holding_counter']) ?><?php if ($item['holding_room']): ?>, room <?= e($item['holding_room']) ?><?php endif; ?>
          </div>
        </div>
      </a>
    <?php endforeach; ?>
  </div>

  <?php if ($pages > 1): ?>
    <nav class="pagination">
      <?php if ($page > 1): ?><a href="<?= e(page_url($page - 1, $filters)) ?>">‹ Prev</a><?php endif; ?>
      <?php for ($p = 1; $p <= $pages; $p++): ?>
        <?php if ($p === $page): ?><span class="current"><?= $p ?></span>
        <?php else: ?><a href="<?= e(page_url($p, $filters)) ?>"><?= $p ?></a><?php endif; ?>
      <?php endfor; ?>
      <?php if ($page < $pages): ?><a href="<?= e(page_url($page + 1, $filters)) ?>">Next ›</a><?php endif; ?>
    </nav>
  <?php endif; ?>
<?php endif; ?>
<?php require __DIR__ . '/includes/footer.php'; ?>

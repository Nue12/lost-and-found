<?php
require __DIR__ . '/includes/bootstrap.php';
$user = require_admin();

// Every admin sees every student's lost report, campus-wide, so any counter
// can spot an item it is holding (or one that is handed in later)
$tabs = ['OPEN' => 'Open', 'RETURNED' => 'Returned', 'EXPIRED' => 'Expired', 'ALL' => 'All'];
$status = strtoupper(input('status', 'OPEN'));
if (!isset($tabs[$status])) {
    $status = 'OPEN';
}
$filters = [
    'q'        => input('q'),
    'category' => input('category'),
    'lost_at'  => input('lost_at'),
];

$where = ["i.report_type = 'LOST'"];
$params = [$user['location_id']];   // for the "at your counter" count below
if ($status !== 'ALL') {
    $where[] = 'i.status = ?';
    $params[] = $status;
}
if ($filters['q'] !== '') {
    $where[] = '(i.title LIKE ? OR i.public_description LIKE ?)';
    $params[] = '%' . $filters['q'] . '%';
    $params[] = '%' . $filters['q'] . '%';
}
if ($filters['category'] !== '') {
    $where[] = 'i.category_id = ?';
    $params[] = (int)$filters['category'];
}
if ($filters['lost_at'] !== '') {
    $where[] = 'i.event_location_id = ?';
    $params[] = (int)$filters['lost_at'];
}

$stmt = db()->prepare(
    "SELECT i.item_id, i.title, i.public_description, i.color, i.event_date, i.status,
            c.category_name, u.university_email AS reported_by,
            CONCAT(el.building_name, ' - ', el.department_counter) AS lost_near,
            (SELECT MAX(m.match_score) FROM matches m WHERE m.lost_item_id = i.item_id) AS best_score,
            (SELECT COUNT(*) FROM matches m
             JOIN items f ON f.item_id = m.found_item_id
             WHERE m.lost_item_id = i.item_id
               AND f.holding_location_id = ? AND f.status = 'AVAILABLE') AS at_my_counter
     FROM items i
     JOIN users u           ON u.user_id = i.creator_user_id
     JOIN categories c      ON c.category_id = i.category_id
     LEFT JOIN locations el ON el.location_id = i.event_location_id
     WHERE " . implode(' AND ', $where) . "
     ORDER BY i.event_date DESC, i.item_id DESC"
);
$stmt->execute($params);
$reports = $stmt->fetchAll();

$counts = db()->query("SELECT status, COUNT(*) AS n FROM items WHERE report_type = 'LOST' GROUP BY status")->fetchAll();
$counts = array_column($counts, 'n', 'status');
$counts['ALL'] = array_sum($counts);

$categories = categories();
$locations = locations();

$pageTitle = 'Lost reports';
require __DIR__ . '/includes/header.php';
?>
<div class="page-head">
  <div>
    <h1>Lost reports</h1>
    <p class="muted">Every student's lost report across campus. Check whether your counter is holding any of these items.</p>
  </div>
</div>

<nav class="tabs">
  <?php foreach ($tabs as $key => $label): ?>
    <a href="?<?= e(http_build_query(['status' => $key] + array_filter($filters, 'strlen'))) ?>" class="<?= $status === $key ? 'active' : '' ?>"><?= $label ?> (<?= (int)($counts[$key] ?? 0) ?>)</a>
  <?php endforeach; ?>
</nav>

<form class="filters card" method="get">
  <input type="hidden" name="status" value="<?= e($status) ?>">
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
  <label>Lost near
    <select name="lost_at">
      <option value="">Anywhere</option>
      <?php foreach ($locations as $l): ?>
        <option value="<?= $l['location_id'] ?>" <?= $filters['lost_at'] == $l['location_id'] ? 'selected' : '' ?>><?= e($l['building_name']) ?></option>
      <?php endforeach; ?>
    </select>
  </label>
  <div class="actions">
    <button class="btn">Filter</button>
    <a class="btn btn-light" href="admin_lost_reports.php?status=<?= e($status) ?>">Clear</a>
  </div>
</form>

<?php if (!$reports): ?>
  <div class="card empty">No lost reports here.</div>
<?php else: ?>
  <div class="table-wrap">
    <table>
      <tr><th>Report</th><th>Category</th><th>Lost near</th><th>Lost on</th><th>Reported by</th><th>Best match</th><th>Status</th></tr>
      <?php foreach ($reports as $r): ?>
        <tr>
          <td><a href="item.php?id=<?= $r['item_id'] ?>"><?= e($r['title']) ?></a>
            <?php if ($r['public_description']): ?><br><small class="muted"><?= e(mb_strimwidth($r['public_description'], 0, 60, '…')) ?></small><?php endif; ?>
          </td>
          <td><?= e($r['category_name']) ?><?= $r['color'] ? ' · ' . e($r['color']) : '' ?></td>
          <td><?= e($r['lost_near'] ?? 'Not sure') ?></td>
          <td><?= format_date($r['event_date']) ?></td>
          <td><?= e($r['reported_by']) ?></td>
          <td>
            <?php if ($r['best_score'] !== null): ?>
              <span class="score"><?= (int)$r['best_score'] ?>%</span>
              <?php if ($r['at_my_counter'] > 0): ?><br><span class="badge badge-open">At your counter</span><?php endif; ?>
            <?php else: ?><span class="muted">None yet</span><?php endif; ?>
          </td>
          <td><?= status_badge($r['status']) ?></td>
        </tr>
      <?php endforeach; ?>
    </table>
  </div>
<?php endif; ?>
<?php require __DIR__ . '/includes/footer.php'; ?>

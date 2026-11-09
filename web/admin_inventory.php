<?php
require __DIR__ . '/includes/bootstrap.php';
$user = require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['expire'])) {
    check_csrf();
    $count = (int)call_procedure('CALL sp_expire_items()')[0][0]['items_expired'];
    flash('success', $count === 0 ? 'No items are past their expiration date.' : "$count item(s) marked EXPIRED.");
    redirect('admin_inventory.php');
}

$tabs = ['AVAILABLE' => 'Available', 'RETURNED' => 'Returned', 'EXPIRED' => 'Expired', 'ALL' => 'All'];
$status = strtoupper(input('status', 'AVAILABLE'));
if (!isset($tabs[$status])) {
    $status = 'AVAILABLE';
}

$sql = 'SELECT * FROM v_admin_inventory WHERE holding_location_id = ?';
$params = [$user['location_id']];
if ($status !== 'ALL') {
    $sql .= ' AND status = ?';
    $params[] = $status;
}
$sql .= ' ORDER BY event_date DESC, item_id DESC';
$stmt = db()->prepare($sql);
$stmt->execute($params);
$items = $stmt->fetchAll();

$counts = db()->prepare('SELECT status, COUNT(*) AS n FROM v_admin_inventory WHERE holding_location_id = ? GROUP BY status');
$counts->execute([$user['location_id']]);
$counts = array_column($counts->fetchAll(), 'n', 'status');
$counts['ALL'] = array_sum($counts);

$pageTitle = 'Inventory';
require __DIR__ . '/includes/header.php';
?>
<div class="page-head">
  <div>
    <h1>Counter inventory</h1>
    <p class="muted"><?= e($user['counter']) ?></p>
  </div>
  <div style="display:flex;gap:8px;flex-wrap:wrap">
    <form method="post" onsubmit="return confirm('Mark every item past its expiration date as EXPIRED?')">
      <?= csrf_field() ?><button class="btn btn-light" name="expire" value="1">Run expiration now</button>
    </form>
    <a class="btn" href="admin_log_found.php">+ Log found item</a>
  </div>
</div>

<nav class="tabs">
  <?php foreach ($tabs as $key => $label): ?>
    <a href="?status=<?= $key ?>" class="<?= $status === $key ? 'active' : '' ?>"><?= $label ?> (<?= (int)($counts[$key] ?? 0) ?>)</a>
  <?php endforeach; ?>
</nav>

<?php if (!$items): ?>
  <div class="card empty">Nothing here.</div>
<?php else: ?>
  <div class="table-wrap">
    <table>
      <tr><th>Item</th><th>Category</th><th>Found</th><th>Expires</th><th>Matches</th><th>Status</th><th></th></tr>
      <?php foreach ($items as $i): ?>
        <tr>
          <td><a href="item.php?id=<?= $i['item_id'] ?>"><?= e($i['title']) ?></a>
            <?php if ($i['private_notes']): ?><br><small class="muted">🔒 <?= e(mb_strimwidth($i['private_notes'], 0, 60, '…')) ?></small><?php endif; ?>
          </td>
          <td><?= e($i['category_name']) ?><?= $i['color'] ? ' · ' . e($i['color']) : '' ?></td>
          <td><?= format_date($i['event_date']) ?></td>
          <td>
            <?= format_date($i['expiration_date']) ?>
            <?php if ($i['status'] === 'AVAILABLE'): ?>
              <br><small class="muted"><?= $i['days_until_expiry'] < 0 ? 'overdue' : (int)$i['days_until_expiry'] . ' days left' ?></small>
            <?php endif; ?>
          </td>
          <td><?= (int)$i['match_count'] ?></td>
          <td><?= status_badge($i['status']) ?></td>
          <td style="white-space:nowrap">
            <?php if ($i['status'] === 'AVAILABLE'): ?><a class="btn btn-sm" href="admin_handover.php?id=<?= $i['item_id'] ?>">Hand over</a><?php endif; ?>
            <?php if ($i['logged_by'] === $user['email'] && $i['status'] !== 'RETURNED'): ?><?= delete_button($i['item_id'], $i['title']) ?><?php endif; ?>
          </td>
        </tr>
      <?php endforeach; ?>
    </table>
  </div>
<?php endif; ?>
<?php require __DIR__ . '/includes/footer.php'; ?>

<?php
require __DIR__ . '/includes/bootstrap.php';
$user = require_login();

$notifications = call_procedure('CALL sp_get_notifications(?)', [$user['id']])[0] ?? [];

$stmt = db()->prepare(
    "SELECT i.item_id, i.title, c.category_name, i.color, i.event_date, i.expiration_date, i.status,
            (SELECT COUNT(*) FROM matches m WHERE m.lost_item_id = i.item_id) AS match_count
     FROM items i
     JOIN categories c ON c.category_id = i.category_id
     WHERE i.report_type = 'LOST' AND i.creator_user_id = ?
     ORDER BY i.status = 'OPEN' DESC, i.event_date DESC"
);
$stmt->execute([$user['id']]);
$reports = $stmt->fetchAll();

$stmt = db()->prepare('SELECT * FROM v_return_history WHERE recipient = ? ORDER BY handover_timestamp DESC');
$stmt->execute([$user['email']]);
$returns = $stmt->fetchAll();

$pageTitle = 'My reports';
require __DIR__ . '/includes/header.php';
?>
<div class="page-head">
  <div><h1>My reports</h1><p class="muted">Your lost reports, match alerts and collected items.</p></div>
  <a class="btn" href="report_lost.php">Report a lost item</a>
</div>

<h2>Match alerts</h2>
<?php if (!$notifications): ?>
  <div class="card empty">No alerts right now. We'll notify you here when a counter logs a strong match.</div>
<?php else: ?>
  <div class="stack">
    <?php foreach ($notifications as $n): ?>
      <div class="notice">
        <span class="score"><?= (int)$n['match_score'] ?>% match</span> · <?= e($n['message']) ?>
        <br><a href="item.php?id=<?= $n['found_item_id'] ?>">View the found item</a>
      </div>
    <?php endforeach; ?>
  </div>
<?php endif; ?>

<h2>Lost reports</h2>
<?php if (!$reports): ?>
  <div class="card empty">You haven't reported anything lost.</div>
<?php else: ?>
  <div class="table-wrap">
    <table>
      <tr><th>Item</th><th>Category</th><th>Lost on</th><th>Matches</th><th>Status</th><th>Listed until</th><th></th></tr>
      <?php foreach ($reports as $r): ?>
        <tr>
          <td><a href="item.php?id=<?= $r['item_id'] ?>"><?= e($r['title']) ?></a></td>
          <td><?= e($r['category_name']) ?><?= $r['color'] ? ' · ' . e($r['color']) : '' ?></td>
          <td><?= format_date($r['event_date']) ?></td>
          <td><?= (int)$r['match_count'] ?></td>
          <td><?= status_badge($r['status']) ?></td>
          <td><?= format_date($r['expiration_date']) ?></td>
          <td><?= $r['status'] !== 'RETURNED' ? delete_button($r['item_id'], $r['title']) : '' ?></td>
        </tr>
      <?php endforeach; ?>
    </table>
  </div>
<?php endif; ?>

<?php if ($returns): ?>
  <h2>Items you collected</h2>
  <div class="table-wrap">
    <table>
      <tr><th>Item</th><th>Counter</th><th>Collected</th></tr>
      <?php foreach ($returns as $r): ?>
        <tr><td><?= e($r['item_title']) ?></td><td><?= e($r['counter']) ?></td><td><?= e(date('j M Y, H:i', strtotime($r['handover_timestamp']))) ?></td></tr>
      <?php endforeach; ?>
    </table>
  </div>
<?php endif; ?>
<?php require __DIR__ . '/includes/footer.php'; ?>

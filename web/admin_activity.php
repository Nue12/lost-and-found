<?php
require __DIR__ . '/includes/bootstrap.php';
$user = require_admin();

$stmt = db()->prepare(
    "SELECT r.* FROM v_return_history r
     JOIN items f ON f.item_id = r.found_item_id
     WHERE f.holding_location_id = ?
     ORDER BY r.handover_timestamp DESC"
);
$stmt->execute([$user['location_id']]);
$returns = $stmt->fetchAll();

// Audit trail for items held at this counter
$stmt = db()->prepare(
    "SELECT a.* FROM v_audit_trail a
     JOIN items i ON i.item_id = a.target_item_id
     WHERE i.holding_location_id = ?
     ORDER BY a.log_id DESC
     LIMIT 100"
);
$stmt->execute([$user['location_id']]);
$logs = $stmt->fetchAll();

$pageTitle = 'Activity';
require __DIR__ . '/includes/header.php';
?>
<div class="page-head">
  <div><h1>Counter activity</h1><p class="muted"><?= e($user['counter']) ?></p></div>
</div>

<h2>Handover history</h2>
<?php if (!$returns): ?>
  <div class="card empty">No handovers yet.</div>
<?php else: ?>
  <div class="table-wrap">
    <table>
      <tr><th>When</th><th>Item</th><th>Recipient</th><th>Verified by</th><th>Proof</th></tr>
      <?php foreach ($returns as $r): ?>
        <tr>
          <td><?= e(date('j M Y, H:i', strtotime($r['handover_timestamp']))) ?></td>
          <td><a href="item.php?id=<?= $r['found_item_id'] ?>"><?= e($r['item_title']) ?></a></td>
          <td><?= e($r['recipient']) ?></td>
          <td><?= e($r['verified_by']) ?></td>
          <td><?= e($r['verification_notes']) ?></td>
        </tr>
      <?php endforeach; ?>
    </table>
  </div>
<?php endif; ?>

<h2>Audit log <small class="muted">(latest 100)</small></h2>
<?php if (!$logs): ?>
  <div class="card empty">No activity yet.</div>
<?php else: ?>
  <div class="table-wrap">
    <table>
      <tr><th>When</th><th>Who</th><th>Item</th><th>Action</th></tr>
      <?php foreach ($logs as $l): ?>
        <tr>
          <td><?= e(date('j M Y, H:i', strtotime($l['timestamp']))) ?></td>
          <td><?= e($l['actor']) ?></td>
          <td><a href="item.php?id=<?= $l['target_item_id'] ?>"><?= e($l['item_title']) ?></a></td>
          <td><?= e($l['action_description']) ?></td>
        </tr>
      <?php endforeach; ?>
    </table>
  </div>
<?php endif; ?>
<?php require __DIR__ . '/includes/footer.php'; ?>

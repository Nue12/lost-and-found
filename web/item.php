<?php
require __DIR__ . '/includes/bootstrap.php';
$user = require_login();

$id = (int)input('id');
$stmt = db()->prepare(
    "SELECT i.*, c.category_name,
            el.building_name AS event_building, el.department_counter AS event_counter,
            hl.building_name AS holding_building, hl.department_counter AS holding_counter,
            hl.room_number AS holding_room, hl.hours AS holding_hours,
            u.university_email AS creator_email
     FROM items i
     JOIN categories c      ON c.category_id = i.category_id
     JOIN users u           ON u.user_id = i.creator_user_id
     LEFT JOIN locations el ON el.location_id = i.event_location_id
     LEFT JOIN locations hl ON hl.location_id = i.holding_location_id
     WHERE i.item_id = ?"
);
$stmt->execute([$id]);
$item = $stmt->fetch();

// Who may see what:
//  - FOUND + AVAILABLE: everyone logged in. Other statuses: admins only.
//  - LOST reports: the student who filed it, and admins.
//  - Private notes and private photos: only the admin of the holding counter.
$isOwner = $item && (int)$item['creator_user_id'] === $user['id'];
$canView = $item && (
    is_admin()
    || ($item['report_type'] === 'FOUND' && $item['status'] === 'AVAILABLE')
    || ($item['report_type'] === 'LOST' && $isOwner)
);
if (!$canView) {
    http_response_code(404);
    $pageTitle = 'Not found';
    require __DIR__ . '/includes/header.php';
    echo '<div class="card empty">This item is not available. <a href="feed.php">Back to the feed</a></div>';
    require __DIR__ . '/includes/footer.php';
    exit;
}

$isHoldingAdmin = is_admin() && $item['holding_location_id'] !== null
    && (int)$item['holding_location_id'] === $user['location_id'];

$imgStmt = db()->prepare('SELECT image_url, is_public FROM item_images WHERE item_id = ? ORDER BY image_id');
$imgStmt->execute([$id]);
$images = array_values(array_filter($imgStmt->fetchAll(),
    fn($img) => $img['is_public'] || $isHoldingAdmin));

// Matches: the holding admin sees matching lost reports; the lost-report owner sees matching found items
$matches = [];
if ($item['report_type'] === 'FOUND' && $isHoldingAdmin) {
    $m = db()->prepare(
        "SELECT m.match_score, l.item_id, l.title, l.status, u.university_email AS owner
         FROM matches m
         JOIN items l ON l.item_id = m.lost_item_id
         JOIN users u ON u.user_id = l.creator_user_id
         WHERE m.found_item_id = ? ORDER BY m.match_score DESC"
    );
    $m->execute([$id]);
    $matches = $m->fetchAll();
} elseif ($item['report_type'] === 'LOST' && ($isOwner || is_admin())) {
    $m = db()->prepare(
        "SELECT m.match_score, f.item_id, f.title, f.status,
                CONCAT(hl.building_name, ' - ', hl.department_counter) AS counter
         FROM matches m
         JOIN items f      ON f.item_id = m.found_item_id
         JOIN locations hl ON hl.location_id = f.holding_location_id
         WHERE m.lost_item_id = ? ORDER BY m.match_score DESC"
    );
    $m->execute([$id]);
    $matches = $m->fetchAll();
}

$pageTitle = $item['title'];
require __DIR__ . '/includes/header.php';
?>
<?php
if ($item['report_type'] === 'LOST') {
    $back = is_admin() ? 'admin_lost_reports.php' : 'my_reports.php';
} else {
    $back = is_admin() ? 'admin_inventory.php' : 'feed.php';
}
?>
<p><a href="<?= $back ?>">‹ Back</a></p>

<div class="two-col">
  <div class="stack">
    <?= photo_html($images[0]['image_url'] ?? null, $item['category_name'], 'photo-lg') ?>
    <?php if (count($images) > 1): ?>
      <div class="photo-row">
        <?php foreach (array_slice($images, 1) as $img): ?>
          <?= photo_html($img['image_url'], $img['is_public'] ? 'Photo' : 'Private photo') ?>
        <?php endforeach; ?>
      </div>
    <?php endif; ?>
  </div>

  <div class="stack">
    <div class="card stack">
      <div>
        <span class="chip"><?= $item['report_type'] === 'FOUND' ? 'Found item' : 'Lost report' ?></span>
        <?= status_badge($item['status']) ?>
      </div>
      <h1><?= e($item['title']) ?></h1>
      <p><?= nl2br(e($item['public_description'])) ?></p>
      <dl class="facts">
        <dt>Category</dt><dd><?= e($item['category_name']) ?></dd>
        <dt>Color</dt><dd><?= e($item['color'] ?: '—') ?></dd>
        <dt><?= $item['report_type'] === 'FOUND' ? 'Found at' : 'Lost near' ?></dt>
        <dd><?= $item['event_building'] ? e($item['event_building'] . ' - ' . $item['event_counter']) : 'Not sure' ?></dd>
        <dt><?= $item['report_type'] === 'FOUND' ? 'Found on' : 'Lost on' ?></dt><dd><?= format_date($item['event_date']) ?></dd>
        <dt>Listed until</dt><dd><?= format_date($item['expiration_date']) ?></dd>
        <?php if (is_admin()): ?><dt><?= $item['report_type'] === 'FOUND' ? 'Logged by' : 'Reported by' ?></dt><dd><?= e($item['creator_email']) ?></dd><?php endif; ?>
      </dl>
    </div>

    <?php if ($item['report_type'] === 'FOUND'): ?>
      <div class="notice">
        <strong>How to claim it</strong><br>
        Go to <strong><?= e($item['holding_building']) ?> · <?= e($item['holding_counter']) ?></strong>
        <?php if ($item['holding_room']): ?>(room <?= e($item['holding_room']) ?>)<?php endif; ?>
        <?php if ($item['holding_hours']): ?><br>Open <?= e($item['holding_hours']) ?><?php endif; ?>
        <br>Bring your university ID and be ready to describe details only the owner would know.
        There are no online claims, so the first person to prove ownership at the counter gets the item.
      </div>
    <?php endif; ?>

    <?php if ($isHoldingAdmin): ?>
      <div class="private-box">
        <h3>Private verification notes (staff only)</h3>
        <?= $item['private_notes'] ? nl2br(e($item['private_notes'])) : '<span class="muted">None recorded.</span>' ?>
      </div>
      <?php if ($item['status'] === 'AVAILABLE'): ?>
        <a class="btn" href="admin_handover.php?id=<?= $item['item_id'] ?>">Verify &amp; hand over</a>
      <?php endif; ?>
    <?php endif; ?>
  </div>
</div>

<?php if ($matches): ?>
  <h2><?= $item['report_type'] === 'FOUND' ? 'Matching lost reports' : 'Possible matches at a counter' ?></h2>
  <div class="table-wrap">
    <table>
      <tr><th>Score</th><th>Item</th><th><?= $item['report_type'] === 'FOUND' ? 'Reported by' : 'Held at' ?></th><th>Status</th></tr>
      <?php foreach ($matches as $m): ?>
        <tr>
          <td class="score"><?= (int)$m['match_score'] ?>%</td>
          <td>
            <?php if ($item['report_type'] === 'LOST' && $m['status'] === 'AVAILABLE' || is_admin()): ?>
              <a href="item.php?id=<?= $m['item_id'] ?>"><?= e($m['title']) ?></a>
            <?php else: ?><?= e($m['title']) ?><?php endif; ?>
          </td>
          <td><?= e($m['owner'] ?? $m['counter']) ?></td>
          <td><?= status_badge($m['status']) ?></td>
        </tr>
      <?php endforeach; ?>
    </table>
  </div>
<?php endif; ?>
<?php require __DIR__ . '/includes/footer.php'; ?>

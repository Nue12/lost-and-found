<?php
require __DIR__ . '/includes/bootstrap.php';
$user = require_admin();

$id = (int)input('id');
$stmt = db()->prepare("SELECT * FROM v_admin_inventory WHERE item_id = ? AND holding_location_id = ?");
$stmt->execute([$id, $user['location_id']]);
$item = $stmt->fetch();

if (!$item || $item['status'] !== 'AVAILABLE') {
    flash('error', 'That item is not available for handover at your counter.');
    redirect('admin_inventory.php');
}

$imgStmt = db()->prepare('SELECT image_url, is_public FROM item_images WHERE item_id = ? ORDER BY image_id');
$imgStmt->execute([$id]);
$images = $imgStmt->fetchAll();

// Open lost reports that matched this item (the claimant may be one of them)
$m = db()->prepare(
    "SELECT l.item_id, l.title, m.match_score, u.university_email
     FROM matches m
     JOIN items l ON l.item_id = m.lost_item_id
     JOIN users u ON u.user_id = l.creator_user_id
     WHERE m.found_item_id = ? AND l.status = 'OPEN'
     ORDER BY m.match_score DESC"
);
$m->execute([$id]);
$matches = $m->fetchAll();

$errors = [];
$form = [
    'email' => strtolower(input('email')),
    'lost'  => input('lost'),
    'notes' => input('notes'),
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $linkedLost = null;

    if ($form['lost'] !== '') {
        // Linking a matched lost report: the recipient is that report's owner
        foreach ($matches as $match) {
            if ((int)$match['item_id'] === (int)$form['lost']) {
                $linkedLost = (int)$match['item_id'];
                $form['email'] = $match['university_email'];
            }
        }
    }

    $recipient = db()->prepare('SELECT user_id FROM users WHERE university_email = ?');
    $recipient->execute([$form['email']]);
    $recipientId = $recipient->fetchColumn();

    if (!$recipientId) {
        $errors[] = 'No account uses that email. The claimant must register before collecting the item.';
    }
    if ($form['notes'] === '') {
        $errors[] = 'Summarise the proof the claimant gave.';
    }
    if (!isset($_POST['id_checked'])) {
        $errors[] = "Confirm that you checked the claimant's university ID.";
    }

    if (!$errors) {
        try {
            // Triggers check the counter and status, then mark the item (and linked report) RETURNED
            call_procedure('CALL sp_record_handover(?, ?, ?, ?, ?)',
                [$user['id'], $id, (int)$recipientId, $linkedLost, $form['notes']]);
            flash('success', "Handover recorded: \"{$item['title']}\" returned to {$form['email']}.");
            redirect('admin_inventory.php?status=RETURNED');
        } catch (PDOException $e) {
            $errors[] = db_error_message($e);
        }
    }
}

$pageTitle = 'Hand over item';
require __DIR__ . '/includes/header.php';
?>
<p><a href="admin_inventory.php">‹ Inventory</a></p>
<div class="page-head">
  <div>
    <h1>Verify &amp; hand over</h1>
    <p class="muted">Ask the claimant to describe hidden details or unlock the device, then compare with your private notes.</p>
  </div>
</div>
<?php foreach ($errors as $err): ?><div class="alert alert-error"><?= e($err) ?></div><?php endforeach; ?>

<div class="two-col">
  <div class="card stack">
    <h2 style="margin:0"><?= e($item['title']) ?></h2>
    <div class="chips">
      <span class="chip"><?= e($item['category_name']) ?></span>
      <?php if ($item['color']): ?><span class="chip"><?= e($item['color']) ?></span><?php endif; ?>
      <span class="chip">Found <?= format_date($item['event_date']) ?></span>
    </div>
    <p><?= nl2br(e($item['public_description'])) ?></p>
    <div class="private-box">
      <h3>Check the claimant's proof against</h3>
      <?= $item['private_notes'] ? nl2br(e($item['private_notes'])) : '<span class="muted">No private notes recorded.</span>' ?>
    </div>
    <?php if ($images): ?>
      <div class="photo-row">
        <?php foreach ($images as $img): ?><?= photo_html($img['image_url'], $img['is_public'] ? 'Photo' : 'Private photo') ?><?php endforeach; ?>
      </div>
    <?php endif; ?>
  </div>

  <form method="post" class="form card">
    <?= csrf_field() ?>
    <?php if ($matches): ?>
      <fieldset class="stack" style="border:0;padding:0;margin:0">
        <legend style="font-weight:600;margin-bottom:6px">Is the claimant one of these students?</legend>
        <?php foreach ($matches as $match): ?>
          <label class="check">
            <input type="radio" name="lost" value="<?= $match['item_id'] ?>" <?= $form['lost'] == $match['item_id'] ? 'checked' : '' ?>>
            <?= e($match['university_email']) ?> · "<?= e($match['title']) ?>" <span class="score"><?= (int)$match['match_score'] ?>%</span>
          </label>
        <?php endforeach; ?>
        <label class="check">
          <input type="radio" name="lost" value="" <?= $form['lost'] === '' ? 'checked' : '' ?>> Someone else (enter their email below)
        </label>
      </fieldset>
    <?php endif; ?>
    <label>Claimant's university email <small><?= $matches ? 'Only needed for "Someone else"' : 'They must have an account' ?></small>
      <input type="email" name="email" value="<?= e($form['email']) ?>">
    </label>
    <label>Proof summary
      <textarea name="notes" placeholder="e.g. Described the blue keychain inside; unlocked the phone in front of me." required><?= e($form['notes']) ?></textarea>
    </label>
    <label class="check"><input type="checkbox" name="id_checked" value="1"> I checked the claimant's university ID in person</label>
    <button class="btn">Confirm handover</button>
  </form>
</div>
<?php require __DIR__ . '/includes/footer.php'; ?>

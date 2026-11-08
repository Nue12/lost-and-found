<?php
require __DIR__ . '/includes/bootstrap.php';
$user = require_admin();

$errors = [];
$form = [
    'category' => input('category'),
    'location' => input('location', (string)$user['location_id']),
    'title'    => input('title'),
    'color'    => input('color'),
    'public'   => input('public'),
    'private'  => input('private'),
    'date'     => input('date', date('Y-m-d')),
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    if ($form['category'] === '') {
        $errors[] = 'Choose a category.';
    }
    if ($form['title'] === '') {
        $errors[] = 'Give the item a short title.';
    }
    if (valid_date($form['date']) === '' || $form['date'] > date('Y-m-d')) {
        $errors[] = 'Enter the date it was found (not in the future).';
    }

    $imageUrl = null;
    if (!$errors) {
        try {
            $imageUrl = save_upload('photo');
        } catch (RuntimeException $e) {
            $errors[] = $e->getMessage();
        }
    }

    if (!$errors) {
        try {
            // Holding counter = this admin's counter (set by the trigger).
            // Status defaults to AVAILABLE and matching runs automatically.
            $result = call_procedure('CALL sp_log_found_item(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [
                $user['id'],
                (int)$form['category'],
                $form['location'] !== '' ? (int)$form['location'] : null,
                $form['title'],
                $form['color'] !== '' ? $form['color'] : null,
                $form['public'] !== '' ? $form['public'] : null,
                $form['private'] !== '' ? $form['private'] : null,
                $form['date'],
                $imageUrl,
                isset($_POST['photo_public']) ? 1 : 0,
            ])[0][0];

            $msg = 'Item logged and published to the feed.';
            if ($result['matches_found'] > 0) {
                $msg .= " {$result['matches_found']} matching lost report(s) found; {$result['users_notified']} student(s) alerted.";
            }
            flash('success', $msg);
            redirect('item.php?id=' . $result['new_item_id']);
        } catch (PDOException $e) {
            if ($imageUrl) {
                @unlink(__DIR__ . '/' . $imageUrl);
            }
            $errors[] = db_error_message($e);
        }
    }
}

$pageTitle = 'Log found item';
require __DIR__ . '/includes/header.php';
?>
<div class="page-head">
  <div>
    <h1>Log a found item</h1>
    <p class="muted">The item will be held at <strong><?= e($user['counter']) ?></strong> and goes on the feed right away.</p>
  </div>
</div>
<?php foreach ($errors as $err): ?><div class="alert alert-error"><?= e($err) ?></div><?php endforeach; ?>

<form method="post" enctype="multipart/form-data" class="form card" style="max-width:760px">
  <?= csrf_field() ?>
  <label>Title <small>Shown on the feed, e.g. "Black leather wallet"</small>
    <input name="title" value="<?= e($form['title']) ?>" maxlength="150" required>
  </label>
  <div class="form-row">
    <label>Category
      <select name="category" required>
        <option value="">Choose…</option>
        <?php foreach (categories() as $c): ?>
          <option value="<?= $c['category_id'] ?>" <?= $form['category'] == $c['category_id'] ? 'selected' : '' ?>><?= e($c['category_name']) ?></option>
        <?php endforeach; ?>
      </select>
    </label>
    <label>Color
      <input name="color" value="<?= e($form['color']) ?>" maxlength="50" placeholder="e.g. Black">
    </label>
  </div>
  <div class="form-row">
    <label>Where was it found?
      <select name="location">
        <option value="">Unknown</option>
        <?php foreach (locations() as $l): ?>
          <option value="<?= $l['location_id'] ?>" <?= $form['location'] == $l['location_id'] ? 'selected' : '' ?>><?= e($l['building_name'] . ' - ' . $l['department_counter']) ?></option>
        <?php endforeach; ?>
      </select>
    </label>
    <label>Date found
      <input type="date" name="date" value="<?= e($form['date']) ?>" max="<?= date('Y-m-d') ?>" required>
    </label>
  </div>
  <label>Public description <small>Visible to everyone. Keep identifying details out of it.</small>
    <textarea name="public"><?= e($form['public']) ?></textarea>
  </label>
  <label>Private verification notes <small>Staff only. Hidden details to check the claimant's proof against.</small>
    <textarea name="private" class="private-field" placeholder="e.g. blue keychain inside, student ID of …"><?= e($form['private']) ?></textarea>
  </label>
  <div class="form-row">
    <label>Photo <small>JPG, PNG or WebP, up to 5 MB</small>
      <input type="file" name="photo" accept="image/jpeg,image/png,image/webp">
    </label>
    <label class="check" style="align-self:end">
      <input type="checkbox" name="photo_public" value="1" checked> Show photo on the public feed
    </label>
  </div>
  <div><button class="btn">Log item</button></div>
</form>
<?php require __DIR__ . '/includes/footer.php'; ?>

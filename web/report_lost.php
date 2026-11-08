<?php
require __DIR__ . '/includes/bootstrap.php';
$user = require_login();

$errors = [];
$created = null;   // new lost item id after a successful submit
$matches = [];
$form = [
    'category' => input('category'),
    'location' => input('location'),
    'title'    => input('title'),
    'color'    => input('color'),
    'description' => input('description'),
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
        $errors[] = 'Enter the date you lost it (not in the future).';
    }

    if (!$errors) {
        try {
            // sp_report_lost_item runs the duplicate check and smart matching,
            // then returns the new id and any found items that already match
            $results = call_procedure('CALL sp_report_lost_item(?, ?, ?, ?, ?, ?, ?)', [
                $user['id'],
                (int)$form['category'],
                $form['location'] !== '' ? (int)$form['location'] : null,
                $form['title'],
                $form['color'] !== '' ? $form['color'] : null,
                $form['description'] !== '' ? $form['description'] : null,
                $form['date'],
            ]);
            $created = (int)$results[0][0]['new_lost_item_id'];
            $matches = $results[1] ?? [];
        } catch (PDOException $e) {
            $errors[] = db_error_message($e);
        }
    }
}

$pageTitle = 'Report a lost item';
require __DIR__ . '/includes/header.php';
?>
<?php if ($created): ?>
  <div class="alert alert-success">Your lost report has been saved. We'll alert you when a matching item is logged at a counter.</div>
  <?php if ($matches): ?>
    <h2>Good news: these items at a counter may be yours</h2>
    <div class="grid">
      <?php foreach ($matches as $m): ?>
        <a class="card item-card" href="item.php?id=<?= $m['found_item_id'] ?>">
          <div class="body">
            <span class="score"><?= (int)$m['match_score'] ?>% match</span>
            <h3><?= e($m['title']) ?></h3>
            <p class="desc"><?= e($m['public_description']) ?></p>
            <div class="where"><strong>Pick up:</strong> <?= e($m['pick_up_at']) ?><?php if ($m['room_number']): ?>, room <?= e($m['room_number']) ?><?php endif; ?>
              <?php if ($m['hours']): ?><br><span class="muted"><?= e($m['hours']) ?></span><?php endif; ?>
            </div>
          </div>
        </a>
      <?php endforeach; ?>
    </div>
  <?php else: ?>
    <p class="muted">No matching items have been handed in yet.</p>
  <?php endif; ?>
  <p><a class="btn" href="my_reports.php">Go to my reports</a> <a class="btn btn-light" href="feed.php">Browse the feed</a></p>
<?php else: ?>
  <div class="page-head">
    <div>
      <h1>Report a lost item</h1>
      <p class="muted">Check the <a href="feed.php">feed</a> first. If your item isn't there yet, report it here and we'll alert you when a counter logs a match.</p>
    </div>
  </div>
  <?php foreach ($errors as $err): ?><div class="alert alert-error"><?= e($err) ?></div><?php endforeach; ?>
  <form method="post" class="form card" style="max-width:720px">
    <?= csrf_field() ?>
    <label>What did you lose? <small>A short title, e.g. "Black leather wallet"</small>
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
      <label>Where did you lose it?
        <select name="location">
          <option value="">Not sure</option>
          <?php foreach (locations() as $l): ?>
            <option value="<?= $l['location_id'] ?>" <?= $form['location'] == $l['location_id'] ? 'selected' : '' ?>><?= e($l['building_name']) ?></option>
          <?php endforeach; ?>
        </select>
      </label>
      <label>When?
        <input type="date" name="date" value="<?= e($form['date']) ?>" max="<?= date('Y-m-d') ?>" required>
      </label>
    </div>
    <label>Description <small>Don't include secret details. You'll use those to prove ownership at the counter.</small>
      <textarea name="description"><?= e($form['description']) ?></textarea>
    </label>
    <div><button class="btn">Submit lost report</button></div>
  </form>
<?php endif; ?>
<?php require __DIR__ . '/includes/footer.php'; ?>

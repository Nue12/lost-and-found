<?php
require __DIR__ . '/includes/bootstrap.php';

if (current_user()) {
    redirect('feed.php');
}

$errors = [];
$email = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $email = strtolower(input('email'));
    $password = (string)($_POST['password'] ?? '');
    $confirm = (string)($_POST['confirm'] ?? '');

    $domain = substr(strrchr($email, '@') ?: '', 1);
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)
        || ($domain !== UNIVERSITY_EMAIL_DOMAIN && !str_ends_with($domain, '.' . UNIVERSITY_EMAIL_DOMAIN))) {
        $errors[] = 'Use your university email address (ending in ' . UNIVERSITY_EMAIL_DOMAIN . ').';
    }
    if (strlen($password) < 8) {
        $errors[] = 'Password must be at least 8 characters.';
    }
    if ($password !== $confirm) {
        $errors[] = 'Passwords do not match.';
    }

    if (!$errors) {
        try {
            // New accounts are always general users; admins are assigned by the university
            call_procedure('CALL sp_register_user(?, ?, ?, ?)',
                [$email, password_hash($password, PASSWORD_DEFAULT), 'USER', null]);
            flash('success', 'Account created. You can log in now.');
            redirect('login.php');
        } catch (PDOException $e) {
            $errors[] = ($e->errorInfo[1] ?? 0) === 1062
                ? 'An account with that email already exists.'
                : db_error_message($e);
        }
    }
}

$pageTitle = 'Create account';
require __DIR__ . '/includes/header.php';
?>
<div class="auth card">
  <h1>Create an account</h1>
  <p class="muted">For students and staff with a university email.</p>
  <?php foreach ($errors as $err): ?><div class="alert alert-error"><?= e($err) ?></div><?php endforeach; ?>
  <form method="post" class="form">
    <?= csrf_field() ?>
    <label>University email
      <input type="email" name="email" value="<?= e($email) ?>" placeholder="name@student.<?= e(UNIVERSITY_EMAIL_DOMAIN) ?>" required>
    </label>
    <label>Password <small>At least 8 characters</small>
      <input type="password" name="password" minlength="8" required>
    </label>
    <label>Confirm password
      <input type="password" name="confirm" minlength="8" required>
    </label>
    <button class="btn">Create account</button>
  </form>
  <p>Already registered? <a href="login.php">Log in</a></p>
</div>
<?php require __DIR__ . '/includes/footer.php'; ?>

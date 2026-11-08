<?php
require __DIR__ . '/includes/bootstrap.php';

if (current_user()) {
    redirect('feed.php');
}

$error = '';
$email = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $email = strtolower(input('email'));
    $password = (string)($_POST['password'] ?? '');

    $stmt = db()->prepare(
        "SELECT u.user_id, u.university_email, u.password_hash, u.role, u.location_id,
                CONCAT(l.building_name, ' - ', l.department_counter) AS counter
         FROM users u
         LEFT JOIN locations l ON l.location_id = u.location_id
         WHERE u.university_email = ?"
    );
    $stmt->execute([$email]);
    $row = $stmt->fetch();

    if ($row && password_verify($password, $row['password_hash'])) {
        session_regenerate_id(true);
        $_SESSION['user'] = [
            'id'          => (int)$row['user_id'],
            'email'       => $row['university_email'],
            'role'        => $row['role'],
            'location_id' => $row['location_id'] !== null ? (int)$row['location_id'] : null,
            'counter'     => $row['counter'],
        ];
        redirect($row['role'] === 'ADMIN' ? 'admin_inventory.php' : 'feed.php');
    }
    $error = 'Incorrect email or password.';
}

$pageTitle = 'Log in';
require __DIR__ . '/includes/header.php';
?>
<div class="auth card">
  <h1>Welcome back</h1>
  <p class="muted">Log in with your university account.</p>
  <?php if ($error): ?><div class="alert alert-error"><?= e($error) ?></div><?php endif; ?>
  <form method="post" class="form">
    <?= csrf_field() ?>
    <label>University email
      <input type="email" name="email" value="<?= e($email) ?>" required autofocus>
    </label>
    <label>Password
      <input type="password" name="password" required>
    </label>
    <button class="btn">Log in</button>
  </form>
  <p>New here? <a href="register.php">Create an account</a></p>
  <div class="demo-accounts muted">
    Demo accounts (password <code>password123</code>):<br>
    Student: <code>aung.min@student.university.edu</code><br>
    Admin: <code>admin.library@university.edu</code>
  </div>
</div>
<?php require __DIR__ . '/includes/footer.php'; ?>

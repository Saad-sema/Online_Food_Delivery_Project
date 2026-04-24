<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>FoodDash Admin – Login</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">
<style>
body{background:linear-gradient(135deg,#ff6b35,#f7931e);min-height:100vh;display:flex;align-items:center;justify-content:center;}
.card{border:none;border-radius:20px;box-shadow:0 20px 60px rgba(0,0,0,.3);}
.brand-logo{width:70px;height:70px;background:linear-gradient(135deg,#ff6b35,#f7931e);border-radius:16px;display:flex;align-items:center;justify-content:center;}
</style>
</head>
<body>
<?php
require 'config.php';

if (!empty($_SESSION['admin_id'])) {
    header('Location: dashboard.php'); exit;
}

$error = '';

// Auto-create admin user if none exists
try {
    $check = db()->query("SELECT COUNT(*) as c FROM users WHERE role='admin'");
    $row = $check->fetch_assoc();
    if ((int)($row['c'] ?? 0) === 0) {
        $adminPass = 'Admin@123';
        $ins = db()->prepare("INSERT INTO users (name, phone, email, password, role, is_active) VALUES ('Admin User','9000000000','admin@foodapp.com',?,'admin',1)");
        $ins->bind_param('s', $adminPass);
        $ins->execute();
    }
} catch (Exception $e) {}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');
    $pass  = $_POST['password'] ?? '';
    if ($email && $pass) {
        $stmt = db()->prepare("SELECT id, name, password FROM users WHERE email=? AND role='admin' AND is_active=1");
        $stmt->bind_param('s', $email);
        $stmt->execute();
        $user = $stmt->get_result()->fetch_assoc();
        if ($user && $pass === $user['password']) {
            $_SESSION['admin_id']   = $user['id'];
            $_SESSION['admin_name'] = $user['name'];
            header('Location: dashboard.php'); exit;
        }
        if (!$user) {
            $error = 'No admin account found with this email.';
        } else {
            $error = 'Incorrect password.';
        }
    } else {
        $error = 'Please enter both email and password.';
    }
}
?>
<div class="container" style="max-width:420px">
  <div class="card p-4 p-md-5">
    <div class="text-center mb-4">
      <div class="brand-logo mx-auto mb-3">
        <i class="bi bi-bag-heart-fill text-white fs-2"></i>
      </div>
      <h3 class="fw-bold">FoodDash Admin</h3>
      <p class="text-muted small">Sign in to your account</p>
    </div>
    <?php if ($error): ?>
    <div class="alert alert-danger alert-dismissible"><i class="bi bi-exclamation-circle me-2"></i><?=htmlspecialchars($error)?><button type="button" class="btn-close" data-bs-dismiss="alert"></button></div>
    <?php endif; ?>
    <form method="POST" autocomplete="on">
      <div class="mb-3">
        <label class="form-label fw-semibold">Email Address</label>
        <div class="input-group">
          <span class="input-group-text"><i class="bi bi-envelope"></i></span>
          <input type="email" name="email" class="form-control" placeholder="admin@foodapp.com" value="<?=htmlspecialchars($_POST['email']??'')?>" required>
        </div>
      </div>
      <div class="mb-4">
        <label class="form-label fw-semibold">Password</label>
        <div class="input-group">
          <span class="input-group-text"><i class="bi bi-lock"></i></span>
          <input type="password" name="password" id="pwdInput" class="form-control" placeholder="••••••••" required>
          <button class="btn btn-outline-secondary" type="button" onclick="togglePwd()"><i class="bi bi-eye" id="eyeIcon"></i></button>
        </div>
      </div>
      <button type="submit" class="btn btn-warning w-100 fw-bold py-2 fs-5">
        <i class="bi bi-box-arrow-in-right me-2"></i>Sign In
      </button>
    </form>
    <p class="text-center text-muted mt-3 small">Default: admin@foodapp.com / Admin@123</p>
  </div>
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<script>
function togglePwd(){
    const i=document.getElementById('pwdInput'),e=document.getElementById('eyeIcon');
    i.type=i.type==='password'?'text':'password';
    e.className=i.type==='password'?'bi bi-eye':'bi bi-eye-slash';
}
</script>
</body>
</html>

<?php
require 'config.php';
requireLogin();
$db = db();
$flash = null;

// Handle actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';

    if ($action === 'create') {
        $name  = trim($_POST['name'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $phone = trim($_POST['phone'] ?? '');
        $role  = $_POST['role'] ?? 'customer';
        $pass  = password_hash($_POST['password'] ?? 'Password@123', PASSWORD_BCRYPT);
        $stmt  = $db->prepare("INSERT INTO users (name, email, phone, password, role) VALUES (?,?,?,?,?)");
        $stmt->bind_param('sssss', $name, $email, $phone, $pass, $role);
        flash($stmt->execute() ? 'User created successfully.' : 'Error: ' . $db->error);
    }

    if ($action === 'toggle') {
        $uid      = (int)$_POST['uid'];
        $isActive = (int)$_POST['is_active'] ? 0 : 1;
        $db->query("UPDATE users SET is_active=$isActive WHERE id=$uid");
        flash($isActive ? 'User activated.' : 'User deactivated.', $isActive ? 'success' : 'warning');
    }

    if ($action === 'delete') {
        $uid = (int)$_POST['uid'];
        if ($uid === (int)$_SESSION['admin_id']) { flash('Cannot delete your own account.', 'danger'); }
        else { $db->query("DELETE FROM users WHERE id=$uid"); flash('User deleted.'); }
    }
    header('Location: users.php'); exit;
}

// Fetch users
$role   = $_GET['role'] ?? '';
$search = trim($_GET['q'] ?? '');
$page   = max(1,(int)($_GET['page']??1));
$limit  = 15; $off = ($page-1)*$limit;
$where  = "WHERE 1";
if ($role)   $where .= " AND role='".  $db->real_escape_string($role)."'";
if ($search) $where .= " AND (name LIKE '%".  $db->real_escape_string($search)."%' OR email LIKE '%".  $db->real_escape_string($search)."%')";
$total  = $db->query("SELECT COUNT(*) c FROM users $where")->fetch_assoc()['c'];
$users  = $db->query("SELECT * FROM users $where ORDER BY created_at DESC LIMIT $limit OFFSET $off")->fetch_all(MYSQLI_ASSOC);
$pages  = ceil($total/$limit);

include 'layout/header.php';
?>

<div class="d-flex justify-content-between align-items-center mb-4">
  <h4 class="fw-bold mb-0"><i class="bi bi-people me-2 text-primary"></i>Users Management</h4>
  <button class="btn btn-warning fw-semibold" data-bs-toggle="modal" data-bs-target="#createModal">
    <i class="bi bi-plus-lg me-1"></i>Add User
  </button>
</div>

<!-- Filters -->
<div class="card border-0 rounded-4 shadow-sm p-3 mb-4">
  <form method="GET" class="row g-2">
    <div class="col-md-5"><input type="text" name="q" class="form-control" placeholder="Search name or email…" value="<?=htmlspecialchars($search)?>"></div>
    <div class="col-md-3">
      <select name="role" class="form-select">
        <option value="">All Roles</option>
        <?php foreach(['customer','restaurant','delivery_boy','admin'] as $r): ?>
        <option value="<?=$r?>" <?=$role===$r?'selected':''?>><?=ucfirst(str_replace('_',' ',$r))?></option>
        <?php endforeach; ?>
      </select>
    </div>
    <div class="col-auto"><button type="submit" class="btn btn-primary">Filter</button></div>
    <div class="col-auto"><a href="users.php" class="btn btn-outline-secondary">Reset</a></div>
  </form>
</div>

<!-- Table -->
<div class="card border-0 rounded-4 shadow-sm p-4">
  <div class="table-responsive">
    <table class="table table-hover align-middle" id="usersTable">
      <thead class="table-light"><tr>
        <th>ID</th><th>Name</th><th>Email</th><th>Phone</th><th>Role</th><th>Status</th><th>Joined</th><th>Actions</th>
      </tr></thead>
      <tbody>
      <?php foreach($users as $u): ?>
      <tr>
        <td class="text-muted small"><?=$u['id']?></td>
        <td class="fw-semibold"><?=htmlspecialchars($u['name'])?></td>
        <td><?=htmlspecialchars($u['email'])?></td>
        <td><?=htmlspecialchars($u['phone']??'-')?></td>
        <td><span class="badge rounded-pill bg-secondary"><?=str_replace('_',' ',ucfirst($u['role']))?></span></td>
        <td>
          <?php if($u['is_active']): ?>
          <span class="badge bg-success-subtle text-success rounded-pill">Active</span>
          <?php else: ?>
          <span class="badge bg-danger-subtle text-danger rounded-pill">Inactive</span>
          <?php endif; ?>
        </td>
        <td class="text-muted small"><?=date('d M Y',strtotime($u['created_at']))?></td>
        <td>
          <form method="POST" class="d-inline">
            <input type="hidden" name="action" value="toggle">
            <input type="hidden" name="uid" value="<?=$u['id']?>">
            <input type="hidden" name="is_active" value="<?=$u['is_active']?>">
            <button class="btn btn-sm btn-outline-<?=$u['is_active']?'warning':'success'?>" title="Toggle">
              <i class="bi bi-<?=$u['is_active']?'slash-circle':'check-circle'?>"></i>
            </button>
          </form>
          <form method="POST" class="d-inline" onsubmit="return confirm('Delete this user?')">
            <input type="hidden" name="action" value="delete">
            <input type="hidden" name="uid" value="<?=$u['id']?>">
            <button class="btn btn-sm btn-outline-danger" title="Delete"><i class="bi bi-trash"></i></button>
          </form>
        </td>
      </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
  <!-- Pagination -->
  <?php if($pages>1): ?>
  <nav class="mt-3"><ul class="pagination pagination-sm justify-content-end mb-0">
    <?php for($p=1;$p<=$pages;$p++): ?>
    <li class="page-item <?=$p==$page?'active':''?>">
      <a class="page-link" href="?page=<?=$p?>&role=<?=urlencode($role)?>&q=<?=urlencode($search)?>"><?=$p?></a>
    </li>
    <?php endfor; ?>
  </ul></nav>
  <?php endif; ?>
</div>

<!-- Create User Modal -->
<div class="modal fade" id="createModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered">
    <div class="modal-content border-0 shadow rounded-4">
      <div class="modal-header border-0"><h5 class="modal-title fw-bold">Add New User</h5><button class="btn-close" data-bs-dismiss="modal"></button></div>
      <form method="POST">
        <input type="hidden" name="action" value="create">
        <div class="modal-body">
          <div class="mb-3"><label class="form-label">Full Name</label><input type="text" name="name" class="form-control" required></div>
          <div class="mb-3"><label class="form-label">Email</label><input type="email" name="email" class="form-control" required></div>
          <div class="mb-3"><label class="form-label">Phone</label><input type="text" name="phone" class="form-control"></div>
          <div class="mb-3"><label class="form-label">Role</label>
            <select name="role" class="form-select">
              <?php foreach(['customer','restaurant','delivery_boy','admin'] as $r): ?>
              <option value="<?=$r?>"><?=ucfirst(str_replace('_',' ',$r))?></option>
              <?php endforeach; ?>
            </select>
          </div>
          <div class="mb-3"><label class="form-label">Password</label><input type="password" name="password" class="form-control" placeholder="Default: Password@123"></div>
        </div>
        <div class="modal-footer border-0">
          <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancel</button>
          <button type="submit" class="btn btn-warning fw-semibold"><i class="bi bi-plus-lg me-1"></i>Create User</button>
        </div>
      </form>
    </div>
  </div>
</div>

<?php include 'layout/footer.php'; ?>

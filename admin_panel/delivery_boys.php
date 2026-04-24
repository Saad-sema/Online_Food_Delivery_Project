<?php
require 'config.php';
requireLogin();
$db = db();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $uid    = (int)($_POST['uid'] ?? 0);
    $status = (int)($_POST['status'] ?? 0) ? 0 : 1;
    $db->query("UPDATE users SET is_active=$status WHERE id=$uid AND role='delivery_boy'");
    flash("Delivery boy " . ($status ? 'activated' : 'deactivated') . ".");
    header('Location: delivery_boys.php'); exit;
}

$boys = $db->query("SELECT u.id, u.name, u.email, u.phone, u.is_active, u.created_at,
    (SELECT COUNT(*) FROM orders WHERE delivery_boy_id=db.id AND order_status='delivered') as completed_orders
    FROM users u 
    JOIN delivery_boys db ON db.user_id = u.id
    WHERE u.role='delivery_boy' 
    ORDER BY u.created_at DESC")->fetch_all(MYSQLI_ASSOC);

include 'layout/header.php';
?>
<div class="d-flex justify-content-between align-items-center mb-4">
  <h4 class="fw-bold mb-0"><i class="bi bi-bicycle me-2 text-info"></i>Delivery Boys</h4>
</div>

<div class="card border-0 rounded-4 shadow-sm p-4">
  <div class="table-responsive">
    <table class="table table-hover align-middle dataTable">
      <thead class="table-light"><tr>
        <th>#</th><th>Name</th><th>Contact</th><th>Completed Orders</th><th>Status</th><th>Actions</th>
      </tr></thead>
      <tbody>
      <?php foreach($boys as $b): ?>
      <tr>
        <td><?=$b['id']?></td>
        <td><span class="fw-semibold"><?=htmlspecialchars($b['name'])?></span></td>
        <td>
          <?=htmlspecialchars($b['email'])?><br>
          <small class="text-muted"><?=htmlspecialchars($b['phone']??'-')?></small>
        </td>
        <td><span class="badge bg-light text-dark"><?=$b['completed_orders']?></span></td>
        <td>
          <span class="badge rounded-pill <?=$b['is_active']?'bg-success':'bg-danger'?>">
            <?=$b['is_active']?'Active':'Inactive'?>
          </span>
        </td>
        <td>
          <form method="POST" class="d-inline">
            <input type="hidden" name="uid" value="<?=$b['id']?>">
            <input type="hidden" name="status" value="<?=$b['is_active']?>">
            <?php if(!$b['is_active']): ?>
            <button class="btn btn-sm btn-success" title="Activate"><i class="bi bi-check-lg"></i> Activate</button>
            <?php else: ?>
            <button class="btn btn-sm btn-outline-danger" title="Deactivate"><i class="bi bi-slash-circle"></i> Deactivate</button>
            <?php endif; ?>
          </form>
        </td>
      </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
<script>$(document).ready(function(){$('.dataTable').DataTable({pageLength:15});});</script>
<?php include 'layout/footer.php'; ?>

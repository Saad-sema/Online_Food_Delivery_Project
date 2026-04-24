<?php
require 'config.php';
requireLogin();
$db = db();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id     = (int)($_POST['id'] ?? 0);
    $status = in_array($_POST['status']??'',['approved','suspended','pending']) ? $_POST['status'] : 'approved';
    $db->query("UPDATE restaurants SET status='$status' WHERE id=$id");
    flash("Restaurant " . ($status === 'approved' ? 'approved' : 'status updated to ' . $status) . ".");
    header('Location: restaurants.php'); exit;
}

$restaurants = $db->query("SELECT r.*, u.name AS owner_name, u.email AS owner_email, u.phone AS owner_phone
    FROM restaurants r JOIN users u ON u.id=r.user_id ORDER BY r.created_at DESC")->fetch_all(MYSQLI_ASSOC);

include 'layout/header.php';
?>
<div class="d-flex justify-content-between align-items-center mb-4">
  <h4 class="fw-bold mb-0"><i class="bi bi-shop me-2 text-success"></i>Restaurants</h4>
</div>
<div class="card border-0 rounded-4 shadow-sm p-4">
  <div class="table-responsive">
    <table class="table table-hover align-middle dataTable">
      <thead class="table-light"><tr>
        <th>#</th><th>Restaurant</th><th>Owner</th><th>Cuisine</th><th>Rating</th><th>Status</th><th>Actions</th>
      </tr></thead>
      <tbody>
      <?php foreach($restaurants as $r): ?>
      <tr>
        <td><?=$r['id']?></td>
        <td>
          <?php if($r['image_url']): ?><img src="<?=htmlspecialchars($r['image_url'])?>" width="38" height="38" class="rounded-3 me-2 object-fit-cover">
          <?php elseif($r['image']): ?><img src="../backend/uploads/<?=htmlspecialchars($r['image'])?>" width="38" height="38" class="rounded-3 me-2 object-fit-cover"><?php endif; ?>
          <span class="fw-semibold"><?=htmlspecialchars($r['name'])?></span>
          <br><small class="text-muted"><?=htmlspecialchars(substr($r['address'],0,40))?></small>
        </td>
        <td><?=htmlspecialchars($r['owner_name'])?><br><small class="text-muted"><?=htmlspecialchars($r['owner_email'])?></small></td>
        <td><?=htmlspecialchars($r['cuisine']??'-')?></td>
        <td><i class="bi bi-star-fill text-warning"></i> <?=number_format($r['rating_avg'],1)?> <small class="text-muted">(<?=$r['rating_count']?>)</small></td>
        <td>
          <span class="badge rounded-pill <?=$r['status']==='approved'?'bg-success':($r['status']==='pending'?'bg-warning text-dark':'bg-danger')?>">
            <?=ucfirst($r['status'])?>
          </span>
        </td>
        <td>
          <form method="POST" class="d-inline">
            <input type="hidden" name="id" value="<?=$r['id']?>">
            <?php if($r['status']!=='approved'): ?>
            <button name="status" value="approved" class="btn btn-sm btn-success" title="Approve"><i class="bi bi-check-lg"></i> Approve</button>
            <?php else: ?>
            <button name="status" value="suspended" class="btn btn-sm btn-outline-danger" title="Suspend"><i class="bi bi-slash-circle"></i> Suspend</button>
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

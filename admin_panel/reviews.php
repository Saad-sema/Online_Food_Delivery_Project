<?php
require 'config.php';
requireLogin();
$db = db();

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['delete_id'])) {
    $id = (int)$_POST['delete_id'];
    $db->query("DELETE FROM reviews WHERE id=$id");
    flash("Review deleted successfully.");
    header('Location: reviews.php'); exit;
}

$reviews = $db->query("SELECT rv.*, u.name AS customer_name, r.name AS restaurant_name
    FROM reviews rv
    JOIN users u ON u.id=rv.user_id
    JOIN orders o ON o.id=rv.order_id
    JOIN restaurants r ON r.id=o.restaurant_id
    ORDER BY rv.created_at DESC")->fetch_all(MYSQLI_ASSOC);

include 'layout/header.php';
?>
<div class="d-flex justify-content-between align-items-center mb-4">
  <h4 class="fw-bold mb-0"><i class="bi bi-star me-2 text-warning"></i>Customer Reviews</h4>
</div>

<div class="card border-0 rounded-4 shadow-sm p-4">
  <div class="table-responsive">
    <table class="table table-hover align-middle dataTable">
      <thead class="table-light"><tr>
        <th>#</th><th>Customer</th><th>Restaurant</th><th>Rating</th><th>Comment</th><th>For</th><th>Date</th><th>Actions</th>
      </tr></thead>
      <tbody>
      <?php foreach($reviews as $rv): ?>
      <tr>
        <td><?=$rv['id']?></td>
        <td><span class="fw-semibold"><?=htmlspecialchars($rv['customer_name'])?></span></td>
        <td><?=htmlspecialchars($rv['restaurant_name'])?></td>
        <td>
          <?php for($i=1; $i<=5; $i++): ?>
            <i class="bi bi-star-fill <?= $i <= $rv['rating'] ? 'text-warning' : 'text-muted' ?>"></i>
          <?php endfor; ?>
        </td>
        <td><small class="text-muted"><?=htmlspecialchars($rv['comment'] ?? '-')?></small></td>
        <td><span class="badge bg-light text-dark border"><?=ucwords(str_replace('_', ' ', $rv['review_for']))?></span></td>
        <td><?=date('d M Y', strtotime($rv['created_at']))?></td>
        <td>
          <form method="POST" onsubmit="return confirm('Delete this review?');" class="d-inline">
            <input type="hidden" name="delete_id" value="<?=$rv['id']?>">
            <button type="submit" class="btn btn-sm btn-outline-danger"><i class="bi bi-trash"></i></button>
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

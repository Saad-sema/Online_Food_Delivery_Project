<?php
require 'config.php';
requireLogin();
$db     = db();
$page   = max(1,(int)($_GET['page']??1));
$limit  = 20; $off = ($page-1)*$limit;
$status = $_GET['status'] ?? '';
$where  = $status ? "WHERE o.order_status='". $db->real_escape_string($status)."'" : '';
$total  = $db->query("SELECT COUNT(*) c FROM orders o $where")->fetch_assoc()['c'];
$orders = $db->query("SELECT o.id, o.order_status, o.payment_method, o.payment_status, o.total_amount, o.created_at,
    u.name AS customer, r.name AS restaurant
    FROM orders o JOIN users u ON u.id=o.user_id JOIN restaurants r ON r.id=o.restaurant_id
    $where ORDER BY o.created_at DESC LIMIT $limit OFFSET $off")->fetch_all(MYSQLI_ASSOC);
$pages  = ceil($total/$limit);

include 'layout/header.php';
?>
<div class="d-flex justify-content-between align-items-center mb-4">
  <h4 class="fw-bold mb-0"><i class="bi bi-receipt me-2 text-danger"></i>Orders</h4>
  <div class="d-flex gap-2">
    <?php $statuses=['','pending','accepted','assigned','out_for_delivery','delivered','cancelled'];
    foreach($statuses as $s): ?>
    <a href="?status=<?=$s?>" class="btn btn-sm <?=$s===$status?'btn-dark':'btn-outline-secondary'?>"><?=$s?strtoupper($s):'ALL'?></a>
    <?php endforeach; ?>
  </div>
</div>
<div class="card border-0 rounded-4 shadow-sm p-4">
  <div class="table-responsive">
    <table class="table table-hover align-middle">
      <thead class="table-light"><tr>
        <th>#</th><th>Customer</th><th>Restaurant</th><th>Amount</th><th>Payment</th><th>Status</th><th>Date</th>
      </tr></thead>
      <tbody>
      <?php foreach($orders as $o): ?>
      <tr>
        <td class="fw-bold">#<?=$o['id']?></td>
        <td><?=htmlspecialchars($o['customer'])?></td>
        <td><?=htmlspecialchars($o['restaurant'])?></td>
        <td class="fw-semibold">₹<?=number_format($o['total_amount'],2)?></td>
        <td><span class="badge bg-<?=$o['payment_status']==='successful'?'success-subtle text-success':'warning-subtle text-warning'?>"><?=strtoupper($o['payment_method'])?></span></td>
        <td><span class="badge badge-status-<?=$o['order_status']?> rounded-pill px-3"><?=str_replace('_',' ',ucfirst($o['order_status']))?></span></td>
        <td class="text-muted small"><?=date('d M, H:i',strtotime($o['created_at']))?></td>
      </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
  <?php if($pages>1): ?>
  <nav class="mt-3"><ul class="pagination pagination-sm justify-content-end mb-0">
    <?php for($p=1;$p<=$pages;$p++): ?>
    <li class="page-item <?=$p==$page?'active':''?>"><a class="page-link" href="?page=<?=$p?>&status=<?=urlencode($status)?>"><?=$p?></a></li>
    <?php endfor; ?>
  </ul></nav>
  <?php endif; ?>
</div>
<?php include 'layout/footer.php'; ?>

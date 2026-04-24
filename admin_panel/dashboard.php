<?php
require 'config.php';
requireLogin();
$db = db();

// Stats
$stats = [
    'users'       => $db->query("SELECT COUNT(*) c FROM users WHERE role='customer'")->fetch_assoc()['c'],
    'restaurants' => $db->query("SELECT COUNT(*) c FROM restaurants")->fetch_assoc()['c'],
    'orders'      => $db->query("SELECT COUNT(*) c FROM orders")->fetch_assoc()['c'],
    'revenue'     => number_format($db->query("SELECT COALESCE(SUM(total_amount),0) s FROM orders WHERE order_status='delivered'")->fetch_assoc()['s'], 2),
    'pending'     => $db->query("SELECT COUNT(*) c FROM orders WHERE order_status='pending'")->fetch_assoc()['c'],
    'delivered'   => $db->query("SELECT COUNT(*) c FROM orders WHERE order_status='delivered'")->fetch_assoc()['c'],
    'tips'        => number_format($db->query("SELECT COALESCE(SUM(tip_amount),0) s FROM orders WHERE order_status='delivered'")->fetch_assoc()['s'], 2),
    'reviews'     => $db->query("SELECT COUNT(*) c FROM reviews")->fetch_assoc()['c'],
    'delivery_boys' => $db->query("SELECT COUNT(*) c FROM users WHERE role='delivery_boy'")->fetch_assoc()['c'],
];

// Chart: last 14 days orders
$chartRows = $db->query("SELECT DATE(created_at) as d, COUNT(*) as c FROM orders WHERE created_at >= DATE_SUB(NOW(),INTERVAL 14 DAY) GROUP BY DATE(created_at) ORDER BY d ASC")->fetch_all(MYSQLI_ASSOC);
$chartLabels  = json_encode(array_column($chartRows,'d'));
$chartOrders  = json_encode(array_column($chartRows,'c'));

// Recent orders
$recent = $db->query("SELECT o.id, o.order_status, o.total_amount, o.created_at, u.name AS customer, r.name AS restaurant
    FROM orders o JOIN users u ON u.id=o.user_id JOIN restaurants r ON r.id=o.restaurant_id
    ORDER BY o.created_at DESC LIMIT 8")->fetch_all(MYSQLI_ASSOC);

include 'layout/header.php';
?>

<div class="row g-4 mb-4">
  <?php $statCards = [
    ['label'=>'Customers','value'=>$stats['users'],'icon'=>'people-fill','color'=>'#4f46e5','bg'=>'#ede9fe'],
    ['label'=>'Restaurants','value'=>$stats['restaurants'],'icon'=>'shop-window','color'=>'#059669','bg'=>'#d1fae5'],
    ['label'=>'Total Orders','value'=>$stats['orders'],'icon'=>'receipt','color'=>'#d97706','bg'=>'#fef3c7'],
    ['label'=>'Revenue (₹)','value'=>$stats['revenue'],'icon'=>'currency-rupee','color'=>'#dc2626','bg'=>'#fee2e2'],
  ];
  foreach ($statCards as $card): ?>
  <div class="col-6 col-xl-3">
    <div class="stat-card p-4 d-flex align-items-center gap-3">
      <div class="icon-box" style="background:<?=$card['bg']?>">
        <i class="bi bi-<?=$card['icon']?>" style="color:<?=$card['color']?>;font-size:1.5rem"></i>
      </div>
      <div>
        <div class="fs-4 fw-bold"><?=$card['value']?></div>
        <div class="text-muted small"><?=$card['label']?></div>
      </div>
    </div>
  </div>
  <?php endforeach; ?>
  <div class="col-6 col-xl-3">
    <div class="stat-card p-4 d-flex align-items-center gap-3">
      <div class="icon-box" style="background:#fff7ed">
        <i class="bi bi-heart-fill" style="color:#ea580c;font-size:1.5rem"></i>
      </div>
      <div>
        <div class="fs-4 fw-bold">₹<?=$stats['tips']?></div>
        <div class="text-muted small">Total Tips</div>
      </div>
    </div>
  </div>
      <div>
        <div class="fs-4 fw-bold"><?=$stats['reviews']?></div>
        <div class="text-muted small">Reviews</div>
      </div>
    </div>
  </div>
  <div class="col-6 col-xl-3">
    <div class="stat-card p-4 d-flex align-items-center gap-3">
      <div class="icon-box" style="background:#e0f2fe">
        <i class="bi bi-bicycle" style="color:#0369a1;font-size:1.5rem"></i>
      </div>
      <div>
        <div class="fs-4 fw-bold"><?=$stats['delivery_boys']?></div>
        <div class="text-muted small">Delivery Boys</div>
      </div>
    </div>
  </div>
</div>

<div class="row g-4 mb-4">
  <!-- Chart -->
  <div class="col-12 col-lg-8">
    <div class="card border-0 rounded-4 shadow-sm p-4">
      <h5 class="fw-semibold mb-3"><i class="bi bi-graph-up-arrow me-2 text-warning"></i>Orders – Last 14 Days</h5>
      <canvas id="ordersChart" height="100"></canvas>
    </div>
  </div>
  <!-- Mini stats -->
  <div class="col-12 col-lg-4">
    <div class="card border-0 rounded-4 shadow-sm p-4 h-100">
      <h5 class="fw-semibold mb-3"><i class="bi bi-pie-chart me-2 text-primary"></i>Order Status</h5>
      <?php $statuses = ['pending'=>['#ffc107','Pending'],'delivered'=>['#198754','Delivered'],'cancelled'=>['#dc3545','Cancelled']];
      foreach($statuses as $s=>[$color,$label]):
          $cnt = $db->query("SELECT COUNT(*) c FROM orders WHERE order_status='$s'")->fetch_assoc()['c'];
          $total = max(1,(int)$stats['orders']);
          $pct = round($cnt/$total*100);
      ?>
      <div class="mb-3">
        <div class="d-flex justify-content-between mb-1"><span class="small"><?=$label?></span><span class="small fw-bold"><?=$cnt?></span></div>
        <div class="progress" style="height:8px"><div class="progress-bar" style="width:<?=$pct?>%;background:<?=$color?>"></div></div>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
</div>

<!-- Recent Orders -->
<div class="card border-0 rounded-4 shadow-sm p-4">
  <div class="d-flex justify-content-between align-items-center mb-3">
    <h5 class="fw-semibold mb-0"><i class="bi bi-clock-history me-2 text-danger"></i>Recent Orders</h5>
    <a href="orders.php" class="btn btn-sm btn-outline-warning">View All</a>
  </div>
  <div class="table-responsive">
    <table class="table table-hover align-middle">
      <thead class="table-light"><tr>
        <th>#</th><th>Customer</th><th>Restaurant</th><th>Amount</th><th>Status</th><th>Date</th>
      </tr></thead>
      <tbody>
      <?php foreach($recent as $o): ?>
      <tr>
        <td><a href="orders.php?id=<?=$o['id']?>" class="fw-bold text-decoration-none">#<?=$o['id']?></a></td>
        <td><?=htmlspecialchars($o['customer'])?></td>
        <td><?=htmlspecialchars($o['restaurant'])?></td>
        <td class="fw-semibold">₹<?=number_format($o['total_amount'],2)?></td>
        <td><span class="badge badge-status-<?=$o['order_status']?> rounded-pill px-3"><?=str_replace('_',' ',ucfirst($o['order_status']))?></span></td>
        <td class="text-muted small"><?=date('d M, H:i',strtotime($o['created_at']))?></td>
      </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>

<script>
const ctx = document.getElementById('ordersChart').getContext('2d');
new Chart(ctx, {
    type: 'line',
    data: {
        labels: <?=$chartLabels?>,
        datasets: [{
            label: 'Orders',
            data: <?=$chartOrders?>,
            borderColor: '#ff6b35',
            backgroundColor: 'rgba(255,107,53,0.1)',
            fill: true,
            tension: 0.4,
            pointRadius: 4,
        }]
    },
    options: {responsive:true, plugins:{legend:{display:false}}, scales:{y:{beginAtZero:true,ticks:{stepSize:1}}}}
});
</script>

<?php include 'layout/footer.php'; ?>

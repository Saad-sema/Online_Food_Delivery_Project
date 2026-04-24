<?php
require 'config.php';
requireLogin();
$db   = db();
$from = $_GET['from'] ?? date('Y-m-01');
$to   = $_GET['to']   ?? date('Y-m-d');

// CSV export
if ($_GET['export'] ?? '' === 'csv') {
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename=orders_report_' . $from . '_' . $to . '.csv');
    $f = fopen('php://output','w');
    fputcsv($f,['Date','Total Orders','Delivered','Cancelled','Gross Revenue (₹)']);
    $rows = $db->query("SELECT DATE(created_at) as d, COUNT(*) as tot,
        SUM(CASE WHEN order_status='delivered' THEN 1 ELSE 0 END) as del,
        SUM(CASE WHEN order_status='cancelled' THEN 1 ELSE 0 END) as can,
        SUM(total_amount) as rev
        FROM orders WHERE DATE(created_at) BETWEEN '$from' AND '$to'
        GROUP BY DATE(created_at) ORDER BY d ASC")->fetch_all(MYSQLI_ASSOC);
    foreach($rows as $r) fputcsv($f,[$r['d'],$r['tot'],$r['del'],$r['can'],number_format($r['rev'],2)]);
    fclose($f); exit;
}

$rows = $db->query("SELECT DATE(created_at) as d, COUNT(*) as tot,
    SUM(CASE WHEN order_status='delivered' THEN 1 ELSE 0 END) as del,
    SUM(CASE WHEN order_status='cancelled' THEN 1 ELSE 0 END) as can,
    SUM(total_amount) as rev
    FROM orders WHERE DATE(created_at) BETWEEN '$from' AND '$to'
    GROUP BY DATE(created_at) ORDER BY d ASC")->fetch_all(MYSQLI_ASSOC);

$earnings = $db->query("SELECT r.name, SUM(o.total_amount) AS revenue, COUNT(*) AS orders
    FROM orders o JOIN restaurants r ON r.id=o.restaurant_id
    WHERE order_status='delivered' AND DATE(o.created_at) BETWEEN '$from' AND '$to'
    GROUP BY r.id ORDER BY revenue DESC LIMIT 5")->fetch_all(MYSQLI_ASSOC);

$chartLabels  = json_encode(array_column($rows,'d'));
$chartRevenue = json_encode(array_column($rows,'rev'));

include 'layout/header.php';
?>
<div class="d-flex justify-content-between align-items-center mb-4">
  <h4 class="fw-bold mb-0"><i class="bi bi-bar-chart-line me-2 text-warning"></i>Reports</h4>
</div>

<!-- Date Filter -->
<div class="card border-0 rounded-4 shadow-sm p-3 mb-4">
  <form method="GET" class="row g-2 align-items-end">
    <div class="col-md-3"><label class="form-label">From</label><input type="date" name="from" class="form-control" value="<?=htmlspecialchars($from)?>"></div>
    <div class="col-md-3"><label class="form-label">To</label><input type="date" name="to" class="form-control" value="<?=htmlspecialchars($to)?>"></div>
    <div class="col-auto"><button class="btn btn-primary">Apply</button></div>
    <div class="col-auto"><a href="?from=<?=urlencode($from)?>&to=<?=urlencode($to)?>&export=csv" class="btn btn-success"><i class="bi bi-download me-1"></i>Export CSV</a></div>
  </form>
</div>

<div class="row g-4 mb-4">
  <!-- Revenue Chart -->
  <div class="col-12 col-lg-8">
    <div class="card border-0 rounded-4 shadow-sm p-4">
      <h5 class="fw-semibold mb-3"><i class="bi bi-currency-rupee me-2 text-success"></i>Daily Revenue</h5>
      <canvas id="revenueChart" height="120"></canvas>
    </div>
  </div>
  <!-- Top Restaurants -->
  <div class="col-12 col-lg-4">
    <div class="card border-0 rounded-4 shadow-sm p-4 h-100">
      <h5 class="fw-semibold mb-3"><i class="bi bi-trophy me-2 text-warning"></i>Top Restaurants</h5>
      <?php foreach($earnings as $i=>$e): ?>
      <div class="d-flex justify-content-between align-items-center mb-2">
        <span class="small"><span class="badge bg-warning text-dark me-2"><?=$i+1?></span><?=htmlspecialchars($e['name'])?></span>
        <span class="fw-bold small">₹<?=number_format($e['revenue'],0)?></span>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
</div>

<!-- Report Table -->
<div class="card border-0 rounded-4 shadow-sm p-4">
  <div class="table-responsive">
    <table class="table table-hover align-middle dataTable">
      <thead class="table-light"><tr>
        <th>Date</th><th>Total Orders</th><th>Delivered</th><th>Cancelled</th><th>Revenue (₹)</th>
      </tr></thead>
      <tbody>
      <?php $totRev=0; foreach($rows as $r): $totRev+= $r['rev']; ?>
      <tr>
        <td><?=date('d M Y',strtotime($r['d']))?></td>
        <td><?=$r['tot']?></td>
        <td class="text-success"><?=$r['del']?></td>
        <td class="text-danger"><?=$r['can']?></td>
        <td class="fw-semibold">₹<?=number_format($r['rev'],2)?></td>
      </tr>
      <?php endforeach; ?>
      </tbody>
      <tfoot><tr class="table-dark fw-bold"><td>Total</td><td><?=array_sum(array_column($rows,'tot'))?></td><td><?=array_sum(array_column($rows,'del'))?></td><td><?=array_sum(array_column($rows,'can'))?></td><td>₹<?=number_format($totRev,2)?></td></tr></tfoot>
    </table>
  </div>
</div>

<script>
new Chart(document.getElementById('revenueChart').getContext('2d'),{
    type:'bar',data:{labels:<?=$chartLabels?>,datasets:[{label:'Revenue (₹)',data:<?=$chartRevenue?>,backgroundColor:'rgba(255,107,53,0.7)',borderRadius:6}]},
    options:{responsive:true,plugins:{legend:{display:false}},scales:{y:{beginAtZero:true}}}
});
$(document).ready(function(){$('.dataTable').DataTable({pageLength:15,ordering:false});});
</script>
<?php include 'layout/footer.php'; ?>

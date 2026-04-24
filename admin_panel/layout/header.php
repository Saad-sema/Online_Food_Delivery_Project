<?php
// Shared header/sidebar for admin panel
// Usage: include 'layout/header.php'; ... include 'layout/footer.php';
$flash = getFlash();
$currentPage = basename($_SERVER['PHP_SELF'], '.php');
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>FoodDash Admin – <?=ucfirst(str_replace('_',' ',$currentPage))?></title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/dataTables.bootstrap5.min.css">
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.8/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.2/dist/chart.umd.min.js"></script>
<style>
:root{--sidebar-w:260px;--brand:#ff6b35;}
body{background:#f5f7fa;font-family:'Segoe UI',sans-serif;}
#sidebar{width:var(--sidebar-w);min-height:100vh;background:linear-gradient(180deg,#1a1a2e,#16213e);position:fixed;top:0;left:0;z-index:1000;transition:.3s;}
#sidebar .brand{padding:20px;border-bottom:1px solid rgba(255,255,255,.1);}
#sidebar .nav-link{color:rgba(255,255,255,.7);padding:12px 20px;border-radius:8px;margin:2px 10px;transition:.2s;font-size:.9rem;}
#sidebar .nav-link:hover,#sidebar .nav-link.active{color:#fff;background:rgba(255,107,53,.25);}
#sidebar .nav-link i{width:22px;}
#main{margin-left:var(--sidebar-w);transition:.3s;}
.topbar{background:#fff;padding:12px 24px;border-bottom:1px solid #e9ecef;display:flex;align-items:center;justify-content:space-between;}
.stat-card{border:none;border-radius:14px;background:#fff;box-shadow:0 2px 12px rgba(0,0,0,.06);}
.stat-card .icon-box{width:56px;height:56px;border-radius:12px;display:flex;align-items:center;justify-content:center;}
.badge-status-pending{background:#fff3cd;color:#856404;}
.badge-status-delivered{background:#d1e7dd;color:#0a3622;}
.badge-status-cancelled{background:#f8d7da;color:#58151c;}
.badge-status-accepted,.badge-status-assigned{background:#cfe2ff;color:#0a3876;}
.badge-status-out_for_delivery{background:#d3f4e0;color:#0c4128;}
@media(max-width:768px){#sidebar{margin-left:calc(-1*var(--sidebar-w));}#main{margin-left:0;}}
</style>
</head>
<body>
<!-- Sidebar -->
<nav id="sidebar">
  <div class="brand text-center">
    <div class="d-flex align-items-center gap-2 justify-content-center">
      <div style="background:var(--brand);border-radius:10px;padding:6px 10px;"><i class="bi bi-bag-heart-fill text-white fs-5"></i></div>
      <span class="text-white fw-bold fs-5">FoodDash</span>
    </div>
    <small class="text-muted">Admin Panel</small>
  </div>
  <ul class="nav flex-column mt-2 px-1">
    <li class="nav-item"><a class="nav-link <?=$currentPage==='dashboard'?'active':''?>" href="dashboard.php"><i class="bi bi-speedometer2"></i> Dashboard</a></li>
    <li class="nav-item"><a class="nav-link <?=$currentPage==='users'?'active':''?>" href="users.php"><i class="bi bi-people"></i> Users</a></li>
    <li class="nav-item"><a class="nav-link <?=$currentPage==='restaurants'?'active':''?>" href="restaurants.php"><i class="bi bi-shop"></i> Restaurants</a></li>
    <li class="nav-item"><a class="nav-link <?=$currentPage==='delivery_boys'?'active':''?>" href="delivery_boys.php"><i class="bi bi-bicycle"></i> Delivery Boys</a></li>
    <li class="nav-item"><a class="nav-link <?=$currentPage==='orders'?'active':''?>" href="orders.php"><i class="bi bi-receipt"></i> Orders</a></li>
    <li class="nav-item"><a class="nav-link <?=$currentPage==='reviews'?'active':''?>" href="reviews.php"><i class="bi bi-star"></i> Reviews</a></li>
    <li class="nav-item"><a class="nav-link <?=$currentPage==='coupons'?'active':''?>" href="coupons.php"><i class="bi bi-ticket-perforated"></i> Coupons</a></li>
    <li class="nav-item"><a class="nav-link <?=$currentPage==='reports'?'active':''?>" href="reports.php"><i class="bi bi-bar-chart-line"></i> Reports</a></li>
    <li class="nav-item"><a class="nav-link <?=$currentPage==='settings'?'active':''?>" href="settings.php"><i class="bi bi-gear"></i> Settings</a></li>
    <li class="nav-item mt-3 border-top border-secondary pt-2">
      <a class="nav-link text-danger" href="logout.php"><i class="bi bi-box-arrow-right"></i> Logout</a>
    </li>
  </ul>
</nav>

<!-- Main -->
<div id="main">
  <div class="topbar">
    <button class="btn btn-sm btn-outline-secondary d-md-none" id="sidebarToggle"><i class="bi bi-list fs-5"></i></button>
    <span class="fw-semibold text-muted"><?=ucfirst(str_replace('_',' ',$currentPage))?></span>
    <div class="d-flex align-items-center gap-3">
      <span class="text-muted small"><i class="bi bi-person-circle me-1"></i><?=htmlspecialchars($_SESSION['admin_name']??'Admin')?></span>
      <a href="logout.php" class="btn btn-sm btn-outline-danger"><i class="bi bi-power"></i></a>
    </div>
  </div>
  <div class="p-4">
    <?php if ($flash): ?>
    <div class="alert alert-<?=$flash['type']?> alert-dismissible fade show">
      <?=htmlspecialchars($flash['msg'])?>
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
    <?php endif; ?>

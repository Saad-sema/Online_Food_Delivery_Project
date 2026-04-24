<?php
require 'config.php';
requireLogin();
$db = db();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    foreach ($_POST as $key => $value) {
        if (in_array($key, ['delivery_charge','tax_percent','app_name','currency_symbol','support_phone','support_email', 'restaurant_visibility_radius'])) {
            $k = $db->real_escape_string($key);
            $v = $db->real_escape_string($value);
            $db->query("INSERT INTO settings (setting_key, value) VALUES ('$k','$v') ON DUPLICATE KEY UPDATE value='$v'");
        }
    }
    flash('Settings saved successfully.');
    header('Location: settings.php'); exit;
}

$result = $db->query("SELECT setting_key, value FROM settings");
$settings = [];
foreach ($result->fetch_all(MYSQLI_ASSOC) as $row) {
    $settings[$row['setting_key']] = $row['value'];
}

include 'layout/header.php';
?>
<div class="mb-4"><h4 class="fw-bold mb-0"><i class="bi bi-gear me-2 text-secondary"></i>Settings</h4></div>

<div class="row g-4">
  <div class="col-12 col-lg-7">
    <div class="card border-0 rounded-4 shadow-sm p-4">
      <h5 class="fw-semibold mb-4">App Configuration</h5>
      <form method="POST">
        <div class="mb-3">
          <label class="form-label fw-semibold">App Name</label>
          <input type="text" name="app_name" class="form-control" value="<?=htmlspecialchars($settings['app_name']??'FoodDash')?>">
        </div>
        <div class="row g-3 mb-3">
          <div class="col">
            <label class="form-label fw-semibold">Delivery Charge (₹)</label>
            <input type="number" name="delivery_charge" class="form-control" step="0.01" value="<?=htmlspecialchars($settings['delivery_charge']??'40.00')?>">
          </div>
          <div class="col">
            <label class="form-label fw-semibold">Tax (%)</label>
            <input type="number" name="tax_percent" class="form-control" step="0.01" value="<?=htmlspecialchars($settings['tax_percent']??'5')?>">
          </div>
          <div class="col">
            <label class="form-label fw-semibold">Visibility Radius (km)</label>
            <input type="number" name="restaurant_visibility_radius" class="form-control" step="1" value="<?=htmlspecialchars($settings['restaurant_visibility_radius']??'15')?>">
          </div>
        </div>
        <div class="mb-3">
          <label class="form-label fw-semibold">Currency Symbol</label>
          <input type="text" name="currency_symbol" class="form-control" value="<?=htmlspecialchars($settings['currency_symbol']??'₹')?>" maxlength="5">
        </div>
        <div class="mb-3">
          <label class="form-label fw-semibold">Support Phone</label>
          <input type="text" name="support_phone" class="form-control" value="<?=htmlspecialchars($settings['support_phone']??'')?>">
        </div>
        <div class="mb-4">
          <label class="form-label fw-semibold">Support Email</label>
          <input type="email" name="support_email" class="form-control" value="<?=htmlspecialchars($settings['support_email']??'')?>">
        </div>
        <button type="submit" class="btn btn-warning fw-bold px-4"><i class="bi bi-save me-2"></i>Save Settings</button>
      </form>
    </div>
  </div>
  <div class="col-12 col-lg-5">
    <div class="card border-0 rounded-4 shadow-sm p-4 bg-dark text-white">
      <h5 class="fw-semibold mb-3"><i class="bi bi-info-circle me-2 text-warning"></i>Quick Notes</h5>
      <ul class="list-unstyled small text-muted">
        <li class="mb-2">⚡ <strong class="text-white">Delivery Charge</strong> is added to each order.</li>
        <li class="mb-2">⚡ <strong class="text-white">Tax</strong> is calculated on (subtotal − coupon discount).</li>
        <li class="mb-2">⚡ <strong class="text-white">Visibility Radius</strong> limits which restaurants a customer can see based on their live location.</li>
        <li class="mb-2">⚡ <strong class="text-white">App Name</strong> appears in FCM push notifications.</li>
        <li class="mb-2">⚡ <strong class="text-white">FCM Server Key</strong> is set in backend/.env</li>
        <li class="mb-2">⚡ <strong class="text-white">JWT Secret</strong> is set in backend/.env</li>
      </ul>
    </div>
  </div>
</div>
<?php include 'layout/footer.php'; ?>

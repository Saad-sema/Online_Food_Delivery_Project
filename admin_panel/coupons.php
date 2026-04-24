<?php
require 'config.php';
requireLogin();
$db = db();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $action = $_POST['action'] ?? '';
  if ($action === 'create') {
    $code = strtoupper(trim($_POST['code'] ?? ''));
    $type = $_POST['discount_type'] ?? 'flat';
    $val = (float) $_POST['discount_value'];
    $min = (float) ($_POST['min_order_amount'] ?? 0);
    $from = $_POST['valid_from'];
    $until = $_POST['valid_until'];
    $limit = (int) ($_POST['usage_limit'] ?? 100);
    $stmt = $db->prepare("INSERT INTO coupons (code,discount_type,discount_value,min_order_amount,valid_from,valid_until,usage_limit) VALUES(?,?,?,?,?,?,?)");
    $stmt->bind_param('ssddssi', $code, $type, $val, $min, $from, $until, $limit);
    flash($stmt->execute() ? 'Coupon created.' : 'Code already exists.', $stmt->execute() ? 'success' : 'danger');
  }
  if ($action === 'toggle') {
    $id = (int) $_POST['id'];
    $db->query("UPDATE coupons SET is_active=NOT is_active WHERE id=$id");
    flash('Coupon status toggled.');
  }
  if ($action === 'delete') {
    $db->query("DELETE FROM coupons WHERE id=" . (int) $_POST['id']);
    flash('Coupon deleted.');
  }
  header('Location: coupons.php');
  exit;
}

$coupons = $db->query("SELECT * FROM coupons ORDER BY created_at DESC")->fetch_all(MYSQLI_ASSOC);
include 'layout/header.php';
?>
<div class="d-flex justify-content-between align-items-center mb-4">
  <h4 class="fw-bold mb-0"><i class="bi bi-ticket-perforated me-2 text-primary"></i>Coupons</h4>
  <button class="btn btn-warning fw-semibold" data-bs-toggle="modal" data-bs-target="#couponModal">
    <i class="bi bi-plus-lg me-1"></i>New Coupon
  </button>
</div>
<div class="card border-0 rounded-4 shadow-sm p-4">
  <div class="table-responsive">
    <table class="table table-hover align-middle dataTable">
      <thead class="table-light">
        <tr>
          <th>Code</th>
          <th>Type</th>
          <th>Value</th>
          <th>Min Order</th>
          <th>Valid Until</th>
          <th>Used</th>
          <th>Status</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($coupons as $c): ?>
          <tr>
            <td><span class="badge bg-dark fs-6 letter-spacing-1"><?= htmlspecialchars($c['code']) ?></span></td>
            <td><?= $c['discount_type'] === 'flat' ? 'Flat ₹' : '%' ?></td>
            <td class="fw-bold">
              <?= $c['discount_type'] === 'flat' ? '₹' : '' ?>  <?= $c['discount_value'] ?>  <?= $c['discount_type'] === 'percent' ? '%' : '' ?>
            </td>
            <td>₹<?= $c['min_order_amount'] ?></td>
            <td><?= date('d M Y', strtotime($c['valid_until'])) ?></td>
            <td><?= $c['used_count'] ?>/<?= $c['usage_limit'] ?></td>
            <td><span
                class="badge <?= $c['is_active'] ? 'bg-success' : 'bg-secondary' ?>"><?= $c['is_active'] ? 'Active' : 'Inactive' ?></span>
            </td>
            <td>
              <form method="POST" class="d-inline"><input type="hidden" name="action" value="toggle"><input type="hidden"
                  name="id" value="<?= $c['id'] ?>">
                <button class="btn btn-sm btn-outline-<?= $c['is_active'] ? 'warning' : 'success' ?>"><i
                    class="bi bi-toggle-<?= $c['is_active'] ? 'on' : 'off' ?>"></i></button>
              </form>
              <form method="POST" class="d-inline" onsubmit="return confirm('Delete coupon?')"><input type="hidden"
                  name="action" value="delete"><input type="hidden" name="id" value="<?= $c['id'] ?>">
                <button class="btn btn-sm btn-outline-danger"><i class="bi bi-trash"></i></button>
              </form>
            </td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>

<!-- Create Coupon Modal -->
<div class="modal fade" id="couponModal" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered">
    <div class="modal-content border-0 shadow rounded-4">
      <div class="modal-header border-0">
        <h5 class="modal-title fw-bold">Create New Coupon</h5><button class="btn-close"
          data-bs-dismiss="modal"></button>
      </div>
      <form method="POST">
        <input type="hidden" name="action" value="create">
        <div class="modal-body row g-3">
          <div class="col-6"><label class="form-label">Code</label><input type="text" name="code"
              class="form-control text-uppercase" required placeholder="SAVE50"></div>
          <div class="col-6"><label class="form-label">Type</label>
            <select name="discount_type" class="form-select">
              <option value="flat">Flat (₹)</option>
              <option value="percent">Percent (%)</option>
            </select>
          </div>
          <div class="col-6"><label class="form-label">Value</label><input type="number" name="discount_value"
              class="form-control" step="0.01" required></div>
          <div class="col-6"><label class="form-label">Min Order (₹)</label><input type="number" name="min_order_amount"
              class="form-control" step="0.01" value="0"></div>
          <div class="col-6"><label class="form-label">Valid From</label><input type="date" name="valid_from"
              class="form-control" value="<?= date('Y-m-d') ?>" required></div>
          <div class="col-6"><label class="form-label">Valid Until</label><input type="date" name="valid_until"
              class="form-control" required></div>
          <div class="col-12"><label class="form-label">Usage Limit</label><input type="number" name="usage_limit"
              class="form-control" value="100"></div>
        </div>
        <div class="modal-footer border-0">
          <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancel</button>
          <button type="submit" class="btn btn-warning fw-semibold"><i class="bi bi-plus-lg me-1"></i>Create</button>
        </div>
      </form>
    </div>
  </div>
</div>
<script>$(document).ready(function () { $('.dataTable').DataTable({ pageLength: 20 }); });</script>
<?php include 'layout/footer.php'; ?>
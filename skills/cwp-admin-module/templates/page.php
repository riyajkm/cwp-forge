<?php
if(!isset($include_path)){echo "invalid access";exit();}
// CWPMOD_TITLE admin page. Engine calls and AJAX handlers live in cwpmod_example/lib.php.
require_once __DIR__ . '/cwpmod_example/lib.php';
$T = cwpmod_example_lang();
$tx = function ($k) use ($T) { return cwpmod_example_h($T[$k] ?? $k); };
// AJAX goes through loader_ajax.php (never index.php?module=...&acc=..., which returns the whole layout).
$cfg = ['url' => 'loader_ajax.php?ajax=cwpmod_example', 'csrf' => cwpmod_example_csrf(), 't' => $T];
?>
<div id="cwpmod_example">
<style>
#cwpmod_example .m-wrap{overflow-x:auto}
#cwpmod_example .tab-content{padding-top:15px}
#cwpmod_example .m-spin{display:inline-block;width:12px;height:12px;border:2px solid currentColor;border-right-color:transparent;border-radius:50%;animation:mspin .8s linear infinite;vertical-align:-2px}
@keyframes mspin{to{transform:rotate(360deg)}}
@media (prefers-reduced-motion:reduce){#cwpmod_example .m-spin{animation:none}}
</style>

<h4><?= $tx('TITLE') ?></h4>
<div id="m-alert" aria-live="polite"></div>

<ul class="nav nav-tabs" role="tablist">
  <li class="active"><a href="#m-overview" data-toggle="tab"><?= $tx('TAB_OVERVIEW') ?></a></li>
  <li><a href="#m-accounts" data-toggle="tab"><?= $tx('TAB_ACCOUNTS') ?></a></li>
</ul>
<div class="tab-content">
  <div class="tab-pane active" id="m-overview">
    <div class="panel panel-default"><div class="panel-body">
      <strong><?= $tx('ENGINE_VERSION') ?>:</strong> <span id="m-version"><span class="m-spin" aria-hidden="true"></span></span>
    </div></div>
  </div>
  <div class="tab-pane" id="m-accounts">
    <div class="form-inline" style="margin-bottom:10px">
      <label for="m-q" class="sr-only"><?= $tx('SEARCH_PH') ?></label>
      <input type="text" id="m-q" class="form-control" placeholder="<?= $tx('SEARCH_PH') ?>" autocomplete="off">
    </div>
    <div class="m-wrap"><table class="table table-striped table-hover">
      <thead><tr><th><?= $tx('COL_USER') ?></th><th><?= $tx('COL_DOMAIN') ?></th><th><?= $tx('COL_PACKAGE') ?></th><th><?= $tx('COL_DISK') ?></th><th></th></tr></thead>
      <tbody id="m-rows"></tbody>
    </table></div>
  </div>
</div>

<script>
window.CWPM_CWPMOD_EXAMPLE = <?= cwpmod_example_json($cfg) ?>;
(function ($) {
  var C = window.CWPM_CWPMOD_EXAMPLE, T = C.t;

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c]; }); }
  function alertBox(type, msg) { return '<div class="alert alert-' + type + '" role="alert">' + esc(msg) + '</div>'; }

  // Explicit Deferred: on CWP's page $.ajax().then() behaves like old jQuery (callbacks get (data, status, xhr), return values are not passed on).
  function api(acc, data, post) {
    var o = {url: C.url + '&acc=' + acc, dataType: 'json', type: post ? 'POST' : 'GET', data: post ? $.extend({csrf: C.csrf}, data || {}) : (data || {})};
    var d = $.Deferred();
    $.ajax(o).done(function (r) { if (r && r.ok) { d.resolve(r.data); } else { d.reject((r && r.error) || T.E_NET); } })
      .fail(function (x) { var m = x.responseJSON && x.responseJSON.error; d.reject(m || T.E_NET); });
    return d.promise();
  }

  function loadOverview() {
    api('status').done(function (s) { $('#m-version').text(s.version || '-'); })
      .fail(function (e) { $('#m-alert').html(alertBox('danger', e)); });
  }
  var qTimer = null;
  function loadAccounts() {
    api('accounts', {q: $('#m-q').val()}).done(function (rows) {
      var h = '';
      $.each(rows, function (i, r) {
        h += '<tr><td>' + esc(r.username) + '</td><td>' + esc(r.domain) + '</td><td>' + esc(r.package) + '</td>' +
          '<td class="m-disk"></td><td><button type="button" class="btn btn-default btn-xs m-usage" data-u="' + esc(r.username) + '">' + esc(T.BTN_USAGE) + '</button></td></tr>';
      });
      $('#m-rows').html(h || '<tr><td colspan="5">' + esc(T.NO_ROWS) + '</td></tr>');
    }).fail(function (e) { $('#m-alert').html(alertBox('danger', e)); });
  }
  $('#m-q').on('input', function () { clearTimeout(qTimer); qTimer = setTimeout(loadAccounts, 300); });
  $('#m-rows').on('click', '.m-usage', function () {
    var cell = $(this).closest('tr').find('.m-disk');
    api('usage', {account: $(this).data('u')}).done(function (u) { cell.text(u.disk_kb); })
      .fail(function (e) { $('#m-alert').html(alertBox('danger', e)); });
  });

  // CWP's theme does not always fire Bootstrap's shown.bs.tab, so react to the click as well (once per click).
  var lastTab = {t: '', at: 0};
  function onTab(t) {
    if (lastTab.t === t && Date.now() - lastTab.at < 500) { return; }
    lastTab = {t: t, at: Date.now()};
    if (t === '#m-accounts') { loadAccounts(); }
  }
  $('#cwpmod_example a[data-toggle="tab"]')
    .on('shown.bs.tab', function (e) { onTab($(e.target).attr('href')); })
    .on('click', function () { var t = $(this).attr('href'); setTimeout(function () { onTab(t); }, 50); });
  loadOverview();
})(jQuery);
</script>
</div>

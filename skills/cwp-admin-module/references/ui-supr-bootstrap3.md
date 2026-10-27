# Admin UI: theme "Supr", Bootstrap 3

## Assets already loaded (do not add CDNs)
CSS: `design/css/bootstrap.css` (Bootstrap 3), `icons.css` (icomoon), `main.css`, `custom.css`.
JS: jQuery 2.1.1, jquery-ui, jquery-migrate 1.2.1, bootstrap.js, bootbox.js, jquery.gritter, bootstrap-notify, jquery.supr.js.

## Markup
- Content sits in `.page-content`; your module is rendered inside it. Wrap everything in a root `<div id="<name>">` and scope CSS and JS to it.
- Components: `.panel .panel-default` (+ `.panel-heading`, `.panel-body`), `.btn .btn-primary|btn-default|btn-warning|btn-danger .btn-xs`, `.table .table-striped .table-hover` inside an `overflow-x:auto` wrapper, `.form-group`, `.form-control`, `.form-inline`, `.alert .alert-danger|warning|success|info`, `.label .label-success`, `.nav .nav-tabs` + `.tab-content .tab-pane`.
- Menu icons: `<span class="icon16 icomoon-icon-database"></span>` (icomoon names, for example `icomoon-icon-cog`, `-database`, `-arrow-right-3`).
- Accessibility basics: real `<label for>` (or `sr-only`), `aria-live="polite"` on message areas, `role="alert"` on error boxes, `prefers-reduced-motion` for spinners.

## jQuery 2.1.1 quirks on CWP's page
- `$.ajax(...).then(fn)` behaves like old jQuery: the callback gets `(data, status, xhr)` and the return value is not passed on (callbacks saw an Array). Wrap every request in an explicit `$.Deferred()` and call `resolve`/`reject` yourself. Do not chain `.then` transforms. `.done`/`.fail` on your own promise are safe.
- `$.when(a, b)` over your own deferreds works; results arrive as separate arguments.
- Use `.on()`, delegated handlers for rendered rows, `.data()` for `data-*`. No arrow functions, `let`, template literals, `fetch` or `Promise` in code that must run on older browsers/themes; ES5 is enough.

## Tabs
`shown.bs.tab` does not fire reliably under this theme. Bind it AND a `click` handler (`setTimeout(…, 50)`) and de-duplicate within 500 ms (see `page.php`). Load tab data lazily from `onTab()`.

## Feedback
- Inline `.alert` boxes for errors (always `esc()` the message).
- `$.gritter.add({title, text, time})` for toasts, guarded with `if ($.gritter)`; `bootbox.confirm` for destructive actions, guarded with a `window.confirm` fallback.
- Confirm before anything irreversible (delete, restore over existing data). Disable the button while a request runs.

## Escaping rules
- PHP output: `<name>_h()` (ENT_QUOTES). JS output into HTML: `esc()`. Never put user data into `innerHTML`, `.html()`, an `on*` attribute, a `javascript:` URL or a `<script>` block unescaped.
- Data from PHP to JS: `json_encode` with `JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS|JSON_HEX_QUOT` into `window.X = ...;`.

# Twig template and UI rules (user panel)

## Contract
- `mod_<name>.html` is rendered by Twig with three variables: `mod` (whatever the PHP file put in `$mod`), `langmod` (all keys of your ini), `users` (the logged-in username, also used to build the module URL).
- Theme assets: `{{ url }}/css/...`, `{{ url }}/js/...`. The shipped `original` theme is Inspinia-style Bootstrap 3 and loads Font Awesome, Toastr, Gritter, Switchery, Ladda, DataTables, iCheck. Reuse what is loaded; add no CDNs.
- Theme files in `original` are overwritten by CWP updates. Clone a theme for permanent branding, and list every theme that must carry your template in `THEMES="original mytheme"` (fix-module copies it into each).

## Escaping
- Autoescape settings are not documented: always write `|e` (HTML text), `|e('html_attr')` (attribute values), `|e('js')` (inside JS strings). Never use `|raw` on user data.
- Language strings with HTML are a trap: keep them plain text.

## JavaScript inside the template
- Twig parses the whole file. Avoid the sequences `{{`, `{%`, `{#` in JS and CSS (write `{ {` or restructure). Object literals like `{a: 1}` are fine.
- Pass server values as `data-*` attributes on an element (`data-url`, `data-csrf`) and read them with `.data()`.
- ES5 only; wrap `$.ajax` in an explicit `$.Deferred()` and use `.done/.fail` on it; escape everything inserted with `.html()` (`esc()` helper in the template).
- Module URL: `./{{ users }}/index.php?module=<name>&acc=<action>`; send `csrf` as a POST field.
- Toasts: `toastr.success/error` exist in the original theme; guard with `if (window.toastr)` and fall back to an inline `.alert`.

## UX defaults
- Disable the action button while a job is queued; poll `status` every 3 s with a cap; show a generic failure text, never raw server errors.
- Accessible markup: `label for`, `aria-live="polite"` message area, `role="alert"` for errors, tables in an `overflow-x:auto` wrapper.
- Scope CSS under the root id (`#<name>`).

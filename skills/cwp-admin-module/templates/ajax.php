<?php
if(!isset($ajax_file)){echo "invalid access";exit();}
// AJAX entry for CWPMOD_TITLE, called as loader_ajax.php?ajax=cwpmod_example&acc=<action>. All logic lives in the shared lib.
require_once dirname(__DIR__, 2) . '/modules/cwpmod_example/lib.php';
cwpmod_example_db(isset($mysql_conn) ? $mysql_conn : null);
cwpmod_example_dispatch(is_string($_GET['acc'] ?? null) ? $_GET['acc'] : '');

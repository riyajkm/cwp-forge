<?php
/**
 * CWP action hook stub. Copy to
 *   /usr/local/cwpsrv/htdocs/resources/admin/hooks/account/account_new.php
 * (file name == function name). For another event rename BOTH, and change $event.
 *
 * It runs inside the panel's PHP as root with a minimal environment, so it only
 * validates and hands off to a detached worker. It never throws, never echoes,
 * never exits (that would end the panel request).
 *
 * Debug: `touch /var/lib/cwp-forge/hook-debug` dumps the raw argument array to the log
 * so you can learn its shape on your CWP version (keys vs positions is unverified).
 */
function account_new($array)
{
    $event  = 'account_new';
    $worker = '/usr/local/sbin/cwp-hook-worker.sh';
    $logdir = '/var/log/cwp-forge';

    try {
        if (!is_dir($logdir)) {
            @mkdir($logdir, 0750, true);
        }
        $log = function ($msg) use ($logdir, $event) {
            @file_put_contents($logdir . '/hooks.log', date('c') . " $event $msg\n", FILE_APPEND | LOCK_EX);
        };

        if (is_file('/var/lib/cwp-forge/hook-debug')) {
            $log('raw=' . json_encode($array));
        }
        if (!is_array($array)) {
            $log('ignored: argument is not an array');
            return;
        }

        // Accept associative or positional arrays.
        $user   = isset($array['username']) ? $array['username'] : (isset($array[0]) ? $array[0] : '');
        $domain = isset($array['domain']) ? $array['domain'] : (isset($array[1]) ? $array[1] : '');
        $user   = is_string($user) ? $user : '';
        $domain = is_string($domain) ? strtolower($domain) : '';

        if (!preg_match('/^[a-z][a-z0-9]{0,31}$/', $user)) {
            $log('rejected: bad username');
            return;
        }
        if ($domain !== '' && !preg_match('/^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/', $domain)) {
            $log('rejected: bad domain');
            return;
        }
        if (!is_executable($worker)) {
            $log('worker missing or not executable');
            return;
        }

        // Argument array: no shell. setsid -f detaches so the panel never waits.
        $cmd = ['/usr/bin/setsid', '-f', $worker, '--apply', $event, $user, $domain];
        $null = ['file', '/dev/null', 'r'];
        $out  = ['file', '/dev/null', 'a'];
        $proc = @proc_open($cmd, [0 => $null, 1 => $out, 2 => $out], $pipes, '/', ['PATH' => '/usr/sbin:/usr/bin:/sbin:/bin']);
        if (is_resource($proc)) {
            proc_close($proc); // returns at once: setsid -f forks
            $log("queued user=$user domain=$domain");
        } else {
            $log('proc_open failed');
        }
    } catch (\Throwable $e) {
        // Never break the panel action.
        @file_put_contents($logdir . '/hooks.log', date('c') . " $event error: " . $e->getMessage() . "\n", FILE_APPEND | LOCK_EX);
    }
}

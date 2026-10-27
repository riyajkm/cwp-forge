"""Minimal CWP (Control Web Panel) API client. Standard library only, Python 3.6+.

Config from the environment (never hard-code the key):
  CWP_HOST        server host or host:port (default port 2304)
  CWP_API_KEY     API key from CWP Settings > API Manager
  CWP_VERIFY_TLS  "0" to skip certificate verification (self-signed lab only)
  CWP_CACERT      optional CA bundle path for a private CA

Usage:
  from cwp_api import cwp_api
  accounts = cwp_api("account", action="list")["msj"]
"""
import json
import os
import ssl
import urllib.error
import urllib.parse
import urllib.request


class CwpApiError(RuntimeError):
    pass


def _redact(text, key):
    return text.replace(key, "REDACTED") if key else text


def _leading_json(body):
    """Decode the first JSON value in body; `account del` appends an HTML log."""
    body = body.lstrip()
    if not body or body[0] not in "{[":
        return None
    try:
        value, _ = json.JSONDecoder().raw_decode(body)
        return value
    except ValueError:
        return None


def cwp_api(function, timeout=120, **params):
    host = os.environ.get("CWP_HOST", "")
    key = os.environ.get("CWP_API_KEY", "")
    if not host or not key:
        raise CwpApiError("Set CWP_HOST and CWP_API_KEY")
    if not function.replace("_", "").isalpha() or not function.islower():
        raise CwpApiError("Invalid function name")
    if ":" not in host:
        host += ":2304"

    ctx = ssl.create_default_context(cafile=os.environ.get("CWP_CACERT") or None)
    if os.environ.get("CWP_VERIFY_TLS") == "0":
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

    data = urllib.parse.urlencode(dict(params, key=key)).encode()  # in the body, not the URL
    req = urllib.request.Request("https://%s/v1/%s/" % (host, function), data=data, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            body = resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
    except (urllib.error.URLError, OSError) as e:
        raise CwpApiError("CWP API connection error: " + _redact(str(e), key))

    parsed = _leading_json(body)
    if not isinstance(parsed, (dict, list)):
        raise CwpApiError("CWP API returned a non-JSON response")
    # accountquota has no "status"; a missing status counts as OK.
    if isinstance(parsed, dict) and parsed.get("status", "OK") != "OK":
        msg = parsed.get("msj") or parsed.get("result") or parsed.get("message") or "unknown error"
        raise CwpApiError("CWP API error: " + _redact(msg if isinstance(msg, str) else json.dumps(msg), key))
    return parsed


def account_exists(user):
    """Reconcile before retrying an `add` after a timeout."""
    return any(a.get("username") == user for a in cwp_api("account", action="list").get("msj", []))


def package_id(name):
    r = cwp_api("packages", action="list")
    for p in r.get("msj") or r.get("result") or []:
        if p.get("package_name") == name:
            return int(p["id"])
    return None


if __name__ == "__main__":
    print(json.dumps(cwp_api("testconex"), indent=2))

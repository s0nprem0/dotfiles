import time

_cache: dict[str, tuple] = {}


def cached(key: str, fn, ttl: float = 3.0):
    now = time.monotonic()
    if key in _cache:
        val, ts = _cache[key]
        if now - ts < ttl:
            return val
    val = fn()
    _cache[key] = (val, now)
    return val


def invalidate(key: str | None = None):
    if key:
        _cache.pop(key, None)
    else:
        _cache.clear()

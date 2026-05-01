"""Простое in-memory ограничение частоты (достаточно для одного процесса / диплома)."""

from __future__ import annotations

import time
from collections import defaultdict
from threading import Lock

from fastapi import HTTPException, status

_lock = Lock()
_buckets: dict[str, list[float]] = defaultdict(list)


def enforce_hourly_limit(key: str, max_events: int, detail: str) -> None:
    now = time.time()
    with _lock:
        bucket = _buckets[key]
        bucket[:] = [t for t in bucket if now - t < 3600]
        if len(bucket) >= max_events:
            raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, detail)
        bucket.append(now)

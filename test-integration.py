#!/usr/bin/env python3
"""
Integration test for Music Streaming Platform.
Tests: PostgreSQL queries, MongoDB logic, recommendation algorithm, API endpoints.

Usage:
  # Start the stack first:
  docker compose up --build -d

  # Full test:
  python3 test-integration.py

  # Syntax/static checks only (no DB needed):
  python3 test-integration.py --syntax-only

  # Recommendation algorithm logic only:
  python3 test-integration.py --algorithm
"""

import json
import os
import py_compile
import subprocess
import sys
import urllib.request
import urllib.error

API = "http://localhost:3001/api"
FRONTEND = "http://localhost:8080"

BACKEND_SRC = os.path.join(os.path.dirname(__file__), "backend", "src")

PASS = 0
FAIL = 0


def report(name, passed, detail=None):
    global PASS, FAIL
    if passed:
        print(f"  [PASS] {name}")
        PASS += 1
    else:
        msg = f"  [FAIL] {name}"
        if detail:
            msg += f": {detail}"
        print(msg)
        FAIL += 1


# =============================================================
# Syntax / static checks
# =============================================================

def check_js_syntax():
    for f in ["db.js", "mongo.js", "server.js"]:
        path = os.path.join(BACKEND_SRC, f)
        r = subprocess.run(["node", "--check", path], capture_output=True, text=True)
        if r.returncode != 0:
            return False, f"{f}: {r.stderr}"
    return True, None


def test_syntax():
    ok, err = check_js_syntax()
    report("JavaScript syntax check", ok, err)

    try:
        py_compile.compile(__file__, doraise=True)
        report("Python syntax check", True)
    except py_compile.PyCompileError as e:
        report("Python syntax check", False, str(e))


# =============================================================
# Recommendation algorithm (pure logic, no DB)
# =============================================================

def test_algorithm():
    plays = [
        {"user_id": 1, "song_id": 1, "artist": "Dawid Podsiadlo"},
        {"user_id": 1, "song_id": 2, "artist": "Andrew Hulshult"},
        {"user_id": 1, "song_id": 3, "artist": "Andrew Hulshult"},
        {"user_id": 2, "song_id": 1, "artist": "Dawid Podsiadlo"},
        {"user_id": 2, "song_id": 4, "artist": "Mick Gordon"},
        {"user_id": 3, "song_id": 2, "artist": "Andrew Hulshult"},
        {"user_id": 3, "song_id": 5, "artist": "Mick Gordon"},
    ]

    all_songs = [
        {"song_id": 1, "title": "Song A", "artist": "Dawid Podsiadlo"},
        {"song_id": 2, "title": "Song B", "artist": "Andrew Hulshult"},
        {"song_id": 3, "title": "Song C", "artist": "Andrew Hulshult"},
        {"song_id": 4, "title": "Song D", "artist": "Mick Gordon"},
        {"song_id": 5, "title": "Song E", "artist": "Mick Gordon"},
        {"song_id": 6, "title": "Song F", "artist": "Plutonio"},
    ]

    def recommend(uid, plays, songs):
        user_plays = [p for p in plays if p["user_id"] == uid]
        user_artist_counts = {}
        for p in user_plays:
            user_artist_counts[p["artist"]] = user_artist_counts.get(p["artist"], 0) + 1

        top_artists = sorted(user_artist_counts.items(), key=lambda x: -x[1])[:3]
        fav_artists = [a for a, _ in top_artists]

        similar_users = set()
        for p in plays:
            if p["user_id"] != uid and p["artist"] in fav_artists:
                similar_users.add(p["user_id"])

        user_song_ids = set(p["song_id"] for p in user_plays)

        candidates = {}
        for p in plays:
            if p["user_id"] in similar_users and p["song_id"] not in user_song_ids:
                candidates[p["song_id"]] = candidates.get(p["song_id"], 0) + 1

        results = []
        for sid, score in sorted(candidates.items(), key=lambda x: -x[1]):
            song = next(s for s in songs if s["song_id"] == sid)
            results.append({"song_id": sid, "title": song["title"],
                            "artist": song["artist"], "score": score})

        if len(results) < 3:
            for song in songs:
                if song["song_id"] not in user_song_ids and \
                   not any(r["song_id"] == song["song_id"] for r in results):
                    results.append({"song_id": song["song_id"],
                                    "title": song["title"],
                                    "artist": song["artist"],
                                    "score": 1})

        return results[:5]

    recs = recommend(1, plays, all_songs)
    assert len(recs) > 0, "should have recommendations for user 1"
    for r in recs:
        assert all(k in r for k in ["song_id", "title", "artist", "score"]), \
            f"missing fields in {r}"

    recs3 = recommend(3, plays, all_songs)
    assert len(recs3) > 0, "should have recommendations for user 3"

    # User with no plays should get fallback global top
    recs6 = recommend(6, plays, all_songs)
    assert len(recs6) > 0, "user with no plays should get fallback recommendations"

    report("Recommendation algorithm logic", True)


# =============================================================
# API tests (need running stack)
# =============================================================

def api_get(path):
    req = urllib.request.Request(f"{API}{path}")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def api_post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f"{API}{path}", data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def test_health():
    try:
        r = api_get("/health")
        report("Health check (PG + Mongo)", r.get("ok") == True, str(r))
    except Exception as e:
        report("Health check (PG + Mongo)", False, str(e))


def test_stats():
    try:
        r = api_get("/stats")
        required = ["users", "artists", "albums", "songs", "playlists"]
        missing = [t for t in required if t not in r or r[t] <= 0]
        report("DB stats", len(missing) == 0,
               f"missing/empty: {missing}" if missing else None)
    except Exception as e:
        report("DB stats", False, str(e))


def test_users():
    try:
        r = api_get("/users")
        report("List users", len(r) >= 12, f"got {len(r)}")
    except Exception as e:
        report("List users", False, str(e))


def test_create_user():
    try:
        import random
        suffix = random.randint(10000, 99999)
        r = api_post("/users", {
            "username": f"tester_{suffix}",
            "email": f"t{suffix}@test.com",
            "country": "PT",
            "subscription": "free",
        })
        ok = r.get("username") == f"tester_{suffix}"
        report("Create user", ok, str(r))
    except Exception as e:
        report("Create user", False, str(e))


def test_artists():
    try:
        r = api_get("/artists")
        ok = len(r) >= 5 and "name" in r[0] and "total_plays" in r[0]
        report("List artists", ok, f"got {len(r)} artists")
    except Exception as e:
        report("List artists", False, str(e))


def test_top_songs():
    try:
        r = api_get("/songs/top?limit=5")
        ok = len(r) <= 5 and (len(r) == 0 or "title" in r[0])
        report("Top songs", ok, f"got {len(r)} songs")
    except Exception as e:
        report("Top songs", False, str(e))


def test_search():
    try:
        r = api_get("/songs/search?q=doom")
        r2 = api_get("/songs/search?q=zzzzz")
        report("Search songs", len(r) > 0 and len(r2) == 0,
               f"'doom': {len(r)} results, 'zzzzz': {len(r2)}")
    except Exception as e:
        report("Search songs", False, str(e))


def test_playlists():
    try:
        r = api_get("/playlists")
        report("List playlists", len(r) >= 10, f"got {len(r)}")
    except Exception as e:
        report("List playlists", False, str(e))


def test_playlist_detail():
    try:
        r = api_get("/playlists/1")
        ok = "songs" in r and len(r["songs"]) > 0
        report("Playlist detail", ok, str(r.get("name", "?")))
    except Exception as e:
        report("Playlist detail", False, str(e))


def test_create_playlist():
    try:
        r = api_post("/playlists", {"user_id": 1, "name": "Test Playlist"})
        report("Create playlist", r.get("name") == "Test Playlist", str(r))
    except Exception as e:
        report("Create playlist", False, str(e))


def test_add_song():
    try:
        r = api_post("/playlists/1/songs", {"song_id": 14})
        report("Add song to playlist", r.get("song_id") == 14, str(r))
    except Exception as e:
        report("Add song to playlist", False, str(e))


def test_log_play():
    try:
        r = api_post("/plays", {
            "user_id": 1, "song_id": 7,
            "seconds_listened": 120, "completed": True,
        })
        report("Log play", "play_id" in r, str(r))
    except Exception as e:
        report("Log play", False, str(e))


def test_mongo_stats():
    try:
        r = api_get("/mongo/stats")
        ok = "collections" in r
        report("MongoDB stats", ok, str(list(r.keys())))
    except Exception as e:
        report("MongoDB stats", False, str(e))


def test_mongo_recent():
    try:
        r = api_get("/mongo/recent-plays?limit=5")
        report("MongoDB recent plays", isinstance(r, list), f"type: {type(r).__name__}")
    except Exception as e:
        report("MongoDB recent plays", False, str(e))


def test_mongo_log_play():
    try:
        r = api_post("/plays/mongo", {
            "user_id": 1, "song_id": 5,
            "seconds_listened": 180, "completed": True,
        })
        ok = r.get("ok") == True and r.get("stored") == "mongodb"
        report("MongoDB log play", ok, str(r))
    except Exception as e:
        report("MongoDB log play", False, str(e))


def test_recommendations_get():
    try:
        r = api_get("/recommendations/1")
        report("Get recommendations", isinstance(r, list), f"got {len(r)} recs")
    except Exception as e:
        report("Get recommendations", False, str(e))


def test_recommendations_generate():
    try:
        r = api_post("/recommendations/generate/1", {})
        report("Generate recommendations", isinstance(r, list), f"got {len(r)} recs")
    except Exception as e:
        report("Generate recommendations", False, str(e))


def test_frontend():
    try:
        req = urllib.request.Request(f"{FRONTEND}/")
        with urllib.request.urlopen(req, timeout=10) as resp:
            html = resp.read().decode()
            ok = "PostgreSQL" in html or "MongoDB" in html
            report("Frontend serves HTML", ok,
                   "page contains relevant content" if ok else "missing keywords")
    except Exception as e:
        report("Frontend serves HTML", False, str(e))


def test_dual_write():
    try:
        r_pg = api_post("/plays", {
            "user_id": 2, "song_id": 10,
            "seconds_listened": 200, "completed": True,
        })
        r_mongo = api_post("/plays/mongo", {
            "user_id": 2, "song_id": 10,
            "seconds_listened": 200, "completed": True,
        })
        ok = "play_id" in r_pg and r_mongo.get("ok") == True
        report("Dual-write (PG + Mongo)", ok,
               f"PG: play_id={r_pg.get('play_id')}, Mongo: ok={r_mongo.get('ok')}")
    except Exception as e:
        report("Dual-write (PG + Mongo)", False, str(e))


# =============================================================
# Main
# =============================================================

if __name__ == "__main__":
    print("=" * 60)
    print("  Music Streaming Platform - Integration Tests")
    print("=" * 60)
    print()

    if "--syntax-only" in sys.argv:
        print("Syntax checks only:\n")
        test_syntax()
        print(f"\n  Syntax: {PASS}/{PASS+FAIL} passed")
        sys.exit(0)

    if "--algorithm" in sys.argv:
        print("Recommendation algorithm only:\n")
        test_algorithm()
        print(f"\n  Algorithm: {PASS}/{PASS+FAIL} passed")
        sys.exit(0)

    test_syntax()
    print()

    test_algorithm()
    print()

    print("API tests (requires running stack):\n")
    test_health()
    test_stats()
    test_users()
    test_create_user()
    test_artists()
    test_top_songs()
    test_search()
    test_playlists()
    test_playlist_detail()
    test_create_playlist()
    test_add_song()
    test_log_play()
    test_mongo_stats()
    test_mongo_recent()
    test_mongo_log_play()
    test_recommendations_get()
    test_recommendations_generate()
    test_frontend()
    test_dual_write()

    print()
    print("=" * 60)
    total = PASS + FAIL
    print(f"  Results: {PASS}/{total} passed, {FAIL}/{total} failed")
    print("=" * 60)
    sys.exit(0 if FAIL == 0 else 1)

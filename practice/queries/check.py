#!/usr/bin/env python3
"""
check50-style verifier for the 15 query exercises.

Usage:
    python3 practice/queries/check.py             # all exercises
    python3 practice/queries/check.py 03 07 12    # specific ones

Requires: python3, docker (with the project's `docker compose up -d` already running).
The script shells out to the running `db` container — no Python deps needed.
"""

import os
import re
import sys
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent  # project root (has docker-compose.yml)

# ANSI colors (degrade gracefully when stdout isn't a TTY)
ISATTY = sys.stdout.isatty()
def c(code, text):
    return f"\033[{code}m{text}\033[0m" if ISATTY else text
GREEN  = lambda s: c("32", s)
RED    = lambda s: c("31", s)
YELLOW = lambda s: c("33", s)
DIM    = lambda s: c("2",  s)
BOLD   = lambda s: c("1",  s)


# ---------------------------------------------------------------------------
# The canonical answers. Each entry contains:
#   - file:     student stub filename
#   - title:    short label
#   - ordered:  whether row order matters (True) or set-equality is enough
#   - sql:      reference query (must match the prompt exactly)
# ---------------------------------------------------------------------------
EXERCISES = {
    "01": {
        "file": "01-songs-with-album-artist.sql",
        "title": "All songs with album and artist",
        "ordered": True,
        "sql": """
            SELECT s.song_id, s.title, al.title, ar.name
            FROM songs s
            JOIN albums  al ON al.album_id  = s.album_id
            JOIN artists ar ON ar.artist_id = al.artist_id
            ORDER BY s.song_id
        """,
    },
    "02": {
        "file": "02-long-songs.sql",
        "title": "Songs longer than 4 minutes",
        "ordered": True,
        "sql": """
            SELECT s.title, ar.name, s.duration_seconds
            FROM songs s
            JOIN albums  al ON al.album_id  = s.album_id
            JOIN artists ar ON ar.artist_id = al.artist_id
            WHERE s.duration_seconds > 240
            ORDER BY s.duration_seconds DESC, s.title ASC
        """,
    },
    "03": {
        "file": "03-song-count-per-artist.sql",
        "title": "Song count per artist",
        "ordered": True,
        "sql": """
            SELECT ar.name, COUNT(s.song_id)::int
            FROM artists ar
            LEFT JOIN albums al ON al.artist_id = ar.artist_id
            LEFT JOIN songs  s  ON s.album_id   = al.album_id
            GROUP BY ar.artist_id, ar.name
            ORDER BY COUNT(s.song_id) DESC, ar.name ASC
        """,
    },
    "04": {
        "file": "04-top-5-songs.sql",
        "title": "Top 5 most-played songs",
        "ordered": True,
        "sql": """
            SELECT s.title, ar.name, s.play_count
            FROM songs s
            JOIN albums  al ON al.album_id  = s.album_id
            JOIN artists ar ON ar.artist_id = al.artist_id
            ORDER BY s.play_count DESC, s.title ASC
            LIMIT 5
        """,
    },
    "05": {
        "file": "05-users-with-playlists.sql",
        "title": "Users who own at least one playlist",
        "ordered": True,
        "sql": """
            SELECT DISTINCT u.username
            FROM users u
            JOIN playlists p ON p.user_id = u.user_id
            ORDER BY u.username ASC
        """,
    },
    "06": {
        "file": "06-albums-avg-duration.sql",
        "title": "Albums with average duration > 250 s",
        "ordered": True,
        "sql": """
            SELECT al.title, ROUND(AVG(s.duration_seconds))::int
            FROM albums al
            JOIN songs s ON s.album_id = al.album_id
            GROUP BY al.album_id, al.title
            HAVING AVG(s.duration_seconds) > 250
            ORDER BY ROUND(AVG(s.duration_seconds))::int DESC, al.title ASC
        """,
    },
    "07": {
        "file": "07-big-playlists.sql",
        "title": "Playlists with more than 4 songs",
        "ordered": True,
        "sql": """
            SELECT p.name, u.username, COUNT(ps.song_id)::int
            FROM playlists p
            JOIN users u            ON u.user_id  = p.user_id
            JOIN playlist_songs ps  ON ps.playlist_id = p.playlist_id
            GROUP BY p.playlist_id, p.name, u.username
            HAVING COUNT(ps.song_id) > 4
            ORDER BY COUNT(ps.song_id) DESC, p.name ASC
        """,
    },
    "08": {
        "file": "08-orphan-songs.sql",
        "title": "Songs not in any playlist",
        "ordered": True,
        "sql": """
            SELECT s.song_id, s.title
            FROM songs s
            LEFT JOIN playlist_songs ps ON ps.song_id = s.song_id
            WHERE ps.song_id IS NULL
            ORDER BY s.song_id ASC
        """,
    },
    "09": {
        "file": "09-listening-time.sql",
        "title": "Total listening time per user",
        "ordered": True,
        "sql": """
            SELECT u.username, SUM(ph.seconds_listened)::bigint
            FROM users u
            JOIN play_history ph ON ph.user_id = u.user_id
            GROUP BY u.user_id, u.username
            ORDER BY SUM(ph.seconds_listened) DESC, u.username ASC
        """,
    },
    "10": {
        "file": "10-silent-users.sql",
        "title": "Users with no play history",
        "ordered": True,
        "sql": """
            SELECT u.username
            FROM users u
            LEFT JOIN play_history ph ON ph.user_id = u.user_id
            WHERE ph.user_id IS NULL
            ORDER BY u.username ASC
        """,
    },
    "11": {
        "file": "11-top-genre.sql",
        "title": "Genre with the highest total plays",
        "ordered": True,
        "sql": """
            SELECT ar.genre, SUM(s.play_count)::bigint
            FROM artists ar
            JOIN albums al ON al.artist_id = ar.artist_id
            JOIN songs  s  ON s.album_id   = al.album_id
            GROUP BY ar.genre
            ORDER BY SUM(s.play_count) DESC, ar.genre ASC
            LIMIT 1
        """,
    },
    "12": {
        "file": "12-user-longest-listen.sql",
        "title": "Each user's longest single listen",
        "ordered": True,
        "sql": """
            SELECT username, song_title, seconds_listened FROM (
                SELECT u.username,
                       s.title AS song_title,
                       ph.seconds_listened,
                       ROW_NUMBER() OVER (
                           PARTITION BY u.user_id
                           ORDER BY ph.seconds_listened DESC, s.song_id ASC
                       ) AS rn
                FROM users u
                JOIN play_history ph ON ph.user_id = u.user_id
                JOIN songs s         ON s.song_id  = ph.song_id
            ) t
            WHERE rn = 1
            ORDER BY username ASC
        """,
    },
    "13": {
        "file": "13-running-plays-per-artist.sql",
        "title": "Running total of plays per artist",
        "ordered": True,
        "sql": """
            WITH album_plays AS (
                SELECT al.album_id,
                       al.artist_id,
                       al.title       AS album_title,
                       al.release_year,
                       COALESCE(SUM(s.play_count), 0)::bigint AS album_plays
                FROM albums al
                LEFT JOIN songs s ON s.album_id = al.album_id
                GROUP BY al.album_id, al.artist_id, al.title, al.release_year
            )
            SELECT ar.name,
                   ap.album_title,
                   ap.album_plays,
                   SUM(ap.album_plays) OVER (
                       PARTITION BY ar.artist_id
                       ORDER BY ap.release_year ASC, ap.album_id ASC
                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                   )::bigint AS running_total
            FROM album_plays ap
            JOIN artists ar ON ar.artist_id = ap.artist_id
            ORDER BY ar.name ASC, ap.release_year ASC, ap.album_title ASC
        """,
    },
    "14": {
        "file": "14-user-pairs.sql",
        "title": "User pairs sharing songs",
        "ordered": True,
        "sql": """
            SELECT u1.username, u2.username,
                   COUNT(DISTINCT a.song_id)::int AS shared
            FROM play_history a
            JOIN play_history b ON a.song_id = b.song_id AND a.user_id < b.user_id
            JOIN users u1 ON u1.user_id = a.user_id
            JOIN users u2 ON u2.user_id = b.user_id
            GROUP BY u1.username, u2.username
            ORDER BY shared DESC, u1.username ASC, u2.username ASC
            LIMIT 10
        """,
    },
    "15": {
        "file": "15-above-average-albums.sql",
        "title": "Albums above the global average",
        "ordered": True,
        "sql": """
            SELECT al.title, ROUND(AVG(s.duration_seconds))::int AS avg_dur
            FROM albums al
            JOIN songs s ON s.album_id = al.album_id
            GROUP BY al.album_id, al.title
            HAVING AVG(s.duration_seconds) > (SELECT AVG(duration_seconds) FROM songs)
            ORDER BY avg_dur DESC, al.title ASC
        """,
    },
}


# ---------------------------------------------------------------------------
# psql plumbing
# ---------------------------------------------------------------------------

PSQL_BASE = [
    "docker", "compose", "exec", "-T", "db",
    "psql", "-U", "music", "-d", "music",
    "-A", "-F", "\t", "-t",          # unaligned, tab-separated, tuples-only
    "--no-psqlrc",
    "-v", "ON_ERROR_STOP=1",
]


def run_sql(sql: str):
    """Execute SQL via the db container's psql. Returns (rows, error_or_None)."""
    sql = sql.strip().rstrip(";")
    # Wrap in a CTE so we control ordering exactly as written.
    cmd = PSQL_BASE + ["-c", sql]
    try:
        r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=30)
    except FileNotFoundError:
        return None, "docker not found on PATH — install Docker or run `docker compose up -d`."
    except subprocess.TimeoutExpired:
        return None, "query timed out (30s)."
    if r.returncode != 0:
        msg = (r.stderr or r.stdout).strip().splitlines()
        # keep just the first non-empty error line
        first = next((ln for ln in msg if ln.strip()), "psql failed")
        return None, first
    rows = [tuple(line.split("\t")) for line in r.stdout.splitlines() if line]
    return rows, None


def extract_student_sql(path: Path) -> str:
    """Strip SQL comments and return the user's query body."""
    body = []
    for line in path.read_text(encoding="utf-8").splitlines():
        # drop everything after a `--` not inside quotes (good enough for this project)
        idx = line.find("--")
        if idx >= 0:
            line = line[:idx]
        body.append(line)
    return "\n".join(body).strip()


# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

def compare(expected, actual, ordered: bool):
    """Return a list of human-readable diff lines (empty if equal)."""
    if not ordered:
        e = sorted(expected); a = sorted(actual)
    else:
        e = list(expected); a = list(actual)

    if e == a:
        return []

    diffs = []
    if len(e) != len(a):
        diffs.append(f"row count: expected {len(e)}, got {len(a)}")

    # Show the first row that differs.
    for i, (er, ar) in enumerate(zip(e, a)):
        if er != ar:
            diffs.append(f"first differing row (index {i}):")
            diffs.append(f"  expected: {er}")
            diffs.append(f"  got:      {ar}")
            break
    else:
        # one is a prefix of the other
        if len(a) > len(e):
            diffs.append(f"unexpected extra row: {a[len(e)]}")
        elif len(e) > len(a):
            diffs.append(f"missing row: {e[len(a)]}")

    # set-level hints (only if ordered, since order being wrong is a common bug)
    if ordered:
        eset = set(e); aset = set(a)
        missing = [r for r in e if r not in aset][:3]
        extra   = [r for r in a if r not in eset][:3]
        if missing or extra:
            if missing:
                diffs.append(f"rows you don't return at all (showing up to 3): {missing}")
            if extra:
                diffs.append(f"rows you return but shouldn't (showing up to 3): {extra}")
        elif eset == aset:
            diffs.append("(your rows are correct as a set — only the ORDER BY is off)")
    return diffs


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def check_one(num: str):
    spec = EXERCISES[num]
    path = HERE / spec["file"]
    label = f"{num}. {spec['title']}"

    if not path.exists():
        print(f"{RED(':(')} {label} — file missing: {path.name}")
        return False

    student_sql = extract_student_sql(path)
    if not student_sql:
        print(f"{YELLOW(':|')} {label} — {DIM('not attempted yet')}")
        return False

    expected, err_e = run_sql(spec["sql"])
    if err_e:
        print(f"{RED('!!')} {label} — internal error in reference query: {err_e}")
        return False

    actual, err_a = run_sql(student_sql)
    if err_a:
        print(f"{RED(':(')} {label}")
        print(f"   {RED('SQL error:')} {err_a}")
        return False

    diffs = compare(expected, actual, spec["ordered"])
    if not diffs:
        print(f"{GREEN(':)')} {label}")
        return True

    print(f"{RED(':(')} {label}")
    for line in diffs:
        print(f"   {DIM(line)}")
    return False


def main(argv):
    selected = argv[1:] if len(argv) > 1 else list(EXERCISES.keys())
    selected = [s.zfill(2) for s in selected]
    unknown = [s for s in selected if s not in EXERCISES]
    if unknown:
        print(f"unknown exercise(s): {unknown}")
        print(f"valid: {sorted(EXERCISES.keys())}")
        return 2

    print(BOLD("== Music Streaming DB · Query Exercises =="))
    print()
    passed = 0
    for num in selected:
        if check_one(num):
            passed += 1
    print()
    total = len(selected)
    color = GREEN if passed == total else (YELLOW if passed > 0 else RED)
    print(BOLD(f"Score: {color(f'{passed}/{total}')}"))
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

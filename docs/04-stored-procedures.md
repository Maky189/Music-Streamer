# Stored Procedures and Functions

PostgreSQL has both:

- **Functions** (`CREATE FUNCTION`) — return a value, callable inside `SELECT`. Run inside the caller's transaction.
- **Procedures** (`CREATE PROCEDURE`, PG ≥ 11) — invoked with `CALL`. Can manage their own transactions (`COMMIT`, `ROLLBACK`).

## Function syntax

```sql
CREATE OR REPLACE FUNCTION add_two(a INT, b INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN a + b;
END;
$$;

SELECT add_two(2, 3);    -- 5
```

## Procedure syntax

```sql
CREATE OR REPLACE PROCEDURE archive_user(p_user_id INT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE users SET subscription = 'free' WHERE user_id = p_user_id;
    DELETE FROM user_sessions WHERE user_id = p_user_id;
    COMMIT;                       -- procedures may commit
END;
$$;

CALL archive_user(7);
```

## Parameter modes

| Mode | Direction | Notes |
|------|-----------|-------|
| `IN`    | caller → routine | default |
| `OUT`   | routine → caller | function return value-style; for procs, set inside body |
| `INOUT` | both             | useful for read-modify-write |

```sql
CREATE PROCEDURE next_position(p_playlist_id INT, INOUT p_pos INT)
LANGUAGE plpgsql AS $$
BEGIN
    SELECT COALESCE(MAX(position), 0) + 1
      INTO p_pos
      FROM playlist_songs
     WHERE playlist_id = p_playlist_id;
END; $$;
```

## Returning result sets (functions only)

```sql
CREATE FUNCTION songs_in_playlist(p_id INT)
RETURNS TABLE(song_id INT, title VARCHAR, position INT)
LANGUAGE sql AS $$
    SELECT s.song_id, s.title, ps.position
    FROM playlist_songs ps
    JOIN songs s USING (song_id)
    WHERE ps.playlist_id = p_id
    ORDER BY ps.position;
$$;

SELECT * FROM songs_in_playlist(1);
```

## Error handling

```sql
BEGIN
    INSERT INTO playlist_songs(...) VALUES (...);
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Already in playlist';
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Invalid song or playlist';
END;
```

`RAISE EXCEPTION` aborts the transaction. `RAISE NOTICE` only logs.

## Calling other routines

A procedure can `CALL` another procedure or `PERFORM other_function()` (PERFORM = call a function whose result you ignore).

## MySQL differences

- MySQL has only **procedures** (`CREATE PROCEDURE`) and **functions**, both via `DELIMITER` blocks.
- MySQL stored procs cannot return a table directly — they return result sets via `SELECT` statements.
- Error handling uses `DECLARE ... HANDLER FOR SQLEXCEPTION ...`.

## Best practices

- Keep procedures short and focused. Big monoliths are hard to test.
- Validate inputs early; fail loudly with `RAISE EXCEPTION`.
- Don't put business decisions only in the DB if your team also has app-layer logic — duplicate logic is the worst kind.
- Version control your procedures in `.sql` files (you already are).

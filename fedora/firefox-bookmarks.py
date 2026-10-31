"""firefox-bookmarks.py <default-bookmarks.html> <places.sqlite>...: removes the bookmarks each firefox
profile started with (fedora's, from the html firefox ships) and their tags and folders; bookmarks you
added stay. a database that changes is backed up first, as places.sqlite.bak. exits 3 when firefox has
a profile open, as it locks the database while it runs"""

import html
import re
import sqlite3
import sys
import time
from pathlib import Path

ROOTS = ("root________", "menu________", "toolbar_____", "tags________", "unfiled_____", "mobile______")


def defaults(path):
    """the (url, title) pairs, folder names and tags in firefox's default bookmarks"""
    text = Path(path).read_text(encoding="utf-8")
    links = {
        (html.unescape(url), html.unescape(title))
        for url, title in re.findall(r'<A HREF="([^"]*)"[^>]*>([^<]*)</A>', text)
    }
    folders = {html.unescape(t) for t in re.findall(r"<H3[^>]*>([^<]*)</H3>", text)}
    tags = {t for group in re.findall(r'TAGS="([^"]*)"', text) for t in html.unescape(group).split(",")}
    return links, folders, tags


def clean(db, links, folders, tags):
    """removes the defaults from one places.sqlite; returns how many items went"""
    con = sqlite3.connect(db, timeout=0, isolation_level=None)
    try:
        roots = dict(con.execute(
            f"SELECT guid, id FROM moz_bookmarks WHERE guid IN ({','.join('?' * len(ROOTS))})", ROOTS))
        tag_root = roots["tags________"]
        tag_folders = {i for i, title in con.execute(
            "SELECT id, title FROM moz_bookmarks WHERE parent = ? AND type = 2", (tag_root,)) if title in tags}

        urls = {url for url, _ in links}
        # the default bookmarks, and their entries in the default tags
        items = {i for i, parent, url, title in con.execute(
            "SELECT b.id, b.parent, p.url, b.title FROM moz_bookmarks b JOIN moz_places p ON p.id = b.fk "
            "WHERE b.type = 1")
            if (url in urls if parent in tag_folders else (url, title) in links)}
        if not items:
            return 0
        backup = Path(str(db) + ".bak")
        if not backup.exists():
            con.execute("VACUUM INTO ?", (str(backup),))
        con.execute("BEGIN EXCLUSIVE")
        now = int(time.time() * 1_000_000)
        removed = 0
        while items:
            rows = con.execute(
                f"SELECT id, parent, fk, guid, syncStatus FROM moz_bookmarks WHERE id IN ({','.join('?' * len(items))})",
                list(items)).fetchall()
            for i, parent, fk, guid, sync in rows:
                con.execute("DELETE FROM moz_bookmarks WHERE id = ?", (i,))
                con.execute("DELETE FROM moz_items_annos WHERE item_id = ?", (i,))
                # an item firefox sync already has needs a tombstone, or sync brings it back
                if sync == 2:
                    con.execute("INSERT OR IGNORE INTO moz_bookmarks_deleted (guid, dateRemoved) VALUES (?, ?)",
                                (guid, now))
                if fk is not None:
                    con.execute(
                        "UPDATE moz_places SET foreign_count = "
                        "(SELECT count(*) FROM moz_bookmarks WHERE fk = ?1) + "
                        "(SELECT count(*) FROM moz_keywords WHERE place_id = ?1) WHERE id = ?1", (fk,))
                con.execute("UPDATE moz_bookmarks SET lastModified = ?, syncChangeCounter = syncChangeCounter + 1 "
                            "WHERE id = ?", (now, parent))
            removed += len(rows)
            # folders and tags of the defaults that are empty now
            items = {i for i, parent, title in con.execute(
                "SELECT id, parent, title FROM moz_bookmarks f WHERE type = 2 AND guid NOT IN "
                f"({','.join('?' * len(ROOTS))}) AND NOT EXISTS (SELECT 1 FROM moz_bookmarks c WHERE c.parent = f.id)",
                ROOTS) if (parent == tag_root and title in tags) or (parent != tag_root and title in folders)}
        # what's left in each folder, numbered from 0 again
        for (parent,) in con.execute("SELECT DISTINCT parent FROM moz_bookmarks").fetchall():
            for pos, (i,) in enumerate(con.execute(
                    "SELECT id FROM moz_bookmarks WHERE parent = ? ORDER BY position", (parent,)).fetchall()):
                con.execute("UPDATE moz_bookmarks SET position = ? WHERE id = ? AND position != ?", (pos, i, pos))
        con.execute("COMMIT")
        return removed
    finally:
        con.close()


def main():
    links, folders, tags = defaults(sys.argv[1])
    if not links:
        sys.exit("no default bookmarks found in " + sys.argv[1])
    busy = False
    for db in sys.argv[2:]:
        try:
            removed = clean(db, links, folders, tags)
        except sqlite3.OperationalError as e:
            if "locked" not in str(e):
                raise
            busy = True
            continue
        if removed:
            print(f"removed {removed} of fedora's bookmarks, tags and folders from {Path(db).parent.name}")
    sys.exit(3 if busy else 0)


if __name__ == "__main__":
    main()

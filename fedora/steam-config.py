"""steam-config.py [--check] <file.vdf> <section/.../key=value>...: sets keys in one of steam's text vdf
files, adding the sections they need, and leaves the rest of the file as steam wrote it; prints each key
it changes. with --check it changes nothing and exits 10 when a key would change"""

import os
import re
import sys
import tempfile
from pathlib import Path

TOKEN = re.compile(r'\s+|//[^\n]*|"((?:\\.|[^"\\])*)"|([{}])|([^\s{}"]+)')


def parse(text):
    """the file as nested sections: {"depth", "close", "keys": {name: ("value", start, end, text) or
    ("section", section)}}, with names lowercased, as steam reads them; start and end bound a value"""
    root = {"depth": 0, "close": len(text), "keys": {}}
    stack, name, pos = [root], None, 0
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            raise ValueError(f"can't read the file at character {pos}")
        pos = m.end()
        if m.group(2) == "{":
            if name is None:
                raise ValueError(f"a section with no name at character {m.start()}")
            section = {"depth": len(stack), "keys": {}}
            stack[-1]["keys"].setdefault(name.casefold(), ("section", section))
            stack.append(section)
            name = None
        elif m.group(2) == "}":
            if len(stack) == 1:
                raise ValueError(f"a }} too many at character {m.start()}")
            stack.pop()["close"] = m.start()
        elif m.group(1) is not None or m.group(3) is not None:
            group = 1 if m.group(1) is not None else 3
            if name is None:
                name = m.group(group)
            else:
                stack[-1]["keys"].setdefault(name.casefold(), ("value", m.start(group), m.end(group), m.group(group)))
                name = None
    if len(stack) != 1 or name is not None:
        raise ValueError("the file ends inside a section")
    return root


def block(names, value, depth):
    """the lines for a key, inside any sections it needs, indented with tabs as steam does"""
    tabs = "\t" * depth
    if len(names) == 1:
        return f'{tabs}"{names[0]}"\t\t"{value}"\n'
    return f'{tabs}"{names[0]}"\n{tabs}{{\n{block(names[1:], value, depth + 1)}{tabs}}}\n'


def set_key(text, path, value):
    """text with path set to value, and whether it changed"""
    section = parse(text)
    for i, name in enumerate(path):
        entry = section["keys"].get(name.casefold())
        if entry is None:
            # the missing part goes on its own lines, before the section's closing brace
            at = text.rfind("\n", 0, section["close"]) + 1
            return text[:at] + block(path[i:], value, section["depth"]) + text[at:], True
        last = i == len(path) - 1
        if last and entry[0] == "value":
            if entry[3] == value:
                return text, False
            return text[:entry[1]] + value + text[entry[2]:], True
        if last or entry[0] != "section":
            raise ValueError(f"{'/'.join(path[:i + 1])} is a {entry[0]} in the file, not what's expected")
        section = entry[1]
    raise ValueError("no key to set")


def main():
    args = sys.argv[1:]
    check = args[:1] == ["--check"]
    if check:
        args = args[1:]
    file, settings = Path(args[0]), args[1:]
    text = original = file.read_text(encoding="utf-8")
    for setting in settings:
        path, _, value = setting.partition("=")
        if re.search(r'["\\]', value):
            sys.exit(f"{setting}: a value with a quote or backslash isn't supported")
        text, changed = set_key(text, path.split("/"), value)
        if changed and check:
            sys.exit(10)
        if changed:
            print(f"setting {path.rsplit('/', 1)[-1]} to {value!r} in {file.name}")
    if text == original:
        return
    parse(text)
    # a new file beside the old one, then swapped in, so a failed write leaves steam's file whole
    fd, tmp = tempfile.mkstemp(dir=file.parent, prefix=file.name + ".")
    with os.fdopen(fd, "w", encoding="utf-8") as out:
        out.write(text)
    os.chmod(tmp, file.stat().st_mode & 0o7777)
    os.replace(tmp, file)


if __name__ == "__main__":
    main()

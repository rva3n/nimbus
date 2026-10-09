#!/usr/bin/env python3
"""Прописать параметры запуска игры в Steam (localconfig.vdf).

Использование:
    python3 tools/set-steam-launch.py <appid> "<параметры>"
    python3 tools/set-steam-launch.py 1091500 "gamescope -f -- %command%"

Steam должен быть закрыт: клиент держит localconfig.vdf в памяти и перезапишет
правку. Скрипт делает резервную копию рядом с файлом и трогает только блок
нужного приложения.
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import time


def steam_running() -> bool:
    try:
        return subprocess.run(["pgrep", "-x", "steam"], capture_output=True).returncode == 0
    except FileNotFoundError:
        return False


def find_localconfig() -> str:
    paths = glob.glob(os.path.expanduser("~/.local/share/Steam/userdata/*/config/localconfig.vdf"))
    if not paths:
        sys.exit("localconfig.vdf не найден")
    paths.sort(key=os.path.getmtime, reverse=True)
    return paths[0]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("appid")
    ap.add_argument("options")
    ap.add_argument("--file", default=None, help="путь к localconfig.vdf (по умолчанию — самый свежий)")
    ap.add_argument("--force", action="store_true", help="не проверять, закрыт ли Steam")
    args = ap.parse_args()

    path = args.file or find_localconfig()
    if not os.path.isfile(path):
        sys.exit(f"нет файла: {path}")
    if steam_running() and not args.force:
        sys.exit("Steam запущен — закрой его и повтори (иначе Steam затрёт правку).")

    with open(path, "r", encoding="utf-8", errors="surrogateescape") as fh:
        text = fh.read()

    # блок приложения: 5 табов «appid» + 5 табов «{»
    m = re.search(r'(\n\t{5}"%s"\n\t{5}\{\n)' % re.escape(args.appid), text)
    if not m:
        sys.exit(f"не найден блок приложения {args.appid} в {path}")
    start = m.end()

    rest = text[start:]
    end = re.search(r"\n\t{5}\}", rest)
    block = rest[:end.start()] if end else rest

    value = args.options.replace('"', '\\"')
    opt_re = re.compile(r'((?:^|\n)\t{6}"LaunchOptions"[ \t]*)"[^"]*"', re.M)
    if opt_re.search(block):
        block_new = opt_re.sub(lambda mo: mo.group(1) + '"' + value + '"', block, count=1)
        action = "обновлены"
    else:
        block_new = '\t\t\t\t\t\t"LaunchOptions"\t\t"' + value + '"\n' + block
        action = "добавлены"

    new_text = text[:start] + block_new + text[start + len(block):]

    backup = path + ".bak-" + time.strftime("%Y%m%d-%H%M%S")
    shutil.copy2(path, backup)
    with open(path, "w", encoding="utf-8", errors="surrogateescape") as fh:
        fh.write(new_text)

    print(f"ok: параметры запуска {action} для {args.appid}: {args.options}")
    print(f"бэкап: {backup}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

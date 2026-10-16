#!/usr/bin/env python3
"""opencode-ctl — управление OpenCode для Oberon (волна B4).

Локально, без сети: БД ~/.local/share/opencode/opencode.db (usage),
конфиг ~/.config/opencode/opencode.json (модель по умолчанию),
~/.config/opencode/agents/*.md (модели субагентов), живой сервер через
`opencode api`. Перед любой правкой файла создаётся бэкап
<файл>.bak-usectl-<штамп>.

Подкоманды:
  usage                                 — расход по окнам 5ч/7д/30д (SQL + fallback на python-sqlite)
  main-model <provider/model|default> [--live] [--session ID]
                                        — модель оркестратора: пишется в
                                          opencode.json («default» = удалить
                                          ключ «model»; сервер возьмёт дефолт
                                          провайдера); --live — POST
                                          /api/session/<id>/model (одна
                                          топ-уровневая активная сессия или
                                          --session)
  agent-model <agent> <provider/model>  — модель субагента: frontmatter
                                          agents/<agent>.md, иначе inline
                                          agents.<agent> в opencode.json
  reload                                — `opencode reload`
  list-models [--json]                  — Go-таблица лимитов + текущие модели
                                          агентов из файлов
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
OC_DIR = os.path.join(HOME, ".config", "opencode")
CONFIG_PATH = os.path.join(OC_DIR, "opencode.json")
AGENTS_DIR = os.path.join(OC_DIR, "agents")
DB_PATH = os.path.join(HOME, ".local", "share", "opencode", "opencode.db")
OC_BIN = os.path.join(HOME, ".opencode", "bin", "opencode")
PROVIDER = "opencode-go"

# ── Go-таблица (источник: сводка плана; зеркало core/GoLimits.js) ──────────
LIMITS_SCHEMA = "go-limits v1 · 5ч=20% мес | 7д=50% | 30д=100% | Plus=×2"
GO_LIMITS = {
    "deepseek-v4.1-flash": 80,
    "glm-5.3-flash": 60,
    "glm-5.2": 60,
    "glm-5.3": 15,
    "kimi-k2.7-code": 60,
    "kimi-k2.6": 60,
    "kimi-k3": 15,
    "minimax-m3": 60,
    "minimax-m2.7": 60,
    "muse-spark-1.3": 60,
    "qwen3.8-flash": 30,
    "qwen3.8-max": 15,
    "grok-4.7": 15,
    "gpt-6-luna": 15,
    "claude-haiku-5-5": 15,
    "deepseek-v4-pro": 15,
    "deepseek-v4-flash": 30,
    "deepseek-v4-flash-vision-exp": 15,
    "hy3": 60,
    "hy4-preview": 30,
    "space-bunny": 30,
}
FREE_EXACT = {"space-bunny-free"}
FREE_PREFIX = ("mimo-", "nemotron-", "jev-", "ling-")
WINDOWS = (("5h", 5 * 3600 * 1000, 0.20), ("7d", 7 * 86400 * 1000, 0.50),
           ("30d", 30 * 86400 * 1000, 1.00))

AGENT_FILES = ("general", "explore", "scout", "tester", "reviewer")


def die(msg, code=1):
    print(f"opencode-ctl: {msg}", file=sys.stderr)
    sys.exit(code)


def backup(path):
    """Бэкап перед правкой: <файл>.bak-usectl-<штамп> рядом."""
    if not os.path.exists(path):
        return None
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dst = f"{path}.bak-usectl-{stamp}"
    with open(path, "rb") as f:
        with open(dst, "wb") as g:
            g.write(f.read())
    return dst


def oc_api_raw(op, *args, timeout=20):
    """~/.opencode/bin/opencode api ... → (rc, stdout, stderr).

    op — либо один токен (operation id), либо «METHOD /путь» (разбивается
    на слова: CLI принимает их раздельно)."""
    argv = [OC_BIN, "api"] + (op.split() if " " in op else [op]) + list(args)
    try:
        out = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except FileNotFoundError:
        return 127, "", "opencode не найден"
    return out.returncode, out.stdout, out.stderr


def oc_api(op, *args, timeout=20):
    """oc_api_raw + разбор JSON (успешные POST'ы отвечают пустотой → None)."""
    rc, stdout, _ = oc_api_raw(op, *args, timeout=timeout)
    if rc != 0:
        return None
    try:
        return json.loads(stdout)
    except (json.JSONDecodeError, TypeError):
        return {}


def oc_reload():
    """Перечитать конфиги сервером opencode."""
    try:
        out = subprocess.run([OC_BIN, "reload"], capture_output=True, text=True,
                             timeout=30)
        if out.stdout.strip():
            print(out.stdout.strip())
        if out.returncode != 0 and out.stderr.strip():
            print(out.stderr.strip(), file=sys.stderr)
        return out.returncode
    except FileNotFoundError:
        die("opencode не найден: " + OC_BIN)
    except subprocess.TimeoutExpired:
        die("opencode reload не ответил за 30с")


def write_json(path, data):
    """JSON-файл обратно: 2 пробела + перенос строки в конце (как было)."""
    with open(path, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def parse_model_ref(ref):
    """provider/id[#variant] → (provider, id, variant|None)"""
    variant = None
    if "#" in ref:
        ref, variant = ref.split("#", 1)
    if "/" not in ref:
        die(f"ожидался формат provider/model, получено: {ref!r}")
    provider, model = ref.split("/", 1)
    if not provider or not model:
        die(f"лишние слэши в ref: {ref!r}")
    return provider, model, variant


def frontmatter_set_model(text, ref):
    """Заменить строку `model:` в YAML-frontmatter. Возвращает (текст, ok)."""
    m = re.match(r"^---\s*\n(.*?)\n(---)(\s*\n)?", text, re.S)
    if not m:
        return None, False
    block, closing = m.group(1), m.group(2)
    if re.search(r"^model:\s", block, re.M):
        new_block = re.sub(r"^model:\s*\S+.*$", f"model: {ref}", block,
                           count=1, flags=re.M)
    else:
        new_block = block + f"\nmodel: {ref}\n"
    return text[:m.start()] + "---\n" + new_block + "\n" + closing + \
        (m.group(3) or "\n")[0] + text[m.end():], True


def frontmatter_get_model(path):
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read(8192)
    except OSError:
        return None
    m = re.search(r"^model:\s*(\S+)\s*$", text, re.M)
    return m.group(1) if m else None


# ── usage ──────────────────────────────────────────────────────────────────

def sql_usage(t5, t7, t30):
    """Один GROUP BY: {model: [spent5h, spent7d, spent30d], req, last}.
    printf — родная функция SQLite (безопасно и для python-sqlite3)."""
    return f"""SELECT json_extract(data,'$.model.id'),
 printf('%.6f', SUM(CASE WHEN time_created > {t5} THEN COALESCE(json_extract(data,'$.cost'),0) ELSE 0 END)),
 printf('%.6f', SUM(CASE WHEN time_created > {t7} THEN COALESCE(json_extract(data,'$.cost'),0) ELSE 0 END)),
 printf('%.6f', SUM(CASE WHEN time_created > {t30} THEN COALESCE(json_extract(data,'$.cost'),0) ELSE 0 END)),
 COUNT(CASE WHEN time_created > {t5} THEN 1 END),
 COUNT(CASE WHEN time_created > {t7} THEN 1 END),
 COUNT(CASE WHEN time_created > {t30} THEN 1 END),
 printf('%d', MAX(time_created))
 FROM session_message
 WHERE type='assistant'
 AND json_extract(data,'$.model.providerID')='{PROVIDER}'
 AND time_created > {t30}
 GROUP BY 1"""


def usage_rows():
    """[{id, s5, s7, s30, r5, r7, r30, last}] — сначала sqlite3-бинарь,
    потом fallback на python-sqlite3 (read-only URI, WAL-safe)."""
    now = int(time.time() * 1000)
    sql = sql_usage(now - WINDOWS[0][1], now - WINDOWS[1][1], now - WINDOWS[2][1])
    rows = []
    try:
        out = subprocess.run(
            ["sqlite3", "-readonly", "-batch", "-noheader", "-separator", "\t",
             DB_PATH, sql],
            capture_output=True, text=True, timeout=30)
        if out.returncode != 0:
            raise RuntimeError(out.stderr.strip() or "sqlite3 вернул " + str(out.returncode))
        for line in out.stdout.splitlines():
            f = line.split("\t")
            if len(f) < 8:
                continue
            rows.append((f[0], float(f[1] or 0), float(f[2] or 0), float(f[3] or 0),
                         int(f[4] or 0), int(f[5] or 0), int(f[6] or 0), int(f[7] or 0)))
    except FileNotFoundError:
        import sqlite3
        con = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True, timeout=5)
        try:
            for r in con.execute(sql):
                rows.append((r[0], float(r[1] or 0), float(r[2] or 0), float(r[3] or 0),
                             int(r[4] or 0), int(r[5] or 0), int(r[6] or 0), int(r[7] or 0)))
        finally:
            con.close()
    return rows


def frontmatter_set_model(text, ref):
    """Заменить/вставить строку `model:` в YAML-frontmatter. (текст, ok|False)."""
    m = re.match(r"^---\s*\n(.*?)\n---(\n|$)", text, re.S)
    if not m:
        return None, False
    block = m.group(1)
    if re.search(r"^model:\s*\S", block, re.M):
        new_block = re.sub(r"^model:\s*\S+.*$", "model: " + ref, block,
                           count=1, flags=re.M)
    else:
        new_block = block + "\nmodel: " + ref
    return (text[:m.start()] + "---\n" + new_block + "\n---"
            + (m.group(2) or "\n") + text[m.end():], True)


def cmd_usage(_args):
    plan = os.environ.get("OBERON_GO_PLAN", "go")
    mult = 2 if plan == "plus" else 1
    try:
        rows = usage_rows()
    except FileNotFoundError as exc:
        die(f"нет DB/sqlite3: {exc}")
    except (RuntimeError, subprocess.TimeoutExpired) as exc:
        die(f"sqlite3 не сработал: {exc}")

    if not rows:
        print("usage: данных нет (opencode-go не тратился за 30 дней)")
        return

    print(f"OpenCode Go usage ({LIMITS_SCHEMA}; план: {'Go Plus (×2)' if mult == 2 else 'Go'})")
    header = (f"{'model':32} | {'5ч $':>10} {'7д $':>10} {'30д $':>10} | "
              f"{'5ч%':>4} {'7д%':>4} {'30д%':>4} | {'req30':>6} | last")
    print(header)
    print("-" * len(header))
    for mid, s5, s7, s30, r5, r7, r30, last in sorted(rows, key=lambda r: -r[3]):
        limit = GO_LIMITS.get(mid, 0) * mult
        free = mid.endswith("-free") or mid in FREE_EXACT or mid.startswith(FREE_PREFIX)
        if free or not limit:
            pct = ("  —", "  —", "  — ")
        else:
            pct = (f"{s5 / (limit * WINDOWS[0][2]) * 100:4.0f}",
                   f"{s7 / (limit * WINDOWS[1][2]) * 100:4.0f}",
                   f"{s30 / limit * 100:4.0f}")
        print(f"{mid:32} | ${s5:<9.2f} ${s7:<9.2f} ${s30:<9.2f} | "
              f"{pct[0]} {pct[1]} {pct[2]} | {r30:>6} | "
              f"{time.strftime('%m-%d %H:%M', time.localtime(last / 1000))}")
    print(f"\nитого 30д: ${sum(r[3] for r in rows):.2f}, запросов 30д: {sum(r[6] for r in rows)}")


# ── main-model ─────────────────────────────────────────────────────────────

def default_model_from_server():
    """Серверный дефолт (GET /api/model/default) → "provider/id"."""
    resp = oc_api("GET /api/model/default")
    if not resp:
        return None
    data = resp.get("data", resp)
    loc = (resp.get("location") or {}).get("directory") if isinstance(resp, dict) else None
    mid = data.get("modelID") or data.get("id")
    prov = data.get("providerID")
    if mid and prov:
        return f"{prov}/{mid}"
    return None


def config_set_model(ref_or_none):
    """Правка «model» в opencode.json (+бэкап). None — удалить ключ."""
    if not os.path.exists(CONFIG_PATH):
        die("нет " + CONFIG_PATH)
    with open(CONFIG_PATH, encoding="utf-8") as f:
        cfg = json.load(f)
    bak = backup(CONFIG_PATH)
    if ref_or_none is None:
        had = "model" in cfg
        if had:
            del cfg["model"]
            write_json(CONFIG_PATH, cfg)
            print(f"opencode.json: ключ «model» удалён (бэкап {os.path.basename(bak)})")
        else:
            print("opencode.json: ключа «model» нет — нечего убирать")
        return had
    old = cfg.get("model")
    cfg["model"] = ref_or_none
    write_json(CONFIG_PATH, cfg)
    print(f"opencode.json: model {old!r} → {ref_or_none!r} (бэкап {os.path.basename(bak)})")


def pick_active_session(explicit=None):
    """Активная топ-уровневая сессия (не субагент): [--session] > одну корневую.

    Субагентные (parentID) трогать нельзя — там может думать оркестратор.
    """
    if explicit:
        return explicit
    act = oc_api("GET /api/session/active")
    if not act:
        die("сервер opencode не отвечает (active)")
    ids = list((act.get("data") or {}).keys())
    if not ids:
        die("нет активных сессий")
    sess = oc_api("GET /api/session") or {}
    items = sess.get("data") if isinstance(sess, dict) else sess
    if not isinstance(items, list):
        die("не понял список сессий")
    roots = []
    for s in items:
        if s.get("id") in ids and not s.get("parentID"):
            roots.append(s.get("id"))
    if len(roots) == 1:
        return roots[0]
    ids.sort()
    die("активных корневых сессий " + str(len(roots)) +
        f" — уточни --session (кандидаты: {', '.join(roots or ids)})")


def cmd_main_model(args):
    if args.ref == "default":
        # «По умолчанию» = снять оверрайд: opencode.json без ключа «model» —
        # сервер берёт дефолт провайдера самостоятельно. (/api/model/default
        # зеркалит текущую конфигурацию, поэтому источником «серверного
        # дефолта» он быть не может.)
        config_set_model(None)
        oc_reload()
        return

    provider, model, variant = parse_model_ref(args.ref)
    if provider != PROVIDER:
        print(f"внимание: провайдер {provider!r} вне Go-плана", file=sys.stderr)
    ref = args.ref

    if args.live:
        sid = pick_active_session(args.session)
        body = {"model": {"providerID": provider, "id": model}}
        if variant:
            body["model"]["variant"] = variant
        rc, sout, serr = oc_api_raw("POST", f"/api/session/{sid}/model", "-d",
                                    json.dumps(body), timeout=30)
        if rc != 0:
            die(f"переключение сессии {sid} не удалось: " + (serr or sout).strip())
        check = oc_api("GET", f"/api/session/{sid}")
        cur = (check.get("data") or {}).get("model") if check else None
        print(f"сессия {sid}: model → {(cur or {}).get('providerID','')}/"
              f"{(cur or {}).get('id','')}"
              + (f"#{(cur or {}).get('variant','')}" if (cur or {}).get("variant") else ""))
        return

    config_set_model(ref)
    oc_reload()


# ── agent-model ────────────────────────────────────────────────────────────

def cmd_agent_model(args):
    agent, ref = args.agent, args.ref
    provider, model, variant = parse_model_ref(ref)  # валичный формат
    _ = provider, model, variant
    path = os.path.join(AGENTS_DIR, f"{agent}.md")

    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            text = f.read()
        new_text, ok = frontmatter_set_model(text, ref)
        if not ok:
            die(f"{path}: нет YAML-frontmatter (--- … ---)")
        bak = backup(path)
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_text)
        print(f"{agent}.md: model → {ref!r} (бэкап {os.path.basename(bak)})")
        oc_reload()
        return

    # нет md-файла — inline-агент в opencode.json (general/explore)
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, encoding="utf-8") as f:
            cfg = json.load(f)
        agents = cfg.get("agents")
        if isinstance(agents, dict) and agent in agents:
            if not isinstance(agents[agent], dict):
                die(f"opencode.json: agents.{agent} не словарь")
            bak = backup(CONFIG_PATH)
            old = agents[agent].get("model")
            agents[agent]["model"] = ref
            cfg["agents"] = agents
            write_json(CONFIG_PATH, cfg)
            print(f"opencode.json agents.{agent}: model {old!r} → {ref!r} "
                  f"(бэкап {os.path.basename(bak)})")
            oc_reload()
            return

    known = [a for a in AGENT_FILES if os.path.exists(os.path.join(AGENTS_DIR, a + ".md"))]
    die(f"агент {agent!r} не найден: нет {path} и нет agents.{agent} в opencode.json "
        f"(md-агенты: {', '.join(known) or '—'})")


# ── list-models ────────────────────────────────────────────────────────────

def cmd_list_models(args):
    if args.json:
        print(json.dumps(_list_models_json(), ensure_ascii=False, indent=2))
        return
    print("== Go-таблица ==")
    print(LIMITS_SCHEMA)
    print(f"{'model':32} {'$/мес':>7} {'5ч':>6} {'7д':>6}")
    for mid, lim in sorted(GO_LIMITS.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"{mid:32} {lim:>7} {lim*0.2:>6.0f} {lim*0.5:>6.0f}")
    print("free (unlimited): space-bunny-free, модели на -free, " +
          ", ".join(p + "*" for p in FREE_PREFIX))

    print("\n== модели агентов (файлы) ==")
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, encoding="utf-8") as f:
            try:
                cfg = json.load(f)
            except json.JSONDecodeError:
                cfg = {}
        if cfg.get("model"):
            print(f"opencode.json: model = {cfg['model']}")
        for k, v in (cfg.get("agents") or {}).items():
            if isinstance(v, dict) and v.get("model"):
                print(f"opencode.json agents.{k} = {v['model']}")
    if os.path.isdir(AGENTS_DIR):
        for fn in sorted(os.listdir(AGENTS_DIR)):
            if fn.endswith(".md"):
                ref = frontmatter_get_model(os.path.join(AGENTS_DIR, fn))
                if ref:
                    print(f"agents/{fn}: model = {ref}")


def _list_models_json():
    out = {"schema": LIMITS_SCHEMA, "limits": GO_LIMITS, "free": {
        "exact": sorted(FREE_EXACT), "prefix": list(FREE_PREFIX),
    }, "agents": {}}
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, encoding="utf-8") as f:
                cfg = json.load(f)
        except (json.JSONDecodeError, OSError):
            cfg = {}
        out["default"] = cfg.get("model")
        out["agents"] = {k: v.get("model") for k, v in (cfg.get("agents") or {}).items()
                         if isinstance(v, dict)}
    if os.path.isdir(AGENTS_DIR):
        for fn in sorted(os.listdir(AGENTS_DIR)):
            if fn.endswith(".md"):
                ref = frontmatter_get_model(os.path.join(AGENTS_DIR, fn))
                if ref:
                    out["agents"][fn[:-3]] = ref
    return out


# ── CLI ────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(prog="opencode-ctl", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("usage", help="SQL-расход по окнам 5ч/7д/30д")

    mm = sub.add_parser("main-model", help="модель оркестратора (opencode.json / live)")
    mm.add_argument("ref", help="provider/model[#variant] или «default»")
    mm.add_argument("--live", action="store_true",
                    help="переключить активную топ-уровневую сессию через API")
    mm.add_argument("--session", default=None, help="живая сессия (иначе — активная корневая)")

    am = sub.add_parser("agent-model", help="модель субагента (agents/*.md или inline)")
    am.add_argument("agent", help="general/explore/scout/tester/reviewer")
    am.add_argument("ref", help="provider/model[#variant]")

    sub.add_parser("reload", help="opencode reload")
    lm = sub.add_parser("list-models", help="Go-таблица + модели агентов из файлов")
    lm.add_argument("--json", action="store_true")

    args = ap.parse_args()
    if args.cmd == "usage":
        cmd_usage(args)
    elif args.cmd == "main-model":
        cmd_main_model(args)
    elif args.cmd == "agent-model":
        cmd_agent_model(args)
    elif args.cmd == "reload":
        sys.exit(oc_reload())
    elif args.cmd == "list-models":
        cmd_list_models(args)


if __name__ == "__main__":
    main()

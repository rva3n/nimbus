#!/usr/bin/env python3
"""Umbriel settings — чтение и правка конфигурации композитора для Nimbus.

Интерфейс заморожен (его дергает QML настроек):

    umbriel-settings.py read
        Печатает ОДНУ строку JSON с ТЕКУЩИМИ эффективными значениями.
        Значения берутся из ~/.config/umbriel/src/*.toml, но если тот же
        ключ есть и в главном config.toml — главный конфиг побеждает
        (main overrides). Отсутствующие ключи в JSON не попадают —
        в QML на них есть fallback-значения.

    umbriel-settings.py set <file> <section> <key> <tomlValue>
        Например:
            set src/appearance.toml layout gap 12
            set src/input.toml input.mouse accel_profile "\\"adaptive\\""
            set src/appearance.toml output:DP-1 scale 1.25

        <section> для вывода — `output:DP-1`. <tomlValue> передаётся уже
        готовым TOML-литералом (строки — в кавычках), скрипт пишет как есть.

Только стандартная библиотека (tomllib есть в Python >= 3.11).
"""
import json
import os
import re
import subprocess
import sys

try:
    import tomllib
except ImportError:  # pragma: no cover - Python < 3.11
    print("нужен Python >= 3.11 (tomllib)", file=sys.stderr)
    raise SystemExit(1)

# --- Пути -------------------------------------------------------------------
CONFIG_DIR = os.path.join(os.path.expanduser("~"), ".config", "umbriel")
MAIN_CONFIG = os.path.join(CONFIG_DIR, "config.toml")
# Файлы, из которых читаются базовые (не-output) настройки.
SRC_FILES = (
    os.path.join(CONFIG_DIR, "src", "appearance.toml"),
    os.path.join(CONFIG_DIR, "src", "general.toml"),
    os.path.join(CONFIG_DIR, "src", "input.toml"),
)

DEVNULL = subprocess.DEVNULL

# Заголовок TOML-таблицы целиком (для определения границ секции).
HEADER_RE = re.compile(r"^\s*\[[^\]]*\]\s*(?:#.*)?$")


# --- Разбор TOML ------------------------------------------------------------
def load_toml(path):
    """Прочитать TOML, вернуть dict ({} если файла нет или он битый)."""
    try:
        with open(path, "rb") as f:
            return tomllib.load(f)
    except (OSError, tomllib.TOMLDecodeError):
        return {}


def deep_merge(base, override):
    """Рекурсивно наложить override поверх base (override побеждает).

    Не мутирует исходные словари.
    """
    out = dict(base)
    for k, v in override.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def effective_config():
    """Эффективная конфигурация: src/*.toml, затем главный config.toml."""
    eff = {}
    for path in SRC_FILES:
        eff = deep_merge(eff, load_toml(path))
    return deep_merge(eff, load_toml(MAIN_CONFIG))


# --- Вывод `umbriel outputs` ------------------------------------------------
def parse_outputs():
    """Разобрать `umbriel outputs` -> {name: {...}} для подключённых голов.

    Поля: scale(float), transform(str), adaptive(str), current((w,h,hz)),
    modes[(w,h,hz)].
    """
    try:
        proc = subprocess.run(
            ["umbriel", "outputs"],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return {}
    heads = {}
    cur = None
    in_modes = False
    for raw in proc.stdout.splitlines():
        if not raw.strip():
            continue
        if not raw[0].isspace():  # строка головы: "DP-1 \"...\""
            name = raw.split()[0]
            cur = {"modes": []}
            heads[name] = cur
            in_modes = False
            continue
        if cur is None:
            continue
        line = raw.strip()
        if line.startswith("Modes:"):
            in_modes = True
            continue
        m = re.match(r"^(\d+)x(\d+)\s*@\s*([\d.]+)\s*Hz", line)
        if m:
            if in_modes:
                mode = (int(m.group(1)), int(m.group(2)), float(m.group(3)))
                cur["modes"].append(mode)
                if "(current)" in line:
                    cur["current"] = mode
            continue
        if ":" in line:
            k, v = line.split(":", 1)
            k, v = k.strip(), v.strip()
            if k == "Scale":
                try:
                    cur["scale"] = float(v)
                except ValueError:
                    pass
            elif k == "Transform":
                cur["transform"] = v
            elif k == "Adaptive sync":
                cur["adaptive"] = v
    return heads


def fmt_hz(hz):
    """60.000 -> '60', 59.940 -> '59.94', 75.025 -> '75.025'."""
    return "%g" % hz


def fmt_mode(mode):
    return "%dx%d@%s" % (mode[0], mode[1], fmt_hz(mode[2]))


# --- Чтение -----------------------------------------------------------------
# Ключи: (поле в JSON, сколько частей пути после корня, тип)
SCALAR_KEYS = (
    ("appearance.border_width", ("appearance", "border_width"), int),
    ("appearance.corner_radius", ("appearance", "corner_radius"), int),
    ("appearance.drag_opacity", ("appearance", "drag_opacity"), float),
    ("layout.gap", ("layout", "gap"), int),
    ("appearance.shadow.enabled", ("appearance", "shadow", "enabled"), bool),
    ("appearance.shadow.softness", ("appearance", "shadow", "softness"), int),
    ("appearance.blur.enabled", ("appearance", "blur", "enabled"), bool),
    ("animation.enabled", ("animation", "enabled"), bool),
    ("input.mouse.sensitivity", ("input", "mouse", "sensitivity"), float),
    ("input.mouse.natural_scroll", ("input", "mouse", "natural_scroll"), bool),
    ("input.mouse.accel_profile", ("input", "mouse", "accel_profile"), str),
    ("input.keyboard.repeat_delay", ("input", "keyboard", "repeat_delay"), int),
    ("input.keyboard.repeat_rate", ("input", "keyboard", "repeat_rate"), int),
    ("input.keyboard.options", ("input", "keyboard", "options"), str),
    ("input.focus.follows_mouse", ("input", "focus", "follows_mouse"), bool),
    ("input.middle_click_paste", ("input", "middle_click_paste"), bool),
    ("input.cursor.hide_when_typing", ("input", "cursor", "hide_when_typing"), bool),
)


def _lookup(data, path):
    cur = data
    for part in path:
        if not isinstance(cur, dict) or part not in cur:
            return _MISSING
        cur = cur[part]
    return cur


_MISSING = object()


def cmd_read():
    eff = effective_config()
    result = {}
    for name, path, cast in SCALAR_KEYS:
        val = _lookup(eff, path)
        if val is _MISSING:
            continue
        try:
            result[name] = cast(val)
        except (TypeError, ValueError):
            continue

    # Выходы: значения из конфига, но список режимов и «сырые» поля — из
    # состояния композитора (`umbriel outputs`).
    out_cfg = eff.get("output", {})
    if not isinstance(out_cfg, dict):
        out_cfg = {}
    for name, info in parse_outputs().items():
        cfg = out_cfg.get(name, {})
        if not isinstance(cfg, dict):
            cfg = {}

        if "scale" in cfg:
            result["output.%s.scale" % name] = float(cfg["scale"])
        elif "scale" in info:
            result["output.%s.scale" % name] = info["scale"]

        if "vrr" in cfg:
            result["output.%s.vrr" % name] = str(cfg["vrr"])
        elif "adaptive" in info:
            result["output.%s.vrr" % name] = (
                "off" if info["adaptive"].lower().startswith("disabled") else "on"
            )

        if "transform" in cfg:
            result["output.%s.transform" % name] = str(cfg["transform"])
        elif "transform" in info:
            result["output.%s.transform" % name] = info["transform"]

        if "mode" in cfg:
            result["output.%s.mode" % name] = str(cfg["mode"])
        elif "current" in info:
            result["output.%s.mode" % name] = fmt_mode(info["current"])

        modes = sorted(set(info.get("modes", [])), key=lambda t: (t[0], t[1], t[2]))
        if modes:
            result["output.%s.modes" % name] = [fmt_mode(m) for m in modes]

    print(json.dumps(result, ensure_ascii=False))
    return 0


# --- Правка -----------------------------------------------------------------
def _sec_re(section):
    """Регэксп заголовка секции (для output — с учётом кавычек)."""
    if section.startswith("output:"):
        name = re.escape(section[len("output:"):])
        return re.compile(
            r'^\s*\[output\s*\.\s*(?:"%s"|%s)\s*\]\s*(?:#.*)?$' % (name, name)
        )
    return re.compile(r"^\s*\[%s\]\s*(?:#.*)?$" % re.escape(section))


def _key_re(key):
    return re.compile(
        r"^(\s*)" + re.escape(key) + r"\s*=\s*(.*?)(\s+#.*)?$"
    )


def _header_for(section):
    if section.startswith("output:"):
        return 'output."%s"' % section[len("output:"):]
    return section


def apply_edit(text, section, key, value):
    """Заменить/добавить key = value в секции, вернуть новый текст."""
    lines = text.split("\n")
    sec_re = _sec_re(section)

    start = -1
    for i, line in enumerate(lines):
        if sec_re.match(line):
            start = i
            break

    if start == -1:
        # Секции нет нигде — дописываем в конец целевого файла.
        out = text
        if out and not out.endswith("\n"):
            out += "\n"
        if out and not out.endswith("\n\n"):
            out += "\n"
        out += "[%s]\n%s = %s\n" % (_header_for(section), key, value)
        return out

    # Границы секции — до следующего заголовка таблицы или EOF.
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if HEADER_RE.match(lines[j]):
            end = j
            break

    key_re = _key_re(key)
    found = -1
    for j in range(start + 1, end):
        if key_re.match(lines[j]):
            found = j
            break

    if found != -1:
        m = key_re.match(lines[found])
        comment = m.group(3) or ""
        lines[found] = "%s%s = %s%s" % (m.group(1), key, value, comment)
    else:
        # Вставляем в конец секции, но перед её хвостовыми пустыми строками.
        ins = end
        while ins > start + 1 and lines[ins - 1].strip() == "":
            ins -= 1
        lines.insert(ins, "%s = %s" % (key, value))
    return "\n".join(lines)


def _node(data, section):
    """Узел-словарь секции или None. section: 'a.b' или 'output:NAME'."""
    if section.startswith("output:"):
        path = ("output", section[len("output:"):])
    else:
        path = tuple(section.split("."))
    cur = data
    for part in path:
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur if isinstance(cur, dict) else None


def resolve_path(file_arg):
    if os.path.isabs(file_arg):
        return file_arg
    return os.path.join(CONFIG_DIR, file_arg)


def cmd_set(argv):
    if len(argv) != 4:
        print("usage: umbriel-settings.py set <file> <section> <key> <tomlValue>",
              file=sys.stderr)
        return 2
    file_arg, section, key, value = argv
    target = resolve_path(file_arg)
    if not os.path.isfile(target):
        print("нет файла: %s" % target, file=sys.stderr)
        return 1

    same_main = os.path.abspath(target) == os.path.abspath(MAIN_CONFIG)
    edit_path = target

    if not same_main:
        # Если ключ есть в главном конфиге (или секция только там) — правим
        # главный: именно он задаёт эффективное значение.
        main_data = load_toml(MAIN_CONFIG)
        tgt_data = load_toml(target)
        main_sec = _node(main_data, section)
        tgt_sec = _node(tgt_data, section)
        main_has_key = main_sec is not None and key in main_sec
        tgt_has_sec = tgt_sec is not None
        if main_has_key or (main_sec is not None and not tgt_has_sec):
            edit_path = MAIN_CONFIG

    try:
        with open(edit_path, "r", encoding="utf-8") as f:
            text = f.read()
    except OSError as exc:
        print("не удалось прочитать %s: %s" % (edit_path, exc), file=sys.stderr)
        return 1

    new_text = apply_edit(text, section, key, value)
    try:
        with open(edit_path, "w", encoding="utf-8") as f:
            f.write(new_text)
    except OSError as exc:
        print("не удалось записать %s: %s" % (edit_path, exc), file=sys.stderr)
        return 1

    # Перечитать конфиг композитором; ошибки не фатальны.
    try:
        subprocess.run(["umbriel", "msg", "config-reload"],
                       stdout=DEVNULL, stderr=DEVNULL, timeout=10)
    except (OSError, subprocess.SubprocessError):
        pass
    return 0


# --- Точка входа ------------------------------------------------------------
def main(argv):
    if not argv:
        print("usage: umbriel-settings.py {read|set ...}", file=sys.stderr)
        return 2
    if argv[0] == "read":
        return cmd_read()
    if argv[0] == "set":
        return cmd_set(argv[1:])
    print("неизвестная команда: %s" % argv[0], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

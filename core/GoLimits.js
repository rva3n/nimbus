.pragma library
// Таблица лимитов плана OpenCode Go — легкоредактируемая строкочка.
//
// СХЕМА: "go-limits v1" — источники:
//   • сводка плана из переписки оркестратора (Oberon, волна B4): OpenCode Go $10,
//     лимит — месячные $ НА КАЖДУЮ модель (не общий счётчик), окна:
//     5ч = 20% месячного лимита, неделя = 50%, месяц = 100%;
//     Go Plus — те же лимиты ×2 (ключ Prefs.goPlan).
//   • проверка цифр: SELECT … FROM session_message (см. core/GoUsage.qml).
// При смене плана/чисел правятся GO_LIMITS/PLUS_MULT ниже, версию bumped-им.

// Месячный лимит ($) на модель для базового плана Go.
var GO_LIMITS = {
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
    "space-bunny": 30
};

// Месяц Go Plus = базовый лимит × эта константа.
var PLUS_MULT = 2;

// Окна расхода: <окно>: { h — длина в мс, frac — доля месячного лимита,
// label — подпись в UI }. Месяц = rolling 30д.
var WINDOWS = {
    "5h":  { "h": 5 * 3600 * 1000,      "frac": 0.20, "label": "5ч" },
    "7d":  { "h": 7 * 86400 * 1000,     "frac": 0.50, "label": "7д" },
    "30d": { "h": 30 * 86400 * 1000,    "frac": 1.00, "label": "30д" }
};

// Порядок окон в карточках/тултипах.
var WINDOW_KEYS = ["5h", "7d", "30d"];

var GO_PROVIDER = "opencode-go";

// free-модели — «unlimited»: суффикс -free, префиксы семейств и точный список.
// (longcat-*/step-*/muse-spark-*-free и space-bunny-free приходят суффиксами/точным списком).
var FREE_EXACT = ["space-bunny-free"];
var FREE_PREFIX = ["mimo-", "nemotron-", "jev-", "ling-"];

function isFree(id) {
    if (typeof id !== "string" || id === "")
        return false;
    if (id.slice(-5) === "-free")
        return true; // longcat-2.5-preview-free, step-5-preview-free, muse-spark-*-free, …
    if (FREE_EXACT.indexOf(id) !== -1)
        return true;
    for (var i = 0; i < FREE_PREFIX.length; i++)
        if (FREE_PREFIX[i] !== "" && id.indexOf(FREE_PREFIX[i]) === 0)
            return true;
    return false;
}

// Месячный лимит модели с учётом плана: 0 = «unlimited», -1 = нет в таблице.
function limitFor(id, plan) {
    if (typeof GO_LIMITS[id] === "number")
        return GO_LIMITS[id] * (plan === "plus" ? PLUS_MULT : 1);
    if (isFree(id))
        return 0;
    return -1;
}

function planLabel(plan) {
    return plan === "plus" ? "Go Plus" : "Go";
}

// Короткие имена моделей для UI: подсказка префикса + обычные токены.
var NAME_HINTS = {
    "deepseek": "DeepSeek", "glm": "GLM", "kimi": "Kimi", "minimax": "MiniMax",
    "muse-spark": "Muse Spark", "qwen": "Qwen", "grok": "Grok", "gpt": "GPT",
    "claude": "Claude", "hy3": "HY3", "hy4-preview": "HY4 Preview",
    "space-bunny": "Space Bunny", "longcat": "LongCat", "step": "Step",
    "mimo": "MiMo", "nemotron": "Nemotron", "jev": "Jev", "ling": "Ling"
};

function nameOf(id) {
    if (typeof NAME_HINTS[id] === "string")
        return NAME_HINTS[id];
    var parts = String(id).split("-");
    var out = [];
    for (var i = 0; i < parts.length; i++) {
        var t = parts[i];
        if (i === 0 && typeof NAME_HINTS[t] === "string") {
            out.push(NAME_HINTS[t]);
        } else if (t.length > 2) {
            out.push(t.charAt(0).toUpperCase() + t.slice(1));
        } else {
            out.push(t); // версии (v4.1, 5) и мелкие токены — как есть
        }
    }
    return out.join(" ");
}

.pragma library
// Таблица лимитов плана OpenCode Go — легкоредактируемая строкочка.
//
// СХЕМА: "go-limits v2" — источники:
//   • официальная документация OpenCode Go (opencode.ai/v2/docs/console/go):
//     OpenCode Go $10/мес, Go Plus $40/мес.
//   • все модели подписки делят единый нормализованный счётчик подписки
//     (сумма % расхода по использованным моделям от их месячных/7д/5ч квот;
//     базовый эквивалент плана: $60/мес, $30/7д, $12/5ч для Go и $240/$120/$48 для Go Plus).
//   • окна: 5ч = 20% месячного лимита, неделя (7д) = 50%, месяц (30д) = 100%.
//   • проверка цифр: SELECT … FROM session_message / message / part (см. core/GoUsage.qml).
// При смене плана/чисел правятся GO_LIMITS/GO_PLUS_LIMITS ниже, версию bumped-им.

// Месячный лимит ($) на модель для базового плана Go ($10/мес).
var GO_LIMITS = {
    "deepseek-v4.1-flash": 80,
    "gemini-4-argon-contributor": 60,
    "glm-5.3-flash": 60,
    "glm-5.2": 60,
    "glm-5.3": 15,
    "kimi-k2.7-code": 60,
    "kimi-k2.6": 60,
    "kimi-k3": 15,
    "longcat-2.0": 60,
    "minimax-m3": 60,
    "minimax-m2.7": 60,
    "mimo-v2.6-flash": 60,
    "mimo-v2.6-pro": 15,
    "mimo-v2.5": 60,
    "mimo-v2.5-pro": 15,
    "muse-spark-1.3": 60,
    "muse-spark-1.3-contributor": 60,
    "muse-spark-1.2-contributor": 60,
    "qwen3.8-flash": 30,
    "qwen3.8-max": 15,
    "qwen3.7-plus": 60,
    "step-5-preview": 60,
    "grok-4.7": 15,
    "gpt-6-luna": 15,
    "gpt-5.6-luna": 15,
    "claude-haiku-5-5": 15,
    "deepseek-v4-pro": 15,
    "deepseek-v4-flash": 30,
    "deepseek-v4-flash-vision-exp": 15,
    "hy3": 60,
    "hy4-preview": 30,
    "space-bunny": 30
};

// Явные лимиты ($) на модель для плана Go Plus ($40/мес).
var GO_PLUS_LIMITS = {
    "deepseek-v4.1-flash": 160,
    "gemini-4-argon-contributor": 240,
    "glm-5.3-flash": 180,
    "glm-5.2": 180,
    "glm-5.3": 120,
    "kimi-k2.7-code": 180,
    "kimi-k2.6": 180,
    "kimi-k3": 60,
    "longcat-2.0": 240,
    "minimax-m3": 180,
    "minimax-m2.7": 180,
    "mimo-v2.6-flash": 120,
    "mimo-v2.6-pro": 60,
    "mimo-v2.5": 120,
    "mimo-v2.5-pro": 60,
    "muse-spark-1.3": 120,
    "muse-spark-1.3-contributor": 120,
    "muse-spark-1.2-contributor": 120,
    "qwen3.8-flash": 90,
    "qwen3.8-max": 60,
    "qwen3.7-plus": 180,
    "step-5-preview": 240,
    "grok-4.7": 60,
    "gpt-6-luna": 60,
    "gpt-5.6-luna": 60,
    "claude-haiku-5-5": 60,
    "deepseek-v4-pro": 60,
    "deepseek-v4-flash": 90,
    "deepseek-v4-flash-vision-exp": 60,
    "hy3": 240,
    "hy4-preview": 120,
    "space-bunny": 120
};

// Дефолтный множитель Go Plus, если модель не задана в GO_PLUS_LIMITS.
var PLUS_MULT = 3;

// Базовый месячный лимит подписки ($) и дефолтный лимит неизвестной платной модели:
// Go = $60/мес ($12 за 5ч, $30 за 7д), Go Plus = $240/мес ($48 за 5ч, $120 за 7д).
var PLAN_BASE_LIMIT = {
    "go": 60,
    "plus": 240
};

var DEFAULT_MODEL_LIMIT = 60;

// Окна расхода: <окно>: { h — длина в мс, frac — доля месячного лимита,
// label — подпись в UI, title — полная подпись }. Месяц = rolling 30д.
var WINDOWS = {
    "5h":  { "h": 5 * 3600 * 1000,      "frac": 0.20, "label": "5ч",  "title": "5 часов" },
    "7d":  { "h": 7 * 86400 * 1000,     "frac": 0.50, "label": "7д",  "title": "7 дней" },
    "30d": { "h": 30 * 86400 * 1000,    "frac": 1.00, "label": "30д", "title": "30 дней" }
};

// Порядок окон в карточках/тултипах.
var WINDOW_KEYS = ["5h", "7d", "30d"];

var GO_PROVIDER = "opencode-go";

// free-модели — «unlimited»: суффикс -free, префиксы семейств и точный список.
// (longcat-2.5-preview-free, beam-free, space-bunny-free и т.д.).
var FREE_EXACT = ["space-bunny-free", "beam-free", "longcat-2.5-preview-free", "big-pickle"];
var FREE_PREFIX = ["nemotron-", "jev-", "ling-"];

function isFree(id) {
    if (typeof id !== "string" || id === "")
        return false;
    if (id.slice(-5) === "-free")
        return true; // longcat-2.5-preview-free, beam-free, muse-spark-*-free, …
    if (FREE_EXACT.indexOf(id) !== -1)
        return true;
    for (var i = 0; i < FREE_PREFIX.length; i++)
        if (FREE_PREFIX[i] !== "" && id.indexOf(FREE_PREFIX[i]) === 0)
            return true;
    return false;
}

// Базовый месячный лимит всей подписки ($) для плана.
function planLimit(plan) {
    return plan === "plus" ? PLAN_BASE_LIMIT["plus"] : PLAN_BASE_LIMIT["go"];
}

// Лимит окна всей подписки ($) для плана и ключа окна ("5h" | "7d" | "30d").
function planWindowCap(plan, key) {
    var w = WINDOWS[key];
    if (!w)
        return 0;
    return planLimit(plan) * w.frac;
}

// Месячный лимит модели с учётом плана: 0 = «unlimited», >0 = лимит в $.
// Для новых моделей opencode-go, ещё не внесённых в таблицу, возвращает дефолтный лимит плана,
// чтобы их расход учитывался в общей подписке.
function limitFor(id, plan) {
    if (isFree(id))
        return 0;
    if (plan === "plus" && typeof GO_PLUS_LIMITS[id] === "number")
        return GO_PLUS_LIMITS[id];
    if (typeof GO_LIMITS[id] === "number")
        return GO_LIMITS[id] * (plan === "plus" ? PLUS_MULT : 1);
    return DEFAULT_MODEL_LIMIT * (plan === "plus" ? PLUS_MULT : 1);
}

function planLabel(plan) {
    return plan === "plus" ? "Go Plus" : "Go";
}

// Короткие имена моделей для UI: подсказка префикса + обычные токены.
var NAME_HINTS = {
    "deepseek": "DeepSeek", "gemini": "Gemini", "glm": "GLM", "kimi": "Kimi",
    "minimax": "MiniMax", "muse-spark": "Muse Spark", "qwen": "Qwen", "grok": "Grok",
    "gpt": "GPT", "claude": "Claude", "hy3": "HY3", "hy4-preview": "HY4 Preview",
    "space-bunny": "Space Bunny", "longcat": "LongCat", "step": "Step",
    "mimo": "MiMo", "nemotron": "Nemotron", "jev": "Jev", "ling": "Ling",
    "beam": "Beam",
    "gemini-4-argon-contributor": "Gemini 4 Argon",
    "muse-spark-1.3-contributor": "Muse Spark 1.3",
    "muse-spark-1.2-contributor": "Muse Spark 1.2"
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

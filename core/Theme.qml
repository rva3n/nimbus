pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Nimbus design tokens — Material 3 Expressive, без зависимостей от Hyprland.
//
// Палитра приходит от matugen в ~/.cache/nimbus/colors.json (полный набор M3
// ролей) и читается FileView'ом. Всё остальное выводится здесь: тональные
// рампы (atTone/tonal/tint), семантические роли, типографика, motion и формы —
// адаптация дизайн-движка Lucid (MIT) под Nimbus.
Singleton {
    id: root

    // ── Палитра (matugen → ~/.cache/nimbus/colors.json) ───────────────
    FileView {
        id: paletteFile
        path: Quickshell.env("HOME") + "/.cache/nimbus/colors.json"
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: m

            property string source_color: ""
            property string primary: "#a8c7fa"
            property string on_primary: "#062e6f"
            property string primary_container: "#0842a0"
            property string on_primary_container: "#d3e3fd"
            property string inverse_primary: "#415f91"
            property string secondary: "#bec6dc"
            property string on_secondary: "#283141"
            property string secondary_container: "#3e4759"
            property string on_secondary_container: "#dae2f9"
            property string tertiary: "#ddbce0"
            property string on_tertiary: "#3f2844"
            property string tertiary_container: "#573e5c"
            property string on_tertiary_container: "#fbdefe"
            property string error: "#ffb4ab"
            property string on_error: "#690005"
            property string error_container: "#93000a"
            property string on_error_container: "#ffdad6"
            property string surface: "#111318"
            property string on_surface: "#e2e2e9"
            property string surface_variant: "#44474f"
            property string on_surface_variant: "#c4c6d0"
            property string surface_dim: "#111318"
            property string surface_bright: "#37393e"
            property string surface_tint: "#a8c7fa"
            property string surface_container_lowest: "#0c0e13"
            property string surface_container_low: "#191c20"
            property string surface_container: "#1d2024"
            property string surface_container_high: "#282a2f"
            property string surface_container_highest: "#33353a"
            property string outline: "#8e9099"
            property string outline_variant: "#44474f"
            property string inverse_surface: "#e2e2e9"
            property string inverse_on_surface: "#2f3033"
            property string shadow: "#000000"
            property string scrim: "#000000"
        }
    }

    readonly property bool paletteLoaded: paletteFile.loaded

    // ── Настройки вида (позже переедут в prefs.json) ──────────────────
    readonly property real uiScale: 1
    readonly property real cornerScale: 1
    readonly property real motionScale: 1
    // 0 = непрозрачные панели, 1 = максимальное стекло
    property real blurAmount: 0
    // акцент: 1 = как даёт палитра, >1 — ярче, <1 — тише
    property real accentPunch: 1
    // тени поверхностей: -1 = авто по теме
    property real surfaceDarkness: -1
    property real surfaceTintSetting: -1

    readonly property bool isLight: root.toneOf(root.cSurface) > 50
    readonly property int _dir: root.isLight ? -1 : 1
    readonly property real surfaceTint: root.surfaceTintSetting >= 0 ? root.surfaceTintSetting : (root.isLight ? 0.7 : 0)
    readonly property real _toneShift: Math.max(0, root.surfaceDarkness) * 3
    readonly property real _tintLift: 10
    readonly property real _tintTarget: 0.13
    readonly property color _containerSeed: root.cPrimaryContainer
    readonly property real _containerSatFloor: 0.22
    readonly property real _cardSatFloor: root.isLight ? root._containerSatFloor : Math.min(1, Math.max(root._containerSatFloor, root.mHigh.hslSaturation * 1.15))
    readonly property real _containerTone: root.isLight ? 30 : Math.max(30, root.toneOf(root.mHigh) + 2)
    readonly property real _containerInkTone: Math.min(98, Math.max(90, root._containerTone + 45))
    readonly property real _rampShift: root.surfaceTint <= 0 ? 0 : (root.isLight ? Math.max(0, root.toneOf(root.cLowest) - (100 - root.surfaceTint * root._tintLift)) : -(root.surfaceTint * root._tintLift))

    // ── Сырые роли ─────────────────────────────────────────────────────
    readonly property color cPrimary: m.primary
    readonly property color cOnPrimary: m.on_primary
    readonly property color cPrimaryContainer: m.primary_container
    readonly property color cOnPrimaryContainer: m.on_primary_container
    readonly property color cInversePrimary: m.inverse_primary
    readonly property color cSecondary: m.secondary
    readonly property color cOnSecondary: m.on_secondary
    readonly property color cSecondaryContainer: m.secondary_container
    readonly property color cOnSecondaryContainer: m.on_secondary_container
    readonly property color cTertiary: m.tertiary
    readonly property color cOnTertiary: m.on_tertiary
    readonly property color cTertiaryContainer: m.tertiary_container
    readonly property color cOnTertiaryContainer: m.on_tertiary_container
    readonly property color cError: m.error
    readonly property color cOnError: m.on_error
    readonly property color cErrorContainer: m.error_container
    readonly property color cOnErrorContainer: m.on_error_container
    readonly property color cSurface: m.surface
    readonly property color cOnSurface: m.on_surface
    readonly property color cSurfaceVariant: m.surface_variant
    readonly property color cOnSurfaceVariant: m.on_surface_variant
    readonly property color cSurfaceBright: m.surface_bright
    readonly property color cSurfaceTint: m.surface_tint
    readonly property color cLowest: m.surface_container_lowest
    readonly property color cLow: m.surface_container_low
    readonly property color cContainer: m.surface_container
    readonly property color cHigh: m.surface_container_high
    readonly property color cHighest: m.surface_container_highest
    readonly property color cOutline: m.outline
    readonly property color cOutlineVariant: m.outline_variant
    readonly property color cInverseSurface: m.inverse_surface
    readonly property color cInverseOnSurface: m.inverse_on_surface
    readonly property color cShadow: m.shadow
    readonly property color cScrim: m.scrim

    // ── Тональная рампа поверхностей (M3 elevation) ────────────────────
    readonly property color mSurface: root.toneSurface(root.cSurface, root._toneShift)
    readonly property color mLowest: root.toneSurface(root.cLowest, root._toneShift)
    readonly property color mLow: root.toneSurface(root.cLow, root._toneShift)
    readonly property color mContainer: root.toneSurface(root.cContainer, root._toneShift)
    readonly property color mHigh: root.toneSurface(root.cHigh, root._toneShift)
    readonly property color mHighest: root.toneSurface(root.cHighest, root._toneShift)
    readonly property color mBright: root.toneSurface(root.cSurfaceBright, root._toneShift)

    // ── Семантика поверхностей ─────────────────────────────────────────
    readonly property color bg: root.alpha(root.mContainer, 1 - root.blurAmount * 0.85)
    readonly property color bgTransparent: root.alpha(root.bg, 0)
    readonly property color bgOpaque: root.mContainer
    readonly property color bgSunken: root.mLow
    readonly property color bgTile: root.mHigh
    readonly property color bgHover: root.mHighest
    readonly property color bgActive: root.atTone(root.mHighest, root.toneOf(root.mHighest) + root._dir * 3)
    readonly property color bgBright: root.mBright
    readonly property color bgTrack: root.mHighest
    // legacy-алиасы старого острова: панель — bg, карточка — surface, ховер — surfaceHi
    readonly property color surface: root.mHigh
    readonly property color surfaceHi: root.mHighest

    readonly property color text: root.cOnSurface
    readonly property color subtext: root.cOnSurfaceVariant
    readonly property color subtextDim: root.tint(root.atTone(root.cOnSurfaceVariant, root.isLight ? 50 : 65), 1.5)

    // Акцент и его контейнеры. NB: имена не начинаются с on<Role> — иначе QML
    // парсит свойство как обработчик сигнала. Поэтому fg*.
    readonly property color accent: root.accentPunch === 1 ? root.cPrimary : root.atTone(root.cPrimary, root.toneOf(root.cPrimary) + root._dir * (root.accentPunch - 1) * 9)
    readonly property color accentHover: root.atTone(root.accent, Math.max(0, Math.min(100, root.toneOf(root.accent) + root._dir * 6)))
    readonly property color accentPressed: root.atTone(root.accent, Math.max(0, Math.min(100, root.toneOf(root.accent) - root._dir * 6)))
    readonly property color fgOnFill: root.containerFill(root._containerSeed, root.isLight ? 98 : 20)
    readonly property color fgAccent: root.fgOnFill
    readonly property color accentContainer: root.containerFill(root._containerSeed, root._containerTone, root._cardSatFloor)
    readonly property color fgAccentContainer: root.containerInk(root._containerSeed)
    readonly property color accentMuted: root.atTone(root.withSat(root.cPrimary, 0.55), (root.toneOf(root.cPrimary) + root.toneOf(root.cOnSurfaceVariant)) / 2)
    readonly property color accentBorder: root.alpha(root.accent, 0.45)
    readonly property color secondaryContainer: root.accentContainer
    readonly property color fgSecondaryContainer: root.fgAccentContainer
    readonly property color tertiaryContainer: root.accentContainer
    readonly property color fgTertiaryContainer: root.fgAccentContainer

    readonly property color outline: root.tint(root.cOutlineVariant, 1.8)
    readonly property color outlineStrong: root.tint(root.cOutline, 1.8)
    readonly property color error: root.cError
    readonly property color fgError: root.fgOnFill
    readonly property color errorContainer: root.containerFill(root.cError, root._containerTone, root._cardSatFloor)
    readonly property color fgErrorContainer: root.containerInk(root.cError)
    readonly property color success: root.isGreenish(root.cTertiary) ? root.cTertiary : root.statusHue(145)
    readonly property color fgSuccess: root.fgOnFill
    readonly property color warning: root.statusHue(45)
    readonly property color fgWarning: root.fgOnFill
    readonly property color shadow: root.cShadow
    readonly property color scrim: root.alpha(root.cScrim, 0.5)
    readonly property color inverseSurface: root.cInverseSurface
    readonly property color fgInverseSurface: root.tint(root.cInverseOnSurface, 1.6)
    readonly property color inversePrimary: root.cInversePrimary

    // M3-имена для нового кода
    readonly property color primary: root.accent
    readonly property color fgPrimary: root.fgAccent
    readonly property color primaryContainer: root.accentContainer
    readonly property color fgPrimaryContainer: root.fgAccentContainer
    readonly property color secondary: root.containerFill(root.withHue(root.cPrimary, -20), root.toneOf(root.cSecondary))
    readonly property color fgSecondary: root.fgOnFill
    readonly property color tertiary: root.containerFill(root.withHue(root.cPrimary, 14), root.isLight ? 42 : 80)
    readonly property color fgTertiary: root.fgOnFill
    readonly property color divider: root.alpha(root.cOutlineVariant, root.isLight ? 0.7 : 0.55)

    // ── State layer ────────────────────────────────────────────────────
    readonly property real stateHover: 0.08
    readonly property real stateFocus: 0.1
    readonly property real statePressed: 0.1
    readonly property real stateDragged: 0.16
    readonly property real disabledContent: 0.38
    readonly property real disabledContainer: 0.12

    // ── Формы ──────────────────────────────────────────────────────────
    readonly property int radiusPill: 999
    readonly property int radiusXs: root.rad(8)
    readonly property int radiusSm: root.rad(12)
    readonly property int radiusMd: root.rad(16)
    readonly property int radiusLg: root.rad(20)
    readonly property int radiusXl: root.rad(28)
    readonly property int shapeNone: 0
    readonly property int shapeXs: root.dp(4)
    readonly property int shapeSm: root.rad(8)
    readonly property int shapeMd: root.rad(12)
    readonly property int shapeLg: root.rad(16)
    readonly property int shapeLgInc: root.rad(20)
    readonly property int shapeXl: root.rad(28)
    readonly property int shapeXlInc: root.rad(32)
    readonly property int shapeXxl: root.rad(48)
    readonly property int shapeFull: 999
    readonly property int shapeJoin: root.dp(4)

    // ── Motion (адаптация кривых Lucid) ────────────────────────────────
    readonly property int durQuick: Math.round(120 * root.motionScale)
    readonly property int durShort: Math.round(180 * root.motionScale)
    readonly property int durMedium: Math.round(280 * root.motionScale)
    readonly property int durLong: Math.round(400 * root.motionScale)
    readonly property var easeEmphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var easeEmphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property int durEnter: Math.round(320 * root.motionScale)
    readonly property int durExit: Math.round(190 * root.motionScale)
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeEmphasized: Easing.OutBack
    readonly property real emphasizedOvershoot: 0.7
    readonly property var curveStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var curveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var curveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var curveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var curveEffects: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property int durFastSpatial: Math.round(350 * root.motionScale)
    readonly property int durDefaultSpatial: Math.round(500 * root.motionScale)
    readonly property int durSlowSpatial: Math.round(650 * root.motionScale)
    readonly property int durFastEffects: Math.round(150 * root.motionScale)
    readonly property int durDefaultEffects: Math.round(200 * root.motionScale)
    readonly property int durSlowEffects: Math.round(300 * root.motionScale)

    // ── Типографика ────────────────────────────────────────────────────
    // Иконный шрифт бандлится в assets/fonts, чтобы не зависеть от системы.
    FontLoader {
        id: iconFontLoader
        source: "file://" + Quickshell.env("HOME") + "/nimbus/assets/fonts/MaterialSymbolsRounded.ttf"
    }
    readonly property string textFont: "Roboto"
    readonly property string textFontFallback: "Noto Sans"
    readonly property string iconFont: iconFontLoader.status === FontLoader.Ready ? iconFontLoader.name : "Material Symbols Rounded"

    readonly property real typeBaseline: 0.9
    readonly property real fontScale: root.typeBaseline * root.uiScale

    readonly property int fontLabel: Math.round(11 * root.fontScale)
    readonly property int fontBody: Math.round(12 * root.fontScale)
    readonly property int fontTitle: Math.round(13 * root.fontScale)
    readonly property int fontHeadline: Math.round(15 * root.fontScale)

    readonly property int fontDisplayLg: Math.round(52 * root.fontScale)
    readonly property int fontDisplayMd: Math.round(42 * root.fontScale)
    readonly property int fontDisplaySm: Math.round(32 * root.fontScale)
    readonly property int fontHeadlineLg: Math.round(30 * root.fontScale)
    readonly property int fontHeadlineMd: Math.round(26 * root.fontScale)
    readonly property int fontHeadlineSm: Math.round(22 * root.fontScale)
    readonly property int fontTitleLg: Math.round(19 * root.fontScale)
    readonly property int fontTitleMd: Math.round(16 * root.fontScale)
    readonly property int fontTitleSm: Math.round(14 * root.fontScale)
    readonly property int fontBodyLg: Math.round(15 * root.fontScale)
    readonly property int fontBodyMd: Math.round(13 * root.fontScale)
    readonly property int fontBodySm: Math.round(12 * root.fontScale)
    readonly property int fontLabelLg: Math.round(13 * root.fontScale)
    readonly property int fontLabelMd: Math.round(12 * root.fontScale)
    readonly property int fontLabelSm: Math.round(11 * root.fontScale)

    readonly property var typeRoles: ({
        "displayLarge": [52, 500],
        "displayMedium": [42, 500],
        "displaySmall": [32, 500],
        "headlineLarge": [30, 500],
        "headlineMedium": [26, 500],
        "headlineSmall": [22, 500],
        "titleLarge": [19, 500],
        "titleMedium": [16, 560],
        "titleSmall": [14, 560],
        "bodyLarge": [15, 420],
        "bodyMedium": [13, 420],
        "bodySmall": [12, 420],
        "labelLarge": [13, 560],
        "labelMedium": [12, 560],
        "labelSmall": [11, 560]
    })

    function typeSize(role) {
        var r = root.typeRoles[role] || root.typeRoles.bodyMedium;
        return Math.round(r[0] * root.fontScale);
    }
    function typeWeight(role) {
        var r = root.typeRoles[role] || root.typeRoles.bodyMedium;
        return r[1];
    }

    // ── Legacy-метрики старого острова ─────────────────────────────────
    readonly property int radius: root.radiusLg
    readonly property int pad: 12
    readonly property int height: 34
    readonly property int spacing: 10

    // ── Хелперы масштаба ───────────────────────────────────────────────
    function dp(px) { return Math.round(px * root.uiScale) }
    function rad(px) { return px < 8 ? root.dp(px) : Math.round(px * root.uiScale * root.cornerScale) }
    function pill(size) { return size / 2 * Math.min(1, root.cornerScale) }
    function fs(px) { return Math.round(px * root.fontScale) }
    function ms(d) { return Math.round(d * root.motionScale) }

    // ── Цветовая математика (M3 tone) ──────────────────────────────────
    function _lin(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4) }
    function _gam(c) {
        var v = c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
        return Math.max(0, Math.min(1, v));
    }
    function _y(c) { return 0.2126 * root._lin(c.r) + 0.7152 * root._lin(c.g) + 0.0722 * root._lin(c.b) }
    function _yAt(t) { return t <= 8 ? t / 903.2963 : Math.pow((t + 16) / 116, 3) }

    function toneOf(c) {
        var y = root._y(c);
        return y <= 0.008856 ? y * 903.2963 : 116 * Math.pow(y, 1 / 3) - 16;
    }

    function atTone(c, t) {
        var tt = Math.max(0, Math.min(100, t));
        var target = root._yAt(tt);
        var y = root._y(c);
        if (y <= 0) {
            var g = root._gam(target);
            return Qt.rgba(g, g, g, c.a);
        }
        var k = target / y;
        var lr = root._lin(c.r) * k;
        var lg = root._lin(c.g) * k;
        var lb = root._lin(c.b) * k;
        var peak = Math.max(lr, lg, lb);
        if (peak > 1) {
            lr /= peak;
            lg /= peak;
            lb /= peak;
            var yb = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb;
            var w = yb >= 1 ? 0 : Math.max(0, Math.min(1, (target - yb) / (1 - yb)));
            lr += (1 - lr) * w;
            lg += (1 - lg) * w;
            lb += (1 - lb) * w;
        }
        return Qt.rgba(root._gam(lr), root._gam(lg), root._gam(lb), c.a);
    }

    // одна ступень тональной рампы: hue пересобирается на средней светлоте,
    // чтобы цвет не выцветал в серый к низу рампы
    function tonal(c, tone) {
        var h = c.hslHue;
        if (h < 0)
            return root.atTone(c, tone);

        var lift = 1 + Math.max(0, (50 - tone) / 50) * 3;
        var s = Math.min(1, c.hslSaturation * lift);
        return root.atTone(Qt.hsla(h, s, 0.5, c.a), tone);
    }

    function shade(c, tones) { return tones === 0 ? c : root.atTone(c, root.toneOf(c) - tones) }

    // подтянуть нейтраль к hue акцента, не сдвигая тон
    function tint(c, k) {
        if (k <= 0)
            return c;

        var h = root.cPrimary.hslHue;
        if (h < 0)
            return c;

        var t = root.toneOf(c);
        var pure = root.atTone(Qt.hsla(h, Math.max(0.55, Math.min(1, root.cPrimary.hslSaturation)), 0.55, 1), t);
        var head = root.chromaOf(pure);
        if (head <= 0.001)
            return c;

        var f = Math.min(1, k * root._tintTarget / head);
        var mx = root._mix(c, pure, f);
        return root.atTone(Qt.rgba(mx.r, mx.g, mx.b, c.a), t);
    }

    function chromaOf(c) { return Math.max(c.r, c.g, c.b) - Math.min(c.r, c.g, c.b) }

    // ступень рампы поверхности, с учётом tint в светлой теме
    function toneSurface(c, tones) { return root.tint(root.shade(c, tones + root._rampShift), root.surfaceTint) }

    function withHue(c, deg) {
        var h = c.hslHue;
        if (h < 0 || deg === 0)
            return c;

        var nh = (h + deg / 360) % 1;
        if (nh < 0)
            nh += 1;
        return root.atTone(Qt.hsla(nh, c.hslSaturation, c.hslLightness, c.a), root.toneOf(c));
    }

    // цветной контейнер: сначала полная хрома, потом спуск к нужному тону
    function containerFill(c, tone, floor) {
        var h = c.hslHue;
        if (h < 0)
            return root.atTone(c, tone);

        var hh = h % 1;
        if (hh < 0)
            hh += 1;
        var s = Math.max(c.hslSaturation, floor === undefined ? root._containerSatFloor : floor);
        return root.atTone(Qt.hsla(hh, s, 0.5, c.a), tone);
    }

    function containerInk(c) { return root.containerFill(c, root._containerInkTone) }

    function withSat(c, k) {
        var h = c.hslHue;
        if (h < 0)
            return c;

        var s = Math.max(0, Math.min(1, c.hslSaturation * k));
        return root.atTone(Qt.hsla(h, s, c.hslLightness, c.a), root.toneOf(c));
    }

    function isGreenish(c) {
        var h = c.hslHue;
        return h >= 0 && h * 360 >= 55 && h * 360 <= 175 && c.hslSaturation > 0.15;
    }

    function statusHue(deg) {
        var s = Math.max(0.35, Math.min(0.75, root.cPrimary.hslSaturation));
        return root.atTone(Qt.hsla(deg / 360, s, 0.55, 1), root.isLight ? 40 : 80);
    }

    // state layer композитом, где второй прямоугольник недопустим
    function layer(base, over, a) {
        return Qt.rgba(base.r * (1 - a) + over.r * a, base.g * (1 - a) + over.g * a, base.b * (1 - a) + over.b * a, base.a);
    }

    function _mix(a, b, t) { return Qt.rgba(a.r * (1 - t) + b.r * t, a.g * (1 - t) + b.g * t, a.b * (1 - t) + b.b * t, 1) }

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function withBlur(c) { return root.alpha(c, 1 - root.blurAmount * 0.85) }

    function toHex(c) {
        var r = Math.round(c.r * 255).toString(16).padStart(2, "0");
        var g = Math.round(c.g * 255).toString(16).padStart(2, "0");
        var b = Math.round(c.b * 255).toString(16).padStart(2, "0");
        return "#" + r + g + b;
    }

    // legacy-алиас старого кода
    function a(c, alpha) { return root.alpha(c, alpha) }
}

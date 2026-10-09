pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: t

    // ── Colors (updated from the wallpaper via matugen) ────────────────
    property color bg:        "#111319"
    property color surface:   "#1b1e26"
    property color surfaceHi: "#252a36"
    property color text:      "#e2e2ea"
    property color subtext:   "#c3c6d4"
    property color accent:    "#afc6ff"
    property color warning:   "#f3aeff"
    property color error:     "#ffb4ab"
    property color outline:   "#343a49"

    function applyScheme(o) {
        if (!o) return;
        if (o.primary) accent = o.primary;
        if (o.tertiary) warning = o.tertiary;
        if (o.error) error = o.error;
        if (o.surface) surface = o.surface;
        if (o.surface_variant) surfaceHi = o.surface_variant;
        if (o.on_surface) text = o.on_surface;
        if (o.on_surface_variant) subtext = o.on_surface_variant;
        if (o.background) bg = o.background;
    }

    // ── Metrics ────────────────────────────────────────────────────────
    readonly property int radius: 18
    readonly property int pad: 12
    readonly property int height: 34
    readonly property int spacing: 10

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13

    function a(c, alpha) { return Qt.rgba(c.r, c.g, c.b, alpha) }
}

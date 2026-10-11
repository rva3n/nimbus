.pragma library
// Nimbus → SymbolPaths aliases.
//
// Names that nimbus used with the old bundled icon font (ui/Glyphs.js) but that
// are absent from the copied Material Symbols path set (ui/SymbolPaths.js).
// Each maps to the visually closest available glyph.
var alias = {
    "brightness_6": "brightness_medium",
    "calculate": "equal",
    "device_thermostat": "thermostat",
    "north": "arrow_upward",
    "south": "arrow_downward",
    "play_circle": "play_arrow",
    "push_pin": "pin",
    "storage": "hard_drive",
    "system_update_alt": "update"
};

// Unknown names are warned about once per engine so gaps are visible at runtime
// without spamming the log every frame.
var _warned = {};

function warnUnknown(name) {
    if (_warned[name])
        return;

    _warned[name] = true;
    console.warn("[Icon] unknown symbol name, nothing drawn:", name);
}

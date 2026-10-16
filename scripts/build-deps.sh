#!/bin/sh
# build-deps.sh — собирает весь вендорный стек Oberon в build/prefix.
# Запускается установщиком (install.sh) или вручную: sh scripts/build-deps.sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD="$ROOT/build"
PREFIX="$BUILD/prefix"
JOBS=$(nproc 2>/dev/null || echo 4)

export PATH="$HOME/.cargo/bin:$PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export CARGO_TARGET_DIR="$BUILD/cargo-target"

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '!! %s\n' "$*" >&2; exit 1; }

command -v cmake >/dev/null 2>&1 || die "нет cmake — поставь: sudo pacman -S cmake ninja base-devel"
command -v cargo >/dev/null 2>&1 || die "нет cargo — поставь: sudo pacman -S rust (или rustup)"

missing=0
for d in quickshell matugen awww cava hypridle umbriel cli11 vulkan-headers hyprwayland-scanner hyprland-protocols; do
	[ -n "$(ls -A "$ROOT/third_party/$d" 2>/dev/null)" ] || missing=1
done
if [ "$missing" = 1 ]; then
	log "Инициализирую сабмодули"
	git -C "$ROOT" submodule update --init --recursive
fi

# ── build-зависимости (cmake) ─────────────────────────────────────────
log "cli11 (build-зависимость)"
cmake -GNinja -S "$ROOT/third_party/cli11" -B "$BUILD/cli11" \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
	-DCLI11_BUILD_EXAMPLES=OFF -DCLI11_BUILD_TESTS=OFF -DCLI11_BUILD_DOCS=OFF
cmake --build "$BUILD/cli11"
cmake --build "$BUILD/cli11" --target install

log "vulkan-headers (build-зависимость)"
cmake -GNinja -S "$ROOT/third_party/vulkan-headers" -B "$BUILD/vulkan-headers" \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build "$BUILD/vulkan-headers"
cmake --build "$BUILD/vulkan-headers" --target install

log "hyprwayland-scanner (build-зависимость)"
cmake -GNinja -S "$ROOT/third_party/hyprwayland-scanner" -B "$BUILD/hyprwayland-scanner" \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build "$BUILD/hyprwayland-scanner"
cmake --build "$BUILD/hyprwayland-scanner" --target install

log "hyprland-protocols (build-зависимость)"
cmake -GNinja -S "$ROOT/third_party/hyprland-protocols" -B "$BUILD/hyprland-protocols" \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build "$BUILD/hyprland-protocols"
cmake --build "$BUILD/hyprland-protocols" --target install

# ── quickshell → oberonqs ─────────────────────────────────────────────
log "quickshell (oberonqs)"
cmake -GNinja -S "$ROOT/third_party/quickshell" -B "$BUILD/quickshell" \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
	-DCMAKE_PREFIX_PATH="$PREFIX"
cmake --build "$BUILD/quickshell"
cmake --build "$BUILD/quickshell" --target install

# ── Rust: oberoncolor, oberonwall ─────────────────────────────────────
log "matugen (oberoncolor)"
cargo build --release --manifest-path "$ROOT/third_party/matugen/Cargo.toml"
install -Dm755 "$CARGO_TARGET_DIR/release/oberoncolor" "$PREFIX/bin/oberoncolor"

log "awww (oberonwall + oberonwall-daemon)"
cargo build --release --manifest-path "$ROOT/third_party/awww/Cargo.toml"
install -Dm755 "$CARGO_TARGET_DIR/release/oberonwall" "$PREFIX/bin/oberonwall"
install -Dm755 "$CARGO_TARGET_DIR/release/oberonwall-daemon" "$PREFIX/bin/oberonwall-daemon"

# ── cava → oberoncava (autotools) ─────────────────────────────────────
log "cava (oberoncava)"
if [ ! -f "$ROOT/third_party/cava/version" ]; then
	# upstream держит файл version вне git (генерируется релизным скриптом);
	# без него AC_INIT оставляет пустую версию
	printf '1.0.0\n' > "$ROOT/third_party/cava/version"
fi
if [ ! -f "$ROOT/third_party/cava/configure" ]; then
	( cd "$ROOT/third_party/cava" && autoreconf -fi )
fi
mkdir -p "$BUILD/cava"
if [ ! -f "$BUILD/cava/Makefile" ]; then
	( cd "$BUILD/cava" && "$ROOT/third_party/cava/configure" --prefix="$PREFIX" )
fi
make -C "$BUILD/cava" -j"$JOBS"
install -Dm755 "$BUILD/cava/oberoncava" "$PREFIX/bin/oberoncava"

# ── hypridle → oberonidle ─────────────────────────────────────────────
log "hypridle (oberonidle)"
cmake -GNinja -S "$ROOT/third_party/hypridle" -B "$BUILD/hypridle" \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
	-DCMAKE_PREFIX_PATH="$PREFIX"
cmake --build "$BUILD/hypridle"
cmake --build "$BUILD/hypridle" --target install

# ── итог ──────────────────────────────────────────────────────────────
log "Готово — бинарники в $PREFIX/bin"
for b in oberonqs oberoncolor oberonwall oberonwall-daemon oberoncava oberonidle; do
	if [ -x "$PREFIX/bin/$b" ]; then
		printf '  %-18s %s\n' "$b" "$(timeout 3 "$PREFIX/bin/$b" --version </dev/null 2>&1 | head -n1 || true)"
	else
		printf '  %-18s ОТСУТСТВУЕТ\n' "$b"
	fi
done

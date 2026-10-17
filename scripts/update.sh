#!/bin/sh
# update.sh — обновление Oberon: основной репозиторий, сабмодули и пересборка.
#
#   update.sh --check    — fetch и подсчёт отставания (машиночитаемый вывод)
#   update.sh --apply    — подтянуть обновления и пересобрать стек
#   update.sh --restart  — перезапустить шелл
#
# Вывод --check (по строкам):  MAIN <отставание> <hash>
#                              SUB <имя> <отставание> <hash>
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STATE="$HOME/.local/state/oberon"
MODE="${1:---check}"

sub_list() {
	git -C "$ROOT" config -f "$ROOT/.gitmodules" --get-regexp '^submodule\..*\.branch$' 2>/dev/null || true
}

check() {
	br=$(git -C "$ROOT" symbolic-ref -q --short HEAD || echo main)
	git -C "$ROOT" fetch --quiet origin
	printf 'MAIN %s %s\n' "$(git -C "$ROOT" rev-list --count "HEAD..origin/$br")" "$(git -C "$ROOT" rev-parse --short HEAD)"
	sub_list | while read -r key branch; do
		path=${key#submodule.}; path=${path%.branch}
		name=${path#third_party/}
		dir="$ROOT/$path"
		[ -e "$dir/.git" ] || continue
		git -C "$dir" fetch --quiet origin
		printf 'SUB %s %s %s\n' "$name" "$(git -C "$dir" rev-list --count "HEAD..origin/$branch")" "$(git -C "$dir" rev-parse --short HEAD)"
	done
}

case "$MODE" in
--check)
	check
	;;
--apply)
	# убираем «дрейф» gitlink-ов от прошлых обновлений
	git -C "$ROOT" checkout -- third_party 2>/dev/null || true
	# блокируем только реальные правки отслеживаемых файлов; грязные сабмодули
	# (артефакты сборки) и untracked-файлы обновлению не мешают
	CHANGES=$(git -C "$ROOT" status --porcelain --untracked-files=no --ignore-submodules=dirty | grep -vE '^ M third_party/' | head -n1)
	if [ -n "$CHANGES" ]; then
		echo "!! есть незакоммиченные изменения: $CHANGES — обновление отменено"
		exit 1
	fi
	OUT=$(check)
	printf '%s\n' "$OUT"
	TOTAL=$(printf '%s\n' "$OUT" | awk '{s+=($1=="MAIN"?$2:$3)} END{print s+0}')
	SUBBEFORE=$(git -C "$ROOT" submodule status | md5sum)
	if [ "$TOTAL" = 0 ]; then
		echo "==> Обновлений нет — всё актуально"
	else
		echo "==> Основной репозиторий"
		git -C "$ROOT" pull --ff-only
	fi
	echo "==> Сабмодули"
	git -C "$ROOT" submodule update --init
	sub_list | while read -r key branch; do
		path=${key#submodule.}; path=${path%.branch}
		git -C "$ROOT" submodule update --remote -- "$path" || { echo "!! не удалось обновить $path"; exit 1; }
	done
	SUBAFTER=$(git -C "$ROOT" submodule status | md5sum)
	if [ "$TOTAL" != 0 ] || [ "$SUBBEFORE" != "$SUBAFTER" ]; then
		echo "==> Пересборка (инкрементально, обычно до пары минут)"
		sh "$ROOT/scripts/build-deps.sh" </dev/null
	else
		echo "==> Изменений в компонентах нет — пересборка не нужна"
	fi
	mkdir -p "$STATE"
	{
		printf '{\n  "date": "%s",\n  "main": "%s"' "$(date -Is)" "$(git -C "$ROOT" rev-parse --short HEAD)"
		sub_list | while read -r key branch; do
			path=${key#submodule.}; path=${path%.branch}
			name=${path#third_party/}
			printf ',\n  "%s": "%s"' "$name" "$(git -C "$ROOT/$path" rev-parse --short HEAD 2>/dev/null || echo '?')"
		done
		printf '\n}\n'
	} > "$STATE/versions.json"
	echo "OK"
	;;
--restart)
	exec sh "$ROOT/scripts/restart.sh"
	;;
*)
	echo "usage: update.sh [--check|--apply|--restart]" >&2
	exit 2
	;;
esac

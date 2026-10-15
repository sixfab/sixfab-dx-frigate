#!/usr/bin/env bash
# Shared helpers for install-frigate.sh and the project install.sh scripts. Source it, do not run it.
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${PYTHON:-python3}"
RELEASE_REPO="${RELEASE_REPO:-sixfab/sixfab-dx-frigate}"
# Shared Python environment that the sixfab-dx package installs (dx_engine, numpy, ...).
SIXFAB_VENV="${SIXFAB_VENV:-/opt/sixfab-dx/venv}"

die() { echo "ERROR: $*" >&2; exit 1; }
say() { echo "$*"; }

# ask PROMPT [DEFAULT] -> answer on stdout. The prompt goes to stderr so it is
# visible inside $(...). Reads the terminal (works behind curl | bash); with no
# terminal it returns DEFAULT.
ask() {
    local prompt="$1" default="${2:-}" reply=""
    printf '%s' "$prompt" >&2
    if [ "${ASK_FROM_STDIN:-0}" = "1" ]; then
        IFS= read -r reply || reply=""
    elif [ "${SIXFAB_NO_TTY:-0}" != "1" ] && ( : </dev/tty ) 2>/dev/null; then
        IFS= read -r reply </dev/tty || reply=""
    fi
    [ -t 2 ] || printf '\n' >&2
    printf '%s' "${reply:-$default}"
}

confirm() {
    [ "${ASSUME_YES:-0}" = "1" ] && return 0
    case "$(ask "$1 [y/N] ")" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

run() {  # DRY_RUN=1 prints instead of executing
    if [ "${DRY_RUN:-0}" = "1" ]; then echo "DRY: $*"; else "$@"; fi
}

models_tag() { sed -n 's/^# TAG:[[:space:]]*//p' "$1" | head -1; }

# name <TAB> path <TAB> sha256 <TAB> optional-or-empty
models_rows() {
    grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$1" \
        | awk '{printf "%s\t%s\t%s\t%s\n", $1, $2, $3, $4}'
}

release_url() {
    local base="${RELEASE_BASE_URL:-https://github.com/${RELEASE_REPO}/releases/download}"
    echo "$base/$1/$2"
}

# fetch_assets APP_DIR WITH_OPTIONAL(0|1): download every asset of APP_DIR/models.txt
# to APP_DIR/<path>, verifying SHA-256. Existing files with a matching SHA are kept.
fetch_assets() {
    local app="$1" with_optional="${2:-0}" tag name path sha opt dest got
    tag="$(models_tag "$app/models.txt")"
    [ -n "$tag" ] || die "$app/models.txt has no '# TAG:' line"
    while IFS=$'\t' read -r name path sha opt; do
        if [ "$opt" = "optional" ] && [ "$with_optional" != "1" ]; then continue; fi
        dest="$app/$path"
        if [ -f "$dest" ] && [ "$(sha256sum "$dest" | cut -d' ' -f1)" = "$sha" ]; then
            say "   have $path"; continue
        fi
        if [ "${DRY_RUN:-0}" = "1" ]; then echo "DRY: download $(release_url "$tag" "$name") -> $path"; continue; fi
        mkdir -p "$(dirname "$dest")"
        say "   downloading $name ($tag)"
        curl -fL --progress-bar -o "$dest.part" "$(release_url "$tag" "$name")" \
            || { rm -f "$dest.part"; die "could not download $name from release $tag"; }
        got="$(sha256sum "$dest.part" | cut -d' ' -f1)"
        if [ "$got" != "$sha" ]; then
            rm -f "$dest.part"
            die "SHA-256 mismatch for $name (expected $sha, got $got). The release may have changed."
        fi
        mv "$dest.part" "$dest"
    done < <(models_rows "$app/models.txt")
}

require_sixfab_venv() {
    [ -x "$SIXFAB_VENV/bin/python" ]         || die "Python environment not found at $SIXFAB_VENV. Install the sixfab-dx package first (see the README in the repo root), or set SIXFAB_VENV."
}

parse_flags() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --rtsp-url)    RTSP_URL="$2"; shift 2 ;;
            --camera-name) CAMERA_NAME="$2"; shift 2 ;;
            --broker)      BROKER="$2"; shift 2 ;;
            --container)   CONTAINER="$2"; shift 2 ;;
            --config-dir)  CONFIG_DIR="$2"; shift 2 ;;
            --yes)         ASSUME_YES=1; shift ;;
            --dry-run)     DRY_RUN=1; shift ;;
            -h|--help)     echo "Flags: --rtsp-url URL --camera-name NAME --broker HOST --container NAME --config-dir DIR --yes --dry-run"; exit 0 ;;
            *) die "unknown flag '$1' (try --help)" ;;
        esac
    done
}

discover_frigate() {
    CONTAINER="${CONTAINER:-frigate}"
    command -v docker >/dev/null || die "Frigate not found: docker is not installed. Run toolkit/install-frigate.sh first."
    docker inspect "$CONTAINER" >/dev/null 2>&1 \
        || die "Frigate container '$CONTAINER' not found. Run toolkit/install-frigate.sh first, or pass --container NAME."
    "$PYTHON" -c 'import yaml' 2>/dev/null || die "PyYAML is missing. Install it with: sudo apt install python3-yaml"
    if [ -z "${CONFIG_DIR:-}" ]; then
        CONFIG_DIR="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/config"}}{{.Source}}{{end}}{{end}}' "$CONTAINER")"
        [ -n "$CONFIG_DIR" ] || die "container '$CONTAINER' has no /config mount. Pass --config-dir DIR."
    fi
    [ -f "$CONFIG_DIR/config.yaml" ] || die "$CONFIG_DIR/config.yaml not found."
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"' EXIT
}

check_stream() {
    ffprobe -v error -rtsp_transport tcp -show_entries stream=codec_name -of default=noprint_wrappers=1 "$1" >/dev/null 2>&1 \
        || die "cannot read $1 - is the stream running and reachable from this Pi?"
}

# name_taken NAME: already a Frigate camera, or already entered in this run
name_taken() {
    local n="$1" c
    for c in "${CAM_NAMES[@]:-}"; do [ "$c" = "$n" ] && return 0; done
    grep -qx -- "$n" <<<"${EXISTING_CAMERAS:-}"
}

next_free_name() {
    local i=1
    while name_taken "$1$i"; do i=$((i + 1)); done
    echo "$1$i"
}

# collect_cameras PREFIX -> CAM_NAMES / CAM_URLS
collect_cameras() {
    local prefix="$1" n i name url default c
    CAM_NAMES=(); CAM_URLS=()
    EXISTING_CAMERAS="$("$PYTHON" "$LIB/frigate_cfg.py" names "$CONFIG_DIR/config.yaml")"
    if [ -n "${RTSP_URL:-}" ]; then
        [[ "$RTSP_URL" == rtsp://* ]] || die "RTSP URL must start with rtsp:// (got '$RTSP_URL')"
        check_stream "$RTSP_URL"
        CAM_NAMES+=("${CAMERA_NAME:-$(next_free_name "$prefix")}"); CAM_URLS+=("$RTSP_URL")
        return 0
    fi
    n="$(ask 'How many cameras do you want to add? [1] ' 1)"
    [[ "$n" =~ ^[1-9][0-9]*$ ]] || die "the camera count must be a positive number (got '$n')"
    for ((i = 1; i <= n; i++)); do
        default="$(next_free_name "$prefix")"
        name="$(ask "Camera $i name [$default]: " "$default")"
        for c in "${CAM_NAMES[@]:-}"; do
            [ "$c" != "$name" ] || die "camera name '$name' was entered more than once"
        done
        if grep -qx -- "$name" <<<"$EXISTING_CAMERAS"; then
            existing_scene="$("$PYTHON" "$LIB/frigate_cfg.py" camera-scene "$CONFIG_DIR/config.yaml" "$name")"
            if [ -n "$existing_scene" ] && [ "$existing_scene" != "${SCENE:-}" ]; then
                die "camera '$name' already exists for another app (scene '$existing_scene'); pick a different name"
            fi
            confirm "Camera '$name' already exists in Frigate; its URL and settings would be replaced. Replace it?" \
                || die "camera '$name' already exists; pick another name"
        fi
        url="$(ask "Camera $i RTSP URL (rtsp://...): ")"
        [[ "$url" == rtsp://* ]] || die "RTSP URL must start with rtsp:// (got '$url'). Pass --rtsp-url when there is no terminal."
        check_stream "$url"
        CAM_NAMES+=("$name"); CAM_URLS+=("$url")
    done
}

# Validates, clones the template per camera, backs up, then merges.
merge_fragment() {
    local fragment="$1" scene="$2" cfg="$CONFIG_DIR/config.yaml" pairs=() i
    for i in "${!CAM_NAMES[@]}"; do pairs+=("${CAM_NAMES[$i]}=${CAM_URLS[$i]}"); done
    "$PYTHON" "$LIB/frigate_cfg.py" check-scene "$cfg" "$fragment" || exit 1
    "$PYTHON" "$LIB/frigate_cfg.py" check-names "$cfg" "$scene" "${CAM_NAMES[@]}" || exit 1
    "$PYTHON" "$LIB/frigate_cfg.py" clone "$fragment" "$WORK/fragment.yaml" "${pairs[@]}" || exit 1
    if [ -n "${FRAGMENT_HOOK:-}" ]; then "$FRAGMENT_HOOK" "$WORK/fragment.yaml" || exit 1; fi
    [ "${DRY_RUN:-0}" = "1" ] || cp "$cfg" "$cfg.bak-$(date +%Y%m%d%H%M%S)"
    "$PYTHON" "$LIB/merge_config.py" "$cfg" "$WORK/fragment.yaml" "$WORK/merged.yaml" >/dev/null || exit 1
    if [ "${DRY_RUN:-0}" = "1" ]; then
        cp "$WORK/merged.yaml" "$cfg.dryrun"; say "   dry run: merged config written to $cfg.dryrun"
    else
        cp "$WORK/merged.yaml" "$cfg"
    fi
}

broker_for_listener() {
    if [ -n "${BROKER:-}" ]; then echo "$BROKER"; return; fi
    local b; b="$("$PYTHON" "$LIB/frigate_cfg.py" broker "$CONFIG_DIR/config.yaml")"
    echo "${b:-127.0.0.1}"
}

write_cameras_file() {
    "$PYTHON" "$LIB/frigate_cfg.py" cameras "$CONFIG_DIR/config.yaml" "$2" > "$1"
}

install_listener() {
    local app="$1" script="$2" desc="$3" scene="$4" dest="$HOME/sixfab-apps/$1" file broker
    file="$(basename "$script")"; broker="$(broker_for_listener)"
    if [ "${DRY_RUN:-0}" = "1" ]; then
        say "DRY: install listener $app in $dest (broker $broker, systemd user unit $app-automation.service)"
        return 0
    fi
    mkdir -p "$dest" "$HOME/.config/systemd/user"
    sed -E "s|^BROKER = \"[^\"]*\".*|BROKER = \"$broker\"|" "$script" > "$dest/$file"
    cp "$LIB/camera_filter.py" "$dest/camera_filter.py"
    write_cameras_file "$dest/cameras.txt" "$scene"
    if [ "${SIXFAB_TEST:-0}" != "1" ]; then
        require_sixfab_venv
        "$SIXFAB_VENV/bin/python" -c 'import paho.mqtt.client' 2>/dev/null             || "$SIXFAB_VENV/bin/python" -m pip install --quiet paho-mqtt
    fi
    cat > "$HOME/.config/systemd/user/$app-automation.service" <<UNIT
[Unit]
Description=$desc
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$dest
ExecStart=$SIXFAB_VENV/bin/python $dest/$file
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
UNIT
    run systemctl --user daemon-reload
    run systemctl --user enable --now "$app-automation.service"
    run systemctl --user restart "$app-automation.service"
    say "   For auto-start after a reboot, run once:  sudo loginctl enable-linger ${USER:-$(id -un)}"
}

wait_for_frigate() {  # Frigate needs a while to load the DEEPX models after a restart
    [ "${SIXFAB_TEST:-0}" = "1" ] && return 0
    [ "${DRY_RUN:-0}" = "1" ] && return 0
    local i
    for i in $(seq 1 30); do
        docker exec "$CONTAINER" curl -sf http://localhost:5000/api/version >/dev/null 2>&1 && return 0
        sleep 2
    done
    say "   warning: Frigate did not answer within 60 seconds"
    return 1
}

restart_frigate() {
    if confirm "Restart the Frigate container '$CONTAINER' now so it loads the new config?"; then
        run docker restart "$CONTAINER"
        [ "${SIXFAB_TEST:-0}" = "1" ] || sleep 20
        local n
        for n in "${CAM_NAMES[@]:-}"; do
            [ -n "$n" ] || continue
            run docker exec "$CONTAINER" curl -s -X PUT "http://localhost:5000/api/camera/$n/set/enabled" \
                -H 'Content-Type: application/json' -d '{"value":"ON"}' >/dev/null
        done
    else
        say "Frigate was NOT restarted. Run 'docker restart $CONTAINER' when you are ready."
    fi
}

# camera_menu SCENE APP -> MODE=add|remove|quit
camera_menu() {
    local scene="$1" app="$2" existing choice
    MODE=add
    existing="$("$PYTHON" "$LIB/frigate_cfg.py" cameras "$CONFIG_DIR/config.yaml" "$scene" | tr '\n' ' ')"
    [ -n "${existing// /}" ] || return 0
    [ -z "${RTSP_URL:-}" ] || return 0
    [ "${ASSUME_YES:-0}" != "1" ] || return 0
    say "$app already has cameras: $existing"
    choice="$(ask '  1) add cameras  2) remove a camera  3) quit  [1]: ' 1)"
    case "$choice" in 2) MODE=remove ;; 3) MODE=quit ;; *) MODE=add ;; esac
}

remove_camera_flow() {
    local scene="$1" app="$2" name
    name="$(ask 'Camera name to remove: ')"
    [ -n "$name" ] || die "no camera name given"
    "$PYTHON" "$LIB/frigate_cfg.py" cameras "$CONFIG_DIR/config.yaml" "$scene" | grep -qx -- "$name"         || die "'$name' is not one of $app's cameras (scene $scene); nothing was removed"
    if [ "${DRY_RUN:-0}" = "1" ]; then say "DRY: would remove camera '$name' from config.yaml"; return 0; fi
    "$PYTHON" "$LIB/frigate_cfg.py" remove "$CONFIG_DIR/config.yaml" "$WORK/removed.yaml" "$name" || exit 1
    cp "$CONFIG_DIR/config.yaml" "$CONFIG_DIR/config.yaml.bak-$(date +%Y%m%d%H%M%S)"
    cp "$WORK/removed.yaml" "$CONFIG_DIR/config.yaml"
    [ ! -f "$HOME/sixfab-apps/$app/cameras.txt" ] || write_cameras_file "$HOME/sixfab-apps/$app/cameras.txt" "$scene"
    CAM_NAMES=()
    restart_frigate
}

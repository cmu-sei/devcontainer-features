#!/bin/bash
# Start or stop the on-demand VNC/noVNC desktop for headed browsers.
# Usage: playwright-desktop start|stop|status
set -uo pipefail

INIT=/usr/local/share/desktop-init.sh
OPTIONS=/usr/local/share/org-features/playwright/options.env
PASSWORD=$(sed -n 's/^DESKTOPPASSWORD=//p' "$OPTIONS" 2>/dev/null | tail -n 1)

is_running() { pgrep -x Xtigervnc >/dev/null 2>&1; }

where() {
    echo "  noVNC: http://localhost:6080 (forward port 6080)"
    echo "  VNC:   localhost:5901"
    [ "$PASSWORD" = noPassword ] || echo "  Password: ${PASSWORD:-vscode}"
    echo "  Headed browsers use DISPLAY=${DISPLAY:-:1}"
}

case "${1:-}" in
    start)
        if is_running; then
            echo "Desktop is already running."
            where
            exit 0
        fi
        [ -x "$INIT" ] || { echo "Desktop is not installed; set the playwright feature's desktop option." >&2; exit 1; }
        echo "Starting desktop (TigerVNC, noVNC, fluxbox)..."
        DISPLAY="${DISPLAY:-:1}" nohup bash "$INIT" >/tmp/playwright-desktop.log 2>&1 &
        for _ in $(seq 1 15); do
            if is_running; then
                echo "Desktop started."
                where
                exit 0
            fi
            sleep 1
        done
        echo "Desktop may not have started; see /tmp/playwright-desktop.log" >&2
        exit 1
        ;;
    stop)
        is_running || { echo "Desktop is not running."; exit 0; }
        pkill -x Xtigervnc
        pkill -f 'novnc_proxy|launch.sh.*novnc'
        pkill -x fluxbox
        sleep 1
        ! is_running || pkill -9 -x Xtigervnc
        echo "Desktop stopped."
        ;;
    status)
        if is_running; then
            echo "Desktop is running."
            where
        else
            echo "Desktop is stopped. Start it with: playwright-desktop start"
        fi
        ;;
    *)
        echo "Usage: playwright-desktop {start|stop|status}" >&2
        exit 1
        ;;
esac

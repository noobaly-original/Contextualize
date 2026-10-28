#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$PROJECT_DIR/build/ContextMenuStudio.app"
APP_DEST="/Applications/ContextMenuStudio.app"

if [[ ! -d "$APP_SOURCE" ]]; then
    "$PROJECT_DIR/build.sh"
fi

echo "==> Stopping previous ContextMenu Studio & FinderSync instances..."
killall ContextMenuStudio ContextMenuFinderSync 2>/dev/null || true

echo "==> Installing ContextMenuStudio.app to /Applications..."
if rm -rf "$APP_DEST" 2>/dev/null && cp -R "$APP_SOURCE" "$APP_DEST" 2>/dev/null; then
    INSTALLED_APP="$APP_DEST"
    touch "$INSTALLED_APP"
    echo "==> Installed to $INSTALLED_APP"
else
    INSTALLED_APP="$APP_SOURCE"
    touch "$INSTALLED_APP"
    echo "==> Using bundle at $INSTALLED_APP"
fi

echo "==> Registering and enabling Finder Sync Extension..."
/usr/bin/pluginkit -a "$INSTALLED_APP/Contents/PlugIns/ContextMenuFinderSync.appex" || true
/usr/bin/pluginkit -e use -i com.contextmenustudio.app.FinderSync || true

echo "==> Launching ContextMenu Studio..."
open "$INSTALLED_APP"

#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/ContextMenuStudio.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_TEMPLATES="$APP_RESOURCES/Templates"
APP_PLUGINS="$APP_CONTENTS/PlugIns"

EXT_BUNDLE="$APP_PLUGINS/ContextMenuFinderSync.appex"
EXT_CONTENTS="$EXT_BUNDLE/Contents"
EXT_MACOS="$EXT_CONTENTS/MacOS"
EXT_RESOURCES="$EXT_CONTENTS/Resources"

MODULE_CACHE="/tmp/clang-module-cache"
mkdir -p "$MODULE_CACHE"

echo "==> Preparing bundle directories..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_TEMPLATES" "$APP_PLUGINS" "$EXT_MACOS" "$EXT_RESOURCES"

cp "$PROJECT_DIR/Resources/HostApp-Info.plist" "$APP_CONTENTS/Info.plist"
cp "$PROJECT_DIR/Resources/FinderSync-Info.plist" "$EXT_CONTENTS/Info.plist"

echo "==> Generating default AppIcon.icns..."
ICONSET_DIR="/tmp/ContextMenuStudio.iconset"
ICON_GENERATOR="/tmp/generate_app_icon_bin"
swiftc -module-cache-path "$MODULE_CACHE" -parse-as-library -framework Cocoa "$PROJECT_DIR/scripts/generate_app_icon.swift" -o "$ICON_GENERATOR"
"$ICON_GENERATOR" "$ICONSET_DIR"
/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$APP_RESOURCES/AppIcon.icns"
cp "$APP_RESOURCES/AppIcon.icns" "$EXT_RESOURCES/AppIcon.icns"
rm -rf "$ICONSET_DIR" "$ICON_GENERATOR"

echo "==> Bundling valid blank iWork & Office document templates..."
if [[ -f "/Applications/Pages Creator Studio.app/Contents/SharedSupport/Templates/00B_Blank_Portrait/ISO.template" ]]; then
    cp "/Applications/Pages Creator Studio.app/Contents/SharedSupport/Templates/00B_Blank_Portrait/ISO.template" "$APP_TEMPLATES/Blank.pages"
elif [[ -f "/Applications/Pages.app/Contents/SharedSupport/Templates/00B_Blank_Portrait/ISO.template" ]]; then
    cp "/Applications/Pages.app/Contents/SharedSupport/Templates/00B_Blank_Portrait/ISO.template" "$APP_TEMPLATES/Blank.pages"
fi

if [[ -f "/Applications/Keynote Creator Studio.app/Contents/SharedSupport/Templates/21_BasicWhite/Wide.kth" ]]; then
    cp "/Applications/Keynote Creator Studio.app/Contents/SharedSupport/Templates/21_BasicWhite/Wide.kth" "$APP_TEMPLATES/Blank.key"
elif [[ -f "/Applications/Keynote.app/Contents/SharedSupport/Templates/21_BasicWhite/Wide.kth" ]]; then
    cp "/Applications/Keynote.app/Contents/SharedSupport/Templates/21_BasicWhite/Wide.kth" "$APP_TEMPLATES/Blank.key"
fi

if [[ -f "/Applications/Numbers Creator Studio.app/Contents/SharedSupport/Templates/Blank/Traditional.nmbtemplate" ]]; then
    cp "/Applications/Numbers Creator Studio.app/Contents/SharedSupport/Templates/Blank/Traditional.nmbtemplate" "$APP_TEMPLATES/Blank.numbers"
elif [[ -f "/Applications/Numbers.app/Contents/SharedSupport/Templates/Blank/Traditional.nmbtemplate" ]]; then
    cp "/Applications/Numbers.app/Contents/SharedSupport/Templates/Blank/Traditional.nmbtemplate" "$APP_TEMPLATES/Blank.numbers"
fi

# Generate a valid minimal OpenXML .docx file
python3 - "$APP_TEMPLATES/Blank.docx" << 'PYEOF'
import sys, zipfile

docx_path = sys.argv[1]

content_types = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>"""

rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>"""

document_xml = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t></w:t></w:r></w:p>
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>"""

with zipfile.ZipFile(docx_path, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.writestr("[Content_Types].xml", content_types)
    zf.writestr("_rels/.rels", rels)
    zf.writestr("word/document.xml", document_xml)
PYEOF

echo "==> Compiling Finder Sync Extension (ContextMenuFinderSync.appex)..."
swiftc \
    -module-cache-path "$MODULE_CACHE" \
    -O \
    -application-extension \
    -Xlinker -e -Xlinker _NSExtensionMain \
    -framework Cocoa \
    -framework FinderSync \
    "$PROJECT_DIR/Sources/Shared/MenuConfiguration.swift" \
    "$PROJECT_DIR/Sources/Shared/ActionExecutor.swift" \
    "$PROJECT_DIR/Sources/FinderSyncExtension/FinderSync.swift" \
    -o "$EXT_MACOS/ContextMenuFinderSync"

echo "==> Compiling Host Menu Bar App (ContextMenuStudio.app)..."
swiftc \
    -module-cache-path "$MODULE_CACHE" \
    -O \
    -parse-as-library \
    -framework Cocoa \
    -framework SwiftUI \
    -framework UniformTypeIdentifiers \
    "$PROJECT_DIR/Sources/Shared/MenuConfiguration.swift" \
    "$PROJECT_DIR/Sources/Shared/ActionExecutor.swift" \
    "$PROJECT_DIR/Sources/HostApp/ThirdPartyMenuManager.swift" \
    "$PROJECT_DIR/Sources/HostApp/SettingsWindowView.swift" \
    "$PROJECT_DIR/Sources/HostApp/AppMain.swift" \
    -o "$APP_MACOS/ContextMenuStudio"

echo "==> Signing bundles..."
codesign --force --sign - --entitlements "$PROJECT_DIR/Resources/FinderSync.entitlements" "$EXT_BUNDLE"
codesign --force --sign - "$APP_BUNDLE"

echo "==> Build succeeded: $APP_BUNDLE"

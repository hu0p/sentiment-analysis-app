#!/bin/bash

# Build script for Sentiment Analyzer distribution
# This script creates a properly signed and packaged app for distribution

set -e

echo "🚀 Building Sentiment Analyzer for distribution..."

# Configuration
PROJECT_NAME="SentimentAnalysisApp"
SCHEME_NAME="SentimentAnalysisApp"
ARCHIVE_NAME="SentimentAnalysisApp.xcarchive"
EXPORT_PATH="./dist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
  print_error "Please run this script from the project root directory"
  exit 1
fi

# Function to check available certificates
check_certificates() {
  print_info "Checking available certificates..."

  # Check for Developer ID Application certificate
  if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    print_status "Developer ID Application certificate found"
    return 0
  fi

  # Check for Apple Development certificate
  if security find-identity -v -p codesigning | grep -q "Apple Development"; then
    print_status "Apple Development certificate found"
    return 1
  fi

  print_error "No suitable certificates found"
  return 2
}

# Determine export options based on available certificates
determine_export_options() {
  check_certificates
  cert_status=$?

  case $cert_status in
  0)
    # Developer ID certificate available
    EXPORT_OPTIONS="exportOptions-developer-id.plist"
    print_status "Using Developer ID distribution (direct download)"
    ;;
  1)
    # Only Apple Development certificate available
    EXPORT_OPTIONS="exportOptions.plist"
    print_warning "Using App Store distribution (requires App Store submission)"
    print_warning "For direct distribution, you need a Developer ID Application certificate"
    ;;
  2)
    print_error "No certificates found. Please set up code signing in Xcode first."
    exit 1
    ;;
  esac
}

# Clean previous builds
print_status "Cleaning previous builds..."
xcodebuild clean -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -configuration Release

# Build and archive
print_status "Building and archiving the app..."
xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_NAME}" \
  -configuration Release \
  -archivePath "${ARCHIVE_NAME}" \
  -allowProvisioningUpdates

# Check if archive was created successfully
if [ ! -d "${ARCHIVE_NAME}" ]; then
  print_error "Archive creation failed"
  exit 1
fi

print_status "Archive created successfully at ${ARCHIVE_NAME}"

# Create export directory
mkdir -p "${EXPORT_PATH}"

# Determine export options
determine_export_options

# Export for distribution
print_status "Exporting for distribution using ${EXPORT_OPTIONS}..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_NAME}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}" \
  -allowProvisioningUpdates

# Check if export was successful
if [ ! -d "${EXPORT_PATH}/Sentiment Analyzer.app" ]; then
  print_error "Export failed"
  print_error "This might be due to missing certificates or incorrect export options"
  print_info "Available export options:"
  print_info "  - exportOptions.plist (App Store distribution)"
  print_info "  - exportOptions-developer-id.plist (Direct distribution - requires Developer ID certificate)"
  print_info "  - exportOptions-adhoc.plist (Testing distribution)"
  exit 1
fi

print_status "Export completed successfully"

# --- Extract version from built app's Info.plist (Xcode authoritative source) ---
INFO_PLIST_PATH="${EXPORT_PATH}/Sentiment Analyzer.app/Contents/Info.plist"
if [ ! -f "$INFO_PLIST_PATH" ]; then
  print_error "Info.plist not found at $INFO_PLIST_PATH. Cannot determine version."
  exit 1
fi
VERSION=$(plutil -extract CFBundleShortVersionString xml1 -o - "$INFO_PLIST_PATH" | grep -oE '<string>.*</string>' | sed -E 's/<\/?string>//g' | xargs)
if [ -z "$VERSION" ]; then
  print_error "Could not extract version from Info.plist. Aborting."
  exit 1
fi
print_status "App version determined from Info.plist: $VERSION"

# Set release paths now that version is known
RELEASES_DIR="releases/$VERSION"
DEST_DMG_PATH="$RELEASES_DIR/SentimentAnalyzer.dmg"

# Create DMG (optional - requires create-dmg)
if command -v create-dmg &>/dev/null; then
  print_status "Creating DMG installer..."
  # Remove old DMG if it exists to prevent hdiutil errors
  rm -f "$DEST_DMG_PATH"
  mkdir -p "$RELEASES_DIR"
  create-dmg \
    --volname "Sentiment Analyzer" \
    --window-pos 200 120 \
    --window-size 600 300 \
    --icon-size 100 \
    --icon "Sentiment Analyzer.app" 175 120 \
    --hide-extension "Sentiment Analyzer.app" \
    --app-drop-link 425 120 \
    --background "dmg_background.png" \
    "$DEST_DMG_PATH" \
    "${EXPORT_PATH}/Sentiment Analyzer.app"

  if [ -f "$DEST_DMG_PATH" ]; then
    print_status "DMG created successfully: $DEST_DMG_PATH"
    # Sparkle signing and appcast update logic follows...

    # --- Sparkle: Sign the DMG and update appcast.xml ---
    SPARKLE_TOOLS_PATH="/Users/lhoup/Library/Developer/Xcode/DerivedData/SentimentAnalysisApp-gawezplxrvumjsdcmfrvigrzfaew/SourcePackages/artifacts/sparkle/Sparkle/bin"
    SPARKLE_PRIVKEY="$HOME/.sparkle/ed25519.priv.pem" # Keep your private key OUTSIDE the repo
    APPCAST="releases/appcast.xml"
    DMG_FILE="$DEST_DMG_PATH"
    PUBDATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")
    LENGTH=$(stat -f%z "$DMG_FILE")
    # Update appcast.xml enclosure URL
    DMG_URL="https://hu0p.github.io/SentimentAnalysisApp/$DEST_DMG_PATH"

    if [ ! -f "$SPARKLE_PRIVKEY" ]; then
      print_error "Sparkle private key not found at $SPARKLE_PRIVKEY. Skipping update signing."
    elif [ ! -f "$APPCAST" ]; then
      print_error "Appcast file not found at $APPCAST. Skipping appcast update."
    else
      print_status "Signing DMG with Sparkle..."
      SPARKLE_SIGNATURE=$($SPARKLE_TOOLS_PATH/sign_update --ed-key-file "$SPARKLE_PRIVKEY" "$DMG_FILE" | sed -n 's/.*sparkle:edSignature=\"\([^"]*\)\".*/\1/p')
      print_status "Signature: $SPARKLE_SIGNATURE"

      # Remove any existing item for this version
      if command -v xmlstarlet &>/dev/null; then
        xmlstarlet ed -L -d "//item[enclosure/@sparkle:version='$VERSION']" "$APPCAST"

        # Remove any empty <item/> or <enclosure/> tags (cleanup from previous runs or template)
        xmlstarlet ed -L -d "//item[not(node())]" "$APPCAST"
        xmlstarlet ed -L -d "//enclosure[not(@url)]" "$APPCAST"

        # Insert new <item> at the top of <channel> with all required children and attributes
        xmlstarlet ed -L \
          -s "/rss/channel" -t elem -n "item" -v "" \
          -s "/rss/channel/item[1]" -t elem -n "title" -v "Version $VERSION" \
          -s "/rss/channel/item[1]" -t elem -n "pubDate" -v "$PUBDATE" \
          -s "/rss/channel/item[1]" -t elem -n "enclosure" -v "" \
          -i "/rss/channel/item[1]/enclosure" -t attr -n "url" -v "$DMG_URL" \
          -i "/rss/channel/item[1]/enclosure" -t attr -n "sparkle:version" -v "$VERSION" \
          -i "/rss/channel/item[1]/enclosure" -t attr -n "length" -v "$LENGTH" \
          -i "/rss/channel/item[1]/enclosure" -t attr -n "type" -v "application/x-apple-diskimage" \
          -i "/rss/channel/item[1]/enclosure" -t attr -n "sparkle:edSignature" -v "$SPARKLE_SIGNATURE" \
          "$APPCAST"
        print_status "Appcast updated with new release item."
      else
        print_warning "xmlstarlet not found. Please install with: brew install xmlstarlet"
      fi
    fi
  else
    print_warning "DMG creation failed (create-dmg not found or failed)"
  fi
else
  print_warning "create-dmg not found. Skipping DMG creation."
  print_warning "Install create-dmg with: brew install create-dmg"
fi

# Summary
echo ""
print_status "Build completed successfully!"
echo ""
echo "📦 Distribution files:"
echo "   App: ${EXPORT_PATH}/Sentiment Analyzer.app"
if [ -f "$DEST_DMG_PATH" ]; then
  echo "   DMG: $DEST_DMG_PATH"
fi
echo ""
echo "🔍 Next steps:"
echo "   1. Test the app on a clean system"
echo "   2. Verify all features work correctly"
echo "   3. Upload to your distribution platform"
echo ""

# Clean up archive
print_status "Cleaning up archive..."
rm -rf "${ARCHIVE_NAME}"

# Remove the dist folder if it exists
if [ -d "${EXPORT_PATH}" ]; then
  print_status "Removing temporary export folder: ${EXPORT_PATH}"
  rm -rf "${EXPORT_PATH}"
fi

print_status "Build process completed! 🎉"

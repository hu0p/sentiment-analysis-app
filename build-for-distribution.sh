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

# Create DMG (optional - requires create-dmg)
if command -v create-dmg &>/dev/null; then
  print_status "Creating DMG installer..."
  create-dmg \
    --volname "Sentiment Analyzer" \
    --window-pos 200 120 \
    --window-size 600 300 \
    --icon-size 100 \
    --icon "Sentiment Analyzer.app" 175 120 \
    --hide-extension "Sentiment Analyzer.app" \
    --app-drop-link 425 120 \
    --background "dmg_background.png" \
    "SentimentAnalyzer.dmg" \
    "${EXPORT_PATH}/Sentiment Analyzer.app"

  if [ -f "SentimentAnalyzer.dmg" ]; then
    print_status "DMG created successfully: SentimentAnalyzer.dmg"
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
if [ -f "SentimentAnalyzer.dmg" ]; then
  echo "   DMG: SentimentAnalyzer.dmg"
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

print_status "Build process completed! 🎉"

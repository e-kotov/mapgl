#!/bin/bash
# Reproducible build script for flowmap.gl integration into mapgl R package
# This script builds flowmap.gl from TypeScript source and bundles it with deck.gl
# for use in the mapgl R package
#
# =============================================================================
# PREREQUISITES
# =============================================================================
#
# 1. Clone flowmap.gl repository:
#    cd /path/to/your/projects  # Navigate to parent directory of mapgl
#    git clone https://github.com/visgl/flowmap.gl.git
#
# 2. (Optional) Checkout a known working commit:
#    cd flowmap.gl
#    git checkout 4065dbef697a86ac7b85c6c5dd1bd961455a810d
#
#    OR to use the latest version:
#    git checkout main
#    git pull origin main
#
# 3. Ensure you have the required tools:
#    - Node.js v20.x (managed via volta)
#    - yarn (npm install -g yarn)
#
# Expected directory structure:
#   parent_dir/
#   ├── mapgl/                  (this R package)
#   │   └── build-flowmap.sh    (this script)
#   └── flowmap.gl/             (cloned from GitHub)
#       └── packages/
#           ├── data/
#           └── layers/
#
# =============================================================================
# HOW TO RUN
# =============================================================================
#
# From the mapgl package root directory:
#   chmod +x build-flowmap.sh    # Make executable (first time only)
#   ./build-flowmap.sh           # Run the build
#
# The script will:
#   1. Build flowmap.gl TypeScript packages
#   2. Bundle with deck.gl dependencies
#   3. Create minified browser bundle
#   4. Copy to inst/htmlwidgets/lib/flowmap-gl/
#
# Output: flowmap-gl-bundle.min.js (~588KB) ready for use in mapgl
#
# =============================================================================

set -e  # Exit on error

echo "========================================"
echo "Building flowmap.gl for mapgl R package"
echo "========================================"

# Paths (use absolute paths for reliability)
MAPGL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ -z "$FLOWMAP_DIR" ]; then
    FLOWMAP_DIR="$(cd "$MAPGL_DIR/../flowmap.gl" && pwd)"
fi
OUTPUT_DIR="$MAPGL_DIR/inst/htmlwidgets/lib/flowmap-gl"

# Known working commit (tested and verified)
KNOWN_COMMIT="ed581e11ca674ed1e17457a9526c864f8def678b"


# Check if flowmap.gl directory exists
if [ ! -d "$FLOWMAP_DIR" ]; then
    echo "Error: flowmap.gl directory not found at $FLOWMAP_DIR"
    echo ""
    echo "Please clone the flowmap.gl repository:"
    echo "  cd $(dirname "$MAPGL_DIR")"
    echo "  git clone https://github.com/visgl/flowmap.gl.git"
    echo ""
    echo "Then optionally checkout the known working commit:"
    echo "  cd flowmap.gl"
    echo "  git checkout $KNOWN_WORKING_COMMIT"
    echo ""
    exit 1
fi

# Check current git commit
if [ -d "$FLOWMAP_DIR/.git" ]; then
    cd "$FLOWMAP_DIR"
    CURRENT_COMMIT=$(git rev-parse HEAD)
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo "Using flowmap.gl:"
    echo "  Branch: $CURRENT_BRANCH"
    echo "  Commit: $CURRENT_COMMIT"
    if [ "$CURRENT_COMMIT" = "$KNOWN_WORKING_COMMIT" ]; then
        echo "  ✓ Using known working commit"
    else
        echo "  ⚠ Using different commit (known working: $KNOWN_WORKING_COMMIT)"
        echo "    If build fails, try: git checkout $KNOWN_WORKING_COMMIT"
    fi
    echo ""
fi

# Step 1: Install dependencies and build flowmap.gl packages
echo ""
echo "Step 1: Building flowmap.gl packages..."
cd "$FLOWMAP_DIR"

# Check if node_modules exists, if not install
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies with yarn..."
    yarn install
fi

# Build packages in correct order (data first, then layers)
echo "Building @flowmap.gl/data package..."
cd packages/data
yarn build
cd ../..

echo "Building @flowmap.gl/layers package..."
cd packages/layers
yarn build
cd ../..

# Verify build outputs
if [ ! -f "packages/data/dist/index.js" ]; then
    echo "Error: packages/data/dist/index.js not found after build"
    exit 1
fi

if [ ! -f "packages/layers/dist/index.js" ]; then
    echo "Error: packages/layers/dist/index.js not found after build"
    exit 1
fi

echo "✓ flowmap.gl packages built successfully"

# Step 2: Create bundle configuration
echo ""
echo "Step 2: Creating bundle with deck.gl dependencies..."
cd "$MAPGL_DIR"

# Create a temporary directory for bundling
TEMP_DIR="$MAPGL_DIR/.flowmap-build"
mkdir -p "$TEMP_DIR"

# Create package.json for bundling
cat > "$TEMP_DIR/package.json" <<EOF
{
  "name": "flowmap-gl-bundle",
  "version": "1.0.0",
  "private": true,
  "type": "module"
}
EOF

# Create the bundler entry point
cat > "$TEMP_DIR/bundle-entry.js" <<EOF
// Bundle entry point for flowmap.gl with deck.gl dependencies
export { FlowmapLayer, AnimatedFlowLinesLayer, FlowLinesLayer, FlowCirclesLayer } from '@flowmap.gl/layers';
export * from '@flowmap.gl/data';
export { MapboxOverlay } from '@deck.gl/mapbox';
export { Deck } from '@deck.gl/core';
export { ScatterplotLayer, TextLayer, LineLayer } from '@deck.gl/layers';
EOF

# Install required dependencies for bundling
echo "Installing bundling dependencies..."
cd "$TEMP_DIR"
yarn add @flowmap.gl/layers@file:$FLOWMAP_DIR/packages/layers
yarn add @flowmap.gl/data@file:$FLOWMAP_DIR/packages/data
yarn add @deck.gl/core@^9.0.0 @deck.gl/layers@^9.0.0 @deck.gl/mapbox@^9.0.0 @luma.gl/core@^9.0.0 @luma.gl/engine@^9.0.0 @luma.gl/shadertools@^9.0.0
yarn add esbuild --dev

# Step 3: Bundle with esbuild
echo ""
echo "Step 3: Creating browser bundle with esbuild..."

# Create esbuild configuration and bundle
cat > "$TEMP_DIR/build.js" <<EOF
import esbuild from 'esbuild';

esbuild.build({
  entryPoints: ['bundle-entry.js'],
  bundle: true,
  format: 'iife',
  globalName: 'FlowmapGL',
  outfile: 'flowmap-gl-bundle.js',
  platform: 'browser',
  target: 'es2020',
  minify: false,
  sourcemap: true,
  external: [], // Bundle everything
}).catch(() => process.exit(1));
EOF

node build.js

if [ ! -f "$TEMP_DIR/flowmap-gl-bundle.js" ]; then
    echo "Error: Bundle creation failed"
    exit 1
fi

echo "✓ Bundle created successfully"

# Step 4: Copy to inst/htmlwidgets/lib
echo ""
echo "Step 4: Copying bundle to mapgl package..."

mkdir -p "$OUTPUT_DIR"
cp "$TEMP_DIR/flowmap-gl-bundle.js" "$OUTPUT_DIR/"
cp "$TEMP_DIR/flowmap-gl-bundle.js.map" "$OUTPUT_DIR/" 2>/dev/null || true

# Create a minified version as well
echo "Creating minified version..."
cd "$TEMP_DIR"

cat > "$TEMP_DIR/build-min.js" <<EOF
import esbuild from 'esbuild';

esbuild.build({
  entryPoints: ['bundle-entry.js'],
  bundle: true,
  format: 'iife',
  globalName: 'FlowmapGL',
  outfile: 'flowmap-gl-bundle.min.js',
  platform: 'browser',
  target: 'es2020',
  minify: true,
  sourcemap: true,
  external: [],
}).catch(() => process.exit(1));
EOF

node build-min.js
cp "$TEMP_DIR/flowmap-gl-bundle.min.js" "$OUTPUT_DIR/" 2>/dev/null || true
cp "$TEMP_DIR/flowmap-gl-bundle.min.js.map" "$OUTPUT_DIR/" 2>/dev/null || true

echo "✓ Files copied to $OUTPUT_DIR"

# Step 5: Cleanup
echo ""
echo "Step 5: Cleaning up temporary files..."
cd "$MAPGL_DIR"
rm -rf "$TEMP_DIR"

echo ""
echo "========================================"
echo "✓ Build completed successfully!"
echo "========================================"
echo ""
echo "Output files:"
ls -lh "$OUTPUT_DIR"
echo ""
echo "You can now use these files in the mapgl R package"

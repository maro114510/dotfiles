#!/bin/bash
# chezmoi run_once_after_ script: set up Raycast memo-search extension

set -euo pipefail

EXTENSION_DIR="${HOME}/.raycast/memo-search"

echo "Setting up Raycast memo-search extension in ${EXTENSION_DIR}..."

cd "${EXTENSION_DIR}"

# Check if Bun is installed
if ! command -v bun &>/dev/null; then
  echo "Error: bun is not installed. Please install it first: brew install bun" >&2
  exit 1
fi

# Install dependencies
bun install --frozen-lockfile

# Build the extension
bun run build

# Generate assets/icon.png using Python3
python3 - <<'PYEOF'
import struct, zlib, os
os.makedirs('assets', exist_ok=True)
def make_png(w, h, r, g, b):
    def chunk(name, data):
        c = zlib.crc32(name + data) & 0xffffffff
        return struct.pack('>I', len(data)) + name + data + struct.pack('>I', c)
    raw = b''.join(b'\x00' + bytes([r, g, b] * w) for _ in range(h))
    sig = b'\x89PNG\r\n\x1a\n'
    return sig + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
with open('assets/icon.png', 'wb') as f:
    f.write(make_png(512, 512, 100, 150, 220))
PYEOF

echo "Raycast memo-search extension setup complete."
echo "To register the extension in Raycast: Raycast -> Import Extension -> ${EXTENSION_DIR}"

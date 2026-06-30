import os
from PIL import Image
import glob

# Compress large PNGs that are > 1MB
assets_dir = 'assets'
large_files = []
for ext in ['*.png', '*.jpg', '*.jpeg', '*.webm', '*.mp4']:
    for f in glob.glob(os.path.join(assets_dir, '**', ext), recursive=True):
        size_mb = os.path.getsize(f) / (1024 * 1024)
        if size_mb > 1:
            large_files.append((f, size_mb))

print("Large files found:")
for f, s in sorted(large_files, key=lambda x: -x[1]):
    print(f"  {f}: {s:.2f} MB")

# Compress PNG images > 1MB - resize to max 1200px width and optimize
for f, s in large_files:
    if f.lower().endswith(('.png', '.jpg', '.jpeg')):
        print(f"\nProcessing {f} ({s:.2f} MB)...")
        img = Image.open(f)
        w, h = img.size
        print(f"  Original: {w}x{h}")
        
        # Resize if width > 1200
        if w > 1200:
            ratio = 1200.0 / w
            new_size = (1200, int(h * ratio))
            img = img.resize(new_size, Image.Resampling.LANCZOS)
            print(f"  Resized to: {new_size}")
        
        # Save with optimization
        if f.lower().endswith('.png'):
            img.save(f, optimize=True, compress_level=9)
        else:
            img.save(f, optimize=True, quality=85)
        
        new_size_mb = os.path.getsize(f) / (1024 * 1024)
        print(f"  New size: {new_size_mb:.2f} MB (saved {s - new_size_mb:.2f} MB)")

print("\nDone! All large images compressed.")
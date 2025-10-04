import os
import json
import base64
from pathlib import Path
# === CONFIGURATION ===
ROOT_DIR = "lib" # change if your root folder has a different name or path
OUTPUT_JSON = "structure1.json"
MAX_FILE_SIZE_BYTES = 2 * 1024 * 1024 # 2MB per file max (adjust if needed)
TEXT_ENCODINGS = ["utf-8", "latin-1", "utf-16"]
IGNORED_DIR_NAMES = {"my_env", "__pycache__", ".venv", ".git","admin","careTaker"}# directories to skip entirely
IMAGE_EXTENSIONS = {".ico",".svg", ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".webmanifest",".apk"} # image files to skip reading
def read_file_content(path: Path):
    """
    Try to read a file as text (with multiple encodings).
    Skip reading content of image files. If too large or undecodable, fallback to base64.
    """
    try:
        if path.suffix.lower() in IMAGE_EXTENSIONS:
            return {"_note": "image file, content not read"}
        size = path.stat().st_size
        if size > MAX_FILE_SIZE_BYTES:
            return {
                "_binary_base64": base64.b64encode(path.read_bytes()).decode("utf-8"),
                "_note": f"file too large ({size} bytes), base64 encoded"
            }
        for enc in TEXT_ENCODINGS:
            try:
                text = path.read_text(encoding=enc)
                return {"_text": text, "_encoding": enc}
            except Exception:
                continue
        # fallback to base64 if no text decoding succeeded
        return {
            "_binary_base64": base64.b64encode(path.read_bytes()).decode("utf-8"),
            "_note": "could not decode as text, base64 encoded"
        }
    except Exception as e:
        return {"_error": f"failed to read: {e}"}
def build_structure(root: Path):
    """
    Recursively build nested dict of directories and their file contents,
    skipping ignored directories.
    """
    structure = {}
    try:
        entries = sorted(root.iterdir(), key=lambda p: (p.is_file(), p.name.lower()))
    except Exception as e:
        return {"_error": f"cannot list directory: {e}"}
    for entry in entries:
        if entry.is_dir():
            if entry.name in IGNORED_DIR_NAMES:
                continue
            structure[entry.name] = build_structure(entry)
        elif entry.is_file():
            structure[entry.name] = read_file_content(entry)
    return structure
def main():
    root_path = Path(ROOT_DIR)
    if not root_path.exists() or not root_path.is_dir():
        print(f"Error: root directory '{ROOT_DIR}' does not exist or is not a directory.")
        return
    tree = {root_path.name: build_structure(root_path)}
    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(tree, f, indent=2, ensure_ascii=False)
    print(f"Serialized structure written to {OUTPUT_JSON}")
if __name__ == "__main__":
    main()
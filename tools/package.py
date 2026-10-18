"""Validate a buffered source snapshot and verify every packaged byte."""
from pathlib import Path
import hashlib, json, re, stat, sys
from zipfile import ZipFile, ZIP_DEFLATED
ROOT = Path(__file__).resolve().parents[1]
CONFIG = json.loads((ROOT / 'repository.json').read_text())
SOURCE = ROOT / CONFIG['source']

def main():
    snapshot = {}
    for path in sorted(SOURCE.rglob('*')):
        if path.is_symlink() or getattr(path.lstat(), 'st_file_attributes', 0) & 0x400:
            raise ValueError(f'Linked content: {path}')
        if not path.is_file():
            continue
        if path.suffix.lower() in {'.dll', '.exe', '.dmp', '.log', '.zip'} or path.name in {'.env', 'workshop.mjl'}:
            raise ValueError(f'Unexpected distribution file: {path}')
        snapshot[path.relative_to(SOURCE).as_posix()] = path.read_bytes()
    meta = snapshot['modInfo.lua'].decode('utf-8')
    version = re.search(r'version\s*=\s*"(\d+\.\d+\.\d+)"', meta)
    if not version or not re.search(r'developer\s*=\s*"Vittorio"', meta):
        raise ValueError('Missing version or expected developer Vittorio')
    preview = re.search(r'preview\s*=\s*"([^"\r\n]+)"', meta)
    if preview and len(snapshot[preview[1]]) >= 1_000_000:
        raise ValueError('Workshop preview must be smaller than 1 MB')
    for name, data in snapshot.items():
        if name.endswith('.json'):
            json.loads(data)
    if CONFIG['source'] == 'SplitLogFloor45':
        sys.path.insert(0, str(ROOT))
        from model_assets import consolidate
        report = consolidate(SOURCE)  # Read-only: never normalize published assets here.
        if report['removed_bytes']:
            raise ValueError('Source needs model consolidation in the authoring workspace')
        print('Model validation:', json.dumps(report))
    target = ROOT / 'dist' / (CONFIG['slug'] + '-' + version[1] + '.zip')
    target.parent.mkdir(exist_ok=True)
    expected = {CONFIG['archive_root'] + '/' + k: v for k, v in snapshot.items()}
    with ZipFile(target, 'w', ZIP_DEFLATED) as archive:
        for name, data in expected.items():
            archive.writestr(name, data)
    with ZipFile(target) as archive:
        if len(archive.namelist()) != len(expected) or set(archive.namelist()) != set(expected) or archive.testzip():
            raise ValueError('Archive entry validation failed')
        for name, data in expected.items():
            if archive.read(name) != data:
                raise ValueError('Archive mismatch: ' + name)
    target.with_suffix('.zip.sha256').write_text(hashlib.sha256(target.read_bytes()).hexdigest() + '  ' + target.name + '\n')
    print(f'PASS: {len(expected)} files packaged and byte-verified: {target}')

if __name__ == '__main__':
    main()

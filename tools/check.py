"""Run local selected regression suites and syntax checks for both game editions."""
from pathlib import Path
import json, os, subprocess, sys
ROOT = Path(__file__).resolve().parents[1]
config = json.loads((ROOT / 'repository.json').read_text())
for edition, game in [('Public', 'Sapiens_NICHT_BETA'), ('Unstable', 'Sapiens')]:
    env = dict(os.environ, SAPIENS_GAME_DIR='D:/Steam/steamapps/common/' + game)
    print('Testing edition:', edition, flush=True)
    code = "import json; from pathlib import Path; from lua_runner import run; root=Path.cwd(); run('\\n'.join('assert(loadfile('+json.dumps(p.as_posix())+'))' for p in sorted((root / " + repr(config['source']) + ").rglob('*.lua'))))"
    subprocess.run([sys.executable, '-c', code], cwd=ROOT, env=env, check=True)
    if config['source'] == 'FamilyTree':
        for test in ['family-tree-tests/run.py', 'family-tree-tests/persistence_restart.py']:
            subprocess.run([sys.executable, test], cwd=ROOT, env=env, check=True)
    elif config['source'] == 'Precise Rotation':
        subprocess.run([sys.executable, 'rotation45-tests/verify.py'], cwd=ROOT, env=env, check=True)
subprocess.run([sys.executable, 'tools/package.py'], cwd=ROOT, check=True)

"""Compile and test with the installed game's LuaJIT DLL, without running the game."""
import ctypes as C
import json
import os
from pathlib import Path

root = Path(__file__).resolve().parents[1]
game = Path(os.environ.get('SAPIENS_GAME_DIR', r'D:\Steam\steamapps\common\Sapiens')).resolve()
os.environ['PATH'] = str(game) + os.pathsep + os.environ.get('PATH', '')
dll_dir = os.add_dll_directory(str(game))
lua = C.CDLL(str(game / 'lua51.dll'))
lua.luaL_newstate.restype = C.c_void_p
lua.luaL_openlibs.argtypes = [C.c_void_p]
lua.luaL_loadstring.argtypes = [C.c_void_p, C.c_char_p]
lua.lua_pcall.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_int]
lua.lua_tolstring.argtypes = [C.c_void_p, C.c_int, C.c_void_p]
lua.lua_tolstring.restype = C.c_char_p
lua.lua_close.argtypes = [C.c_void_p]
state = lua.luaL_newstate()
lua.luaL_openlibs(state)
def execute(code):
    error = lua.luaL_loadstring(state, code.encode())
    if error == 0:
        error = lua.lua_pcall(state, 0, 0, 0)
    if error:
        raise RuntimeError(lua.lua_tolstring(state, -1, None).decode('utf-8', 'replace'))
try:
    execute('ROOT = ' + json.dumps(root.as_posix()) + '; GAME = ' + json.dumps(game.as_posix()))
    patch = Path(os.environ.get('HAMMERSTONE_VIEW_PATCH', str(game.parents[1] / 'workshop/content/1060230/2840825226/patches/View_new_patch.lua')))
    if not patch.is_file():
        raise FileNotFoundError('Set HAMMERSTONE_VIEW_PATCH to the installed patches/View_new_patch.lua')
    execute('HAMMERSTONE_VIEW_PATCH = ' + json.dumps(patch.as_posix()))
    execute('HAMMERSTONE_OPTIONS_UI = ' + json.dumps((patch.parent.parent / 'scripts/hammerstone/options/modOptionsUI.lua').as_posix()))
    for path in sorted((root / 'FamilyTree').rglob('*.lua')):
        execute('assert(loadfile(' + json.dumps(path.as_posix()) + '))')
    execute('CATALOG = dofile(ROOT .. "/FamilyTree/scripts/familyTree/nameCatalog.lua"); mjrequire = function(name) if name == "familyTree/nameCatalog" then return CATALOG end; error(name) end')
    execute('dofile(ROOT .. "/family-tree-tests/verify.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/recovery.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/ui.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/surnames.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/stats.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/summaryCache.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/uniqueNames.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/audit.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/recruitment.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/conception.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/conceptionUI.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/conceptionNative.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/tree.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/treeUI.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/treePresentation.lua")')
    execute('dofile(ROOT .. "/family-tree-tests/requestTimeouts.lua")')
    print('PASS: all Family Tree Lua files compiled and test suites passed.')
finally:
    lua.lua_close(state)

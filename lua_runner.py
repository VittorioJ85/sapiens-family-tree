"""Execute local test code using the installed game's Lua 5.1 DLL."""
import ctypes
import os
from pathlib import Path

GAME = Path(os.environ.get('SAPIENS_GAME_DIR', 'D:/Steam/steamapps/common/Sapiens')).resolve()
DLL_DIRECTORY = os.add_dll_directory(str(GAME))
DLL = ctypes.CDLL(str(GAME / 'lua51.dll'))
DLL.luaL_newstate.restype = ctypes.c_void_p
DLL.luaL_openlibs.argtypes = [ctypes.c_void_p]
DLL.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
DLL.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
DLL.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
DLL.lua_tolstring.restype = ctypes.c_char_p
DLL.lua_close.argtypes = [ctypes.c_void_p]

def run(code):
    state = DLL.luaL_newstate()
    DLL.luaL_openlibs(state)
    raw = code.encode('utf-8')
    try:
        status = DLL.luaL_loadbuffer(state, raw, len(raw), b'@hotfix-tests')
        if not status:
            status = DLL.lua_pcall(state, 0, 0, 0)
        if status:
            raise RuntimeError(DLL.lua_tolstring(state, -1, None).decode('utf-8', 'replace'))
    finally:
        DLL.lua_close(state)

if __name__ == '__main__':
    import sys
    run(Path(sys.argv[1]).read_text(encoding='utf-8'))

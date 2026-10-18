"""Three fresh LuaJIT processes, file-backed test adapter; never opens a game save.

This verifies serialized journal/reload logic, not the native database's fsync or
power-loss guarantees. Only generated test data is loaded as Lua below.
"""
import ctypes as C
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get('SAPIENS_GAME_DIR', r'D:\Steam\steamapps\common\Sapiens'))
SCRIPT = r'''
local function encode(value)
    if type(value)=='string' then return string.format('%q',value) end
    if type(value)=='number' or type(value)=='boolean' then return tostring(value) end
    assert(type(value)=='table')
    local out={'{'}
    for k,v in pairs(value)do out[#out+1]='['..encode(k)..']='..encode(v)..',' end
    out[#out+1]='}';return table.concat(out)
end
local values=PHASE=='write' and {} or dofile(FIXTURE)
local fail=false
local db={dataForKey=function(_,k)return values[k]end,
    setDataForKey=function(_,v,k)
        if fail and k=='member:tribe:t:child' then error('injected stop before membership')end
        values[k]=v
        local f=assert(io.open(FIXTURE,'wb'));assert(f:write('return '..encode(values)));assert(f:close())
    end}
local Archive=dofile(ROOT..'/FamilyTree/scripts/familyTree/archive.lua')
local a=Archive.new(db)
if PHASE=='write' then
    a:put('nameSettings:t',{automatic=false,culture='roman',customNames={'Alpha'}})
    a:observe({id='parent',tribeID='t',name='Parent Julius',surname='Julius'})
    fail=true
    assert(not pcall(function()a:observe({id='child',tribeID='t',father='parent',deathTime=42})end))
    assert(values.pendingWrite)
elseif PHASE=='recover' then
    assert(not values.pendingWrite and a:hasMember('t','child'))
    assert(a:person('child').father=='parent' and a:person('child').deathTime==42)
    assert(a:get('nameSettings:t').customNames[1]=='Alpha')
    a:observe({id='other',tribeID='t'})
    a:observe({id='child',tribeID='t'})
    assert(select(2,a:list('tribe:t',0))==3)
else
    assert(not values.pendingWrite and select(2,a:list('tribe:t',0))==3)
    assert(a:person('child').deathTime==42)
    assert(select(2,a:list('children:parent',0))==1)
    assert(a:get('nameSettings:t').culture=='roman')
end
print('PASS fresh process '..PHASE..': file-backed archive/settings/journal')
'''

def phase(name, fixture):
    os.environ['PATH'] = str(GAME) + os.pathsep + os.environ.get('PATH', '')
    with os.add_dll_directory(str(GAME)):
        lua = C.CDLL(str(GAME / 'lua51.dll'))
        lua.luaL_newstate.restype = C.c_void_p
        lua.luaL_openlibs.argtypes = [C.c_void_p]
        lua.luaL_loadstring.argtypes = [C.c_void_p, C.c_char_p]
        lua.lua_pcall.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_int]
        lua.lua_tolstring.argtypes = [C.c_void_p, C.c_int, C.c_void_p]
        lua.lua_tolstring.restype = C.c_char_p
        lua.lua_close.argtypes = [C.c_void_p]
        state = lua.luaL_newstate()
        try:
            lua.luaL_openlibs(state)
            code = f'ROOT={json.dumps(ROOT.as_posix())}; PHASE={json.dumps(name)}; FIXTURE={json.dumps(Path(fixture).as_posix())};\n' + SCRIPT
            status = lua.luaL_loadstring(state, code.encode()) or lua.lua_pcall(state, 0, 0, 0)
            if status:
                raise RuntimeError(lua.lua_tolstring(state, -1, None).decode('utf-8', 'replace'))
        finally:
            lua.lua_close(state)

if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == '--phase':
        phase(sys.argv[2], sys.argv[3])
    else:
        with tempfile.TemporaryDirectory(prefix='family-tree-restart-') as scratch:
            fixture = str(Path(scratch) / 'generated-fixture.lua')
            for name in ('write', 'recover', 'verify'):
                subprocess.run([sys.executable, str(Path(__file__).resolve()), '--phase', name, fixture], check=True)

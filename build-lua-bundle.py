#!/usr/bin/env python3
import os
import json

def read_lua_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def build_bundle():
    base_dir = 'prometheus-obfuscator/src'
    modules = {}
    
    lua_files = []
    for root, dirs, files in os.walk(base_dir):
        for file in files:
            if file.endswith('.lua'):
                lua_files.append(os.path.join(root, file))
    
    for filepath in lua_files:
        rel_path = os.path.relpath(filepath, base_dir)
        module_name = rel_path.replace('/', '.').replace('\\', '.').replace('.lua', '')
        content = read_lua_file(filepath)
        modules[module_name] = content
    
    js_output = """// Auto-generated Lua modules bundle for Fengari
const LUA_MODULES = """ + json.dumps(modules, indent=2) + """;

const PRESETS = {
    "Minify": {
        LuaVersion: "Lua51",
        VarNamePrefix: "",
        NameGenerator: "MangledShuffled",
        PrettyPrint: false,
        Seed: 0,
        Steps: []
    },
    "Weak": {
        LuaVersion: "Lua51",
        VarNamePrefix: "",
        NameGenerator: "MangledShuffled",
        PrettyPrint: false,
        Seed: 0,
        Steps: [
            { Name: "Vmify", Settings: {} },
            { Name: "ConstantArray", Settings: { Treshold: 1, StringsOnly: true } },
            { Name: "WrapInFunction", Settings: {} }
        ]
    },
    "Medium": {
        LuaVersion: "Lua51",
        VarNamePrefix: "",
        NameGenerator: "MangledShuffled",
        PrettyPrint: false,
        Seed: 0,
        Steps: [
            { Name: "EncryptStrings", Settings: {} },
            { Name: "AntiTamper", Settings: { UseDebug: false } },
            { Name: "Vmify", Settings: {} },
            { Name: "ConstantArray", Settings: { Treshold: 1, StringsOnly: true, Shuffle: true, Rotate: true, LocalWrapperTreshold: 0 } },
            { Name: "NumbersToExpressions", Settings: {} },
            { Name: "WrapInFunction", Settings: {} }
        ]
    },
    "Strong": {
        LuaVersion: "Lua51",
        VarNamePrefix: "",
        NameGenerator: "MangledShuffled",
        PrettyPrint: false,
        Seed: 0,
        Steps: [
            { Name: "Vmify", Settings: {} },
            { Name: "EncryptStrings", Settings: {} },
            { Name: "AntiTamper", Settings: {} },
            { Name: "Vmify", Settings: {} },
            { Name: "ConstantArray", Settings: { Treshold: 1, StringsOnly: true, Shuffle: true, Rotate: true, LocalWrapperTreshold: 0 } },
            { Name: "NumbersToExpressions", Settings: {} },
            { Name: "WrapInFunction", Settings: {} }
        ]
    },
    "Maximum": {
        LuaVersion: "Lua51",
        VarNamePrefix: "",
        NameGenerator: "MangledShuffled",
        PrettyPrint: false,
        Seed: 0,
        Steps: [
            { Name: "Vmify", Settings: {} },
            { Name: "EncryptStrings", Settings: {} },
            { Name: "AntiTamper", Settings: {} },
            { Name: "Vmify", Settings: {} },
            { Name: "ConstantArray", Settings: { Treshold: 1, StringsOnly: true, Shuffle: true, Rotate: true, LocalWrapperTreshold: 0 } },
            { Name: "NumbersToExpressions", Settings: {} },
            { Name: "WrapInFunction", Settings: {} }
        ]
    }
};
"""
    
    with open('lua-bundle.js', 'w', encoding='utf-8') as f:
        f.write(js_output)
    
    print(f"Generated lua-bundle.js with {len(modules)} modules")
    for name in sorted(modules.keys()):
        print(f"  - {name}")

if __name__ == '__main__':
    build_bundle()

const SAMPLE_CODE = `-- Light Obfuscator Sample

local function greet(name)
    print("Hello, " .. name .. "!")
    return true
end

local function calculateSum(a, b)
    local result = a + b
    return result
end

local userName = "World"
greet(userName)

local sum = calculateSum(10, 25)
print("Sum: " .. sum)
`;

const PRESET_INFO = {
  Weak: { label: "Weak", description: "Light obfuscation, smallest output size" },
  Medium: { label: "Medium", description: "Balanced protection and performance" },
  Strong: { label: "Strong", description: "NOT COMPATIBLE WITH LUAU!" },
  Maximum: { label: "Maximum", description: "NOT COMPATIBLE WITH LUAU!" }
};

let inputEditor = null;
let outputEditor = null;
let inputCode = "";
let outputCode = "";
let currentPreset = "Medium";
let isProcessing = false;
let fengariReady = false;
let luaState = null;

function showToast(title, description, variant = "default") {
  const container = document.getElementById("toastContainer");
  const toast = document.createElement("div");
  toast.className = `toast ${variant}`;
  toast.innerHTML = `
    <span class="toast-title">${title}</span>
    <span class="toast-description">${description}</span>
  `;
  container.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = "0";
    setTimeout(() => toast.remove(), 200);
  }, 3000);
}

function updateStats() {
  const inputLines = inputCode.split("\n").length;
  const inputChars = inputCode.length;
  const outputLines = outputCode ? outputCode.split("\n").length : 0;
  const outputChars = outputCode.length;

  document.getElementById("inputLines").textContent = `${inputLines} lines`;
  document.getElementById("inputChars").textContent = `${inputChars.toLocaleString()} characters`;
  document.getElementById("outputLines").textContent = `${outputLines} lines`;
  document.getElementById("outputChars").textContent = `${outputChars.toLocaleString()} characters`;
}

function updateButtonStates() {
  const hasInput = inputCode.trim().length > 0;
  const hasOutput = outputCode.length > 0;

  document.getElementById("copyInputBtn").disabled = !hasInput;
  document.getElementById("clearBtn").disabled = !hasInput;
  document.getElementById("copyOutputBtn").disabled = !hasOutput;
  document.getElementById("downloadBtn").disabled = !hasOutput;
  document.getElementById("obfuscateBtn").disabled = !hasInput || isProcessing || !fengariReady;

  document.getElementById("inputEmptyState").classList.toggle("hidden", hasInput);
  document.getElementById("outputEmptyState").classList.toggle("hidden", hasOutput);
  document.getElementById("outputIndicator").classList.toggle("hidden", !hasOutput);
}

function initFengari() {
  if (typeof fengari === 'undefined') {
    console.error('Fengari not available, retrying in 500ms...');
    setTimeout(initFengari, 500);
    return;
  }
  
  console.log('Fengari found, initializing...');
  
  try {
    const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;
    console.log('Fengari modules extracted:', { lua: !!lua, lauxlib: !!lauxlib, lualib: !!lualib });
    luaState = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(luaState);
    
    const preloadCode = `
      -- Mock arg table (command-line arguments - not used in browser)
      arg = arg or {}
      
      -- Store modules in package.preload
      package.preload = package.preload or {}
      
      -- Override require to check our preloaded modules first
      local originalRequire = require
      local loadedModules = {}
      
      function require(modname)
        if loadedModules[modname] then
          return loadedModules[modname]
        end
        
        if package.preload[modname] then
          local result = package.preload[modname]()
          loadedModules[modname] = result or true
          return loadedModules[modname]
        end
        
        return originalRequire(modname)
      end
      
      -- Polyfills for Lua 5.1 compatibility
      if not bit32 then
        bit32 = {
          band = function(a, b) return a & b end,
          bor = function(a, b) return a | b end,
          bxor = function(a, b) return a ~ b end,
          bnot = function(a) return ~a end,
          lshift = function(a, b) return a << b end,
          rshift = function(a, b) return a >> b end,
          arshift = function(a, b) return a >> b end,
          extract = function(n, field, width)
            width = width or 1
            return (n >> field) & ((1 << width) - 1)
          end,
          replace = function(n, v, field, width)
            width = width or 1
            local mask = (1 << width) - 1
            return (n & ~(mask << field)) | ((v & mask) << field)
          end,
        }
      end

            -- Polyfills for Lua 5.1 compatibility
      if not bit32 then
        bit32 = {
          band = function(a, b) return a & b end,
          bor = function(a, b) return a | b end,
          bxor = function(a, b) return a ~ b end,
          bnot = function(a) return ~a end,
          lshift = function(a, b) return a << b end,
          rshift = function(a, b) return a >> b end,
          arshift = function(a, b) return a >> b end,
          extract = function(n, field, width)
            width = width or 1
            return (n >> field) & ((1 << width) - 1)
          end,
          replace = function(n, v, field, width)
            width = width or 1
            local mask = (1 << width) - 1
            return (n & ~(mask << field)) | ((v & mask) << field)
          end,
        }
      end

      -- safe math.random to avoid 'interval too large' / nil errors
      do
        local original_random = math and math.random
        local original_randomseed = math and math.randomseed

        if type(original_random) == "function" then
          local max_int = 2 ^ 31 - 1

          math.random = function(a, b)
            if a == nil then
              return original_random()
            elseif b == nil then
              return math.random(1, a)
            end

            if a > b then a, b = b, a end
            local diff = b - a

            if diff <= max_int then
              return original_random(a, b)
            end

            local r = original_random()
            if type(r) == "number" and r >= 0 and r < 1 then
              return a + math.floor(r * (diff + 1))
            end

            local value = 0
            local base = max_int + 1
            local remaining = diff + 1

            while remaining > 0 do
              value = value * base + (original_random(0, max_int) or 0)
              remaining = math.floor(remaining / base)
            end

            return a + (value % (diff + 1))
          end

          if type(original_randomseed) == "function" then
            math.randomseed = original_randomseed
          end
        end
      end

      -- Polyfill for unpack
      if not unpack then
        unpack = table.unpack
      end

      
      -- Polyfill for unpack
      if not unpack then
        unpack = table.unpack
      end
      
      -- Polyfill for loadstring
      if not loadstring then
        loadstring = load
      end
      
      -- Mock debug.getinfo for browser
      local oldDebugGetinfo = debug and debug.getinfo
      if debug then
        debug.getinfo = function(level, what)
          if oldDebugGetinfo then
            local ok, result = pcall(oldDebugGetinfo, level, what)
            if ok then return result end
          end
          return { source = "@virtual", short_src = "virtual" }
        end
      end
      
      -- Mock os.time
      if not os then os = {} end
      if not os.time then
        os.time = function() return math.floor(os.clock() * 1000) end
      end
      if not os.clock then
        os.clock = function() return 0 end
      end
      
      -- Mock io module (not needed for obfuscation)
      if not io then io = {} end
      
      _G.newproxy = _G.newproxy or function(arg)
        if arg then
          return setmetatable({}, {})
        end
        return {}
      end
    `;
    
    lauxlib.luaL_dostring(luaState, to_luastring(preloadCode));
    
    for (const [moduleName, moduleCode] of Object.entries(LUA_MODULES)) {
      const wrappedCode = `
        package.preload["${moduleName}"] = function()
          ${moduleCode}
        end
      `;
      const result = lauxlib.luaL_dostring(luaState, to_luastring(wrappedCode));
      if (result !== 0) {
        const errStr = lua.lua_tostring(luaState, -1);
        const error = errStr ? to_jsstring(errStr) : "Unknown error";
        console.error(`Failed to load module ${moduleName}:`, error);
        lua.lua_pop(luaState, 1);
      }
    }
    
    console.log("Loaded all modules, testing initialization...");
    
    const testLoad = lauxlib.luaL_dostring(luaState, to_luastring(`
      local modules_to_test = {
        "colors", "config", "logger", "presets",
        "prometheus.util", "prometheus.enums", "prometheus.ast",
        "prometheus.tokenizer", "prometheus.parser", "prometheus.scope",
        "prometheus.step", "prometheus.namegenerators",
        "prometheus.unparser", "prometheus.pipeline"
      }
      
      for i, modname in ipairs(modules_to_test) do
        local ok, result = pcall(require, modname)
        if not ok then
          return "Failed to load " .. modname .. ": " .. tostring(result)
        end
      end
      
      return true
    `));
    
    if (testLoad === 0) {
      const resultType = lua.lua_type(luaState, -1);
      if (resultType === lua.LUA_TBOOLEAN && lua.lua_toboolean(luaState, -1)) {
        fengariReady = true;
        console.log("Fengari initialized successfully with Prometheus modules");
      } else if (resultType === lua.LUA_TSTRING) {
        const errStr = lua.lua_tostring(luaState, -1);
        const error = errStr ? to_jsstring(errStr) : "Unknown error";
        console.error("Failed to initialize Prometheus:", error);
        showToast("Engine Error", error, "destructive");
      } else {
        console.error("Unexpected result type:", resultType);
        showToast("Engine Error", "Failed to initialize obfuscation engine", "destructive");
      }
    } else {
      const errStr = lua.lua_tostring(luaState, -1);
      const error = errStr ? to_jsstring(errStr) : "Script execution failed";
      console.error("Failed to run test script:", error);
      showToast("Engine Error", error, "destructive");
    }
    lua.lua_pop(luaState, 1);
    
  } catch (error) {
    console.error("Fengari initialization error:", error);
    console.error("Error stack:", error.stack);
    console.error("Error message:", error.message);
    showToast("Engine Error", "Failed to initialize Lua engine: " + (error.message || error.toString()), "destructive");
  }
}

async function handleObfuscate() {
  if (!inputCode.trim() || isProcessing) return;

  if (!fengariReady) {
    showToast("Not Ready", "Obfuscation engine is still loading...", "destructive");
    return;
  }

  isProcessing = true;
  const btn = document.getElementById("obfuscateBtn");
  btn.innerHTML = `
    <svg class="loading-spinner" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
      <path d="M21 12a9 9 0 1 1-6.219-8.56"/>
    </svg>
    <span>Processing...</span>
  `;
  btn.disabled = true;

  await new Promise(resolve => setTimeout(resolve, 50));

  try {
    const { lua, lauxlib, to_luastring, to_jsstring } = fengari;
    
    const presetConfig = PRESETS[currentPreset] || PRESETS["Strong"];
    
    // Convert steps to Lua table syntax
    function toLuaTable(obj) {
      if (Array.isArray(obj)) {
        return '{' + obj.map(toLuaTable).join(', ') + '}';
      } else if (typeof obj === 'object' && obj !== null) {
        const pairs = Object.entries(obj).map(([k, v]) => `["${k}"] = ${toLuaTable(v)}`);
        return '{' + pairs.join(', ') + '}';
      } else if (typeof obj === 'string') {
        return '"' + obj.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
      } else if (typeof obj === 'boolean') {
        return obj ? 'true' : 'false';
      } else if (typeof obj === 'number') {
        return String(obj);
      }
      return 'nil';
    }
    
    const stepsLua = toLuaTable(presetConfig.Steps.map(s => ({
      Name: s.Name,
      Settings: s.Settings || {}
    })));
    
    // Escape for Lua string literal (using double quotes)
    // Handle all special characters including ]] which would break multiline strings
    const escapedCode = inputCode
      .replace(/\\/g, '\\\\')
      .replace(/"/g, '\\"')
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r')
      .replace(/\t/g, '\\t')
      .replace(/\0/g, '\\0');
    
    const obfuscateScript = `
      local function runObfuscation()
        local Pipeline = require("prometheus.pipeline")
        local logger = require("logger")
        
        logger.logLevel = 0
        
        local config = {
          LuaVersion = "LuaU",
          VarNamePrefix = "",
          NameGenerator = "MangledShuffled",
          PrettyPrint = false,
          Seed = math.random(1, 1000000),
          InjectRuntimeModules = true,
          Steps = {}
        }
        
        local stepsData = ${stepsLua}
        for i, stepData in ipairs(stepsData) do
          table.insert(config.Steps, {
            Name = stepData.Name,
            Settings = stepData.Settings or {}
          })
        end
        
        local pipeline = Pipeline:fromConfig(config)
        local inputCode = "${escapedCode}"
        local result = pipeline:apply(inputCode, "input.lua")

        return "-- Obfuscated with light obfuscator v1.2\\n" .. result
      end
      
      local ok, result = pcall(runObfuscation)
      if ok then
        return result
      else
        error(result)
      end
    `;

    
    const result = lauxlib.luaL_dostring(luaState, to_luastring(obfuscateScript));
    
    if (result === 0) {
      const obfuscated = to_jsstring(lua.lua_tostring(luaState, -1));
      lua.lua_pop(luaState, 1);
      
      if (obfuscated) {
        outputCode = obfuscated;
        if (outputEditor) {
          outputEditor.setValue(outputCode);
        }
        switchToTab("output");
        showToast("Obfuscation Complete", `Your code has been successfully obfuscated with the ${currentPreset} preset.`);
      } else {
        showToast("Obfuscation Failed", "No output was generated.", "destructive");
      }
    } else {
      const error = to_jsstring(lua.lua_tostring(luaState, -1));
      lua.lua_pop(luaState, 1);
      console.error("Obfuscation error:", error);
      showToast("Obfuscation Failed", error || "An unknown error occurred.", "destructive");
    }
  } catch (error) {
    console.error("Obfuscation error:", error);
    showToast("Error", error.message || "Failed to obfuscate code.", "destructive");
  } finally {
    isProcessing = false;
    btn.innerHTML = `
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
        <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
        <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
      </svg>
      <span>Obfuscate</span>
    `;
    updateButtonStates();
  }
}

async function copyToClipboard(text, isInput) {
  try {
    await navigator.clipboard.writeText(text);
    const btn = document.getElementById(isInput ? "copyInputBtn" : "copyOutputBtn");
    btn.querySelector(".copy-icon").classList.add("hidden");
    btn.querySelector(".check-icon").classList.remove("hidden");
    setTimeout(() => {
      btn.querySelector(".copy-icon").classList.remove("hidden");
      btn.querySelector(".check-icon").classList.add("hidden");
    }, 2000);
    showToast("Copied!", "Code copied to clipboard.");
  } catch {
    showToast("Copy Failed", "Failed to copy to clipboard.", "destructive");
  }
}

function downloadCode() {
  if (!outputCode) return;
  const blob = new Blob([outputCode], { type: "text/plain" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "obfuscated.lua";
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  showToast("Downloaded", "Obfuscated code saved as obfuscated.lua");
}

function loadSample() {
  inputCode = SAMPLE_CODE;
  if (inputEditor) {
    inputEditor.setValue(SAMPLE_CODE);
  }
  switchToTab("input");
  updateStats();
  updateButtonStates();
  showToast("Sample Loaded", "Sample Lua code has been loaded into the editor.");
}

loadSample();

function clearInput() {
  inputCode = "";
  outputCode = "";
  if (inputEditor) inputEditor.setValue("");
  if (outputEditor) outputEditor.setValue("");
  updateStats();
  updateButtonStates();
}

function switchToTab(tab) {
  document.querySelectorAll(".tab-btn").forEach(btn => {
    btn.classList.toggle("active", btn.dataset.tab === tab);
  });
  document.getElementById("inputPanel").classList.toggle("active", tab === "input");
  document.getElementById("outputPanel").classList.toggle("active", tab === "output");
}

function openSettings() {
  document.getElementById("settingsOverlay").classList.remove("hidden");
}

function closeSettings() {
  document.getElementById("settingsOverlay").classList.add("hidden");
}

function updatePresetDisplay() {
  document.getElementById("footerPreset").textContent = `${currentPreset} Preset`;
  document.getElementById("currentPresetName").textContent = `${currentPreset} Preset`;
  document.getElementById("currentPresetDesc").textContent = PRESET_INFO[currentPreset].description;
}

function initResizeHandle() {
  const handle = document.getElementById("resizeHandle");
  const inputPanel = document.getElementById("inputPanel");
  const outputPanel = document.getElementById("outputPanel");
  let isResizing = false;

  handle.addEventListener("mousedown", (e) => {
    isResizing = true;
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
  });

  document.addEventListener("mousemove", (e) => {
    if (!isResizing) return;
    const container = document.querySelector(".panels");
    const containerRect = container.getBoundingClientRect();
    const percentage = ((e.clientX - containerRect.left) / containerRect.width) * 100;
    const clampedPercentage = Math.max(25, Math.min(75, percentage));
    inputPanel.style.flex = `0 0 ${clampedPercentage}%`;
    outputPanel.style.flex = `0 0 ${100 - clampedPercentage - 1}%`;
  });

  document.addEventListener("mouseup", () => {
    isResizing = false;
    document.body.style.cursor = "";
    document.body.style.userSelect = "";
  });
}

function initMonaco() {
  require.config({ paths: { vs: "https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.44.0/min/vs" } });

  require(["vs/editor/editor.main"], function () {
    const editorOptions = {
      theme: "vs-dark",
      language: "lua",
      minimap: { enabled: false },
      fontSize: 13,
      fontFamily: "'JetBrains Mono', monospace",
      lineNumbers: "on",
      scrollBeyondLastLine: false,
      automaticLayout: true,
      padding: { top: 12 },
      tabSize: 2,
      wordWrap: "on"
    };

    inputEditor = monaco.editor.create(document.getElementById("inputEditor"), {
      ...editorOptions,
      value: inputCode
    });

    outputEditor = monaco.editor.create(document.getElementById("outputEditor"), {
      ...editorOptions,
      value: outputCode,
      readOnly: true
    });

    inputEditor.onDidChangeModelContent(() => {
      inputCode = inputEditor.getValue();
      updateStats();
      updateButtonStates();
    });

    updateStats();
    updateButtonStates();
  });
}

document.addEventListener("DOMContentLoaded", () => {
  initMonaco();
  initResizeHandle();
  initFengari();

  document.getElementById("obfuscateBtn").addEventListener("click", handleObfuscate);
  document.getElementById("sampleBtn").addEventListener("click", loadSample);
  document.getElementById("clearBtn").addEventListener("click", clearInput);
  document.getElementById("copyInputBtn").addEventListener("click", () => copyToClipboard(inputCode, true));
  document.getElementById("copyOutputBtn").addEventListener("click", () => copyToClipboard(outputCode, false));
  document.getElementById("downloadBtn").addEventListener("click", downloadCode);
  document.getElementById("settingsBtn").addEventListener("click", openSettings);
  document.getElementById("applySettingsBtn").addEventListener("click", closeSettings);

  document.getElementById("settingsOverlay").addEventListener("click", (e) => {
    if (e.target.id === "settingsOverlay") closeSettings();
  });

  document.querySelectorAll(".tab-btn").forEach(btn => {
    btn.addEventListener("click", () => switchToTab(btn.dataset.tab));
  });

  document.querySelectorAll('input[name="preset"]').forEach(radio => {
    radio.addEventListener("change", () => {
      currentPreset = radio.value;
      updatePresetDisplay();
    });
  });

  document.addEventListener("keydown", (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
      e.preventDefault();
      handleObfuscate();
    }
  });

  switchToTab("input");
  updatePresetDisplay();
});

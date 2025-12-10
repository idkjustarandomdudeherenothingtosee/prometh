-- This Script is Part of the Prometheus Obfuscator by narodi
-- namegenerators/mangled_shuffled.lua
-- This Script provides a function for generation of highly obfuscated mangled names.

local util = require("prometheus.util");
local RandomStrings = require("prometheus.randomStrings"); -- Assuming this is available for salt generation

-- --- Core Character Sets ---
-- These are the base pools of characters we will draw from.
local BASE_START_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
local BASE_MIDDLE_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";

-- --- Runtime State ---
-- These tables will be populated and shuffled during the prepare phase.
local VarStartDigits = {};
local VarDigits = {};

-- --- Obfuscation Configuration ---
-- These settings control the complexity of the generated names.
local MIN_NAME_LENGTH = 8;  -- Minimum length for generated names.
local MAX_NAME_LENGTH = 16; -- Maximum length for generated names.
local USE_HEX_PREFIX = true; -- Prepend a random hex-like prefix (e.g., "_x1A2b").
local SALT = nil; -- Will be initialized in prepare() to ensure uniqueness per run.

-- --- Helper Functions ---

-- A cryptographically weak but sufficient pseudo-random number generator.
-- Using a simple Linear Congruential Generator (LCG) makes the sequence harder to guess
-- than standard math.random if the seed is unknown.
local lcg_seed = 0;
local function lcg_random()
    lcg_seed = (lcg_seed * 1664525 + 1013904223) % (2^1^);
    return lcg_seed / (2^1^);
end

-- A more complex shuffle algorithm (Fisher-Yates) using our LCG.
-- This is better than a naive shuffle and uses our custom PRNG.
local function fisherYatesShuffle(t)
    local n = #t;
    for i = n, 2, -1 do
        local j = math.floor(lcg_random() * i) + 1;
        t[i], t[j] = t[j], t[i];
    end
end

-- --- Name Generation Logic ---

-- The main function to generate a name for a given identifier.
local function generateName(id, scope)
    -- The id is now primarily used to seed the random number generator for this specific name.
    -- This ensures the same `id` in the same scope always gets the same name, but the name itself is complex.
    lcg_seed = id + (SALT and SALT:len() or 0);

    local name_parts = {};

    -- 1. Add an optional, non-deterministic hex-like prefix.
    -- This breaks the simple "starts with a letter" pattern and adds noise.
    if USE_HEX_PREFIX and lcg_random() > 0.3 then -- 70% chance to add a prefix
        local prefix = "_x" .. string.format("%x", math.floor(lcg_random() * 0xFFFF));
        table.insert(name_parts, prefix);
    end

    -- 2. Determine the length of the core name.
    -- The length is now random within a defined range, not based on the ID's magnitude.
    local core_length = math.floor(MIN_NAME_LENGTH + lcg_random() * (MAX_NAME_LENGTH - MIN_NAME_LENGTH + 1));

    -- 3. Build the core name from the shuffled character sets.
    -- The first character is from the start set, the rest from the middle set.
    local start_char_idx = math.floor(lcg_random() * #VarStartDigits) + 1;
    table.insert(name_parts, VarStartDigits[start_char_idx]);

    for i = 2, core_length do
        local char_idx = math.floor(lcg_random() * #VarDigits) + 1;
        table.insert(name_parts, VarDigits[char_idx]);
    end
    
    -- 4. Concatenate all parts to form the final name.
    return table.concat(name_parts);
end

-- --- Preparation Logic ---

-- This function is called once before name generation begins.
-- It's responsible for setting up the unique, shuffled state for this obfuscation run.
local function prepare(ast)
    -- Generate a unique, random salt for this run.
    -- This ensures that even with the same input script, the output names are different every time.
    SALT = RandomStrings.randomString(32);

    -- Seed our custom PRNG with the salt and a timestamp for extra entropy.
    lcg_seed = util.stringToHash(SALT) + os.time();

    -- 1. Populate the runtime character tables from the base sets.
    -- We create copies to avoid modifying the original constants.
    for i = 1, #BASE_START_CHARS do
        VarStartDigits[i] = BASE_START_CHARS:sub(i, i);
    end
    for i = 1, #BASE_MIDDLE_CHARS do
        VarDigits[i] = BASE_MIDDLE_CHARS:sub(i, i);
    end

    -- 2. Shuffle the character tables using our custom, seeded PRNG.
    -- This is the most critical step. The order of characters is now unique per run.
    fisherYatesShuffle(VarStartDigits);
    fisherYatesShuffle(VarDigits);
end

return {
    generateName = generateName,
    prepare = prepare
};

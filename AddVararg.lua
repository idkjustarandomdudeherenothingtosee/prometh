-- This Script is Part of the Prometheus Obfuscator by narodi
-- AddVararg.lua
-- This Script provides an Obfuscation Step that conditionally wraps functions with a vararg
-- and adds a simple, obfuscated usage and integrity check.

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local visitast = require("prometheus.visitast");
local AstKind = Ast.AstKind;
local RandomStrings = require("prometheus.randomStrings");

local AddVararg = Step:extend();
AddVararg.Description = "Conditionally adds a vararg to functions and includes integrity checks.";
AddVararg.Name = "Add Vararg (Enhanced)";

AddVararg.SettingsDescriptor = {
    -- Probability of adding a vararg to any given function.
    -- A value of 0.7 means ~70% of functions will be modified.
    Probability = { type = "number", default = 0.7, description = "Probability (0.0-1.0) to add vararg to a function." },
    -- If true, adds a simple, obfuscated usage of the vararg to prevent it from being optimized away.
    AddUsage = { type = "boolean", default = true, description = "Add an obfuscated usage for the added vararg." },
    -- If true, adds a runtime check to ensure the vararg wasn't removed after obfuscation.
    AddIntegrityCheck = { type = "boolean", default = true, description = "Add a runtime integrity check for the vararg." }
}

function AddVararg:init(settings)
    -- Sanitize probability value
    self.Probability = math.max(0.0, math.min(1.0, tonumber(settings.Probability) or 0.7));
    self.AddUsage = settings.AddUsage ~= false; -- Default to true
    self.AddIntegrityCheck = settings.AddIntegrityCheck ~= false; -- Default to true
end

function AddVararg:apply(ast)
    -- Use a unique, random string for the integrity check to avoid collisions.
    local integritySalt = RandomStrings.randomString(16);

    visitast(ast, nil, function(node, parent)
        -- Only target function definitions and literals.
        if node.kind == AstKind.FunctionDeclaration or node.kind == AstKind.LocalFunctionDeclaration or node.kind == AstKind.FunctionLiteralExpression then
            
            -- --- Control Flow & Conditional Logic ---
            -- Don't process if the function already has a vararg.
            if #node.args > 0 and node.args[#node.args].kind == AstKind.VarargExpression then
                return
            end

            -- Randomly decide whether to modify this function based on the probability setting.
            if math.random() > self.Probability then
                return
            end

            -- --- The Core Transformation ---
            -- Add the vararg to the function's argument list.
            table.insert(node.args, Ast.VarargExpression());
            
            -- --- Vararg Usage ---
            -- If the setting is enabled, add a simple, obfuscated usage of the vararg.
            -- This makes the vararg a legitimate part of the function's logic.
            if self.AddUsage and node.body and node.body.statements then
                -- Create a local variable to store the number of varargs passed.
                -- `select('#', ...)` is the standard way to do this.
                local varargCount = Ast.FunctionCallExpression(
                    Ast.IdentifierExpression("select"),
                    {
                        Ast.StringLiteral("#"),
                        Ast.VarargExpression()
                    }
                );

                -- Create a simple assignment: `local _<random> = select('#', ...)`
                -- The underscore prefix and random name suggest it's a dummy/temp variable.
                local dummyName = "_" .. RandomStrings.randomString(8);
                local usageStatement = Ast.LocalVariableDeclaration(
                    { Ast.Identifier(dummyName) },
                    { varargCount }
                );

                -- Prepend the usage statement to the function body.
                table.insert(node.body.statements, 1, usageStatement);
            end

            -- --- Anti-Tamper / Integrity Check ---
            -- If enabled, add a runtime check to ensure the vararg is still present.
            -- This check is placed at the end of the function body.
            if self.AddIntegrityCheck and node.body and node.body.statements then
                -- Create a check that will fail if the vararg `...` is removed.
                -- The logic is: `if (select('#', ...) or 0) < 0 then error() end`
                -- This is always false, but it requires `...` to exist to be evaluated.
                -- If `...` is removed, it becomes a syntax error, breaking the script.
                local checkCondition = Ast.BinaryExpression(
                    Ast.BinaryExpression(
                        Ast.FunctionCallExpression(
                            Ast.IdentifierExpression("select"),
                            {
                                Ast.StringLiteral("#"),
                                Ast.VarargExpression()
                            }
                        ),
                        "or",
                        Ast.NumberLiteral(0)
                    ),
                    "<",
                    Ast.NumberLiteral(0)
                );

                local errorMessage = string.format("Vararg integrity check failed: %s", integritySalt);
                local integrityCheck = Ast.IfStatement(
                    checkCondition,
                    {
                        Ast.FunctionCallExpression(
                            Ast.IdentifierExpression("error"),
                            { Ast.StringLiteral(errorMessage) }
                        )
                    }
                );

                -- Append the integrity check to the end of the function body.
                table.insert(node.body.statements, integrityCheck);
            end
        end
    end)

    return ast;
end

return AddVararg;

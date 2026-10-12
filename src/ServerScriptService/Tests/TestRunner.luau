-- A tiny test runner. Runs every "*.spec" module in this folder when you press Play in Studio
-- (GameConfig.RunTestsInStudio) and prints the results to the Output window.
--
-- A spec module returns a function that receives `t`:
--   t.test("name", function() t.equal(1 + 1, 2) end)
--   t.equal(actual, expected, message?)    t.near(actual, expected, tolerance?, message?)
--   t.truthy(value, message?)

local TestRunner = {}

local function describe(value: any): string
	if type(value) == "string" then
		return `"{value}"`
	end
	return tostring(value)
end

local function makeContext(results)
	local t = {}

	function t.test(name: string, fn: () -> ())
		table.insert(results.Tests, { Name = `{results.Suite} > {name}`, Fn = fn })
	end

	function t.equal(actual: any, expected: any, message: string?)
		if actual ~= expected then
			error(`{message or "Values differ"}: expected {describe(expected)}, got {describe(actual)}`, 2)
		end
	end

	function t.near(actual: number, expected: number, tolerance: number?, message: string?)
		if math.abs(actual - expected) > (tolerance or 1e-6) then
			error(`{message or "Numbers differ"}: expected {expected}, got {actual}`, 2)
		end
	end

	function t.truthy(value: any, message: string?)
		if not value then
			error(message or "Expected a truthy value", 2)
		end
	end

	return t
end

function TestRunner.Run(): (number, number)
	local tests = {}
	for _, module in script.Parent:GetChildren() do
		if module:IsA("ModuleScript") and string.sub(module.Name, -5) == ".spec" then
			local results = { Suite = string.sub(module.Name, 1, -6), Tests = tests }
			local ok, err = pcall(function()
				require(module)(makeContext(results))
			end)
			if not ok then
				table.insert(tests, {
					Name = `{results.Suite} (loading)`,
					Fn = function()
						error(err, 0)
					end,
				})
			end
		end
	end

	local passed, failed = 0, 0
	for _, test in tests do
		local ok, err = pcall(test.Fn)
		if ok then
			passed += 1
		else
			failed += 1
			warn(`[Tests] FAIL {test.Name}: {err}`)
		end
	end

	if failed == 0 then
		print(`[Tests] All {passed} tests passed.`)
	else
		warn(`[Tests] {failed} failed, {passed} passed.`)
	end
	return passed, failed
end

return TestRunner

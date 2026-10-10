--!strict
-- The test runner: `lune run tests/run`. Each spec returns a function that receives `t`.
-- Exit code = number of failures, so CI fails when a check fails.
local process = require("@lune/process")

local passed, failed = 0, 0

local t = {}

function t.check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		print("FAIL " .. name .. (if detail then "  (" .. detail .. ")" else ""))
	end
end

function t.equal(name: string, actual: any, expected: any)
	t.check(name, actual == expected, `got {actual}, expected {expected}`)
end

local specs = {
	require("./specs/Config"),
	require("./specs/Eggs"),
	require("./specs/Properties"),
	require("./specs/Layout"),
	require("./specs/ZFight"),
	require("./specs/Controls"),
	require("./specs/UiScale"),
	require("./specs/HudUi"),
	require("./specs/BaseView"),
	require("./specs/PanelsUi"),
	require("./specs/Trap"),
	require("./specs/TrapsWorld"),
	require("./specs/MutatedEggs"),
	require("./specs/CarryFling"),
	require("./specs/Treadmill"),
	require("./specs/TreadmillLock"),
	require("./specs/PetDisplay"),
	require("./specs/ModelsWorld"),
	require("./specs/Models"),
	require("./specs/Base"),
	require("./specs/Economy"),
	require("./specs/Events"),
	require("./specs/Admin"),
	require("./specs/Limited"),
	require("./specs/Objective"),
	require("./specs/Rebirth"),
	require("./specs/Store"),
	require("./specs/Zones"),
	require("./specs/Progression"),
	require("./specs/Guardian"),
	require("./specs/Game"),
	require("./specs/Wilds"),
	require("./specs/Shop"),
	require("./specs/Purchases"),
	require("./specs/ShopUi"),
	require("./specs/Retention"),
	require("./specs/Prompts"),
	require("./specs/Soak"),
	require("./specs/Fuzz"),
}

for _, spec in specs do
	spec(t)
end

print(`RESULT: {if failed == 0 then "ALL PASS" else "FAILED"} ({passed} passed, {failed} failed)`)
process.exit(if failed == 0 then 0 else 1)

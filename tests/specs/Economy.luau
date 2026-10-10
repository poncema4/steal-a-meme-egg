--!strict
local Economy = require("../../src/shared/Game/Economy")

return function(t)
	t.equal("the first extra slot costs the base price", Economy.slotCost(6, 6, 1000), 1000)
	t.equal("each slot costs 4x the one before", Economy.slotCost(8, 6, 1000), 16000)
	t.equal("offline pays income for the time away", Economy.offline(10, 60, 7200), 600)
	t.equal("offline is capped", Economy.offline(10, 99999, 7200), 72000)
	t.equal("a negative time away pays nothing", Economy.offline(10, -5, 7200), 0)
	t.equal("small numbers print whole", Economy.format(999), "999")
	t.equal("thousands", Economy.format(1500), "1.5K")
	t.equal("round thousands drop the decimals", Economy.format(2000), "2K")
	t.equal("millions", Economy.format(25000000), "25M")
	t.equal("billions with two decimals", Economy.format(1234000000), "1.23B")
	t.equal("zero", Economy.format(0), "0")
end

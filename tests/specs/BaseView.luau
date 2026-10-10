--!strict
local Base = require("../../src/shared/Game/Base")
local BaseView = require("../../src/shared/Game/BaseView")
local Collection = require("../../src/shared/Game/Collection")
local Eggs = require("../../src/shared/Game/Eggs")

return function(t)
	-- the base view
	local base = Base.new(6)
	Base.placeEgg(base, "Soggy")
	Base.placeCharacter(base, "BonkBean", "Gold")
	Base.placeEgg(base, "Golden")
	base.slots[1].hatchLeft = 11.2
	local text = BaseView.encode(base)
	local rows = BaseView.decode(text)
	t.equal("every item is in the view", #rows, 3)
	t.equal("an egg keeps its tier", rows[1].id, "Soggy")
	t.equal("and its time left, rounded up", rows[1].secondsLeft, 12)
	t.equal("a character keeps its id", rows[2].id, "BonkBean")
	t.equal("and its mutation", rows[2].mutation, "Gold")
	t.equal("an empty base is an empty string", BaseView.encode(Base.new(6)), "")
	t.equal("and decodes to no rows", #BaseView.decode(""), 0)
	local garbage = {
		"x",
		";;;",
		"1,e,Nope,5",
		"99,e,Soggy,5",
		"1,c,BonkBean,Evil",
		"1,z,Soggy,5",
		"a,b,c,d",
		"1,e,Soggy,5;1,e,Soggy,5;",
	}
	for _, g in garbage do
		local ok, got = pcall(BaseView.decode, g)
		t.check(`garbage "{g}" is survivable`, ok)
		if ok then
			for _, row in got do
				if row.kind == "egg" and not Eggs.tier(row.id) then
					t.check("garbage never invents an egg", false)
				end
			end
		end
	end
	t.equal("a made-up egg is dropped", #BaseView.decode("1,e,Nope,5"), 0)
	t.equal("a made-up mutation is dropped", #BaseView.decode("1,c,BonkBean,Evil"), 0)
	t.equal("a slot past the base is dropped", #BaseView.decode("99,e,Soggy,5"), 0)
	local long = {}
	for i = 1, 50 do
		table.insert(long, `{(i % 12) + 1},e,Soggy,1`)
	end
	t.check("a huge list is capped at 12 rows", #BaseView.decode(table.concat(long, ";")) <= 12)

	-- the collection
	local c = Collection.new()
	t.equal("a new Index is empty", select(1, Collection.progress(c)), 0)
	local fresh = Collection.record(c, base)
	t.check("a new character is a discovery", fresh)
	t.check("and is remembered", Collection.has(c, "BonkBean"))
	t.check("with its mutation", Collection.hasMutation(c, "BonkBean", "Gold"))
	t.check("but not other mutations", not Collection.hasMutation(c, "BonkBean", "Rainbow"))
	t.check("the same base again is nothing new", not Collection.record(c, base))
	base.slots[2] = nil
	Collection.record(c, base)
	t.check("a character that left the base stays discovered", Collection.has(c, "BonkBean"))
	local found, total = Collection.progress(c)
	t.equal("progress counts characters, not mutations", found, 1)
	t.check("out of every character in the game", total >= 18)
	local again = Collection.decode(Collection.encode(c))
	t.check(
		"saving and loading keeps everything",
		Collection.has(again, "BonkBean") and Collection.hasMutation(again, "BonkBean", "Gold")
	)
	t.equal("encoding is stable", Collection.encode(c), Collection.encode(again))
	local hostile = Collection.decode("BonkBean,Nope,Nope:Gold,BonkBean:Evil,<script>,,:,x:y:z")
	t.equal("a hostile list keeps only the real character", Collection.encode(hostile), "BonkBean")
	t.equal("an empty string is an empty Index", Collection.encode(Collection.decode("")), "")
end

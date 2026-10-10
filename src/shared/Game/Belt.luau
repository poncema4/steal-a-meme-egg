--!strict
-- How fast the treadmill belt runs back under a runner so they stay where they are. The belt matches their run speed exactly,
-- and a gentle correction speeds it up when they creep toward the front edge and slows it when they slip toward the back, so a
-- runner holds the middle of the belt for as long as they like instead of drifting off the end.
local Belt = {}

Belt.CORRECTION = 3 -- extra belt speed (studs per second) for every stud the runner is ahead of the middle
Belt.MIN = 0.4 -- the belt never runs slower than this fraction of the run speed...
Belt.MAX = 1.6 -- ...or faster than this one

-- `walkSpeed`: the runner's WalkSpeed. `ahead`: studs the runner is in front of the belt's middle (negative: behind it).
function Belt.pace(walkSpeed: number, ahead: number): number
	local speed = math.max(walkSpeed, 0)
	return math.clamp(speed + Belt.CORRECTION * ahead, speed * Belt.MIN, speed * Belt.MAX)
end

return Belt

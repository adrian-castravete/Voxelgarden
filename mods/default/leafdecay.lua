-- minetest/default/leafdecay.lua

-- To enable leaf decay for a node, add it to the "leafdecay" group.
--
-- The rating of the group determines how far from a node in the group "tree"
-- the node can be without decaying.
--
-- If param2 of the node is ~= 0, the node will always be preserved. Thus, if
-- the player places a node of that kind, you will want to set param2=1 or so.

default.leafdecay_trunk_cache = {}
default.leafdecay_enable_cache = true
-- Spread the load of finding trunks
default.leafdecay_trunk_find_allow_accumulator = 0

minetest.register_globalstep(function(dtime)
	local finds_per_second = 5000
	default.leafdecay_trunk_find_allow_accumulator =
			math.floor(dtime * finds_per_second)
end)

local function leafupdate(p0)
	for xi = -1, 1 do
	for yi = -1, 1 do
	for zi = -1, 1 do
		if xi == 0 and yi == 0 and zi == 0 then return end
		local p1 = {x=p0.x + xi, y=p0.y + yi, z=p0.z + zi}
		local node = minetest.get_node(p1)
		local range = minetest.registered_nodes[node.name].groups.leafdecay
		if range then
			minetest.after(math.random(1,8), default.leafdecay, p1)
		end
	end
	end
	end
end

default.leafdecay = function(p0)
	--print("leafdecay ABM at "..p0.x..", "..p0.y..", "..p0.z..")")
	local node = minetest.get_node(p0)
	local do_preserve = false
	local def = minetest.registered_nodes[node.name]
	local range = def.groups.leafdecay
	if not range or range == 0 then return end
	local trunk = def.trunk or "group:tree"
	local n0 = minetest.get_node(p0)
	if n0.param2 ~= 0 then
		--print("param2 ~= 0")
		return
	end
	local p0_hash = nil
	if default.leafdecay_enable_cache then
		p0_hash = minetest.hash_node_position(p0)
		local trunkp = default.leafdecay_trunk_cache[p0_hash]
		if trunkp then
			local n = minetest.get_node(trunkp)
			local reg = minetest.registered_nodes[n.name]
			-- Assume ignore is a trunk, to make the thing work at the border of the active area
			if n.name == "ignore" then return end
			if n.name == trunk then return end
			if trunk == "group:tree" and (reg and reg.groups.tree and reg.groups.tree ~= 0) then return end
			--print("cached trunk is invalid")
			-- Cache is invalid
			table.remove(default.leafdecay_trunk_cache, p0_hash)
		end
	end
	if default.leafdecay_trunk_find_allow_accumulator <= 0 then
		return
	end
	default.leafdecay_trunk_find_allow_accumulator =
			default.leafdecay_trunk_find_allow_accumulator - 1
	-- Assume ignore is a trunk, to make the thing work at the border of the active area
	local p1 = minetest.find_node_near(p0, range, {"ignore", trunk})
	if p1 then
		do_preserve = true
		if default.leafdecay_enable_cache then
			--print("caching trunk")
			-- Cache the trunk
			default.leafdecay_trunk_cache[p0_hash] = {p1, trunk}
		end
	end
	if not do_preserve then
		-- Drop stuff other than the node itself
		itemstacks = minetest.get_node_drops(n0.name)
		for _, itemname in ipairs(itemstacks) do
			if itemname ~= n0.name then
				local p_drop = {
					x = math.floor(p0.x + 0.5),
					y = math.floor(p0.y + 0.5),
					z = math.floor(p0.z + 0.5),
				}
				spawn_falling_node(p_drop, {name=itemname})
			end
		end
		-- Remove node
		minetest.remove_node(p0)
		nodeupdate(p0)
		leafupdate(p0)
	end
end

minetest.register_abm({
	nodenames = {"group:leafdecay"},
	neighbors = {"air", "group:liquid"},
	-- A low interval and a high inverse chance spreads the load
	interval = 5,
	chance = 90,

	action = function(p0, node, _, _)
		default.leafdecay(p0)
	end
})

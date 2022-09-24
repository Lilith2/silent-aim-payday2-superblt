-- Silent aimbot / Cops are bullet magnets
-- Author: rogerxiii / DvD
 
local target_closest = true				-- Set to true if you want to target the enemy that is closest to your crosshair instead of just any
local shoot_through_wall = false		-- Set to true if you want to target enemies through walls		NOTE: This does not give you the ability to shoot through walls!
local shoot_through_wall_thickness = 40	-- Set the value of through how many things you can shoot, 40 is a normal wall
local fov_only = 90					-- Set to a value between 0-360 if you want to only shoot within a certain amount of degrees, false if shoot everywhere
 
-----------------------------------------------------------------------------------------------------------------------------------------------
 
-- Activation
active = not active
managers.hud:show_hint({text = active and "Aimbot Activated" or "Aimbot Deactivated"})
 
function calculate_angle(unit)
	-- Initialize vars
	local player = Vector3()
	local enemy = Vector3()
	local dir = Vector3()
	
	-- Set initial vectors
	mvector3.set(player, managers.player:player_unit():camera():position())
	mvector3.set(enemy, unit:movement():m_head_pos())
	
	-- Calculate difference vector
	mvector3.set(dir, player)
	mvector3.subtract(dir, enemy)
	mvector3.normalize(dir)
 
	-- Calculate direction
	local newx, newy, newz = dir.x, dir.y, dir.z
	if player.x > enemy.x or (player.x < enemy.x and newx < 0) then newx = newx * -1 end
	if player.y > enemy.y or (player.y < enemy.y and newy < 0) then newy = newy * -1 end
	if player.z > enemy.z or (player.z < enemy.z and newz < 0) then newz = newz * -1 end
	mvector3.set(dir, Vector3(newx, newy, newz))
	
	return dir
end
 
function get_target(pthis)
	-- Initialize vars
	local from = managers.player:player_unit():camera():position()
	local current = managers.player:player_unit():camera():forward()
	local best = nil
	local closest = 100000
	
	for _,ene in pairs(managers.enemy:all_enemies()) do
		if ene.unit and ene.unit:movement() and not ene.unit:brain():surrendered() 
					and (ene.unit:brain()._logic_data and not ene.unit:brain()._logic_data.is_converted or true) then
			local to = ene.unit:movement():m_head_pos()
			local ray = nil
			local ray_hits = nil
			
			-- Determine whether or not this weapon can shoot through shields (explosive bullets, etc.)
			old_can_shoot = pthis._can_shoot_through_shield
			for _,cat in pairs(tweak_data.weapon[pthis._name_id].categories) do
				if cat == "grenade_launcher" then pthis._can_shoot_through_shield = true end
			end
			if pthis._bullet_class.id == "explosive" or pthis._bullet_class.id == "dragons_breath" then pthis._can_shoot_through_shield = true end
			
			-- Get hits of ray to head
			if shoot_through_wall or pthis._can_shoot_through_wall then
				ray_hits = World:raycast_wall("ray", from, to, "slot_mask", pthis._bullet_slotmask, "ignore_unit", pthis._setup.ignore_units, 
					"thickness", (shoot_through_wall and shoot_through_wall_thickness or 40), "thickness_mask", managers.slot:get_mask("world_geometry", "vehicles"))
			else ray_hits = World:raycast_all("ray", from, to, "slot_mask", pthis._bullet_slotmask, "ignore_unit", pthis._setup.ignore_units) end
			
			-- Decide whether we can hit this enemy or not
			for _, hit in ipairs(ray_hits) do
				if hit.unit:key() == ene.unit:key() then ray = hit; break end
				if not shoot_through_wall then
					if not pthis._can_shoot_through_wall and hit.unit:in_slot(managers.slot:get_mask("world_geometry", "vehicles")) then break
					elseif not pthis._can_shoot_through_shield and hit.unit:in_slot(managers.slot:get_mask("enemy_shield_check")) then break end
				end
			end
			
			-- Reset changed penetration value
			pthis._can_shoot_through_shield = old_can_shoot
			
			if ray and ray.unit and ray.unit:key() == ene.unit:key() then
				-- Calculate needed angle and compare shortest if needed
				local dir = calculate_angle(ene.unit)
				if not target_closest then return dir end
				
				local distance = mvector3.distance(current, dir)
				if distance < closest and (fov_only and (distance / 2 * 360) <= fov_only or not fov_only) then
					closest = distance
					best = dir
				end
			end
		end
	end
	
	return best
end
 
old_fire = old_fire or NewRaycastWeaponBase.fire
function NewRaycastWeaponBase:fire(from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul, target_unit)
	local dir = nil
	if active and self._setup.user_unit == managers.player:player_unit() then dir = get_target(self) end
	if dir then return old_fire(self, from_pos, dir, dmg_mul, shoot_player, 0, autohit_mul, suppr_mul, target_unit) end
	return old_fire(self, from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul, target_unit)
end


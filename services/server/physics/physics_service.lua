local Point3 = _radiant.csg.Point3
local Transform = _radiant.csg.Transform
local MobEnums = _radiant.om.Mob
local log = radiant.log.create_logger('physics')

local Sky_Lands_PhysicsService = class()

function Sky_Lands_PhysicsService:_move_entity(entity)
   local mob = entity:get_component('mob')
   if not mob then
      return false
   end

   local location = radiant.entities.get_world_grid_location(entity)
   if not location then
      return false
   end

   if not mob:get_in_free_motion() then
      log:debug('taking %s out of free motion', entity)
      return false
   end

   -- Accleration due to gravity is 9.8 m/(s*s).  One block is one meter.
   -- You do the math (oh wait.  there isn't any! =)
   local acceleration = 9.8 / _radiant.sim.get_game_tick_interval();

   -- Update velocity.  Terminal velocity is currently 1-block per tick
   -- to make it really easy to figure out where the thing lands.
   local velocity = mob:get_velocity()

   log:debug('adding %.2f to %s current velocity %s', acceleration, entity, velocity)

   velocity.position.y = velocity.position.y - acceleration;
   velocity.position.y = math.max(velocity.position.y, -1.0);

   -- Update position
   local current = mob:get_transform()
   local nxt = Transform()
   nxt.position = current.position + velocity.position
   nxt.orientation = current.orientation

   -- when testing to see if we're blocked, make sure we look at the right point.
   -- `is_standable` will round to the closest int, so if we're at (1, -0.3, 1), it
   -- will actually test the point (1, 0, 1) when we wanted (1, -1, 1) !!
   local test_position = nxt.position - Point3(0, 0.5, 0)

   -- If our next position is blocked, fall to the bottom of the current
   -- brick and clear the free motion flag.
   local mob_collision_type = mob:get_mob_collision_type()
   local can_fall_through_ladders = (mob_collision_type == MobEnums.TINY or mob_collision_type == MobEnums.HUMANOID) and not mob:get_has_free_will()

   local next_position_standable = false
   if can_fall_through_ladders then
      next_position_standable = _physics:is_blocked(entity, test_position)
   else
      next_position_standable = _physics:is_standable(entity, test_position)
   end

   if next_position_standable then
      log:debug('%s next position %s is standable.  leaving free motion', entity, test_position)

      velocity.position = Point3.zero
      if can_fall_through_ladders then
         nxt.position.y = math.floor(current.position.y)
      else
         nxt.position.y = math.floor(test_position.y)
      end
      mob:set_in_free_motion(false)
   else
      log:debug('%s next position %s is not standable.  staying in free motion', entity, test_position)
   end

   local in_bounds = radiant.terrain.in_bounds(nxt.position)
   if not in_bounds then
      local pos_no_y = Point3(nxt.position.x, 0, nxt.position.z)
      local new_pos = radiant.terrain.get_point_on_terrain(pos_no_y)
      log:error('%s is at location: %s, which is not in bounds of the terrain. Placing it at %s', entity, nxt.position, new_pos)
      nxt.position.x = new_pos.x
      nxt.position.y = new_pos.y
      nxt.position.z = new_pos.z
      velocity.position = Point3.zero
      mob:set_in_free_motion(false)
      if new_pos.y < 1 then
         radiant.entities.destroy_entity(entity)
         log:error('%s was destroyed by Sky Lands mod because its new Y position was %s (in the void)', entity, new_pos.y)
         return
      end
   end

   -- Update our actual velocity and position.  Return false if we left
   -- the free motion state to get the task pruned
   mob:set_velocity(velocity);
   mob:set_transform(nxt);
   log:debug('%s new transform: %s  new velocity: %s', entity, nxt.position, velocity.position)

   return mob:get_in_free_motion()
end

return Sky_Lands_PhysicsService
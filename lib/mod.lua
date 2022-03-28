local mod = require 'core/mods'
local script = require 'core/script'


-- -------------------------------------------------------------------------
-- HELPERS - CORE

-- utility to clone function
local function clone_function(fn)
  local dumped=string.dump(fn)
  local cloned=load(dumped)
  local i=1
  while true do
    local name=debug.getupvalue(fn,i)
    if not name then
      break
    end
    debug.upvaluejoin(cloned,i,fn,i)
    i=i+1
  end
  return cloned
end


-- -------------------------------------------------------------------------
-- HELPERS - NETWORK

local function getHostname()
  local f = io.popen ("/bin/hostname")
  local hostname = f:read("*a") or ""
  f:close()
  hostname =string.gsub(hostname, "\n$", "")
  return hostname
end

local function isValidIp(ip)
  local chunks = {ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
  if (#chunks == 4) then
    for _,v in pairs(chunks) do
      if (tonumber(v) < 0 or tonumber(v) > 255) then
        return false
      end
    end
    return true
  end
  return false
end



-- -------------------------------------------------------------------------
-- STATE

local state = {
  hostname = nil,
  dest_ip = "10.0.1.26",
  dest_port = "10101",
  send = true,
  is_loading_script = nil,
  logging = false;
}


-- -------------------------------------------------------------------------
-- MAIN

local function enrich_param_actions()
  for p_name, p_id in pairs(params.lookup) do
    local p = params.params[p_id]
    if p ~= nil and p.osc_casted == nil then -- edge case where sync issue between `params.lookup` & `params.params`
      p.osc_casted = true
      p.og_action = clone_function(p.action)
      p.action = function(x)
        if (state.send) then
          --local path = "/param/"..state.hostname.."/"..p.id
          local path = "/param/".. p.id
          if isValidIp(state.dest_ip) then
            if (logging) then
              print("sending osc to "..state.dest_ip..": "..path.." = "..x)
            end
            osc.send({state.dest_ip, state.dest_port}, path, {x})
          else
            --print("sending osc: "..path.." = "..x)
            --print("Param 'osc-cast IP' not set or invalid, not sending")
          end
          p.og_action(x)
        end
      end
    end
  end
end

mod.hook.register("system_post_startup", "osc-cast-sys-startup", function ()
    state.system_post_startup = true
    state.hostname = getHostname()
    local script_clear = script.clear
    script.clear = function()
      script_clear()

      local is_restart = (tab.count(params.lookup) == 0)
      
      if is_restart then
        print("mod - osc-cast - clear at (re)start")
      end

      enrich_param_actions()

    end
end)

mod.hook.register("script_pre_init", "osc-cast-pren-init", function()
    local script_init = init
    init = function ()
      script_init()

      print("mod - osc-cast - init")

      enrich_param_actions()

      state.is_loading_script = nil
    end
end)

mod.hook.register("script_post_cleanup", "osc-cast-cleanup", function()
    print("mod - osc-cast - script post cleanup")
    -- state.is_loading_script = true
end)


local m = {}

m.key = function(n, z)
  if n == 2 and z == 1 then
    -- return to the mod selection menu
    mod.menu.exit()
  end
end

m.enc = function(n, d)
  if n == 2 then 
  
  elseif n == 3 then 
      if (state.send) then 
        state.send = false
      else
        state.send = true
      end
  end
  -- tell the menu system to redraw, which in turn calls the mod's menu redraw
  -- function
  mod.menu.redraw()
end

m.redraw = function()
  screen.clear()
  screen.move(10,8)
  screen.text("OSC-CAST")
  screen.move(10,16)
  screen.text("Destination: " .. state.dest_ip .. "/" .. state.dest_port)
  screen.move(10,40)
  if (state.send) then 
    issending = "on"
  else
    issending = "off"
  end
  
  screen.text("Sending: " .. issending)
  screen.update()
end

m.init = function() end -- on menu entry, ie, if you wanted to start timers
m.deinit = function() end -- on menu exit

-- register the mod menu
--
-- NOTE: `mod.this_name` is a convienence variable which will be set to the name
-- of the mod which is being loaded. in order for the menu to work it must be
-- registered with a name which matches the name of the mod in the dust folder.
--
mod.menu.register(mod.this_name, m)

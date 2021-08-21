local mod = require 'core/mods'


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
  dest_ip = "",
}


-- -------------------------------------------------------------------------
-- MAIN

mod.hook.register("system_post_startup", "osc-cast-sys-startup", function ()
                    state.hostname = getHostname()
end)

mod.hook.register("script_pre_init", "osc-cast", function()
                    local script_init = init
                    init = function ()
                      script_init()
                      print("mod - osc-cast - init")

                      params:add_separator("MOD - OSC-CAST")
                      params:add_text("osc_cast_ip", "osc-cast IP", "")

                      for p_name, p_id in pairs(params.lookup) do
                        local p = params.params[p_id]
                        p.og_action = clone_function(p.action)
                        p.action = function(x)
                          local path = "/param/"..state.hostname.."/"..p.id
                          if isValidIp(state.dest_ip) then
                            print("sending osc to "..state.dest_ip..": "..path.." = "..x)
                            osc.send(state.dest_ip, path, x)
                          else
                            -- print("Param 'osc-cast IP' not set or invalid, not sending")
                          end
                          p.og_action(x)
                        end
                      end
                    end

end)

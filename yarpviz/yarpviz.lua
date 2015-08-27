#!/usr/bin/lua 

-- Copyright: (C) 2015 iCub Facility - Italian Institute of Technology (IIT)
-- Author: Ali Paikan <ali.paikan@iit.it>
-- Copy Policy: Released under the terms of the LGPLv2.1 or later, see LGPL.TXT


-- LUA_CPATH should have the path to yarp-lua binding library (i.e. yarp.so, yarp.dll) 
require("yarp")

-- initialize yarp network
yarp.Network()


--
-- print_error
--

function print_error(msg)
    if package.config:sub(1,1) == "/" then  -- an ugly way to determine the platform (pooof!)
        print("\27[91m[ERROR]\27[0m "..msg)
    else
        print("[ERROR] "..msg)
    end    
end


--
-- splits string by a text delimeter
--
function string:split(inSplitPattern, outResults)
   if not outResults then
      outResults = { }
   end
   local theStart = 1
   local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
   while theSplitStart do
      table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
      theStart = theSplitEnd + 1
      theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
   end
   table.insert( outResults, string.sub( self, theStart ) )
   return outResults
end

--
--  gets a list of the yarp ports
--
function yarp_name_list() 
  local style = yarp.ContactStyle()
  style.quiet = true
  style.timeout = 3.0

  local cmd = yarp.Bottle()
  local reply = yarp.Bottle()
  cmd:addString("list")
  local ret = yarp.NetworkBase_writeToNameServer(cmd, reply, style)
  if ret == false or reply:size() ~= 1 then
    print_error("Error")
  end

  local str = reply:get(0):asString()
  local fields = str:split("registration name /")
  ports_map = {}
  for i = 1, #fields do
     local s = fields[i]
     local name = s:split("ip")
     name = name[1]:gsub("^%s*(.-)%s*$", "%1")
     if name ~= "" then
       name = "/"..name
       if name ~= yarp.NetworkBase_getNameServerName() then 
         ports_map[name] = "P"..i
       end     
     end     
  end
  return ports_map
end

function get_port_con(port_name, with_owners)
  local ping = yarp.Port()  
  ping:open("/anon_rpc");  
  ping:setAdminMode(true)
  local ret = yarp.NetworkBase_connect(ping:getName(), port_name)
  if ret == false then
      print_error("Cannot connect to " .. port_name)
      return nil, nil, nil
  end

  --getting output list
  local cmd = yarp.Bottle()
  local reply = yarp.Bottle()
  cmd:addString("list")
  cmd:addString("out")  
  if ping:write(cmd, reply) == false then
      print_error("(getting out list) Cannot write to " .. port_name)
      ping:close()
      return nil, nil, nil
  end  
  outs_list = {}
  outs_carlist = {}
  for i=0,reply:size()-1 do 
    out_name = reply:get(i):asString()
    outs_list[#outs_list+1] = out_name
    -- getting the carrier
    cmd:clear()
    local reply2 = yarp.Bottle()
    cmd:addString("list")
    cmd:addString("out")
    cmd:addString(out_name)
    if ping:write(cmd, reply2) == false then
      print_error("(getting carrier) Cannot write to " .. port_name)
      ping:close()
      return nil, outs_list, nil 
    end
    outs_carlist[#outs_carlist+1] = reply2:find("carrier"):asString()
  end 

  -- getting input list
  cmd:clear()
  reply:clear()
  cmd:addString("list")
  cmd:addString("in")  
  if ping:write(cmd, reply) == false then
      print_error("(getting in list) Cannot write to " .. port_name)
      ping:close()
      return nil, outs_list, outs_carlist
  end  
  ins_list = {}
  for i=0,reply:size()-1 do 
    ins_list[#ins_list+1] = reply:get(i):asString()
  end 

  -- getting port owner name 
  if with_owners ~= nil and with_owners == true then 
      cmd:clear()
      reply:clear()
      cmd:addString("prop")
      cmd:addString("get") 
      cmd:addString(port_name) 
      if ping:write(cmd, reply) == false then
          print_error("(geting owner) Cannot write to " .. port_name)
          ping:close()
          return nil, ins_list, outs_list, outs_carlist
      end  
      proc = reply:findGroup("process")
      if proc ~= nil and proc:isNull() == false then
          proc_prop = proc:get(1):asDict()
          owner = {}
          owner["name"] = proc_prop:find("name"):asString()
          owner["arguments"] = proc_prop:find("arguments"):asString()
          owner["pid"] = proc_prop:find("pid"):asInt()
          ping:close()
          return ins_list, outs_list, outs_carlist, owner   
      else
          print_error("(geting owner) cannot find group 'process' in prop get!")
      end
  end
  ping:close()
  return ins_list, outs_list, outs_carlist
end

---------------------------------------------------------------------
---  main 
---------------------------------------------------------------------

param = ""
for i=1,#arg do
  param = param .. arg[i] .. " "
end
prop = yarp.Property()
prop:fromArguments(param)

if prop:check("help") then
  print("Usage: yarpviz.lua [OPTIONS]\n")
  print("Known values for OPTION are:\n")
  print("  --type <output_type>\t Output type: x11, pdf, eps, svg, jpg, png, txt (default: x11)")
  print("  --out  <output_name>\t Output file name (default: output.txt)")
  print("  --gen  <generator>  \t Graphviz-based graph generator: dot, neato, twopi, circo (default: dot)")
  print("  --nodesep <value>   \t Specifies the minimum vertical distance between the adjacent nodes  (default: 0.4)")
  print("  --ranksep <value>   \t Specifies the minimum distance between the adjacent nodes (default: 0.5)")
  print("\nWith the default output type (x11), it opens an X11 window to renders the graph. This is not available on ")
  print("a Windows machine. However, you can allways render the graph in other formats (e.g., jpg).")

--  print("  --all-ports         \t Shows all the ports even without any connection")
  os.exit()
end

os.execute("yarp clean --timeout 0.2")

local ports = yarp_name_list()

typ = "x11"
if prop:check("type") then typ = prop:find("type"):asString() end
if typ == "txt" then 
    -- creating dot file
    local filename = "output.txt"
    if prop:check("out") then filename = prop:find("out"):asString() end
    local file = io.open(filename, "w")
    if file == nil then
      print_error("cannot open", filename)
      os.exit()
    end 

    for name,node in pairs(ports) do   
       print("checking "..name.." ...")
       local ins, outs, cars = get_port_con(name, "out")
       if outs ~= nil then
           for i=1,#outs do       
             file:write(name..", "..outs[i]..", "..cars[i].."\n")
           end
       end    
    end
    file:close()
    os.exit()
end

-- creating dot file
local filename = "output."..typ
if prop:check("out") then filename = prop:find("out"):asString() end
local file = io.open(filename..".dot", "w")
if file == nil then
  print_error("cannot open", filename..".dot")
  os.exit()
end  
  
ranksep = 0.5
nodesep = 0.4

if prop:check("ranksep") then 
    ranksep = prop:find("ranksep"):asDouble()
end
if prop:check("nodesep") then 
    nodesep = prop:find("nodesep"):asDouble()
end    

digraph = "digraph \"\" {\n  nodesep="..nodesep..";\n  ranksep="..ranksep..";\n"
file:write(digraph)

dot_header = [[
  graph [rankdir="LR", overlap="false", packmode="graph", fontname="helvetica", fontsize="10", concentrate="true", bgcolor="#2e3e56"];
  node [style="filled", color="#edad56", fillcolor="#edad56", label="", sides="4", fontcolor="#333333", fontname="helvetica", fontsize="10", shape="cds"];
  edge [penwidth=1.5, color="#FFFFFF", label="", fontname="Arial", fontsize="8", fontcolor="#555555"];]]
  
file:write(dot_header.."\n")

processes = {}
owner_inputs = {}
owner_outputs = {}
for name,node in pairs(ports) do 
    local ins, outs, cars, owner = get_port_con(name, true)
    if owner ~= nil then
        owner["outputs"] = {}
        owner["inputs"] = {}
    end        
    if prop:check("all-ports") ~= true then        
        if ins ~= nil and outs ~= nil then 
            if #outs ~= 0 or #ins ~=1 then
                file:write(node.." [label=\""..name.."\"]\n")
                if owner ~= nil then 
                    if #outs ~= 0 then 
                        owner_outputs[node] = owner["pid"]
                    else
                        owner_inputs[node] = owner["pid"]
                    end
                    processes[owner["pid"]] = owner
                end                    
            end 
        end    
     else
        file:write(node.." [label=\""..name.."\"]\n")
    end       
end

-- adding owner (process) shapes
for pid,info in pairs(processes) do 
    file:write(pid.." [label=\""..info["name"].."\\n"..info["arguments"].."\", shape=\"component\", color=\"#a5cf80\",  fillcolor=\"#a5cf80\"]\n")
end

-- adding ports to the owner
for node,pid in pairs(owner_outputs) do 
    file:write(pid.." -> "..node.." [penwidth=1.0, style=\"dashed\", color=\"#8c8c8c\"]\n")
end

for node,pid in pairs(owner_inputs) do 
    file:write(node.." -> "..pid.." [penwidth=1.0, style=\"dashed\", color=\"#8c8c8c\"]\n")
end

-- adding connection links
for name,node in pairs(ports) do   
   print("checking "..name.." ...")
   local ins, outs, cars = get_port_con(name, "out")
   if outs ~= nil then 
       for i=1,#outs do
         local to = ports[outs[i]]
         if to ~= nil then
            file:write(node.." -> "..to.."[weight=0.1]\n")
         end   
       end
   end    
end

file:write("}\n")
file:close()


gen = "dot"
if prop:check("gen") then gen = prop:find("gen"):asString() end

-- rendering
os.execute(gen.." -T"..typ.." -o "..filename.." "..filename..".dot")

-- Deinitialize yarp network
yarp.Network_fini()

#!/usr/bin/lua 

-- Copyright: (C) 2015 iCub Facility - Italian Institute of Technology (IIT)
-- Author: Ali Paikan <ali.paikan@iit.it>
-- Copy Policy: Released under the terms of the LGPLv2.1 or later, see LGPL.TXT


-- LUA_CPATH should have the path to yarp-lua binding library (i.e. yarp.so, yarp.dll) 
require("yarp")

-- initialize yarp network
yarp.Network()



-----------------------------------------------
-- helper functions
-----------------------------------------------
function table.count(a) 
    local cnt = 0
    for i,v in pairs(a) do cnt = cnt+1 end
    return cnt
end

-----------------------------------------------
-- Class Edge
-----------------------------------------------
local Edge = {}
Edge.__index = Edge

setmetatable(Edge, {
    __call = function (cls, ...)
    return cls.new(...)
    end,
})

function Edge.new(from, to, uid, label)
    local self = setmetatable({}, Edge)
    self.from = from
    self.to = to
    self.label = label
    self._uid = uid
    return self
end

function Edge:get_from() return self.from  end
function Edge:get_to() return self.to end
function Edge:get_label() return self.label  end
function Edge:set_label(label) self.label = label end
function Edge:uid() return self._uid end



-----------------------------------------------
-- Class Node
-----------------------------------------------
local Node = {}
Node.__index = Node

setmetatable(Node, {
    __call = function (cls, ...)
    return cls.new(...)
    end,
})

function Node.new(uid, label)
    local self = setmetatable({}, Node)
    self._uid = uid
    self.label = label
    self.visited = false
    self.inputs = {}
    self.outputs = {}
    return self
end

function Node:uid() return self._uid end
function Node:get_label() return self.label  end
function Node:is_leaf() return (table.count(self.outputs) == 0) end
function Node:is_orphan() return (table.count(self.inputs) == 0) end
function Node:add_input(edge) self.inputs[edge:uid()] = edge end
function Node:add_output(edge) self.outputs[edge:uid()] = edge end

function Node:remove_input(edge) self.inputs[edge:uid()] = nil end
function Node:remove_output(edge) self.outputs[edge:uid()] = nil end
function Node:get_inputs() return self.inputs end
function Node:get_outputs() return self.outputs end
function Node:set_visited(flag) self.visited = flag end
function Node:is_visited(flag) return self.visited end

function Node:all_child_leaves()
    if table.count(self.outputs) == 0 then return false end    
    for uid,edge in pairs(self.outputs) do
        if not edge:get_to():is_leaf() then return false end
    end
    return true
end

function Node:all_parent_orphans() 
    if table.count(self.inputs) == 0 then return false end
    for uid,edge in pairs(self.inputs) do
        if not edge:get_from():is_orphan() then return false end
    end
    return true
end



-----------------------------------------------
-- Class Graph
-----------------------------------------------
local Graph = {}
Graph.__index = Graph

setmetatable(Graph, {
    __call = function (cls, ...)
    return cls.new(...)
    end,
})

function Graph.new()
    local self = setmetatable({}, Graph)
    self.nodes = {}
    self.edges = {}
    return self
end

function Graph:add_node(node)
    self.nodes[node:uid()] = node
end

function Graph:add_edge(edge)
    self.edges[edge:uid()] = edge
end

function Graph:create_node(uid, label) 
    local node = self.get_node_by_uid(self, uid) 
    if node ~= nil then return node end
    node = Node(uid, label)
    self.nodes[node:uid()] = node
    return self.nodes[node:uid()]
end

function Graph:delete_node(node) self.nodes[node] = nil end
function Graph:get_nodes() return self.nodes end
function Graph:get_edges() return self.edges end

function Graph:clear() 
    self.nodes = {}
    self.edges = {}
end

function Graph:connect(node1, node2, label)
    local uid = node1:uid()..node2:uid()
    local e = Edge(node1, node2, uid, label)
    node1:add_output(e)
    node2:add_input(e)
    self.edges[e:uid()] = e
end

function Graph:disconnect(node1, node2)
    outs = node1:get_outputs()
    ins  = node2:get_inputs()
    for uid,edge in pairs(outs) do
        if edge:get_to() == node2 then 
            node1:remove_output(edge)
            node2:remove_input(edge)
            self.edges[edge:uid()] = nil
            break
        end
    end
end

function Graph:get_node_by_uid(uid)
    return self.nodes[uid]
end

function Graph:get_subgraph(node, new_graph)
    -- get all child nodes
    if(node:is_visited() == true) then return end
    node:set_visited(true)
    new_graph:add_node(node)    
    for uid,edge in pairs(node:get_outputs()) do
        new_graph:add_edge(edge)
        Graph:get_subgraph(edge:get_to(), new_graph)
    end
    for uid,edge in pairs(node:get_inputs()) do
        new_graph:add_edge(edge)
        Graph:get_subgraph(edge:get_from(), new_graph)
    end
end

function print_graph(g) 
    for uid,node in pairs(g:get_nodes()) do
        if node:get_label().type == "process" then
            print(node:get_label().name.." (".. node:get_label().arguments..")")
        else
            print(node:get_label().name)
        end            
        print(" |")
        print(" |_ Outputs:")
        for uid, edge in pairs(node:get_outputs()) do 
        print(" |         |_ "..edge:get_to():get_label().name)
        end
        print(" |")
        print(" |_ Inputs :")
        for uid, edge in pairs(node:get_inputs()) do 
        print(" |         |_ "..edge:get_from():get_label().name)
        end
        print("")
    end
end


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
-- print_warning
--
function print_warning(msg)
    if package.config:sub(1,1) == "/" then  -- an ugly way to determine the platform (pooof!)
        print("\27[93m[WARNING]\27[0m "..msg)
    else
        print("[WARNING] "..msg)
    end    
end


--
-- print_info
--
function print_info(msg)
    if package.config:sub(1,1) == "/" then  -- an ugly way to determine the platform (pooof!)
        print("\27[92m[INFO]\27[0m "..msg)
    else
        print("[INFO] "..msg)
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
    print_error("Cannot write to YARP name server")
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
  ping:open("...");  
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
    if reply:get(i):asString() ~= ping:getName() then
        ins_list[#ins_list+1] = reply:get(i):asString()
    end    
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
          owner["priority"] = proc_prop:find("priority"):asInt()
          owner["policy"] = proc_prop:find("policy"):asInt()

          platform = reply:findGroup("platform")
          if platform ~= nil and platform:isNull() == false then
              platform_prop = platform:get(1):asDict()
              owner["os"] = platform_prop:find("os"):asInt()
              owner["hostname"] = platform_prop:find("hostname"):asInt()
          else
              print_warning("(geting owner) cannot find group 'platform' in prop get!")
          end
          ping:close()
          return ins_list, outs_list, outs_carlist, owner   
      else
          print_error("(geting owner) cannot find group 'process' in prop get!")
      end
  end
  ping:close()
  return ins_list, outs_list, outs_carlist
end


function generate_text_output(graph)
    local filename = "output.txt"
    if prop:check("out") then filename = prop:find("out"):asString() end
    local file = io.open(filename, "w")
    if file == nil then
      print_error("cannot open", filename)
      return false
    end 

    edges = graph:get_edges()
    for uid,edge in pairs(edges) do
        if edge:get_label().type == "connection" then 
            local from = edge:get_from()
            local to = edge:get_to()
            local carrier = edge:get_label().carrier
            file:write(from:get_label().name..", "..to:get_label().name..", "..carrier.."\n")
        end
    end
    file:close()
    return true
end

function generate_dot_output(graph)
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

    local only_cons = prop:check("only-cons")

    -- write graphviz nodes
    nodes = graph:get_nodes()
    for uid,node in pairs(nodes) do
        local label = node:get_label()
        if label.type == "process" then
            if only_cons == true then                
                if not (node:is_orphan() and node:all_child_leaves())then
                    file:write(label.gv_label.." [label=\""..label.name.."\\n"..label.arguments.."\", shape=\"component\", color=\"#a5cf80\",  fillcolor=\"#a5cf80\"]\n")
                end
            else
                --print(label.name.." ("..label.arguments..")", node:is_orphan(), node:all_child_leaves())
                file:write(label.gv_label.." [label=\""..label.name.."\\n"..label.arguments.."\", shape=\"component\", color=\"#a5cf80\",  fillcolor=\"#a5cf80\"]\n")
            end
        elseif label.type == "port" then
            if only_cons == true then
                if not node:is_leaf() and not node:is_orphan() then
                    file:write(label.gv_label.." [label=\""..label.name.."\"]\n")
                end
            else
                file:write(label.gv_label.." [label=\""..label.name.."\"]\n")
            end                
        end
    end
    -- wrtie graphviz links
    edges = graph:get_edges()
    for uid,edge in pairs(edges) do
        local from = edge:get_from()
        local to = edge:get_to()
        if edge:get_label().type == "connection" then 
            local carrier = edge:get_label().carrier
            file:write(from:get_label().gv_label.." -> "..to:get_label().gv_label.."[weight=0.1]\n")
        elseif edge:get_label().type == "ownership" then 
            if only_cons == true then            
                --print(from:get_label().name.." -> "..to:get_label().name, from:is_orphan(), to:is_leaf())
                if not ((to:get_label().type == "port") and to:is_leaf()) then 
                    file:write(from:get_label().gv_label.." -> "..to:get_label().gv_label.." [penwidth=1.0, style=\"dashed\", color=\"#8c8c8c\"]\n")
                end
            else
                file:write(from:get_label().gv_label.." -> "..to:get_label().gv_label.." [penwidth=1.0, style=\"dashed\", color=\"#8c8c8c\"]\n")
            end
        elseif edge:get_label().type == "ownership_unknown" then 
            if only_cons == true then
                if not ((to:get_label().type == "port") and to:is_leaf()) then 
                    file:write(from:get_label().gv_label.." -> "..to:get_label().gv_label.." [penwidth=1.0, style=\"dotted\", arrowhead=\"none\" color=\"#ff4444\"]\n")
                end
            else
                file:write(from:get_label().gv_label.." -> "..to:get_label().gv_label.." [penwidth=1.0, style=\"dotted\", arrowhead=\"none\" color=\"#ff4444\"]\n")
            end  
       end
    end

    file:write("}\n")
    file:close()

    -- rendering
    gen = "dot"
    if prop:check("gen") then gen = prop:find("gen"):asString() end
    os.execute(gen.." -T"..typ.." -o "..filename.." "..filename..".dot")
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
  print("  --filter <port_name>\t Create graph of connections which are related to specific port")
  print("  --type <output_type>\t Output type: x11, pdf, eps, svg, jpg, png, txt (default: x11)")
  print("  --out  <output_name>\t Output file name (default: output.txt)")
  print("  --gen  <generator>  \t Graphviz-based graph generator: dot, neato, twopi, circo (default: dot)")
  print("  --nodesep <value>   \t Specifies the minimum vertical distance between the adjacent nodes  (default: 0.4)")
  print("  --ranksep <value>   \t Specifies the minimum distance between the adjacent nodes (default: 0.5)")
--  print("  --only-cons         \t Shows only ports with connection")
  print("\nWith the default output type (x11), it opens an X11 window to renders the graph. This is not available on ")
  print("a Windows machine. However, you can allways render the graph in other formats (e.g., jpg).")
  os.exit()
end


-- force yarp clean
os.execute("yarp clean --timeout 0.2")

-- get the ports list
local ports = yarp_name_list()

-- generate the graph
local graph = Graph()

for name,label in pairs(ports) do
    local node = {}
    node.type = "port"
    node.name = name
    node.gv_label = label
    graph:create_node(node.name, node)
end

-- create links between nodes
for name,label in pairs(ports) do
    local ins, outs, cars, owner = get_port_con(name, true)
    local node = graph:get_node_by_uid(name)
    -- create node for the port owner
    if owner ~= nil then 
        local p_node = {}
        p_node.type = "process"
        p_node.name = owner["name"]
        p_node.arguments = owner["arguments"]
        p_node.gv_label = owner["pid"]
        owner_node = graph:create_node(owner["pid"], p_node)    

        -- create link between port and its owner
        elab_owner = {}
        elab_owner.type = "ownership"
        if #outs ~= 0 then             
            graph:connect(owner_node, node, elab_owner)
        elseif #ins ~= 0 then 
            graph:connect(node, owner_node, elab_owner)            
        else
            elab_owner.type = "ownership_unknown"
            graph:connect(owner_node, node, elab_owner)
        end
    end
    -- create link between port and its output
    if outs ~= nil then
        for i=1,#outs do 
            local elab_out = {}
            elab_out.type = "connection"
            elab_out.cars = "unknown"
            if cars[i] ~= nil then elab_out.carrier = cars[i] end
            local node2 = graph:get_node_by_uid(outs[i])
            if node2 ~= nil then
                graph:connect(node, node2, elab_out)
            end
        end
    end        
end


if prop:check("filter") then 
    local portname = prop:find("filter"):asString() 
    new_graph = Graph()
    local n = graph:get_node_by_uid(portname)
    if n == nil then
        print_error("Cannot find any port called '"..portname.."'!")
        os.exit()
    end
    graph:get_subgraph(n, new_graph)
    graph = new_graph
end

typ = "x11"
if prop:check("type") then typ = prop:find("type"):asString() end

-- generating plain text file
if typ == "txt" then
    generate_text_output(graph)
    os.exit()
else
    generate_dot_output(graph)
end


-- Deinitialize yarp network
yarp.Network_fini()


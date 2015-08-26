#!/usr/bin/lua 

-- Copyright: (C) 2011 Robotics, Brain and Cognitive Sciences - Italian Institute of Technology (IIT)
-- Author: Ali Paikan <ali.paikan@iit.it>
-- Copy Policy: Released under the terms of the LGPLv2.1 or later, see LGPL.TXT


-- LUA_CPATH should have the path to yarp-lua binding library (i.e. yarp.so, yarp.dll) 
require("yarp")

-- initialize yarp network
yarp.Network()


--
-- load a log file
--
function load_log(filename)
  local file = io.open(filename, "r")
  if file == nil then
    print("cannot open '"..filename.."'")
    return nil
  end
  data = {}
  for line in file:lines() do      
      data[#data + 1] = line
  end
  file:close()
  print("'"..filename.."' is loaded!")
  return data
end

--
-- search in a table
--
function inTable(tbl, item)
    for key, value in pairs(tbl) do
        if value == item then return key end
    end
    return nil
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

function help() 
    local msg = [[
help            : show help
exit            : exit portadmin
load <filename> : loads a connections list file 
list            : list the loaded connections 
attach <id|*> <portmonitor> <context> [send|recv] : attach a portmonitor to the connections
detach <id|*>   : dettach any portmonitors from the the connections 
qos set <id|*> <LOW|NORM|HIGH|CRIT> <sched_priority> [sched_policy: 0|1|2] : set the packet QoS and thread priority of the connections.
qos get <id|*>  : get the packet QoS and thread priority of the connections.     
]]
    print(msg)
end

function attach(cons, id, plugin, context, side)
    if side ~= "send" and side ~= "recv" then
        print("'"..side.."' is not correct. Available options are 'send' and 'recv'.")
        return false
    end
    if cons == nil or #cons < id then
        print("'"..id.."' is out of the range. Did you load any connection list file?")
        return false
    end

    local ports = cons[id]:split(",")
    if #ports ~= 3 then
        print("Error while parsing the connection list file at line "..i)
        return false
    end
    -- triming the spaces
    src = ports[1]:match "^%s*(.-)%s*$"
    dest = ports[2]:match "^%s*(.-)%s*$"
    car = ports[3]:match "^%s*(.-)%s*$"
    local ret = yarp.NetworkBase_connect(src, dest,
                             car.."+"..side..".portmonitor+context."..context.."+file."..plugin)
    if ret == false then
        print("Cannot connect '"..src.."' to '"..dest.."' using plugin '"..plugin.."'")
    end
    return true
end

function detach(cons, id)
    if cons == nil or #cons < id then
        print("'"..id.."' is out of the range. Did you load any connection list file?")
        return false
    end

    local ports = cons[id]:split(",")
    if #ports ~= 3 then
        print("Error while parsing the connection list file at line "..i)
        return false
    end
    -- triming the spaces
    src = ports[1]:match "^%s*(.-)%s*$"
    dest = ports[2]:match "^%s*(.-)%s*$"
    car = ports[3]:match "^%s*(.-)%s*$"
    local ret = yarp.NetworkBase_connect(src, dest, car)
    if ret == false then
        print("Cannot reconnect '"..src.."' to '"..dest.."' using carrier '"..car.."'")
    end
    return true
end

function list(cons)
    if cons == nil then return end
    for i=1,#cons do
        print("["..i.."]\t"..cons[i])
    end
end

function set_qos(cons, id, qos, prio, policy) 
    if cons == nil or #cons < id then
        print("'"..id.."' is out of the range. Did you load any connection list file?")
        return false
    end

    local ports = cons[id]:split(",")
    if #ports ~= 3 then
        print("Error while parsing the connection list file at line "..i)
        return false
    end
    -- triming the spaces
    src = ports[1]:match "^%s*(.-)%s*$"
    dest = ports[2]:match "^%s*(.-)%s*$"
    style = yarp.QosStyle()
    style:setThreadPriority(prio)
    style:setThreadPolicy(policy)
    if style:setPacketPriority("LEVEL:"..qos) == false then
        print("Cannot set qos level'"..qos.."'.")
        return
    end
    yarp.NetworkBase_setConnectionQos(src, dest, style, false)
end

function get_qos_level(packet)
    if packet == -1 then return "Invalid" 
    elseif packet == 0 then return "Norm" 
    elseif packet == 10 then return "Low" 
    elseif packet == 36 then return "High" 
    elseif packet == 44 then return "Crit" 
    else return "Undefined" end
end

function get_qos(cons, id) 
    if cons == nil or #cons < id then
        print("'"..id.."' is out of the range. Did you load any connection list file?")
        return false
    end

    local ports = cons[id]:split(",")
    if #ports ~= 3 then
        print("Error while parsing the connection list file at line "..i)
        return false
    end
    -- triming the spaces
    src = ports[1]:match "^%s*(.-)%s*$"
    dest = ports[2]:match "^%s*(.-)%s*$"
    style_src = yarp.QosStyle()
    style_dest = yarp.QosStyle()
    ret = yarp.NetworkBase_getConnectionQos(src, dest, style_src, style_dest, false)
    if ret == false then return end
    print("["..id.."]\t".."thread: ("..style_src:getThreadPriority()..", "..style_src:getThreadPolicy()..") packet: ("..get_qos_level(style_src:getPacketPriorityAsLevel())..")\t"..src)
    print("["..id.."]\t".."thread: ("..style_dest:getThreadPriority()..", "..style_dest:getThreadPolicy()..") packet: ("..get_qos_level(style_dest:getPacketPriorityAsLevel())..")\t"..dest)
end

-------------------------------------------------------
-- main 
-------------------------------------------------------
logo = [[
                  _            _           _       
 _ __   ___  _ __| |_ __ _  __| |_ __ ___ (_)_ __  
| '_ \ / _ \| '__| __/ _` |/ _` | '_ ` _ \| | '_ \ 
| |_) | (_) | |  | || (_| | (_| | | | | | | | | | |
| .__/ \___/|_|   \__\__,_|\__,_|_| |_| |_|_|_| |_|
|_|

type 'help' for more information.
]]

print(logo)

if #arg > 0 then
    cons = load_log(arg[1])
end

repeat
    io.write(">> ") io.flush()
    local cmd = io.read()
    cmd = cmd:match "^%s*(.-)%s*$"
    if cmd == "exit" or cmd == "quit" then break end
    tokens = cmd:split(" ")
    -- loading the file
    if tokens[1] == "help" then
        help()
    elseif tokens[1] == "load" then
        if #tokens < 2 then 
            print("Usage: load <filename>.") 
        else
            cons = load_log(tokens[2]) 
        end
    elseif tokens[1] == "list" then
        list(cons)
    elseif tokens[1] == "attach" then    
        if #tokens < 4 then 
            print("Usage: attach <id|*> <portmonitor> <context> [send|recv].") 
        else
            local side = "recv"
            if #tokens > 4 then side = tokens[5] end
            if tokens[2] == "*" then
                for i=1,#cons do
                    attach(cons, i, tokens[3], tokens[4], side)
                end
            else
                local id = tonumber(tokens[2])
                attach(cons, id, tokens[3], tokens[4], side)
            end    
        end
    elseif tokens[1] == "detach" then    
        if #tokens ~= 2 then 
            print("Usage: detach <id|*>") 
        else
            print(tokens[2])
            if tokens[2] == "*" then
                for i=1,#cons do
                    detach(cons, i)
                end
            else
                local id = tonumber(tokens[2])
                detach(cons, id)
            end    
        end
    elseif #tokens > 2 and tokens[1] == "qos" then
        if tokens[2] == "get" then
            if #tokens < 3 then 
                print("Usage: qos get <id|*>.") 
            else
                if tokens[3] == "*" then
                    for i=1,#cons do
                        get_qos(cons, i) 
                    end
                else
                    local id = tonumber(tokens[3])
                    get_qos(cons, id) 
                end
            end        
        elseif tokens[2] == "set" then
            if #tokens < 5 then 
                print("Usage: qos set <id|*> <LOW|NORM|HIGH|CRIT> <sched_priority> [sched_policy].") 
            else
                local qos = tokens[4]
                local prio = tokens[5]
                local policy = 1
                if #tokens > 5 then policy = tonumber(tokens[6]) end
                if tokens[3] == "*" then
                    for i=1,#cons do
                        set_qos(cons, i, qos, prio, policy) 
                    end
                else
                    local id = tonumber(tokens[3])
                    set_qos(cons, id, qos, prio, policy) 
                end
            end
        end    
    else
        print("'"..cmd.."' is not correct. type 'help' for more information.")
    end
until false



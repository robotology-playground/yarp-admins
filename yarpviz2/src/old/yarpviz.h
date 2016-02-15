/***************************************************************
QGVCore Sample
Copyright (c) 2014, Bergont Nicolas, All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 3.0 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library.
***************************************************************/
#ifndef YARPVIZ_H
#define YARPVIZ_H

#include <string>
#include <sstream>
#include <iostream>

//using namespace std;


struct ConnectionInfo {
    std::string name;
    std::string carrier;
};

struct ProcessInfo {
    std::string name;
    std::string arguments;
    std::string os;
    std::string hostname;
    int pid;
    int priority;
    int policy;
    ProcessInfo() { pid = priority = policy = -1; }
};

struct PortDetails {
    std::string name;
    std::vector<ConnectionInfo> outputs;
    std::vector<ConnectionInfo> inputs;
    ProcessInfo owner;
    std::string toString() {
        std::ostringstream str;
        str<<"port name: "<<name<<std::endl;
        str<<"outputs:"<<std::endl;
        std::vector<ConnectionInfo>::iterator itr;
        for(itr=outputs.begin(); itr!=outputs.end(); itr++)
            str<<"   + "<<(*itr).name<<" ("<<(*itr).carrier<<")"<<std::endl;
        str<<"inputs:"<<std::endl;
        for(itr=inputs.begin(); itr!=inputs.end(); itr++)
            str<<"   + "<<(*itr).name<<" ("<<(*itr).carrier<<")"<<std::endl;
        str<<"owner:"<<std::endl;
        str<<"   + name:      "<<owner.name<<std::endl;
        str<<"   + arguments: "<<owner.arguments<<std::endl;
        str<<"   + hostname:  "<<owner.hostname<<std::endl;
        str<<"   + priority:  "<<owner.priority<<std::endl;
        str<<"   + policy:    "<<owner.policy<<std::endl;
        str<<"   + os:        "<<owner.os<<std::endl;
        str<<"   + pid:       "<<owner.pid<<std::endl;

        return str.str();
    }
};

class GenericNode {
public:
    enum NodeType {PORT, PROCESS};

public:
    PortDetails info;
    NodeType type;

public:
    GenericNode(NodeType type=PORT) {
        GenericNode::type = type;
    }

    GenericNode(NodeType type, PortDetails& info) {
        GenericNode::type = type;
        GenericNode::info = info;
    }

    virtual ~GenericNode() { }

    const std::string& getName() {
        if(type == PORT) return info.name;
        if(type == PROCESS) return info.owner.name;
    }

    friend bool operator == ( const GenericNode &n1, const GenericNode &n2) {
        if(n1.type != n2.type) return false;
        if(n1.type == PORT)
            return n1.info.name == n2.info.name;
        if(n1.type == PROCESS)
            return (n1.info.owner.hostname == n2.info.owner.hostname) &&
                  (n1.info.owner.pid == n2.info.owner.pid);
    }


    bool operator<(const GenericNode& n1) const {
        if(type != n1.type) return (type==PORT && n1.type == PROCESS) ? true : false;
        if(type == PORT) return (info.name < n1.info.name);
        if(type == PROCESS) return (info.owner.name < n1.info.owner.name);
        return false;
    }

    friend std::ostream &operator<<(std::ostream &os, GenericNode const &n) {
        if(n.type == PORT) return os << n.info.name;
        if(n.type == PROCESS) return os << n.info.owner.name <<" ("<<n.info.owner.pid<<")";
    }

};



#endif // YARPVIZ_H


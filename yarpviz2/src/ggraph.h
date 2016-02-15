/***************************************************************
YGraph
***************************************************************/
#ifndef _YARP_GRAPH_
#define _YARP_GRAPH_

#include<yarp/os/Property.h>

//#include <sstream>
#include <iostream>
#include <vector>
#include <string>

namespace yarp {
    namespace graph {
        class Vertex;
        class Edge;
        class Graph;
    }
};


typedef typename std::vector<yarp::graph::Edge> edge_set;
typedef typename edge_set::iterator edge_iterator;
typedef typename edge_set::const_iterator edge_const_iterator;

typedef typename std::vector<yarp::graph::Vertex*> pvertex_set;
typedef typename pvertex_set::iterator pvertex_iterator;
typedef typename pvertex_set::const_iterator pvertex_const_iterator;


/**
 * @brief The yarp::graph::Edge class
 */
class yarp::graph::Edge {
public:

    Edge(const yarp::graph::Vertex& firstV,
         const yarp::graph::Vertex& secondV,
         yarp::os::Property property="");

    Edge(const Edge& edge);

    virtual ~Edge();

    const yarp::graph::Vertex& first() const;
    const yarp::graph::Vertex& second() const;
    virtual bool operator == (const yarp::graph::Edge &edge) const;

public:
    yarp::os::Property property;

private:
    const yarp::graph::Vertex* firstVertex;
    const yarp::graph::Vertex* secondVertex;
};


/**
 * @brief The yarp::graph::Vertex class
 */
class yarp::graph::Vertex {

public:
    Vertex(const yarp::os::Property &prop);
    Vertex(const yarp::graph::Vertex& vertex);
    virtual ~Vertex();

    const edge_set& outEdges() const { return outs; }
    const edge_set& inEdges() const { return ins; }
    size_t degree() const { return ins.size() + outs.size(); }

    virtual bool operator == (const yarp::graph::Vertex &v1) const = 0;
    virtual bool operator<(const Vertex &v1) const;

    friend class Graph;

public:
    yarp::os::Property property;

private:
    void insertOuts(const yarp::graph::Edge& edge);
    void insertIns(const yarp::graph::Edge& edge);

private:
    edge_set outs;
    edge_set ins;
};


/**
 * @brief The yarp::graph::Graph class
 */
class yarp::graph::Graph {

public:
    Graph();
    //Graph(yarp::graph::Graph& graph);
    virtual ~Graph();

    //void insert(Vertex *vertex);
    void insert(const Vertex &vertex);
    void remove(const Vertex &vertex);
    void remove(const pvertex_iterator vi);

    void insertEdge(const Vertex &v1, const Vertex &v2,
                    const yarp::os::Property &property="");

    void insertEdge(const pvertex_iterator vi1, const pvertex_iterator vi2,
                    const yarp::os::Property &property="");

    const pvertex_iterator find(const Vertex &v1);

    size_t size();

    const pvertex_set& vertices() { return mVertices; }
    size_t order() { return mVertices.size(); }


private:
    pvertex_set mVertices;
};


#endif // _YARP_GRAPH_


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
#include "MainWindow.h"
#include "moc_MainWindow.cpp"
#include "ui_MainWindow.h"
#include "QGVScene.h"
#include "QGVNode.h"
#include "QGVEdge.h"
#include "QGVSubGraph.h"
#include <QMessageBox>
#include <yarp/os/Time.h>

#include <yarp/os/LogStream.h>
#include "NetworkProfiler.h"
#include "ggraph.h"

using namespace std;
using namespace yarp::os;
using namespace yarp::graph;


/*
vector<GenericNode>::iterator findPortNodeByName(vector<GenericNode>& nodes, const string name) {
    GenericNode n;
    n.info.name = name;
    return std::find(nodes.begin(), nodes.end(), n);
}
*/


MainWindow::MainWindow(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::MainWindow)
{

    ui->setupUi(this);
    stringModel.setStringList(messages);
    ui->messageView->setModel(&stringModel);
    _scene = new QGVScene("DEMO", this);
    //bgcolor="#2e3e56"
    ui->graphicsView->setBackgroundBrush(QBrush(QColor("#2e3e56"), Qt::SolidPattern));
    ui->graphicsView->setScene(_scene);

    connect(_scene, SIGNAL(nodeContextMenu(QGVNode*)), SLOT(nodeContextMenu(QGVNode*)));
    connect(_scene, SIGNAL(nodeDoubleClick(QGVNode*)), SLOT(nodeDoubleClick(QGVNode*)));
    connect(ui->actionProfile_YARP_network, SIGNAL(triggered()),this,SLOT(onProfileYarpNetwork()));

    connect(ui->actionOrthogonal, SIGNAL(triggered()),this,SLOT(onLayoutOrthogonal()));
    connect(ui->actionCurved, SIGNAL(triggered()),this,SLOT(onLayoutCurved()));
    connect(ui->actionPolyline, SIGNAL(triggered()),this,SLOT(onLayoutPolyline()));
    connect(ui->actionLine, SIGNAL(triggered()),this,SLOT(onLayoutLine()));
    connect(ui->actionSubgraph, SIGNAL(triggered()),this,SLOT(onLayoutSubgraph()));
    connect(ui->nodesTreeWidget, SIGNAL(itemClicked(QTreeWidgetItem*, int)), this,
            SLOT(onNodesTreeItemClicked(QTreeWidgetItem *, int)));

    progressDlg = new QProgressDialog("...", "Cancel", 0, 100, this);

    layoutStyle = "ortho";
    ui->actionOrthogonal->setChecked(true);
    layoutSubgraph = true;
    ui->actionSubgraph->setChecked(true);


    moduleParentItem = new QTreeWidgetItem( ui->nodesTreeWidget,  QStringList("Modules"));
    portParentItem = new QTreeWidgetItem( ui->nodesTreeWidget,  QStringList("Ports"));
    //moduleParentItem->setIcon(0, QIcon(":/Gnome-System-Run-64.png"));
    //moduleParentItem->setIcon(0, QIcon(":/Gnome-System-Run-64.png"));

}

MainWindow::~MainWindow()
{
    delete progressDlg;
    delete ui;
}


void MainWindow::onProgress(unsigned int percentage) {
    //yInfo()<<percentage<<"%";
    progressDlg->setValue(percentage);
}

void MainWindow::drawGraph(Graph &graph)
{
    if(graph.nodesCount() == 0)
        return;

    _scene->clear();    
    delete _scene;
    _scene = new QGVScene("yarpviz", this);
    ui->graphicsView->setBackgroundBrush(QBrush(QColor("#2e3e56"), Qt::SolidPattern));
    ui->graphicsView->setScene(_scene);

    //Configure scene attributes
    //_scene->setGraphAttribute("label", "yarp-viz");

    _scene->setGraphAttribute("splines", layoutStyle.c_str()); //curved, polyline, line. ortho
    _scene->setGraphAttribute("rankdir", "LR");
    _scene->setGraphAttribute("bgcolor", "#2e3e56");
    //_scene->setGraphAttribute("concentrate", "true"); //Error !
    _scene->setGraphAttribute("nodesep", "0.4");
    _scene->setGraphAttribute("ranksep", "0.5");
    //_scene->setNodeAttribute("shape", "box");
    _scene->setNodeAttribute("style", "filled");
    _scene->setNodeAttribute("fillcolor", "gray");
    _scene->setNodeAttribute("height", "1.0");
    _scene->setEdgeAttribute("minlen", "2.0");
    //_scene->setEdgeAttribute("dir", "both");

    // drawing nodes
    // create a map between graph nodes and their visualization
    std::map<const Vertex*, QGVNode*> nodeSet;
    std::map<const string, QGVSubGraph*> subgraphSet;


    // adding all process nodes and subgraphs
    pvertex_const_iterator itr;
    const pvertex_set& vertices = graph.vertices();
    for(itr = vertices.begin(); itr!=vertices.end(); itr++) {
        const Property& prop = (*itr)->property;
        QGVNode *node;
        if(dynamic_cast<ProcessVertex*>(*itr) && !prop.check("hidden"))
        {
            if(layoutSubgraph) {
                QGVSubGraph *sgraph = _scene->addSubGraph(prop.toString().c_str());
                //sgraph->setAttribute("label", prop.find("name").asString().c_str());
                sgraph->setAttribute("color", "#2e3e56"); // hidden!
                //sgraph->setAttribute("fillcolor", "#0180B5");
                subgraphSet[prop.toString()] = sgraph;
                node = sgraph->addNode(prop.find("name").asString().c_str());
            }else
                node = _scene->addNode(prop.find("name").asString().c_str());
            node->setAttribute("shape", "box");
            node->setAttribute("fillcolor", "#a5cf80");
            node->setAttribute("color", "#a5cf80");
            node->setIcon(QImage(":/icons/Gnome-System-Run-64.png"));
            nodeSet[*itr] = node;
        }
    }

    // adding port nodes
    //pvertex_const_iterator itr;
    //const pvertex_set& vertices = graph.vertices();
    for(itr = vertices.begin(); itr!=vertices.end(); itr++) {
        const Property& prop = (*itr)->property;
        if(dynamic_cast<PortVertex*>(*itr) && !prop.check("hidden")) {
            if(!prop.check("orphan")) {
                QGVNode *node;
                if(layoutSubgraph) {
                    PortVertex* pv = dynamic_cast<PortVertex*>(*itr);
                    Vertex* v = pv->getOwner();
                    QGVSubGraph *sgraph = subgraphSet[v->property.toString()];
                    if(sgraph)
                        node =  sgraph->addNode(prop.find("name").asString().c_str());
                    else
                        node =  _scene->addNode(prop.find("name").asString().c_str());
                }
                else
                    node =  _scene->addNode(prop.find("name").asString().c_str());
                node->setAttribute("shape", "ellipse");
                node->setAttribute("fillcolor", "#edad56");
                node->setAttribute("color", "#edad56");
                nodeSet[*itr] = node;
            }
        }
    }

    for(itr = vertices.begin(); itr!=vertices.end(); itr++) {
        const Vertex &v1 = (**itr);
        for(int i=0; i<v1.outEdges().size(); i++) {
            const Edge& edge = v1.outEdges()[i];
            const Vertex &v2 = edge.second();
            // add ownership edges
            if(!v1.property.check("hidden") && !v2.property.check("hidden")) {
                if(edge.property.find("type").asString() == "ownership" &&
                        edge.property.find("dir").asString() != "unknown") {
                    QGVEdge* gve = _scene->addEdge(nodeSet[&v1], nodeSet[&v2], "");
                    gve->setAttribute("color", "grey");
                    gve->setAttribute("style", "dashed");
                }

                if(edge.property.find("type").asString() == "connection") {
                    QGVEdge* gve = _scene->addEdge(nodeSet[&v1], nodeSet[&v2],
                                                   edge.property.find("carrier").asString().c_str());
                    gve->setAttribute("color", "white");
                }
            }
        }
    }

    //Layout scene
    _scene->applyLayout();

    //Fit in view
    ui->graphicsView->fitInView(_scene->sceneRect(), Qt::KeepAspectRatio);

    //_scene->addEdge(node3, snode1, "GB8");

    /*
    _scene->loadLayout("digraph test{node [style=filled,fillcolor=white];N1 -> N2;N2 -> N3;N3 -> N4;N4 -> N1;}");
    connect(_scene, SIGNAL(nodeContextMenu(QGVNode*)), SLOT(nodeContextMenu(QGVNode*)));
    connect(_scene, SIGNAL(nodeDoubleClick(QGVNode*)), SLOT(nodeDoubleClick(QGVNode*)));
    ui->graphicsView->setScene(_scene);
    return;
    */

/*
    //Add some nodes
    QGVNode *node1 = _scene->addNode("BOX");
    node1->setIcon(QImage(":/icons/Gnome-System-Run-64.png"));
    QGVNode *node2 = _scene->addNode("SERVER0");
    node2->setIcon(QImage(":/icons/Gnome-Network-Transmit-64.png"));
    QGVNode *node3 = _scene->addNode("SERVER1");
    node3->setIcon(QImage(":/icons/Gnome-Network-Transmit-64.png"));
    QGVNode *node4 = _scene->addNode("USER");
    node4->setIcon(QImage(":/icons/Gnome-Stock-Person-64.png"));
    QGVNode *node5 = _scene->addNode("SWITCH");
    node5->setIcon(QImage(":/icons/Gnome-Network-Server-64.png"));

    //Add some edges
    _scene->addEdge(node1, node2, "TTL")->setAttribute("color", "red");
    _scene->addEdge(node1, node2, "SERIAL");
    _scene->addEdge(node1, node3, "RAZ")->setAttribute("color", "blue");
    _scene->addEdge(node2, node3, "SECU");

    _scene->addEdge(node2, node4, "STATUS")->setAttribute("color", "red");

    _scene->addEdge(node4, node3, "ACK")->setAttribute("color", "red");

    _scene->addEdge(node4, node2, "TBIT");
    _scene->addEdge(node4, node2, "ETH");
    _scene->addEdge(node4, node2, "RS232");

    _scene->addEdge(node4, node5, "ETH1");
    _scene->addEdge(node2, node5, "ETH2");

    */

/*
    QGVSubGraph *ssgraph = sgraph->addSubGraph("SUB2");
    ssgraph->setAttribute("label", "DESK");
    _scene->addEdge(snode1, ssgraph->addNode("PC0155"), "S10");
*/

}

void MainWindow::nodeContextMenu(QGVNode *node)
{
    //Context menu exemple
    QMenu menu(node->label());

    menu.addSeparator();
    menu.addAction(tr("Informations"));
    menu.addAction(tr("Options"));

    QAction *action = menu.exec(QCursor::pos());
    if(action == 0)
        return;
}

void MainWindow::nodeDoubleClick(QGVNode *node)
{
    QMessageBox::information(this, tr("Node double clicked"), tr("Node %1").arg(node->label()));
}

void MainWindow::onProfileYarpNetwork() {

    mainGraph.clear();

    yInfo()<<"Cleaning death ports...";
    NetworkProfiler::yarpClean(0.1);

    yInfo()<<"Getting the ports list...";
    NetworkProfiler::ports_name_set ports;
    NetworkProfiler::yarpNameList(ports);


    yInfo()<<"Getting the ports details...";
    NetworkProfiler::ports_detail_set portsInfo;
    progressDlg->setLabelText("Getting the ports details...");
    progressDlg->reset();
    progressDlg->setRange(0, ports.size());
    progressDlg->setValue(0);
    progressDlg->setWindowModality(Qt::WindowModal);
    progressDlg->show();
    for(int i=0; i<ports.size(); i++) {
        NetworkProfiler::PortDetails info;
        std::string portname = ports[i].find("name").asString();
        std::string msg = string("Cheking ") + portname + "...";
        messages.append(QString(msg.c_str()));
        if(NetworkProfiler::getPortDetails(portname, info))
            portsInfo.push_back(info);
        progressDlg->setValue(i);
        if (progressDlg->wasCanceled())
            return;
    }
    //progressDlg->setValue(ports.size());
    stringModel.setStringList(messages);
    ui->messageView->update();

    NetworkProfiler::setProgressCallback(this);
    progressDlg->setLabelText("Generating the graph...");
    progressDlg->setRange(0, 100);
    progressDlg->setValue(0);
    NetworkProfiler::creatNetworkGraph(portsInfo, mainGraph);
    progressDlg->close();

    // add process and port nodes to the tree
    QTreeWidgetItem* item= NULL;
    for (int i= moduleParentItem->childCount()-1; i>-1; i--) {
        item = moduleParentItem->child(i);
        delete item;
    }
    for (int i= portParentItem->childCount()-1; i>-1; i--) {
        item = portParentItem->child(i);
        delete item;
    }
    pvertex_const_iterator itr;
    const pvertex_set& vertices = mainGraph.vertices();
    for(itr = vertices.begin(); itr!=vertices.end(); itr++) {
        const Property& prop = (*itr)->property;
        if(dynamic_cast<ProcessVertex*>(*itr)) {
            NodeWidgetItem *moduleItem =  new NodeWidgetItem(moduleParentItem, (*itr), MODULE);
            moduleItem->setFlags( Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsUserCheckable );
            moduleItem->check(true);
        }
        else if(dynamic_cast<PortVertex*>(*itr) && !(*itr)->property.check("orphan")) {
            NodeWidgetItem *portItem =  new NodeWidgetItem(portParentItem, (*itr), PORT);
            portItem->setFlags( Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsUserCheckable );
            portItem->check(true);
            //moduleItem->setIcon(0, QIcon(":/Gnome-System-Run-64.png"));
        }
    }



    drawGraph(mainGraph);
}


void MainWindow::onLayoutOrthogonal() {
    ui->actionPolyline->setChecked(false);
    ui->actionLine->setChecked(false);
    ui->actionCurved->setChecked(false);
    layoutStyle = "ortho";
    drawGraph(mainGraph);
}

void MainWindow::onLayoutPolyline() {
    ui->actionOrthogonal->setChecked(false);
    ui->actionLine->setChecked(false);
    ui->actionCurved->setChecked(false);
    layoutStyle = "polyline";
    drawGraph(mainGraph);
}

void MainWindow::onLayoutLine() {
    ui->actionOrthogonal->setChecked(false);
    ui->actionPolyline->setChecked(false);
    ui->actionCurved->setChecked(false);
    layoutStyle = "line";
    drawGraph(mainGraph);
}

void MainWindow::onLayoutCurved() {
    ui->actionOrthogonal->setChecked(false);
    ui->actionPolyline->setChecked(false);
    ui->actionLine->setChecked(false);
    layoutStyle = "curved";
    drawGraph(mainGraph);
}

void MainWindow::onLayoutSubgraph() {
    layoutSubgraph = ui->actionSubgraph->isChecked();
    drawGraph(mainGraph);
}

void MainWindow::onNodesTreeItemClicked(QTreeWidgetItem *item, int column){
    if(item->type() != MODULE && item->type() != PORT )
        return;

    bool state = (item->checkState(column) == Qt::Checked);
    bool needUpdate = state != ((NodeWidgetItem*)(item))->checked();
    ((NodeWidgetItem*)(item))->check(state);
    if(needUpdate)
        drawGraph(mainGraph);
}

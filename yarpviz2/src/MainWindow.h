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
#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QGVScene.h>
#include <QProgressDialog>
#include <QStringList>
#include <QStringListModel>

#include "NetworkProfiler.h"

namespace Ui {
class MainWindow;
}

class MainWindow : public QMainWindow, public NetworkProfiler::ProgressCallback
{
    Q_OBJECT
    
public:
    explicit MainWindow(QWidget *parent = 0);
    ~MainWindow();
    void drawGraph();

public:
    virtual void onProgress(unsigned int percentage);

private slots:
    void nodeContextMenu(QGVNode* node);
    void nodeDoubleClick(QGVNode* node);
    void onProfileYarpNetwork();
    void onLayoutOrthogonal();
    void onLayoutPolyline();
    void onLayoutLine();
    void onLayoutCurved();

private:
    Ui::MainWindow *ui;
    QGVScene *_scene;
    QProgressDialog* progressDlg;
    QStringList messages;
    QStringListModel stringModel;
    yarp::graph::Graph graph;
    std::string layoutStyle;
};

#endif // MAINWINDOW_H
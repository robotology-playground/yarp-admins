#include <iostream>
#include <string>
#include <yarp/os/Network.h>
#include <yarp/os/BufferedPort.h>
#include <yarp/os/Stamp.h>
#include <yarp/sig/all.h>
#include <yarp/os/QosStyle.h>
#include <yarp/sig/Image.h>
#include <yarp/os/ResourceFinder.h>
#include <yarp/os/RFModule.h>

using namespace std;
using namespace yarp::os;
using namespace yarp::sig;


class MyModule:public RFModule
{
   yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> > left;
   yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> > right;

public:
    double getPeriod() {
        return 0.0;
    }

    bool updateModule() {
        ImageOf<PixelRgb> *yarp_imgL=left.read(true);                                                  
        ImageOf<PixelRgb> *yarp_imgR=right.read(true);                                                 
         if ((yarp_imgL==NULL) || (yarp_imgR==NULL))                                                           
            return false;
                                                                                                                 
        Stamp stamp_left, stamp_right;                                                                        
        left.getEnvelope(stamp_left);                                                                      
        right.getEnvelope(stamp_right);                                                                          
        printf("%.6f, %.6f\n", stamp_left.getTime(), stamp_right.getTime());

        return true;
    }

    bool configure(yarp::os::ResourceFinder &conf) {
        if(!conf.check("left") || !conf.check("right")) {
            cout << "Usage: ./receiver --left <port_name> --rigth <port_name>" << endl;
            return false;
        }

        struct sched_param sch_param;
        sch_param.__sched_priority = sched_get_priority_max(SCHED_FIFO) / 4;
        if( sched_setscheduler(0, SCHED_FIFO, &sch_param) != 0 ) {
            cout<<"sched_setscheduler failed."<<endl;
            return false;
        }
        cout<<"Current sched policy: '"<<sched_getscheduler(0)<<"' and priority: '"<<sch_param.__sched_priority<<"'\n";

        if(!left.open("/receiver/left"))
            return false;

        if(!right.open("/receiver/right"))
            return false;


        if(!NetworkBase::connect(conf.find("left").asString().c_str(), 
                                left.getName(), "udp")) {
            cout<<"Cannot connect!"<<endl;
            return false;
        }

        if(!NetworkBase::connect(conf.find("right").asString().c_str(), 
                                right.getName(), "udp")) {
            cout<<"Cannot connect!"<<endl;
            return false;
        }                            

        yarp::os::QosStyle style;
        style.setThreadPolicy(1);
        style.setThreadPriority(15);
        style.setPacketPriorityByLevel(QosStyle::PacketPriorityHigh);
        if(!NetworkBase::setConnectionQos(conf.find("right").asString().c_str(), right.getName(),style)) {
            cout<<"Cannot set Qos"<<endl;
            return false;
        }
        if(!NetworkBase::setConnectionQos(conf.find("left").asString().c_str(), left.getName(),style)) {
            cout<<"Cannot set Qos"<<endl;
            return false;
        }

        return true;
    }

    // Interrupt function.
    bool interruptModule() {
        cout<<"Interrupting your module, for port cleanup"<<endl;
        left.interrupt();
        right.interrupt();
        return true;
    }


    /* Close function, to perform cleanup. */
    bool close() {
        /* optional, close port explicitly */
        cout<<"Calling close function\n";
        left.close();
        right.close();
      return true;
    }
};

int main(int argc, char *argv[]) {
    Network yarp;
    
    ResourceFinder conf;
    conf.configure(argc, argv);  

    MyModule module;
    module.runModule(conf); 

    return 0;
}


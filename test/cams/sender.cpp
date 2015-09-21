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
#include <yarp/os/Random.h>

#include <fstream>
#include <vector>

using namespace std;
using namespace yarp::os;
using namespace yarp::sig;
using namespace yarp::sig::draw;

struct LogType  {
    yarp::os::Stamp left;
    yarp::os::Stamp right;
};

class MyModule:public RFModule
{
   yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> > left;

   unsigned int sample_count;
   std::vector<LogType> samples;

public:
    double getPeriod() {
        return 1.0/30.0;
    }

    bool updateModule() {
        static unsigned  int count = 0;

        ImageOf<PixelRgb>& imgL = left.prepare();
        imgL.resize(16, 8);
        /*
        imgL.zero();
        for(int i=0; i<240; i+=20) {
            PixelRgb rgb(Random::uniform(0, 255),
                           Random::uniform(0, 255),
                           Random::uniform(0, 255));
            addCircleOutline(imgL, rgb, 160, 120, i);
        }
        */
        Stamp stamp;
        stamp.update();
        left.setEnvelope(stamp);
        left.write();
        return true;
    }

    bool configure(yarp::os::ResourceFinder &conf) {

        struct sched_param sch_param;
        sch_param.__sched_priority = sched_get_priority_max(SCHED_FIFO) / 4;
        if( sched_setscheduler(0, SCHED_FIFO, &sch_param) != 0 ) {
            cout<<"sched_setscheduler failed."<<endl;
            return false;
        }
        cout<<"Current sched policy: '"<<sched_getscheduler(0)<<"' and priority: '"<<sch_param.__sched_priority<<"'\n";

        if(!left.open("/sender/cam"))
            return false;

        return true;
    }

    // Interrupt function.
    bool interruptModule() {
        cout<<"Interrupting your module, for port cleanup"<<endl;
        return true;
    }


    /* Close function, to perform cleanup. */
    bool close() {
        left.close();
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


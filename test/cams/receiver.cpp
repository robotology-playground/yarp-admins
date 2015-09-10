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

#include <fstream>
#include <vector>

using namespace std;
using namespace yarp::os;
using namespace yarp::sig;


struct LogType  {
    yarp::os::Stamp left;
    yarp::os::Stamp right;
};

class MyModule:public RFModule
{
   yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> > left;
   yarp::os::BufferedPort<yarp::sig::ImageOf<yarp::sig::PixelRgb> > right;

   unsigned int sample_count;
   std::vector<LogType> samples;

public:
    double getPeriod() {
        return 0.0;
    }

    bool updateModule() {
        static unsigned  int count = 0;

        ImageOf<PixelRgb> *yarp_imgL=left.read(true);                                                  
        ImageOf<PixelRgb> *yarp_imgR=right.read(true);                                                 
         if ((yarp_imgL==NULL) || (yarp_imgR==NULL))                                                           
            return false;
                                                                                                                 
        Stamp stamp_left, stamp_right;                                                                        
        left.getEnvelope(stamp_left);                                                                      
        right.getEnvelope(stamp_right);                                                                          
        LogType sample;
        sample.left = stamp_left;
        sample.right = stamp_right;
        samples[count++] = sample;

        if (count >= sample_count)
            return false;

        if(count % (unsigned int)(0.1*sample_count) == 0)
            printf("Got [%d \%]\n", (int)((float)count / (float)sample_count*100.0) );
        return true;
    }

    bool configure(yarp::os::ResourceFinder &conf) {
        if(!conf.check("left") || !conf.check("right")) {
            cout << "Usage: ./receiver --left <port_name> --rigth <port_name> --count <samnple count>" << endl;
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

        sample_count = conf.check("count") ? conf.find("count").asInt() : 1000;
        samples.resize(sample_count);
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
        cout<<"Saving log ..."<<endl;
        
        ofstream logfile("./samples.log");        
        for(unsigned int i=0; i<samples.size(); i++) {
            char msg[128];
            sprintf(msg, "%d %.6f %d %.6f %.6f\n",
                    samples[i].left.getCount(), samples[i].left.getTime(),
                    samples[i].right.getCount(), samples[i].right.getTime(), 
                    fabs(samples[i].left.getTime() - samples[i].right.getTime()));
            logfile<<msg;                    
        }
        logfile.close();
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


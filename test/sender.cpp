#include <iostream>
#include <string>
#include <yarp/os/Network.h>
#include <yarp/os/BufferedPort.h>
#include <yarp/os/Bottle.h>
#include <yarp/os/Time.h>


using namespace std;
using namespace yarp::os;

int main(int argc, char *argv[]) {
    Network yarp;

    /*
	struct sched_param sch_param;
	sch_param.__sched_priority = sched_get_priority_max(SCHED_FIFO) / 3;
	if( sched_setscheduler(0, SCHED_FIFO, &sch_param) != 0 ) {
		cout<<"sched_setscheduler failed."<<endl;
		return 0;
	}
    cout<<"Current sched policy: '"<<sched_getscheduler(0)<<"' and priority: '"<<sch_param.__sched_priority<<"'\n";
    */

    BufferedPort<Bottle> outPort;
    if(!outPort.open("/sender"))
        return 0;
    
    cout<<"Running...."<<endl;
    int count=0;
    while (true) {
        Bottle& msg = outPort.prepare();
        msg.clear();
        msg.addInt(count++);
        outPort.write();
        yarp::os::Time::delay(0.004);
    }
    return 0;
}


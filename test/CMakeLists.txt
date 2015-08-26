cmake_minimum_required(VERSION 2.8)

project(test)

find_package(YARP)

include_directories(${YARP_INCLUDE_DIRS})

add_executable(sender sender.cpp)
target_link_libraries(sender ${YARP_LIBRARIES})

add_executable(receiver receiver.cpp)
target_link_libraries(receiver ${YARP_LIBRARIES})


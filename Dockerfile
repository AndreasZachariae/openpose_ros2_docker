##############################################################################
##                                 Base Image                               ##
##############################################################################
# FROM cwaffles/openpose
# https://hub.docker.com/r/cwaffles/openpose

FROM nvidia/cuda:10.1-cudnn7-devel-ubuntu18.04

##############################################################################
##                                 OpenPose                                 ##
##############################################################################
RUN apt-get update && \
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
python3-dev python3-pip python3-setuptools git g++ wget make libprotobuf-dev protobuf-compiler libopencv-dev \
libgoogle-glog-dev libboost-all-dev libcaffe-cuda-dev libhdf5-dev libatlas-base-dev

#for python api
RUN pip3 install --upgrade pip
RUN pip3 install numpy opencv-python 

#replace cmake as old version has CUDA variable bugs
RUN wget https://github.com/Kitware/CMake/releases/download/v3.16.0/cmake-3.16.0-Linux-x86_64.tar.gz && \
tar xzf cmake-3.16.0-Linux-x86_64.tar.gz -C /opt && \
rm cmake-3.16.0-Linux-x86_64.tar.gz
ENV PATH="/opt/cmake-3.16.0-Linux-x86_64/bin:${PATH}"

#get openpose
WORKDIR /openpose
RUN git clone https://github.com/CMU-Perceptual-Computing-Lab/openpose.git .
RUN git checkout 254570d

#build it
WORKDIR /openpose/build
RUN cmake -DBUILD_PYTHON=ON .. && make -j `nproc`
RUN make install

##############################################################################
##                        Install ROS2 & dependencies                       ##
##############################################################################
RUN apt-get update && apt-get install -y \
    locales \
    curl \
    gnupg2 \
    lsb-release \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*rm

RUN locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && export LANG=en_US.UTF-8

ARG ROS_DISTRO=dashing
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key  -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

RUN apt-get update && apt-get install --no-install-recommends -y \
    ros-$ROS_DISTRO-ros-base \
    ros-$ROS_DISTRO-cv-bridge \
    ros-$ROS_DISTRO-rqt* \
    ros-$ROS_DISTRO-image-transport \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-argcomplete \
    && rm -rf /var/lib/apt/lists/*rm

SHELL ["/bin/bash", "-c"] 

RUN source /opt/ros/$ROS_DISTRO/setup.bash

ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN rosdep init
RUN rosdep update --rosdistro $ROS_DISTRO

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install -U pip
RUN pip3 install -U \
    setuptools \
    opencv-python

##############################################################################
##                                 Create User                              ##
##############################################################################
ARG USER=docker
ARG PASSWORD=docker
ARG UID=1000
ARG GID=1000
ARG DOMAIN_ID=1
ENV UID=$UID
ENV GID=$GID
ENV USER=$USER
ENV ROS_DOMAIN_ID=$DOMAIN_ID
RUN groupadd -g "$GID" "$USER"  && \
    useradd -m -u "$UID" -g "$GID" --shell $(which bash) "$USER" -G sudo && \
    echo "$USER:$PASSWORD" | chpasswd && \
    echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudogrp
RUN echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> /etc/bash.bashrc

USER $USER 
RUN mkdir -p /home/$USER/ros2_ws/src

##############################################################################
##                            OpenPose ROS2 Wrapper                         ##
##############################################################################
WORKDIR /home/$USER/ros2_ws/src
RUN git clone --depth 1 -b ros2 https://github.com/AndreasZachariae/openpose_ros.git

##############################################################################
##                                 Build ROS and run                        ##
##############################################################################
WORKDIR /home/$USER/ros2_ws
RUN . /opt/ros/$ROS_DISTRO/setup.sh && colcon build --symlink-install
RUN echo "source /home/$USER/ros2_ws/install/setup.bash" >> /home/$USER/.bashrc

RUN touch ros_entrypoint.sh
RUN chmod +x ros_entrypoint.sh
RUN echo "#!/bin/bash" >> ros_entrypoint.sh
RUN echo "set -e" >> ros_entrypoint.sh
RUN echo "# setup ros environment" >> ros_entrypoint.sh
RUN echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> ros_entrypoint.sh
RUN echo "source /home/$USER/ros2_ws/install/setup.bash" >> ros_entrypoint.sh
RUN echo "sudo ldconfig" >> ros_entrypoint.sh
RUN echo "exec \$@" >> ros_entrypoint.sh
RUN sudo mv ros_entrypoint.sh /
ENTRYPOINT ["/ros_entrypoint.sh"]

# CMD /bin/bash
CMD ["ros2", "launch", "openpose_ros", "openpose_ros.launch.py"]
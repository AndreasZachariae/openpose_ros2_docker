#!/bin/sh
uid=$(eval "id -u")
gid=$(eval "id -g")
docker build --build-arg UID="$uid" --build-arg GID="$gid" -t openpose/ros:dashing .

echo "Run Container"
xhost + local:root
docker run --gpus all --name openpose -it --privileged --net host -e DISPLAY=$DISPLAY --rm openpose/ros:dashing

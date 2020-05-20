#!/bin/bash


if [ $USER != root ]; then
    echo "请用root用户执行!!!"
    exit
fi

echo " start build bmdn ..."
/usr/lib/dart/bin/dart2native bin/server.dart -o docker/bmdm
echo "build bmdm end ..."
echo "build docker"
cd docker && docker build -t asmh1989/dart . 
echo "build docker end..."


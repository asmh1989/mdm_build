#!/bin/sh

case "$1" in

  'master')
  	ARGS="--manager"
  	exec /usr/bin/bmdm $@ $ARGS
	;;

  *)
  	exec /usr/bin/bmdm $@
	;;
esac
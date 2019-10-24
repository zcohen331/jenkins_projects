#!/bin/bash

for ipaddr in `cat /home/terra/expect/listip.txt`;do
	#/home/terra/expect/copy_script.exp $ipaddr jenkins mavenir scp
	/home/terra/expect/connect.exp $ipaddr jenkins mavenir ssh
	
done

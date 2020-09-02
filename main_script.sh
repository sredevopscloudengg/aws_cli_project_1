#!/bin/bash

# current date and time
current_day=$(date '+%Y%b%d%H%M%S')

#create key pair
./aws_config.sh

#run cli
./helper_script.sh $current_day
#./test_helper.sh $current_day

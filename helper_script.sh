#this is the main script that reads the config file, prepares the directory structure for logs and aws key pair
#!/bin/bash

# sep
name_sep="_"
dir_path_sep="/"

# current date and time
current_day=$1

# get the current directory
current_dir=$(PWD)

# proj dir names prefix
work_dir_prefix="work"

# create the project dirs
work_dir=$current_dir$dir_path_sep$work_dir_prefix$name_sep$current_day

#exit(0)

# check if the project dirs exist
if [ ! -d "$work_dir" ] 
then
	mkdir $work_dir
fi

#current_day=$(date '+%Y%b%d')

# create output file
log_ext=".output"
script_name="create_aws_infra_cli_2ec2.sh"
script_log_prefix="script_run"

output_file=$work_dir$dir_path_sep$script_name$log_ext
echo $output_file

# run aws infra script
./$script_name $work_dir $current_day > $output_file

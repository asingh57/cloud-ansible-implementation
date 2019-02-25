#!/bin/bash

#program to setup the basic ansible system


OPTIND=1         # Reset in case getopts has been used previously in the shell.

#runs a given command and handles errors
run_command(){
	ret="$($@)"
	if ! [ $? -eq 0 ]; then
		echo -e "$@ failed \n">&2
		echo -e 'Ansible system setup failed, rolling back changes\n' >&2;
		

		#delete all dockers
		if [[ ! -z "$control_machine_name" ]] ; then
			docker stop $control_machine_name
			docker rm $control_machine_name
		fi
		if [[ ! -z "$web_server_name" ]] ; then
			docker stop $web_server_name
			docker rm $web_server_name
		fi
		if [[ ! -z "$db_server_name" ]] ; then
			docker stop $db_server_name
			docker rm $db_server_name
		fi
	exit 126 #command cannot execute
	fi
	
	
	
	echo "$ret"
}
############################
#finds a free port
port=1024 # start from non-reserved ports
get_free_port(){
	isfree= $(netstat -tapln | grep $port)
	while [[ -n "$isfree" ]]; do
	  port=$[port+100]
	  isfree= $(netstat -tapln | grep $port)
	done
	ret_port=$port
	echo "$ret_port"
}
#############################

control_machine_name="ctrl_mach"
ctrl_ssh=$(get_free_port)
run_command bash docker_setup_script.sh -s $ctrl_ssh:22 -g keystore control_machine $control_machine_name
db_server_name="db_serv"
port=$[ctrl_ssh+100]
db_ssh=$(get_free_port)
run_command bash docker_setup_script.sh -s $db_ssh:22 -p 3306:3306 -x 7WEb281s_g43 -g keystore database_server $db_server_name
#change -x argument to change db password
web_server_name="web_serv"
port=$[db_ssh+100]
web_ssh=$(get_free_port)
run_command bash docker_setup_script.sh -s $web_ssh:22 -p 443:443 -g keystore other $web_server_name


docker exec $db_server_name bash -c "cat /root/.ssh/authorized_keys"
docker exec $web_server_name bash -c "cat /root/.ssh/authorized_keys"
############################
#give access of web and db servers to ansible control machine
ctrl_key=$( cat keystore/$control_machine_name.pub )
echo Final key is: $ctrl_key
docker exec $db_server_name bash -c "echo $ctrl_key >> /root/.ssh/authorized_keys"
docker exec $web_server_name bash -c "echo $ctrl_key >> /root/.ssh/authorized_keys"
docker exec $db_server_name /etc/init.d/ssh restart
docker exec $web_server_name /etc/init.d/ssh restart
unset ctrl_key
###########################
docker exec $db_server_name bash -c "cat /root/.ssh/authorized_keys"
docker exec $web_server_name bash -c "cat /root/.ssh/authorized_keys"

###########################


echo Control server running at ssh port $ctrl_ssh
echo Db server running ssh port at $db_ssh
echo Web server running ssh port at $web_ssh



exit 0

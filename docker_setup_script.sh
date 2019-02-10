#!/bin/bash
OPTIND=1         # Reset in case getopts has been used previously in the shell.

###################
#displays correct usage
usage(){
	printf "\nUsage: $0 [-p externalport:internalport] [-d externalport:internalport] [-r ipaddress] [-w externalport:internalport] [-s externalport:internalport] [-c] control_machine|web_server|db_server container_name|custom <docker_name> \n"
	printf "\control_machine: sets up control container with ansible installed\n"
	printf "\web_server: sets up web server in container\n"
	printf "\t-w webport is required if web_server is chosen\n"
	printf "\db_server: sets up mariadb in container\n"
	printf "\t-d database port mapping from container to machine (required if db_server is chosen)\n"
	printf "\t-r restricts mariadb to listen to only one ip address\n"
	printf " -p allows any other ports to be open\n"
	printf " -s installs ssh server and sets default port\n"
	printf " -c copies ~/.ssh/id_rsa.pub into docker's ~/.ssh/authorized_keys and disables password logon\n"	
}
#################

###################
#runs a given command
run_command(){
	if ! ("$@"); then
		echo "$1 failed"
		echo 'Docker setup failed, rolling back changes' >&2;
		if [[ ! -z "$hash" ]]
			then
			docker container stop $hash
			docker container rm $hash
			if [[ ! -z "$setupfilename" ]]
			then
				echo " "
				#rm $setupfilename #delete the config file
			fi
			exit 126 #command cannot execute
		fi
	fi
}
###################
check_valid_port(){
	#check if a valid port
	re='^[0-9]+$'
	
	IFS=: read -r var1 var2 <<< "$1"
	
	
	if ! [[ $var1 =~ $re ]] ; then
	   echo "error: $var1 Not a valid port" >&2;
	   exit 128
	fi
	if ! [[ $var2 =~ $re ]] ; then
	   echo "error: $var2 Not a valid port" >&2;
	   exit 128
	fi
	
}
###################

##################
#check if asking for help
if [  $# -le 0 ] 
then 
	usage
	exit 1
fi 
if [[ ( $# == "--help") ||  $# == "-h" ]] 
then 
	usage
	exit 0
fi
##############



###################
#device type invalid
if [[ ( ${@: -2:1} != "other") && ( ${@: -2:1} != "control_machine") &&  (${@: -2:1} != "web_server") &&  (${@: -2:1} != "db_server") ]] 
then 
	printf "error: ${@: -2:1} is not a valid device type" >&2
	usage
	exit 128
else
	machine_type=${@: -2:1}
fi
###################

container_name=${@: -1}

p=()

while getopts ':p:w:s:c:d:r:' opt; do
  case "$opt" in
        p)
			check_valid_port $OPTARG
            p+=(${OPTARG})
			
            ;;
        w)
			check_valid_port $OPTARG
            w=${OPTARG}
            ;;
		s)
            s=${OPTARG}
			###############
			#separate ssh port
			IFS=: read -r externalssh internalssh <<< "$s"	
			###############
            ;;
		c)
            c=true
            ;;
		d)
            check_valid_port $OPTARG
            d=${OPTARG}
            ;;
		r) 
			r=${OPTARG}
			;;
		*)
            usage
            ;;
    esac
done


#check if webport is enabled when web_server is enabled
if [ "$machine_type" == "web_server" ]; then
	if [ -z "$w" ];then
		echo 'error: web port is missing' >&2
		usage
		exit 128
	fi
	re='^[0-9]+$'
	IFS=: read -r externalweb internalweb <<< "$w"	
elif [ "$machine_type" == "db_server" ]; then
	if [ -z "$d" ];then
		echo 'error: db port is missing' >&2
		usage
		exit 128
	fi
	re='^[0-9]+$'
	IFS=: read -r externaldb internaldb <<< "$d"
fi




###############
#Create docker
dock_create_cmd='docker run -d -t'

###########
#set port mappings
p_switch=' -p '
for i in "${p[@]}"
do	
	dock_create_cmd=$dock_create_cmd$p_switch$i
done
if [[ ! -z "$w" ]]; then
	dock_create_cmd=$dock_create_cmd$p_switch$w
fi
if [[ ! -z "$s" ]]; then
	dock_create_cmd=$dock_create_cmd$p_switch$s
fi
if [[ ! -z "$d" ]]; then
	dock_create_cmd=$dock_create_cmd$p_switch$d
fi

nameplug=' --name '
dist=' debian'
dock_create_cmd=$dock_create_cmd$nameplug${@: -1}$dist



hash=$($dock_create_cmd)


if [ 0 != $? ]; then
	echo 'Docker setup failed, rolling back changes' >&2;
	exit 126 #command cannot execute
fi

###############


setupfilename=internal_script_$(date +"%s").sh


#-------------------------------------------------
#setup for script to run inside container

#utility bash functions
setupfile="\
run_command(){ \n
	if ! (\"\$@\"); then \n
		echo 'Docker setup failed, rolling back changes' >&2; \n
		exit 126 #command cannot execute \n
	fi \n
} \n 
run_command apt-get update \n 

check_file_exists(){ \n
	if [ ! -f \$1 ]; then\n
		echo '\$1: file not found, rolling back changes' >&2; \n
		exit 126 #command cannot execute \n
	fi \n
} \n
"
#############################
if [[ ! -z "$internalssh" ]]; then #if ssh is required to be installed
	setupfile+="\
run_command apt-get -y update \n
run_command apt-get -y install openssh-server \n
run_command printf 'PubkeyAuthentication yes \\\nPasswordAuthentication no\\\nPort $internalssh\\\nPermitRootLogin yes\\\n' > /etc/ssh/sshd_config \n
mkdir ~/.ssh
chmod 700 ~/.ssh
run_command touch ~/.ssh/authorized_keys \n
run_command chmod 644 ~/.ssh/authorized_keys \n
run_command /etc/init.d/ssh restart \n 
" 
fi
#############################


if [[ ( ${@: -2:1} == "control_machine")]] 
then
	setupfile+="\
run_command apt-get -y update \n
run_command apt-get -y install software-properties-common \n
run_command apt-get -y update \n
run_command apt-get -y install gpg \n
run_command apt-add-repository ppa:ansible/ansible \n
run_command apt-get -y update \n
run_command apt-get -y install ansible \n 
"
elif [[ ( ${@: -2:1} == "web_server")]]
then
	setupfile+="\
run_command apt install nodejs npm \n
"
elif [[ ( ${@: -2:1} == "db_server")]]
then
	setupfile+="\
run_command apt-get -y install mariadb-server \n
check_file_exists /etc/mysql/my.cnf \n
run_command printf '\\\n[mysqld]\nport=$internaldb'>> /etc/mysql/my.cnf \n
"
	if [[ ! -z "$r" ]] #restrict ip access
	then
setupfile+="\
run_command printf '\\\nbind-address=127.0.0.1'>> /etc/mysql/my.cnf \n
"
	fi
	setupfile+="\
run_command service mysql restart \n
"
fi


#write to config script and run
printf "$setupfile"> $setupfilename
run_command docker cp $setupfilename $container_name:/$setupfilename
#printf "docker exec -i -t $container_name bash -c \"chmod +rx $setupfilename\""
#exit 0
run_command docker exec -it $container_name bash -c "ls /"
run_command docker exec -it $container_name bash -c "chmod +rx /$setupfilename"
run_command docker exec -it $container_name bash -c "./$setupfilename"
###############




if [[ ! -z "$internalssh" ]]; then #if ssh is required to be installed
	auth_key_serv=$( cat ~/.ssh/id_rsa.pub )
	run_command docker exec $container_name bash -c "echo $auth_key_serv > ~/.ssh/authorized_keys"
	run_command docker exec $container_name /etc/init.d/ssh restart
	unset auth_key_serv
fi





echo $hash #print from console, the hash of the container we just created

#docker container stop $hash
#docker container rm $hash

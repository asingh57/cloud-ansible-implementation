#!/bin/bash

#program to setup individual dockers


OPTIND=1         # Reset in case getopts has been used previously in the shell.

###################
#displays correct usage
usage(){
	printf "\nUsage: $0 [-p externalport:internalport] [-s externalport:internalport] [-g hostlocation] [<control_machine>] <container_name> \n"
	printf "\control_machine: sets up control container with ansible\n"
	printf " -p allows any TCP ports to be opened and maps them to the host\n"
	printf " -s installs ssh server, sets default port and copies ssh key to authorized keys of the docker\n"	
	printf " -g generates a rsa key and copies the public key from the docker to mentioned host machine location\n"
	printf "\t This public key is needed for two things"
	printf "\t\t as a authorized_key ansible control_server must generate and add to db & web servers to have ssh access"
	printf "\t\t as a deploy key web server must generate to be able to clone from git (needs to be placed in the webserver github repo)"
}
#################

###################
#runs a given command
run_command(){
	if ! ("$@"); then
		echo "$1 failed ">&2
		echo 'Docker setup failed, rolling back changes' >&2;
		if [[ ! -z "$hash" ]]
			then
			docker container stop $hash
			docker container rm $hash
			if [[ ! -z "$setupfilename" ]]
			then
				
				rm $setupfilename #delete the config file
			fi			
		fi
		exit 126 #command cannot execute
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
	exit 1
fi
##############



if [[( ${@: -2:1} == "control_machine" || ${@: -2:1} == "web_server" )]] #ansible will be installed on this server
then
	machine_type=${@: -2:1}
fi



container_name=${@: -1}

p=()
while getopts ':p:s:g:' opt; do
  case "$opt" in
        p)
			check_valid_port $OPTARG
            p+=(${OPTARG})
			
            ;;        
		s)
            p+=(${OPTARG})
			###############
			#separate ssh port
			IFS=: read -r externalssh internalssh <<< ${OPTARG}	
			###############
            ;;		
		g)
            g=${OPTARG}
            ;;		
		*)
            usage
            ;;
    esac
done

#create docker with given info
dock_create_cmd='docker run -d -t'
p_switch=' -p '
for i in "${p[@]}"
do	
	dock_create_cmd=$dock_create_cmd$p_switch$i
done

nameplug=' --name '
dist=' debian'
dock_create_cmd=$dock_create_cmd$nameplug$container_name$dist
#############################

#create docker and store the hash
if ! (hash=$($dock_create_cmd)); then
	echo 'Docker creation failed, rolling back changes' >&2;
	exit 126 #command cannot execute
fi

setupfilename=internal_script_$(date +"%s").sh


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
setupfile+="run_command apt-get -y update \n"



#############################
if [[ ! -z "$internalssh" ]]; then #if ssh is required to be installed


	setupfile+="\
run_command apt-get -y install openssh-server \n
run_command printf 'PubkeyAuthentication yes \\\nPasswordAuthentication no\\\nPort $internalssh\\\nPermitRootLogin yes\\\n' > /etc/ssh/sshd_config \n
mkdir ~/.ssh
chmod 700 ~/.ssh
run_command touch ~/.ssh/authorized_keys \n
run_command chmod 644 ~/.ssh/authorized_keys \n
"
	if [[ ! -z "$g" ]]; then # generate public key from server
		setupfile+="run_command ssh-keygen -b 2048 -t rsa -f ~/.ssh/sshkey -q -N \"\" \n" 
	fi

setupfile+="run_command /etc/init.d/ssh restart \n" 
fi
#############################

#############################
if [[ ( machine_type == "control_machine")]] 
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
fi

#write to config script and run
printf "$setupfile"> $setupfilename
run_command docker cp $setupfilename $container_name:/$setupfilename
#printf "docker exec -i -t $container_name bash -c \"chmod +rx $setupfilename\""
#exit 0
run_command docker exec -it $container_name bash -c "ls /"
run_command docker exec -it $container_name bash -c "chmod +rx /$setupfilename"
run_command docker exec -it $container_name bash -c "./$setupfilename"

if [[ ! -z "$g" ]]; then # generate public key from server
	run_command mkdir -p $g
	run_command [ -e file ] && rm $g/$container_name.pub
	run_command docker cp $container_name:~/.ssh/id_rsa.pub $g/$container_name.pub
fi

###############


if [[ ! -z "$internalssh" ]];then #add to ssh keys host's key and ormuco's key

	auth_key_serv=$( cat ~/.ssh/ormuco_ssh_key.pub )
	run_command docker exec $container_name bash -c "echo $auth_key_serv >> ~/.ssh/authorized_keys"

	
	auth_key_serv=$( cat ~/.ssh/id_rsa.pub )
	run_command docker exec $container_name bash -c "echo $auth_key_serv >> ~/.ssh/authorized_keys"
	run_command docker exec $container_name /etc/init.d/ssh restart
	unset auth_key_serv

fi



echo $hash #print from console to stdout, the hash of the container we just created

exit 0








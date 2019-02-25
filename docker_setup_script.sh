#!/bin/bash
#Author: Abhi Singh
#program to setup individual dockers


OPTIND=1         # Reset in case getopts has been used previously in the shell.

###################
#displays correct usage
usage(){
	printf "\nUsage: $0 [-p externalport:internalport] [-s externalport:internalport] [-g hostlocation] [<control_machine>|<database_server>|<other>] <container_name> \n"
	printf "\control_machine: sets up control container with ansible\n"
	printf " -p allows any TCP ports to be opened and maps them to the host\n"
	printf " -s installs ssh server, sets default port and copies ssh key to authorized keys of the docker\n"	
	printf " -g generates a rsa key and copies the public key from the docker to mentioned host machine location\n"
	printf "\t This public key is needed for two things"
	printf "\t\t as a public key ansible control_server must generate and add to db & web servers' authorized keys file to have ssh access"
	printf "\t\t as a deploy key web server must generate to be able to clone from git (needs to be placed in the webserver github repo)"
	exit 1
}
#################

###################
#runs a given command
run_command(){
	if ! ("$@"); then
		echo "$@ failed ">&2
		echo 'Docker setup failed, rolling back changes' >&2;
		
		if [[ ! -z "$setupfilename" ]]
		then
			
			rm $setupfilename #delete the config file
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



if [[( ${@: -2:1} == "control_machine" )]] #ansible will be installed on this server
then
	machine_type=${@: -2:1}
fi

if [[( ${@: -2:1} == "database_server" )]] #db image will be installed on this server
then
	machine_type=${@: -2:1}
fi

container_name=${@: -1}

p=()
while getopts ':p:s:g:x:' opt; do
  case "$opt" in
        p)
			check_valid_port $OPTARG
            p+=(${OPTARG})
			
            ;;        
	s)
            p+=(${OPTARG})
		###############
		#parse ssh port
		IFS=: read -r externalssh internalssh <<< ${OPTARG}	
		###############
            ;;		
	g)
            g=${OPTARG}
            ;;		
    x)
            x=${OPTARG}
            ;;	
	*)
            usage
            ;;
    esac
done

#create docker with given info
dock_create_cmd='docker run -d -t'
p_switch=" -p :"
for i in "${p[@]}"
do	
	dock_create_cmd=$dock_create_cmd$p_switch$i
done

nameplug=' --name '
dist=' debian'

if [[ ( $machine_type == "database_server" ) ]] 
then
    dist=" -e MYSQL_ROOT_PASSWORD=$x -e MYSQL_DATABASE=default mariadb/server:10.3"
fi
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
	echo \"\$@\"
        if ! (\"\$@\"); then \n
                echo 'generated script command failed' >&2; \n
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

echo "Internal ssh enabled ">&2

	setupfile+="\
run_command apt-get -y install openssh-server \n
echo -e \"PubkeyAuthentication yes \\\nPasswordAuthentication no\\\nPort $internalssh\\\nPermitRootLogin yes\\\n\" > /etc/ssh/sshd_config \n
echo installed openssh server \n
run_command mkdir -p ~/.ssh \n
run_command chmod 700 ~/.ssh \n
run_command touch ~/.ssh/authorized_keys \n
run_command chmod 644 ~/.ssh/authorized_keys \n
"

	if [[ ! -z "$g" ]]; then # generate public key from server
		echo "server ssh keygen enabled ">&2
		setupfile+="run_command ssh-keygen -t rsa -N \"\" -f ~/.ssh/id_rsa \n"
        setupfile+="echo ssh-keygen done \n"
	fi

setupfile+="run_command service ssh restart \n" 
setupfile+="echo ssh completed \n"
fi
#############################

#############################
if [[ ( $machine_type == "control_machine" ) ]] 
then
echo "Device is a control machine ">&2
	setupfile+="\
run_command apt-get -y update \n
run_command apt-get -y install software-properties-common \n
run_command apt-get -y update \n
run_command apt-get -y install gpg \n
run_command echo -e \"\\\n\" | apt-add-repository ppa:ansible/ansible \n
run_command apt install -y ansible \n 
"
#run_command apt-get update \n
fi

#write to config script and run
printf "$setupfile"> $setupfilename
run_command docker cp $setupfilename $container_name:/$setupfilename
#printf "docker exec -i -t $container_name bash -c \"chmod +rx $setupfilename\""
#exit 0
run_command docker exec -it $container_name bash -c "ls /"
run_command docker exec -it $container_name bash -c "chmod +rx /$setupfilename"
run_command docker exec -it $container_name bash -c "./$setupfilename"

if [[ ! -z "$g" ]]; then # Copy server's public key to given folder name
	echo "public key is being copied from the server ">&2
	run_command mkdir -p $g
	file="$g/$container_name.pub"
	if [ -f "$file" ];then # delete file if it exists
		run_command rm $g/$container_name.pub
	fi
	run_command docker cp $container_name:/root/.ssh/id_rsa.pub $g/$container_name.pub
fi

###############


if [[ ! -z "$internalssh" ]];then #add to ssh keys host's key and ormuco's key
	echo "public keys added to the server ">&2
	auth_key_serv=$( cat ~/.ssh/ormuco_ssh_key.pub )
	run_command docker exec $container_name bash -c "echo $auth_key_serv >> /root/.ssh/authorized_keys"

	
	auth_key_serv=$( cat ~/.ssh/id_rsa.pub )
	run_command docker exec $container_name bash -c "echo $auth_key_serv >> /root/.ssh/authorized_keys"
	docker exec $container_name service ssh restart
	unset auth_key_serv

fi

if [[ ! -z "$setupfilename" ]]
then
	
	rm $setupfilename #delete the config file
fi	

echo $hash #print from console to stdout, the hash of the container we just created

exit 0








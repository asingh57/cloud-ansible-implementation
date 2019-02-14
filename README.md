# Cloud Ansible Implementation

A simple implementation for Ansible-Nodejs-Mariadb on 3 docker containers on the same machine

The following applications are necessary for this app to work:

```bash
sudo apt-get install -y docker \
					openssh-client
```

	
If you do not have an ssh key already, do the following
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
ssh-add ~/.ssh/id_rsa
```

If you do, make sure the public key is stored in ~/.ssh/id_rsa.pub
This is required to establish ssh access from master machine tot the 3 dockers
	
	
Clone the repository using your provided SSH key
```bash
git clone --recursive git@github.com:asingh57/cloud-ansible-implementation.git	
```

You must make sure that port 443 (https) and port 3306 (mariadb) are not currently busy
```bash
sudo netstat -tulpn | grep LISTEN
```

Now simply run the bash script inside the cloned git repo folder to establish the three containers
```bash
./server_setup.sh
```

Three docker containers: ctrl_mach, db_serv, web_serv will be established. ctrl_mach will have the latest version of ansible installed. You have ssh access to all machines
The application finds free ports and maps port 22 (default ssh) of internal machine to an unused port of the host. It also maps https and mariadb ports respectively

To find which host your dockers mapped to do
```bash
docker ps
```
Note the port mapped to PORTNUMBER->22 for each machines

To access each machine simply do the following:
```bash
ssh root@localhost -p PORTNUMBER
```


To remove all containers do
```bash
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
```




 ansible nodeappserver -m ping-i <path>
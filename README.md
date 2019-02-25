# Cloud Ansible Implementation

A simple implementation for Ansible-Nodejs-Mariadb on 3 debian docker containers on the same machine

Note: You should configure the ansible playbooks according to your needs (update the github repo url, install additional packages/dependencies etc) before you do any of the steps below

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
This is required to establish ssh access from master machine to the 3 dockers
	
	
Clone the repository using your provided SSH key
```bash
git clone git@github.com:asingh57/cloud-ansible-implementation.git	
```

You must make sure that port 443 (https) and port 3306 (mariadb) are not currently busy. To check your occupied ports do
```bash
sudo netstat -tulpn | grep LISTEN
```

Alternatively, you can change the mappings inside server_setup.sh to specify your own paths to RSA keys, etc

Debian and mariadb docker images must be pulled:
```bash
docker pull mariadb/server:10.3 debian
```

Now simply run the bash script inside the cloned git repo folder to establish the three containers
```bash
./server_setup.sh
```

Three docker containers: ctrl_mach, db_serv, web_serv will be established. ctrl_mach will have the latest version of ansible installed. You have ssh access to all machines
The application finds free ports and maps port 22 (default ssh) of internal machine to an unused port of the host. It also maps https and mariadb ports respectively
In addition, ctrl_mach is configured for ssh access to the other two docker containers.

The above command will also list the ssh ports all your containers are available on
Alternatively, to find which host your dockers mapped to do
```bash
docker ps
```
Note the port mapped to PORTNUMBER->22 for each machines

To access each machine simply do the following:
```bash
ssh root@localhost -p PORTNUMBER
```

SSH key for web_serv is stored by default in keystore/web_mach.pub
This key must be added to the git repo of the node web app you intend to use with this ansible role
In addition ctrl_mach and db_serv keys are also made available just in case your app uses remote git repos for each of the two

Now for the ansible portion of this app:

There are a few variables/files that need to be created and modified by you

The config.example folder contains a sample schema. You should configure your own schema accordingly and place it in a directory of you choice (mine is /config)

There are two roles in this ansible app.
In addition, vars folders for both roles have a main.yml.example file which contain configuration variables for each roles 

Copy and adjust this to create your own main.yml for each and then encrypt it using:
```bash
ansible-vault encrypt roles/mariadb/vars/main.yml roles/nodeserver/vars/main.yml
```

once all docs have been configured, copy the ansible playbooks

To copy the playbooks simply do
```bash
docker cp ansible_implementation ctrl_mach:/
docker cp ansible_implementation/. ctrl_mach:/
```
You may also wish to copy your ssl certs

Replace your cert names/directories accordingly and make sure to check the permissions on certs
```bash
#ssl for web site
docker cp /etc/ssl/private/abhisingh_ca.ca-bundle ctrl_mach:/etc/ssl/private/abhisingh_ca.ca-bundle
docker cp /etc/ssl/private/abhisingh_ca.key ctrl_mach:/etc/ssl/private/abhisingh_ca.key 
docker cp /etc/ssl/certs/abhisingh_ca.crt ctrl_mach:/etc/ssl/certs/abhisingh_ca.crt
#ssl for db server
docker exec ctrl_mach mkdir /etc/ssl/private/mariadb/
docker cp /etc/ssl/private/mariadb/ca-cert.pem ctrl_mach:/etc/ssl/private/mariadb/ca-cert.pem
docker cp /etc/ssl/private/mariadb/server-key.pem ctrl_mach:/etc/ssl/private/mariadb/server-key.pem
docker cp /etc/ssl/private/mariadb/server-cert.pem ctrl_mach:/etc/ssl/private/mariadb/server-cert.pem
#schema for db
docker exec ctrl_mach mkdir /config
docker cp /config/schema.sql ctrl_mach:/config/schema.sql
```

Now that we have everything setup, we can simply ssh into the ctrl server using:
```bash
ssh root@localhost -p 1024 
#replace with whatever was assigned to you
```

Once the above have been configured, do
```bash
ansible-playbook site.yml  -i production
```

This should successfully deploy your web app


To remove all containers do
```bash
docker stop ctrl_mach web_serv db_serv
docker rm ctrl_mach web_serv db_serv
```





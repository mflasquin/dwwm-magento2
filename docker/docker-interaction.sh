#!/bin/bash
function setup(){
  #sudo ip addr add 10.254.254.254/24 brd + dev eth0 label eth0:1
  #Update docker images if needed
  docker-compose pull
  fig up -d --force-recreate
  sleep 10

	# add project host to /etc/hosts file
	addhost

	touch .installed
}

function fig() {
  docker-compose -f docker-compose.yml -p $config_project_name $@
}

function up() {
   fig start
}

function stop() {
    fig stop
}

function rm(){
	fig down

	# Remove project domain from host file
	removehost
}

function composer() {
	fig exec --user mflasquin cli composer $@
}

function drush() {
	fig exec --user mflasquin cli drush $@
}

function parse_yaml() {
	if [ ! -f $1 ]; then
		exit
	fi
   	local prefix=$2
   	local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   	sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   	awk -F$fs '{
		indent = length($1)/2;
		vname[indent] = $2;
		for (i in vname) {if (i > indent) {delete vname[i]}}
		if (length($3) > 0) {
			vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
			printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
		}
   	}'
}

function removehost() {
    echo "removing host";
    if [ -n "$(grep $config_project_host $config_project_hostfile)" ]
    then
        echo "$config_project_host Found in your $config_project_hostfile, Removing now...";
        sudo sed -i".bak" "/$config_project_host/d" $config_project_hostfile
    else
        echo "$config_project_host was not found in your $config_project_hostfile";
    fi
}

function addhost() {
    echo "adding host";
    HOSTS_LINE="$config_project_ip\t$config_project_host"
    if [ -n "$(grep $config_project_host $config_project_hostfile)" ]
        then
            echo "$config_project_host already exists : $(grep $config_project_host $config_project_hostfile)"
        else
            echo "Adding $config_project_host to your $config_project_hostfile";
            sudo -- sh -c -e "echo '$HOSTS_LINE' >> /etc/hosts";

            if [ -n "$(grep $config_project_host /etc/hosts)" ]
                then
                    echo "$config_project_host was added succesfully \n $(grep $config_project_host /etc/hosts)";
                else
                    echo "Failed to Add $config_project_host, Try again!";
            fi
    fi
}

PWD=$(dirname ${BASH_SOURCE[0]})
ROOT=./
OS=$(uname)

can_continue=1
if [ ! -f project.yml ]; then
	echo 'project.yml configuration file is required to use local docker env.'
	can_continue=0
fi

eval $(parse_yaml $ROOT/project.yml "config_")

if [ -z $config_project_name ] || [ -z $config_project_host ]; then
	echo 'project.yml require project.name and project.host vars to be defined'
	can_continue=0
fi
if [ -z $config_project_ip ]; then
	config_project_ip="127.0.0.1"
fi
if [ -z $config_project_hostfile ]; then
	config_project_hostfile="/etc/hosts"
fi

if [[ $# -lt 1 ]] || [[ $1 = "--help" ]] || [[ $1 = '-?' ]] | [[ $1 = '-h' ]]; then
	echo -e "Available methods are : "
	compgen -A function
    can_continue=0
fi

if [[ $can_continue -lt 1 ]]; then
	exit 0
fi

$@

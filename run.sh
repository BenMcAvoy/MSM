#!/usr/bin/env bash

###################################
##                               ##
##   Copyright Ben McAvoy, 2024  ##
##   <ben.mcavoy@tutanota.com>   ##
##                               ##
###################################
##                               ##
##   Licensed under MIT. Used    ##
##   Used for automatically      ##
##	 setting up servers and      ##
##   configuring the proxy.      ##
##                               ##
###################################

set -e

#### Variables ####
SERVER_LAUNCHER="while [ true ]; do java -Xms4G -Xmx4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -jar server.jar --nogui; echo Server restarting...; echo Press CTRL + C to stop.; sleep 2; done"
PROXY_LAUNCHER="while [ true ]; do java -Xms4G -Xmx4G -XX:+UseG1GC -XX:G1HeapRegionSize=4M -XX:+UnlockExperimentalVMOptions -XX:+ParallelRefProcEnabled -XX:+AlwaysPreTouch -XX:MaxInlineLevel=15 -jar server.jar; echo Server restarting...; echo Press CTRL + C to stop.; done"

VELOCITY_BOOTSTRAP="#!/usr/bin/env bash\n\ntimeout 10s bash launch.sh\nsed -i 's/25577/25565/g' ./velocity.toml\nrm bootstrap.sh\n"

set -x

LOWEST_PORT=25566

server_ports=()
server_names=()
server_dirs=()

#### Functions ####
function get_velocity_link() {
	# Disable debug
	set +x
	RELEASE_JSON=$(curl -s https://api.papermc.io/v2/projects/velocity/)
	RELEASE=$(echo $RELEASE_JSON | jq -r '.versions[-1]')

	BUILD_JSON=$(curl -s https://api.papermc.io/v2/projects/velocity/versions/$RELEASE/builds/)
	BUILD=$(echo $BUILD_JSON | jq -r '.builds[-1].build')

	URL="https://api.papermc.io/v2/projects/velocity/versions/$RELEASE/builds/$BUILD/downloads/velocity-$RELEASE-$BUILD.jar"

	# Enable debug
	set -x

	# Return the URL
	echo $URL
}

function clear_proxy() {
	sed -i '/\[servers\]/,/try/ {//!d}' ./servers/proxy/velocity.toml
}

function add_server_to_proxy() {
	IP="127.0.0.1:$2"
	STRING="$1 = \"$IP\""

	sed -i "/\[servers\]/a $STRING" ./servers/proxy/velocity.toml
}

# Create proxy folder and download velocity and the config
if [ ! -f "./servers/proxy/server.jar" ]; then
	mkdir -p ./servers/proxy
	echo $PROXY_LAUNCHER > ./servers/proxy/launch.sh
	echo -e "$VELOCITY_BOOTSTRAP" > ./servers/proxy/bootstrap.sh
	wget $(get_velocity_link) -O ./servers/proxy/server.jar
	(cd ./servers/proxy && bash bootstrap.sh)
	echo -n "Press RETURN after configuring forced hosts (or removing them)"
	read
fi

set +x
echo $SERVER_LAUNCHER > ./servers/launch.sh
set -x

for server in ./servers/*; do
	if [ -d $server ]; then
		server_names+=($(basename $server))
		server_dirs+=($server)

		if [ -z "$server_ports" ]; then
			server_ports+=($LOWEST_PORT)
		else
			server_ports+=($((${server_ports[-1]} + 1)))
		fi
	fi
done

clear_proxy

# Create a TMUX session
tmux new-session -d -s minecraft
tmux_pid=$(tmux list-sessions -F "#{session_name} #{session_id}" | grep minecraft | awk '{print $2}')

for i in ${!server_names[@]}; do
	server_dir=${server_dirs[$i]}
	server_name=${server_names[$i]}
	server_port=${server_ports[$i]}

	# If it's not the proxy, add it to the proxy
	if [ $server_name != "proxy" ]; then
		sed -i "s/server-port=.*/server-port=$server_port/g" "$server_dir/server.properties"
		add_server_to_proxy $server_name $server_port
	fi

	# Check if the server has a local `launch.sh` script (store in a boolean)
	if [ -f "$server_dir/launch.sh" ]; then
		launch_script="launch.sh"
	else
		launch_script="../launch.sh"
	fi

	tmux new-window -n $server_name -c $server_dir "bash $launch_script"
done

tmux kill-window -t minecraft:0
tmux attach-session -t minecraft

tmux kill-session -t minecraft

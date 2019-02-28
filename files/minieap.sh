#!/bin/sh

. /lib/functions.sh
. /lib/functions/network.sh
. ../netifd-proto.sh
init_proto "$@"

proto_minieap_init_config() {
	lasterror=1

	proto_config_add_string username
	proto_config_add_string password
	#proto_config_add_string nic
	proto_config_add_array 'module:list(string)'
	#proto_config_add_int daemonize #=0
	#proto_config_add_string if_impl #=sockraw
	proto_config_add_int max_fail
	proto_config_add_int max_retries
	proto_config_add_boolean no_auto_reauth
	proto_config_add_int wait_after_fail
	proto_config_add_int stage_timeout
	#proto_config_add_string proxy_lan_iface
	proto_config_add_int auth_round
	#proto_config_add_string pid_file #=none
	proto_config_add_string log_file
	#proto_config_add_string script #=/lib/netifd/minieap.script

	#rjv3 plugin
	proto_config_add_int heartbeat
	proto_config_add_int eap_bcast_addr
	proto_config_add_int dhcp_type
	proto_config_add_array 'rj_option:list(string)'
	proto_config_add_string service
	proto_config_add_string version_str
	proto_config_add_string dhcp_script
	proto_config_add_string 'fake_dns1:ip4addr'
	proto_config_add_string 'fake_dns2:ip4addr'
	proto_config_add_string fake_serial
	proto_config_add_int max_dhcp_count
}

proto_minieap_add_module() {
	[ -n "$1" ] && append "$3" "--module $1"
}

proto_minieap_add_rj_option() {
	[ -n "$1" ] && append "$3" "--rj-option $1"
}

proto_minieap_setup() {
	local config="$1"
	local iface="$2"

	local username password module max_fail max_retries no_auto_reauth wait_after_fail stage_timeout auth_round log_file heartbeat eap_bcast_addr dhcp_type rj_option service version_str dhcp_script fake_dns1 fake_dns2 fake_serial max_dhcp_count
	json_get_vars username password max_fail max_retries no_auto_reauth wait_after_fail stage_timeout auth_round log_file heartbeat eap_bcast_addr dhcp_type service version_str dhcp_script fake_dns1 fake_dns2 fake_serial max_dhcp_count

	[ -z "$username" -o -z "$password" ] && {
		echo "minieap: Missing username or password." >&2
		proto_notify_error "$config" "MISSING_USER_OR_PASS"
		proto_block_restart "$config"
		return
	}

	local modules
	json_for_each_item proto_minieap_add_module module modules

	local rj_options
	json_for_each_item proto_minieap_add_rj_option rj_option rj_options

	[ "$no_auto_reauth" = 0 ] && no_auto_reauth=""

	network_is_up wan || (echo "wan is not ready, sleep 10s." >&2; sleep 10)

	proto_export "INTERFACE=$config"
	proto_run_command "$config" minieap \
		-u "$username" \
		-p "$password" \
		-n "$iface" \
		-b 0 \
		--script /lib/netifd/minieap.script \
		--pid-file none \
		${max_fail:+-l $max_fail} \
		${max_retries:+--max-retries $max_retries} \
		${no_auto_reauth:+--no-auto-reauth } \
		${wait_after_fail:+-r $wait_after_fail} \
		${stage_timeout:+-t $stage_timeout} \
		${auth_round:+-j $auth_round} \
		${log_file:+--log-file "$log_file"} \
		${heartbeat:+-e $heartbeat} \
		${eap_bcast_addr:+-a $eap_bcast_addr} \
		${dhcp_type:+-d $dhcp_type} \
		${service:+--service "$service"} \
		${version_str:+--version-str "$version_str"} \
		${fake_dns1:+--fake-dns1 $fake_dns1} \
		${fake_dns2:+--fake-dns2 $fake_dns2} \
		${fake_serial:+--fake-serial "$fake_serial"} \
		${max_dhcp_count:+--max-dhcp-count $max_dhcp_count} \
		$modules $rj_options
}

proto_minieap_teardown() {
	local interface="$1"

	[ ${ERROR:-0} -ne 0 ] && {
		echo "minieap: Program exited with code $ERROR." >&2
		proto_notify_error "$interface" "EXIT_FAILURE"
	}

	proto_block_restart "$interface"
	proto_kill_command "$interface"
}

add_protocol minieap

.PHONY: all build update format install

all: build install

build:
	cargo build --release

update:
	cargo update

format:
	cargo fmt --all

install: build
	@echo "-- Stopping running daemons before install"
	-pkill -f battery_daemon 2>/dev/null || true
	@sleep 1
	mkdir -p ../helpers
	cd target/release && strip \
		get_network_status get_battery_status get_audio_status \
		get_bluetooth_status get_power_profile battery_daemon \
		log_battery osdctl screenshot ports_menu get_sys_diagnostics \
		check_daemons parse_binds mtp_notify display_toggle 2>/dev/null || true
	cp target/release/get_apps_list ../helpers/get_apps_list
	cp target/release/get_network_status ../helpers/get_network_status
	cp target/release/get_battery_status ../helpers/get_battery_status
	cp target/release/get_audio_status ../helpers/get_audio_status
	cp target/release/get_bluetooth_status ../helpers/get_bluetooth_status
	cp target/release/get_power_profile ../helpers/get_power_profile
	-cp target/release/battery_daemon ../helpers/battery_daemon
	cp target/release/log_battery ../helpers/log_battery
	cp target/release/osdctl ../helpers/osdctl
	cp target/release/screenshot ../helpers/screenshot
	cp target/release/ports_menu ../helpers/ports_menu
	cp target/release/get_sys_diagnostics ../helpers/get_sys_diagnostics
	cp target/release/check_daemons ../helpers/check_daemons
	cp target/release/parse_binds ../helpers/parse_binds
	-cp target/release/mtp_notify ../helpers/mtp_notify
	cp target/release/display_toggle ../helpers/display_toggle

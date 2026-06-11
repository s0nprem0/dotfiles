.PHONY: all build install

all: build install

build:
	cargo build --release

install: build
	mkdir -p ../helpers
	cp target/release/get_network_status ../helpers/get_network_status
	cp target/release/get_battery_status ../helpers/get_battery_status
	cp target/release/get_audio_status ../helpers/get_audio_status
	cp target/release/get_bluetooth_status ../helpers/get_bluetooth_status
	cp target/release/get_power_profile ../helpers/get_power_profile
	cp target/release/battery_daemon ../helpers/battery_daemon
	cp target/release/log_battery ../helpers/log_battery
	cp target/release/osdctl ../helpers/osdctl
	cp target/release/screenshot ../helpers/screenshot
	cp target/release/ports_menu ../helpers/ports_menu

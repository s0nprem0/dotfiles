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
	cp target/release/get_brightness_status ../helpers/get_brightness_status
	cp target/release/battery_daemon ../helpers/battery_daemon

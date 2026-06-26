.PHONY: all build update format install

BINARIES := \
	get_apps_list \
	get_network_status \
	get_battery_status \
	get_audio_status \
	get_bluetooth_status \
	get_power_profile \
	get_sysmon_status \
	battery_daemon \
	log_battery \
	osdctl \
	screenshot \
	ports_menu \
	get_sys_diagnostics \
	check_daemons \
	parse_binds \
	mtp_notify \
	display_toggle \
	caffeine \
	list_presets \
	apply_preset

HELPER_DIR := $(HOME)/.config/quickshell/helpers

all: build install

build:
	cargo build --release

update:
	cargo update

format:
	cargo fmt --all

install: build
	@echo "-- Stopping running daemons before install"
	-pkill -f battery_daemon >/dev/null 2>&1 || true
	-pkill -f get_audio_status >/dev/null 2>&1 || true

	@sleep 1

	mkdir -p $(HELPER_DIR)

	@echo "-- Stripping binaries"
	@for bin in $(BINARIES); do \
		if [ -f target/release/$$bin ]; then \
			strip target/release/$$bin || true; \
		fi; \
	done

	@echo "-- Installing helpers"
	@for bin in $(BINARIES); do \
		if [ -f target/release/$$bin ]; then \
			cp target/release/$$bin $(HELPER_DIR)/; \
		fi; \
	done

	@echo "-- Installation complete"

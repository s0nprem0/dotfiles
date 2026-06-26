pub mod battery;
pub mod command;
pub mod display;
pub mod external;
pub mod icon;
pub mod paths;
pub mod settings;
pub mod state_file;

pub use battery::{BatterySnapshot, battery_snapshot, find_battery_dir};
pub use command::{run_cmd, run_cmd_with_stderr};
pub use display::{
    get_current_mode, get_current_mode_from, get_internal_monitors, get_monitor_by_id,
    get_monitor_by_name, get_monitors, get_primary_monitor, get_monitor_scale,
    get_monitor_transform, load_display_config, save_display_config, set_mode,
    set_mode_verified, set_monitor_scale, set_monitor_transform, toggle_mode,
    DisplayConfig, DisplayMode, Monitor, MonitorSettings,
};
pub use external::{
    active_wifi_device, brightnessctl_percent, cidr_to_netmask, find_kbd_backlight_device,
    parse_percent, split_nmcli_t_line, wpctl_get_volume,
};
pub use icon::cache::IconResolver;
pub use icon::{ApplicationInfo, IconCache, IconResult};
pub use paths::{cache_dir, home_dir, quickshell_dir};
pub use settings::{load_json_with_default, save_json_atomic};
pub use state_file::{atomic_write_json, print_json, read_json, read_trimmed, round_to};

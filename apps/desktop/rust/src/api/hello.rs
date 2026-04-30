// Phase 0 smoke test — forwards to tindra-core's api::hello.
// To remove once Phase 1 starts and real session/profile APIs land.

use flutter_rust_bridge::frb;

#[frb(sync)]
pub fn echo(msg: String) -> String {
    tindra_core::api::hello::echo(msg)
}

#[frb(sync)]
pub fn core_version() -> String {
    tindra_core::api::hello::core_version()
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

// FFI bridge surface for the Tindra desktop app.
// Each module here is read by flutter_rust_bridge codegen and produces the
// matching Dart API. Implementations forward to `tindra-core` (the real
// engine) so this layer stays a thin, allocation-cheap shim.

pub mod hello;
pub mod profiles;
pub mod ssh;

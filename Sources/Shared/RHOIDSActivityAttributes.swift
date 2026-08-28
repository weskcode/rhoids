// Re-export from the shared package so that code in the app target
// can continue to use `RHOIDSActivityAttributes` without an explicit
// `import RHOIDSShared`. The canonical definition lives in the
// RHOIDSShared local Swift package to guarantee a single module
// identity across the app and widget extension (required for
// ActivityKit type matching on physical devices).
@_exported import RHOIDSShared

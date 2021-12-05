const std = @import("std");

// Edit these constants to change bundle
const w4exe = "snek";
const w4title = "Snek";
const w4desc = "U r snek. Die do not.";
const w4icon: ?[]const u8 = "assets/fruit.png";
const w4url: ?[]const u8 = null;
const w4timestamp = false;

pub fn build(b: *std.build.Builder) void {
    const lib = b.addSharedLibrary(w4exe, "src/main.zig", .unversioned);
    lib.setBuildMode(.ReleaseSafe);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.global_base = 6560;
    lib.stack_size = 8192;
    lib.install();

    const w4_run = b.addSystemCommand(&[_][]const u8{ "w4", "run-native" });
    w4_run.addArtifactArg(lib);

    const run_step = b.step("run", "Run using `w4 run-native`");
    run_step.dependOn(&lib.step);
    run_step.dependOn(&w4_run.step);

    const BundleTargets = enum { html, windows, mac, linux };

    const bundle_mac = b.option(bool, "mac", "create a mac bundle") orelse false;
    const bundle_html = b.option(bool, "html", "create a html bundle") orelse true;
    const bundle_linux = b.option(bool, "linux", "create a linux bundle") orelse false;
    const bundle_windows = b.option(bool, "windows", "create a windows bundle") orelse false;

    var bundle_targets = std.BoundedArray(BundleTargets, 4).init(0) catch unreachable;

    if (bundle_mac) bundle_targets.append(.mac) catch unreachable;
    if (bundle_html) bundle_targets.append(.html) catch unreachable;
    if (bundle_linux) bundle_targets.append(.linux) catch unreachable;
    if (bundle_windows) bundle_targets.append(.windows) catch unreachable;

    const w4_bundle = b.addSystemCommand(&[_][]const u8{ "w4", "bundle" });
    for (bundle_targets.constSlice()) |target| {
        const prefix = b.getInstallPath(.bin, "");
        const path = std.fs.path.join(b.allocator, &.{ prefix, w4exe }) catch unreachable;
        defer b.allocator.free(path);
        switch (target) {
            .mac => w4_bundle.addArgs(&.{ "--mac", b.fmt("{s}-mac", .{path}) }),
            .html => w4_bundle.addArgs(&.{ "--html", b.fmt("{s}.html", .{path}) }),
            .linux => w4_bundle.addArgs(&.{ "--linux", path }),
            .windows => w4_bundle.addArgs(&.{ "--windows", b.fmt("{s}.exe", .{path}) }),
        }
    }
    w4_bundle.addArgs(&.{ "--title", w4title });
    w4_bundle.addArgs(&.{ "--description", w4desc });
    if (w4url) |icon| w4_bundle.addArgs(&.{ "--icon-url", icon });
    if (w4icon) |icon| w4_bundle.addArgs(&.{ "--icon-file", icon });
    if (w4timestamp) w4_bundle.addArg("--timestamp");
    w4_bundle.addArtifactArg(lib);

    const bundle_step = b.step("bundle", "Bundle using `w4 bundle`");
    bundle_step.dependOn(&lib.step);
    bundle_step.dependOn(&w4_bundle.step);
}

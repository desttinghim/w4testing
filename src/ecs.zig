const std = @import("std");

pub fn World(comptime Component: type) type {
    return struct {
        components: ComponentPool,
        alloc: std.mem.Allocator,
        pub const Query = ComponentQuery;

        const ComponentPool = std.MultiArrayList(Component);
        const ComponentEnum = std.meta.FieldEnum(Component);
        const ComponentSet = std.EnumSet(ComponentEnum);
        const ComponentQuery = struct {
            required: ComponentSet = ComponentSet.init(.{}),
            excluded: ComponentSet = ComponentSet.init(.{}),

            pub fn init() @This() {
                return @This(){};
            }

            pub fn query(require_set: []const ComponentEnum, exclude_set: []const ComponentEnum) @This() {
                var this = @This(){};
                for (require_set) |f| {
                    this.required.insert(f);
                }
                for (exclude_set) |f| {
                    this.excluded.insert(f);
                }
                return this;
            }

            pub fn require(set: []const ComponentEnum) @This() {
                var this = @This(){};
                for (set) |f| {
                    this.required.insert(f);
                }
                return this;
            }

            pub fn exclude(set: []const ComponentEnum) @This() {
                var this = @This(){};
                for (set) |f| {
                    this.excluded.insert(f);
                }
                return this;
            }
        };

        const fields = std.meta.fields(Component);

        pub fn init(alloc: std.mem.Allocator) @This() {
            return @This(){
                .components = ComponentPool{},
                .alloc = alloc,
            };
        }

        pub fn create(this: *@This(), component: Component) u32 {
            this.components.append(this.alloc, component) catch unreachable;
            return this.components.len;
        }

        pub fn destroy(this: *@This(), component: u32) void {
            // TODO
            _ = this;
            _ = component;
        }

        const Self = @This();
        const WorldIterator = struct {
            world: *Self,
            lastComponent: ?Component,
            index: usize,
            query: ComponentQuery,

            pub fn init(w: *Self, q: ComponentQuery) @This() {
                return @This(){
                    .world = w,
                    .lastComponent = null,
                    .index = 0,
                    .query = q,
                };
            }

            pub fn next(this: *@This()) ?*Component {
                if (this.lastComponent) |e| this.world.components.set(this.index - 1, e);
                if (this.index == this.world.components.len) return null;
                var match = false;
                while (!match) {
                    if (this.index == this.world.components.len) return null;
                    this.lastComponent = this.world.components.get(this.index);
                    match = true;
                    inline for (fields) |f| {
                        const fenum = std.meta.stringToEnum(ComponentEnum, f.name) orelse unreachable;
                        const required = this.query.required.contains(fenum);
                        const excluded = this.query.excluded.contains(fenum);
                        const has = @field(this.lastComponent.?, f.name) != null;
                        if ((required and !has) or (excluded and has)) {
                            match = false;
                            break;
                        }
                    }
                    this.index += 1;
                }
                return &this.lastComponent.?;
            }
        };

        pub fn iterAll(this: *@This()) WorldIterator {
            return WorldIterator.init(this, ComponentQuery{});
        }

        pub fn iter(this: *@This(), query: ComponentQuery) WorldIterator {
            return WorldIterator.init(this, query);
        }

        pub fn process(this: *@This(), q: *ComponentQuery, func: fn (e: *Component) void) void {
            var s = this.components.slice();
            var i: usize = 0;
            while (i < s.len) : (i += 1) {
                var e = this.components.get(i);
                var matches = true;
                inline for (fields) |f| {
                    const fenum = std.meta.stringToEnum(ComponentEnum, f.name) orelse unreachable;
                    const required = q.required.contains(fenum);
                    const has = @field(e, f.name) != null;
                    if (required and !has) matches = false;
                    break;
                }
                if (matches) {
                    func(&e);
                    this.components.set(i, e);
                }
            }
        }
    };
}

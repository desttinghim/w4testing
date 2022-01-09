const std = @import("std");

pub fn World(comptime Entity: type) type {
    return struct {
        entities: EntityPool,
        alloc: std.mem.Allocator,

        const EntityPool = std.MultiArrayList(Entity);
        const EntityEnum = std.meta.FieldEnum(Entity);
        const EntitySet = std.EnumSet(EntityEnum);
        const EntityQuery = struct {
            required: std.EnumSet(EntityEnum),
        };

        const fields = std.meta.fields(Entity);

        pub fn init(alloc: std.mem.Allocator) @This() {
            return @This(){
                .entities = EntityPool{},
                .alloc = alloc,
            };
        }

        pub fn create(this: *@This(), entity: Entity) u32 {
            this.entities.append(this.alloc, entity) catch unreachable;
            return this.entities.len;
        }

        pub fn destroy(this: *@This(), entity: u32) void {
            // TODO
            _ = this;
            _ = entity;
        }

        const Self = @This();
        const WorldIterator = struct {
            world: *Self,
            lastEntity: ?Entity,
            index: usize,
            query: EntityQuery,

            pub fn init(w: *Self) @This() {
                return @This(){
                    .world = w,
                    .lastEntity = null,
                    .index = 0,
                    .query = EntityQuery{ .required = EntitySet.init(.{}) },
                };
            }

            pub fn next(this: *@This()) ?*Entity {
                if (this.lastEntity) |e| this.world.entities.set(this.index - 1, e);
                if (this.index == this.world.entities.len) return null;
                this.lastEntity = this.world.entities.get(this.index);
                this.index += 1;
                return &this.lastEntity.?;
            }
        };

        pub fn iterAll(this: *@This()) WorldIterator {
            return WorldIterator.init(this);
        }

        pub fn query(require: []const EntityEnum) EntityQuery {
            var q = EntitySet.init(.{});
            for (require) |f| {
                q.insert(f);
            }
            return EntityQuery{ .required = q };
        }

        pub fn process(this: *@This(), q: *EntityQuery, func: fn (e: *Entity) void) void {
            var s = this.entities.slice();
            var i: usize = 0;
            while (i < s.len) : (i += 1) {
                var e = this.entities.get(i);
                var matches = true;
                inline for (fields) |f| {
                    const fenum = std.meta.stringToEnum(EntityEnum, f.name) orelse unreachable;
                    const required = q.required.contains(fenum);
                    const has = @field(e, f.name) != null;
                    if (required and !has) matches = false;
                    break;
                }
                if (matches) {
                    func(&e);
                    this.entities.set(i, e);
                }
            }
        }
    };
}

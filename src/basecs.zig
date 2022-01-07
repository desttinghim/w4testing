const std = @import("std");

/// Runtime generic store for components. Does not manage memory
const ComponentPool = struct {
    data: []u8,
    elementSize: usize,

    fn init(data: []u8, elementSize: usize) @This() {
        return @This(){
            .data = data,
            .elementSize = elementSize,
        };
    }

    fn get(this: *@This(), index: usize) []u8 {
        const begin = index * this.elementSize;
        return this.data[begin .. begin + this.elementSize];
    }
};

/// Accepts a struct where each component is a field
fn ECS(comptime Components: type) type {
    // Component Enum
    const ComponentEnum = std.meta.FieldEnum(Components);
    const ComponentSet = std.EnumSet(ComponentEnum);
    const ComponentMap = std.EnumMap(ComponentEnum, ComponentPool);

    // Component Union
    const fields = std.meta.fields(Components);
    var unionFields: [fields.len]std.builtin.TypeInfo.UnionField = undefined;
    inline for (fields) |field, i| {
        unionFields[i] = .{
            .alignment = field.alignment,
            .name = field.name,
            .field_type = field.field_type,
        };
    }
    const ComponentUnion = @Type(.{ .Union = .{
        .layout = .Auto,
        .tag_type = ComponentEnum,
        .fields = &unionFields,
        .decls = &[_]std.builtin.TypeInfo.Declaration{},
    } });

    // Entity
    const EntityID = struct {
        id: u64,
        const Invalid = std.math.maxInt(u32);
        pub fn init(index: u32, version: u32) @This() {
            return @This(){
                .id = ((@as(u64, index) << 32) | version),
            };
        }
        pub fn getIndex(this: @This()) u32 {
            return @truncate(u32, this.id >> 32);
        }
        pub fn getVersion(this: @This()) u32 {
            return @truncate(u32, this.id);
        }
        pub fn isValid(this: @This()) bool {
            return (this.id >> 32) != Invalid;
        }
    };
    const Entity = struct {
        id: EntityID,
        mask: ComponentSet,
    };

    // TODO: Remove this parameter and store data in heap instead
    const MAX_ENTITIES = 100;

    const EntityPool = std.BoundedArray(Entity, MAX_ENTITIES);

    var componentSize: [fields.len]usize = undefined;
    const TotalComponentSize = totalsize: {
        var sum = 0;
        inline for (fields) |field, i| {
            const size = @sizeOf(field.field_type);
            componentSize[i] = size;
            sum += size;
        }
        break :totalsize sum;
    };
    const ComponentSize = componentSize;

    // World
    const World = struct {
        entities: EntityPool,
        freeEntities: std.BoundedArray(u32, MAX_ENTITIES),
        components: ComponentMap,

        const MIN_HEAP = TotalComponentSize;

        pub fn init(heap: []u8) !@This() {
            const maxEnt = heap.len / TotalComponentSize;
            if (heap.len < TotalComponentSize or maxEnt < 1) {
                return error.InsufficientHeap;
            }
            var compMap = ComponentMap.init(.{});
            var begin: usize = 0;
            inline for (fields) |field, i| {
                const e = std.enums.nameCast(ComponentEnum, field.name);
                const size = ComponentSize[i];
                const total = size * maxEnt;
                compMap.put(e, ComponentPool.init(heap[begin .. begin + total], size));
                begin += total;
            }
            return @This(){
                .entities = EntityPool.init(0) catch unreachable,
                .freeEntities = std.BoundedArray(u32, MAX_ENTITIES).init(0) catch unreachable,
                .components = compMap,
            };
        }

        pub fn create(this: *@This()) EntityID {
            if (this.freeEntities.len != 0) {
                var newIndex = this.freeEntities.pop();
                var newID = EntityID.init(newIndex, this.entities.get(newIndex).id.getVersion());
                this.entities.slice()[newIndex].id = newID;
                return newID;
            }
            const index = @truncate(u32, this.entities.len);
            const id = EntityID.init(index, 0);
            var entity = Entity{ .id = id, .mask = ComponentSet.init(.{}) };
            this.entities.append(entity) catch unreachable;
            return id;
        }

        /// Takes an entity ID and a component struct and stores it
        pub fn assign(this: *@This(), entity: EntityID, comptime tag: ComponentEnum, component: anytype) !void {
            const i = entity.getIndex();
            if (this.entities.get(i).id.id != entity.id)
                return error.EntityRemoved;

            const T =
                this.entities.slice()[i].mask.insert(tag);
            var pool = this.components.get(tag) orelse return error.UninitializedComponentPool;
            std.mem.copy(T, @ptrCast(T, pool.get(i)), component);
        }

        pub fn get(this: *@This(), entity: EntityID, comptime component: ComponentUnion) ?*component {
            const i = entity.getIndex();
            if (this.entities.get(i).id.id != entity.id)
                return error.EntityRemoved;

            if (!this.entities.get(i).mask.contains(component)) {
                return null;
            }
            var store = this.components.get(component);
            return store[i];
        }

        pub fn remove(this: *@This(), entity: EntityID, component: ComponentEnum) void {
            const i = entity.getIndex();
            if (this.entities.get(i).id.id != entity.id)
                return;

            this.entities.slice()[i].mask.remove(component);
        }

        pub fn destroy(this: *@This(), entity: EntityID) void {
            var new = EntityID.init(EntityID.Invalid, entity.getVersion() + 1);
            const i = entity.getIndex();
            var entities = this.entities.slice();
            entities[i].id = new;
            entities[i].mask.setIntersection(ComponentSet.init(.{}));
            this.freeEntities.append(i) catch std.log.warn("help", .{});
        }

        // pub fn query(require: []const EntityEnum) EntityQuery {
        //     var q = EntitySet.init(.{});
        //     for (require) |f| {
        //         q.insert(f);
        //     }
        //     return EntityQuery{ .required = q };
        // }

        // pub fn process(this: *@This(), q: *EntityQuery, func: fn (e: *Entity) void) void {
        //     for (this.entities.slice()) |*e| {
        //         var matches = true;
        //         inline for (fields) |f| {
        //             const fenum = std.meta.stringToEnum(EntityEnum, f.name) orelse unreachable;
        //             const required = q.required.contains(fenum);
        //             const has = @field(e, f.name) != null;
        //             if (required and !has) matches = false;
        //             break;
        //         }
        //         if (matches) func(e);
        //     }
        // }
    };

    return World;
}

test "Insufficient space" {
    var heap = [1]u8{0};
    const comp = struct { dummy: u32 };
    const World = ECS(comp);
    try std.testing.expectError(error.InsufficientHeap, World.init(&heap));
}

test "Entity" {
    var heap: [300]u8 = undefined;
    const Vec2 = struct { x: i32, y: i32 };
    const Comp = struct { pos: Vec2, hp: i32 };
    const World = ECS(Comp);
    std.log.warn("Minimum heap is {}", .{World.MIN_HEAP});
    var world = try World.init(&heap);

    var e = world.create();
    defer world.destroy(e);

    try world.assign(e, .{ .pos = .{ .x = 10, .y = 10 } });
    defer world.remove(e, .pos);
}

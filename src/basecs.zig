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

    fn get(this: @This(), index: usize) *u8 {
        return &this.data[index];
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
                .mask = ComponentSet.init(.{}),
            };
        }
        pub fn getIndex(this: @This()) u32 {
            return this.id >> 32;
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

    const MAX_ENTITIES = 100;

    const EntityPool = std.BoundedArray(Entity, MAX_ENTITIES);

    var componentPoolData: [fields.len][2]usize = undefined;
    const TotalData = tot: {
        var begin = 0;
        inline for (fields) |field, i| {
            const size = @sizeOf(field.field_type);
            componentPoolData[i] = .{ begin, size };
            begin += size * MAX_ENTITIES;
        }
        break :tot begin;
    };
    const ComponentPoolData = componentPoolData;

    // World
    const World = struct {
        entities: EntityPool,
        freeEntities: std.BoundedArray(u32, MAX_ENTITIES),
        components: ComponentMap,

        const MIN_HEAP = TotalData;

        pub fn init(heap: []u8) !@This() {
            if (heap.len < TotalData) {
                return error.InsufficientHeap;
            }
            var compMap = ComponentMap.init(.{});
            inline for (fields) |field, i| {
                const e = std.enums.nameCast(ComponentEnum, field.name);
                const data = ComponentPoolData[i];
                const begin = data[0];
                const size = data[1];
                const total = size * MAX_ENTITIES;
                compMap.put(e, ComponentPool.init(heap[begin .. begin + total], size));
            }
            return @This(){
                .entities = EntityPool.init(0) catch unreachable,
                .freeEntities = std.BoundedArray(u32, MAX_ENTITIES).init(0) catch unreachable,
                .components = compMap,
            };
        }

        pub fn create(this: *@This()) EntityID {
            if (this.freeEntities.len != 0) {
                var newIndex = this.freeEntities.pop() catch unreachable;
                var newID = EntityID.init(newIndex, this.entities.get(newIndex).version);
                this.entities.set(newIndex, newID);
                return newID;
            }
            const index = this.entities.len;
            const id = EntityID.init(index, 0);
            var entity = Entity{ .id = id, .mask = ComponentSet.init(.{}) };
            this.entities.append(entity) catch unreachable;
            return id;
        }

        /// Takes an entity ID and a component struct and stores it
        pub fn assign(this: *@This(), entity: EntityID, comptime component: ComponentUnion) *component {
            const i = entity.getIndex();
            if (this.entities.get(i).id != entity.id)
                return error.EntityRemoved;

            const tag = std.enums.nameCast(ComponentEnum, @tagName(component));
            var pool = this.components.get(tag) orelse unreachable;
            pool.get(i).* = component;
            this.entities.slice()[i].mask.insert(tag);
        }

        pub fn get(this: *@This(), entity: EntityID, comptime component: ComponentUnion) ?*component {
            const i = entity.getIndex();
            if (this.entities.get(i).id != entity.id)
                return error.EntityRemoved;

            if (!this.entities.get(i).mask.contains(component)) {
                return null;
            }
            var store = this.components.get(component);
            return store[i];
        }

        pub fn remove(this: *@This(), entity: EntityID, component: ComponentEnum) !void {
            const i = entity.getIndex();
            if (this.entities.get(i).id != entity.id)
                return error.EntityRemoved;

            this.entities.slice()[i].mask.remove(component);
        }

        pub fn destroy(this: *@This(), entity: EntityID) void {
            var new = EntityID.init(EntityID.Invalid, entity.version + 1);
            const i = entity.getIndex();
            var entities = this.entities.slice();
            entities[i].id = new;
            entities[i].mask.reset();
            try this.freeEntities.append(i);
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
    const comp = struct { dummy: u8 };
    const World = ECS(comp);
    std.log.warn("Minimum heap is {}", .{World.MIN_HEAP});
    try std.testing.expectError(error.InsufficientHeap, World.init(&heap));
}

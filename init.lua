-- Seeker of knowledge? :^)

local mod_id = "disable-mod-restrictions"
function setting_get(name)
    return ModSettingGet(mod_id .. "." .. name)
end

local ffi = require("ffi")

ffi.cdef([[

bool VirtualProtect(void* adress, size_t size, int new_protect, int* old_protect);
int memcmp(const void *buffer1, const void *buffer2, size_t count);

]])

local nop2 = ffi.new("char[2]", {0x66, 0x90})
local nop6 = ffi.new("char[6]", {0x66, 0x0f, 0x1f, 0x44, 0x00, 0x00})

local test_non_zero2 = ffi.new("char[2]", {0x85, 0xe4})

local game_modifications = {
    records = {
        {
            location = ffi.cast("void*", 0x009c1b00),
            original = ffi.new("char[2]", {0x77, 0x1b}),
            patch_bytes = ffi.new("char[2]", {0xeb, 0x2c}),
        },
    },

    achievements = {
        { -- By name
            location = ffi.cast("void*", 0x0076d1f2),
            original = ffi.new("char[2]", {0xa1, 0x60}),
            patch_bytes = ffi.new("char[2]", {0xeb, 0x1f}),
        },
        { -- By ID
            location = ffi.cast("void*", 0x0076d292),
            original = ffi.new("char[2]", {0xa1, 0x60}),
            patch_bytes = ffi.new("char[2]", {0xeb, 0x1f}),
        },
    },

    cauldron = {
        {
            location = ffi.cast("void*", 0x005c84e7),
            original = ffi.new("char[6]", {0x0f, 0x85, 0x41, 0x07, 0x00, 0x00}),
            patch_bytes = nop6,
        },
    },

    eyes = {
        {
            location = ffi.cast("void*", 0x005b4185),
            original = ffi.new("char[6]", {0x0f, 0x85, 0x9d, 0x01, 0x00, 0x00}),
            patch_bytes = nop6,
        },
    },

    bones = {
        {
            location = ffi.cast("void*", 0x006416b4),
            original = ffi.new("char[6]", {0x0f, 0x87, 0x29, 0x01, 0x00, 0x00}),
            patch_bytes = nop6,
        }
    },

    streaks = {
        {
            location = ffi.cast("void*", 0x0063a4ac),
            original = ffi.new("char[2]", {0x74, 0x25}),
            patch_bytes = nop2,
        },
        {
            location = ffi.cast("void*", 0x006750ee),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
        {
            location = ffi.cast("void*", 0x009c1110),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
        {
            location = ffi.cast("void*", 0x009c1127),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
        {
            location = ffi.cast("void*", 0x009c1abc),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
    },

    gods_are_very_curious = {
        {
            location = ffi.cast("void*", 0x00aa4337),
            original = ffi.new("char[6]", {0x0f, 0x85, 0x77, 0x01, 0x00, 0x00}),
            patch_bytes = nop6,
        },
    },
}


-- The init.lua script will get unloaded & reloaded when you start a new game so
-- we need some code to keep track of which patches have been enabled.  Just do
-- so by looking at the memory.

function get_enabled_modifications()
    local enabled = {}
    for name, modification in pairs(game_modifications) do
        local patch = modification[1]
        enabled[name] = ffi.C.memcmp(patch.location, patch.patch_bytes, ffi.sizeof(patch.patch_bytes)) == 0
    end
    return enabled
end


-- Desired modifications are the values that were configured by the user.

function get_desired_modifications()
    local desired = {}
    for name, _ in pairs(game_modifications) do
        desired[name] = setting_get(name)
    end
    return desired
end


-- Compare enabled vs. desired and reconfigure to desired.

function configure_desired_modifications()
    local enabled = get_enabled_modifications()
    local desired = get_desired_modifications()

    for name, modification in pairs(game_modifications) do
        if enabled[name] ~= desired[name] then
            configure_modification(modification, desired[name])
        end
    end

    local enabled = get_enabled_modifications()
    local desired = get_desired_modifications()

    for name, modification in pairs(game_modifications) do
        if enabled[name] ~= desired[name] then
            print(
                "Warning: modification " .. name ..
                " couldn't be configured to desired state: " ..
                tostring(desired[name])
            )
        end
    end
end


-- Might've changed settings in the pause menu, reconfigure the patches.

function OnPausedChanged()
    configure_desired_modifications()
end


function configure_modification(modification, enable)
    for _, patch in ipairs(modification) do
        local patch_bytes = enable and patch.patch_bytes or patch.original
        local expect =      enable and patch.original or patch.patch_bytes

        patch_location(patch.location, expect, patch_bytes)
    end
end

function patch_location(location, expect, patch_bytes)
    if ffi.C.memcmp(location, expect, ffi.sizeof(expect)) ~= 0 then
        print("Unexpected instructions at location.")
        return false
    end

    local restore_protection = ffi.new("int[1]")
    local prot_success = ffi.C.VirtualProtect(
        location, ffi.sizeof(patch_bytes), 0x40, restore_protection)

    if not prot_success then
        print("Couldn't change memory protection.")
        return false
    end

    ffi.copy(location, patch_bytes, ffi.sizeof(patch_bytes))

    -- Restore protection
    ffi.C.VirtualProtect(
        location,
        ffi.sizeof(patch_bytes),
        restore_protection[0],
        restore_protection)

    return true
end


-- Initial configuration when you start a run.

configure_desired_modifications()

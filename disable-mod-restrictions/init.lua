-- Seeker of knowledge? :^)

local mod_id = "disable-mod-restrictions"
local function setting_get(name)
    return ModSettingGet(mod_id .. "." .. name)
end

local ffi = require("ffi")

ffi.cdef([[

bool VirtualProtect(void* adress, size_t size, int new_protect, int* old_protect);
int memcmp(const void *buffer1, const void *buffer2, size_t count);

unsigned long GetCurrentDirectoryA(unsigned long nBufferLength, char* lpBuffer);
unsigned long GetModuleFileNameA(void* hModule, const char* lpFilename, unsigned long nSize);

]])

function get_cwd()
    local buffer = ffi.new("char[2000]")
    local ret = ffi.C.GetCurrentDirectoryA(ffi.sizeof(buffer), buffer)
    if ret ~= 0 then
        return ffi.string(buffer, ret)
    end
    return nil
end

function get_module_name()
    local buffer = ffi.new("char[2000]")
    local ret = ffi.C.GetModuleFileNameA(nil, buffer, ffi.sizeof(buffer))
    if ret ~= 0 then
        return ffi.string(buffer, ret)
    end
    return nil
end

function print_array(ptr, len)
    local str = {}
    ptr = ffi.cast("unsigned char*", ptr)
    for i=0,len-1 do
        table.insert(str, ("%02x"):format(ptr[i]))
    end
    return table.concat(str, ", ")
end

local nop2 = ffi.new("char[2]", {0x66, 0x90})
local nop6 = ffi.new("char[6]", {0x66, 0x0f, 0x1f, 0x44, 0x00, 0x00})

local test_non_zero2 = ffi.new("char[2]", {0x85, 0xe4})

local game_modifications = {
    intro = {
        {
            location = ffi.cast("void*", 0x0061e327),
            original = ffi.new("char[6]", {0x2b, 0x0d, 0x74, 0x76, 0x00, 0x01}),
            patch_bytes = ffi.new("char[6]", {0xb9, 0x01, 0x00, 0x00, 0x00, 0x90}),
        },
    },

    achievements = {
        { -- By name
            location = ffi.cast("void*", 0x007659b2),
            original = ffi.new("char[2]", {0xa1, 0x90}),
            patch_bytes = ffi.new("char[2]", {0xeb, 0x1f}),
        },
        { -- By ID
            location = ffi.cast("void*", 0x00765a52),
            original = ffi.new("char[2]", {0xa1, 0x90}),
            patch_bytes = ffi.new("char[2]", {0xeb, 0x1f}),
        },
    },

    cauldron = {
        {
            location = ffi.cast("void*", 0x005c2077),
            original = ffi.new("char[6]", {0x0f, 0x85, 0x41, 0x07, 0x00, 0x00}),
            patch_bytes = nop6,
        },
    },

    eyes = {
        {
            location = ffi.cast("void*", 0x005add15),
            original = ffi.new("char[6]", {0x0f, 0x85, 0x9d, 0x01, 0x00, 0x00}),
            patch_bytes = nop6,
        },
    },

    bones = {
        {
            location = ffi.cast("void*", 0x00628b14),
            original = ffi.new("char[6]", {0x0f, 0x87, 0x29, 0x01, 0x00, 0x00}),
            patch_bytes = nop6,
        }
    },

    streaks = {
        -- Records
        {
            location = ffi.cast("void*", 0x009d5050),
            original = ffi.new("char[2]", {0x77, 0x1b}),
            patch_bytes = ffi.new("char[2]", {0xeb, 0x2c}),
        },
        -- Stats
        {
            location = ffi.cast("void*", 0x0062182c),
            original = ffi.new("char[2]", {0x74, 0x25}),
            patch_bytes = nop2,
        },
        {
            location = ffi.cast("void*", 0x0065380e),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
        {
            location = ffi.cast("void*", 0x009d4660),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
        {
            location = ffi.cast("void*", 0x009d4677),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
        {
            location = ffi.cast("void*", 0x009d500c),
            original = ffi.new("char[2]", {0x84, 0xc0}),
            patch_bytes = test_non_zero2,
        },
    },

    gods_are_afraid = {
        {
            location = ffi.cast("void*", 0x00996df8),
            original = ffi.new("char[6]", {0x0f, 0x85, 0x17, 0x01, 0x00, 0x00}),
            patch_bytes = nop6,
        },
    },

    gods_are_very_curious = {
        {
            location = ffi.cast("void*", 0x00abdb57),
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

    print("CWD", tostring(get_cwd()))
    print("MOD", tostring(get_module_name()))

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
        print("Unexpected instructions at location: ", tostring(location))
        print("  Expected: ", print_array(expect, ffi.sizeof(expect)))
        print("  Actual:   ", print_array(location, ffi.sizeof(expect)))
        print()
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

patch_location(ffi.cast("void*", 0x00e3b864),
    ffi.new("char[19]", {0x24, 0x6d, 0x65, 0x6e, 0x75, 0x70, 0x61, 0x75, 0x73, 0x65, 0x5f, 0x6d, 0x6f, 0x64, 0x73, 0x75, 0x73, 0x65, 0x64}),
    ffi.new("char[19]", {0x24, 0x61, 0x6e, 0x69, 0x6d, 0x61, 0x6c, 0x5f, 0x6c, 0x6f, 0x6e, 0x67, 0x6c, 0x65, 0x67, 0x00, 0x00, 0x00, 0x00}))

configure_desired_modifications()

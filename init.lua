-- Seeker of knowledge? :^)

local ffi = require("ffi")

ffi.cdef([[

bool VirtualProtect(void* adress, size_t size, int new_protect, int* old_protect);
int memcmp(const void *buffer1, const void *buffer2, size_t count);

]])

local err_msg = "Could not alter Noita.  Records will not be stored since you're using mods."
local suc_msg = "Success! Records will be kept despite having mods active."

function abort_patch(message)
    GamePrint(message)
    GamePrint(err_msg)
    error(message)
end

local target_location = ffi.cast("void*", 0x9c1b00)
local expected = ffi.new("char[2]", {0x77, 0x1b})
local replacement = ffi.new("char[2]", {0xeb, 0x2c})

if ffi.C.memcmp(target_location, replacement, ffi.sizeof(replacement)) == 0 then
    -- Already patched
    GamePrint(suc_msg)
    return
end

if ffi.C.memcmp(target_location, expected, ffi.sizeof(expected)) ~= 0 then
    msg = "Incorrect instructions at target location. " ..
          "This mod only works on noita.exe, Apr 23 2021, Steam version!"
    abort_patch(msg)
end

local restore_protection = ffi.new("int[1]")
local prot_success = ffi.C.VirtualProtect(
    target_location, ffi.sizeof(replacement), 0x40, restore_protection)

if not prot_success then
    abort_patch("Couldn't change memory protection.")
end

ffi.copy(target_location, replacement, ffi.sizeof(replacement))
ffi.C.VirtualProtect(
    target_location,
    ffi.sizeof(replacement),
    restore_protection[0],
    restore_protection)

GamePrint(suc_msg)

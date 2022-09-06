//! these buffers are used for creating resouces to be used for rendering

/// Commands that are submitted with a resource buffer
const Command = enum {
    CreateBuffer,
};

/// maximum number of commands that can be held by a buffer
const MAX_COMMANDS = 32;

/// commands that have been submitted to this buffer
commands: [MAX_COMMANDS]Command,

/// last index that has been used by this buffer
idx: usize,

//! This will have all the kinds of allocators we need
//! This will include:
//! Block: freelist of equal sized blocks allocated on page boundaries
//! Frame: for stuff that we don't need for more than one frame, cleared every frame
//! Frame-Buffer: for stuff that we don't need for more than two or three frames, ping-ponged

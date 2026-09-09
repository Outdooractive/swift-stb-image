extension STBImage {

    /// Reference to a pixel in an image.
    ///
    /// It contains an `UnsafeMutableBufferPointer` pointing into the image's
    /// buffer, and is only valid for the duration of the closure passed to
    /// ``STBImage/unsafePixelwiseConvert(_:)``. It must not escape the closure.
    public struct UnsafePixelRef {

        /// The pixel's x coordinate, starting at 0 on the left.
        public let x: Int

        /// The pixel's y coordinate, starting at 0 at the top.
        public let y: Int

        /// The number of channels of the image: 3 (RGB) or 4 (RGBA).
        public let channels: Int

        /// A buffer pointer to the pixel's channel values.
        ///
        /// - Warning: Only valid inside the closure that created this
        ///   reference. Keeping it alive past the closure or reading the
        ///   image through its own subscripts inside the closure are
        ///   undefined behavior.
        public let pointer: UnsafeMutableBufferPointer<UInt8>

        @inlinable
        init(x: Int,
             y: Int,
             channels: Int,
             pointer: UnsafeMutableBufferPointer<UInt8>
        ) {
            assert(pointer.count == channels)
            self.x = x
            self.y = y
            self.channels = channels
            self.pointer = pointer
        }

        @inlinable
        init(x: Int,
             y: Int,
             channels: Int,
             rebasing slice: Slice<UnsafeMutableBufferPointer<UInt8>>
        ) {
            self.init(x: x,
                      y: y,
                      channels: channels,
                      pointer: UnsafeMutableBufferPointer(rebasing: slice))
        }

        /// Reads or writes a single channel of the pixel.
        ///
        /// - Parameter channel: The channel index, 0 (red) to 2 (blue) and
        ///   3 (alpha) for RGBA images.
        @inlinable
        public subscript(channel: Int) -> UInt8 {
            get {
                return pointer[channel]
            }
            nonmutating set {
                pointer[channel] = newValue
            }
        }

    }

}

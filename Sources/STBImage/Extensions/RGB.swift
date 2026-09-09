
extension STBImage {
    
    /// Channel names for RGB images.
    public enum RGB: Int, CaseIterable {
        
        /// The red channel, at buffer index 0.
        case red = 0
        /// The green channel, at buffer index 1.
        case green = 1
        /// The blue channel, at buffer index 2.
        case blue = 2
        
        /// The number of channels of an RGB image.
        public static let channels: Int = 3
        
        /// The buffer index of the red channel.
        public static let redIndex: Int = RGBA.red.rawValue
        /// The buffer index of the green channel.
        public static let greenIndex: Int = RGBA.green.rawValue
        /// The buffer index of the blue channel.
        public static let blueIndex: Int = RGBA.blue.rawValue
        
        /// The buffer index of the first color channel.
        public static let colorStartIndex: Int = RGBA.red.rawValue
        
    }
    
}

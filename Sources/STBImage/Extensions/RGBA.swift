
extension STBImage {
    
    /// Channel names for RGBA images.
    public enum RGBA: Int, CaseIterable {
        
        /// The red channel, at buffer index 0.
        case red = 0
        /// The green channel, at buffer index 1.
        case green = 1
        /// The blue channel, at buffer index 2.
        case blue = 2
        /// The alpha channel, at buffer index 3.
        case alpha = 3
        
        /// The number of channels of an RGBA image.
        public static let channels: Int = 4
        
        /// The buffer index of the red channel.
        public static let redIndex: Int = RGBA.red.rawValue
        /// The buffer index of the green channel.
        public static let greenIndex: Int = RGBA.green.rawValue
        /// The buffer index of the blue channel.
        public static let blueIndex: Int = RGBA.blue.rawValue
        
        /// The buffer index of the first color channel.
        public static let colorStartIndex: Int = RGBA.red.rawValue
        /// The buffer index of the alpha channel.
        public static let alphaIndex: Int = RGBA.alpha.rawValue
        
    }
    
}

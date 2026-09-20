/// Image cache configuration constants
/// Protects against iOS Jetsam memory terminations when scrolling large photo sets
library;

/// Maximum number of image entries held in memory
const int kImageCacheMaximumSize = 100;

/// Maximum image cache size in bytes (120MB limit)
const int kImageCacheMaximumSizeBytes = 120 * 1024 * 1024;

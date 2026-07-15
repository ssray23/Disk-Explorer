import Foundation

public struct SystemInfo {
    public let osVersion: String
    public let macModel: String
    public let cpuBrand: String
    public let physicalMemory: UInt64
    
    public let totalDiskSpace: Int64
    public let usedDiskSpace: Int64
    public let availableDiskSpace: Int64
    public let purgeableDiskSpace: Int64
}

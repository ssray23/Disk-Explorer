import Foundation
import Darwin

public class SystemInfoService {
    
    public static func getSystemInfo() -> SystemInfo {
        let processInfo = ProcessInfo.processInfo
        
        let osVersion = processInfo.operatingSystemVersionString
        let physicalMemory = processInfo.physicalMemory
        
        let cpuBrand = getSysctlString(key: "machdep.cpu.brand_string") ?? "Unknown CPU"
        let macModel = getSysctlString(key: "hw.model") ?? "Unknown Mac"
        
        var totalSpace: Int64 = 0
        var availableSpace: Int64 = 0
        var purgeableSpace: Int64 = 0
        
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? homeURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityForOpportunisticUsageKey]) {
            totalSpace = Int64(values.volumeTotalCapacity ?? 0)
            availableSpace = values.volumeAvailableCapacityForImportantUsage ?? 0
            
            // A rough estimation of purgeable space
            let opportunistic = values.volumeAvailableCapacityForOpportunisticUsage ?? 0
            if opportunistic > availableSpace {
                purgeableSpace = opportunistic - availableSpace
            }
        }
        
        let usedSpace = totalSpace - availableSpace
        
        return SystemInfo(
            osVersion: osVersion,
            macModel: macModel,
            cpuBrand: cpuBrand,
            physicalMemory: physicalMemory,
            totalDiskSpace: totalSpace,
            usedDiskSpace: usedSpace,
            availableDiskSpace: availableSpace,
            purgeableDiskSpace: purgeableSpace
        )
    }
    
    private static func getSysctlString(key: String) -> String? {
        var size: Int = 0
        sysctlbyname(key, nil, &size, nil, 0)
        
        guard size > 0 else { return nil }
        
        var machine = [CChar](repeating: 0, count: size)
        let result = sysctlbyname(key, &machine, &size, nil, 0)
        
        if result == 0 {
            // Trim null terminators if present
            let nullIndex = machine.firstIndex(of: 0) ?? machine.count
            let trimmed = Array(machine[0..<nullIndex])
            return String(decoding: trimmed.map { UInt8($0) }, as: UTF8.self)
        }
        return nil
    }
}

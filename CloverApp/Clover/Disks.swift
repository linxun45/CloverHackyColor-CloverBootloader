//
//  Disks.swift
//  Clover
//
//  Created by vector sigma on 19/10/2019.
//  Copyright © 2019 CloverHackyColor. All rights reserved.
//

import Cocoa
import IOKit
import IOKit.serial
import IOKit.kext
import CoreFoundation
import DiskArbitration
import SystemConfiguration

let kNotAvailable : String = "N/A"

/// Get DADisk dictionary from DiskArbitration from the given disk name or mount point.
func getDAdiskDescription(from diskOrMtp: String) -> NSDictionary? {
  var dict : NSDictionary? = nil
  if let session = DASessionCreate(kCFAllocatorDefault) {
    if diskOrMtp.hasPrefix("/") &&
      !diskOrMtp.hasPrefix("/dev/disk") &&
      FileManager.default.fileExists(atPath: diskOrMtp) {
      let volume : CFURL =  URL(fileURLWithPath: diskOrMtp) as CFURL
      if let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, volume) {
        dict = DADiskCopyDescription(disk)
      }
    } else if diskOrMtp.hasPrefix("/dev/disk") ||
      diskOrMtp.hasPrefix("disk") {
      var ndisk = diskOrMtp
      if ndisk.hasPrefix("/dev/disk") {
        ndisk = (ndisk as NSString).replacingOccurrences(of: "/dev/", with: "")
      }
      if let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, ndisk) {
        dict = DADiskCopyDescription(disk)
      }
    }
  }
  return dict
}

/// Check disk or mount point is writable (kDADiskDescriptionMediaWritableKey).
func isWritable(diskOrMtp: String) -> Bool {
  var isWritable : Bool = false
  if let dict : NSDictionary = getDAdiskDescription(from: diskOrMtp) {
    if let val = dict.object(forKey: kDADiskDescriptionMediaWritableKey) as? NSNumber {
      isWritable = val.boolValue
    }
  }
  
  return isWritable
}

/// Get the media content name (kDADiskDescriptionMediaContentKey).
func getMediaContent(from diskOrMtp: String) -> String? {
  var content : String? = nil
  if let dict : NSDictionary = getDAdiskDescription(from: diskOrMtp) {
    if (dict.object(forKey: kDADiskDescriptionMediaContentKey) != nil) {
      content = dict.object(forKey: kDADiskDescriptionMediaContentKey) as? String
    }
  }
  
  return content
}

/// get the Partition Scheme Map from the parent disk (kDADiskDescriptionMediaContentKey).
func getPartitionSchemeMap(from diskOrMtp: String) -> String? {
  var sheme : String? = nil
  if let dadisk = getBSDParent(of: diskOrMtp) {
    if let dict : NSDictionary = getDAdiskDescription(from: dadisk) {
      if (dict.object(forKey: kDADiskDescriptionMediaContentKey) != nil) {
        sheme = dict.object(forKey: kDADiskDescriptionMediaContentKey) as? String
      }
    }
  }
  return sheme
}

/// Find the mountpoint for the given disk object. You can pass also a mount point to se if it is valid.
func getMountPoint(from diskOrMtp: String) -> String? {
  // kDADiskDescriptionVolumePathKey
  var mountPoint : String? = nil
  if let dict : NSDictionary = getDAdiskDescription(from: diskOrMtp) {
    if (dict.object(forKey: kDADiskDescriptionVolumePathKey) != nil) {
      let temp : AnyObject = dict.object(forKey: kDADiskDescriptionVolumePathKey) as AnyObject
      if temp is NSURL {
        mountPoint = (dict.object(forKey: kDADiskDescriptionVolumePathKey) as? URL)?.path
      } else if temp is NSString {
        mountPoint = dict.object(forKey: kDADiskDescriptionVolumePathKey) as? String
      }
    }
  }
  
  return mountPoint
}

/// Find the Volume name: be aware that this is not the mount point name.
func getVolumeName(from diskOrMtp: String) -> String? {
  // kDADiskDescriptionVolumeNameKey
  var name : String? = nil
  if let dict : NSDictionary = getDAdiskDescription(from: diskOrMtp) {
    if (dict.object(forKey: kDADiskDescriptionVolumeNameKey) != nil) {
      name = dict.object(forKey: kDADiskDescriptionVolumeNameKey) as? String
    }
  }
  return name
}

/// Get partition UUID for the given volume:  This is not a disk UUID.
func getVolumeUUID(from diskOrMtp: String) -> String? {
  // kDADiskDescriptionVolumeUUIDKey
  var uuid : String? = nil
  if let dict : NSDictionary = getDAdiskDescription(from: diskOrMtp) {
    if (dict.object(forKey: kDADiskDescriptionVolumeUUIDKey) != nil) {
      
      let cfuuid :CFUUID = dict.object(forKey: kDADiskDescriptionVolumeUUIDKey) as! CFUUID
      uuid = CFUUIDCreateString(kCFAllocatorDefault, cfuuid)! as String
      //print(uuid!)
    }
  }
  return uuid
}

/// Get disk uuid for the given diskx. This is not a Volume UUID but a media UUID.
func getDiskUUID(from diskOrMtp: String) -> String? {
  // kDADiskDescriptionVolumeUUIDKey
  var uuid : String? = nil
  if let dict : NSDictionary = getDAdiskDescription(from: getBSDParent(of: diskOrMtp)!) {
    if (dict.object(forKey: kDADiskDescriptionMediaUUIDKey) != nil) {
      let temp : AnyObject = dict.object(forKey: kDADiskDescriptionMediaUUIDKey) as AnyObject
      if temp is NSUUID {
        uuid = (dict.object(forKey: kDADiskDescriptionMediaUUIDKey) as? UUID)?.uuidString
      } else if temp is NSString {
        uuid = dict.object(forKey: kDADiskDescriptionMediaUUIDKey) as? String
      }
    }
  }
  return uuid
}

/// Get Media Name (kDADiskDescriptionMediaNameKey).
func getMediaName(from diskOrMtp: String) -> String? {
  var name : String? = nil
  if let dict : NSDictionary = getDAdiskDescription(from: diskOrMtp) {
    if (dict.object(forKey: kDADiskDescriptionMediaNameKey) != nil) {
      name = (dict.object(forKey: kDADiskDescriptionMediaNameKey) as? String)!
    }
  }
  
  return name
}
/// Get Media Name (kDADiskDescriptionDeviceProtocolKey).
func getDeviceProtocol(from diskOrMtp: String) -> String {
  var prot : String = kNotAvailable
  if let dict : NSDictionary = getDAdiskDescription(from: diskOrMtp) {
    if (dict.object(forKey: kDADiskDescriptionDeviceProtocolKey) != nil) {
      prot = (dict.object(forKey: kDADiskDescriptionDeviceProtocolKey) as? String)!
    }
  }
  
  return prot
}

/// Get all BSDName in the System.
func getAlldisks() -> NSDictionary {
  let match_dictionary: CFMutableDictionary = IOServiceMatching("IOMedia")
  var entry_iterator: io_iterator_t = 0
  let allDisks = NSMutableDictionary()
  if IOServiceGetMatchingServices(kIOMasterPortDefault, match_dictionary, &entry_iterator) == kIOReturnSuccess {
    //let serviceObject: io_registry_entry_t
    //var serviceObject : UnsafeMutablePointer<io_registry_entry_t>
    var serviceObject : io_registry_entry_t = 0
    
    repeat {
      serviceObject = IOIteratorNext(entry_iterator)
      if serviceObject != 0 {
        var serviceDictionary : Unmanaged<CFMutableDictionary>?
        if (IORegistryEntryCreateCFProperties(serviceObject,
                                              &serviceDictionary,
                                              kCFAllocatorDefault,
                                              0) != kIOReturnSuccess) {
          IOObjectRelease(serviceObject)
          continue
        }
        
        let d : NSDictionary = (serviceDictionary?.takeRetainedValue())!
        
        if (d.object(forKey: kIOBSDNameKey) != nil) {
          allDisks.setValue(d, forKey: (d.object(forKey: kIOBSDNameKey) as! String))
        }
      }
    } while serviceObject != 0
    IOObjectRelease(entry_iterator)
  }
  
  return allDisks
}

/// Get FileSystem for the given disk or mount point.
func getFS(from diskOrMtp: String) -> String? {
  var fs : String? = nil
  if let dict : NSDictionary = getDAdiskDescription(from: diskOrMtp) {
    var temp : String = ""
    if (dict.object(forKey: kDADiskDescriptionVolumeKindKey) != nil) {
      temp = dict.object(forKey: kDADiskDescriptionVolumeKindKey) as! String
      
      // if msdos we would know if is fat32, exfat etc..
      if temp.lowercased() == "msdos" {
        // Since last few OSes (..on 10.13) the DAVolumeType
        // contains a string like ""MS-DOS (FAT32)" so that we can identify the real fs
        // w/o using statfs.
        if (dict.object(forKey: kDADiskDescriptionVolumeTypeKey) != nil) {
          let volType : String = dict.object(forKey: kDADiskDescriptionVolumeTypeKey) as! String
          
          if (volType.lowercased().range(of: "exfat") != nil) {
            temp = "exFAT"
          } else if (volType.lowercased().range(of: "fat16") != nil) {
            temp = "FAT16"
          } else if (volType.lowercased().range(of: "fat32") != nil) {
            temp = "FAT32"
          }
        }
      }
      
      fs = temp
    }
  }
  return fs
}

/// Get all ESP (EFI System Partition) in the System.
func getAllESPs() -> [String] {
  var  allEsps : [String] = [String]()
  for  disk in getAlldisks().allKeys {
    let mediaContent = getMediaContent(from: disk as! String) ?? ""
    if getMediaName(from: disk as! String) == "EFI System Partition" &&
      mediaContent == "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"{
      if !allEsps.contains(disk as! String) {
        allEsps.append(disk as! String)
      }
    }
  }
  return allEsps
}

/// Get a list of ESP that have a mount point.
func getListOfMountedEsp() -> [String] {
  var  mounted : [String] = [String]()
  for bsdName in getAllESPs() {
    if isMountPoint(path: bsdName) {
      mounted.append(bsdName)
    }
  }

  return mounted
}

/// get and array of currently mounted volumes
func getVolumes() -> [String] {
  var  mounted : [String] = [String]()
  let all = getAlldisks().allKeys
  for b in all {
    let bsd : String = b as! String
    if let mp = getMountPoint(from: bsd) {
      mounted.append(mp)
    }
  }
  return mounted
}

/// Find the BSDName of the given mount point.
func getBSDName(of mountpoint: String) -> String? {
  if let dict : NSDictionary = getDAdiskDescription(from: mountpoint) {
    if (dict.object(forKey: kDADiskDescriptionMediaBSDNameKey) != nil) {
      return dict.object(forKey: kDADiskDescriptionMediaBSDNameKey) as? String
    }
  }
  return nil
}

/// Find the BSDName of the given parent disk.
func getBSDParent(of mountpointORDevDisk: String) -> String? {
  // DAMediaBSDUnit
  if let dict : NSDictionary = getDAdiskDescription(from: mountpointORDevDisk) {
    if (dict.object(forKey: kDADiskDescriptionMediaBSDUnitKey) != nil) {
      return "disk" + ((dict.object(forKey: kDADiskDescriptionMediaBSDUnitKey) as? NSNumber)?.stringValue)!
    }
  }
  return nil
}

/// Return the partition slice number (as string) for the given disk or mount point.
func getPartitionSlice(of mountpointORDevDisk: String) -> String? {
  if let dict : NSDictionary = getDAdiskDescription(from: mountpointORDevDisk) {
    if (dict.object(forKey: kDADiskDescriptionMediaBSDNameKey) != nil) {
      let disk = (dict.object(forKey: kDADiskDescriptionMediaBSDNameKey) as? String)!
      if (disk.range(of: "s") != nil) {
        let arr : [String] = disk.components(separatedBy: "s")
        if arr.count == 3 { /* dis k0s 1 */
          return arr.last
        }
      }
    }
  }
  return nil
}

/// Return the image (NSImage) for the given mount point or disk object.
func getIconFor(volume mountpointORDevDisk: String) -> NSImage? {
  var image : NSImage? = nil
  // get a customized icon.. if any
  if isMountPoint(path: mountpointORDevDisk) {
    let mtp : String = getMountPoint(from: mountpointORDevDisk)!
    if FileManager.default.fileExists(atPath: mtp + "/.VolumeIcon.icns") {
      image = NSImage(byReferencingFile: mtp + "/.VolumeIcon.icns")
      return image
    }
  }
  // .. otherwise get a System icon
  if let daDict : NSDictionary = getDAdiskDescription(from: mountpointORDevDisk) {
    if let iconDict = daDict.object(forKey: kDADiskDescriptionMediaIconKey) as? NSDictionary,
      let iconName = iconDict.object(forKey: kIOBundleResourceFileKey ) as? String {
      let identifier =  iconDict.object(forKey: kCFBundleIdentifierKey as String) as! CFString
      
      let url : CFURL = Unmanaged.takeRetainedValue(KextManagerCreateURLForBundleIdentifier(kCFAllocatorDefault, identifier))()
      //print(url)
      if let kb = Bundle(url: url as URL) {
        image = NSImage(byReferencingFile:
          kb.path(forResource: iconName.deletingFileExtension, ofType: iconName.fileExtension) ?? "")
      }
    }
  }
  return image
}

/// Boolean value indicanting if the given mount point or disk is internal.
func isInternalDevice(diskOrMtp: String) -> Bool {
  if let dict : NSDictionary = getDAdiskDescription(from: diskOrMtp) {
    if (dict.object(forKey: kDADiskDescriptionDeviceInternalKey) != nil) {
      return ((dict.object(forKey: kDADiskDescriptionDeviceInternalKey) as? NSNumber)?.boolValue)!
    }
  }
  return false
}

/// Boolean value indicanting if the given path is a valid mount point for a disk object.
func isMountPoint(path: String) -> Bool {
  let mtp : String? = getMountPoint(from: path)
  return (mtp != nil)
}

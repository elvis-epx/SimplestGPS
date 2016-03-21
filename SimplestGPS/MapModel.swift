//
//  MapModel.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 8/6/15.
//  Copyright (c) 2015 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

// could not be struct because we want this to passed around by reference
public class MapDescriptor {
    static let NOTLOADED = 0
    static let LOADING_1ST_TIME = 1
    static let LOADING_RESERVED_RAM = 2
    static let CANTLOAD = 3
    static let LOADED = 4
    static let NOTLOADED_OOM = 5
    
    let file: NSURL
    var img: UIImage
    let name: String
    let priority: Double
    let lat0: Double
    let lat1: Double
    let long0: Double
    let long1: Double
    let latheight: Double
    let longwidth: Double
    let midlat: Double
    let midlong: Double
    var boundsx: CGFloat = 0 // manipulated by Controller
    var boundsy: CGFloat = 0 // manipulated by Controller
    var centerx: CGFloat = 0 // manipulated by Controller
    var centery: CGFloat = 0 // manipulated by Controller
    var max_ram_size = 0
    var cur_ram_size = 0
    var imgstatus = MapDescriptor.NOTLOADED
    var shrunk = false
    var insertion = 0
    var distance = 0.0
    
    init(img: UIImage, file: NSURL, name: String, priority: Double, latNW: Double, longNW: Double, latheight: Double, longwidth: Double)
    {
        self.img = img
        self.imgstatus = MapDescriptor.NOTLOADED
        self.file = file
        self.name = name
        self.priority = priority
        self.lat0 = latNW
        self.long0 = longNW
        self.latheight = latheight
        self.longwidth = longwidth
        
        self.lat1 = latNW - latheight
        self.long1 = longNW + longwidth
        self.midlat = lat0 - latheight / 2
        self.midlong = long0 + longwidth / 2
    }
}

@objc class MapModel: NSObject {
    var ram_inuse = 0
    var max_ram_inuse = 0
    static let INITIAL_RAM_LIMIT = 250000000
    var ram_limit = INITIAL_RAM_LIMIT
    
    var task_timer: NSTimer? = nil
    var loader_queue: (MapDescriptor, Bool)? = nil
    var loader_busy: Bool = false
    var shrink_queue: (MapDescriptor, CGSize)? = nil
    var shrink_busy: Bool = false

    var maps: [MapDescriptor] = [];
    var current_map_list: [String:MapDescriptor] = [:]
    var i_notloaded: UIImage
    var i_loading: UIImage
    var i_loading_res: UIImage
    var i_cantload: UIImage
    var i_oom: UIImage
    
    var memoryWarningObserver : NSObjectProtocol!
    
    class func parse_map_name(f: String) -> (ok: Bool, lat: Double, long: Double,
        latheight: Double, longwidth: Double, dx: Double, dy: Double)
    {
        NSLog("Parsing %@", f)
        var lat = 1.0
        var long = 1.0
        var latheight = 0.0
        var longwidth = 0.0
        var dx: Double? = 0.0
        var dy: Double? = 0.0
        
        let e = f.lowercaseString
        let g = (e.characters.split(".").map{ String($0) }).first!
        var h = (g.characters.split("+").map{ String($0) })
        
        if h.count != 4 && h.count != 6 {
            NSLog("    did not find 4/6 tokens")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        if h[0].characters.count < 4 || h[0].characters.count > 6 {
            NSLog("    latitude with <3 or >5 chars")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        
        if h[1].characters.count < 4 || h[1].characters.count > 6 {
            NSLog("    latitude with <3 or >5 chars")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        if h[2].characters.count < 2 || h[2].characters.count > 4 {
            NSLog("    latheight with <3 or >4 chars")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        if h[3].characters.count < 2 || h[3].characters.count > 4 {
            NSLog("    longwidth with <3 or >4 chars")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        
        let ns = h[0].characters.last
        
        if (ns != "n" && ns != "s") {
            NSLog("    latitude with no N or S suffix")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        if (ns == "s") {
            lat = -1;
        }
        
        let ew = h[1].characters.last
        
        if (ew != "e" && ew != "w") {
            NSLog("    longitude with no W or E suffix")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        if (ew == "w") {
            long = -1;
        }
        h[0] = h[0].substringToIndex(h[0].endIndex.predecessor())
        h[1] = h[1].substringToIndex(h[1].endIndex.predecessor())
        let ilat = Int(h[0])
        if (ilat == nil) {
            NSLog("    lat not parsable")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        let ilong = Int(h[1])
        if (ilong == nil) {
            NSLog("    long not parsable")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        let ilatheight = Int(h[2])
        if (ilatheight == nil) {
            NSLog("    latheight not parsable")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        let ilongwidth = Int(h[3])
        if (ilongwidth == nil) {
            NSLog("    longwidth not parsable")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        
        if h.count == 6 {
            dx = Double(h[4])
            if (dx == nil) {
                NSLog("    dx not parsable")
                return (false, 0, 0, 0, 0, 0, 0)
            }
            dy = Double(h[5])
            if (dy == nil) {
                NSLog("    dy not parsable")
                return (false, 0, 0, 0, 0, 0, 0)
            }
        }
        
        lat *= Double(ilat! / 100) + (Double(ilat! % 100) / 60.0)
        long *= Double(ilong! / 100) + (Double(ilong! % 100) / 60.0)
        latheight = Double(ilatheight! / 100) + (Double(ilatheight! % 100) / 60.0)
        longwidth = Double(ilongwidth! / 100) + (Double(ilongwidth! % 100) / 60.0)
        
        return (true, lat, long, latheight, longwidth, dx!, dy!)
    }
    
    // FIXME downsize image when memory full
    
    func get_maps_force_refresh() {
        current_map_list = [:]
    }
    
    func get_maps(clat: Double, clong: Double, radius: Double, latheight: Double) -> [String:MapDescriptor]?
    {
        // NOTE: we use a radius instead of a box to test if a map belongs to the screen,
        // because in HEADING modes the map rotates, so the map x screen overlap must be
        // valid for every heading
        
        var new_list: [String:MapDescriptor] = [:]
        
        // calculate intersection with screen circle and proximity to screen center
        
        for map in maps {
            let (ins, d) = GPSModel2.map_inside(map.lat0, maplatb: map.lat1, maplonga: map.long0,
                                                maplongb: map.long1, lat_circle: clat,
                                                long_circle: clong, radius: radius)
            map.insertion = ins
            map.distance = d
        }
        
        // Try to free memory before it becomes a problem
        // Naïve strategy: release maps not in use right now
        
        for map in maps {
            if self.ram_within_safe_limits() {
                break
            }
            if map.insertion <= 0 && is_img_loaded(map) {
                NSLog("Unused evicted from memory: %@", map.name)
                img_unload(map)
            }
        }
        
        // sorting helps the culling algorithm
        
        let maps_sorted = maps.sort({
            if $0.priority == $1.priority {
                return $0.distance < $1.distance
            }
            return $0.priority < $1.priority
        })

        if !self.ram_within_safe_limits() {
            // See if we can shrink some image, based on screen resolution
            
            for map in maps_sorted.reverse() {
                if map.insertion > 0 && is_img_loaded(map) && shrink_queue == nil {
                    // example: map is 6000 px height, 15' height = 400 px / minute
                    // if screen zoomed out to 60' height, 60 x 400 = 24000 pixels
                    // but screen has only ~2000 pixels height
                    let hpixels = Double(map.img.size.height) / map.latheight * latheight
                    if hpixels > 2100 {
                        // still in the example, 2000 / 24000 = 1:12 reduction
                        // image becomes 500x500, which is enough to cover 1/4 x 1/4 of
                        // the screen with enough sharpness
                        NSLog("Shrinking image %@", map.name)
                        let factor = CGFloat(1920 / hpixels)
                        shrink_queue = (map, CGSize(width: map.img.size.width * factor,
                            height: map.img.size.height * factor))
                        // FIXME what if user zooms in?
                        // FIXME annotate shrunk images
                        // FIXME reinflate more important images
                    }
                }
            }
        } else {
            // Memory is available, blow up highest-priority images if shrunk
            
            for map in maps_sorted {
                if map.shrunk && map.insertion > 0 && is_img_loaded(map) {
                    let hpixels = Double(map.img.size.height) / map.latheight * latheight
                    if hpixels < 1500 {
                        // lacking in resolution; reload without removing current from screen
                        if self.loader_queue == nil {
                            self.loader_queue = (map, true)
                        }
                        break
                    }
                }
            }
            
        }
    
        if !ram_within_hard_limits(nil) {
            // memory full: all unused maps already removed
            // try to remove lowest-priority after a gap
            var gap = false
            for map in maps_sorted {
                if is_img_unloaded(map) {
                    gap = true
                } else if gap && is_img_loaded(map) {
                    NSLog("Gap image evicted from memory: %@", map.name)
                    img_unload(map)
                }
            }
        }

        if !ram_within_hard_limits(nil) {
            // memory full: all unused maps already removed
            // try to remove lowest-priority
            for map in maps_sorted.reverse() {
                if is_img_loaded(map) {
                    NSLog("Lowest prio image evicted from memory: %@", map.name)
                    img_unload(map)
                    break
                }
            }
        }

        // 'maps' ordered by priority (last map = more priority)
        // satrt by higher priority maps (if one encloses the screen circle, call it a day.)
        
        for map in maps_sorted {
            if map.insertion > 0 {
                // NSLog("Image %@ distance %f", map.name, map.distance)
                if is_img_unloaded(map) {
                    if !ram_within_hard_limits(map) {
                        NSLog("Image %@ not loaded due to memory pressure", map.name)
                        if !is_img_unloaded_oom(map) {
                            img_unload_oom(map)
                        }
                    } else {
                        if self.loader_queue == nil {
                            img_loading(map)
                            self.loader_queue = (map, false)
                        }
                    }
                }
                new_list[map.name] = map
                if map.insertion > 1 && is_img_loaded(map) {
                    // culling: map fills the screen completely
                    break
                }
            }
        }

        /*
        var memory_tally = 0
        for map in maps {
            if is_img_loaded(map) {
                memory_tally += map.ram_size
            }
        }
        NSLog("memory accounting: %d %d", ram_inuse, memory_tally)
         */

        var changed = false
        
        if current_map_list.count != new_list.count {
            changed = true
        } else {
            for (name, _) in new_list {
                if current_map_list[name] == nil {
                    // replacement
                    changed = true
                    break
                }
            }
        }

        if changed {
            current_map_list = new_list
            return new_list
        }
            
        return nil
    }
    
    func task_serve()
    {
        loader_serve_queue()
        shrink_serve_queue()
    }
    
    func loader_serve_queue()
    {
        if self.loader_queue == nil || self.loader_busy {
            return
        }

        let (map, is_reload) = self.loader_queue!
        
        if !is_reload && is_img_loaded(map) {
            NSLog("ERROR -------- img tried to load already loaded %@", map.name)
            self.loader_queue = nil
            return
        }

        self.loader_busy = true

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            if !self.ram_within_hard_limits(map) {
                NSLog("Image %@ not loaded due to memory pressure (thread)", map.name)
                dispatch_async(dispatch_get_main_queue()) {
                    if !is_reload {
                        if self.loader_queue == nil {
                            // request was cancelled: remove map from LOADING state,
                            // otherwise it will be stuck (loading maps are not retried)
                            self.img_cancel_loading(map)
                        } else {
                            self.img_unload_oom(map)
                        }
                    }
                    self.loader_queue = nil
                    self.loader_busy = false
                }
            } else {
                if let img = UIImage(data: NSData(contentsOfURL: map.file)!) {
                    dispatch_async(dispatch_get_main_queue()) {
                        if self.loader_queue == nil {
                            if is_reload {
                                // simply disregard
                            } else {
                                self.img_cancel_loading(map)
                            }
                        } else {
                            map.shrunk = false
                            if is_reload {
                                self.img_reloaded(map, img: img)
                            } else {
                                self.img_loaded(map, img: img)
                            }
                        }
                        self.loader_queue = nil
                        self.loader_busy = false
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        if !is_reload {
                            if self.loader_queue == nil {
                                self.img_cancel_loading(map)
                            } else {
                                self.img_cantload(map)
                            }
                        }
                        self.loader_queue = nil
                        self.loader_busy = false
                    }
                }
            }
        }
    }

    func shrink_serve_queue()
    {
        if self.shrink_queue == nil || self.shrink_busy {
            return
        }
        
        let (map, newsize) = self.shrink_queue!
        
        if !is_img_loaded(map) {
            NSLog("ERROR -------- tried to shrink not loaded %@", map.name)
            self.shrink_queue = nil
            return
        }
        
        self.shrink_busy = true
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            let newimg = MapModel.imgresize(map.img, newsize: newsize)
            dispatch_async(dispatch_get_main_queue()) {
                if self.shrink_queue == nil {
                    // disregard result
                } else if !self.is_img_loaded(map) {
                    // disregard result
                } else {
                    map.shrunk = true
                    self.img_shrunk(map, img: newimg)
                }
                self.shrink_queue = nil
                self.shrink_busy = false
            }
        }
    }

    override init()
    {
        i_notloaded = MapModel.simple_image(UIColor(colorLiteralRed: 0, green: 1.0, blue: 0, alpha: 0.33))
        i_oom = MapModel.simple_image(UIColor(colorLiteralRed: 1.0, green: 0, blue: 0.0, alpha: 0.33))
        i_loading = MapModel.simple_image(UIColor(colorLiteralRed: 0, green: 0.0, blue: 1.0, alpha: 0.33))
        i_loading_res = MapModel.simple_image(UIColor(colorLiteralRed: 0, green: 1.0, blue: 1.0, alpha: 0.33))
        i_cantload = MapModel.simple_image(UIColor(colorLiteralRed: 1.0, green: 0, blue: 1.0, alpha: 0.33))
        super.init()
        
        maps = []
        
        let fileManager = NSFileManager.defaultManager()
        let documentsUrl = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as NSURL
        if let directoryUrls = try? NSFileManager.defaultManager().contentsOfDirectoryAtURL(documentsUrl,
                                                                                            includingPropertiesForKeys: nil,
                                                                                            options:NSDirectoryEnumerationOptions.SkipsSubdirectoryDescendants) {
            NSLog("%@", directoryUrls)
            for url in directoryUrls {
                let f = url.lastPathComponent!
                let coords = MapModel.parse_map_name(f)
                if !coords.ok {
                    continue
                }
                NSLog("   %@ map coords %f %f %f %f dx=%f dy=%f", url.absoluteString, coords.lat, coords.long,
                      coords.latheight, coords.longwidth, coords.dx, coords.dy)
                var lat = coords.lat
                var long = coords.long
                if coords.dx != 0 || coords.dy != 0 {
                    // convert dx and dy from meters to degrees and add move map
                    lat += coords.dy / (1852.0 * 60)
                    long += coords.dx / ((1852.0 * 60) * GPSModel2.longitude_proportion(lat))
                    NSLog("   compensated to %f %f", lat, long)
                }
                
                let map = MapDescriptor(img: i_notloaded,
                                    file: url,
                                    name: url.lastPathComponent!,
                                    priority: coords.latheight,
                                    latNW: coords.lat,
                                    longNW: coords.long,
                                    latheight: coords.latheight,
                                    longwidth: coords.longwidth)
                maps.append(map)
            }
        }
        
        let notifications = NSNotificationCenter.defaultCenter()
        memoryWarningObserver = notifications.addObserverForName(UIApplicationDidReceiveMemoryWarningNotification,
                                object: nil,
                                queue: NSOperationQueue.mainQueue(),
                                usingBlock: { [unowned self] (notification : NSNotification!) -> Void in
                                        self.memory_low()
                                }
        )
        
        task_timer = NSTimer(timeInterval: 0.16, target: self,
                         selector: #selector(MapModel.task_serve),
                         userInfo: nil, repeats: true)
        NSRunLoop.currentRunLoop().addTimer(task_timer!, forMode: NSRunLoopCommonModes)
    }
    
    deinit {
        let notifications = NSNotificationCenter.defaultCenter()
        notifications.removeObserver(memoryWarningObserver, name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
        task_timer!.invalidate()
    }
    
    func memory_low() {
        NSLog("################################################# Memory low")
        for i in 0..<maps.count {
            if is_img_loaded(maps[i]) {
                img_unload_oom(maps[i])
            }
        }
        // reset limits after purge so the current usage is low
        // and won't interfere with max_ram_inuse calculation
        
        self.ram_limit = self.max_ram_inuse / 10 * 8
        self.max_ram_inuse = self.ram_limit
    }

    func commit_ram(n: Int) {
        self.ram_inuse += n
        self.max_ram_inuse = max(self.ram_inuse, self.max_ram_inuse)
        NSLog("Memory in use: +%d %d of %d", n, self.ram_inuse, self.ram_limit)
    }

    func release_ram(n: Int) {
        self.ram_inuse -= n
        NSLog("Memory in use: -%d %d of %d", n, self.ram_inuse, self.ram_limit)
    }
    
    func is_img_unloaded(map: MapDescriptor) -> Bool {
        return map.imgstatus == MapDescriptor.NOTLOADED || map.imgstatus == MapDescriptor.NOTLOADED_OOM
    }

    func is_img_unloaded_oom(map: MapDescriptor) -> Bool {
        return map.imgstatus == MapDescriptor.NOTLOADED_OOM
    }
    
    func is_img_loaded(map: MapDescriptor) -> Bool {
        return map.imgstatus == MapDescriptor.LOADED
    }

    // tells if image size has already been tallied up in RAM control
    func has_img_reserved_ram(map: MapDescriptor) -> Bool {
        return map.imgstatus == MapDescriptor.LOADED || map.imgstatus == MapDescriptor.LOADING_RESERVED_RAM
    }

    func img_loading(map: MapDescriptor) {
        if map.imgstatus == MapDescriptor.LOADED || map.imgstatus == MapDescriptor.LOADING_RESERVED_RAM {
            NSLog("Warning: img_loading called for loaded or loading image %@", map.name)
            release_ram(map.cur_ram_size)
        }
        if map.max_ram_size > 0 {
            // size is known
            // always considers the full-res version
            map.cur_ram_size = map.max_ram_size
            commit_ram(map.cur_ram_size)
            map.imgstatus = MapDescriptor.LOADING_RESERVED_RAM
            NSLog("%@ -> LOADING_RESERVED_RAM", map.name)
        } else {
            map.imgstatus = MapDescriptor.LOADING_1ST_TIME
            NSLog("%@ -> LOADING_1ST_TIME", map.name)
        }
        map.img = i_loading
    }
    
    func img_cancel_loading(map: MapDescriptor)
    {
        if map.imgstatus == MapDescriptor.LOADING_RESERVED_RAM {
            release_ram(map.cur_ram_size)
            map.imgstatus = MapDescriptor.NOTLOADED
            NSLog("%@ LOADING_RESERVED_RAM -> NOTLOADED", map.name)
            
        } else if map.imgstatus == MapDescriptor.LOADING_1ST_TIME {
            map.imgstatus = MapDescriptor.NOTLOADED
            NSLog("%@ LOADING_1ST_TIME -> NOTLOADED", map.name)

        } else {
            NSLog("Warning: img_cancel_loading called for not-loading image %@", map.name)
        }
        map.img = i_notloaded
    }

    func img_loaded(map: MapDescriptor, img: UIImage) {
        if map.imgstatus == MapDescriptor.LOADED {
            NSLog("Warning: img_loaded called for already loaded img %@", map.name)
            release_ram(map.cur_ram_size)
        }
        
        // calculate aprox. size
        // NOTE: this assumes that img_loaded() is always called with full-res img
        map.max_ram_size = Int(img.size.width * img.size.height * 4)
        map.cur_ram_size = map.max_ram_size
        
        if map.imgstatus != MapDescriptor.LOADING_RESERVED_RAM {
            NSLog("%@ -> committing memory", map.name)
            commit_ram(map.cur_ram_size)
        }
        map.imgstatus = MapDescriptor.LOADED
        map.img = img
        NSLog("%@ -> LOADED", map.name)
    }

    func img_shrunk(map: MapDescriptor, img: UIImage) {
        if map.imgstatus != MapDescriptor.LOADED {
            NSLog("Warning: img_shrunk called for not loaded img %@", map.name)
            return
        }
        let new_size = Int(img.size.width * img.size.height * 4)
        NSLog("shrunk %d bytes for img %@", map.cur_ram_size - new_size, map.name)
        release_ram(map.cur_ram_size)
        map.cur_ram_size = new_size
        commit_ram(map.cur_ram_size)
        map.img = img
    }

    func img_reloaded(map: MapDescriptor, img: UIImage) {
        if map.imgstatus != MapDescriptor.LOADED {
            NSLog("Warning: img_reloaded called for non-loaded img %@", map.name)
            return
        }
        
        let new_size = Int(img.size.width * img.size.height * 4)
        NSLog("blown up %d bytes for img %@", new_size - map.cur_ram_size, map.name)
        release_ram(map.cur_ram_size)
        map.cur_ram_size = new_size
        commit_ram(map.cur_ram_size)
        map.img = img
    }
    
    func img_unload(map: MapDescriptor) {
        if map.imgstatus == MapDescriptor.LOADED || map.imgstatus == MapDescriptor.LOADING_RESERVED_RAM {
            NSLog("%@ -> releasing memory on unload", map.name)
            release_ram(map.cur_ram_size)
        }
        map.imgstatus = MapDescriptor.NOTLOADED
        map.img = i_notloaded
        NSLog("%@ -> NOTLOADED", map.name)
    }

    func img_unload_oom(map: MapDescriptor) {
        if map.imgstatus == MapDescriptor.LOADED || map.imgstatus == MapDescriptor.LOADING_RESERVED_RAM {
            NSLog("%@ -> releasing memory on unload oom", map.name)
            release_ram(map.cur_ram_size)
        }
        map.imgstatus = MapDescriptor.NOTLOADED_OOM
        map.img = i_oom
        NSLog("%@ -> NOTLOADED_OOM", map.name)
    }

    func img_cantload(map: MapDescriptor) {
        if map.imgstatus == MapDescriptor.LOADED || map.imgstatus == MapDescriptor.LOADING_RESERVED_RAM {
            NSLog("%@ -> releasing memory on cantload", map.name)
            release_ram(map.cur_ram_size)
        }
        map.imgstatus = MapDescriptor.CANTLOAD
        map.img = i_cantload
        NSLog("%@ -> CANTLOAD", map.name)
    }
    
    func ram_within_safe_limits() -> Bool {
        return (self.ram_limit / 10 * 6) > self.ram_inuse
    }

    func ram_within_hard_limits(newobj: MapDescriptor?) -> Bool {
        var additional = 0
        if newobj != nil {
            if !has_img_reserved_ram(newobj!) {
                // make sure we don't count the future img impact when it was
                // already reserved by img_loading()
                additional = newobj!.max_ram_size
            }
        }
        return self.ram_limit > (self.ram_inuse + additional)
    }

    static let singleton = MapModel();
    
    class func model() -> MapModel
    {
        return singleton
    }
    
    class func simple_image(color: UIColor) -> UIImage
    {
        let rect = CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, color.CGColor)
        CGContextFillRect(context, rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    class func imgresize(img: UIImage, newsize: CGSize) -> UIImage
    {
        UIGraphicsBeginImageContextWithOptions(newsize, true, 1.0)
        img.drawInRect(CGRect(x: 0, y: 0,
            width: newsize.width, height: newsize.height))
        let newimg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext()
        return newimg
    }
 }

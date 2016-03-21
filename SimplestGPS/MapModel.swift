//
//  MapModel.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 8/6/15.
//  Copyright (c) 2015 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

typealias ClosureType = (AnyObject?) -> ()

enum State: Int {
    case NEVER_LOADED = 0
    case NEVER_LOADED_OOM
    case LOADING_1ST
    case LOADED
    case SHRUNK
    case CANTLOAD
    case NOT_LOADED
    case NOT_LOADED_OOM
    case LOADING_2ND
    case SHRINKING
}

// could not be struct because we want this to passed around by reference
public class MapDescriptor {
    let statename = ["NEVER_LOADED", "NEVER_LOADED_OOM", "LOADING_1ST", "LOADED",
                     "SHRUNK", "CANTLOAD", "NOT_LOADED", "NOT_LOADED_OOM", "LOADING_2ND",
                     "SHRINKING"]
    
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
    var max_density: Double
    var cur_density: Double
    var boundsx: CGFloat = 0 // manipulated by Controller
    var boundsy: CGFloat = 0 // manipulated by Controller
    var centerx: CGFloat = 0 // manipulated by Controller
    var centery: CGFloat = 0 // manipulated by Controller
    var max_ram = 0
    var cur_ram = 0
    var state = State.NEVER_LOADED
    var insertion = 0
    var distance = 0.0
    var sm: [State:[State:ClosureType]] = [:]
    let model: MapModel
    
    init(model: MapModel, file: NSURL, name: String, priority: Double, latNW: Double,
         longNW: Double, latheight: Double, longwidth: Double)
    {
        self.model = model
        self.img = model.i_notloaded
        self.state = State.NEVER_LOADED
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
        self.cur_density = 0
        self.max_density = 0
        
        sm[State.NEVER_LOADED] = [:]
        sm[State.NEVER_LOADED_OOM] = [:]
        sm[State.LOADING_1ST] = [:]
        sm[State.LOADED] = [:]
        sm[State.SHRINKING] = [:]
        sm[State.SHRUNK] = [:]
        sm[State.CANTLOAD] = [:]
        sm[State.LOADING_2ND] = [:]
        sm[State.NOT_LOADED] = [:]
        sm[State.NOT_LOADED_OOM] = [:]
        
        // A
        sm[State.NEVER_LOADED]![State.NEVER_LOADED_OOM] = { _ in
            self.img = model.i_oom
        }
        // B
        sm[State.NEVER_LOADED_OOM]![State.NEVER_LOADED_OOM] = {_ in}
        // C
        sm[State.LOADING_1ST]![State.NEVER_LOADED_OOM] = { _ in
            self.img = model.i_oom
        }
        
        // D
        sm[State.NOT_LOADED]![State.NOT_LOADED_OOM] = { _ in
            self.img = model.i_oom
        }
        // E
        sm[State.NOT_LOADED_OOM]![State.NOT_LOADED_OOM] = { _ in }
        // F
        sm[State.LOADING_2ND]![State.NOT_LOADED_OOM] = { _ in
            NSLog("%@ -> releasing 2nd on unload oom", name)
            model.release_ram(self.cur_ram)
            self.img = model.i_oom
        }
        // G
        sm[State.LOADED]![State.NOT_LOADED_OOM] = { _ in
            NSLog("%@ -> releasing loaded on unload oom", name)
            model.release_ram(self.cur_ram)
            self.img = model.i_oom
        }
        // H
        sm[State.SHRUNK]![State.NOT_LOADED_OOM] = { _ in
            NSLog("%@ -> releasing shrunk on unload oom", name)
            model.release_ram(self.cur_ram)
            self.img = model.i_oom
        }
        // Z
        sm[State.SHRINKING]![State.NOT_LOADED_OOM] = { _ in
            NSLog("%@ -> releasing shrinking memory on unload oom", name)
            model.release_ram(self.cur_ram)
            self.img = model.i_oom
        }
        // X
        sm[State.SHRINKING]![State.NOT_LOADED] = { _ in
            NSLog("%@ -> releasing shrinking memory on unload", name)
            model.release_ram(self.cur_ram)
            self.img = model.i_notloaded
        }
        
        // I
        sm[State.NEVER_LOADED]![State.LOADING_1ST] = { screenh in
            if !model.queue_load() {
                NSLog("ERROR ######## could not queue load %@", name)
                self.state = State.NEVER_LOADED
                return
            }
            let l = screenh as! Double
            self.img = model.i_loading
            self.Load(l, cb: { model.dequeue_load() })
        }
        
        // I2
        sm[State.LOADING_1ST]![State.NEVER_LOADED] = { _ in
            self.img = model.i_notloaded
        }
        // J
        sm[State.NEVER_LOADED_OOM]![State.LOADING_1ST] = { screenh in
            if !model.queue_load() {
                NSLog("ERROR ######## could not queue load %@", name)
                self.state = State.NEVER_LOADED_OOM
                return
            }
            self.img = model.i_loading
            let l = screenh as! Double
            self.Load(l, cb: { model.dequeue_load() })
        }
        
        // no K
        
        // L
        sm[State.LOADING_1ST]![State.CANTLOAD] = { _ in
            self.img = model.i_cantload
        }
        // M
        sm[State.LOADING_2ND]![State.CANTLOAD] = { _ in
            model.release_ram(self.cur_ram)
            self.img = model.i_cantload
        }
        
        // N
        sm[State.NOT_LOADED]![State.LOADING_2ND] = { screenh in
            if !model.queue_load() {
                NSLog("ERROR ######## could not queue load %@", name)
                self.state = State.NOT_LOADED
                return
            }
            self.cur_ram = self.max_ram
            model.commit_ram(self.cur_ram)
            self.img = model.i_loading_res
            let l = screenh as! Double
            self.Load(l, cb: { model.dequeue_load() })
        }
        // N2
        sm[State.LOADING_2ND]![State.NOT_LOADED] = { _ in
            model.release_ram(self.cur_ram)
            self.img = model.i_notloaded
        }
        // H2
        sm[State.SHRUNK]![State.NOT_LOADED] = { _ in
            NSLog("%@ -> releasing shrunk memory on unload", name)
            model.release_ram(self.cur_ram)
            self.img = model.i_notloaded
        }
        // O
        sm[State.NOT_LOADED_OOM]![State.LOADING_2ND] = { screenh in
            if !model.queue_load() {
                NSLog("ERROR ######## could not queue load %@", name)
                self.state = State.NOT_LOADED_OOM
                return
            }
            self.cur_ram = self.max_ram
            model.commit_ram(self.cur_ram)
            self.img = model.i_loading_res
            let l = screenh as! Double
            self.Load(l, cb: { model.dequeue_load() })
        }
        
        // P
        sm[State.LOADED]![State.NOT_LOADED] = { _ in
            model.release_ram(self.cur_ram)
            self.img = model.i_notloaded
        }
        // CANTLOAD is a final state
        
        // V
        sm[State.LOADED]![State.SHRINKING] = { size in
            if !model.queue_shrink() {
                NSLog("ERROR ######## could not queue shrink %@", name)
                self.state = State.LOADED
                return
            }
            self.shrink((size as! NSValue).CGSizeValue(), cb: { model.dequeue_shrink() } )
        }
        // R
        sm[State.SHRUNK]![State.SHRINKING] = { size in
            if !model.queue_shrink() {
                NSLog("ERROR ######## could not queue shrink %@", name)
                self.state = State.SHRUNK
                return
            }
            self.shrink((size as! NSValue).CGSizeValue(), cb: { model.dequeue_shrink() } )
        }
        // Q
        sm[State.SHRINKING]![State.SHRUNK] = { img in
            let imgc = img as! UIImage
            let new_size = Int(imgc.size.width * imgc.size.height * 4)
            NSLog("shrunk %d bytes for img %@", self.cur_ram - new_size, self.name)
            model.release_ram(self.cur_ram)
            self.cur_ram = new_size
            model.commit_ram(self.cur_ram)
            self.img = imgc
        }
        // SA
        sm[State.LOADING_1ST]![State.SHRUNK] = { img in
            let imgc = img as! UIImage
            let new_size = Int(imgc.size.width * imgc.size.height * 4)
            self.cur_ram = new_size
            model.commit_ram(self.cur_ram)
            self.img = imgc
        }
        // SB
        sm[State.LOADING_2ND]![State.SHRUNK] = { img in
            let imgc = img as! UIImage
            let new_size = Int(imgc.size.width * imgc.size.height * 4)
            model.release_ram(self.cur_ram)
            self.cur_ram = new_size
            model.commit_ram(self.cur_ram)
            self.img = imgc
        }
    
        // S (blow-up)
        sm[State.SHRUNK]![State.LOADING_2ND] = { screenh in
            if !model.queue_load() {
                NSLog("ERROR ######## could not queue blowup %@", name)
                self.state = State.SHRUNK
                return
            }
            let new_size = self.max_ram
            NSLog("blown up %d bytes for img %@", new_size - self.cur_ram, self.name)
            model.release_ram(self.cur_ram)
            self.cur_ram = new_size
            model.commit_ram(self.cur_ram)
            let l = screenh as! Double
            self.Load(l, cb: { model.dequeue_load() })
        }
        
        // T
        sm[State.LOADING_1ST]![State.LOADED] = { img in
            // calculate aprox. size
            // NOTE: this assumes that img_loaded() is always called with full-res img
            let imgc = img as! UIImage
            self.cur_ram = self.max_ram
            model.commit_ram(self.cur_ram)
            self.img = imgc
        }
        // U
        sm[State.LOADING_2ND]![State.LOADED] = { img in
            self.img = img as! UIImage
        }
    }
    
    func trans(newstate: State, arg: AnyObject?) {
        let oldstate = state
        if sm[oldstate]![newstate] == nil {
            NSLog("############# ERROR ########### cannot move state %@ -> %@",
                  statename[oldstate.rawValue], statename[newstate.rawValue])
            return
        }
        NSLog("Map %@ trans %@ -> %@", name, statename[oldstate.rawValue], statename[newstate.rawValue])
        state = newstate
        sm[oldstate]![newstate]!(arg)
    }
    
    /* Convenience methods for clients */
    func please_oom() {
        if state == State.NEVER_LOADED || state == State.LOADING_1ST
                || state == State.NEVER_LOADED_OOM {
            trans(State.NEVER_LOADED_OOM, arg: nil)
        } else if is_loaded() || state == State.LOADING_2ND
                || state == State.NOT_LOADED_OOM || state == State.NOT_LOADED {
            trans(State.NOT_LOADED_OOM, arg: nil)
        } else {
            NSLog("Warning ####### please_oom called for invalid state %@ %@",
                  statename[state.rawValue], name)
        }
    }
    
    func please_load(screenh: Double) -> Bool {
        if model.loader_busy() {
            return false
        }
        
        let nscreenh = NSNumber(double: screenh)
        
        if state == State.NEVER_LOADED || state == State.NEVER_LOADED_OOM {
            trans(State.LOADING_1ST, arg: nscreenh)
            return true
        } else if state == State.NOT_LOADED || state == State.NOT_LOADED_OOM || state == State.SHRUNK {
            trans(State.LOADING_2ND, arg: nscreenh)
            return true
        } else if state == State.LOADING_1ST || state == State.LOADING_2ND {
            // ignore
            return true
        }
        
        NSLog("Warning ####### please_load called for invalid state %@ %@",
              statename[state.rawValue], name)
        return false
    }
    
    func please_shrink(factor: Double) -> Bool {
        
        if model.shrink_busy() {
            return false
        } else if state == State.SHRINKING {
            // ignore
        } else if state != State.SHRUNK && state != State.LOADED {
            NSLog("Warning ####### please_shrink called for invalid state %@ %@",
                  statename[state.rawValue], name)
            return false
        }
        
        let size = CGSize(width: img.size.width * CGFloat(factor),
                          height: img.size.height * CGFloat(factor))
        
        trans(State.SHRINKING, arg: NSValue(CGSize: size))
        return true
    }
    
    func please_unload() {
        if !is_loaded() && state != State.LOADING_2ND {
            NSLog("Warning ####### please_unload called for invalid state %@ %@",
                  statename[state.rawValue], name)
            return
        }
        trans(State.NOT_LOADED, arg: nil)
    }
    
    func please_blowup(screenh: Double) -> Bool {
        if model.loader_busy() {
            return false
        } else if state != State.SHRUNK {
            NSLog("Warning ####### please_blowup called for invalid state %@ %@",
                  statename[state.rawValue], name)
            return false
        }
        trans(State.LOADING_2ND, arg: NSNumber(double: screenh))
        return true
    }
    
    func is_unloaded_but_is_loadable() -> Bool {
        return state == State.NEVER_LOADED || state == State.NOT_LOADED ||
            state == State.NEVER_LOADED_OOM || state == State.NOT_LOADED_OOM
    }
        
    func is_loaded() -> Bool {
        return state == State.LOADED || state == State.SHRINKING || state == State.SHRUNK
    }
    
    func is_shrinking() -> Bool {
        return state == State.SHRINKING
    }
    
    func is_shrunk() -> Bool {
        return state == State.SHRUNK
    }
    
    func has_reserved_ram() -> Bool {
        return is_loaded() || state == State.LOADING_2ND
    }
    
    func ram_estimate() -> Int {
        return self.max_ram
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
    
    func shrink(newsize: CGSize, cb: () -> ())
    {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            NSLog("Shrinking image current density %f", self.cur_density)
            let newimg = MapDescriptor.imgresize(self.img, newsize: newsize)
            dispatch_async(dispatch_get_main_queue()) {
                if self.state != State.SHRINKING {
                    NSLog("Warning ########### %@ shrink disregarded", self.name)
                } else {
                    self.cur_density = Double(newsize.height) / self.latheight
                    NSLog("        final density %f", self.cur_density)
                    self.trans(State.SHRUNK, arg: newimg)
                }
                cb()
            }
        }
    }
    
    func Load(screenh: Double, cb: () -> ())
    {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            let rawimg = UIImage(data: NSData(contentsOfURL: self.file)!)
            
            if rawimg != nil && rawimg!.size.height > 0 && rawimg!.size.width > 0 {
                // update image statistics
                self.max_ram = Int(rawimg!.size.width * rawimg!.size.height * 4)
                self.max_density = Double(rawimg!.size.height) / self.latheight
                
                // determine if image should be shrunk right away
                let hpixels = self.max_density * screenh
                if hpixels > 2250 {
                    // image too big: shrink
                    let factor = CGFloat(1920 / hpixels)
                    let newsize = CGSize(width: rawimg!.size.width * factor,
                                         height: rawimg!.size.height * factor)
                    NSLog("  shrinking-on-load orig density %f screenh %f hpixels %f factor %f",
                          self.max_density, screenh, hpixels, factor)
                    let shrunkimg = MapDescriptor.imgresize(rawimg!, newsize: newsize)
                    self.cur_density = Double(shrunkimg.size.height) / self.latheight
                    NSLog("        final density %f", self.cur_density)
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        if self.state != State.LOADING_1ST && self.state != State.LOADING_2ND {
                            NSLog("Warning ########### %@ load+shrink disregarded", self.name)
                        } else {
                            self.trans(State.SHRUNK, arg: shrunkimg)
                        }
                        cb()
                    }
                } else {
                    // using raw image
                    self.cur_density = self.max_density
                    dispatch_async(dispatch_get_main_queue()) {
                        if self.state != State.LOADING_1ST && self.state != State.LOADING_2ND {
                            NSLog("Warning ########### %@ load disregarded", self.name)
                        } else {
                            self.trans(State.LOADED, arg: rawimg)
                        }
                        cb()
                    }
                }
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    if self.state != State.LOADING_1ST && self.state != State.LOADING_2ND {
                        NSLog("Warning ########### %@ load (cantload) disregarded", self.name)
                    } else {
                        self.trans(State.CANTLOAD, arg: nil)
                    }
                    cb()
                }
            }
        }
    }
}

@objc class MapModel: NSObject {
    var ram_inuse = 0
    var max_ram_inuse = 0
    static let INITIAL_RAM_LIMIT = 250000000
    var ram_limit = INITIAL_RAM_LIMIT
    
    var _loader_busy: Bool = false
    var _shrink_busy: Bool = false
    
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
    
    func get_maps_force_refresh() {
        current_map_list = [:]
    }
    
    func get_maps(clat: Double, clong: Double, radius: Double, screenh: Double) -> [String:MapDescriptor]?
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
            if map.insertion <= 0 && map.is_loaded() {
                NSLog("Unused evicted from memory: %@", map.name)
                map.please_unload()
            }
        }
        
        // sorting helps the culling algorithm
        
        let maps_sorted = maps.sort({
            if $0.priority == $1.priority {
                return $0.distance < $1.distance
            }
            return $0.priority < $1.priority
        })
        
        if !self.ram_within_safe_limits() && self.ram_within_hard_limits(nil) {
            // See if we can shrink some image, based on screen resolution
            
            for map in maps_sorted.reverse() {
                if map.insertion > 0 && map.is_loaded() && !map.is_shrinking() {
                    // example: map is 6000 px height, 15' height = 400 px / minute
                    // if screen zoomed out to 60' height, 60 x 400 = 24000 pixels
                    // but screen has only ~2000 pixels height
                    let hpixels = map.cur_density * screenh
                    if hpixels > 2250 {
                        // still in the example, 2000 / 24000 = 1:12 reduction
                        // image becomes 500x500, which is enough to cover 1/4 x 1/4 of
                        // the screen with enough sharpness
                        NSLog("Shrinking image %@ current density %f screenh %f hpixels %f",
                              map.name, map.cur_density, screenh, hpixels)
                        let factor = 1920.0 / hpixels
                        if !map.please_shrink(factor) {
                            break
                        }
                    }
                }
            }
        }
        
        if self.ram_within_safe_limits() {
            // Memory is available, blow up highest-priority images if shrunk
            
            for map in maps_sorted {
                if map.insertion > 0 && map.is_loaded() && map.is_shrunk() {
                    let hpixels = map.cur_density * screenh
                    if hpixels < 1500 {
                        NSLog("Blowing up image %@ current density %f screenh %f hpixels %f",
                              map.name, map.cur_density, screenh, hpixels)
                        // found wanting in resolution; reload without remove from screen
                        if !map.please_blowup(screenh) {
                            break
                        }
                    }
                }
            }
        }
        
        if !ram_within_hard_limits(nil) {
            // memory full: all unused maps already removed
            // try to remove lowest-priority after a gap
            var gap = false
            for map in maps_sorted {
                if !map.is_loaded() {
                    gap = true
                } else if gap && map.is_loaded() {
                    NSLog("Gap image evicted from memory: %@", map.name)
                    map.please_oom()
                }
            }
        }
        
        if !ram_within_hard_limits(nil) {
            // memory full: all unused maps already removed
            // try to remove lowest-priority
            for map in maps_sorted.reverse() {
                if map.is_loaded() {
                    NSLog("Lowest prio image evicted from memory: %@", map.name)
                    map.please_oom()
                    break
                }
            }
        }
        
        // 'maps' ordered by priority (last map = more priority)
        // satrt by higher priority maps (if one encloses the screen circle, call it a day.)
        
        for map in maps_sorted {
            if map.insertion > 0 {
                // NSLog("Image %@ distance %f", map.name, map.distance)
                if map.is_unloaded_but_is_loadable() {
                    if !ram_within_hard_limits(map) {
                        NSLog("Image %@ not loaded due to memory pressure", map.name)
                        map.please_oom()
                    } else {
                        map.please_load(screenh)
                    }
                }
                new_list[map.name] = map
                if map.insertion > 1 && map.is_loaded() {
                    // culling: map fills the screen completely
                    break
                }
            }
        }
        
        var memory_tally = 0
        var inflight = 0
        for map in maps {
            if map.is_loaded() {
                memory_tally += map.cur_ram
            }
            if map.state == State.LOADING_2ND || map.state == State.LOADING_1ST || map.state == State.SHRINKING {
                inflight += 1
            }
        }
        if ram_inuse != memory_tally || inflight > 0 {
            NSLog("memory accounting: %d %d, in flight %d", ram_inuse, memory_tally, inflight)
        }
        
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
                
                let map = MapDescriptor(model: self,
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
    }
    
    deinit {
        let notifications = NSNotificationCenter.defaultCenter()
        notifications.removeObserver(memoryWarningObserver, name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
    
    func memory_low() {
        NSLog("################################################# Memory low")
        for i in 0..<maps.count {
            if maps[i].is_loaded() {
                maps[i].please_oom()
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
    
    func ram_within_safe_limits() -> Bool {
        return (self.ram_limit / 10 * 5) > self.ram_inuse
    }
    
    func ram_within_hard_limits(newobj: MapDescriptor?) -> Bool {
        var additional = 0
        if newobj != nil {
            if !(newobj!.has_reserved_ram()) {
                // make sure we don't count the future img impact when it was
                // already reserved by img_loading()
                additional = newobj!.ram_estimate()
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
    
    func queue_load() -> Bool {
        if _loader_busy {
            return false
        }
        _loader_busy = true
        return true
    }
    
    func dequeue_load() {
        _loader_busy = false
    }
    
    func loader_busy() -> Bool {
        return _loader_busy
    }
    
    func queue_shrink() -> Bool {
        if _shrink_busy {
            return false
        }
        _shrink_busy = true
        return true
    }
    
    func dequeue_shrink() {
        _shrink_busy = false
    }
    
    func shrink_busy() -> Bool {
        return _shrink_busy
    }
}

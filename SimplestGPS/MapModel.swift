//
//  MapModel.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 8/6/15.
//  Copyright (c) 2015 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

typealias ClosureType = (AnyObject?) -> Bool

enum State: Int {
    case notloaded = 0
    case loading
    case loaded
    case cantload
    case notloaded_OOM
}

// could not be struct because we want this to passed around by reference
open class MapDescriptor {
    let statename = ["NOTLOADED", "LOADING", "LOADED", "CANTLOAD", "NOTLOADED_OOM"]
    
    let file: URL
    var img: UIImage
    let name: String
    let priority: Double
    let olat0: Double
    let olat1: Double
    let olong0: Double
    let olong1: Double
    let olatheight: Double
    let olongwidth: Double
    let omidlat: Double
    let omidlong: Double
    var boundsx: CGFloat = 0 // manipulated by Controller
    var boundsy: CGFloat = 0 // manipulated by Controller
    var vcenterx: CGFloat = 0 // manipulated by Controller
    var vcentery: CGFloat = 0 // manipulated by Controller
    var offsetx: CGFloat = 0 // manipulated by Controller
    var offsety: CGFloat = 0 // manipulated by Controller
    var maxram = 0
    var currentram = 0
    var state = State.notloaded
    var insertion = 0
    var distance = 0.0
    var sm: [State:[State:ClosureType]] = [:]
    let model: MapModel
    
    var oheight: CGFloat = 0
    var owidth: CGFloat = 0
    var curlat0: Double = 0
    var curlat1: Double = 0
    var curlong0: Double = 0
    var curlong1: Double = 0
    var curlatheight: Double = 0
    var curlongwidth: Double = 0
    var curmidlat: Double = 0
    var curmidlong: Double = 0
    
    init(model: MapModel, file: URL, name: String, priority: Double, latNW: Double,
         longNW: Double, latheight: Double, longwidth: Double)
    {
        self.model = model
        self.img = model.i_notloaded
        self.file = file
        self.name = name
        self.priority = priority
        self.olat0 = latNW
        self.olong0 = GPSModel2.handle_cross_180f(longNW)
        self.olatheight = latheight
        self.olongwidth = longwidth
        
        self.olat1 = latNW - latheight
        self.olong1 = GPSModel2.handle_cross_180f(longNW + longwidth)
        self.omidlat = latNW - latheight / 2
        self.omidlong = GPSModel2.handle_cross_180f(longNW + longwidth / 2)
        
        self.reset_cur()
        
        sm[State.notloaded] = [:]
        sm[State.loading] = [:]
        sm[State.loaded] = [:]
        sm[State.cantload] = [:]
        sm[State.notloaded_OOM] = [:]
        
        // Cleanup (A)
        sm[State.notloaded]![State.notloaded_OOM] = { _ in
            model.update_ram(self, n: 0)
            self.img = model.i_oom
            self.reset_cur()
            return true
        }
        
        sm[State.loading]![State.notloaded_OOM] =
            sm[State.notloaded]![State.notloaded_OOM]
        
        sm[State.loaded]![State.notloaded_OOM] =
            sm[State.loading]![State.notloaded_OOM]
        
        sm[State.loading]![State.notloaded] = { _ in
            model.update_ram(self, n: 0)
            self.img = model.i_notloaded
            self.reset_cur()
            return true
        }
        
        sm[State.loaded]![State.notloaded] =
            sm[State.loading]![State.notloaded]
        
        // Fail (F)
        sm[State.loading]![State.cantload] = { _ in
            model.update_ram(self, n: 0)
            self.img = model.i_cantload
            self.reset_cur()
            return true
        }
        
        // Null
        sm[State.notloaded_OOM]![State.notloaded_OOM] = { _ in
            return true
        }
        
        // Loading (L)
        sm[State.notloaded]![State.loading] = { info in
            if !model.queue_load() {
                NSLog("ERROR ######## could not queue load %@", name)
                return false
            }
            model.update_ram(self, n: self.maxram)
            if self.state != State.loaded {
                // make this transition usable in others
                self.img = model.i_loading
                self.reset_cur()
            }
            
            let blat0 = ((info as! NSDictionary)["lat0"] as! NSNumber) as! Double
            let blat1 = ((info as! NSDictionary)["lat1"] as! NSNumber) as! Double
            let blong0 = ((info as! NSDictionary)["long0"] as! NSNumber) as! Double
            let blong1 = ((info as! NSDictionary)["long1"] as! NSNumber) as! Double
            let screenh = ((info as! NSDictionary)["screenh"] as! NSNumber) as! Double
            self.Load(blat0, blat1: blat1, blong0: blong0, blong1: blong1,
                      screenh: CGFloat(screenh), cb: { model.dequeue_load() })
            return true
        }
        
        // blowup / shrink
        sm[State.loaded]![State.loading] =
            sm[State.notloaded]![State.loading]
        
        sm[State.notloaded_OOM]![State.loading] =
            sm[State.notloaded]![State.loading]
        
        // Commit (C)
        sm[State.loading]![State.loaded] = { img in
            model.update_ram(self, n: 0)
            let imgc = img as! UIImage
            let new_size = Int(imgc.size.width * imgc.size.height * 4)
            model.update_ram(self, n: new_size)
            NSLog("    actual img size %d bytes (max %d)", new_size, self.maxram)
            self.img = imgc
            return true
        }
    }
    
    // density in pixels per degree
    func max_density() -> CGFloat {
        return self.oheight / CGFloat(self.olatheight)
    }
    
    func cur_density() -> CGFloat {
        return self.img.size.height / CGFloat(abs(self.curlat1 - self.curlat0))
    }
    
    // calculate map crop that fills a box (typically, the screen)
    func calc_crop(_ boxlat0: Double, boxlat1: Double, boxlong0: Double, boxlong1: Double)
        -> (CGRect, Double, Double, Double, Double)
    {
        // NSLog("calc_crop lat0 %f lat1 %f long0 %f long1 %f", olat0, olat1, olong0, olong1)
        // NSLog("      box blat0 %f blat1 %f blong0 %f blong1 %f", boxlat0, boxlat1, boxlong0, boxlong1)

        let _newlat0 = GPSModel2.clamp_lat(boxlat0, a: olat0, b: olat1)
        let _newlat1 = GPSModel2.clamp_lat(boxlat1, a: olat0, b: olat1)
        // remember that map.*lat0 northern to map.*lat1,
        // but boxlat0/boxlat1 might not follow this convention
        // reorder
        let (newlat0, newlat1) = (max(_newlat0, _newlat1), min(_newlat0, _newlat1))
        
        var newlong0 = GPSModel2.clamp_long(boxlong0, a: olong0, b: olong1)
        var newlong1 = GPSModel2.clamp_long(boxlong1, a: olong0, b: olong1)
        
        if GPSModel2.longitude_minusf(newlong1, minus: newlong0) < 0 {
            // reorder
            (newlong0, newlong1) = (newlong1, newlong0)
        }
        
        let y0 = self.oheight * -CGFloat((newlat0 - self.olat0) / self.olatheight)
        let y1 = self.oheight * -CGFloat((newlat1 - self.olat0) / self.olatheight)
        let x0 = self.owidth *
            CGFloat(GPSModel2.longitude_minusf(newlong0, minus: self.olong0) / self.olongwidth)
        let x1 = self.owidth *
            CGFloat(GPSModel2.longitude_minusf(newlong1, minus: self.olong0) / self.olongwidth)
        
        // NSLog("      width %f height %f", self.owidth, self.oheight)
        // NSLog("      width %f height %f", x1 - x0, y1 - y0)
        // NSLog("      box lat0 %f lat1 %f long0 %f long1 %f", newlat0, newlat1, newlong0, newlong1)
        
        return (CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0),
                newlat0, newlat1, newlong0, newlong1)
    }
    
    // see if current 'box' (typically, the screen) is covered by the map crop currently in memory
    // i.e. if the map contains the box
    func is_crop_enough(_ boxlat0: Double, boxlat1: Double, boxlong0: Double, boxlong1: Double) -> Bool
    {
        let (_, ideallat0, ideallat1, ideallong0, ideallong1) =
                calc_crop(boxlat0, boxlat1: boxlat1, boxlong0: boxlong0, boxlong1: boxlong1)

        let contained =
               (GPSModel2.contains_latitude(ideallat0, b: ideallat1, c: curlat0, d: curlat1) &&
               GPSModel2.contains_longitude(ideallong0, b: ideallong1, c: curlong0, d: curlong1))
        
        if !contained {
            NSLog("Map does not contain box %f-%f %f-%f", boxlat0, boxlat1, boxlong0, boxlong1)
            NSLog("         Current map size %f-%f %f-%f", curlat0, curlat1, curlong0, curlong1)
            NSLog("             max map size %f-%f %f-%f", olat0, olat1, olong0, olong1)
        }
        
        return contained
    }
    
    func trans(_ newstate: State, arg: AnyObject?) {
        let oldstate = state
        if sm[oldstate]![newstate] == nil {
            NSLog("############# ERROR ########### cannot move state %@ -> %@",
                  statename[oldstate.rawValue], statename[newstate.rawValue])
            return
        }
        NSLog("Map %@ trans %@ -> %@", name, statename[oldstate.rawValue], statename[newstate.rawValue])
        if sm[oldstate]![newstate]!(arg) {
            state = newstate
        } else {
            NSLog("     refused to change state!")
        }
    }
    
    /* Convenience methods for clients */
    func please_oom() {
        if state == State.notloaded || state == State.loading ||
            state == State.notloaded_OOM || is_loaded() {
            trans(State.notloaded_OOM, arg: nil)
        } else {
            NSLog("Warning ####### please_oom called for invalid state %@ %@",
                  statename[state.rawValue], name)
        }
    }
    
    func please_load(_ lat0: Double, lat1: Double, long0: Double, long1: Double, screenh: Double) -> Bool {
        if model.loader_busy() {
            return false
        }
        
        if state == State.notloaded || state == State.notloaded_OOM {
            let d: NSDictionary = ["lat0": NSNumber(value: lat0 as Double),
                                   "lat1": NSNumber(value: lat1 as Double),
                                   "long0": NSNumber(value: long0 as Double),
                                   "long1": NSNumber(value: long1 as Double),
                                   "screenh": NSNumber(value: screenh as Double)]
            trans(State.loading, arg: d)
            return true
        } else if state == State.loading {
            // ignore
            return true
        }
        
        NSLog("Warning ####### please_load called for invalid state %@ %@",
              statename[state.rawValue], name)
        return false
    }
    
    func please_unload() {
        if !is_loaded() && state != State.loading {
            NSLog("Warning ####### please_unload called for invalid state %@ %@",
                  statename[state.rawValue], name)
            return
        }
        trans(State.notloaded, arg: nil)
    }
    
    func please_reload(_ lat0: Double, lat1: Double, long0: Double, long1: Double, screenh: Double) -> Bool {
        if model.loader_busy() {
            return false
        } else if state != State.loaded {
            NSLog("Warning ####### please_blowup called for invalid state %@ %@",
                  statename[state.rawValue], name)
            return false
        }
        let d: NSDictionary = ["lat0": NSNumber(value: lat0 as Double),
                               "lat1": NSNumber(value: lat1 as Double),
                               "long0": NSNumber(value: long0 as Double),
                               "long1": NSNumber(value: long1 as Double),
                               "screenh": NSNumber(value: screenh as Double)]
        trans(State.loading, arg: d)
        return true
    }
    
    func is_unloaded_but_is_loadable() -> Bool {
        return state == State.notloaded || state == State.notloaded_OOM
    }
    
    func is_loaded() -> Bool {
        return state == State.loaded
    }
    
    func is_shrunk() -> Bool {
        return self.max_density() > (self.cur_density() + 0.00001)
    }
    
    func ram_estimate() -> Int {
        if self.currentram > 0 {
            // already committed
            return 0
        }
        return self.maxram
    }
    
    func imgresize(_ img: UIImage, crop: CGRect, shrink_factor: CGFloat) -> UIImage
    {
        let newsize = CGSize(width: crop.width / shrink_factor,
                             height: crop.height / shrink_factor)
        
        // transform crop so it falls exactly on newsize
        let paintrect = CGRect(
            x: -crop.origin.x / shrink_factor,
            y: -crop.origin.y / shrink_factor,
            width: img.size.width / shrink_factor,
            height: img.size.height / shrink_factor)
        
        UIGraphicsBeginImageContextWithOptions(newsize, true, 1.0)
        img.draw(in: paintrect)
        let newimg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext()
        return newimg!
    }
    
    func reset_cur() {
        self.curlat0 = olat0
        self.curlat1 = olat1
        self.curlong0 = olong0
        self.curlong1 = olong1
        self.curlatheight = olatheight
        self.curlongwidth = olongwidth
        self.curmidlat = omidlat
        self.curmidlong = omidlong
    }
    
    func Load(_ blat0: Double, blat1: Double, blong0: Double, blong1: Double, screenh: CGFloat, cb: @escaping () -> ())
    {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            let rawimg = UIImage(data: try! Data(contentsOf: self.file))
            
            if rawimg != nil && rawimg!.size.height > 0 && rawimg!.size.width > 0 {
                // update image statistics
                self.maxram = Int(rawimg!.size.width * rawimg!.size.height * 4)
                self.oheight = rawimg!.size.height
                self.owidth = rawimg!.size.width
                
                // determine if image should be shrunk right away
                var factor = CGFloat(1.0)
                let hpixels = self.max_density() * CGFloat(screenh)
                if hpixels > 2250 {
                    // image too big: shrink
                    factor = hpixels / 1920
                }
                NSLog("   current density %f screenh %f height %f excess %f",
                      self.max_density(), screenh, hpixels, factor)
                
                // TODO load a bigger chunk if the map is low density,
                // or if this is the only map on screen
                let (crop, newlat0, newlat1, newlong0, newlong1) =
                    self.calc_crop(blat0, boxlat1: blat1, boxlong0: blong0, boxlong1: blong1)
                
                let shrunk = self.imgresize(rawimg!, crop: crop, shrink_factor: factor)
                
                DispatchQueue.main.async {
                    if self.state != State.loading {
                        NSLog("Warning ########### %@ load disregarded", self.name)
                    } else {
                        self.curlat0 = newlat0
                        self.curlat1 = newlat1
                        self.curlong0 = newlong0
                        self.curlong1 = newlong1
                        self.curlatheight = abs(newlat1 - newlat0)
                        self.curlongwidth = abs(newlong1 - newlong0)
                        self.curmidlat = (newlat0 + newlat1) / 2
                        self.curmidlong = (newlong0 + newlong1) / 2
                        self.trans(State.loaded, arg: shrunk)
                    }
                    cb()
                }
            } else {
                DispatchQueue.main.async {
                    if self.state != State.loading {
                        NSLog("Warning ########### %@ load (cantload) disregarded", self.name)
                    } else {
                        self.trans(State.cantload, arg: nil)
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
    static let MIN_RAM = 75000000
    var ram_limit = INITIAL_RAM_LIMIT
    
    var _loader_busy: Bool = false

    var maps: [MapDescriptor] = [];
    var current_map_list: [String:MapDescriptor] = [:]
    var i_notloaded: UIImage
    var i_loading: UIImage
    var i_cantload: UIImage
    var i_oom: UIImage
    
    var memoryWarningObserver : NSObjectProtocol!
    
    class func parse_map_name(_ f: String) -> (ok: Bool, lat: Double, long: Double,
        latheight: Double, longwidth: Double, dx: Double, dy: Double)
    {
        NSLog("Parsing %@", f)
        var lat = 1.0
        var long = 1.0
        var latheight = 0.0
        var longwidth = 0.0
        var dx: Double? = 0.0
        var dy: Double? = 0.0
        
        let e = f.lowercased()
        let g = (e.split(separator: ".").map{ String($0) }).first!
        var h = (g.split(separator: "+").map{ String($0) })
        
        if h.count != 4 && h.count != 6 {
            NSLog("    did not find 4/6 tokens")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        if h[0].count < 4 || h[0].count > 6 {
            NSLog("    latitude with <3 or >5 chars")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        
        if h[1].count < 4 || h[1].count > 6 {
            NSLog("    latitude with <3 or >5 chars")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        if h[2].count < 2 || h[2].count > 4 {
            NSLog("    latheight with <3 or >4 chars")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        if h[3].count < 2 || h[3].count > 4 {
            NSLog("    longwidth with <3 or >4 chars")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        
        let ns = h[0].last
        
        if (ns != "n" && ns != "s") {
            NSLog("    latitude with no N or S suffix")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        if (ns == "s") {
            lat = -1;
        }
        
        let ew = h[1].last
        
        if (ew != "e" && ew != "w") {
            NSLog("    longitude with no W or E suffix")
            return (false, 0, 0, 0, 0, 0, 0)
        }
        if (ew == "w") {
            long = -1;
        }
        h[0] = String(h[0][..<h[0].index(before: h[0].endIndex)])
        h[1] = String(h[1][..<h[1].index(before: h[1].endIndex)])
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
    
    func get_maps(_ clat: Double, clong: Double, radius: Double, screenh: Double) -> [String:MapDescriptor]?
    {
        // NOTE: we use a radius instead of a box to test if a map belongs to the screen,
        // because in HEADING modes the map rotates, so the map x screen overlap must be
        // valid for every heading
        
        var new_list: [String:MapDescriptor] = [:]
        
        // calculate intersection with screen circle and proximity to screen center
        
        for map in maps {
            let (ins, d) = GPSModel2.map_inside(
                map.olat0, maplatmid: map.omidlat, maplatb: map.olat1,
                maplonga: map.olong0, maplongmid: map.omidlong, maplongb: map.olong1,
                lat_circle: clat, long_circle: clong, radius: radius)
            map.insertion = ins
            map.distance = d
        }
        
        // Try to free memory before it becomes a problem
        // Naïve strategy: release maps not in use right now
        
        for map in maps {
            if self.ram_within_comfortable_limits() {
                break
            }
            if map.insertion <= 0 && map.is_loaded() {
                NSLog("Unused evicted from memory: %@", map.name)
                map.please_unload()
            }
        }
        
        // sorting helps the culling algorithm
        
        let maps_sorted = maps.sorted(by: {
            if $0.priority == $1.priority {
                return $0.distance < $1.distance
            }
            return $0.priority < $1.priority
        })
    
        for map in maps_sorted {
            if map.insertion > 0 && map.is_loaded() {
                
                let (blat0, blat1, blong0, blong1) =
                    GPSModel2.enclosing_box(clat, clong: clong, radius: radius * 1.1)
                var blowup = false
                let hpixels = map.cur_density() * CGFloat(screenh)
                
                if hpixels < 1500 && map.is_shrunk() {
                    // found wanting in resolution; reload without remove from screen
                    NSLog("Blowing up image density %@ cur density %f", map.name, map.cur_density())
                    blowup = true
                } else if (hpixels > 2300 && !self.ram_within_safe_limits()) {
                    NSLog("Shrinking image density %@ cur density %f", map.name, map.cur_density())
                    blowup = true
                } else if !map.is_crop_enough(blat0, boxlat1: blat1, boxlong0: blong0, boxlong1: blong1) {
                    NSLog("Re-cropping image %@", map.name)
                    blowup = true
                }
                if blowup {
                    let (blat0, blat1, blong0, blong1) =
                        GPSModel2.enclosing_box(clat, clong: clong, radius: radius * 1.5)
                    
                    if !map.please_reload(blat0, lat1: blat1,
                                            long0: blong0, long1: blong1,
                                            screenh: screenh) {
                            break
                    }
                }
            }
        }
        
        if !ram_within_hard_limits(nil) {
            // memory full: all unused maps already removed
            // try to remove lowest-priority
            for map in maps_sorted.reversed() {
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
                        // crop kept in memory
                        let (blat0, blat1, blong0, blong1) =
                            GPSModel2.enclosing_box(clat, clong: clong, radius: radius * 1.5)
                        _ = map.please_load(blat0, lat1: blat1,
                                        long0: blong0, long1: blong1,
                                        screenh: screenh)
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
                memory_tally += map.currentram
            }
            if map.state == State.loading {
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
    
    init(_: Int)
    {
        i_notloaded = MapModel.simple_image(UIColor(red: 0, green: 1.0, blue: 0, alpha: 0.33))
        i_oom = MapModel.simple_image(UIColor(red: 1.0, green: 0, blue: 0.0, alpha: 0.33))
        i_loading = MapModel.simple_image(UIColor(red: 0, green: 0.0, blue: 1.0, alpha: 0.33))
        i_cantload = MapModel.simple_image(UIColor(red: 1.0, green: 0, blue: 1.0, alpha: 0.33))
        super.init()
        
        maps = []
        
        let fileManager = FileManager.default
        let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0] as URL
        
        #if targetEnvironment(simulator)
        // Write a canary file to find the app's Documents folder in Simulator
        let w = documentsUrl.appendingPathComponent("canary666.txt")
        let text = "bla"
        do {
            try text.write(to: w, atomically: false, encoding: String.Encoding.utf8)
        } catch {
        }
        #endif
        
        if let directoryUrls = try? FileManager.default.contentsOfDirectory(at: documentsUrl,
                                                                                            includingPropertiesForKeys: nil,
                                                                                            options:FileManager.DirectoryEnumerationOptions.skipsSubdirectoryDescendants) {
            NSLog("%@", directoryUrls)
            for url in directoryUrls {
                let f = url.lastPathComponent
                
                if f.hasSuffix("txt") {
                    NSLog("    Found target file");
                    GPSModel2.model().read_targets(url)
                    continue
                }
                
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
                                        name: url.lastPathComponent,
                                        priority: coords.latheight,
                                        latNW: lat,
                                        longNW: long,
                                        latheight: coords.latheight,
                                        longwidth: coords.longwidth)
                maps.append(map)
            }
        }
        
        let notifications = NotificationCenter.default
        memoryWarningObserver = notifications.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                                                 object: nil,
                                                                 queue: OperationQueue.main,
                                                                 using: { [unowned self] (notification : Notification!) -> Void in
                                                                    self.memory_low()
            }
        )
    }
    
    func are_there_maps() -> Bool
    {
        return self.maps.count > 0
    }
    
    deinit {
        let notifications = NotificationCenter.default
        notifications.removeObserver(memoryWarningObserver, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
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
        
        self.ram_limit = max(MapModel.MIN_RAM, self.max_ram_inuse / 10 * 8)
        self.max_ram_inuse = self.ram_limit
    }
    
    func update_ram(_ map: MapDescriptor, n: Int) {
        let change = n - map.currentram
        map.currentram = n
        self.ram_inuse += change
        self.max_ram_inuse = max(self.ram_inuse, self.max_ram_inuse)
        var sign = "+"
        if change < 0 {
            sign = ""
        }
        NSLog("Memory %@%d, inuse %d of %d", sign, change,
              self.ram_inuse, self.ram_limit)
    }
    
    func ram_within_comfortable_limits() -> Bool {
        return (self.ram_limit / 100 * 25) > self.ram_inuse
    }
    
    func ram_within_safe_limits() -> Bool {
        return (self.ram_limit / 10 * 5) > self.ram_inuse
    }
    
    func ram_within_hard_limits(_ newobj: MapDescriptor?) -> Bool {
        var additional = 0
        if newobj != nil {
            additional += newobj!.ram_estimate()
        }
        return self.ram_limit > (self.ram_inuse + additional)
    }
    
    static let singleton = MapModel(1);
    
    class func model() -> MapModel
    {
        return singleton
    }
    
    class func simple_image(_ color: UIColor) -> UIImage
    {
        let rect = CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext();
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
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
}

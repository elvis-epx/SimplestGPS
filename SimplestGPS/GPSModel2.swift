//
//  GPSModel2.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 8/6/15.
//  Copyright (c) 2015 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

@objc protocol ModelListener {
    func fail()
    func permission()
    func update()
}

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

@objc class GPSModel2: NSObject, CLLocationManagerDelegate {
    var observers = [ModelListener]()
    var names = [NSObject: AnyObject]()
    var lats = [NSObject: AnyObject]()
    var longs = [NSObject: AnyObject]()
    var alts = [NSObject: AnyObject]()
    var target_list = [String]()
    var next_target: Int = 0
    var curloc: CLLocation? = nil
    var curloc_new: CLLocation? = nil
    var held: Bool = false
    var lman: CLLocationManager? = nil
    var metric: Int = 1;
    var editing: Int = -1
    
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
    var prefsObserver : NSObjectProtocol!
    
    func hold() -> Bool
    {
        if curloc == nil {
            return false
        }
        held = true
        curloc_new = curloc
        return true
    }
    
    func releas()
    {
        curloc = curloc_new
        // TODO call update() when curloc changed and is not nil?
        held = false
    }
    
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
    
    class func array_adapter(keys: Array<NSObject>) -> [String]
    {
        var ret = [String]();
        for k in keys {
            // exclamation point means: cast w/ abort if type is wrong
            ret.append(k as! String);
        }
        return ret;
    }
    
    
    // make sure that longitude is in range -180 <= x < +180
    class func normalize_longitude(x: Double) -> Double
    {
        if x < -180 {
            // 181W -> 179E
            return 360 - x
        } else if x >= 180 {
            // 181E -> 179W
            return x - 360
        }
        return x
    }

    // make sure that longitude is in range -180 <= x < +180
    class func normalize_longitude_cgfloat(x: CGFloat) -> CGFloat
    {
        if x < -180 {
            // 181W -> 179E
            return 360 - x
        } else if x >= 180 {
            // 181E -> 179W
            return x - 360
        }
        return x
    }

    // test whether a longitude range is nearer to meridian 180 than meridian 0
    class func nearer_180(a: Double, b: Double) -> Bool
    {
        // note: this test assumes that range is < 180 degrees
        return (abs(a) + abs(b)) >= 180
    }

    class func nearer_180_cgfloat(a: CGFloat, b: CGFloat) -> Bool
    {
        return (abs(a) + abs(b)) >= 180
    }

    // converts longitude, so values across +180/-180 line are directly comparable
    // It actually moves the 180 "problem" to the meridian 0 (longitude line becomes 359..0..1)
    // so this function should be used only when the range of interest does NOT cross 0
    class func offset_180(x: Double) -> Double
    {
        if x < 0 {
            return x + 360
        }
        return x
    }

    class func offset_180_cgfloat(x: CGFloat) -> CGFloat
    {
        if x < 0 {
            return x + 360
        }
        return x
    }

    // checks whether a coordinate is inside a circle
    class func inside(lat: Double, long: Double, lat_circle: Double, long_circle: Double, radius: Double) -> Bool
    {
        let _lat = lat
        var _long = normalize_longitude(long)

        let _lata = lat_circle
        var _longa = normalize_longitude(long_circle)
        
        if nearer_180(_long, b: _longa) {
            _long = offset_180(_long)
            _longa = offset_180(_longa)
        }

        return harvesine(_lat, lat2: _lata, long1: _long, long2: _longa) <= radius
    }

    class func clamp(value: Double, mini: Double, maxi: Double) -> Double
    {
        return max(mini, min(maxi, value))
    }
    
    class func map_inside(maplata: Double, maplatb: Double, maplonga: Double, maplongb: Double,
                          lat_circle: Double, long_circle: Double, radius: Double) -> (Int, Double)
    {
        let _maplata = min(maplata, maplatb)
        let _maplatb = max(maplata, maplatb)
        var _maplonga = normalize_longitude(maplonga)
        var _maplongb = normalize_longitude(maplongb)
        let _lata = lat_circle
        var _longa = normalize_longitude(long_circle)
        
        if nearer_180(_longa, b: _maplonga) || nearer_180(_longa, b: _maplongb) {
            _longa = offset_180(_longa)
            _maplonga = offset_180(_maplonga)
            _maplongb = offset_180(_maplongb)
        }
        
        (_maplonga, _maplongb) = (min(_maplonga, _maplongb), max(_maplonga, _maplongb))
        
        // from http://stackoverflow.com/questions/401847/circle-rectangle-collision-detection-intersection
        // Find the closest point to the circle within the rectangle
        let closest_long = clamp(_longa, mini: _maplonga, maxi: _maplongb);
        let closest_lat = clamp(_lata, mini: _maplata, maxi: _maplatb);
        let db = harvesine(closest_lat, lat2: _lata, long1: closest_long, long2: _longa)
        // also find the distance from circle center to map center, for prioritization purposes
        let dc = harvesine((_maplata + _maplatb) / 2, lat2: _lata,
                           long1: (_maplonga + _maplongb) / 2, long2: _longa)
        
        if db > radius {
            // no intersection
            return (0, dc)
        } else if db > 0 {
            // intersects but not completely enclosed by map
            return (1, dc)
        }
        
        // is the circle completely enclosed by map?
        // convert circle to a box
        let radius_lat = radius / 1853.0 / 60.0
        let radius_long = radius_lat / longitude_proportion(_lata)
        let lat0_circle = _lata - radius_lat
        let lat1_circle = _lata + radius_lat
        let long0_circle = _longa - radius_long
        let long1_circle = _longa + radius_long
        
        if lat0_circle >= _maplata && lat1_circle <= _maplatb
                && long0_circle >= _maplonga && long1_circle <= _maplongb {
            // box enclosed in map
            return (2, dc)
        }
        
        return (1, dc)
    }
    
    class func do_format_heading(n: Double) -> String
    {
        if n != n {
            return ""
        }
        return String(format: "%.0f°", n);
    }

    class func format_deg(p: Double) -> String
    {
        if p != p {
            return ""
        }
        var n: Double = p;
        let deg = Int(floor(n));
        n = (n - floor(n)) * 60;
        let minutes = Int(floor(n));
        return String(format: "%d°%02d'", deg, minutes);
    }
    
    class func format_deg2(p: Double) -> String
    {
        if p != p {
            return ""
        }
        var n: Double = p;
        n = (n - floor(n)) * 60;
        n = (n - floor(n)) * 60;
        let seconds = Int(floor(n));
        n = (n - floor(n)) * 100;
        let cents = Int(floor(n));
        return String( format: "%02d.%02d\"", seconds, cents);
    }
    
    class func format_deg_t(p: Double) -> String
    {
        if p != p {
            return ""
        }
        var n: Double = p;
        let deg = Int(floor(n));
        n = (n - floor(n)) * 60;
        let minutes = Int(floor(n));
        n = (n - floor(n)) * 60;
        let seconds = Int(floor(n));
        n = (n - floor(n)) * 100;
        let cents = Int(floor(n));
        return String(format: "%d.%02d.%02d.%02d", deg, minutes, seconds, cents);
    }
    
    
    class func format_latitude_t(lat: Double) -> String
    {
        if lat != lat {
            return "---";
        }
        let suffix = (lat < 0 ? "S" : "N");
        return String(format: "%@%@", format_deg_t(fabs(lat)), suffix);
    }
    
    class func format_longitude_t(lo: Double) -> String
    {
        if lo != lo {
            return "---";
        }
        let suffix = (lo < 0 ? "W" : "E");
        return String(format: "%@%@", format_deg_t(fabs(lo)), suffix);
    }
    
    class func format_heading_t(course: Double) -> String
    {
        if course != course {
            return "---";
        }
        return do_format_heading(course);
    }
    
    class func format_heading_delta_t (course: Double) -> String
    {
        if course != course {
            return "---";
        }
        
        let plus = course > 0 ? "+" : "";
        return String(format: "%@%@", plus, do_format_heading(course));
    }
    
    class func format_altitude_t(alt: Double) -> String
    {
        if alt != alt {
            return "---";
        }
        return String(format: "%.0f", alt);
    }

    class func do_format_latitude(lat: Double) -> String
    {
        if lat != lat {
            return "---";
        }
        let suffix = lat < 0 ? "S" : "N";
        return String(format: "%@%@", format_deg(fabs(lat)), suffix);
    }

    class func do_format_latitude_full(lat: Double) -> String
    {
        if lat != lat {
            return "---";
        }
        let suffix = lat < 0 ? "S" : "N";
        return String(format: "%@%@%@", format_deg(fabs(lat)), format_deg2(fabs(lat)), suffix);
    }

    class func do_format_latitude2(lat: Double) -> String
    {
        if lat != lat {
            return "---";
        }
        return String(format: "%@", format_deg2(fabs(lat)));
    }

    class func do_format_longitude(lon: Double) -> String
    {
        if lon != lon {
            return "---";
        }
        let suffix = lon < 0 ? "W" : "E";
        return String(format: "%@%@", format_deg(fabs(lon)), suffix);
    }

    class func do_format_longitude_full(lon: Double) -> String
    {
        if lon != lon {
            return "---";
        }
        let suffix = lon < 0 ? "W" : "E";
        return String(format: "%@%@%@", format_deg(fabs(lon)), format_deg2(fabs(lon)), suffix);
    }
    

    class func do_format_longitude2(lon: Double) -> String
    {
        if lon != lon {
            return "---";
        }
        return String(format: "%@", format_deg2(fabs(lon)));
    }
    
    class func do_format_altitude(p: Double, met: Int) -> String
    {
        if p != p {
            return ""
        }

        var alt: Double = p;
        if met == 0 {
            alt *= 3.28084;
        }
        
        return String(format: "%.0f%@", alt, (met != 0 ? "m" : "ft"));
    }
    
    class func format_distance_t(p: Double, met: Int) -> String
    {
        var dst = p;
        if dst != dst {
            return "---";
        }
        
        let f = NSNumberFormatter();
        f.numberStyle = .DecimalStyle;
        f.maximumFractionDigits = 0;
        f.roundingMode = .RoundHalfEven;
        
        var m = "m";
        var i = "ft";
        if met != 0 {
            if dst >= 10000 {
                dst /= 1000;
                m = "km";
            }
        } else {
            dst *= 3.28084;
            if dst >= (5280 * 6) {
                dst /= 5280;
                i = "mi";
            }
        }
        
        return String(format: "%@%@", f.stringFromNumber(Int(dst))!, (met != 0 ? m : i));
    }
    
    class func do_format_speed(p: Double, met: Int) -> String
    {
        if p != p || p == 0 {
            return ""
        }
        
        var spd = p;
        
        if met != 0 {
            spd *= 3.6;
        } else {
            spd *= 2.23693629;
        }
        
        return String(format: "%.0f%@", spd, (met != 0 ? "km/h " : "mi/h "));
    }
    
    class func do_format_accuracy(h: Double, vertical v: Double, met: Int) -> String
    {
        if h > 10000 || v > 10000 {
            return "imprecise";
        }
        if v >= 0 {
            return String(format: "%@↔︎ %@↕︎", do_format_altitude(h, met: met), do_format_altitude(v, met: met));
        } else if h >= 0 {
            return String(format: "%@↔︎", do_format_altitude(h, met: met));
        } else {
            return "";
        }
    }
    
    class func harvesine(lat1: Double, lat2: Double, long1: Double, long2: Double) -> Double
    {
        // http://www.movable-type.co.uk/scripts/latlong.html
        
        if lat1 == lat2 && long1 == long2 {
            // avoid a non-zero result due to FP limitations
            return 0;
        }
        
        let R = 6371000.0; // metres
        let phi1 = lat1 * M_PI / 180.0;
        let phi2 = lat2 * M_PI / 180.0;
        let deltaphi = (lat2-lat1) * M_PI / 180.0;
        let deltalambda = (long2-long1) * M_PI / 180.0;
        
        let a = sin(deltaphi/2) * sin(deltaphi/2) +
            cos(phi1) * cos(phi2) *
            sin(deltalambda/2) * sin(deltalambda/2);
        let c = 2 * atan2(sqrt(a), sqrt(1.0 - a));
        let d = R * c;
        
        if d < 0.1 {
            // make sure it returns a round 0 when distance is negligible
            return 0
        }
        
        return d;
    }
    
    /* Given a latitude, return the proportion of longitude distance
     e.g. 1 deg long / 1 deg lat (tends to 1.0 in tropics, to 0.0 in poles
     */
    class func longitude_proportion(lat: Double) -> Double
    {
        return cos(abs(lat) * M_PI / 180.0)
    }

    class func longitude_proportion_cgfloat(lat: CGFloat) -> CGFloat
    {
        return CGFloat(longitude_proportion(Double(lat)))
    }
    
    class func azimuth(lat1: Double, lat2: Double, long1: Double, long2: Double) -> Double
    {
        let phi1 = lat1 * M_PI / 180.0;
        let phi2 = lat2 * M_PI / 180.0;
        let lambda1 = long1 * M_PI / 180.0;
        let lambda2 = long2 * M_PI / 180.0;
        
        let y = sin(lambda2-lambda1) * cos(phi2);
        let x = cos(phi1) * sin(phi2) -
            sin(phi1) * cos(phi2) * cos(lambda2 - lambda1);
        var brng = atan2(y, x) * 180.0 / M_PI;
        if brng < 0 {
            brng += 360.0;
        }
        return brng;
    }
    
    
    class func parse_latz(lat: String) -> Double
    {
        return parse_coordz(lat, latitude: true);
    }
    
    class func parse_longz(lo: String) -> Double
    {
        return parse_coordz(lo, latitude: false);
    }
    
    
    class func parse_coordz(c: String, latitude is_lat: Bool) -> Double
    {
        var value: Double = 0.0 / 0.0;
        var deg: Int = 0
        var min: Int = 0
        var sec: Int = 0
        var cent: Int = 0
        let coord = c.uppercaseString;
        
        let s = NSScanner(string: coord);
        s.charactersToBeSkipped = NSCharacterSet(charactersInString: ". ;,:/");
        
        if !s.scanInteger(&deg) {
            NSLog("Did not find degree in %@", coord);
            return value;
        }
        
        if deg < 0 || deg > 179 || (is_lat && deg > 89) {
            NSLog("Invalid deg %ld", deg);
            return value;
        }
        
        var bt = s.scanLocation;
        if s.scanInteger(&min) {
            if min < 0 || min > 59 {
                NSLog("Invalid minute %ld", min);
                return value;
            }
            bt = s.scanLocation;
            if s.scanInteger(&sec) {
                if sec < 0 || sec > 59 {
                    NSLog("Invalid second %ld", sec);
                    return value;
                }
                bt = s.scanLocation;
                if s.scanInteger(&cent) {
                    if cent < 0 || cent > 99 {
                        NSLog("Invalid cent %ld", cent);
                        return value;
                    }
                } else {
                    s.scanLocation = bt;
                    NSLog("Did not find cent in %@ (may not be error)", coord);
                }
            } else {
                s.scanLocation = bt;
                NSLog("Did not find second in %@ (may not be error)", coord);
            }
        } else {
            s.scanLocation = bt;
            NSLog("Did not find minute in %@ (may not be error)", coord);
        }
        
        var cardinal: NSString?
        if !s.scanUpToString("FOOBAR", intoString: &cardinal) {
            NSLog("Did not find cardinal in %@ (assuming positive)", coord);
            cardinal = "";
        }
        
        var sign = 1.0
        
        if is_lat {
            if cardinal == "N" || cardinal == "" || cardinal == "+" {
                // positive
            } else if cardinal == "S" || cardinal == "-" {
                sign = -1.0;
            } else {
                NSLog("Invalid cardinal for latitude: %@", cardinal!);
                return value;
            }
        } else {
            if cardinal == "E" || cardinal == "" || cardinal == "+" {
                // positive
            } else if cardinal == "W" || cardinal == "-" {
                sign = -1.0;
            } else {
                NSLog("Invalid cardinal for longitude: %@", cardinal!);
                return value;
            }
        }
        
        value = Double(deg)
        value += Double(min) / 60.0
        value += Double(sec) / 3600.0
        value += Double(cent) / 360000.0
        value *= sign
        
        NSLog("Parsed %@ as %f %ld %ld %ld %ld %@ %f", coord, sign, deg,
              min, sec, cent, cardinal!, value);
        return value;
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
            let newimg = GPSModel2.imgresize(map.img, newsize: newsize)
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

    
    func latitude() -> Double
    {
        return self.curloc != nil ? (self.curloc!.coordinate.latitude) : Double.NaN
    }

    func longitude() -> Double
    {
        return self.curloc != nil ? (self.curloc!.coordinate.longitude) : Double.NaN
    }
    
    func speed() -> Double {
        return self.curloc != nil ? (self.curloc!.speed < 0 ? Double.NaN : self.curloc!.speed) : Double.NaN
    }
    
    func horizontal_accuracy() -> Double
    {
        return self.curloc != nil ? (self.curloc!.horizontalAccuracy) : Double.NaN
    }
    
    func vertical_accuracy() -> Double
    {
        return self.curloc != nil ? (self.curloc!.verticalAccuracy) : Double.NaN
    }
    
    func heading() -> Double
    {
        return self.curloc != nil ? (self.curloc!.course >= 0 ? self.curloc!.course : Double.NaN) : Double.NaN
    }
    
    func altitude() -> Double {
        return self.curloc != nil ? (self.curloc!.altitude) : Double.NaN
    }

    func locationManager(manager: CLLocationManager, didUpdateToLocation newLocation: CLLocation, fromLocation oldLocation: CLLocation)
    {
        if held {
            self.curloc_new = newLocation
        } else {
            self.curloc = newLocation
            self.update()
        }
    }

    func latitude_formatted() -> String
    {
        return GPSModel2.do_format_latitude_full(latitude());
    }

    func latitude_formatted_part1() -> String
    {
        return GPSModel2.do_format_latitude(latitude());
    }

    func latitude_formatted_part2() -> String
    {
        return GPSModel2.do_format_latitude2(latitude());
    }
    
    func heading_formatted() -> String
    {
        return GPSModel2.do_format_heading(self.heading())
    }
    
    func longitude_formatted() -> String
    {
        return GPSModel2.do_format_longitude_full(self.longitude())
    }
    
    func longitude_formatted_part1() -> String
    {
        return GPSModel2.do_format_longitude(self.longitude());
    }

    func longitude_formatted_part2() -> String
    {
        return GPSModel2.do_format_longitude2(self.longitude());
    }
    
    func altitude_formatted() -> String
    {
        return GPSModel2.do_format_altitude(self.altitude(), met: metric)
    }
    
    func speed_formatted() -> String
    {
        return GPSModel2.do_format_speed(self.speed(), met: metric);
    }

    func accuracy_formatted() -> String
    {
        return GPSModel2.do_format_accuracy(horizontal_accuracy(), vertical: vertical_accuracy(), met: metric)
    }
    
    func target_count() -> Int
    {
        return target_list.count;
    }
    
    func target_name(index: Int) -> String
    {
        if index < 0 || index >= target_list.count {
            return "Here";
        }
        return names[target_list[index]] as! String;
    }

    func target_altitude(index: Int) -> Double
    {
        if index < 0 || index >= target_list.count {
            return Double.NaN;
        }
        
        let alt = alts[target_list[index]] as! Double;
        if (alt == 0) {
            return Double.NaN;
        }
        
        return -(altitude() - alt);
    }

    func target_altitude_formatted(index: Int) -> String
    {
        var dn = target_altitude(index);
        if dn != dn {
            return "";
        }
        
        if metric == 0 {
            dn *= 3.28084;
        }
        let esign = dn >= 0 ? "+": "";
        let sn = GPSModel2.format_altitude_t(dn);
        let unit = metric != 0 ? "m" : "ft";
        return String(format: "%@%@%@", esign, sn, unit);
    }
    
    func target_altitude_input_formatted(index: Int) -> String
    {
        var dn: Double;
        
        if index < 0 || index >= target_list.count {
            dn = altitude()
            if dn != dn {
                dn = 0
            }
        } else if alts[target_list[index]] == nil {
            return "";
        } else {
            dn = alts[target_list[index]] as! Double;
            if dn != dn || dn == 0 {
                return "";
            }
            if metric == 0 {
                dn *= 3.28084;
            }
        }
        return GPSModel2.format_altitude_t(dn);
    }
    
    func target_latitude(index: Int) -> Double
    {
        var n: Double;
        if index < 0 || index >= target_list.count {
            n = latitude()
            if n != n {
                n = 0
            }
        } else {
            n = lats[target_list[index]] as! Double;
        }
        return n;
    }
   
    func target_latitude_formatted(index: Int) -> String
    {
        return GPSModel2.format_latitude_t(self.target_latitude(index));
    }

    func target_longitude(index: Int) -> Double
    {
        var n: Double;
        if index < 0 || index >= target_list.count {
            n = longitude()
            if n != n {
                n = 0
            }
        } else {
            n = longs[target_list[index]] as! Double;
        }
        return n;
    }

    func target_longitude_formatted(index: Int) -> String
    {
        return GPSModel2.format_longitude_t(self.target_longitude(index));
    }
    
    func target_heading(index: Int) -> Double
    {
        if index < 0 || index >= target_list.count {
            return Double.NaN;
        }
        
        let lat1 = self.latitude();
        let long1 = self.longitude();
        
        if lat1 != lat1 || long1 != long1 {
            return Double.NaN
        }
        
        let key = target_list[index];
        let lat2 = lats[key] as! Double;
        let long2 = longs[key] as! Double;
        
        return GPSModel2.azimuth(lat1, lat2: lat2, long1: long1, long2: long2);
    }

    func target_heading_formatted(index: Int) -> String
    {
        return GPSModel2.format_heading_t(self.target_heading(index));
    }
    
    func target_heading_delta(index: Int) -> Double
    {
        let tgt_heading = target_heading(index)
        if tgt_heading != tgt_heading {
            return Double.NaN
        }
        
        let cur_heading = self.heading()
        if cur_heading < 0 || cur_heading != cur_heading {
            return Double.NaN
        }
        
        var delta = tgt_heading - cur_heading
        if delta <= -180 {
            delta += 360
        } else if delta >= 180 {
            delta -= 360
        }
        return delta;
    }

    func target_heading_delta_formatted(index: Int) -> String
    {
        return GPSModel2.format_heading_delta_t(target_heading_delta(index));
    }
    
    func target_distance(index: Int) -> Double
    {
        if index < 0 || index >= target_list.count {
            return Double.NaN;
        }
        
        let lat1 = latitude()
        let long1 = longitude()
        
        if lat1 != lat1 || long1 != long1 {
            return Double.NaN
        }
        
        let key = target_list[index];
        let lat2 = lats[key] as! Double;
        let long2 = longs[key] as! Double;
        
        return GPSModel2.harvesine(lat1, lat2: lat2, long1: long1, long2: long2);
    }
    
    func target_distance_formatted(index: Int) -> String
    {
        return GPSModel2.format_distance_t(target_distance(index), met: metric);
    }
    
    func target_set(pindex: Int, nam: String, latitude: String, longitude: String, altitude: String) -> String?
    {
        NSLog("Target_set %d", pindex)
        
        var index = pindex;
        
        if nam.isEmpty {
            return "Name must not be empty.";
        }
    
        let dlatitude = GPSModel2.parse_latz(latitude);
        if dlatitude != dlatitude {
            return "Latitude is invalid.";
        }
    
        let dlongitude = GPSModel2.parse_longz(longitude);
        if dlongitude != dlongitude {
            return "Longitude ixs invalid.";
        }
    
        var daltitude = 0.0;
        if !altitude.isEmpty {
            daltitude = (altitude as NSString).doubleValue;
            if daltitude == 0.0 {
                return "Altitude is invalid.";
            }
        }
        
        if metric == 0 {
            // altitude supplied in ft internally stored in m
            daltitude /= 3.28084;
        }
        
        var key: String = "";
        
        if index < 0 || index >= target_list.count {
            next_target += 1
            index = next_target
            key = String(format: "k%ld", index);
        } else {
            key = target_list[index];
        }
        
        names[key] = nam;
        lats[key] = dlatitude;
        longs[key] = dlongitude;
        alts[key] = daltitude;
        
        saveTargets();
        update();
        
        return nil;
    }
    
    func target_delete(index: Int)
    {
        if index < 0 || index >= target_list.count {
            return;
        }
        let key = target_list[index];
        names.removeValueForKey(key);
        lats.removeValueForKey(key);
        longs.removeValueForKey(key);
        alts.removeValueForKey(key);

        saveTargets();
        update();
    }
    
    func saveTargets()
    {
        updateTargetList();
        let prefs = NSUserDefaults.standardUserDefaults();
        prefs.setObject(names, forKey: "names");
        prefs.setObject(lats, forKey: "lats");
        prefs.setObject(longs, forKey: "longs");
        prefs.setObject(alts, forKey: "alts");
        prefs.setInteger(next_target, forKey: "next_target");
    }
    
    func update()
    {
        for observer in observers {
            observer.update();
        }
    }

    func target_getEdit() -> Int
    {
        return editing;
    }
    
    func target_setEdit(index: Int)
    {
        editing = index;
    }
    
    func upgradeAltitudes()
    {
        // takes care of upgrade from 1.2 to 1.3, where targets can have
        // altitudes. Missing altitudes are added to the list
        var dirty = false;
        for key in target_list {
            if alts[key] == nil {
                dirty = true;
                alts[key] = 0.0;
                NSLog("Added key %@ in altitudes due to upgrade", key);
            }
        }
        
        if dirty {
            let prefs = NSUserDefaults.standardUserDefaults();
            prefs.setObject(alts, forKey: "alts");
        }
    }

    func get_altitude_unit() -> String
    {
        return (get_metric() != 0) ? "m" : "ft"
    }
    
    override init()
    {
        i_notloaded = GPSModel2.simple_image(UIColor(colorLiteralRed: 0, green: 1.0, blue: 0, alpha: 0.33))
        i_oom = GPSModel2.simple_image(UIColor(colorLiteralRed: 1.0, green: 0, blue: 0.0, alpha: 0.33))
        i_loading = GPSModel2.simple_image(UIColor(colorLiteralRed: 0, green: 0.0, blue: 1.0, alpha: 0.33))
        i_loading_res = GPSModel2.simple_image(UIColor(colorLiteralRed: 0, green: 1.0, blue: 1.0, alpha: 0.33))
        i_cantload = GPSModel2.simple_image(UIColor(colorLiteralRed: 1.0, green: 0, blue: 1.0, alpha: 0.33))
        super.init()
        
        let prefs = NSUserDefaults.standardUserDefaults();
        
        prefs.registerDefaults(["metric": 1, "next_target": 3,
            "names": ["1": "Joinville", "2": "Blumenau"],
            "lats": ["1": GPSModel2.parse_latz("26.18.19.50S"),
                "2": GPSModel2.parse_latz("26.54.46.10S")],
            "longs": ["1": GPSModel2.parse_longz("48.50.44.44W"),
                "2": GPSModel2.parse_longz("49.04.04.47W")],
            "alts": ["2": 50.0],
            ])
        
        names = prefs.dictionaryForKey("names")!
        lats = prefs.dictionaryForKey("lats")!
        longs = prefs.dictionaryForKey("longs")!
        alts = prefs.dictionaryForKey("alts")!
        
        self.updateTargetList()
        self.upgradeAltitudes()
        
        metric = prefs.integerForKey("metric")
        next_target = prefs.integerForKey("next_target")
        curloc = nil
        
        lman = CLLocationManager()
        lman!.delegate = self
        lman!.distanceFilter = kCLDistanceFilterNone
        lman!.desiredAccuracy = kCLLocationAccuracyBest
        lman!.requestAlwaysAuthorization()
        lman!.startUpdatingLocation()
        
        maps = []
        
        let fileManager = NSFileManager.defaultManager()
        let documentsUrl = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as NSURL
        if let directoryUrls = try? NSFileManager.defaultManager().contentsOfDirectoryAtURL(documentsUrl,
                                                                                            includingPropertiesForKeys: nil,
                                                                                            options:NSDirectoryEnumerationOptions.SkipsSubdirectoryDescendants) {
            NSLog("%@", directoryUrls)
            for url in directoryUrls {
                let f = url.lastPathComponent!
                let coords = GPSModel2.parse_map_name(f)
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
        prefsObserver = notifications.addObserverForName(NSUserDefaultsDidChangeNotification,
                                object: nil,
                                queue: NSOperationQueue.mainQueue(),
                                usingBlock: { [unowned self] (notification : NSNotification!) -> Void in
                                    self.prefs_changed()
                                }
        )
        
        task_timer = NSTimer(timeInterval: 0.16, target: self,
                         selector: #selector(GPSModel2.task_serve),
                         userInfo: nil, repeats: true)
        NSRunLoop.currentRunLoop().addTimer(task_timer!, forMode: NSRunLoopCommonModes)
    }
    
    deinit {
        let notifications = NSNotificationCenter.defaultCenter()
        notifications.removeObserver(memoryWarningObserver, name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
        notifications.removeObserver(prefsObserver, name: NSUserDefaultsDidChangeNotification, object: nil)
        task_timer!.invalidate()
    }
    
    func prefs_changed()
    {
        let prefs = NSUserDefaults.standardUserDefaults();
        metric = prefs.integerForKey("metric")
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

    static let singleton = GPSModel2();
    
    class func model() -> GPSModel2
    {
        return singleton
    }
    
    func updateTargetList()
    {
        target_list = GPSModel2.array_adapter(Array(names.keys));
        target_list = target_list.sort({$0.localizedCaseInsensitiveCompare($1) ==
            .OrderedAscending});
        NSLog("Number of targets: %ld", target_list.count);
    }
    
    func set_metric(value: Int)
    {
        metric = value
        let prefs = NSUserDefaults.standardUserDefaults()
        prefs.setInteger(metric, forKey: "metric")
        if curloc != nil {
            return;
        }
        self.update();
    }
    
    func get_metric() -> Int
    {
        return metric;
    }
    
    func index_of_listener(haystack: [ModelListener], needle: ModelListener) -> Int
    {
        for i in 0..<haystack.count {
            if haystack[i] === needle {
                return i;
            }
        }
        return -1;
    }
    
    func contains(haystack: [ModelListener], needle: ModelListener) -> Bool
    {
        return index_of_listener(haystack, needle: needle) >= 0;
    }
    
    func addObs(observer: ModelListener)
    {
        if !contains(observers, needle: observer) {
            observers.append(observer);
            NSLog("Added observer %@", observer as! NSObject);
        }
        self.update();
    }
    
    func delObs(observer: ModelListener)
    {
        while contains(observers, needle: observer) {
            NSLog("Removed observer %@", observer as! NSObject);
            let i = index_of_listener(observers, needle: observer);
            observers.removeAtIndex(i);
        }
    }
    
    // Failed to get current location
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError)
    {
        if held {
            self.curloc_new = nil
        } else {
            self.curloc = nil
        }
        
        for observer in observers {
            observer.fail();
        }
        
        if error.code == CLError.Denied.rawValue {
            for observer in observers {
                observer.permission();
            }
            lman!.stopUpdatingLocation();
        }
    }
    
    func locationManager(manager :CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus)
    {
        lman!.startUpdatingLocation()
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

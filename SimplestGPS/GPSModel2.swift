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
import AVFoundation

@objc protocol ModelListener {
    func fail()
    func permission()
    func update()
}

@objc class GPSModel2: NSObject, CLLocationManagerDelegate {
    var observers = [ModelListener]()
    var names = [AnyHashable: Any]()
    var lats = [AnyHashable: Any]()
    var longs = [AnyHashable: Any]()
    var alts = [AnyHashable: Any]()
    var tdistances = [String: Double]()
    var tlastdistances = [String: Double]()
    var theadings = [String: Double]()
    var trelheadings = [String: Double]()
    var target_list = [String]()
    var next_target: Int = 0
    var curloc: CLLocation? = nil
    var curloc_new: CLLocation? = nil
    var held: Bool = false
    var lman: CLLocationManager? = nil
    var metric: Int = 1;
    var beep: Int = 1;
    var editing: Int = -1
    var mode: Int = 1 // MAPCOMPASS
    var tgt_dist: Int = 1
    var current_target: Int = -1
    var zoom: Double = 0.0
    var welcome: Int = 0
    var blink: Int = 1
    
    var fwav_hi = URL(fileURLWithPath: Bundle.main.path(forResource: "1000", ofType: "wav")!)
    var fwav_lo = URL(fileURLWithPath: Bundle.main.path(forResource: "670", ofType: "wav")!)
    var fwav_side = URL(fileURLWithPath: Bundle.main.path(forResource: "836", ofType: "wav")!)
    var wav_hi: AVAudioPlayer? = nil
    var wav_lo: AVAudioPlayer? = nil
    var wav_side: AVAudioPlayer? = nil
    var last_side_played: Date? = nil
    
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
    
    class func array_adapter(_ keys: Array<NSObject>) -> [String]
    {
        var ret = [String]();
        for k in keys {
            // exclamation point means: cast w/ abort if type is wrong
            ret.append(k as! String);
        }
        return ret;
    }
    
    // make sure that longitude is in range -180 <= x < +180
    class func handle_cross_180(_ c: CGFloat) -> CGFloat
    {
        var x = c
        while x < -180 {
            // 181W -> 179E
            x += 360
        }
        while x >= 180 {
            // 181E -> 179W
            x -= 360
        }
        return x
    }
    class func handle_cross_180f(_ x: Double) -> Double
    {
        return Double(handle_cross_180(CGFloat(x)))
    }
    
    // Makes a - b taking into consideration the international date line
    class func longitude_minus(_ a: CGFloat, minus: CGFloat) -> CGFloat
    {
        let c = a - minus
        // a difference above 180 degrees can be handled in the same
        // fashion as an absolute longitude (proof: make minus = 0)
        return handle_cross_180(c)
    }
    
    class func longitude_minusf(_ a: Double, minus: Double) -> Double
    {
        return Double(longitude_minus(CGFloat(a), minus: CGFloat(minus)))
    }

    // checks whether a coordinate is inside a circle
    class func inside(_ lat: Double, long: Double, lat_circle: Double, long_circle: Double, radius: Double) -> Bool
    {
        return harvesine(lat, lat2: lat_circle, long1: long, long2: long_circle) <= radius
    }

    // helper function for map_inside()
    class func clamp_lat(_ x: Double, a: Double, b: Double) -> Double
    {
        let (mini, maxi) = (min(a, b), max(a, b))
        return max(mini, min(maxi, x))
    }

    // helper function for map_inside()
    class func clamp_long(_ x: Double, a: Double, b: Double) -> Double
    {
        // convert longitudes to relative coordinates (as if a = 0)
        let db = longitude_minusf(b, minus: a)
        let da = 0.0
        let dx = longitude_minusf(x, minus: a)
        
        let dres = clamp_lat(dx, a: da, b: db)
        
        // convert back to absolute longitude
        return handle_cross_180f(dres + a)
    }
    
    class func contains_latitude(_ a: Double, b: Double, c: Double, d: Double) -> Bool {
        let (_a, _b) = (min(a, b), max(a, b))
        let (_c, _d) = (min(c, d), max(c, d))
        return (_a + 0.0001) >= _c && (_b - 0.0001) <= _d
    }

    class func contains_longitude(_ a: Double, b: Double, c: Double, d: Double) -> Bool {
        // convert longitudes to abstract coords relative to a
        let da = 0.0
        let db = longitude_minusf(b, minus: a)
        let dc = longitude_minusf(c, minus: a)
        let dd = longitude_minusf(d, minus: a)
        
        return contains_latitude(da, b: db, c: dc, d: dd)
    }
    
    class func map_inside(_ maplata: Double, maplatmid: Double, maplatb: Double,
                          maplonga: Double, maplongmid: Double, maplongb: Double,
                          lat_circle: Double, long_circle: Double, radius: Double)
                    -> (Int, Double)
    {

        // from http://stackoverflow.com/questions/401847/circle-rectangle-collision-detection-intersection
        // Find the closest point to the circle within the rectangle
        
        let closest_long = clamp_long(long_circle, a: maplonga, b: maplongb);
        let closest_lat = clamp_lat(lat_circle, a: maplata, b: maplatb);
        let db = harvesine(closest_lat, lat2: lat_circle,
                           long1: closest_long, long2: long_circle)
        
        // also find the distance from circle center to map center, for prioritization purposes
        
        let dc = harvesine(maplatmid, lat2: lat_circle,
                           long1: maplongmid, long2: long_circle)
        
        if db > radius {
            // no intersection
            return (0, dc)
        } else if db > 0 {
            // intersects but not completely enclosed by map
            return (1, dc)
        }
        
        // is the circle completely enclosed by map?
        let (lat0_circle, lat1_circle, long0_circle, long1_circle) =
            GPSModel2.enclosing_box(lat_circle, clong: long_circle, radius: radius)
        
        if contains_latitude(lat0_circle, b: lat1_circle, c: maplata, d: maplatb) &&
            contains_longitude(long0_circle, b: long1_circle, c: maplonga, d: maplongb) {
            // box enclosed in map
            return (2, dc)
        }
        
        return (1, dc)
    }
    
    class func enclosing_box(_ clat: Double, clong: Double, radius: Double)
                    -> (Double, Double, Double, Double) {
        let radius_lat = radius / 1853.0 / 60.0
        let radius_long = radius_lat / longitude_proportion(clat)
        let lat0_circle = clat - radius_lat
        let lat1_circle = clat + radius_lat
        let long0_circle = handle_cross_180f(clong - radius_long)
        let long1_circle = handle_cross_180f(clong + radius_long)
        
        return (lat0_circle, lat1_circle, long0_circle, long1_circle)
    }
    
    class func do_format_heading(_ n: Double) -> String
    {
        if n != n {
            return ""
        }
        return String(format: "%.0f°", n);
    }

    class func format_deg(_ p: Double) -> String
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
    
    class func format_deg2(_ p: Double) -> String
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
    
    class func format_deg_t(_ p: Double) -> String
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
    
    
    class func format_latitude_t(_ lat: Double) -> String
    {
        if lat != lat {
            return "---";
        }
        let suffix = (lat < 0 ? "S" : "N");
        return String(format: "%@%@", format_deg_t(fabs(lat)), suffix);
    }
    
    class func format_longitude_t(_ lo: Double) -> String
    {
        if lo != lo {
            return "---";
        }
        let suffix = (lo < 0 ? "W" : "E");
        return String(format: "%@%@", format_deg_t(fabs(lo)), suffix);
    }
    
    class func format_heading_t(_ course: Double) -> String
    {
        if course != course {
            return "---";
        }
        return do_format_heading(course);
    }
    
    class func format_heading_delta_t (_ course: Double) -> String
    {
        if course != course {
            return "---";
        }
        
        let plus = course > 0 ? "+" : "";
        return String(format: "%@%@", plus, do_format_heading(course));
    }
    
    class func format_altitude_t(_ alt: Double) -> String
    {
        if alt != alt {
            return "---";
        }
        return String(format: "%.0f", alt);
    }

    class func do_format_latitude(_ lat: Double) -> String
    {
        if lat != lat {
            return "---";
        }
        let suffix = lat < 0 ? "S" : "N";
        return String(format: "%@%@", format_deg(fabs(lat)), suffix);
    }

    class func do_format_latitude_full(_ lat: Double) -> String
    {
        if lat != lat {
            return "---";
        }
        let suffix = lat < 0 ? "S" : "N";
        return String(format: "%@%@%@", format_deg(fabs(lat)), format_deg2(fabs(lat)), suffix);
    }

    class func do_format_latitude2(_ lat: Double) -> String
    {
        if lat != lat {
            return "---";
        }
        return String(format: "%@", format_deg2(fabs(lat)));
    }

    class func do_format_longitude(_ lon: Double) -> String
    {
        if lon != lon {
            return "---";
        }
        let suffix = lon < 0 ? "W" : "E";
        return String(format: "%@%@", format_deg(fabs(lon)), suffix);
    }

    class func do_format_longitude_full(_ lon: Double) -> String
    {
        if lon != lon {
            return "---";
        }
        let suffix = lon < 0 ? "W" : "E";
        return String(format: "%@%@%@", format_deg(fabs(lon)), format_deg2(fabs(lon)), suffix);
    }
    

    class func do_format_longitude2(_ lon: Double) -> String
    {
        if lon != lon {
            return "---";
        }
        return String(format: "%@", format_deg2(fabs(lon)));
    }
    
    class func do_format_altitude(_ p: Double, met: Int) -> String
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
    
    class func format_distance_t(_ p: Double, met: Int) -> String
    {
        var dst = p;
        if dst != dst {
            return "---";
        }
        
        let f = NumberFormatter();
        f.numberStyle = .decimal;
        f.maximumFractionDigits = 0;
        f.roundingMode = .halfEven;
        
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
        
        return String(format: "%d%@",
            Int(dst),
            (met != 0 ? m : i));
    }
    
    class func do_format_speed(_ p: Double, met: Int) -> String
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
    
    class func do_format_accuracy(_ h: Double, vertical v: Double, met: Int) -> String
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
    
    class func harvesine(_ lat1: Double, lat2: Double, long1: Double, long2: Double) -> Double
    {
        // http://www.movable-type.co.uk/scripts/latlong.html
        
        if lat1 == lat2 && long1 == long2 {
            // avoid a non-zero result due to FP limitations
            return 0;
        }
        
        let R = 6371000.0; // metres
        let phi1 = lat1 * .pi / 180.0;
        let phi2 = lat2 * .pi / 180.0;
        let deltaphi = (lat2-lat1) * .pi / 180.0;
        let deltalambda = (long2-long1) * .pi / 180.0;
        
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
    class func longitude_proportion(_ lat: Double) -> Double
    {
        return cos(abs(lat) * .pi / 180.0)
    }

    class func longitude_proportion_cgfloat(_ lat: CGFloat) -> CGFloat
    {
        return CGFloat(longitude_proportion(Double(lat)))
    }
    
    class func azimuth(_ lat1: Double, lat2: Double, long1: Double, long2: Double) -> Double
    {
        let phi1 = lat1 * .pi / 180.0;
        let phi2 = lat2 * .pi / 180.0;
        let lambda1 = long1 * .pi / 180.0;
        let lambda2 = long2 * .pi / 180.0;
        
        let y = sin(lambda2-lambda1) * cos(phi2);
        let x = cos(phi1) * sin(phi2) -
            sin(phi1) * cos(phi2) * cos(lambda2 - lambda1);
        var brng = atan2(y, x) * 180.0 / .pi;
        if brng < 0 {
            brng += 360.0;
        }
        return brng;
    }
    
    
    class func parse_latz(_ lat: String) -> Double
    {
        return parse_coordz(lat, latitude: true);
    }
    
    class func parse_longz(_ lo: String) -> Double
    {
        return parse_coordz(lo, latitude: false);
    }
    
    
    class func parse_coordz(_ c: String, latitude is_lat: Bool) -> Double
    {
        var value: Double = 0.0 / 0.0;
        var deg: Int = 0
        var min: Int = 0
        var sec: Int = 0
        var cent: Int = 0
        let coord = c.uppercased();
        
        let s = Scanner(string: coord);
        s.charactersToBeSkipped = CharacterSet(charactersIn: ". ;,:/");
        
        if !s.scanInt(&deg) {
            NSLog("Did not find degree in %@", coord);
            return value;
        }
        
        if deg < 0 || deg > 179 || (is_lat && deg > 89) {
            NSLog("Invalid deg %ld", deg);
            return value;
        }
        
        var bt = s.scanLocation;
        if s.scanInt(&min) {
            if min < 0 || min > 59 {
                NSLog("Invalid minute %ld", min);
                return value;
            }
            bt = s.scanLocation;
            if s.scanInt(&sec) {
                if sec < 0 || sec > 59 {
                    NSLog("Invalid second %ld", sec);
                    return value;
                }
                bt = s.scanLocation;
                if s.scanInt(&cent) {
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
        if !s.scanUpTo("FOOBAR", into: &cardinal) {
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

    func latitude() -> Double
    {
        return self.curloc != nil ? (self.curloc!.coordinate.latitude) : Double.nan
    }

    func longitude() -> Double
    {
        return self.curloc != nil ? (self.curloc!.coordinate.longitude) : Double.nan
    }
    
    func speed() -> Double {
        return self.curloc != nil ? (self.curloc!.speed < 0 ? Double.nan : self.curloc!.speed) : Double.nan
    }
    
    func horizontal_accuracy() -> Double
    {
        return self.curloc != nil ? (self.curloc!.horizontalAccuracy) : Double.nan
    }
    
    func vertical_accuracy() -> Double
    {
        return self.curloc != nil ? (self.curloc!.verticalAccuracy) : Double.nan
    }
    
    func heading() -> Double
    {
        return self.curloc != nil ? (self.curloc!.course >= 0 ? self.curloc!.course : Double.nan) : Double.nan
    }
    
    func altitude() -> Double {
        return self.curloc != nil ? (self.curloc!.altitude) : Double.nan
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation])
    {
        if let location = locations.last {
            if self.held {
                self.curloc_new = location
            } else {
                self.curloc = location
                self.update()
            }
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
    
    func target_index(_ name: String) -> Int
    {
        for i in 0..<target_list.count {
            if (names[target_list[i]] as! String) == name {
                return i;
            }
        }
        return -1;
    }
    
    func target_name(_ index: Int) -> String
    {
        if index < 0 || index >= target_list.count {
            return "Here";
        }
        return names[target_list[index]] as! String;
    }

    func target_altitude(_ index: Int) -> Double
    {
        if index < 0 || index >= target_list.count {
            return Double.nan;
        }
        
        let alt = alts[target_list[index]] as! Double;
        if (alt == 0) {
            return Double.nan;
        }
        
        return -(altitude() - alt);
    }

    func target_altitude_formatted(_ index: Int) -> String
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
    
    func target_altitude_input_formatted(_ index: Int) -> String
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
    
    func target_latitude(_ index: Int) -> Double
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
   
    func target_latitude_formatted(_ index: Int) -> String
    {
        return GPSModel2.format_latitude_t(self.target_latitude(index));
    }

    func target_longitude(_ index: Int) -> Double
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

    func target_longitude_formatted(_ index: Int) -> String
    {
        return GPSModel2.format_longitude_t(self.target_longitude(index));
    }
    
    func target_calc_heading(_ index: Int) -> Double
    {
        if index < 0 || index >= target_list.count {
            return Double.nan;
        }
        
        let lat1 = self.latitude();
        let long1 = self.longitude();
        
        if lat1 != lat1 || long1 != long1 {
            return Double.nan
        }
        
        let key = target_list[index];
        let lat2 = lats[key] as! Double;
        let long2 = longs[key] as! Double;
        
        return GPSModel2.azimuth(lat1, lat2: lat2, long1: long1, long2: long2);
    }
    
    func target_heading(_ index: Int) -> Double
    {
        if index < 0 || index >= target_list.count {
            return Double.nan;
        }
        
        let key = target_list[index]
        
        if let d = theadings[key] {
            return d
        }
        
        return Double.nan
    }

    func target_heading_formatted(_ index: Int) -> String
    {
        return GPSModel2.format_heading_t(self.target_heading(index));
    }
    
    func calc_heading_delta(_ tgt_heading: Double, cur_heading: Double) -> Double
    {
        if tgt_heading != tgt_heading {
            return Double.nan
        }
        
        if cur_heading < 0 || cur_heading != cur_heading {
            return Double.nan
        }
        
        var delta = tgt_heading - cur_heading
        if delta <= -180 {
            delta += 360
        } else if delta >= 180 {
            delta -= 360
        }
        return delta;
    }

    /*
    func target_heading_delta_formatted(index: Int) -> String
    {
        return GPSModel2.format_heading_delta_t(target_heading_delta(index));
    }
    */
    
    func target_calc_distance(_ index: Int) -> Double
    {
        if index < 0 || index >= target_list.count {
            return Double.nan;
        }
        
        let lat1 = latitude()
        let long1 = longitude()
        
        if lat1 != lat1 || long1 != long1 {
            return Double.nan
        }
        
        let key = target_list[index];
        let lat2 = lats[key] as! Double;
        let long2 = longs[key] as! Double;
        
        return GPSModel2.harvesine(lat1, lat2: lat2, long1: long1, long2: long2);
    }
    
    func target_distance(_ index: Int) -> Double
    {
        if index < 0 || index >= target_list.count {
            return Double.nan;
        }

        let key = target_list[index]
        
        if let d = tdistances[key] {
            return d
        }
        
        return Double.nan
    }
    
    func target_distance_formatted(_ index: Int) -> String
    {
        return GPSModel2.format_distance_t(target_distance(index), met: metric);
    }
    
    func target_set(_ pindex: Int, nam: String, latitude: String, longitude: String, altitude: String) -> String?
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
            return "Longitude is invalid.";
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
    
    func target_delete(_ index: Int)
    {
        if index < 0 || index >= target_list.count {
            return;
        }
        let key = target_list[index];
        names.removeValue(forKey: key);
        lats.removeValue(forKey: key);
        longs.removeValue(forKey: key);
        alts.removeValue(forKey: key);

        saveTargets();
        update();
    }
    
    func saveTargets()
    {
        updateTargetList();
        let prefs = UserDefaults.standard;
        prefs.set(names, forKey: "names");
        prefs.set(lats, forKey: "lats");
        prefs.set(longs, forKey: "longs");
        prefs.set(alts, forKey: "alts");
        prefs.set(next_target, forKey: "next_target");
    }
    
    func update()
    {
        let cur_heading = heading()
        for i in 0..<target_list.count {
            let tgtname = target_list[i]
            tdistances[tgtname] = target_calc_distance(i)
            theadings[tgtname] = target_calc_heading(i)
            trelheadings[tgtname] = calc_heading_delta(theadings[tgtname]!,
                                                    cur_heading: cur_heading)
        }
        process_target_alarms()
        
        for observer in observers {
            observer.update()
        }
    }
    
    func process_target_alarms()
    {
        for i in 0..<target_list.count {
            let tgtname = target_list[i]
            let cur = tdistances[tgtname]!
            let rel_heading = trelheadings[tgtname]!
            if current_target != i || beep != 1 || cur != cur {
                // does nothing
            } else if let last = tlastdistances[tgtname] {
                if last == last {
                    // last distance is known
                    process_alarm(last, cur: cur)
                }
                if rel_heading == rel_heading {
                    process_sidepass(abs(rel_heading), distance: cur)
                }
            }
            tlastdistances[tgtname] = tdistances[tgtname]
        }
    }
    
    func process_sidepass(_ abs_rel_angle: Double, distance: Double)
    {
        // cone of warning that we are leaving a target sideways
        var fudge = 15.0
        
        // decrease the cone when it is very far
        if distance > 1500.0 {
            fudge *= 1500.0 / distance
        }

        // NSLog("Rel tgt az %.0f dst %.0f fudge %.0f", abs_rel_angle, distance, fudge)
        
        if abs_rel_angle > (90.0 - fudge) && abs_rel_angle < (90.0 + fudge) {
            if last_side_played != nil {
                if Date().compare(last_side_played!) == .orderedAscending {
                    return
                }
            }
            wav_side!.play()
            last_side_played = Date().addingTimeInterval(3)
        }
    }
    
    func process_alarm(_ last: Double, cur: Double)
    {
        var rnd = 1000.0
        if cur < 100 {
            rnd = 10.0
        } else if cur < 10000 {
            rnd = 100.0
        }
        let barrier = round((last + cur) / 2.0 / rnd) * rnd
        
        if last > barrier && cur < barrier {
            wav_hi!.play()
        } else if cur > barrier && last < barrier {
            wav_lo!.play()
        }
    }

    func target_getEdit() -> Int
    {
        return editing;
    }
    
    func target_setEdit(_ index: Int)
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
            let prefs = UserDefaults.standard;
            prefs.set(alts, forKey: "alts");
        }
    }

    func get_altitude_unit() -> String
    {
        return (get_metric() != 0) ? "m" : "ft"
    }
    
    /* Asking a dummy parameter reduces de risk of inadvertent non-singleton
       instantiation */
    init(_: Int)
    {
        super.init()
        
        do {
            if #available(iOS 10.0, *) {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            } else {
                // Fallback on earlier versions
            }
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print(error)
        }
        
        self.wav_hi = try? AVAudioPlayer(contentsOf: fwav_hi, fileTypeHint: nil)
        self.wav_lo = try? AVAudioPlayer(contentsOf: fwav_lo, fileTypeHint: nil)
        self.wav_side = try? AVAudioPlayer(contentsOf: fwav_side, fileTypeHint: nil)
        self.wav_hi!.prepareToPlay()
        self.wav_lo!.prepareToPlay()
        self.wav_side!.prepareToPlay()
        
        let prefs = UserDefaults.standard;
        
        prefs.register(defaults: ["metric": 1,
            "beep": 1,
            "next_target": 3,
            "mode": 1, // MAPCOMPASS
            "tgt_dist": 1,
            "welcome": 0,
            "blink": 1,
            "current_target": -1,
            "zoom": 0.0,
            "names": ["1": "Joinville", "2": "Blumenau"],
            "lats": ["1": GPSModel2.parse_latz("26.18.19.50S"),
                "2": GPSModel2.parse_latz("26.54.46.10S")],
            "longs": ["1": GPSModel2.parse_longz("48.50.44.44W"),
                "2": GPSModel2.parse_longz("49.04.04.47W")],
            "alts": ["2": 50.0],
            ])
        
        names = prefs.dictionary(forKey: "names")!
        lats = prefs.dictionary(forKey: "lats")!
        longs = prefs.dictionary(forKey: "longs")!
        alts = prefs.dictionary(forKey: "alts")!
        mode = prefs.integer(forKey: "mode")
        tgt_dist = prefs.integer(forKey: "tgt_dist")
        current_target = prefs.integer(forKey: "current_target")
        zoom = prefs.double(forKey: "zoom")
        welcome = prefs.integer(forKey: "welcome")
        blink = prefs.integer(forKey: "blink")
        
        self.updateTargetList()
        self.upgradeAltitudes()
        
        metric = prefs.integer(forKey: "metric")
        beep = prefs.integer(forKey: "beep")
        next_target = prefs.integer(forKey: "next_target")
        curloc = nil
        
        lman = CLLocationManager()
        lman!.delegate = self
        lman!.distanceFilter = kCLDistanceFilterNone
        lman!.desiredAccuracy = kCLLocationAccuracyBest
        lman!.requestWhenInUseAuthorization()
        lman!.startUpdatingLocation()
        
        let notifications = NotificationCenter.default
        prefsObserver = notifications.addObserver(forName: UserDefaults.didChangeNotification,
                                object: UserDefaults.standard,
                                queue: OperationQueue.main,
                                using: { [unowned self] (notification : Notification!) -> Void in
                                    self.prefs_changed()
                                }
        )
    }
    
    func show_welcome() -> Bool {
        if welcome == 0 {
            welcome = 1;
            let prefs = UserDefaults.standard;
            prefs.set(welcome, forKey: "welcome");
            return true;
        }
        return false;
    }
    
    func get_mode() -> Int {
        return mode
    }
    
    func set_mode(_ new_mode: Int) {
        self.mode = new_mode
        let prefs = UserDefaults.standard;
        prefs.set(self.mode, forKey: "mode");
    }
    
    func get_tgtdist() -> Int {
        return tgt_dist
    }
    
    func set_tgtdist(_ new_tgtdist: Int) {
        self.tgt_dist = new_tgtdist
        let prefs = UserDefaults.standard;
        prefs.set(self.tgt_dist, forKey: "tgt_dist");
    }
    
    func get_blink() -> Int {
        return blink
    }
    
    func set_blink(_ new_blink: Int) {
        self.blink = new_blink
        let prefs = UserDefaults.standard;
        prefs.set(self.blink, forKey: "blink");
    }
   
    func get_currenttarget() -> Int {
        return current_target
    }
    
    func set_currenttarget(_ new_currenttarget: Int) {
        self.current_target = new_currenttarget
        let prefs = UserDefaults.standard;
        prefs.set(self.current_target, forKey: "current_target");
    }
    
    func get_zoom() -> Double {
        return zoom
    }
    
    func set_zoom(_ new_zoom: Double) {
        self.zoom = new_zoom
        let prefs = UserDefaults.standard;
        prefs.set(self.zoom, forKey: "zoom");
    }
    
    deinit {
        let notifications = NotificationCenter.default
        notifications.removeObserver(prefsObserver!,
                                     name: UserDefaults.didChangeNotification,
                                     object: nil)
    }
    
    func prefs_changed()
    {
        let prefs = UserDefaults.standard;
        metric = prefs.integer(forKey: "metric")
        beep = prefs.integer(forKey: "beep")
    }
    
    static let singleton = GPSModel2(1);
    
    class func model() -> GPSModel2
    {
        return singleton
    }
    
    func updateTargetList()
    {
        target_list = GPSModel2.array_adapter(Array(names.keys) as Array<NSObject>);
        target_list = target_list.sorted(by: {$0.localizedCaseInsensitiveCompare($1) ==
            .orderedAscending});
        NSLog("Number of targets: %ld", target_list.count);
    }
    
    func get_metric() -> Int
    {
        return metric;
    }
    
    func index_of_listener(_ haystack: [ModelListener], needle: ModelListener) -> Int
    {
        for i in 0..<haystack.count {
            if haystack[i] === needle {
                return i;
            }
        }
        return -1;
    }
    
    func contains(_ haystack: [ModelListener], needle: ModelListener) -> Bool
    {
        return index_of_listener(haystack, needle: needle) >= 0;
    }
    
    func addObs(_ observer: ModelListener)
    {
        if !contains(observers, needle: observer) {
            observers.append(observer);
            NSLog("Added observer %@", observer as! NSObject);
        }
        self.update();
    }
    
    func delObs(_ observer: ModelListener)
    {
        while contains(observers, needle: observer) {
            NSLog("Removed observer %@", observer as! NSObject);
            let i = index_of_listener(observers, needle: observer);
            observers.remove(at: i);
        }
    }
    
    // Failed to get current location
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        if held {
            self.curloc_new = nil
        } else {
            self.curloc = nil
        }
        
        for observer in observers {
            observer.fail();
        }
        
        if error._code == CLError.Code.denied.rawValue {
            for observer in observers {
                observer.permission();
            }
            lman!.stopUpdatingLocation();
        }
    }
    
    func locationManager(_ manager :CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
    {
        lman!.startUpdatingLocation()
    }
    
    func read_targets(_ url: URL)
    {
        var data = ""
        
        do {
            data = try String(contentsOf: url, encoding: String.Encoding.utf8)
        } catch {
            NSLog("Could not read target file " + url.absoluteString)
            return
        }
        
        let lines = data.components(separatedBy: .newlines)
        for line in lines {
            read_target(line);
        }
        
        do {
            try FileManager.default.removeItem(at: url)
            NSLog("Target file removed")
        } catch {
            NSLog("Could not remove target file " + url.absoluteString)
        }
    }
    
    func read_target(_ data: String)
    {
        let tokens = data.replacingOccurrences(of: "\t", with: " ")
                    .components(separatedBy: .whitespacesAndNewlines)
        if tokens.count <= 0 || data.count <= 0 {
            return
        }
        NSLog("target data: " + data)
        if tokens.count < 3 {
            NSLog("not enough tokens")
            return
        }
        var name = tokens[0]
        let latitude = tokens[1]
        let longitude = tokens[2]
        var altitude = ""
        if tokens.count > 3 {
            altitude = tokens[3]
        }
        if name.count > 15 {
            let i = name.index(name.startIndex, offsetBy: 15)
            name = String(name[..<i])
        }
        
        let err = target_set(target_index(name), nam: name, latitude: latitude,
                             longitude: longitude, altitude: altitude)
        if err != nil {
            NSLog("error: " + err!)
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}

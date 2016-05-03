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
    var names = [NSObject: AnyObject]()
    var lats = [NSObject: AnyObject]()
    var longs = [NSObject: AnyObject]()
    var alts = [NSObject: AnyObject]()
    var tdistances = [String: Double]()
    var tlastdistances = [String: Double]()
    var theadings = [String: Double]()
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
    
    var fwav_hi = NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("1000", ofType: "wav")!)
    var fwav_lo = NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("670", ofType: "wav")!)
    var wav_hi: AVAudioPlayer? = nil
    var wav_lo: AVAudioPlayer? = nil
    
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
    class func handle_cross_180(c: CGFloat) -> CGFloat
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
    class func handle_cross_180f(x: Double) -> Double
    {
        return Double(handle_cross_180(CGFloat(x)))
    }
    
    // Makes a - b taking into consideration the international date line
    class func longitude_minus(a: CGFloat, minus: CGFloat) -> CGFloat
    {
        let c = a - minus
        // a difference above 180 degrees can be handled in the same
        // fashion as an absolute longitude (proof: make minus = 0)
        return handle_cross_180(c)
    }
    
    class func longitude_minusf(a: Double, minus: Double) -> Double
    {
        return Double(longitude_minus(CGFloat(a), minus: CGFloat(minus)))
    }

    // checks whether a coordinate is inside a circle
    class func inside(lat: Double, long: Double, lat_circle: Double, long_circle: Double, radius: Double) -> Bool
    {
        return harvesine(lat, lat2: lat_circle, long1: long, long2: long_circle) <= radius
    }

    // helper function for map_inside()
    class func clamp_lat(x: Double, a: Double, b: Double) -> Double
    {
        let (mini, maxi) = (min(a, b), max(a, b))
        return max(mini, min(maxi, x))
    }

    // helper function for map_inside()
    class func clamp_long(x: Double, a: Double, b: Double) -> Double
    {
        // convert longitudes to relative coordinates (as if a = 0)
        let db = longitude_minusf(b, minus: a)
        let da = 0.0
        let dx = longitude_minusf(x, minus: a)
        
        let dres = clamp_lat(dx, a: da, b: db)
        
        // convert back to absolute longitude
        return handle_cross_180f(dres + a)
    }
    
    class func contains_latitude(a: Double, b: Double, c: Double, d: Double) -> Bool {
        let (_a, _b) = (min(a, b), max(a, b))
        let (_c, _d) = (min(c, d), max(c, d))
        return (_a + 0.0001) >= _c && (_b - 0.0001) <= _d
    }

    class func contains_longitude(a: Double, b: Double, c: Double, d: Double) -> Bool {
        // convert longitudes to abstract coords relative to a
        let da = 0.0
        let db = longitude_minusf(b, minus: a)
        let dc = longitude_minusf(c, minus: a)
        let dd = longitude_minusf(d, minus: a)
        
        return contains_latitude(da, b: db, c: dc, d: dd)
    }
    
    class func map_inside(maplata: Double, maplatmid: Double, maplatb: Double,
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
    
    class func enclosing_box(clat: Double, clong: Double, radius: Double)
                    -> (Double, Double, Double, Double) {
        let radius_lat = radius / 1853.0 / 60.0
        let radius_long = radius_lat / longitude_proportion(clat)
        let lat0_circle = clat - radius_lat
        let lat1_circle = clat + radius_lat
        let long0_circle = handle_cross_180f(clong - radius_long)
        let long1_circle = handle_cross_180f(clong + radius_long)
        
        return (lat0_circle, lat1_circle, long0_circle, long1_circle)
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
    
    func target_calc_heading(index: Int) -> Double
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
    
    func target_heading(index: Int) -> Double
    {
        if index < 0 || index >= target_list.count {
            return Double.NaN;
        }
        
        let key = target_list[index]
        
        if let d = theadings[key] {
            return d
        }
        
        return Double.NaN
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
    
    func target_calc_distance(index: Int) -> Double
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
    
    func target_distance(index: Int) -> Double
    {
        if index < 0 || index >= target_list.count {
            return Double.NaN;
        }

        let key = target_list[index]
        
        if let d = tdistances[key] {
            return d
        }
        
        return Double.NaN
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
        for i in 0..<target_list.count {
            let tgtname = target_list[i]
            tdistances[tgtname] = target_calc_distance(i)
            theadings[tgtname] = target_calc_heading(i)
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
            if current_target != i || beep != 1 || cur != cur {
                // does nothing
            } else if let last = tlastdistances[tgtname] {
                if last == last {
                    // last distance is known
                    process_alarm(last, cur: cur)
                }
            }
            tlastdistances[tgtname] = tdistances[tgtname]
        }
    }
    
    func process_alarm(last: Double, cur: Double)
    {
        let min = 1853.0
        let sec = min / 60
        
        // FIXME remove
        NSLog("Target beep %.0f -> %.0f", last, cur)
        
        if last > min * 3 && cur < min * 3 ||
                last > min && cur < min ||
                last > 30 * sec && cur < 30 * sec ||
                last > 15 * sec && cur < 15 * sec ||
                last > 5 * sec && cur < 5 * sec ||
                last > 3 * sec && cur < 3 * sec ||
                last > 2 * sec && cur < 2 * sec ||
                last > 1 * sec && cur < 1 * sec {
            wav_hi!.play()
        }

        if cur > min * 3 && last < min * 3 ||
            cur > min && last < min ||
            cur > 30 * sec && last < 30 * sec ||
            cur > 15 * sec && last < 15 * sec ||
            cur > 5 * sec && last < 5 * sec ||
            cur > 3 * sec && last < 3 * sec ||
            cur > 2 * sec && last < 2 * sec ||
            cur > 1 * sec && last < 1 * sec {
            wav_lo!.play()
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
    
    /* Asking a dummy parameter reduces de risk of inadvertent non-singleton
       instantiation */
    init(_: Int)
    {
        super.init()
        
        self.wav_hi = try? AVAudioPlayer(contentsOfURL: fwav_hi, fileTypeHint: nil)
        self.wav_lo = try? AVAudioPlayer(contentsOfURL: fwav_lo, fileTypeHint: nil)
        self.wav_hi!.prepareToPlay()
        self.wav_lo!.prepareToPlay()
        
        let prefs = NSUserDefaults.standardUserDefaults();
        
        prefs.registerDefaults(["metric": 1,
            "beep": 1,
            "next_target": 3,
            "mode": 1, // MAPCOMPASS
            "tgt_dist": 1,
            "welcome": 0,
            "current_target": -1,
            "zoom": 0.0,
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
        mode = prefs.integerForKey("mode")
        tgt_dist = prefs.integerForKey("tgt_dist")
        current_target = prefs.integerForKey("current_target")
        zoom = prefs.doubleForKey("zoom")
        welcome = prefs.integerForKey("welcome")
        
        self.updateTargetList()
        self.upgradeAltitudes()
        
        metric = prefs.integerForKey("metric")
        beep = prefs.integerForKey("beep")
        next_target = prefs.integerForKey("next_target")
        curloc = nil
        
        lman = CLLocationManager()
        lman!.delegate = self
        lman!.distanceFilter = kCLDistanceFilterNone
        lman!.desiredAccuracy = kCLLocationAccuracyBest
        lman!.requestAlwaysAuthorization()
        lman!.startUpdatingLocation()
        
        let notifications = NSNotificationCenter.defaultCenter()
        prefsObserver = notifications.addObserverForName(NSUserDefaultsDidChangeNotification,
                                object: nil,
                                queue: NSOperationQueue.mainQueue(),
                                usingBlock: { [unowned self] (notification : NSNotification!) -> Void in
                                    self.prefs_changed()
                                }
        )
    }
    
    func show_welcome() -> Bool {
        if welcome == 0 {
            welcome = 1;
            let prefs = NSUserDefaults.standardUserDefaults();
            prefs.setInteger(welcome, forKey: "welcome");
            return true;
        }
        return false;
    }
    
    func get_mode() -> Int {
        return mode
    }
    
    func set_mode(new_mode: Int) {
        self.mode = new_mode
        let prefs = NSUserDefaults.standardUserDefaults();
        prefs.setObject(self.mode, forKey: "mode");
    }
    
    func get_tgtdist() -> Int {
        return tgt_dist
    }
    
    func set_tgtdist(new_tgtdist: Int) {
        self.tgt_dist = new_tgtdist
        let prefs = NSUserDefaults.standardUserDefaults();
        prefs.setObject(self.tgt_dist, forKey: "tgt_dist");
    }
   
    func get_currenttarget() -> Int {
        return current_target
    }
    
    func set_currenttarget(new_currenttarget: Int) {
        self.current_target = new_currenttarget
        let prefs = NSUserDefaults.standardUserDefaults();
        prefs.setObject(self.current_target, forKey: "current_target");
    }
    
    func get_zoom() -> Double {
        return zoom
    }
    
    func set_zoom(new_zoom: Double) {
        self.zoom = new_zoom
        let prefs = NSUserDefaults.standardUserDefaults();
        prefs.setObject(self.zoom, forKey: "zoom");
    }
    
    deinit {
        let notifications = NSNotificationCenter.defaultCenter()
        notifications.removeObserver(prefsObserver, name: NSUserDefaultsDidChangeNotification, object: nil)
    }
    
    func prefs_changed()
    {
        let prefs = NSUserDefaults.standardUserDefaults();
        metric = prefs.integerForKey("metric")
        beep = prefs.integerForKey("beep")
    }
    
    static let singleton = GPSModel2(1);
    
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
}

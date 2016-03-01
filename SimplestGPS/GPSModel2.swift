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

@objc class GPSModel2: NSObject, CLLocationManagerDelegate {
    var observers = [ModelListener]()
    var names = [NSObject: AnyObject]()
    var lats = [NSObject: AnyObject]()
    var longs = [NSObject: AnyObject]()
    var alts = [NSObject: AnyObject]()
    var target_list = [String]()
    var next_target: Int = 0
    var current: CLLocation? = nil
    var lman: CLLocationManager? = nil
    var metric: Int = 1;
    var editing: Int = -1
    
    var maps: [(file: NSURL, lat0: Double, lat1: Double, long0: Double, long1: Double, latheight: Double, longwidth: Double)] = [];
    var mapimages: [String: UIImage] = [:]
    
    override init()
    {
        super.init()
        
        let prefs = NSUserDefaults.standardUserDefaults();
        
        prefs.registerDefaults(["metric": 1, "next_target": 3,
            "names": ["1": "Joinville, Brazil", "2": "Blumenau, Brazil"],
            "lats": ["1": GPSModel2.parse_lat("26.18.19.50S"),
                     "2": GPSModel2.parse_lat("26.54.46.10S")],
            "longs": ["1": GPSModel2.parse_long("48.50.44.44W"),
                      "2": GPSModel2.parse_long("49.04.04.47W")],
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
        current = nil
        
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
                let coords = parseName(f)
                if !coords.ok {
                    continue
                }
                NSLog("   %@ map coords %f %f %f %f", url.absoluteString, coords.lat, coords.long, coords.latheight, coords.longwidth)
                maps.append((file: url, lat0: coords.lat, lat1: coords.lat - coords.latheight,
                        long0: coords.long, long1: coords.long + coords.longwidth,
                        latheight: coords.latheight, longwidth: coords.longwidth))
            }
        }
    }
    
    func get_map_image(url: NSURL) -> UIImage?
    {
        let name = url.absoluteString
        if let img = mapimages[name] {
            // NSLog("Image cached")
            return img
        }
        if let img = UIImage(data: NSData(contentsOfURL: url)!) {
            NSLog("Image %@ loaded", name)
            mapimages[name] = img
            return img
        }
        
        NSLog("Image %@ NOT LOADED", name)
        // remove map from list, so it is no longer requested
        maps = maps.filter() {$0.file.absoluteString == name}
        return nil
    }

    func parseName(f: String) -> (ok: Bool, lat: Double, long: Double, latheight: Double, longwidth: Double)
    {
        NSLog("Parsing %@", f)
        var lat = 1.0
        var long = 1.0
        var latheight = 0.0
        var longwidth = 0.0
        
        let e = f.lowercaseString
        let g = (e.characters.split(".").map{ String($0) }).first!
        var h = (g.characters.split("+").map{ String($0) })
        
        if h.count != 4 {
            NSLog("    did not find 4 tokens")
            return (false, 0, 0, 0, 0)
        }
        if h[0].characters.count < 4 || h[0].characters.count > 6 {
            NSLog("    latitude with <3 or >5 chars")
            return (false, 0, 0, 0, 0)
        }
        
        if h[1].characters.count < 4 || h[1].characters.count > 6 {
            NSLog("    latitude with <3 or >5 chars")
            return (false, 0, 0, 0, 0)
        }
        if h[2].characters.count < 2 || h[2].characters.count > 4 {
            NSLog("    latheight with <3 or >4 chars")
            return (false, 0, 0, 0, 0)
        }
        if h[3].characters.count < 2 || h[3].characters.count > 4 {
            NSLog("    longwidth with <3 or >4 chars")
            return (false, 0, 0, 0, 0)
        }
        
        let ns = h[0].characters.last
        
        if (ns != "n" && ns != "s") {
            NSLog("    latitude with no N or S suffix")
            return (false, 0, 0, 0, 0)
        }
        if (ns == "s") {
            lat = -1;
        }
        
        let ew = h[1].characters.last
        
        if (ew != "e" && ew != "w") {
            NSLog("    longitude with no W or E suffix")
            return (false, 0, 0, 0, 0)
        }
        if (ew == "w") {
            long = -1;
        }
        h[0] = h[0].substringToIndex(h[0].endIndex.predecessor())
        h[1] = h[1].substringToIndex(h[1].endIndex.predecessor())
        let ilat = Int(h[0])
        if (ilat == nil) {
            NSLog("    lat not parsable")
            return (false, 0, 0, 0, 0)
        }
        let ilong = Int(h[1])
        if (ilong == nil) {
            NSLog("    long not parsable")
            return (false, 0, 0, 0, 0)
        }
        let ilatheight = Int(h[2])
        if (ilatheight == nil) {
            NSLog("    latheight not parsable")
            return (false, 0, 0, 0, 0)
        }
        let ilongwidth = Int(h[3])
        if (ilongwidth == nil) {
            NSLog("    longwidth not parsable")
            return (false, 0, 0, 0, 0)
        }
        lat *= Double(ilat! / 100) + (Double(ilat! % 100) / 60.0)
        long *= Double(ilong! / 100) + (Double(ilong! % 100) / 60.0)
        latheight = Double(ilatheight! / 100) + (Double(ilatheight! % 100) / 60.0)
        longwidth = Double(ilongwidth! / 100) + (Double(ilongwidth! % 100) / 60.0)
        
        return (true, lat, long, latheight, longwidth)
    }
    
    static let singleton = GPSModel2();
    
    class func model() -> GPSModel2
    {
        return singleton
    }
    
    func get_maps() -> [(file: NSURL, lat0: Double, lat1: Double, long0: Double, long1: Double, latheight: Double, longwidth: Double)] {
        return [] + maps[0..<maps.count]
    }
    
    func sk(keys: Array<NSObject>) -> [String]
    {
        var ret = [String]();
        for k in keys {
            // exclamation point means: cast w/ abort if type is wrong
            ret.append(k as! String);
        }
        return ret;
    }
    
    func updateTargetList()
    {
        target_list = sk(Array(names.keys));
        target_list = target_list.sort({$0.localizedCaseInsensitiveCompare($1) ==
                .OrderedAscending});
        NSLog("Number of targets: %ld", target_list.count);
    }
    
    
    func set_metric(value: Int)
    {
        metric = value;
        let prefs = NSUserDefaults.standardUserDefaults();
        prefs.setInteger(metric, forKey: "metric");
        if current != nil {
            return;
        }
        self.update();
    }
    
    func get_metric() -> Int
    {
        return metric;
    }
    
    func idx(haystack: [ModelListener], needle: ModelListener) -> Int
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
        return idx(haystack, needle: needle) >= 0;
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
            let i = idx(observers, needle: observer);
            observers.removeAtIndex(i);
        }
    }
    
    // Failed to get current location
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError)
    {
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

    func do_format_heading(n: Double) -> String
    {
        return String(format: "%.0f°", n);
    }

    func format_deg(p: Double) -> String
    {
        var n: Double = p;
        let deg = Int(floor(n));
        n = (n - floor(n)) * 60;
        let minutes = Int(floor(n));
        return String(format: "%d°%02d'", deg, minutes);
    }
    
    func format_deg2(p: Double) -> String
    {
        var n: Double = p;
        n = (n - floor(n)) * 60;
        n = (n - floor(n)) * 60;
        let seconds = Int(floor(n));
        n = (n - floor(n)) * 100;
        let cents = Int(floor(n));
        return String( format: "%02d.%02d\"", seconds, cents);
    }
    
    func format_deg_t(p: Double) -> String
    {
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
    
    func latitude() -> Double
    {
        return self.current!.coordinate.latitude
    }

    func longitude() -> Double
    {
        return self.current!.coordinate.longitude
    }
    
    
    func format_latitude() -> String
    {
        if self.current == nil {
            return "";
        }
        return self.do_format_latitude(self.current!.coordinate.latitude);
    }
    
    func format_latitude_t(lat: Double) -> String
    {
        if lat != lat {
            return "---";
        }
        let suffix = (lat < 0 ? "S" : "N");
        return String(format: "%@%@", self.format_deg_t(fabs(lat)), suffix);
    }
    
    func format_longitude_t(lo: Double) -> String
    {
        if lo != lo {
            return "---";
        }
        let suffix = (lo < 0 ? "W" : "E");
        return String(format: "%@%@", self.format_deg_t(fabs(lo)), suffix);
    }

    func format_heading_t(course: Double) -> String
    {
        if course != course {
            return "---";
        }
        return self.do_format_heading(course);
    }
 
    func format_heading_delta_t (course: Double) -> String
    {
        if course != course {
            return "---";
        }
    
        let plus = course > 0 ? "+" : "";
        return String(format: "%@%@", plus, self.do_format_heading(course));
    }

    func format_altitude_t(alt: Double) -> String
    {
        if alt != alt {
            return "---";
        }
        return String(format: "%.0f", alt);
    }
    
    func format_heading() -> String
    {
        if self.current?.course >= 0 {
            return self.do_format_heading(self.current!.course);
        }
        return "";
    }
    
    func do_format_latitude(lat: Double) -> String
    {
        let suffix = lat < 0 ? "S" : "N";
        return String(format: "%@%@", format_deg(fabs(lat)), suffix);
    }
    
    func format_latitude2() -> String
    {
        if self.current == nil {
            return "";
        }
        return do_format_latitude2(self.current!.coordinate.latitude);
    }
    
    func do_format_latitude2(lat: Double) -> String
    {
        return String(format: "%@", self.format_deg2(fabs(lat)));
    }
    
    func format_longitude() -> String
    {
        if self.current == nil {
            return "";
        }
        return do_format_longitude(self.current!.coordinate.longitude);
    }
    
    func do_format_longitude(lon: Double) -> String
    {
        let suffix = lon < 0 ? "W" : "E";
        return String(format: "%@%@", format_deg(fabs(lon)), suffix);
    }
    
    func format_longitude2() -> String
    {
        if self.current == nil {
            return "";
        }
        return do_format_longitude2(self.current!.coordinate.longitude);
    }
    
    func do_format_longitude2(lon: Double) -> String
    {
        return String(format: "%@", format_deg2(fabs(lon)));
    }
    
    func format_altitude() -> String
    {
        if self.current == nil {
            return "";
        }
        return do_format_altitude(self.current!.altitude);
    }
    
    
    func do_format_altitude(p: Double) -> String
    {
        var alt: Double = p;
        if metric == 0 {
            alt *= 3.28084;
        }
    
        return String(format: "%.0f%@", alt, (metric != 0 ? "m" : "ft"));
    }
    
    func format_distance_t(p: Double) -> String
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
        if metric != 0 {
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
   
        return String(format: "%@%@", f.stringFromNumber(Int(dst))!, (metric != 0 ? m : i));
    }
    
    func format_speed() -> String
    {
        if self.current?.speed > 0 {
            return do_format_speed(self.current!.speed);
        }
        return "";
    }
    
    func do_format_speed(p: Double) -> String
    {
        var spd = p;

        if metric != 0 {
            spd *= 3.6;
        } else {
            spd *= 2.23693629;
        }
    
        return String(format: "%.0f%@", spd, (metric != 0 ? "km/h " : "mi/h "));
    }
    
    func format_accuracy() -> String
    {
        if self.current != nil {
            return do_format_accuracy(self.current!.horizontalAccuracy,
                vertical: self.current!.verticalAccuracy);
        }
        return "";
    }
    
    func do_format_accuracy(h: Double, vertical v: Double) -> String
    {
        if h > 10000 || v > 10000 {
            return "imprecise";
        }
        if v >= 0 {
            return String(format: "%@↔︎ %@↕︎", do_format_altitude(h), do_format_altitude(v));
        } else if h >= 0 {
            return String(format: "%@↔︎", do_format_altitude(h));
        } else {
            return "";
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateToLocation newLocation: CLLocation, fromLocation oldLocation: CLLocation)
    {
        self.current = newLocation;
        self.update();
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
    
    func target_faltitude(index: Int) -> String
    {
        if index < 0 || index >= target_list.count {
            NSLog("Index %ld out of range", index);
            return "ERR";
        }

        var dn = calculate_altitude_t(index);
        if dn != dn {
            return "";
        }
        
        if metric == 0 {
            dn *= 3.28084;
        }
        let esign = dn >= 0 ? "+": "";
        let sn = format_altitude_t(dn);
        let unit = metric != 0 ? "m" : "ft";
        return String(format: "%@%@%@", esign, sn, unit);
    }
    
    func target_faltitude_input(index: Int) -> String
    {
        var dn: Double;
        
        if index < 0 || index >= target_list.count {
            if self.current != nil {
                dn = self.current!.altitude;
            } else {
                return "";
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
        return format_altitude_t(dn);
    }
    
    func target_latitude(index: Int) -> Double
    {
        var n: Double;
        if index < 0 || index >= target_list.count {
            if self.current != nil {
                n = self.current!.coordinate.latitude;
            } else {
                return 0;
            }
        } else {
            n = lats[target_list[index]] as! Double;
        }
        return n;
    }
   
    func target_flatitude(index: Int) -> String
    {
        var n: Double;
        if index < 0 || index >= target_list.count {
            if self.current != nil {
                n = self.current!.coordinate.latitude;
            } else {
                return "";
            }
        } else {
            n = lats[target_list[index]] as! Double;
        }
        return format_latitude_t(n);
    }

    func target_longitude(index: Int) -> Double
    {
        var n: Double;
        if index < 0 || index >= target_list.count {
            if self.current != nil {
                n = self.current!.coordinate.longitude;
            } else {
                return 0;
            }
        } else {
            n = longs[target_list[index]] as! Double;
        }
        return n;
    }
    

    func target_flongitude(index: Int) -> String
    {
        var n: Double;
        if index < 0 || index >= target_list.count {
            if self.current != nil {
                n = self.current!.coordinate.longitude;
            } else {
                return "";
            }
        } else {
            n = longs[target_list[index]] as! Double;
        }
        return format_longitude_t(n);
    }
    
    func target_fdistance(index: Int) -> String
    {
        if index < 0 || index >= target_list.count {
            NSLog("Index %ld out of range", index);
            return "ERR";
        }
        return format_distance_t(calculate_distance_t(index));
    }
    
    func target_fheading(index: Int) -> String
    {
        if index < 0 || index >= target_list.count {
            NSLog("Index %ld out of range", index);
            return "ERR";
        }
        return format_heading_t(calculate_heading_t(index));
    }
    
    func target_fheading_delta(index: Int) -> String
    {
        if index < 0 || index >= target_list.count {
            NSLog("Index %ld out of range", index);
            return "ERR";
        }
        return format_heading_delta_t(calculate_heading_delta_t(index));
    }
    
    func harvesine(lat1: Double, lat2: Double, long1: Double, long2: Double) -> Double
    {
        // http://www.movable-type.co.uk/scripts/latlong.html
    
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
        return d;
    }
    
    /* Given a latitude, return the proportion of longitude distance
       e.g. 1 deg long / 1 deg lat (tends to 1.0 in tropics, to 0.0 in poles 
    */
    func longitude_proportion(lat: Double) -> Double
    {
        return cos(abs(lat) * M_PI / 180.0)
    }

    func azimuth(lat1: Double, lat2: Double, long1: Double, long2: Double) -> Double
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
    
    func calculate_distance_t(index: Int) -> Double
    {
        if self.current == nil || index < 0 || index >= target_list.count {
            return 0.0/0.0;
        }

        let lat1 = self.current!.coordinate.latitude;
        let long1 = self.current!.coordinate.longitude;
        let key = target_list[index];
        let lat2 = lats[key] as! Double;
        let long2 = longs[key] as! Double;
    
        return harvesine(lat1, lat2: lat2, long1: long1, long2: long2);
    }
    
    func calculate_altitude_t(index: Int) -> Double
    {
        if self.current == nil || index < 0 || index >= target_list.count {
            return 0.0/0.0;
        }

        let alt = alts[target_list[index]] as! Double;
        if (alt == 0) {
            return 0.0/0.0;
        }
        
        return -(self.current!.altitude - alt);
    }
    
    func calculate_heading_t(index: Int) -> Double
    {
        if self.current == nil || index < 0 || index >= target_list.count {
            return 0.0/0.0;
        }

        let lat1 = self.current!.coordinate.latitude;
        let long1 = self.current!.coordinate.longitude;
    
        let key = target_list[index];
        let lat2 = lats[key] as! Double;
        let long2 = longs[key] as! Double;
    
        return azimuth(lat1, lat2: lat2, long1: long1, long2: long2);
    }
    
    func calculate_heading_delta_t(index: Int) -> Double
    {
        let heading = calculate_heading_t(index);
        if heading != heading {
            return 0.0/0.0;
        }
        
        if self.current!.course < 0 {
            return 0.0/0.0;
        }
        var delta = heading - self.current!.course;
        if delta <= -180 {
            delta += 360;
        } else if delta >= 180 {
            delta -= 360;
        }
        return delta;
    }
    
    class func parse_lat(lat: String) -> Double
    {
        return parse_coord(lat, latitude: true);
    }
 
    class func parse_long(lo: String) -> Double
    {
        return parse_coord(lo, latitude: false);
    }
    
    func target_set(pindex: Int, nam: String, latitude: String, longitude: String, altitude: String) -> String?
    {
        var index = pindex;
        
        if nam.isEmpty {
            return "Name must not be empty.";
        }
    
        let dlatitude = GPSModel2.parse_lat(latitude);
        if dlatitude != dlatitude {
            return "Latitude is invalid.";
        }
    
        let dlongitude = GPSModel2.parse_long(longitude);
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

    class func parse_coord(c: String, latitude is_lat: Bool) -> Double
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

    
}
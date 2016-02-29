//
//  TargetViewController.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 10/2/15.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

// FIXME cache loading of images (in main view?)
// FIXME test movement
// FIXME lazy eval


import Foundation
import UIKit

@objc class MapViewController: UIViewController, ModelListener
{
    @IBOutlet weak var zoomout: UIButton!
    @IBOutlet weak var zoomauto: UIButton!
    @IBOutlet weak var centerme: UIButton!
    @IBOutlet weak var zoomin: UIButton!
    @IBOutlet weak var canvas: MapCanvasView!
    @IBOutlet weak var scale: UILabel!
    
    var maps: [(img: UIImage, lat0: Double, lat1: Double, long0: Double, long1: Double, latheight: Double, longwidth: Double)] = [];
    var scrw: Double = 0
    var scrh: Double = 0
    var width_prop: Double = 1
    
    // in seconds of latitude degree across the screen height
    var zoom_factor: Double = 900
    let zoom_min: Double = 30
    let zoom_max: Double = 3600
    let zoom_step: Double = 1.25
    
    // Screen position (0 = center follows GPS position)
    var center_lat: Double = 0
    var center_long: Double = 0
    var touch_point: CGPoint? = nil
    
    // Screen position for painting purposes (either screen position or GPS position)
    var clat: Double = 0
    var clong: Double = 0
    var long_prop: Double = 1
 
    // Most current GPS position
    var gpslat: Double = 0
    var gpslong: Double = 0
    
    var blink_phase = -1
    var last_blink: NSDate? = nil
    var blink_timer: NSTimer? = nil
    
    @IBAction func do_zoomin(sender: AnyObject?)
    {
        NSLog("zoom in")
        zoom_factor /= zoom_step
        zoom_factor = max(zoom_factor, zoom_min)
        repaint()
    }
 
    @IBAction func do_zoomout(sender: AnyObject?)
    {
        NSLog("zoom out")
        zoom_factor *= zoom_step
        zoom_factor = min(zoom_factor, zoom_max)
        repaint()
    }

    @IBAction func do_zoomauto(sender: AnyObject?)
    {
        NSLog("zoom auto")
        calculate_zoom()
    }
    
    @IBAction func do_centerme(sender: AnyObject?)
    {
        NSLog("center me")
        center_lat = 0
        center_long = 0
        recenter()
        repaint()
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
    
    override func viewDidLoad()
    {
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
                NSLog("   map coords %f %f %f %f", coords.lat, coords.long, coords.latheight, coords.longwidth)
                if let img = UIImage(data: NSData(contentsOfURL: url)!) {
                    NSLog("     Image loaded")
                    maps.append((img: img, lat0: coords.lat, lat1: coords.lat - coords.latheight,
                        long0: coords.long, long1: coords.long + coords.longwidth,
                        latheight: coords.latheight, longwidth: coords.longwidth))
                } else {
                    NSLog("     Image NOT loaded")
                }
            }
        }
        
        let pan = UIPanGestureRecognizer(target:self, action:"pan:")
        pan.maximumNumberOfTouches = 1
        pan.minimumNumberOfTouches = 1
        canvas.addGestureRecognizer(pan)
    }
    
    override func viewWillAppear(animated: Bool) {
        NSLog("     map will appear")
        super.viewWillAppear(animated)
        GPSModel2.model().addObs(self)
        blink_timer = NSTimer.scheduledTimerWithTimeInterval(2.0, target: self, selector: #selector(MapViewController.blink), userInfo: nil, repeats: true)
    }
    
    override func viewWillLayoutSubviews() {
        NSLog("     map layout")
        scrw = Double(canvas.bounds.size.width)
        scrh = Double(canvas.bounds.size.height)
        width_prop = scrw / scrh
    }
    
    override func viewWillDisappear(animated: Bool) {
        NSLog("     map will disappear")
        super.viewWillDisappear(animated)
        GPSModel2.model().delObs(self)
        blink_timer?.invalidate()
    }
    
    
    func fail() {
    }
    
    func permission() {
    }
    
    func update() {
        if scrw == 0 {
            return;
        }
        let calc_zoom = gpslat == 0
        gpslat = GPSModel2.model().latitude()
        gpslong = GPSModel2.model().longitude()
        recenter()
        if calc_zoom {
            calculate_zoom()
        }
        repaint()
    }
    
    func recenter()
    {
        // current center of screen in gps
        clat = center_lat
        clong = center_long
        
        // if center is locked in current position:
        if clat == 0 {
            clat = gpslat
        }
        if clong == 0 {
            clong = gpslong
        }
        
        long_prop = GPSModel2.model().longitude_proportion(clat)
    }
    
    func ins(x: Double, y: Double, a: Double, b: Double, c: Double, d: Double) -> Bool
    {
        let a0 = min(a, b)
        let b0 = max(a, b)
        let c0 = min(c, d)
        let d0 = max(c, d)
        return x >= a0 && x <= b0 && y >= c0 && y <= d0
    }

    func iins(x0: Double, x1: Double, y0: Double, y1: Double, a: Double, b: Double, c: Double, d: Double) -> Bool
    {
        let a0 = min(a, b)
        let b0 = max(a, b)
        let c0 = min(c, d)
        let d0 = max(c, d)
        let x0a = min(x0, x1)
        let x1a = max(x0, x1)
        let y0a = min(y0, y1)
        let y1a = max(y0, y1)
        return x0a <= b0 && x1a >= a0 && y0a <= d0 && y1a >= c0
    }
    

    func lat_to(x: Double, a: Double, b: Double) -> CGFloat
    {
        return CGFloat(scrh * (x - a) / (b - a))
    }

    func long_to(x: Double, a: Double, b: Double) -> CGFloat
    {
        return CGFloat(scrw * (x - a) / (b - a))
    }
    
    // Convert zoom factor to degrees of latitude
    func zoom_deg(x: Double) -> Double
    {
        return x / 3600.0
    }
    
    func blink()
    {
        if last_blink == nil {
            return
        }
        let now = NSDate()
        if now.timeIntervalSinceDate(last_blink!) > 2.0 {
            repaint()
        }
    }

    func repaint()
    {
        NSLog("Repaint");

        blink_phase += 1
        blink_phase = blink_phase % 2
        last_blink = NSDate()

        // calculate screen size in GPS
        let dzoom = zoom_deg(zoom_factor)
        let slat0 = clat + dzoom / 2.0
        let slat1 = clat - dzoom / 2.0
        let slong0 = clong - (dzoom * width_prop / long_prop) / 2.0
        let slong1 = clong + (dzoom * width_prop / long_prop) / 2.0
        NSLog("Coordinate space is lat %f to %f (for %f px), long %f to %f (for %f px)", slat0, slat1, scrh, slong0, slong1, scrw)
        NSLog("Coordinate space is %f tall %f wide", slat1 - slat0, slong1 - slong0)
        
        let scale_m = 1852.0 * 60 * long_prop * abs(slong1 - slong0)
        let scale_ft = scale_m * 3.28084
        var scale_text: NSString = ""
        if GPSModel2.model().get_metric() > 0 {
            if scale_m < 1000 {
                scale_text = NSString(format: "<- %.0fm ->", scale_m)
            } else if scale_m < 100000 {
                scale_text = NSString(format: "<- %.1fkm ->", scale_m / 1000)
            } else {
                scale_text = NSString(format: "<- %.0fkm ->", scale_m / 1000)
            }
        } else {
            if scale_m < 5280 {
                scale_text = NSString(format: "<- %.0fft ->", scale_ft)
            } else if scale_m < 5280*100 {
                scale_text = NSString(format: "<- %.1fmi ->", scale_ft / 5280)
            } else {
                scale_text = NSString(format: "<- %.0fmi ->", scale_m / 5280)
            }
        }
        scale.text = scale_text as String
        
        if ins(gpslat, y: gpslong, a: slat0, b: slat1, c: slong0, d: slong1) {
            let x = long_to(gpslong, a: slong0, b: slong1)
            let y = lat_to(gpslat, a: slat0, b: slat1)
            canvas.send_pos(x, y: y)
            NSLog("My position %f %f translated to %f,%f", clat, clong, x, y)
        } else {
            canvas.send_pos(-1, y: -1)
            NSLog("My position %f %f not in space", clat, clong)
        }
        
        var targets: [(CGFloat, CGFloat)] = []
        if blink_phase > 0 {
            var tgt = 0;
            while tgt < GPSModel2.model().target_count() {
                let tlat = GPSModel2.model().target_latitude(tgt)
                let tlong = GPSModel2.model().target_longitude(tgt)
                if ins(tlat, y: tlong, a: slat0, b: slat1, c: slong0, d: slong1) {
                    let x = long_to(tlong, a: slong0, b: slong1)
                    let y = lat_to(tlat, a: slat0, b: slat1)
                    targets.append(x, y)
                    NSLog("Target[%d] %f %f translated to %f,%f", tgt, tlat, tlong, x, y)
                } else {
                    NSLog("Target[%d] %f %f not in space", tgt, tlat, tlong)
                }
                tgt += 1
            }
        }
        canvas.send_targets(targets)
        
        var plot: [(UIImage, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = []
        for map in maps {
            if iins(map.lat0, x1: map.lat1, y0: map.long0, y1: map.long1, a: slat0, b: slat1, c: slong0, d: slong1) {
                let x0 = long_to(map.long0, a: slong0, b: slong1)
                let x1 = long_to(map.long1, a: slong0, b: slong1)
                let y0 = lat_to(map.lat0, a: slat0, b: slat1)
                let y1 = lat_to(map.lat1, a: slat0, b: slat1)
                plot.append((map.img, x0, x1, y0, y1, abs(y1 - y0)))
                NSLog("Map lat %f..%f, long %f..%f translated to x:%f-%f y:%f-%f", map.lat0, map.lat1, map.long0, map.long1, x0, x1, y0, y1)
            } else {
                NSLog("Map %f %f, %f %f not in space", map.lat0, map.lat1, map.long0, map.long1)
            }
        }
        // smaller images should be blitted last since they are probably more detailed maps of the area
        plot.sortInPlace({ $0.5 > $1.5 } )
        canvas.send_img(plot)
        
        NSLog("------------------")
    }
    
    func calculate_zoom()
    {
        if scrw == 0 || gpslat == 0 || GPSModel2.model().target_count() <= 0 {
            return
        }

        // force current position in center
        center_lat = 0
        center_long = 0
        recenter()

        var new_zoom_factor = zoom_min / zoom_step
        var ok = false
        
        while (!ok && new_zoom_factor <= zoom_max) {
            new_zoom_factor *= zoom_step

            // calculate screen size in GPS
            let dzoom = zoom_deg(new_zoom_factor)
            let slat0 = clat + dzoom / 2
            let slat1 = clat - dzoom / 2
            let slong0 = clong - (dzoom * width_prop / long_prop) / 2
            let slong1 = clong + (dzoom * width_prop / long_prop) / 2

            // check whether at least one target fits in current zoom
            var tgt = 0;
            while tgt < GPSModel2.model().target_count() {
                let tlat = GPSModel2.model().target_latitude(tgt)
                let tlong = GPSModel2.model().target_longitude(tgt)
                if ins(tlat, y: tlong, a: slat0, b: slat1, c: slong0, d: slong1) {
                    ok = true
                    break
                }
                tgt += 1
            }
        }
        
        if ok {
            zoom_factor = new_zoom_factor
        }
        
        repaint()
    }
    
    func pan(rec:UIPanGestureRecognizer)
    {
        switch rec.state {
            case .Began:
                touch_point = rec.locationInView(canvas)
                NSLog("Drag began at %f %f", touch_point!.x, touch_point!.y)
        
            case .Changed:
                if scrw == 0 || gpslat == 0 {
                    return
                }
                let new_point = rec.locationInView(canvas)
                let dx = new_point.x - touch_point!.x
                let dy = new_point.y - touch_point!.y
                touch_point = new_point
                NSLog("Drag moved by %f %f", dx, dy)
                if center_lat == 0 {
                    center_lat = gpslat
                    center_long = gpslong
                }
                // zoom = measurement of latitude
                let dzoom = zoom_deg(zoom_factor)
                center_long += dzoom * width_prop / long_prop * (Double(-dx) / scrw)
                center_lat += dzoom * (Double(dy) / scrh)
                recenter()
                repaint()
            
            default:
                break
        }
    }
}
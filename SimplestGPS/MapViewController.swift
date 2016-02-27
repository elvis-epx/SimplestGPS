//
//  TargetViewController.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 10/2/15.
//  Copyright © 2015 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

@objc class MapViewController: UIViewController, ModelListener
{
    @IBOutlet weak var zoomout: UIButton!
    @IBOutlet weak var zoomauto: UIButton!
    @IBOutlet weak var centerme: UIButton!
    @IBOutlet weak var zoomin: UIButton!
    @IBOutlet weak var canvas: MapCanvasView!

    var maps: [(img: UIImage, lat0: Double, lat1: Double, long0: Double, long1: Double, latheight: Double, longwidth: Double)] = [];
    var scrw: Double = 0
    var scrh: Double = 0
    var width_prop: Double = 1
    
    // in seconds of latitude degree across the screen height
    var zoom: Double = 15
    let zoom_min: Double = 1
    let zoom_max: Double = 1800
    
    // Screen position (0 = center locked in current position)
    var center_lat: Double = 0
    var center_long: Double = 0
    
    // Screen position for painting purposes (either screen position or GPS position)
    var clat: Double = 0
    var clong: Double = 0
    var long_prop: Double = 1
 
    // Most current GPS position
    var gpslat: Double = 0
    var gpslong: Double = 0
    
    @IBAction func do_zoomin(sender: AnyObject?)
    {
        NSLog("zoom in")
        zoom /= 1.4
        zoom = max(zoom, zoom_min)
        repaint()
    }
 
    @IBAction func do_zoomout(sender: AnyObject?)
    {
        NSLog("zoom out")
        zoom *= 1.4
        zoom = min(zoom, zoom_max)
        repaint()
    }

    @IBAction func do_zoomauto(sender: AnyObject?)
    {
        NSLog("zoom auto")
        calculate_zoom()
    }
    
    // FIXME drag view (changes center_lat and center_long)
    
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
                    maps.append((img: img, lat0: coords.lat - coords.latheight, lat1: coords.lat,
                        long0: coords.long, long1: coords.long + coords.longwidth,
                        latheight: coords.latheight, longwidth: coords.longwidth))
                } else {
                    NSLog("     Image NOT loaded")
                }
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        GPSModel2.model().addObs(self)
    }
    
    override func viewWillLayoutSubviews() {
        scrw = Double(canvas.bounds.size.width)
        scrh = Double(canvas.bounds.size.height)
        width_prop = scrw / scrh
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        GPSModel2.model().delObs(self)
    }
    
    
    func fail() {
    }
    
    func permission() {
    }
    
    func update() {
        if scrw == 0 {
            return;
        }
        gpslat = GPSModel2.model().latitude()
        gpslong = GPSModel2.model().longitude()
        recenter()
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
        return x0 <= b0 && x1 >= a0 && y0 <= d0 && y1 >= c0
    }
    

    func lat_to(x: Double, a: Double, b: Double) -> CGFloat
    {
        return CGFloat(scrh * (x - a) / (b - a))
    }

    func long_to(x: Double, a: Double, b: Double) -> CGFloat
    {
        return CGFloat(scrw * (x - a) / (b - a))
    }

    func repaint()
    {
        // calculate screen size in GPS
        let slat0 = clat + zoom / 2
        let slat1 = clat - zoom / 2
        let slong0 = clong - (zoom * width_prop / long_prop) / 2
        let slong1 = clong + (zoom * width_prop / long_prop) / 2
        
        if ins(clat, y: clong, a: slat0, b: slat1, c: slong0, d: slong1) {
            canvas.send_pos(long_to(clong, a: slong0, b: slong1), y: lat_to(clat, a: slat0, b: slat1))
        } else {
            canvas.send_pos(0, y: 0)
        }
        
        var tgt = 0;
        var targets: [(CGFloat, CGFloat)] = []
        while tgt < GPSModel2.model().target_count() {
            let tlat = GPSModel2.model().target_latitude(tgt)
            let tlong = GPSModel2.model().target_longitude(tgt)
            if ins(tlat, y: tlong, a: slat0, b: slat1, c: slong0, d: slong1) {
                targets.append((long_to(tlong, a: slong0, b: slong1), lat_to(tlat, a: slat0, b: slat1)))
            }
            tgt += 1
        }
        canvas.send_targets(targets)
        
        var plot: [(UIImage, CGFloat, CGFloat, CGFloat, CGFloat)] = []
        for map in maps {
            if iins(map.lat0, x1: map.lat1, y0: map.long0, y1: map.long1, a: slat0, b: slat1, c: slong0, d: slong1) {
                let x0 = long_to(map.long0, a: slong0, b: slong1)
                let x1 = long_to(map.long1, a: slong0, b: slong1)
                let y0 = lat_to(map.lat0, a: slat0, b: slat1)
                let y1 = lat_to(map.lat1, a: slat0, b: slat1)
                plot.append((map.img, x0, x1, y0, y1))
            }
        }
        canvas.send_img(plot)
    }
    
    func calculate_zoom()
    {
        if scrw == 0 || gpslat == 0 {
            return;
        }

        // force current position in center
        center_lat = 0
        center_long = 0
        recenter()

        var new_zoom = zoom_min / 1.4
        var ok = false
        
        while (!ok && new_zoom <= zoom_max) {
            new_zoom *= 1.4

            // calculate screen size in GPS
            let slat0 = clat + new_zoom / 2
            let slat1 = clat - new_zoom / 2
            let slong0 = clong - (new_zoom * width_prop / long_prop) / 2
            let slong1 = clong + (new_zoom * width_prop / long_prop) / 2

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
            zoom = new_zoom
        }
        
        repaint()
    }
}
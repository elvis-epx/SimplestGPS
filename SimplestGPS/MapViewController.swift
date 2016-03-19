//
//  TargetViewController.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 10/2/15.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
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
    @IBOutlet weak var scale: UILabel!
    
    var scrw: Double = 0
    var scrh: Double = 0
    var width_prop: Double = 1
    
    // in seconds of latitude degree across the screen height
    var zoom_factor: Double = 60
    let zoom_min: Double = 30
    let zoom_step: Double = 1.25
    let zoom_max: Double = 3600
    // we assume that maps have Mercator projection so we cannot go down to 90 degrees either
    let max_latitude = 90.0 - 5.0 - 3600 / 3600.0
    
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
    var blink_timer: NSTimer? = nil
    
    var debug = false

    @IBAction func do_zoomin(sender: AnyObject?)
    {
        // NSLog("zoom in")
        zoom_factor /= zoom_step
        zoom_factor = max(zoom_factor, zoom_min)
        repaint()
    }
 
    @IBAction func do_zoomout(sender: AnyObject?)
    {
        // NSLog("zoom out")
        zoom_factor *= zoom_step
        zoom_factor = min(zoom_factor, zoom_max)
        repaint()
    }

    @IBAction func do_zoomauto(sender: AnyObject?)
    {
        // NSLog("zoom auto")
        calculate_zoom()
    }
    
    @IBAction func do_centerme(sender: AnyObject?)
    {
        // NSLog("center me")
        center_lat = 0
        center_long = 0
        recenter()
        repaint()
    }
    
    override func viewDidLoad()
    {
        let pan = UIPanGestureRecognizer(target:self, action:#selector(MapViewController.pan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.minimumNumberOfTouches = 1
        canvas.addGestureRecognizer(pan)
    }
    
    override func viewWillAppear(animated: Bool) {
        NSLog("     map will appear")
        super.viewWillAppear(animated)
        GPSModel2.model().addObs(self)
        blink_timer = NSTimer.scheduledTimerWithTimeInterval(0.33, target: self, selector: #selector(MapViewController.blink), userInfo: nil, repeats: true)
    }
    
    override func viewWillLayoutSubviews() {
        // NSLog("     map layout")
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
        
        // Keep latitude within Mercator limits
        clat = min(max_latitude, clat)
        clat = max(-max_latitude, clat)
        
        long_prop = GPSModel2.model().longitude_proportion(clat)
    }
    
    func normalize_longitude(x: Double) -> Double
    {
        if x < -180 {
            // 181W -> 179E
            return 360 - x
        } else if center_long > 180 {
            // 181E -> 179W
            return x - 360
        }
        return x
    }
    
    // test whether a longitude range is nearer to meridian 180 than meridian 0
    func nearer_180(a: Double, b: Double) -> Bool
    {
        // note: this test assumes that range is < 180 degrees
        return (abs(a) + abs(b)) >= 180
    }
    
    // converts longitude, so values across +180/-180 line are directly comparable
    // It actually moves the 180 "problem" to the meridian 0 (longitude line becomes 359..0..1)
    // so this function should be used only when the range of interest does NOT cross 0
    func offset_180(x: Double) -> Double
    {
        if x < 0 {
            return x + 360
        }
        return x
    }
    
    func ins(lat: Double, _long: Double, lata: Double, latb: Double, _longa: Double, _longb: Double) -> Bool
    {
        var long = normalize_longitude(_long)
        var longa = normalize_longitude(_longa)
        var longb = normalize_longitude(_longb)
        
        if nearer_180(longa, b: longb) {
            long = offset_180(long)
            longa = offset_180(longa)
            longb = offset_180(longb)
        }
        
        let lat0 = min(lata, latb)
        let lat1 = max(lata, latb)
        let long0 = min(longa, longb)
        let long1 = max(longa, longb)
        return lat >= lat0 && lat <= lat1 && long >= long0 && long <= long1
    }
    
    func iins(maplata: Double, maplatb: Double, _maplonga: Double, _maplongb: Double, lata: Double, latb: Double, _longa: Double, _longb: Double) -> Bool
    {
        var maplonga = normalize_longitude(_maplonga)
        var maplongb = normalize_longitude(_maplongb)
        var longa = normalize_longitude(_longa)
        var longb = normalize_longitude(_longb)
        
        if nearer_180(longa, b: longb) || nearer_180(maplonga, b: maplongb) {
            longa = offset_180(longa)
            longb = offset_180(longb)
            maplonga = offset_180(maplonga)
            maplongb = offset_180(maplongb)
        }
        
        let maplat0 = min(maplata, maplatb)
        let maplat1 = max(maplata, maplatb)
        let maplong0 = min(maplonga, maplongb)
        let maplong1 = max(maplonga, maplongb)
        let lat0 = min(lata, latb)
        let lat1 = max(lata, latb)
        let long0 = min(longa, longb)
        let long1 = max(longa, longb)
        return maplat0 <= lat1 && maplat1 >= lat0 && maplong0 <= long1 && maplong1 >= long0
    }
    
    func lat_to(x: Double, a: Double, b: Double) -> CGFloat
    {
        return CGFloat(scrh * (x - a) / (b - a))
    }

    func long_to(x: Double, a: Double, b: Double) -> CGFloat
    {
        var xx = normalize_longitude(x)
        var aa = normalize_longitude(a)
        var bb = normalize_longitude(b)
        
        if nearer_180(a, b: b) {
            xx = offset_180(xx)
            aa = offset_180(aa)
            bb = offset_180(bb)
        }
        
        return CGFloat(scrw * (xx - aa) / (bb - aa))
    }
    
    // Convert zoom factor to degrees of latitude
    func zoom_deg(x: Double) -> Double
    {
        return x / 3600.0
    }
    
    func blink()
    {
        blink_phase += 1
        blink_phase %= 2
        repaint()
    }

    func repaint()
    {
        if debug {
            NSLog("Repaint");
        }

        // calculate screen size in GPS
        // NOTE: longitude coordinates may be denormalized (e.g. -181W or +181E)
        let dzoom = zoom_deg(zoom_factor)
        let slat0 = clat + dzoom / 2.0
        let slat1 = clat - dzoom / 2.0
        let slong0 = clong - (dzoom * width_prop / long_prop) / 2.0
        let slong1 = clong + (dzoom * width_prop / long_prop) / 2.0
        if debug {
            NSLog("Coordinate space is lat %f to %f (for %f px), long %f to %f (for %f px)", slat0, slat1, scrh, slong0, slong1, scrw)
            NSLog("Coordinate space is %f tall %f wide", slat1 - slat0, slong1 - slong0)
        }
        
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
        
        var plot: [(UIImage, String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = []
        for map in GPSModel2.model().get_maps() {
            if iins(map.lat0, maplatb: map.lat1, _maplonga: map.long0, _maplongb: map.long1, lata: slat0, latb: slat1, _longa: slong0, _longb: slong1) {
                let x0 = long_to(map.long0, a: slong0, b: slong1)
                let x1 = long_to(map.long1, a: slong0, b: slong1)
                let y0 = lat_to(map.lat0, a: slat0, b: slat1)
                let y1 = lat_to(map.lat1, a: slat0, b: slat1)
                let img = GPSModel2.model().get_map_image(map.file)
                if (img != nil) {
                    plot.append((img!, map.file.absoluteString, x0, x1, y0, y1, abs(y1 - y0)))
                    if debug {
                        NSLog("Map lat %f..%f, long %f..%f translated to x:%f-%f y:%f-%f", map.lat0, map.lat1, map.long0, map.long1, x0, x1, y0, y1)
                    }
                } else {
                    if debug {
                        NSLog("Map not available")
                    }
                }
            } else {
                if debug {
                    NSLog("Map %f %f, %f %f not in space", map.lat0, map.lat1, map.long0, map.long1)
                }
            }
        }
        
        // smaller images should be blitted last since they are probably more detailed maps of the area
        plot.sortInPlace({ $0.5 > $1.5 } )
        
        // optimize the case when more than a map covers the whole screen
        var i = plot.count - 1
        while i > 0 {
            let x0 = plot[i].2
            let x1 = plot[i].3
            let y0 = plot[i].4
            let y1 = plot[i].5
            if x0 <= 0 && x1 >= CGFloat(scrw) && y0 <= 0 && y1 >= CGFloat(scrh) {
                // remove maps beneath the topmost that covers the whole screen
                for _ in 1...i {
                    plot.removeAtIndex(0)
                }
                break
            }
            i -= 1
        }
        
        canvas.send_img(plot)
        
        if ins(gpslat, _long: gpslong, lata: slat0, latb: slat1, _longa: slong0, _longb: slong1) {
            let x = long_to(gpslong, a: slong0, b: slong1)
            let y = lat_to(gpslat, a: slat0, b: slat1)
            canvas.send_pos(x, y: y, color: blink_phase)
            if debug {
                NSLog("My position %f %f translated to %f,%f", clat, clong, x, y)
            }
        } else {
            canvas.send_pos(-1, y: -1, color: 0)
            if debug {
                NSLog("My position %f %f not in space", clat, clong)
            }
        }
        
        var targets: [(CGFloat, CGFloat)] = []
        if blink_phase > 0 {
            var tgt = 0;
            while tgt < GPSModel2.model().target_count() {
                let tlat = GPSModel2.model().target_latitude(tgt)
                let tlong = GPSModel2.model().target_longitude(tgt)
                if ins(tlat, _long: tlong, lata: slat0, latb: slat1, _longa: slong0, _longb: slong1) {
                    let x = long_to(tlong, a: slong0, b: slong1)
                    let y = lat_to(tlat, a: slat0, b: slat1)
                    targets.append(x, y)
                    if debug {
                        NSLog("Target[%d] %f %f translated to %f,%f", tgt, tlat, tlong, x, y)
                    }
                } else {
                    if debug {
                        NSLog("Target[%d] %f %f not in space", tgt, tlat, tlong)
                    }
                }
                tgt += 1
            }
        }
        canvas.send_targets(targets)
        
        if debug {
            NSLog("Painted with %d maps", plot.count)
        }
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
            // NOTE: longitude may be denormalized (e.g. -181W)
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
                if ins(tlat, _long: tlong, lata: slat0, latb: slat1, _longa: slong0, _longb: slong1) {
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
                // NSLog("Drag began at %f %f", touch_point!.x, touch_point!.y)
        
            case .Changed:
                if scrw == 0 || gpslat == 0 {
                    return
                }
                let new_point = rec.locationInView(canvas)
                let dx = new_point.x - touch_point!.x
                let dy = new_point.y - touch_point!.y
                touch_point = new_point
                // NSLog("Drag moved by %f %f", dx, dy)
                if center_lat == 0 {
                    center_lat = gpslat
                    center_long = gpslong
                }
                // zoom = measurement of latitude
                let dzoom = zoom_deg(zoom_factor)
                center_long += dzoom * width_prop / long_prop * (Double(-dx) / scrw)
                center_lat += dzoom * (Double(dy) / scrh)
                
                // do not allow latitude above the Mercator reasonable limit
                center_lat = min(max_latitude, center_lat)
                center_lat = max(-max_latitude, center_lat)
                
                // handle cross of 180W meridian, normalize longitude
                center_long = normalize_longitude(center_long)

                recenter()
                repaint()
            
            default:
                break
        }
    }
}

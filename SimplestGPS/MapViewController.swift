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
    @IBOutlet weak var canvas: MapCanvasView!
    @IBOutlet weak var scale: UILabel!
    @IBOutlet weak var new_target: UIButton!
    
    @IBOutlet weak var altitude: UILabel!
    @IBOutlet weak var accuracy: UILabel!
    @IBOutlet weak var longitude: UILabel!
    @IBOutlet weak var latitude: UILabel!
    var scrw: Double = Double.NaN
    var scrh: Double = Double.NaN
    var width_prop: Double = Double.NaN
    
    let MODE_MAPONLY = 0
    let MODE_MAPCOMPASS = 1
    let MODE_MAPHEADING = 2
    let MODE_COMPASS = 3
    let MODE_HEADING = 4
    let MODE_COUNT = 5

    var mode = 1

    // in seconds of latitude degree across the screen height
    var zoom_factor: Double = 900
    let zoom_min: Double = 30
    let zoom_step: Double = 1.25
    let zoom_max: Double = 3600
    // we assume that maps have Mercator projection so we cannot go down to 90 degrees either
    let max_latitude = 90.0 - 5.0 - 3600 / 3600.0
    
    // Screen position (NaN = center follows GPS position)
    var center_lat: Double = Double.NaN
    var center_long: Double = Double.NaN
    var touch_point: CGPoint? = nil
    
    // Screen position for painting purposes (either screen position or GPS position)
    var clat: Double = Double.NaN
    var clong: Double = Double.NaN
    var long_prop: Double = 1
 
    // Most current GPS position
    var gpslat: Double = Double.NaN
    var gpslong: Double = Double.NaN
    
    var blink_phase = -1
    var blink_timer: NSTimer? = nil
    var compass_timer: NSTimer? = nil
    var current_target = -1
    
    var debug = false

    func do_zoomauto(all_targets: Bool)
    {
        // NSLog("zoom auto")
        calculate_zoom(all_targets)
    }
    
    func do_centerme()
    {
        // NSLog("center me")
        center_lat = Double.NaN
        center_long = Double.NaN
        recenter()
        repaint()
    }
    
    override func viewDidLoad()
    {
        let pan = UIPanGestureRecognizer(target:self, action:#selector(MapViewController.pan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.minimumNumberOfTouches = 1
        canvas.addGestureRecognizer(pan)
        
        let pinch = UIPinchGestureRecognizer(target: self, action:#selector(MapViewController.pinch(_:)))
        canvas.addGestureRecognizer(pinch)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(MapViewController.onefinger(_:)))
        tap.numberOfTapsRequired = 3
        tap.numberOfTouchesRequired = 1
        canvas.addGestureRecognizer(tap)

        let tap2 = UITapGestureRecognizer(target: self, action: #selector(MapViewController.twofingers(_:)))
        tap2.numberOfTapsRequired = 3
        tap2.numberOfTouchesRequired = 2
        canvas.addGestureRecognizer(tap2)
        
        let tap3 = UITapGestureRecognizer(target: self, action: #selector(MapViewController.threefingers(_:)))
        tap3.numberOfTapsRequired = 3
        tap3.numberOfTouchesRequired = 3
        canvas.addGestureRecognizer(tap3)
    }
    
    override func viewWillAppear(animated: Bool) {
        NSLog("     map will appear")
        super.viewWillAppear(animated)
        GPSModel2.model().addObs(self)
        blink_timer = NSTimer.scheduledTimerWithTimeInterval(0.33, target: self, selector: #selector(MapViewController.blink), userInfo: nil, repeats: true)
        compass_timer = NSTimer.scheduledTimerWithTimeInterval(1.0 / 30.0, target: self, selector: #selector(MapViewController.compass_anim), userInfo: nil, repeats: true)
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
        compass_timer?.invalidate()
    }
    
    func fail() {
        latitude.text = ""
        longitude.text = "Wait"
    }
    
    func permission() {
        latitude.text = ""
        longitude.text = "Permission denied"
    }
    
    func update() {
        if scrw.isNaN {
            return;
        }
        let calc_zoom = gpslat.isNaN
        gpslat = GPSModel2.model().latitude()
        gpslong = GPSModel2.model().longitude()
        recenter()
        if calc_zoom {
            calculate_zoom(false)
        }
        repaint()
    }
    
    func recenter()
    {
        // current center of screen in gps
        clat = center_lat
        clong = center_long
        
        // if center is locked in current position:
        if clat.isNaN {
            clat = gpslat
            clong = gpslong
        }
        
        // Keep latitude within Mercator limits
        if clat == clat {
            clat = min(max_latitude, clat)
            clat = max(-max_latitude, clat)
        }
        
        long_prop = GPSModel2.longitude_proportion(clat)
        if long_prop.isNaN {
            long_prop = 1
        }
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
        if clat.isNaN {
            return
        }
        
        if !GPSModel2.model().hold() {
            return
        }
        
        scale.hidden = (mode == MODE_COMPASS || mode == MODE_HEADING)
        // latitude.hidden = !(mode == MODE_COMPASS || mode == MODE_HEADING)
        // longitude.hidden = !(mode == MODE_COMPASS || mode == MODE_HEADING)
        // accuracy.hidden = !(mode == MODE_COMPASS || mode == MODE_HEADING)
        
        // send compass data
        var targets_compass: [(heading: Double, name: String, distance: String)] = []
        var tgt = 0
        while tgt < GPSModel2.model().target_count() {
            targets_compass.append((heading: GPSModel2.model().target_heading(tgt),
                name: GPSModel2.model().target_name(tgt),
                distance: GPSModel2.model().target_distance_formatted(tgt)))
            tgt += 1
        }
        if current_target >= targets_compass.count {
            current_target = -1
        }
        canvas.send_compass(mode, heading: GPSModel2.model().heading(),
                            altitude: GPSModel2.model().altitude_formatted(),
                            speed: GPSModel2.model().speed_formatted(),
                            current_target: current_target, targets: targets_compass)

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
        scale.text = GPSModel2.format_distance_t(scale_m, met: GPSModel2.model().get_metric())
        latitude.text = GPSModel2.model().latitude_formatted()
        longitude.text = GPSModel2.model().longitude_formatted()
        altitude.text = GPSModel2.model().altitude_formatted()
        accuracy.text = GPSModel2.model().accuracy_formatted()

        let accuracy_px = scrw * GPSModel2.model().horizontal_accuracy() / scale_m
        
        var plot: [(UIImage, String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = []
        
            for map in GPSModel2.model().get_maps() {
                if GPSModel2.iins(map.lat0, maplatb: map.lat1, _maplonga: map.long0, _maplongb: map.long1,
                                  lata: slat0, latb: slat1, _longa: slong0, _longb: slong1) {
                    let x0 = GPSModel2.long_to(map.long0, a: slong0, b: slong1, scrw: scrw)
                    let x1 = GPSModel2.long_to(map.long1, a: slong0, b: slong1, scrw: scrw)
                    let y0 = GPSModel2.lat_to(map.lat0, a: slat0, b: slat1, scrh: scrh)
                    let y1 = GPSModel2.lat_to(map.lat1, a: slat0, b: slat1, scrh: scrh)
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
        
        if GPSModel2.ins(gpslat, _long: gpslong, lata: slat0, latb: slat1, _longa: slong0, _longb: slong1) {
            let x = GPSModel2.long_to(gpslong, a: slong0, b: slong1, scrw: scrw)
            let y = GPSModel2.lat_to(gpslat, a: slat0, b: slat1, scrh: scrh)
            canvas.send_pos(x, y: y, color: blink_phase, accuracy: CGFloat(accuracy_px))
            if debug {
                NSLog("My position %f %f translated to %f,%f", clat, clong, x, y)
            }
        } else {
            canvas.send_pos(-1, y: -1, color: 0, accuracy: 0)
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
                if GPSModel2.ins(tlat, _long: tlong, lata: slat0, latb: slat1, _longa: slong0, _longb: slong1) {
                    let x = GPSModel2.long_to(tlong, a: slong0, b: slong1, scrw: scrw)
                    let y = GPSModel2.lat_to(tlat, a: slat0, b: slat1, scrh: scrh)
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
        
        GPSModel2.model().releas()
        
        if debug {
            NSLog("Painted with %d maps", plot.count)
        }
    }
    
    func calculate_zoom(all_targets: Bool)
    {
        if scrw.isNaN || gpslat.isNaN || GPSModel2.model().target_count() <= 0 {
            return
        }

        // force current position in center
        center_lat = Double.NaN
        center_long = Double.NaN
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

            // check whether at least one target, or all targets, fit in current zoom
            ok = all_targets
            var tgt = 0;
            while tgt < GPSModel2.model().target_count() {
                let tlat = GPSModel2.model().target_latitude(tgt)
                let tlong = GPSModel2.model().target_longitude(tgt)
                if GPSModel2.ins(tlat, _long: tlong, lata: slat0, latb: slat1, _longa: slong0, _longb: slong1) {
                    if !all_targets {
                        ok = true
                        break
                    }
                } else {
                    if all_targets {
                        ok = false
                        break
                    }
                }
                tgt += 1
            }
        }
        
        zoom_factor = new_zoom_factor
        zoom_factor = max(zoom_factor, zoom_min)
        zoom_factor = min(zoom_factor, zoom_max)
        
        repaint()
    }
    
    func pan(rec:UIPanGestureRecognizer)
    {
        switch rec.state {
            case .Began:
                touch_point = rec.locationInView(canvas)
                // NSLog("Drag began at %f %f", touch_point!.x, touch_point!.y)
        
            case .Changed:
                if scrw.isNaN || gpslat.isNaN {
                    return
                }
                let new_point = rec.locationInView(canvas)
                let dx = new_point.x - touch_point!.x
                let dy = new_point.y - touch_point!.y
                touch_point = new_point
                // NSLog("Drag moved by %f %f", dx, dy)
                if center_lat.isNaN {
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
                center_long = GPSModel2.normalize_longitude(center_long)

                recenter()
                repaint()
            
            default:
                break
        }
    }

    func pinch(rec:UIPinchGestureRecognizer)
    {
        zoom_factor /= Double(rec.scale)
        zoom_factor = max(zoom_factor, zoom_min)
        zoom_factor = min(zoom_factor, zoom_max)
        rec.scale = 1.0
        repaint()
    }

    func onefinger(rec:UITapGestureRecognizer)
    {
        NSLog("One finger")
        switch rec.state {
        case .Ended:
            do_centerme()
        default:
            break
        }
    }

    func twofingers(rec:UITapGestureRecognizer)
    {
        NSLog("Two fingers")
        switch rec.state {
        case .Ended:
            do_zoomauto(false)
        default:
            break
        }
    }
    
    func threefingers(rec:UITapGestureRecognizer)
    {
        NSLog("Three fingers")
        switch rec.state {
        case .Ended:
            do_zoomauto(true)
        default:
            break
        }
    }
    
    @IBAction func mod_button(sender: AnyObject)
    {
        mode += 1
        mode %= MODE_COUNT
        repaint()
    }
    
    @IBAction func tgt_button(sender: AnyObject)
    {
        current_target += 1
        if current_target >= GPSModel2.model().target_count() {
            current_target = -1
        }
        repaint()
    }
    
    func compass_anim()
    {
        canvas.compass_anim()
    }
    
    @IBAction func backToMain(sender: UIStoryboardSegue)
    {
    }
}

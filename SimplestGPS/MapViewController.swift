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
    var width_height_proportion: Double = Double.NaN
    var diag_height_proportion: Double = Double.NaN
    
    let MODE_MAPONLY = 0
    let MODE_MAPCOMPASS = 1
    let MODE_MAPHEADING = 2
    let MODE_COMPASS = 3
    let MODE_HEADING = 4
    let MODE_COUNT = 5
    
    var mode = 1
    var tgt_dist = true
    
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
    var longitude_latitude_proportion: Double = 1
    
    // Heading angle for transforms (in radians)
    var screen_heading: Double = M_PI / 2
    var DEFAULT_SCREEN_HEADING: Double = M_PI / 2
    
    // Most current GPS position
    var gpslat: Double = Double.NaN
    var gpslong: Double = Double.NaN
    
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
        repaint(true)
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
    }
    
    override func viewWillLayoutSubviews() {
        // NSLog("     map layout")
        scrw = Double(canvas.bounds.size.width)
        scrh = Double(canvas.bounds.size.height)
        width_height_proportion = scrw / scrh
        diag_height_proportion = sqrt(scrw * scrw + scrh * scrh) / scrh
    }
    
    override func viewWillDisappear(animated: Bool) {
        NSLog("     map will disappear")
        super.viewWillDisappear(animated)
        GPSModel2.model().delObs(self)
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
        
        if mode == MODE_MAPHEADING {
            var h = GPSModel2.model().heading()
            if h.isNaN {
                h = 0
            }
            screen_heading = h * M_PI / 180
        } else {
            screen_heading = DEFAULT_SCREEN_HEADING
        }
        
        recenter()
        if calc_zoom {
            calculate_zoom(false) // does repaint()
            return
        }
        repaint(false)
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
        
        longitude_latitude_proportion = GPSModel2.longitude_proportion(clat)
        if longitude_latitude_proportion.isNaN {
            longitude_latitude_proportion = 1
        }
    }
    
    func zoom_in_degrees(x: Double) -> Double
    {
        // zoom is in seconds, convert to degrees
        return x / 3600.0
    }
    
    func zoom_in_widthradius_m(x: Double) -> Double
    {
        return width_height_proportion * zoom_in_heightradius_m(x)
    }
    
    func zoom_in_heightradius_m(x: Double) -> Double
    {
        // zoom is in latitude seconds, convert to minutes, then to distance
        return 1853.0 * x / 60.0 / 2.0
    }
    
    func zoom_in_diagradius_m(x: Double) -> Double
    {
        return diag_height_proportion * zoom_in_heightradius_m(x)
    }
    
    func repaint(immediately: Bool)
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
        for tgt in 0..<GPSModel2.model().target_count() {
            targets_compass.append((heading: GPSModel2.model().target_heading(tgt),
                name: GPSModel2.model().target_name(tgt),
                distance: GPSModel2.model().target_distance_formatted(tgt)))
        }
        if current_target >= targets_compass.count {
            current_target = -1
        }
        canvas.send_compass(mode, heading: GPSModel2.model().heading(),
                            altitude: GPSModel2.model().altitude_formatted(),
                            speed: GPSModel2.model().speed_formatted(),
                            current_target: current_target, targets: targets_compass,
                            tgt_dist: tgt_dist)
        
        let zoom_m_diagonal = zoom_in_heightradius_m(zoom_factor)
        let zoom_height = zoom_in_degrees(zoom_factor)
        let zoom_width = zoom_height / longitude_latitude_proportion * width_height_proportion
        if debug {
            NSLog("Coordinate space is lat %f long %f radius %f", clat, clong, zoom_m_diagonal)
        }
        
        let scale_m = 2 * zoom_in_heightradius_m(zoom_factor)
        
        scale.text = GPSModel2.format_distance_t(scale_m, met: GPSModel2.model().get_metric())
        latitude.text = GPSModel2.model().latitude_formatted()
        longitude.text = GPSModel2.model().longitude_formatted()
        altitude.text = GPSModel2.model().altitude_formatted()
        accuracy.text = GPSModel2.model().accuracy_formatted()
        
        let accuracy_px = scrw * GPSModel2.model().horizontal_accuracy() / scale_m
        
        var plot: [(UIImage, String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = []
        
        for map in GPSModel2.model().get_maps() {
            if GPSModel2.map_inside(map.lat0, maplatb: map.lat1, maplonga: map.long0, maplongb: map.long1,
                                    lat_circle: clat, long_circle: clong, radius: zoom_m_diagonal) {

                let (centerx, centery) = GPSModel2.to_raster(
                                                (map.lat0 + map.lat1) / 2,
                                                long: (map.long0 + map.long1) / 2,
                                                clat: clat, clong: clong,
                                                heading: screen_heading,
                                                zoom_height: zoom_height, scrh: scrh, scrw: scrw,
                                                longitude_proportion: longitude_latitude_proportion)
                
                let boundsx = CGFloat(scrw * abs(map.long1 - map.long0) / zoom_width)
                let boundsy = CGFloat(scrh * abs(map.lat1 - map.lat0) / zoom_height)

                let img = GPSModel2.model().get_map_image(map.file)
                if (img != nil) {
                    plot.append((img!, map.file.absoluteString, boundsx, boundsy, centerx, centery,
                        CGFloat(screen_heading), boundsy))
                    if debug {
                        NSLog("Map lat %f..%f, long %f..%f translated to x:%f-%f y:%f-%f", map.lat0, map.lat1,
                              map.long0, map.long1, boundsx, boundsy, centerx, centery)
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
        plot.sortInPlace({ $0.6 > $1.6 } )
        
        canvas.send_img(plot)
        
        if GPSModel2.inside(gpslat, long: gpslong, lat_circle: clat, long_circle: clong, radius: zoom_m_diagonal) {
            let (x, y) = GPSModel2.to_raster(gpslat, long: gpslong, clat: clat, clong: clong, heading: screen_heading,
                                             zoom_height: zoom_height, scrh: scrh, scrw: scrw,
                                             longitude_proportion: longitude_latitude_proportion)
            canvas.send_pos(x, y: y, accuracy: CGFloat(accuracy_px))
            if debug {
                NSLog("My position %f %f translated to %f,%f", clat, clong, x, y)
            }
        } else {
            canvas.send_pos(CGFloat.NaN, y: CGFloat.NaN, accuracy: 0)
            if debug {
                NSLog("My position %f %f not in space", clat, clong)
            }
        }
        
        var targets: [(CGFloat, CGFloat)] = []
        for tgt in 0..<GPSModel2.model().target_count() {
            let tlat = GPSModel2.model().target_latitude(tgt)
            let tlong = GPSModel2.model().target_longitude(tgt)
            if GPSModel2.inside(tlat, long: tlong, lat_circle: clat, long_circle: clong, radius: zoom_m_diagonal) {
                let (x, y) = GPSModel2.to_raster(tlat, long: tlong, clat: clat, clong: clong, heading: screen_heading, zoom_height: zoom_height, scrh: scrh, scrw: scrw,
                                                 longitude_proportion: longitude_latitude_proportion)
                targets.append(x, y)
                if debug {
                    NSLog("Target[%d] %f %f translated to %f,%f", tgt, tlat, tlong, x, y)
                }
            } else {
                if debug {
                    NSLog("Target[%d] %f %f not in space", tgt, tlat, tlong)
                }
            }
        }
        canvas.send_targets(targets)
        
        GPSModel2.model().releas()
        
        if immediately {
            // do not animate changes
            canvas.update_immediately()
        }
        
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
            
            // radius, in meters, of a circle occupying the width of the screen
            let dzoom = zoom_in_widthradius_m(new_zoom_factor)
            // check whether at least one target, or all targets, fit in current zoom
            
            ok = all_targets
            for tgt in 0..<GPSModel2.model().target_count() {
                let tlat = GPSModel2.model().target_latitude(tgt)
                let tlong = GPSModel2.model().target_longitude(tgt)
                if GPSModel2.inside(tlat, long: tlong, lat_circle: clat, long_circle: clong, radius: dzoom) {
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
            }
        }
        
        zoom_factor = new_zoom_factor
        zoom_factor = max(zoom_factor, zoom_min)
        zoom_factor = min(zoom_factor, zoom_max)
        
        repaint(true)
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
            
            var dx = new_point.x - touch_point!.x
            var dy = new_point.y - touch_point!.y
            
            // convert to a polar vector
            let dabs = hypot(dx, dy)
            var dangle = CGFloat(atan2(dy, dx))
            // take into account the current screen heading
            dangle += CGFloat(screen_heading)
            // recalculate cartesian vector
            dx = cos(dangle) * dabs
            dy = sin(dangle) * dabs
            
            touch_point = new_point
            
            // NSLog("Drag moved by %f %f", dx, dy)
            if center_lat.isNaN {
                center_lat = gpslat
                center_long = gpslong
            }
            
            // zoom = measurement of latitude
            let dzoom = zoom_in_degrees(zoom_factor)
            
            // FIXME check if this holds when screen heading is tilted
            center_long += dzoom * width_height_proportion / longitude_latitude_proportion * (Double(-dx) / scrw)
            center_lat += dzoom * (Double(dy) / scrh)
            
            // do not allow latitude above the Mercator reasonable limit
            center_lat = min(max_latitude, center_lat)
            center_lat = max(-max_latitude, center_lat)
            
            // handle cross of 180W meridian, normalize longitude
            center_long = GPSModel2.normalize_longitude(center_long)
            
            recenter()
            repaint(true)
            
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
        repaint(true)
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
    
    @IBAction func tgd_button(sender: AnyObject)
    {
        NSLog("tgd")
        tgt_dist = !tgt_dist
        repaint(false)
    }
    
    @IBAction func mod_button(sender: AnyObject)
    {
        mode += 1
        mode %= MODE_COUNT
        repaint(false)
    }
    
    @IBAction func tgt_button(sender: AnyObject)
    {
        current_target += 1
        if current_target >= GPSModel2.model().target_count() {
            current_target = -1
        }
        repaint(false)
    }
    
    @IBAction func backToMain(sender: UIStoryboardSegue)
    {
    }
}

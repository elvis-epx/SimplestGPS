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
    var scrw = CGFloat.NaN
    var scrh = CGFloat.NaN
    var width_height_proportion = CGFloat.NaN
    var diag_height_proportion = CGFloat.NaN
    
    let MODE_MAPONLY = 0
    let MODE_MAPCOMPASS = 1
    let MODE_MAPHEADING = 2
    let MODE_COMPASS = 3
    let MODE_HEADING = 4
    let MODE_COUNT = 5
    
    var mode = 1
    var tgt_dist = true
    
    // in seconds of latitude degree across the screen height
    var zoom_factor: CGFloat = 30
    let zoom_min: CGFloat = 30
    let zoom_step: CGFloat = 1.25
    let zoom_max: CGFloat = 3600
    
    // we assume that maps have Mercator projection so we cannot go down to 90 degrees either
    let max_latitude = CGFloat(90.0 - 5.0 - 3600 / 3600.0)
    
    // Screen position (NaN = center follows GPS position)
    var center_lat = CGFloat.NaN
    var center_long = CGFloat.NaN
    var touch_point: CGPoint? = nil
    
    // Current list of maps on screen
    var current_maps: [String:MapDescriptor] = [:]
    var last_map_update: Double = 0;
    
    // Screen position for painting purposes (either screen position or GPS position)
    var clat = CGFloat.NaN
    var clong = CGFloat.NaN
    var longitude_latitude_proportion: CGFloat = 1
    
    // Most current GPS position
    var gpslat = CGFloat.NaN
    var gpslong = CGFloat.NaN
    
    var current_target = -1
    var update_timer: NSTimer? = nil
    
    var debug = false
    
    func do_zoomauto(all_targets: Bool)
    {
        // NSLog("zoom auto")
        calculate_zoom(all_targets)
    }
    
    func do_centerme()
    {
        // NSLog("center me")
        center_lat = CGFloat.NaN
        center_long = CGFloat.NaN
        recenter()
        repaint(false, gesture: false)
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
        update_timer = NSTimer(timeInterval: 0.33, target: self,
                               selector: #selector(MapViewController.update),
                        userInfo: nil, repeats: true)
        NSRunLoop.currentRunLoop().addTimer(update_timer!, forMode: NSRunLoopCommonModes)
    }
    
    override func viewWillLayoutSubviews() {
        // NSLog("     map layout")
        scrw = canvas.bounds.size.width
        scrh = canvas.bounds.size.height
        width_height_proportion = scrw / scrh
        diag_height_proportion = sqrt(scrw * scrw + scrh * scrh) / scrh
    }
    
    override func viewWillDisappear(animated: Bool) {
        NSLog("     map will disappear")
        super.viewWillDisappear(animated)
        GPSModel2.model().delObs(self)
        if update_timer != nil {
            update_timer!.invalidate()
            update_timer = nil
        }
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
        gpslat = CGFloat(GPSModel2.model().latitude())
        gpslong = CGFloat(GPSModel2.model().longitude())
        
        recenter()
        repaint(false, gesture: false)
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
        
        longitude_latitude_proportion = GPSModel2.longitude_proportion_cgfloat(clat)
        if longitude_latitude_proportion.isNaN {
            longitude_latitude_proportion = 1
        }
    }
    
    func zoom_in_degrees(x: CGFloat) -> CGFloat
    {
        // zoom is in seconds, convert to degrees
        return x / 3600.0
    }
    
    func zoom_in_widthradius_m(x: CGFloat) -> CGFloat
    {
        return width_height_proportion * zoom_in_heightradius_m(x)
    }
    
    func zoom_in_heightradius_m(x: CGFloat) -> CGFloat
    {
        // zoom is in latitude seconds, convert to minutes, then to distance
        return 1853.0 * x / 60.0 / 2.0
    }
    
    func zoom_in_diagradius_m(x: CGFloat) -> CGFloat
    {
        return diag_height_proportion * zoom_in_heightradius_m(x)
    }
    
    func to_raster(lat: CGFloat, long: CGFloat, clat: CGFloat, clong: CGFloat,
                         lat_height: CGFloat, scrh: CGFloat, scrw: CGFloat,
                         longitude_proportion: CGFloat)
        -> (CGFloat, CGFloat)
    {
        var _long = GPSModel2.normalize_longitude_cgfloat(long)
        var _clong = GPSModel2.normalize_longitude_cgfloat(clong)
        if GPSModel2.nearer_180_cgfloat(_long, b: _clong) {
            _long = GPSModel2.offset_180_cgfloat(_long)
            _clong = GPSModel2.offset_180_cgfloat(_clong)
        }
        // find distance from center point, in pixels
        let dlat = scrh * -(lat - clat) / lat_height
        let dlong = scrh * longitude_proportion * (_long - _clong) / lat_height
        return (dlong, dlat)
    }
    
    func repaint(immediately: Bool, gesture: Bool)
    {
        if clat.isNaN {
            return
        }
        
        if !GPSModel2.model().hold() {
            return
        }
        
        if !gesture {
            scale.hidden = (mode == MODE_COMPASS || mode == MODE_HEADING)
            // latitude.hidden = !(mode == MODE_COMPASS || mode == MODE_HEADING)
            // longitude.hidden = !(mode == MODE_COMPASS || mode == MODE_HEADING)
            // accuracy.hidden = !(mode == MODE_COMPASS || mode == MODE_HEADING)
            
            // send compass data
            var targets_compass: [(heading: CGFloat, name: String, distance: String)] = []
            for tgt in 0..<GPSModel2.model().target_count() {
                targets_compass.append((
                    heading: CGFloat(GPSModel2.model().target_heading(tgt)),
                    name: GPSModel2.model().target_name(tgt),
                    distance: GPSModel2.model().target_distance_formatted(tgt)))
            }
            if current_target >= targets_compass.count {
                current_target = -1
            }
            canvas.send_compass(mode,
                                heading: CGFloat(GPSModel2.model().heading()),
                                altitude: GPSModel2.model().altitude_formatted(),
                                speed: GPSModel2.model().speed_formatted(),
                                current_target: current_target,
                                targets: targets_compass,
                                tgt_dist: tgt_dist)
        }
        
        let zoom_m_diagonal = zoom_in_heightradius_m(zoom_factor)
        let zoom_height = zoom_in_degrees(zoom_factor)
        let zoom_width = zoom_height / longitude_latitude_proportion * width_height_proportion
        if debug {
            NSLog("Coordinate space is lat %f long %f radius %f", clat, clong, zoom_m_diagonal)
        }
        
        let scale_m = 2 * zoom_in_widthradius_m(zoom_factor)
        
        if !gesture {
            scale.text = GPSModel2.format_distance_t(Double(scale_m),
                                                    met: GPSModel2.model().get_metric())
            latitude.text = GPSModel2.model().latitude_formatted()
            longitude.text = GPSModel2.model().longitude_formatted()
            altitude.text = GPSModel2.model().altitude_formatted()
            accuracy.text = GPSModel2.model().accuracy_formatted()
        }
        
        let accuracy_px = scrw * CGFloat(GPSModel2.model().horizontal_accuracy()) / scale_m
        
        var map_list_changed = false
        
        let now = NSDate().timeIntervalSince1970
        if last_map_update == 0 {
            last_map_update = now - 0.5
        }
        
        if !gesture && (now - last_map_update) > 0.5 {
            // only recalculate map list when we are not in a hurry
            last_map_update = now

            if mode == MODE_COMPASS || mode == MODE_HEADING {
                if current_maps.count > 0 {
                    current_maps = [:]
                    map_list_changed = true
                    MapModel.model().get_maps_force_refresh()
                }
            } else {
                let new_list = MapModel.model().get_maps(Double(clat),
                                                  clong: Double(clong),
                                                  radius: Double(zoom_m_diagonal),
                                                  latheight: Double(zoom_height))
                if new_list != nil {
                    map_list_changed = true
                    current_maps = new_list!
                }
            }
        }
        
        for (_, map) in current_maps {
            (map.centerx, map.centery) = to_raster(
                    CGFloat(map.midlat), long: CGFloat(map.midlong),
                    clat: clat, clong: clong,
                    lat_height: zoom_height, scrh: scrh, scrw: scrw,
                    longitude_proportion: longitude_latitude_proportion)
                
            map.boundsx = CGFloat(scrw * CGFloat(map.longwidth) / zoom_width)
            map.boundsy = CGFloat(scrh * CGFloat(map.latheight) / zoom_height)
        }
        
        if !canvas.send_img(current_maps, changed: map_list_changed) {
            MapModel.model().get_maps_force_refresh()
        }

        // point relative 0,0 = screen center
        let (xrel, yrel) = to_raster(gpslat, long: gpslong, clat: clat, clong: clong,
                                             lat_height: zoom_height, scrh: scrh, scrw: scrw,
                                             longitude_proportion: longitude_latitude_proportion)
        canvas.send_pos_rel(xrel, yrel: yrel, accuracy: CGFloat(accuracy_px))

        /*
        NSLog("My position %f %f translated to rel %f,%f", clat, clong, xrel, yrel)
        */
        
        var targets: [(CGFloat, CGFloat)] = []
        for tgt in 0..<GPSModel2.model().target_count() {
            let tlat = GPSModel2.model().target_latitude(tgt)
            let tlong = GPSModel2.model().target_longitude(tgt)
            if GPSModel2.inside(tlat, long: tlong,
                                lat_circle: Double(clat),
                                long_circle: Double(clong),
                                radius: Double(zoom_m_diagonal)) {
                /* point relative 0,0 = screen center */
                let (xrel, yrel) = to_raster(CGFloat(tlat), long: CGFloat(tlong),
                                             clat: clat, clong: clong,
                                             lat_height: zoom_height, scrh: scrh, scrw: scrw,
                                             longitude_proportion: longitude_latitude_proportion)
                targets.append(xrel, yrel)
                if debug {
                    NSLog("Target[%d] %f %f translated to rel %f,%f", tgt, tlat, tlong, xrel, yrel)
                }
            } else {
                if debug {
                    NSLog("Target[%d] %f %f not in space", tgt, tlat, tlong)
                }
            }
        }
        canvas.send_targets_rel(targets)
        
        GPSModel2.model().releas()
        
        if immediately {
            // do not animate changes
            canvas.update_immediately()
        }
        
        if debug {
            NSLog("Painted with %d maps", current_maps.count)
        }
    }
    
    func calculate_zoom(all_targets: Bool)
    {
        if scrw.isNaN || gpslat.isNaN || GPSModel2.model().target_count() <= 0 {
            return
        }
        
        // force current position in center
        center_lat = CGFloat.NaN
        center_long = CGFloat.NaN
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
                if GPSModel2.inside(tlat, long: tlong, lat_circle: Double(clat),
                                    long_circle: Double(clong),
                                    radius: Double(dzoom)) {
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
        
        repaint(true, gesture: false)
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
            var dangle = atan2(dy, dx)
            // take into account the current screen heading
            dangle -= canvas.current_heading()
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
            
            center_long += dzoom * width_height_proportion / longitude_latitude_proportion * ((-dx) / scrw)
            center_lat += dzoom * dy / scrh
            
            // do not allow latitude above the Mercator reasonable limit
            center_lat = min(max_latitude, center_lat)
            center_lat = max(-max_latitude, center_lat)
            
            // handle cross of 180W meridian, normalize longitude
            center_long = GPSModel2.normalize_longitude_cgfloat(center_long)
            
            recenter()
            repaint(true, gesture: true)
            
        default:
            break
        }
    }
    
    func pinch(rec:UIPinchGestureRecognizer)
    {
        zoom_factor /= rec.scale
        zoom_factor = max(zoom_factor, zoom_min)
        zoom_factor = min(zoom_factor, zoom_max)
        rec.scale = 1.0
        repaint(true, gesture: true)
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
        repaint(false, gesture: false)
    }
    
    @IBAction func mod_button(sender: AnyObject)
    {
        mode += 1
        mode %= MODE_COUNT
        repaint(false, gesture: false)
    }
    
    @IBAction func tgt_button(sender: AnyObject)
    {
        current_target += 1
        if current_target >= GPSModel2.model().target_count() {
            current_target = -1
        }
        repaint(false, gesture: false)
    }
    
    @IBAction func backToMain(sender: UIStoryboardSegue)
    {
    }
}

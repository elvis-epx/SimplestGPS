//
//  TargetViewController.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 10/2/15.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

enum Mode: Int {
    case MAP = 0
    case MAPCOMPASS = 1
    case COMPASS = 2
    case MAP_H = 3
    case MAPCOMPASS_H = 4
    case COMPASS_H = 5
}

@objc class MapViewController: UIViewController, ModelListener
{
    @IBOutlet weak var canvas: MapCanvasView!
    @IBOutlet weak var scale: UILabel!
    
    @IBOutlet weak var new_target: UIButton!
    @IBOutlet weak var thf_b: UIButton!
    @IBOutlet weak var tgt_b: UIButton!
    @IBOutlet weak var mod_b: UIButton!
    
    @IBOutlet weak var accuracy: UILabel!
    @IBOutlet weak var longitude: UILabel!
    @IBOutlet weak var latitude: UILabel!
    var scrw = CGFloat.NaN
    var scrh = CGFloat.NaN
    var width_height_proportion = CGFloat.NaN
    var diag_height_proportion = CGFloat.NaN
    
    var mode: Mode = .MAPCOMPASS
    let next_mode = [Mode.MAP: Mode.MAPCOMPASS,
                     Mode.MAPCOMPASS: Mode.COMPASS,
                     Mode.COMPASS: Mode.MAP_H,
                     Mode.MAP_H: Mode.MAPCOMPASS_H,
                     Mode.MAPCOMPASS_H: Mode.COMPASS_H,
                     Mode.COMPASS_H: Mode.MAP]
    let next_mode_nomap = [Mode.MAP: Mode.COMPASS,
                           Mode.MAP_H: Mode.COMPASS,
                           Mode.MAPCOMPASS: Mode.COMPASS,
                           Mode.MAPCOMPASS_H: Mode.COMPASS,
                           Mode.COMPASS_H: Mode.COMPASS,
                           Mode.COMPASS: Mode.COMPASS_H]
    let int_to_mode = [Mode.MAP.rawValue: Mode.MAP,
                       Mode.MAPCOMPASS.rawValue: Mode.MAPCOMPASS,
                       Mode.COMPASS.rawValue: Mode.COMPASS,
                       Mode.MAP_H.rawValue: Mode.MAP_H,
                       Mode.MAPCOMPASS_H.rawValue: Mode.MAPCOMPASS_H,
                       Mode.COMPASS_H.rawValue: Mode.COMPASS_H]
    let mode_name: [Mode:String] = [.MAP: "", .MAPCOMPASS: "", .COMPASS: "",
                                    .MAP_H: "Follows heading",
                                    .MAPCOMPASS_H: "Follows heading",
                                    .COMPASS_H: "Follows heading"]
    var tgt_dist = 1
    var blink = 1
    
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
    var last_label_target = -1
    var last_label_update: NSDate? = nil
    var label_status = 0
    
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
        
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(MapViewController.tgt_longpress(_:)))
        self.tgt_b.addGestureRecognizer(lp)
    }
    
    override func viewDidAppear(animated: Bool) {
        if GPSModel2.model().show_welcome() {
            let alert = UIAlertController(title: "Welcome!", message: "If you need instructions about this app, press 'PIN' at lower left corner, then 'Help' at the bottom.", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        NSLog("     map will appear")
        super.viewWillAppear(animated)
        GPSModel2.model().addObs(self)
        update_timer = NSTimer(timeInterval: 0.33, target: self,
                               selector: #selector(MapViewController.update),
                        userInfo: nil, repeats: true)
        NSRunLoop.currentRunLoop().addTimer(update_timer!, forMode: NSRunLoopCommonModes)
        
        if int_to_mode[GPSModel2.model().get_mode()] != nil {
            mode = int_to_mode[GPSModel2.model().get_mode()]!
        }
        tgt_dist = GPSModel2.model().get_tgtdist() % 2
        blink = GPSModel2.model().get_blink() % 2
        current_target = GPSModel2.model().get_currenttarget()
        if current_target >= GPSModel2.model().target_count() {
            current_target = -1
        }
        zoom_factor = CGFloat(GPSModel2.model().get_zoom())
        zoom_factor = max(zoom_factor, zoom_min)
        zoom_factor = min(zoom_factor, zoom_max)

        if !MapModel.model().are_there_maps() {
            if mode == .MAP || mode == .MAPCOMPASS {
                mode = .COMPASS
            } else if mode == .MAP_H || mode == .MAPCOMPASS_H {
                mode = .COMPASS_H
            }
        }
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
        // find distance from center point, in pixels
        let dlat = scrh * -(lat - clat) / lat_height
        let dlong = scrh * longitude_proportion
                    * GPSModel2.longitude_minus(long, minus: clong)
                    / lat_height
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

        let cur_heading = CGFloat(GPSModel2.model().heading())

        if !gesture {
            // scale.hidden = (mode == .COMPASS || mode == .COMPASS_H)

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
            
            // send compass data
            canvas.send_compass(mode,
                                heading: cur_heading,
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
            var stext = self.mode_name[self.mode]!
            if self.mode != .COMPASS && self.mode != .COMPASS_H {
                stext = GPSModel2.format_distance_t(Double(scale_m),
                                    met: GPSModel2.model().get_metric()) +
                    (stext.isEmpty ? "" : " - ") + stext
            }
            scale.text = stext
            latitude.text = GPSModel2.model().latitude_formatted()
            longitude.text = GPSModel2.model().longitude_formatted()
            accuracy.text = GPSModel2.model().altitude_formatted() + "↑ " +
                GPSModel2.model().accuracy_formatted()
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

            if mode == .COMPASS || mode == .COMPASS_H {
                if current_maps.count > 0 {
                    current_maps = [:]
                    map_list_changed = true
                    MapModel.model().get_maps_force_refresh()
                }
            } else {
                let new_list = MapModel.model().get_maps(Double(clat),
                                                  clong: Double(clong),
                                                  radius: Double(zoom_m_diagonal),
                                                  screenh: Double(zoom_height))
                if new_list != nil {
                    map_list_changed = true
                    current_maps = new_list!
                }
            }
        }
        
        for (_, map) in current_maps {
            // center of the whole map, not of the current crop
            // this one is 'stable' even if map crop size changes
            (map.vcenterx, map.vcentery) = to_raster(
                    CGFloat(map.omidlat), long: CGFloat(map.omidlong),
                    clat: clat, clong: clong,
                    lat_height: zoom_height, scrh: scrh, scrw: scrw,
                    longitude_proportion: longitude_latitude_proportion)
            
            // rasterized offset from whole map's corner to crop corner
            // this changes abruptly as map is cropped
            (map.offsetx, map.offsety) = to_raster(
                CGFloat(map.curmidlat), long: CGFloat(map.curmidlong),
                clat: clat, clong: clong,
                lat_height: zoom_height, scrh: scrh, scrw: scrw,
                longitude_proportion: longitude_latitude_proportion)
            map.offsetx -= map.vcenterx
            map.offsety -= map.vcentery
            map.offsetx *= -1
            map.offsety *= -1
            
            map.boundsx = CGFloat(scrw * CGFloat(map.curlongwidth) / zoom_width)
            map.boundsy = CGFloat(scrh * CGFloat(map.curlatheight) / zoom_height)
        }
        
        if !canvas.send_img(current_maps, changed: map_list_changed) {
            MapModel.model().get_maps_force_refresh()
        }

        // point relative 0,0 = screen center
        let (xrel, yrel) = to_raster(gpslat, long: gpslong, clat: clat, clong: clong,
                                             lat_height: zoom_height, scrh: scrh, scrw: scrw,
                                             longitude_proportion: longitude_latitude_proportion)
        canvas.send_pos_rel(xrel, yrel: yrel, accuracy: CGFloat(accuracy_px),
                            locked: (clat == gpslat && clong == gpslong),
                            blink: blink)

        /*
        NSLog("My position %f %f translated to rel %f,%f", clat, clong, xrel, yrel)
        */
        
        var targets: [(CGFloat, CGFloat, CGFloat)] = []
        var label_x = CGFloat.NaN
        var label_y = CGFloat.NaN
        var changed_label = false
        var presenting_label = false
        var label_name = ""
        var label_distance = ""
        
        for tgt in 0..<GPSModel2.model().target_count() {
            let tlat = GPSModel2.model().target_latitude(tgt)
            let tlong = GPSModel2.model().target_longitude(tgt)
            let tangle1 = CGFloat(GPSModel2.model().target_heading(tgt) * M_PI / 180.0)
            let tangle = CGFloat(M_PI) + tangle1
            if GPSModel2.inside(tlat, long: tlong,
                                lat_circle: Double(clat),
                                long_circle: Double(clong),
                                radius: Double(zoom_m_diagonal)) {
                /* point relative 0,0 = screen center */
                let (xrel, yrel) = to_raster(CGFloat(tlat), long: CGFloat(tlong),
                                             clat: clat, clong: clong,
                                             lat_height: zoom_height, scrh: scrh, scrw: scrw,
                                             longitude_proportion: longitude_latitude_proportion)
                targets.append((xrel, yrel, tangle))
                if debug {
                    NSLog("Target[%d] %f %f translated to rel %f,%f", tgt, tlat, tlong, xrel, yrel)
                }
            } else {
                if debug {
                    NSLog("Target[%d] %f %f not in space", tgt, tlat, tlong)
                }
            }
            if tgt == current_target {
                label_x = 0
                label_y = 0
                if !gesture {
                    // streamline processing during drag
                    label_name = GPSModel2.model().target_name(tgt)
                    label_distance = GPSModel2.model().target_distance_formatted(tgt)
                }
                if last_label_target != current_target {
                    changed_label = true
                    presenting_label = true
                    last_label_target = current_target
                    last_label_update = NSDate().dateByAddingTimeInterval(2)
                    label_status = 1
                } else if label_status == 1 {
                    presenting_label = true
                    if NSDate().compare(last_label_update!) == .OrderedDescending {
                        label_status = 2
                    }
                } else if label_status == 2 {
                    // FIXME angle when cur_heading != 0
                    let (xrel, yrel) = to_raster(CGFloat(tlat), long: CGFloat(tlong),
                                                 clat: clat, clong: clong,
                                                lat_height: zoom_height, scrh: scrh, scrw: scrw,
                                                longitude_proportion: longitude_latitude_proportion)
                    if mode == .MAP_H {
                        // convert to polar, rotate, back to cartesian
                        // this is calculated manually since the label does not belong to map canvas
                        // and does not rotate along with maps and crosshairs
                        let phi = atan2(yrel, xrel) - cur_heading * CGFloat(M_PI / 180.0)
                        let vlen = hypot(xrel, yrel)
                        label_x = vlen * cos(phi)
                        label_y = vlen * sin(phi)
                    } else {
                        label_x = xrel
                        label_y = yrel
                    }
                }
            }
        }
        
        if label_x != label_x {
            last_label_target = -1
            label_status = 0
        }
        
        if !canvas.send_targets_rel(targets,
                                label_x: label_x,
                                label_y: label_y,
                                changed_label: changed_label,
                                presenting_label: presenting_label,
                                gesture: gesture,
                                label_name: label_name,
                                label_distance: label_distance,
                                blink: blink) {
            // needs to send again
            last_label_target = -1
        }
        
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
        GPSModel2.model().set_zoom(Double(zoom_factor))
        
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
            dangle -= canvas.curr_screen_rotation()
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
            
            center_long = GPSModel2.handle_cross_180(center_long)
            
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
        GPSModel2.model().set_zoom(Double(zoom_factor))
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
        NSLog("TGD button")
        if mode == Mode.MAP || mode == Mode.MAP_H {
            blink += 1
            blink %= 2
            GPSModel2.model().set_blink(blink)
        } else {
            tgt_dist += 1
            tgt_dist %= 2
            GPSModel2.model().set_tgtdist(tgt_dist)
        }
        repaint(false, gesture: false)
    }
    
    @IBAction func mod_button(sender: AnyObject)
    {
        if MapModel.model().are_there_maps() {
            mode = next_mode[mode]!
        } else {
            mode = next_mode_nomap[mode]!
        }
        GPSModel2.model().set_mode(mode.rawValue)
        repaint(false, gesture: false)
    }
    
    @IBAction func tgt_button(sender: AnyObject)
    {
        current_target += 1
        if current_target >= GPSModel2.model().target_count() {
            current_target = -1
        }
        GPSModel2.model().set_currenttarget(current_target)
        repaint(false, gesture: false)
    }
    
    func tgt_longpress(guesture: UILongPressGestureRecognizer) {
        current_target = -1
        GPSModel2.model().set_currenttarget(current_target)
        repaint(false, gesture: false)
    }
    
    @IBAction func backToMain(sender: UIStoryboardSegue)
    {
    }
}

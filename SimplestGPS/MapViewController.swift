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

    var maps: [(UIImage, Double, Double, Double, Double)] = [];
    var scrw: CGFloat = 0;
    var scrh: CGFloat = 0;
 
    @IBAction func do_zoomin(sender: AnyObject?)
    {
        NSLog("zoom in")
    }
 
    @IBAction func do_zoomout(sender: AnyObject?)
    {
        NSLog("zoom out")
    }

    @IBAction func do_zoomauto(sender: AnyObject?)
    {
        NSLog("zoom auto")
    }
    
    @IBAction func do_centerme(sender: AnyObject?)
    {
        NSLog("center me")
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
                    maps.append((img, coords.lat - coords.latheight, coords.lat, coords.long, coords.long + coords.longwidth))
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
        scrw = canvas.bounds.size.width
        scrh = canvas.bounds.size.height
        
        canvas.send_pos(scrw / 2, y: scrh / 2)
        canvas.send_targets([(CGFloat(10), CGFloat(10)), (CGFloat(scrw / 4), CGFloat(scrh / 4))])
        
        var plot: [(UIImage, CGFloat, CGFloat, CGFloat, CGFloat)] = []
        for map in maps {
            plot.append((map.0, 0, 0, scrw, scrh))
        }
        canvas.send_img(plot)
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
    }
}
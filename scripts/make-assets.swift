import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func canvas(_ w: Int, _ h: Int, draw: (CGContext) -> Void) -> CGImage {
    let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(context)
    return context.makeImage()!
}
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red:r,green:g,blue:b,alpha:a) }
func rounded(_ c: CGContext, _ rect: CGRect, _ radius: CGFloat, _ fill: CGColor) {
    c.setFillColor(fill); c.addPath(CGPath(roundedRect:rect,cornerWidth:radius,cornerHeight:radius,transform:nil)); c.fillPath()
}
func save(_ img: CGImage, to url: URL, type: UTType = .png, properties: [CFString:Any] = [:]) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, properties as CFDictionary)
    precondition(CGImageDestinationFinalize(dest))
}
let icon = canvas(1024,1024) { c in
    rounded(c, CGRect(x:64,y:64,width:896,height:896), 206, color(0.04,0.30,0.29))
    c.saveGState()
    c.setShadow(offset:CGSize(width:0,height:-20),blur:35,color:color(0,0,0,0.25))
    rounded(c, CGRect(x:240,y:230,width:552,height:580), 68, color(0.87,0.93,0.85))
    c.restoreGState()
    rounded(c, CGRect(x:294,y:320,width:444,height:432), 30, color(0.70,0.83,0.75))
    c.saveGState(); c.addPath(CGPath(roundedRect:CGRect(x:294,y:320,width:444,height:432),cornerWidth:30,cornerHeight:30,transform:nil));c.clip()
    c.setFillColor(color(0.99,0.77,0.42));c.fillEllipse(in:CGRect(x:572,y:572,width:106,height:106))
    c.setFillColor(color(0.18,0.49,0.42));c.move(to:CGPoint(x:280,y:360));c.addLine(to:CGPoint(x:460,y:630));c.addLine(to:CGPoint(x:660,y:320));c.closePath();c.fillPath()
    c.setFillColor(color(0.07,0.36,0.33));c.move(to:CGPoint(x:480,y:320));c.addLine(to:CGPoint(x:640,y:542));c.addLine(to:CGPoint(x:810,y:300));c.closePath();c.fillPath();c.restoreGState()
    c.setStrokeColor(color(0.94,0.73,0.39));c.setLineWidth(42);c.setLineCap(.round)
    c.move(to:CGPoint(x:704,y:213));c.addLine(to:CGPoint(x:808,y:320));c.strokePath()
    c.saveGState();c.setShadow(offset:CGSize(width:0,height:-8),blur:18,color:color(0,0,0,0.2))
    c.setFillColor(color(0.97,0.95,0.87));c.fillEllipse(in:CGRect(x:569,y:246,width:206,height:206));c.restoreGState()
    c.setStrokeColor(color(0.07,0.40,0.33));c.setLineWidth(19)
    c.move(to:CGPoint(x:622,y:348));c.addLine(to:CGPoint(x:657,y:313));c.addLine(to:CGPoint(x:718,y:386));c.strokePath()
}
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try FileManager.default.createDirectory(at:iconset,withIntermediateDirectories:true)
for points in [16,32,128,256,512] {
    for scale in [1,2] {
        let size=points*scale
        let resized=canvas(size,size) { $0.interpolationQuality = .high; $0.draw(icon,in:CGRect(x:0,y:0,width:size,height:size)) }
        save(resized,to:iconset.appendingPathComponent("icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"))
    }
}
save(icon,to:root.appendingPathComponent("docs/icon.png"))

let fixtures=root.appendingPathComponent("evidence/fixtures")
try FileManager.default.createDirectory(at:fixtures,withIntermediateDirectories:true)
for index in 0..<3 {
    let w=2400, h=index == 1 ? 3000 : 1600
    let img=canvas(w,h) { c in
        let palette:[CGColor] = [color(0.77,0.87,0.85),color(0.93,0.81,0.70),color(0.74,0.81,0.91)]
        c.setFillColor(palette[index]);c.fill(CGRect(x:0,y:0,width:w,height:h))
        c.setFillColor(color(1,0.93,0.68));c.fillEllipse(in:CGRect(x:1550,y:h-650,width:360,height:360))
        for layer in 0..<4 {
            c.setFillColor(color(CGFloat(0.08+Double(layer)*0.035),CGFloat(0.25+Double(layer)*0.09),CGFloat(0.28+Double(layer)*0.085)))
            c.move(to:CGPoint(x:0,y:0));c.addLine(to:CGPoint(x:0,y:CGFloat(h)*0.48-CGFloat(layer*150)))
            let end = CGPoint(x:CGFloat(w), y:CGFloat(h)*0.62-CGFloat(layer*170))
            let control1 = CGPoint(x:600, y:CGFloat(h)*0.9-CGFloat(layer*190))
            let control2 = CGPoint(x:1200, y:CGFloat(h)*0.12+CGFloat(layer*50))
            c.addCurve(to:end, control1:control1, control2:control2)
            c.addLine(to:CGPoint(x:w,y:0));c.closePath();c.fillPath()
        }
        for i in 0..<12 {
            c.setStrokeColor(color(0.95,0.94,0.82,0.10));c.setLineWidth(3)
            c.move(to:CGPoint(x:200+i*140,y:120+i*29));c.addLine(to:CGPoint(x:320+i*140,y:120+i*29));c.strokePath()
        }
    }
    var props: [CFString:Any] = [:]
    if index==0 {
        props[kCGImagePropertyGPSDictionary] = [kCGImagePropertyGPSLatitude:37.0,kCGImagePropertyGPSLatitudeRef:"N",kCGImagePropertyGPSLongitude:127.0,kCGImagePropertyGPSLongitudeRef:"E"]
        props[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal:"2020:01:02 03:04:05",kCGImagePropertyExifUserComment:"Synthetic fixture only"]
        props[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFArtist:"Synthetic artist",kCGImagePropertyTIFFMake:"Test camera"]
    }
    save(img,to:fixtures.appendingPathComponent(["01-coastal-morning.jpg","02-sandstone.png","03-blue-hour.jpg"][index]),type:index == 1 ? .png : .jpeg,properties:props)
}
print("Icon and three synthetic landscape fixtures generated.")

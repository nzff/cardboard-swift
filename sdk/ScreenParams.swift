
import UIKit

extension UIScreen
{
    func orientationAwareSize() -> CGSize
    {
        let screenSize = self.bounds.size
        
        if NSFoundationVersionNumber <= NSFoundationVersionNumber10_7_1 && UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication().statusBarOrientation)
        {
            return CGSizeMake(screenSize.height, screenSize.width)
        }
        
        return screenSize;
    }
    
    func sizeFixedToPortrait() -> CGSize
    {
        let screenSize = self.bounds.size
        
        return CGSizeMake(min(screenSize.width, screenSize.height), max(screenSize.width,screenSize.height))
    }
}

class ScreenParams
{
    var screen:UIScreen = UIScreen()
    
    var scale:CGFloat = CGFloat(1)
    
    var xMetersPerPixel:Float = 0
    var yMetersPerPixel:Float = 0
    
    var borderSizeMeters:Float = 0
    
    let correctIphoneViewport:Bool = true
    
    init()
    {
        
    }
    
    init(screenParams: ScreenParams)
    {
        self.scale = screenParams.scale;
        self.xMetersPerPixel = screenParams.xMetersPerPixel;
        self.yMetersPerPixel = screenParams.yMetersPerPixel;
        self.borderSizeMeters = screenParams.borderSizeMeters;
    }
    
    init(deviceScreen:UIScreen)
    {
        screen = deviceScreen;
        
        scale = deviceScreen.nativeScale
        
        let screenPixelsPerInch:Float = pixelsPerInch(screen);
        
        let metersPerInch:Float = 0.0254;
        let defaultBorderSizeMeters:Float = 0.001;
        
        xMetersPerPixel = (metersPerInch / screenPixelsPerInch);
        yMetersPerPixel = (metersPerInch / screenPixelsPerInch);
        
        borderSizeMeters = defaultBorderSizeMeters;
    }

    func width() -> Int
    {
        return Int(screen.orientationAwareSize().width * scale)
    }
    
    func height() -> Int
    {
        return Int(screen.orientationAwareSize().height * scale)
    }
    
    func borderSizeInMeters() -> Float
    {
        return borderSizeMeters
    }
    
    func widthInMeters() -> Float
    {
        return Float(width()) * xMetersPerPixel
    }
    
    func heightInMeters() -> Float
    {
        return Float(height()) * yMetersPerPixel
    }
    
    func pixelsPerInch(deviceScreen:UIScreen) -> Float
    {
        // Default iPhone retina pixels per inch
        let pixelsPerInch:Float = 163.0 * Float(scale);
        //todo: the other things
        return pixelsPerInch;
    }
    
}

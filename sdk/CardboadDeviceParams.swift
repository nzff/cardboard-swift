
import Foundation

class CardboardDeviceParams
{
    var vendor:NSString?
    var model:NSString?
    
    var version:NSString?
    
    var interLensDistance:Float = 0.06
    var verticalDistanceToLensCenter:Float = 0.035
    var screenToLensDistance:Float = 0.042
    
    var maximumLeftEyeFOV:FieldOfView = FieldOfView()
    var distortion:Distortion = Distortion()
}
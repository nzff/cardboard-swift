
import UIKit

class HeadMountedDisplay
{
    var screenParams:ScreenParams = ScreenParams()
    var cardboardParams:CardboardDeviceParams = CardboardDeviceParams()
    
    init(screen:UIScreen)
    {
        screenParams = ScreenParams(deviceScreen: screen)
        cardboardParams = CardboardDeviceParams()
    }
}

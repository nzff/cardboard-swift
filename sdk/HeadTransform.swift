
import GLKit

class HeadTransform
{
    var headView: GLKMatrix4 = GLKMatrix4Identity
    
    func translation() -> GLKVector3
    {
        return GLKVector3Make(headView.m.12, headView.m.13, headView.m.14)
    }
    
    func forwardVector() -> GLKVector3
    {
        return GLKVector3Make(-headView.m.8, -headView.m.9, -headView.m.10)
    }
    
    func upVector() -> GLKVector3
    {
        return GLKVector3Make(headView.m.4, headView.m.5, headView.m.6)
    }
    
    func rightVector() -> GLKVector3
    {
        return GLKVector3Make(headView.m.0, headView.m.1, headView.m.2)
    }
    
    func quaternion() -> GLKQuaternion
    {
        let t = headView.m.0 + headView.m.5 + headView.m.10
        
        var s:Float, w:Float, x:Float, y:Float, z:Float
        
        if (t >= 0.0)
        {
            s = sqrtf(t + 1.0)
            w = 0.5 * s
            s = 0.5 / s
            x = (headView.m.9 - headView.m.6) * s
            y = (headView.m.2 - headView.m.8) * s
            z = (headView.m.4 - headView.m.1) * s
        }
        else if ((headView.m.0 > headView.m.5) && (headView.m.0 > headView.m.10))
        {
            s = sqrtf(1.0 + headView.m.0 - headView.m.5 - headView.m.10)
            x = s * 0.5
            s = 0.5 / s
            y = (headView.m.4 + headView.m.1) * s
            z = (headView.m.2 + headView.m.8) * s
            w = (headView.m.9 - headView.m.6) * s
        }
        else if (headView.m.5 > headView.m.10)
        {
            s = sqrtf(1.0 + headView.m.5 - headView.m.0 - headView.m.10)
            y = s * 0.5
            s = 0.5 / s
            x = (headView.m.4 + headView.m.1) * s
            z = (headView.m.9 + headView.m.6) * s
            w = (headView.m.2 - headView.m.8) * s
        }
        else
        {
            s = sqrtf(1.0 + headView.m.10 - headView.m.0 - headView.m.5)
            z = s * 0.5
            s = 0.5 / s
            x = (headView.m.2 + headView.m.8) * s
            y = (headView.m.9 + headView.m.6) * s
            w = (headView.m.4 - headView.m.1) * s
        }
        
        return GLKQuaternionMake(x, y, z, w)
    }
    
    func eulerAngles() -> GLKVector3
    {
        var yaw:Float = 0
        var roll:Float = 0
        let pitch:Float = asinf(headView.m.6)
        
        if (sqrtf(1.0 - headView.m.6 * headView.m.6) >= 0.01)
        {
            yaw = atan2f(-headView.m.2, headView.m.10)
            roll = atan2f(-headView.m.4, headView.m.5)
        }
        else
        {
            yaw = 0.0
            roll = atan2f(headView.m.1, headView.m.0)
        }
        return GLKVector3Make(-pitch, -yaw, -roll)
    }
    
}

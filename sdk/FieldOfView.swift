
import GLKit

class FieldOfView
{
    var left:Float    = 0
    var right:Float   = 0
    var bottom: Float = 0
    var top: Float    = 0
    
    let defaultViewAngle:Float = 40.0
    
    init()
    {
        left = defaultViewAngle
        right = defaultViewAngle
        bottom = defaultViewAngle
        top = defaultViewAngle
    }
    
    init(left:Float, right:Float, bottom:Float, top:Float)
    {
        self.left = left
        self.right = right
        self.bottom = bottom
        self.top = top
    }
    
    init(fov: FieldOfView)
    {
        left = fov.left
        right = fov.right
        bottom = fov.bottom
        top = fov.top
    }
    
    func toPerspectiveMatrix(zNear near:Float, zFar far: Float) -> GLKMatrix4
    {
        let leftFov = -tanf(GLKMathDegreesToRadians(left)) * near
        let rightFov = -tanf(GLKMathDegreesToRadians(right)) * near
        let bottomFov = -tanf(GLKMathDegreesToRadians(bottom)) * near
        let topFov = tanf(GLKMathDegreesToRadians(top)) * near

        let frustrum = GLKMatrix4MakeFrustum(leftFov, rightFov, bottomFov, topFov, near, far)
        
        return frustrum
    }
}

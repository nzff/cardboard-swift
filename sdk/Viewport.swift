
import Foundation
import CoreGraphics
import OpenGLES

class Viewport
{
    var x: Int = 0
    var y: Int = 0

    var width: Int = 0
    var height: Int = 0
    
    func setViewport(x: Int,_ y: Int,_ width: Int,_ height: Int)
    {
        self.x = x
        self.y = y
        
        self.width = width
        self.height = height
    }
    
    func setGLViewport()
    {
        glViewport(GLint(x), GLint(y), GLint(width), GLint(height))
    }
    
    func setGLScissor()
    {
        glScissor(GLint(x), GLint(y), GLint(width), GLint(height))
    }
    
    func toCGRect() -> CGRect
    {
        return CGRectMake(CGFloat(x), CGFloat(y), CGFloat(width) ,CGFloat(height))
    }
}

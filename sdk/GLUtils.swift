
import Foundation
import OpenGLES

func clamp<T: Comparable>(value: T, lower: T, upper: T) -> T
{
    return min(max(value, lower), upper)
}

func BUFFER_OFFSET(i: Int) -> UnsafePointer<Void>
{
    let p: UnsafePointer<Void> = nil
    return p.advancedBy(i)
}

func GLLinkProgram(prog: GLuint) -> Bool
{
    var status: GLint = 0
    
    glLinkProgram(prog)
    
    glGetProgramiv(prog, GLenum(GL_LINK_STATUS), &status)
    
    if status == 0
    {
        return false
    }
    
    return true
}

func GLCheckForError()
{
#if DEBUG
    let err:GLenum = glGetError()

    if err != GLenum(GL_NO_ERROR)
    {
        print("glError: 0x%04X", err)
    }
#endif
}

func GLCompileFromString(inout shader:GLuint, type:GLenum, source:String) -> Bool
{
    let shaderString = source as NSString
    
    shader = glCreateShader(type)
    
    var src:UnsafePointer<Int8>
        
    src = shaderString.UTF8String
    
    var castSrc = UnsafePointer<GLchar>(src)
    
    glShaderSource(shader, 1, &castSrc, nil)
    
    glCompileShader(shader)
    
    return true
}

func GLCompileShaderFromFile(inout shader: GLuint, type: GLenum, file: String) -> Bool
{
    
    var status: GLint = 0
    var source: UnsafePointer<Int8>
    
    do
    {
        source = try NSString(contentsOfFile: file, encoding: NSUTF8StringEncoding).UTF8String
    } catch
    {
        print("Failed to load vertex shader")
        
        return false
    }
    var castSource = UnsafePointer<GLchar>(source)
    
    shader = glCreateShader(type)
    glShaderSource(shader, 1, &castSource, nil)
    glCompileShader(shader)
    
    glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
    
    if status == 0
    {
        glDeleteShader(shader)
        
        return false
    }
    
    return true
}

func GLValidateProgram(prog: GLuint) -> Bool
{
    var logLength: GLsizei = 0
    var status: GLint = 0
    
    glValidateProgram(prog)
    
    glGetProgramiv(prog, GLenum(GL_INFO_LOG_LENGTH), &logLength)
    
    if logLength > 0
    {
        var log: [GLchar] = [GLchar](count: Int(logLength), repeatedValue: 0)
        glGetProgramInfoLog(prog, logLength, &logLength, &log)
        print("Program validate log: \n\(log)")
    }
    
    glGetProgramiv(prog, GLenum(GL_VALIDATE_STATUS), &status)
    
    var returnVal = true
    
    if status == 0
    {
        returnVal = false
    }
    
    return returnVal
}

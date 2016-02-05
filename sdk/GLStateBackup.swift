
import OpenGLES

class GLStateBackup
{
    var viewport:[GLint] = [0, 0, 0, 0]

    var cullFaceEnabled:Bool = true
    var scissorTestEnabled:Bool = true
    var depthTestEnabled:Bool = true
    
    var clearColor:[GLfloat] = [0.0, 0.0, 0.0, 0.0]
    
    var shaderProgram:GLint = -1
    
    var scissorBox:[GLint] = [0, 0, 0, 0]
    
    var activeTexture:GLint = -1
    var texture2DBinding:GLint = -1
    var arrayBufferBinding:GLint = -1
    var elementArrayBufferBinding:GLint = -1
    
    var vertexAttributes:[VertexAttributeState] = [VertexAttributeState]()
    
    func addTrackedVertexAttribute(id:GLuint)
    {
        vertexAttributes.append(VertexAttributeState(id: id))
    }
    
    func clearTrackedVertexAttributes()
    {
        vertexAttributes.removeAll()
    }
    
    func readFromGL()
    {
        glGetIntegerv(GLenum(GL_VIEWPORT), &viewport);
        
        cullFaceEnabled = (GLboolean(GL_TRUE) == glIsEnabled(GLenum(GL_CULL_FACE))) ? true : false
        scissorTestEnabled = (GLboolean(GL_TRUE) == glIsEnabled(GLenum(GL_SCISSOR_TEST))) ? true : false
        depthTestEnabled = (GLboolean(GL_TRUE) == glIsEnabled(GLenum(GL_DEPTH_TEST))) ? true : false
        
        glGetFloatv(GLenum(GL_COLOR_CLEAR_VALUE), &clearColor)
        glGetIntegerv(GLenum(GL_CURRENT_PROGRAM), &shaderProgram)
        glGetIntegerv(GLenum(GL_SCISSOR_BOX), &scissorBox)
        glGetIntegerv(GLenum(GL_ACTIVE_TEXTURE), &activeTexture)
        glGetIntegerv(GLenum(GL_TEXTURE_BINDING_2D), &texture2DBinding)
        glGetIntegerv(GLenum(GL_ARRAY_BUFFER_BINDING), &arrayBufferBinding)
        glGetIntegerv(GLenum(GL_ELEMENT_ARRAY_BUFFER_BINDING), &elementArrayBufferBinding)
        
        for vertexAttribute in vertexAttributes
        {
            vertexAttribute.readFromGL()
        }
    }
    
    func writeToGL()
    {
        for vertexAttribute in vertexAttributes
        {
            vertexAttribute.writeToGL()
        }
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), GLuint(arrayBufferBinding))
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), GLuint(elementArrayBufferBinding))
        
        glBindTexture(GLenum(GL_TEXTURE_2D), GLuint(texture2DBinding))
        
        glActiveTexture(GLenum(activeTexture))
        
        glScissor(scissorBox[0], scissorBox[1], scissorBox[2], scissorBox[3])
        
        glUseProgram(GLuint(shaderProgram))
        
        glClearColor(clearColor[0], clearColor[1], clearColor[2], clearColor[3])
        
        cullFaceEnabled ? glEnable(GLenum(GL_CULL_FACE)) : glDisable(GLenum(GL_CULL_FACE))
        scissorTestEnabled ? glEnable(GLenum(GL_SCISSOR_TEST)) : glDisable(GLenum(GL_SCISSOR_TEST))
        depthTestEnabled ? glEnable(GLenum(GL_DEPTH_TEST)) : glDisable(GLenum(GL_DEPTH_TEST))

        glViewport(viewport[0], viewport[1], viewport[2], viewport[3])
    }
    
    class VertexAttributeState
    {
        var attributeID:GLuint = 0
        var enabled:GLint = 0
        
        init(id:GLuint)
        {
            attributeID = id
        }
        
        func readFromGL()
        {
            glGetVertexAttribiv(attributeID, GLenum(GL_VERTEX_ATTRIB_ARRAY_ENABLED), &enabled);
        }
        
        func writeToGL()
        {
            if enabled == 0
            {
                glDisableVertexAttribArray(attributeID)
            }
            else
            {
                glEnableVertexAttribArray(attributeID)
            }
            
        }
    }
}

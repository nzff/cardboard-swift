
import Foundation
import OpenGLES
import GLKit

class DistortionRenderer
{
    var textureID:GLuint = 0
    
    var renderbufferID:GLuint = 0
    var framebufferID:GLuint = 0
    
    var textureFormat:GLenum = GLenum(GL_RGB)
    var textureType:GLenum = GLenum(GL_UNSIGNED_BYTE)
    
    var resolutionScale:Float = 1.0
    
    var restoreGLStateEnabled:Bool = true
    
    var chromaticAberrationCorrectionEnabled:Bool = false
    var vignetteEnabled:Bool = true

    var leftEyeDistortionMesh:DistortionMesh?
    var rightEyeDistortionMesh:DistortionMesh?
    
    var glStateBackup:GLStateBackup = GLStateBackup()
    var glStateBackupAberration:GLStateBackup = GLStateBackup()
    
    var headMountedDisplay:HeadMountedDisplay = HeadMountedDisplay(screen: UIScreen.mainScreen())
    
    var leftEyeViewport:EyeViewport = EyeViewport()
    var rightEyeViewport:EyeViewport = EyeViewport()
    
    var fovsChanged:Bool = false
    var viewportsChanged:Bool = false
    
    var textureFormatChanged:Bool = false
    var drawingFrame:Bool = false
    
    var xPxPerTanAngle:Float = 0.0
    var yPxPerTanAngle:Float = 0.0
    
    var metersPerTanAngle:Float = 0.0
    
    var programHolder:ProgramHolder?
    var programHolderAberration:ProgramHolder?
    
    func fovDidChange(hmd:HeadMountedDisplay, _ leftFov:FieldOfView, _ rightFov:FieldOfView, _ eyeToScreenDistance:Float)
    {
        if drawingFrame
        {
            return
        }
        
        headMountedDisplay = hmd

        leftEyeViewport = initEyeViewport(leftFov, 0.0)
        rightEyeViewport = initEyeViewport(rightFov, leftEyeViewport.width)

        let screenParams = headMountedDisplay.screenParams
        metersPerTanAngle = eyeToScreenDistance
        xPxPerTanAngle = Float(screenParams.width()) / ( Float(screenParams.widthInMeters()) / metersPerTanAngle )
        yPxPerTanAngle = Float(screenParams.height()) / ( Float(screenParams.heightInMeters()) / metersPerTanAngle )

        fovsChanged = true
        viewportsChanged = true
    }
    
    func initEyeViewport(fov:FieldOfView, _ xOffset:Float) -> EyeViewport
    {
        let left = tanf(GLKMathDegreesToRadians(fov.left))
        let right = tanf(GLKMathDegreesToRadians(fov.right))
        let bottom = tanf(GLKMathDegreesToRadians(fov.bottom))
        let top = tanf(GLKMathDegreesToRadians(fov.top))
        
        var eyeViewport = EyeViewport()
        
        eyeViewport.x = xOffset
        eyeViewport.y = 0.0
        eyeViewport.width = (left + right)
        eyeViewport.height = (bottom + top)
        eyeViewport.eyeX = (left + xOffset)
        eyeViewport.eyeY = bottom
        
        return eyeViewport
    }
    
    func afterDrawFrame()
    {
        undistortTexture(self.textureID)
        
        drawingFrame = false
    }
    
    func undistortTexture(textureID:GLuint)
    {
        if restoreGLStateEnabled
        {
            if chromaticAberrationCorrectionEnabled
            {
                glStateBackupAberration.readFromGL()
            }
            else
            {
                glStateBackup.readFromGL()
            }
        }
        if fovsChanged || textureFormatChanged
        {
            updateTextureAndDistortionMesh()
        }
        
        let screenParams = headMountedDisplay.screenParams
        glViewport(0, 0, GLsizei(screenParams.width()), GLsizei(screenParams.height()))
        
        glDisable(GLenum(GL_CULL_FACE))
        glDisable(GLenum(GL_SCISSOR_TEST))
        
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
        
        if chromaticAberrationCorrectionEnabled
        {
            glUseProgram(GLuint(programHolderAberration!.program))
        }
        else
        {
            glUseProgram(GLuint(programHolder!.program))
        }
        
        glEnable(GLenum(GL_SCISSOR_TEST))
        
        let oldWidth = GLsizei(screenParams.width() / 2)
        let oldHeight = GLsizei(screenParams.height())
        
        glScissor(0, 0, oldWidth, oldHeight)
        
        renderDistortionMesh(leftEyeDistortionMesh!, textureID: GLint(textureID))
        
        glScissor(oldWidth, 0, oldWidth, oldHeight)
        
        renderDistortionMesh(rightEyeDistortionMesh!, textureID: GLint(textureID))
        
        if restoreGLStateEnabled
        {
            if chromaticAberrationCorrectionEnabled
            {
                glStateBackupAberration.writeToGL()
            }
            else
            {
                glStateBackup.writeToGL()
            }
        }
        
        GLCheckForError()
    }
    
    func setTextureFormat(textureFormat:GLenum, textureType:GLenum)
    
    {
        if drawingFrame
        {
           return
        }
        
        if textureFormat != self.textureFormat || textureType != self.textureType
        {
            self.textureFormat = textureFormat
            self.textureType = textureType
            
            textureFormatChanged = true
        }
    }
    
    func beforeDrawFrame()
    {
        drawingFrame = true
        
        if fovsChanged || textureFormatChanged
        {
            updateTextureAndDistortionMesh()
        }
        
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebufferID)
    }
    
    func updateViewports(inout leftView:Viewport, inout _ rightView:Viewport)
    {
        let newLeftX:Int = Int(round(Float(leftEyeViewport.x) * xPxPerTanAngle * resolutionScale))
        let newLeftY:Int = Int(round(Float(leftEyeViewport.y) * yPxPerTanAngle * resolutionScale))
        let newLeftW:Int = Int(round(Float(leftEyeViewport.width) * xPxPerTanAngle * resolutionScale))
        let newLeftH:Int = Int(round(Float(leftEyeViewport.height) * yPxPerTanAngle * resolutionScale))

        leftView.setViewport(newLeftX, newLeftY, newLeftW, newLeftH)
        
        let newRightX:Int = Int(round(Float(rightEyeViewport.x) * xPxPerTanAngle * resolutionScale))
        let newRightY:Int = Int(round(Float(rightEyeViewport.y) * yPxPerTanAngle * resolutionScale))
        let newRightW:Int = Int(round(Float(rightEyeViewport.width) * xPxPerTanAngle * resolutionScale))
        let newRightH:Int = Int(round(Float(rightEyeViewport.height) * yPxPerTanAngle * resolutionScale))
        
        rightView.setViewport(newRightX, newRightY, newRightW, newRightH)
        
        viewportsChanged = false
    }
    
    func renderDistortionMesh(mesh:DistortionMesh, textureID:GLint)
    {
        var holder:ProgramHolder
        
        if chromaticAberrationCorrectionEnabled
        {
            holder = self.programHolderAberration!
        }
        else
        {
            holder = self.programHolder!
        }
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), GLuint(mesh.arrayBufferID))
        glVertexAttribPointer(GLuint(holder.positionLocation), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(9 * sizeof(Float)), BUFFER_OFFSET(0))
        glEnableVertexAttribArray(GLuint(holder.positionLocation))
        
        glVertexAttribPointer(GLuint(holder.vignetteLocation), 1, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(9 * sizeof(Float)), BUFFER_OFFSET(2*sizeof(Float)))
        glEnableVertexAttribArray(GLuint(holder.vignetteLocation))
        
        glVertexAttribPointer(GLuint(holder.blueTextureCoordLocation), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(9 * sizeof(Float)), BUFFER_OFFSET(7*sizeof(Float)))
        glEnableVertexAttribArray(GLuint(holder.blueTextureCoordLocation))
        
        if chromaticAberrationCorrectionEnabled
        {
            glVertexAttribPointer(GLuint(holder.redTextureCoordLocation), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(9 * sizeof(Float)), BUFFER_OFFSET(3*sizeof(Float)))
            glEnableVertexAttribArray(GLuint(holder.redTextureCoordLocation))
            glVertexAttribPointer(GLuint(holder.greenTextureCoordLocation), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(9 * sizeof(Float)), BUFFER_OFFSET(5*sizeof(Float)))
            glEnableVertexAttribArray(GLuint(holder.greenTextureCoordLocation))
        }
        
        glActiveTexture(GLenum(GL_TEXTURE0))
        
        glBindTexture(GLenum(GL_TEXTURE_2D), GLuint(textureID))
        
        glUniform1i(holder.uTextureSamplerLocation, 0)
        glUniform1f(holder.uTextureCoordScaleLocation, resolutionScale)
        
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), GLuint(mesh.elementBufferID))
        glDrawElements(GLenum(GL_TRIANGLE_STRIP), GLsizei(mesh.indices), GLenum(GL_UNSIGNED_SHORT), BUFFER_OFFSET(0))
    
        GLCheckForError()
    }
    
    
    func computeDistortionScale( distortion:Distortion, screenWidthM: Float, ipd:Float) -> Float
    {
        return distortion.distortionFactor((screenWidthM / 2.0 - ipd / 2.0) / (screenWidthM / 4.0))
    }
    
    func updateTextureAndDistortionMesh()
    {
        let screenParams = headMountedDisplay.screenParams
        let deviceParams = headMountedDisplay.cardboardParams
        
        if programHolder == nil
        {
            programHolder = createProgramHolder(false)
        }
        
        if programHolderAberration == nil
        {
            programHolderAberration = createProgramHolder(true)
        }
        
        let textureWidthTanAngle = leftEyeViewport.width + rightEyeViewport.width
        let textureHeightTanAngle = max(leftEyeViewport.height, rightEyeViewport.height)
        
        var maxTextureSize:GLint = 0
        
        glGetIntegerv(GLenum(GL_MAX_TEXTURE_SIZE), &maxTextureSize)
        
        let tanAngleWidth = Int(round(textureWidthTanAngle * xPxPerTanAngle))
        let texWidth:Int = min(tanAngleWidth, Int(maxTextureSize))

        let tanAngleHeight = Int(round(textureHeightTanAngle * yPxPerTanAngle))
        let texHeight:Int = min(tanAngleHeight, Int(maxTextureSize))
        
        let textureWidthPx:GLint = GLint(texWidth)
        let textureHeightPx:GLint = GLint(texHeight)
        
        var xEyeOffsetTanAngleScreen = (screenParams.widthInMeters() / 2.0 - deviceParams.interLensDistance / 2.0) / metersPerTanAngle
        let yEyeOffsetTanAngleScreen = (deviceParams.verticalDistanceToLensCenter - screenParams.borderSizeInMeters()) / metersPerTanAngle
        
        leftEyeDistortionMesh = createDistortionMesh(leftEyeViewport, textureWidthTanAngle, textureHeightTanAngle, xEyeOffsetTanAngleScreen, yEyeOffsetTanAngleScreen)
        
        xEyeOffsetTanAngleScreen = screenParams.widthInMeters() / metersPerTanAngle - xEyeOffsetTanAngleScreen
        
        rightEyeDistortionMesh = createDistortionMesh(rightEyeViewport, textureWidthTanAngle, textureHeightTanAngle, xEyeOffsetTanAngleScreen, yEyeOffsetTanAngleScreen)
        
        setupRenderTextureAndRenderbuffer(textureWidthPx, textureHeightPx)
        fovsChanged = false
    }
    
    func setupRenderTextureAndRenderbuffer(width:GLint, _ height:GLint) -> GLuint
    {
        if textureID != 0
        {
            glDeleteTextures(1, &textureID)
        }
        if renderbufferID != 0
        {
            glDeleteRenderbuffers(1, &renderbufferID)
        }
        if framebufferID != 0
        {
            glDeleteFramebuffers(1, &framebufferID)
        }
        
        textureID = createTexture(width, height, textureFormat, textureType)
        textureFormatChanged = false
        GLCheckForError()
        
        glGenRenderbuffers(1, &renderbufferID)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), renderbufferID)
        glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_DEPTH_COMPONENT16), width, height)
        GLCheckForError()
        
        glGenFramebuffers(1, &framebufferID)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebufferID)
        
        glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D), textureID, 0)
        
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), GLenum(GL_RENDERBUFFER), renderbufferID)
        
        let status = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
        
        if (status != GLenum(GL_FRAMEBUFFER_COMPLETE))
        {
            print("DistortionRenderer broken frame buffer")
        }
        
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        
        GLCheckForError()
        
        return framebufferID
    }
    
    func createTexture(width:GLint, _ height:GLint, _ textureFormat:GLenum, _ textureType:GLenum) -> GLuint
    {
        var textureID:GLuint = 0
        
        glGenTextures(1, &textureID)
        glBindTexture(GLenum(GL_TEXTURE_2D), textureID)
        
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GLint(textureFormat), width, height, 0, textureFormat, textureType, nil)
        
        GLCheckForError()
        
        return textureID
    }
    
    func createDistortionMesh(eyeViewport:EyeViewport, _ textureWidthTanAngle:Float, _ textureHeightTanAngle:Float,
                              _ xEyeOffsetTanAngleScreen:Float, _ yEyeOffsetTanAngleScreen:Float) -> DistortionMesh
    {
        let hmdDistortion = headMountedDisplay.cardboardParams.distortion
        
        let distortionMesh = DistortionMesh(hmdDistortion, hmdDistortion, hmdDistortion,
                                            headMountedDisplay.screenParams.widthInMeters() / metersPerTanAngle,
                                            headMountedDisplay.screenParams.heightInMeters() / metersPerTanAngle,
                                            xEyeOffsetTanAngleScreen, yEyeOffsetTanAngleScreen,
                                            textureWidthTanAngle, textureHeightTanAngle,
                                            eyeViewport.eyeX, eyeViewport.eyeY,
                                            eyeViewport.x, eyeViewport.y,
                                            eyeViewport.width, eyeViewport.height,
                                            vignetteEnabled)
        
        return distortionMesh
    }
    
    func createProgramHolder(aberrationCorrected:Bool) -> ProgramHolder
    {
        let vertexShader = "\n" +
            "attribute vec2 aPosition;\n" +
            "attribute float aVignette;\n" +
            "attribute vec2 aBlueTextureCoord;\n" +
            "varying vec2 vTextureCoord;\n" +
            "varying float vVignette;\n" +
            "uniform float uTextureCoordScale;\n" +
            "void main() {\n" +
            "gl_Position = vec4(aPosition, 0.0, 1.0);\n" +
            "vTextureCoord = aBlueTextureCoord.xy * uTextureCoordScale;\n" +
            "vVignette = aVignette;\n" +
        "}\n"
        
        let fragmentShader = "\n" +
            "precision mediump float;\n" +
            "varying vec2 vTextureCoord;\n" +
            "varying float vVignette;\n" +
            "uniform sampler2D uTextureSampler;\n" +
            "void main() {\n" +
            "    gl_FragColor = vVignette * texture2D(uTextureSampler, vTextureCoord);\n" +
        "}\n"
        
        
        let vertexShaderAberration = "\n" +
            "attribute vec2 aPosition;\n" +
            "attribute float aVignette;\n" +
            "attribute vec2 aRedTextureCoord;\n" +
            "attribute vec2 aGreenTextureCoord;\n" +
            "attribute vec2 aBlueTextureCoord;\n" +
            "varying vec2 vRedTextureCoord;\n" +
            "varying vec2 vBlueTextureCoord;\n" +
            "varying vec2 vGreenTextureCoord;\n" +
            "varying float vVignette;\n" +
            "uniform float uTextureCoordScale;\n" +
            "void main() {\n" +
            "   gl_Position = vec4(aPosition, 0.0, 1.0);\n" +
            "    vRedTextureCoord = aRedTextureCoord.xy * uTextureCoordScale;\n" +
            "    vGreenTextureCoord = aGreenTextureCoord.xy * uTextureCoordScale;\n" +
            "    vBlueTextureCoord = aBlueTextureCoord.xy * uTextureCoordScale;\n" +
            "    vVignette = aVignette;\n" +
        "}\n"
        
        
        let fragmentShaderAberration = "\n" +
            "precision mediump float;\n" +
            "varying vec2 vRedTextureCoord;\n" +
            "varying vec2 vBlueTextureCoord;\n" +
            "varying vec2 vGreenTextureCoord;\n" +
            "varying float vVignette;\n" +
            "uniform sampler2D uTextureSampler;\n" +
            "void main() {\n" +
            "    gl_FragColor = vVignette * vec4(texture2D(uTextureSampler, vRedTextureCoord).r,\n" +
            "        texture2D(uTextureSampler, vGreenTextureCoord).g,\n" +
            "        texture2D(uTextureSampler, vBlueTextureCoord).b, 1.0);\n" +
        "}\n"
        
        var holder = ProgramHolder()
        var glState: GLStateBackup
        
        if aberrationCorrected
        {
            holder.program = GLint(createProgram(vertexShaderAberration,fragmentShaderAberration))
            glState = glStateBackupAberration
        }
        else
        {
            holder.program = GLint(createProgram(vertexShader,fragmentShader))
            glState = glStateBackup
        }
        
        if holder.program == 0
        {
            print("Distortion Renderer:" + "No program")
        }
        
        holder.positionLocation = glGetAttribLocation(GLuint(holder.program), "aPosition")
        GLCheckForError()
        if holder.positionLocation == -1
        {
            print("DistortionRenderer:" + "Could not get attrib location for aPosition")
        }

        glState.addTrackedVertexAttribute(GLuint(holder.positionLocation))
        
        holder.vignetteLocation = glGetAttribLocation(GLuint(holder.program), "aVignette")
        GLCheckForError()
        if holder.vignetteLocation == -1
        {
            print("DistortionRenderer:" + "Could not get attrib location for aVignette")
        }
        
        glState.addTrackedVertexAttribute(GLuint(holder.vignetteLocation))
        
        if aberrationCorrected
        {
            //redtex attrib

            holder.redTextureCoordLocation = glGetAttribLocation(GLuint(holder.program), "aRedTextureCoord")
            GLCheckForError()
            if holder.redTextureCoordLocation == -1
            {
                print("DistortionRenderer:" + "Could not get attrib location for aRedTextureCoord")
            }
            
            glState.addTrackedVertexAttribute(GLuint(holder.redTextureCoordLocation))
            
            //green
            holder.greenTextureCoordLocation = glGetAttribLocation(GLuint(holder.program), "aGreenTextureCoord")
            GLCheckForError()
            if holder.greenTextureCoordLocation == -1
            {
                print("DistortionRenderer:" + "Could not get attrib location for aGreenTextureCoord")
            }
            
            glState.addTrackedVertexAttribute(GLuint(holder.greenTextureCoordLocation))
        }

        holder.blueTextureCoordLocation = glGetAttribLocation(GLuint(holder.program), "aBlueTextureCoord")
        GLCheckForError()
        if holder.blueTextureCoordLocation == -1
        {
            print("DistortionRenderer:" + "Could not get attrib location for aBlueTextureCoord")
        }
        
        glState.addTrackedVertexAttribute(GLuint(holder.blueTextureCoordLocation));
        
        holder.uTextureCoordScaleLocation = glGetUniformLocation(GLuint(holder.program), "uTextureCoordScale")
        GLCheckForError()
        if holder.uTextureCoordScaleLocation == -1
        {
            print("DistortionRenderer:" + "Could not get attrib location for uTextureCoordScale")
        }
        
        holder.uTextureSamplerLocation = glGetUniformLocation(GLuint(holder.program), "uTextureSampler")
        GLCheckForError()
        if holder.uTextureSamplerLocation == -1
        {
            print("DistortionRenderer:" + "Could not get attrib location for uTextureSampler")
        }
        
        return holder
    }
    
    
    func createProgram(vertexShaderSource:String, _ fragmentShaderSource:String) -> GLuint
    {
        var vertexHandle:GLuint = 0
        GLCompileFromString(&vertexHandle, type: GLenum(GL_VERTEX_SHADER), source: vertexShaderSource)
    
        GLCheckForError()
       
        var fragmentHandle:GLuint = 0
        GLCompileFromString(&fragmentHandle, type: GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderSource)
        
        GLCheckForError()
        
        let program = glCreateProgram()
        
        if program != 0
        {
            glAttachShader(program, vertexHandle)
            GLCheckForError()
            
            glAttachShader(program, fragmentHandle)
            GLCheckForError()
            
            GLLinkProgram(program)
            GLCheckForError()

            var logLength: GLsizei = 0
            var status:GLint = 0
            
            glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)
            glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &logLength)

            if status == GL_FALSE
            {
                if logLength > 0
                {
                    var log: [GLchar] = [GLchar](count: Int(logLength), repeatedValue: 0)
                    
                    glGetProgramInfoLog(program, logLength, &logLength, &log)
                   
                    print("Program validate log: \n\(log)")
                }
            }
        }

        GLCheckForError()
        
        return program
    }
    
    class DistortionMesh
    {
        var indices:Int = -1
        var arrayBufferID:Int = -1
        var elementBufferID:Int = -1
        
        init(_ distortionRed:Distortion,
             _ distortionGreen:Distortion,
             _ distortionBlue:Distortion,
             _ screenWidth:Float, _ screenHeight:Float,
             _ xEyeOffsetScreen:Float, _ yEyeOffsetScreen:Float,
             _ textureWidth:Float, _ textureHeight:Float,
             _ xEyeOffsetTexture:Float, _ yEyeOffsetTexture:Float,
             _ viewportXTexture:Float, _ viewportYTexture:Float,
             _ viewportWidthTexture:Float, _ viewportHeightTexture:Float,
             _ vignetteEnabled:Bool)
        {
            var vertexData:[GLfloat] = [GLfloat](count: 14400, repeatedValue: 0.0)
            
            var vertexOffset:Int = 0
            
            let rows = 40
            let cols = 40
            
            let vignetteSizeTanAngle:Float = 0.05
            
            for (var row = 0; row < rows; row++)
            {
                for (var col = 0; col < cols; col++)
                {
                    let uTextureBlue:Float = Float(col) / 39.0 * (viewportWidthTexture / textureWidth) + viewportXTexture / textureWidth
                    let vTextureBlue:Float = Float(row) / 39.0 * (viewportHeightTexture / textureHeight) + viewportYTexture / textureHeight
                    
                    let xTexture = uTextureBlue * textureWidth - xEyeOffsetTexture
                    let yTexture = vTextureBlue * textureHeight - yEyeOffsetTexture
                    let rTexture = sqrtf(xTexture * xTexture + yTexture * yTexture)
                    
                    let textureToScreenBlue = (rTexture > 0.0) ? distortionBlue.distortInverse(rTexture) / rTexture : 1.0
                    
                    let xScreen = xTexture * textureToScreenBlue
                    let yScreen = yTexture * textureToScreenBlue
                    
                    let uScreen = (xScreen + xEyeOffsetScreen) / screenWidth
                    let vScreen = (yScreen + yEyeOffsetScreen) / screenHeight
                    let rScreen = rTexture * textureToScreenBlue
                    
                    let screenToTextureGreen = (rScreen > 0.0) ? distortionGreen.distortionFactor(rScreen) : 1.0
                    let uTextureGreen = (xScreen * screenToTextureGreen + xEyeOffsetTexture) / textureWidth
                    let vTextureGreen = (yScreen * screenToTextureGreen + yEyeOffsetTexture) / textureHeight
                    
                    let screenToTextureRed = (rScreen > 0.0) ? distortionRed.distortionFactor(rScreen) : 1.0
                    let uTextureRed = (xScreen * screenToTextureRed + xEyeOffsetTexture) / textureWidth
                    let vTextureRed = (yScreen * screenToTextureRed + yEyeOffsetTexture) / textureHeight
                    
                    let vignetteSizeTexture = vignetteSizeTanAngle / textureToScreenBlue
                    
                    let dxTexture = xTexture + xEyeOffsetTexture - clamp(xTexture + xEyeOffsetTexture,
                        lower: viewportXTexture + vignetteSizeTexture,
                        upper: viewportXTexture + viewportWidthTexture - vignetteSizeTexture);
                    let dyTexture = yTexture + yEyeOffsetTexture - clamp(yTexture + yEyeOffsetTexture,
                        lower: viewportYTexture + vignetteSizeTexture,
                        upper: viewportYTexture + viewportHeightTexture - vignetteSizeTexture)
                    let drTexture = sqrtf(dxTexture * dxTexture + dyTexture * dyTexture)
                    
                    var vignette:Float = 1.0
                    if (vignetteEnabled)
                    {
                        vignette = 1.0 - clamp(drTexture / vignetteSizeTexture, lower: 0.0, upper: 1.0)
                    }
                    
                    vertexData[(vertexOffset + 0)] = 2.0 * uScreen - 1.0
                    vertexData[(vertexOffset + 1)] = 2.0 * vScreen - 1.0
                    vertexData[(vertexOffset + 2)] = vignette
                    vertexData[(vertexOffset + 3)] = uTextureRed
                    vertexData[(vertexOffset + 4)] = vTextureRed
                    vertexData[(vertexOffset + 5)] = uTextureGreen
                    vertexData[(vertexOffset + 6)] = vTextureGreen
                    vertexData[(vertexOffset + 7)] = uTextureBlue
                    vertexData[(vertexOffset + 8)] = vTextureBlue
                    
                    vertexOffset += 9
                }
            }
            
            indices = 3158
            var indexData = [GLshort](count:indices, repeatedValue:0)
            
            var indexOffset:Int = 0
            vertexOffset = 0
            
            for var row = 0; row < rows-1; row++
            {
                if row > 0
                {
                    indexData[indexOffset] = indexData[(indexOffset - 1)]
                    indexOffset++
                }
                for var col = 0; col < cols; col++
                {
                    if col > 0
                    {
                        if row % 2 == 0
                        {
                            vertexOffset++
                        }
                        else
                        {
                            vertexOffset--
                        }
                    }
                    indexData[(indexOffset++)] = GLshort(vertexOffset)
                    indexData[(indexOffset++)] = GLshort(vertexOffset + 40)
                }
                vertexOffset += 40
            }
            
            var bufferIDs:[GLuint] = [ 0, 0 ]
            glGenBuffers(2, &bufferIDs)
            arrayBufferID = Int(bufferIDs[0])
            elementBufferID = Int(bufferIDs[1])
            
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), GLuint(arrayBufferID))
            glBufferData(GLenum(GL_ARRAY_BUFFER), sizeof(GLfloat) * vertexData.count, vertexData, GLbitfield(GL_STATIC_DRAW))
            
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), GLuint(elementBufferID))
            glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), sizeof(GLshort) * indexData.count, indexData, GLbitfield(GL_STATIC_DRAW))
            
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
            
            GLCheckForError()
        }
    }
    
    struct EyeViewport
    {
        var x:Float = 0
        var y:Float = 0
        
        var width:Float = 0
        var height:Float = 0
        
        var eyeX:Float = 0
        var eyeY:Float = 0
    }
    
    struct ProgramHolder
    {
        var program:GLint = -1
        var positionLocation:GLint = -1
        var vignetteLocation:GLint = -1
        var redTextureCoordLocation:GLint = -1
        var greenTextureCoordLocation:GLint = -1
        var blueTextureCoordLocation:GLint = -1
        var uTextureCoordScaleLocation:GLint = -1
        var uTextureSamplerLocation:GLint = -1
    }
}

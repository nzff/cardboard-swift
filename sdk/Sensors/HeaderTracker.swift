
import Foundation
import GLKit
import CoreMotion

public class HeadTracker
{
    let motionManager = CMMotionManager()
    
    var lastHeadView:GLKMatrix4 = GLKMatrix4Identity
    
    var inertialReferenceFrameFromWorld:GLKMatrix4 = GLKMatrix4Identity
    var correctedInertialReferenceFrameFromWorld:GLKMatrix4 = GLKMatrix4Identity
    var displayFromDevice:GLKMatrix4 = GLKMatrix4Identity
    
    var trackingType:TrackingType = TrackingType.CoreMotion
    var tracker:OrientationEKF = OrientationEKF()
    
    var headingCorrectionComputed:Bool = false
    
    var neckModelEnabled:Bool = false
    var neckModelTranslation:GLKMatrix4 = GLKMatrix4Identity
    var defaultNeckHorizontalOffset:Float = 0.08
    var defaultNeckVerticalOffset:Float = 0.075
    
    var sampleCount:UInt = 0
    var initialSkipSamples:UInt = 10
    
    var lastGyroEventTimestamp:NSTimeInterval = NSTimeInterval(0.0)
    
    enum TrackingType
    {
        case EKF
        case CoreMotion
        case CoreMotionEKF
    }
    
    init()
    {
        inertialReferenceFrameFromWorld = GetRotateEulerMatrix(-90.0, 0.0, 90.0)
        correctedInertialReferenceFrameFromWorld = inertialReferenceFrameFromWorld
        
        displayFromDevice = GetRotateEulerMatrix(0.0, 0.0, -90.0)
        
        neckModelTranslation = GLKMatrix4Translate(neckModelTranslation, 0, -defaultNeckVerticalOffset, defaultNeckHorizontalOffset)
    }
    
    func getLastHeadView() -> GLKMatrix4
    {
        var deviceFromInertialReferenceFrame = GLKMatrix4()
        
        if trackingType == .EKF || trackingType == .CoreMotionEKF
        {
            let currentTimestamp = CACurrentMediaTime()
            
            let secondsSinceLastGyroEvent = currentTimestamp - lastGyroEventTimestamp
            let secondsToPredictForward = secondsSinceLastGyroEvent + 1.0 / 30.0

            deviceFromInertialReferenceFrame = tracker.getPredictedGLMatrix(secondsToPredictForward)
        }
        
        if trackingType == .CoreMotion
        {
            let motion = motionManager.deviceMotion
            
            if motion == nil
            {
                return lastHeadView
            }
            
            let rotationMatrix = motion?.attitude.rotationMatrix
            
            deviceFromInertialReferenceFrame = GLKMatrix4Transpose(GLMatrixFromRotationMatrix(rotationMatrix!))
        }
        
        if !isReady()
        {
            return lastHeadView
        }
        
        if !headingCorrectionComputed
        {
            let deviceFromWorld = GLKMatrix4Multiply(deviceFromInertialReferenceFrame, inertialReferenceFrameFromWorld)
            let worldFromDevice = GLKMatrix4Transpose(deviceFromWorld)
            
            let deviceForward:GLKVector3 = GLKVector3Make(0.0,0.0,-1.0)
            var deviceForwardWorld:GLKVector3 = GLKMatrix4MultiplyVector3(worldFromDevice, deviceForward)
            
            if fabsf(deviceForwardWorld.y) < 0.99
            {
                let dfw = GLKVector3Make(deviceForwardWorld.x, 0.0, deviceForwardWorld.z)
                
                deviceForwardWorld = GLKVector3Normalize(dfw)
                
                let c = -deviceForwardWorld.z
                let s = -deviceForwardWorld.x

                let Rt = GLKMatrix4Make( c,   0.0,  -s, 0.0,
                                         0.0, 1.0, 0.0, 0.0,
                                         s,   0.0,   c, 0.0,
                                         0.0, 0.0, 0.0, 1.0 )
                
                correctedInertialReferenceFrameFromWorld = GLKMatrix4Multiply(inertialReferenceFrameFromWorld,Rt)
            }
            
            headingCorrectionComputed = true
        }
        
        let deviceFromWorld = GLKMatrix4Multiply(deviceFromInertialReferenceFrame,
                                                 correctedInertialReferenceFrameFromWorld)
        
        var displayFromWorld = GLKMatrix4Multiply(displayFromDevice, deviceFromWorld)
        
        if neckModelEnabled
        {
            displayFromWorld = GLKMatrix4Multiply(neckModelTranslation, displayFromWorld)
            displayFromWorld = GLKMatrix4Translate(displayFromWorld, 0.0, defaultNeckVerticalOffset, 0.0)
        }
        
        lastHeadView = displayFromWorld
        
        return lastHeadView
    }
    
    func isReady() -> Bool
    {
    #if TARGET_IPHONE_SIMULATOR
    
        return true
        
    #else
        
        var isTrackerReady:Bool = true
        
        if trackingType == .EKF || trackingType == .CoreMotionEKF
        {
            isTrackerReady = isTrackerReady && tracker.ready()
        }
        
        return isTrackerReady
    #endif
    }
    
    func startTracking(orientation:UIInterfaceOrientation)
    {
        
        updateDeviceOrientation(orientation)
        
        tracker.reset()
        
        headingCorrectionComputed = false
        
        sampleCount = 0
    
    #if !TARGET_IPHONE_SIMULATOR
        
        if trackingType == .EKF
        {
            let accelerometerQueue = NSOperationQueue()
            let gyroQueue = NSOperationQueue()
            
            motionManager.accelerometerUpdateInterval = 1.0/100.0
            
            motionManager.startAccelerometerUpdatesToQueue(accelerometerQueue, withHandler:
            { ( accelerometerData, error) -> Void in
                
                ++self.sampleCount
                
                if self.sampleCount <= self.initialSkipSamples || accelerometerData == nil
                {
                    return
                }
                
                let kG:Double = 9.81

                let acceleration = accelerometerData!.acceleration
                
                let acc = GLKVector3Make(Float(kG * acceleration.x), Float(kG * acceleration.y), Float(kG * acceleration.z))
                
                self.tracker.processAcceleration(acc, accelerometerData!.timestamp)
            })
            
            motionManager.gyroUpdateInterval = 1.0/100.0
            
            motionManager.startGyroUpdatesToQueue(gyroQueue, withHandler:
                { ( gyroData, error) -> Void in

                    if self.sampleCount <= self.initialSkipSamples || gyroData == nil
                    {
                        return;
                    }
                    
                    let rotationRate = gyroData!.rotationRate
                    
                    let rotVec = GLKVector3Make(Float(rotationRate.x), Float(rotationRate.y), Float(rotationRate.z))
                    
                    self.tracker.processGyro(rotVec, gyroData!.timestamp)
                    
                    self.lastGyroEventTimestamp = gyroData!.timestamp
            })

        }
            
        else if trackingType == .CoreMotionEKF
        {
            let deviceMotionQueue = NSOperationQueue()
            
            motionManager.deviceMotionUpdateInterval = 1.0/100.0
            
            motionManager.startDeviceMotionUpdatesUsingReferenceFrame(CMAttitudeReferenceFrame.XArbitraryZVertical, toQueue: deviceMotionQueue, withHandler:
            { (deviceMotion, error) -> Void in
                
                ++self.sampleCount
                
                if self.sampleCount <= self.initialSkipSamples || deviceMotion == nil
                {
                    return
                }

                let kG:Double = 9.81
                
                let timestamp = deviceMotion!.timestamp
                
                let acceleration = deviceMotion!.gravity
                let acc = GLKVector3Make(Float(kG * acceleration.x), Float(kG * acceleration.y), Float(kG * acceleration.z))

                let rotationRate = deviceMotion!.rotationRate
                let rotVec = GLKVector3Make(Float(rotationRate.x), Float(rotationRate.y), Float(rotationRate.z))
                
                self.tracker.processAcceleration(acc, timestamp)
                self.tracker.processGyro(rotVec, timestamp)
                
                self.lastGyroEventTimestamp = timestamp
            })
        }
            
        else if trackingType == .CoreMotion
        {
            if motionManager.deviceMotionAvailable
            {
                motionManager.startDeviceMotionUpdatesUsingReferenceFrame(CMAttitudeReferenceFrame.XArbitraryZVertical);
            }
        }

        
    #endif
    }
    
    func stopTracking()
    {
        if trackingType == .EKF
        {
            motionManager.stopAccelerometerUpdates()
            motionManager.stopGyroUpdates()
        }
        else if trackingType == .CoreMotion || trackingType == .CoreMotionEKF
        {
            motionManager.stopDeviceMotionUpdates()
        }
    }
    
    func updateDeviceOrientation(orientation:UIInterfaceOrientation)
    {
        
    }
    
    
    
    func GetRotateEulerMatrix(inX:Float, _ inY:Float, _ inZ:Float) -> GLKMatrix4
    {
    
        var x = inX
        var y = inY
        var z = inZ
        
        var matrix:GLKMatrix4 = GLKMatrix4Identity
        
        x *= Float(M_PI / 180.0)
        y *= Float(M_PI / 180.0)
        z *= Float(M_PI / 180.0)
        
        let cx:Float =  cos(x)
        let sx:Float = sin(x)
        let cy:Float = cos(y)
        let sy:Float = sin(y)
        let cz:Float = cos(z)
        let sz:Float = sin(z)
        
        let cxsy = cx * sy
        let sxsy = sx * sy

        matrix.m.0 = cy * cz
        matrix.m.1 = -cy * sz
        matrix.m.2 = sy
        matrix.m.3 = 0.0
        
        matrix.m.4 = cxsy * cz + cx * sz
        matrix.m.5 = -cxsy * sz + cx * cz
        matrix.m.6 = -sx * cy
        matrix.m.7 = 0.0
        
        matrix.m.8 = -sxsy * cz + sx * sz
        matrix.m.9 = sxsy * sz + sx * cz
        matrix.m.10 = cx * cy
        matrix.m.11 = 0.0
        
        matrix.m.12 = 0.0
        matrix.m.13 = 0.0
        matrix.m.14 = 0.0
        matrix.m.15 = 1.0
        
        return matrix;
    }
    
    func GLMatrixFromRotationMatrix(rotationMatrix:CMRotationMatrix) -> GLKMatrix4
    {
        var glRotationMatrix:GLKMatrix4 = GLKMatrix4Identity;
    
        glRotationMatrix.m.0 = Float(rotationMatrix.m11)
        glRotationMatrix.m.1 = Float(rotationMatrix.m12)
        glRotationMatrix.m.2 = Float(rotationMatrix.m13)
        glRotationMatrix.m.3 = 0.0
        
        glRotationMatrix.m.4 = Float(rotationMatrix.m21)
        glRotationMatrix.m.5 = Float(rotationMatrix.m22)
        glRotationMatrix.m.6 = Float(rotationMatrix.m23)
        glRotationMatrix.m.7 = 0.0
        
        glRotationMatrix.m.8 = Float(rotationMatrix.m31)
        glRotationMatrix.m.9 = Float(rotationMatrix.m32)
        glRotationMatrix.m.10 = Float(rotationMatrix.m33)
        glRotationMatrix.m.11 = 0.0
        
        glRotationMatrix.m.12 = 0.0
        glRotationMatrix.m.13 = 0.0
        glRotationMatrix.m.14 = 0.0
        glRotationMatrix.m.15 = 1.0
    
        return glRotationMatrix
    }
    
    
}

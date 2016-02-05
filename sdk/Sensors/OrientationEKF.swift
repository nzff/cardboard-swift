
import Foundation
import GLKit

class OrientationEKF
{
    var so3SensorFromWorld:Matrix3x3d = Matrix3x3d()
    var so3LastMotion:Matrix3x3d = Matrix3x3d()

    var mP:Matrix3x3d = Matrix3x3d()
    var mQ:Matrix3x3d = Matrix3x3d()
    var mR:Matrix3x3d = Matrix3x3d()
    var mRAcceleration = Matrix3x3d()
    var mS:Matrix3x3d = Matrix3x3d()
    var mH:Matrix3x3d = Matrix3x3d()
    var mK:Matrix3x3d = Matrix3x3d()
    
    var vNu:Vector3d = Vector3d()
    var vZ:Vector3d = Vector3d()
    var vH:Vector3d = Vector3d()
    var vU:Vector3d = Vector3d()
    var vX:Vector3d = Vector3d()
    var vDown:Vector3d = Vector3d()
    var vNorth:Vector3d = Vector3d()
    
    var sensorTimeStampGyro:Double = 0.0
    
    var lastGyro:GLKVector3 = GLKVector3()
    
    var previousAccelNorm:Double = 0.0
    var movingAverageAccelNormChange:Double = 0.0
    var filteredGyroTimestep:Double = 0.0
    
    var timestepFilterInit:Bool = false
    
    var numGyroTimestepSamples:Int = 0
    
    var gyroFilterValid:Bool = true
    var alignedToGravity:Bool = false
    
    let DEG_TO_RAD:Double = M_PI / 180.0
    let RAD_TO_DEG:Double = 180.0 / M_PI
    
    var processLock:NSRecursiveLock = NSRecursiveLock()
    
    init()
    {
        reset()
    }
    
    func reset()
    {
        sensorTimeStampGyro = 0.0
        
        so3SensorFromWorld.identity()
        so3LastMotion.identity()
        
        mP.zero()
        mP.setDiagonal(25.0)
        
        mQ.zero()
        mQ.setDiagonal(1.0)
        
        mR.zero()
        mR.setDiagonal(0.0625)
        
        mRAcceleration.zero()
        mRAcceleration.setDiagonal(0.5625)
        
        mS.zero()
        mH.zero()
        mK.zero()
        
        vNu.zero()
        vZ.zero()
        vH.zero()
        vU.zero()
        vX.zero()

        vDown.set(0.0, 0.0, -9.81)
        vNorth.set(0.0, 1.0, 0.0)
        
        alignedToGravity = false
    }
    
    func ready() -> Bool
    {
        return alignedToGravity
    }
    
    func getHeadingDegrees() -> Double
    {
        let x = so3SensorFromWorld.get(2,0)
        let y = so3SensorFromWorld.get(2, 1)
        
        let mag = sqrt(x * x + y * y)
        
        if mag < 0.1
        {
            return 0.0
        }
        
        var heading:Double = -90.0 - atan2(y, x) * RAD_TO_DEG
        
        if heading < 0.0
        {
            heading += 360.0
        }
        
        if heading >= 360.0
        {
            heading -= 360.0
        }
        
        return heading
    }
    
    func setHeadingDegrees(heading:Double)
    {
        let currentHeading = getHeadingDegrees()
        
        let deltaHeading = heading - currentHeading
        
        let s:Double = sin(deltaHeading * DEG_TO_RAD)
        let c:Double = cos(deltaHeading * DEG_TO_RAD)
        
        let deltaHeadingRotationMatrix:Matrix3x3d = Matrix3x3d(c, -s, 0.0, s, c, 0.0, 0.0, 0.0, 1.0)
        
        Matrix3x3d.mult(so3SensorFromWorld, deltaHeadingRotationMatrix, result: &so3SensorFromWorld)
    }
    
    func getGlMatrix() -> GLKMatrix4
    {
        return glMatrixFromSo3(so3SensorFromWorld)
    }
    
    func getPredictedGLMatrix(secondsAfterLastGyroEvent:Double) -> GLKMatrix4
    {
        let dT = secondsAfterLastGyroEvent

        let pmu = Vector3d(Double(lastGyro.x) * -dT, Double(lastGyro.y) * -dT, Double(lastGyro.z) * -dT)

        var so3PredictedMotion = Matrix3x3d()
        
        so3FromMu(pmu, result: &so3PredictedMotion)
        
        var so3PredictedState:Matrix3x3d = Matrix3x3d()

        Matrix3x3d.mult(so3PredictedMotion, so3SensorFromWorld, result:&so3PredictedState)
        
        return glMatrixFromSo3(so3PredictedState)
    }
    
    func processGyro(gyro:GLKVector3, _ sensorTimeStamp:Double)
    {
        let lockAcquired = processLock.tryLock()
        
        if !lockAcquired
        {
            return
        }
        
        if sensorTimeStampGyro != 0.0
        {
            var dT:Double = sensorTimeStamp - sensorTimeStampGyro
            
            if dT > 0.04
            {
                dT = gyroFilterValid ? filteredGyroTimestep : 0.01
            }
            else
            {
                filterGyroTimestep(dT)
            }
            
            vU.set(Double(gyro.x) * -dT, Double(gyro.y) * -dT, Double(gyro.z) * -dT)
            
            so3FromMu(vU, result:&so3LastMotion)
            
            Matrix3x3d.mult(so3LastMotion, so3SensorFromWorld, result:&so3SensorFromWorld)
            updateCovariancesAfterMotion()
            
            let temp = Matrix3x3d()
            temp.set(mQ)
            temp.scale(dT * dT)

            mP.plusEquals(temp)
        }
        
        sensorTimeStampGyro = sensorTimeStamp
        lastGyro = gyro

        processLock.unlock()

    }
    
    func processAcceleration(acc:GLKVector3, _ sensorTimestamp:Double)
    {
        let lockAcquired = processLock.tryLock()
        
        if !lockAcquired
        {
            return
        }

        vZ.set(Double(acc.x), Double(acc.y), Double(acc.z))
        
        updateAccelerationCovariance(vZ.length())
        
        if alignedToGravity
        {
            accelerationObservationFunctionForNumericalJacobian(so3SensorFromWorld, result:&vNu)
            
            let eps = 1.0E-7
            
            for var dof = 0; dof < 3; dof++
            {
                let delta = Vector3d()
                delta.zero()
                delta.setComponent(dof, value: eps)
                
                var tempM = Matrix3x3d()
                so3FromMu(delta, result:&tempM)
                Matrix3x3d.mult(tempM, so3SensorFromWorld, result:&tempM)
                
                var tempV = Vector3d()
                accelerationObservationFunctionForNumericalJacobian(tempM, result:&tempV)
                
                Vector3d.sub(vNu, tempV, result:&tempV)
                tempV.scale(1.0/eps)
                
                mH.setColumn(dof, tempV)
            }
            
            var mHt = Matrix3x3d()
            mH.transpose(&mHt)
            
            var temp = Matrix3x3d()
            Matrix3x3d.mult(mP, mHt, result:&temp)
            Matrix3x3d.mult(mH, temp, result:&temp)
            Matrix3x3d.add(temp, mRAcceleration, result:&mS)
            
            mS.invert(&temp);
            
            Matrix3x3d.mult(mHt, temp, result:&temp)
            Matrix3x3d.mult(mP, temp, result:&mK)
            Matrix3x3d.mult(mK, vNu, result:&vX)
            Matrix3x3d.mult(mK, mH, result:&temp)
            
            let temp2 = Matrix3x3d()
            temp2.identity()
            temp2.minusEquals(temp)
            
            Matrix3x3d.mult(temp2, mP, result:&mP)
            
            so3FromMu(vX, result:&so3LastMotion)
            
            Matrix3x3d.mult(so3LastMotion, so3SensorFromWorld, result:&so3SensorFromWorld)
            
            updateCovariancesAfterMotion()
        }
        else
        {
            so3FromTwoVecN(vDown, vZ, result:&so3SensorFromWorld)
            alignedToGravity = true;
        }
        processLock.unlock()

    }
    
    func filterGyroTimestep(timestep:Double)
    {
        let kFilterCoeff = 0.95
        
        if !timestepFilterInit
        {
            filteredGyroTimestep = timestep
            numGyroTimestepSamples = 1
            timestepFilterInit = true
        }
        else
        {
            filteredGyroTimestep = kFilterCoeff * filteredGyroTimestep + (1.0-kFilterCoeff) * timestep
            ++numGyroTimestepSamples
            gyroFilterValid = (numGyroTimestepSamples > 10)
        }
    }
    
    func updateCovariancesAfterMotion()
    {
        var temp = Matrix3x3d()
        
        so3LastMotion.transpose(&temp)
        
        Matrix3x3d.mult(mP, temp, result:&temp)
        Matrix3x3d.mult(so3LastMotion, temp, result:&mP)
       
        so3LastMotion.identity()
    }
    
    func updateAccelerationCovariance(currentAccelNorm:Double)
    {
        let currentAccelNormChange:Double = fabs(currentAccelNorm - previousAccelNorm)
        previousAccelNorm = currentAccelNorm
        
        let kSmoothingFactor:Double = 0.5
        movingAverageAccelNormChange = kSmoothingFactor * movingAverageAccelNormChange + (1.0 - kSmoothingFactor) * currentAccelNormChange

        let kMaxAccelNormChange:Double = 0.15
        let kMinAccelNoiseSigma:Double = 0.75
        let kMaxAccelNoiseSigma:Double = 7.0
        
        let normChangeRatio = movingAverageAccelNormChange / kMaxAccelNormChange
        
        let accelNoiseSigma = min(kMaxAccelNoiseSigma, kMinAccelNoiseSigma + normChangeRatio * (kMaxAccelNoiseSigma - kMinAccelNoiseSigma))
        
        mRAcceleration.setDiagonal(accelNoiseSigma * accelNoiseSigma)
    }
    
    func accelerationObservationFunctionForNumericalJacobian(so3SensorFromWorldPred:Matrix3x3d, inout result:Vector3d)
    {
        Matrix3x3d.mult(so3SensorFromWorldPred, vDown, result:&vH)
        
        var temp = Matrix3x3d()
        
        so3FromTwoVecN(vH, vZ, result:&temp)
        
        muFromSO3(temp, result:&result)
    }
    
    func glMatrixFromSo3(so3:Matrix3x3d) -> GLKMatrix4
    {
        // Surely there's a better way to do this...
        
        var rotationMatrix = GLKMatrix4()

        rotationMatrix.m.0  = Float(so3.get(0,0))
        rotationMatrix.m.1  = Float(so3.get(1,0))
        rotationMatrix.m.2  = Float(so3.get(2,0))
        rotationMatrix.m.3  = 0.0
        
        rotationMatrix.m.4  = Float(so3.get(0,1))
        rotationMatrix.m.5  = Float(so3.get(1,1))
        rotationMatrix.m.6  = Float(so3.get(2,1))
        rotationMatrix.m.7  = 0.0
        
        rotationMatrix.m.8  = Float(so3.get(0,2))
        rotationMatrix.m.9  = Float(so3.get(1,2))
        rotationMatrix.m.10  = Float(so3.get(2,2))
        rotationMatrix.m.11 = 0.0
        
        rotationMatrix.m.12 = 0.0
        rotationMatrix.m.13 = 0.0
        rotationMatrix.m.14 = 0.0
        rotationMatrix.m.15 = 1.0
        
        return rotationMatrix
    }
    
}
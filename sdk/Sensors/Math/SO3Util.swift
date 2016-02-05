
import Foundation

func so3FromTwoVecN(a:Vector3d, _ b:Vector3d, inout result:Matrix3x3d)
{
    var so3FromTwoVecNN:Vector3d = Vector3d()
    
    Vector3d.cross(a, b, result: &so3FromTwoVecNN)
    
    if so3FromTwoVecNN.length() == 0.0
    {
        let dot:Double = Vector3d.dot(a, b)
        
        if ( dot >= 0.0 )
        {
            result.identity()
        }
        else
        {
            var so3FromTwoVecNRotationAxis:Vector3d = Vector3d()
            
            Vector3d.ortho(a, result: &so3FromTwoVecNRotationAxis)
            
            rotationPiAboutAxis(so3FromTwoVecNRotationAxis, result: &result)
        }
        
        return
    }


    let so3FromTwoVecNA = Vector3d(a)
    let so3FromTwoVecNB = Vector3d(b)
    
    so3FromTwoVecNN.normalize()
    so3FromTwoVecNA.normalize()
    so3FromTwoVecNB.normalize()
    
    var tempVector = Vector3d()
    Vector3d.cross(so3FromTwoVecNN, so3FromTwoVecNA, result: &tempVector)
    
    let r1 = Matrix3x3d()
    r1.setColumn(0, so3FromTwoVecNA)
    r1.setColumn(1, so3FromTwoVecNN)
    r1.setColumn(2, tempVector)
    
    
    let r2 = Matrix3x3d()
    Vector3d.cross(so3FromTwoVecNN, so3FromTwoVecNB, result: &tempVector)
    r2.setColumn(0, so3FromTwoVecNB)
    r2.setColumn(1, so3FromTwoVecNN)
    r2.setColumn(2, tempVector)
    
    r1.transpose()
    
    Matrix3x3d.mult(r2, r1, result: &result)
}

func rotationPiAboutAxis(v:Vector3d, inout result:Matrix3x3d)
{
    let temp = Vector3d(v)
    
    temp.scale(M_PI/temp.length())
    
    let kA:Double = 0.0
    let kB:Double = 0.20264236728467558
    
    rodriguesSo3Exp(temp, kA, kB, result: &result)
}

func rodriguesSo3Exp(w:Vector3d, _ kA:Double, _ kB:Double, inout result:Matrix3x3d)
{
    let wx2 = w.x * w.x
    let wy2 = w.y * w.y
    let wz2 = w.z * w.z
    
    result.set(0, 0, 1.0 - kB * (wy2 + wz2))
    result.set(1, 1, 1.0 - kB * (wx2 + wz2))
    result.set(2, 2, 1.0 - kB * (wx2 + wy2))
    
    var a:Double = kA * w.z
    var b:Double = kB * (w.x * w.y)

    result.set(0, 1, b - a)
    result.set(1, 0, b + a)
    
    a = kA * w.y
    b = kB * (w.x * w.z)
    
    result.set(0, 2, b + a)
    result.set(2, 0, b - a)
    
    a = kA * w.x
    b = kB * (w.y * w.z)
    
    result.set(1, 2, b - a)
    result.set(2, 1, b + a)
    
}

func so3FromMu(w:Vector3d, inout result:Matrix3x3d)
{
    let thetaSq:Double = Vector3d.dot(w, w)
    let theta:Double = sqrt(thetaSq)
    
    var kA:Double = 0.0
    var kB:Double = 0.0
    
    if thetaSq < 1.0E-08
    {
        kA = 1.0 - 0.16666667163372 * thetaSq
        kB = 0.5
    }
    else
    {
        if thetaSq < 1.0E-06
        {
            kB = 0.5 - 0.0416666679084301 * thetaSq
            kA = 1.0 - thetaSq * 0.16666667163372 * (1.0 - 0.16666667163372 * thetaSq)
        }
        else
        {
            let invTheta:Double = 1.0 / theta
            kA = sin(theta) * invTheta
            kB = (1.0 - cos(theta)) * (invTheta * invTheta)
        }
    }
    
    rodriguesSo3Exp(w, kA, kB, result: &result)
}

func muFromSO3(so3:Matrix3x3d, inout result:Vector3d)
{
    let cosAngle = (so3.get(0, 0) + so3.get(1, 1) + so3.get(2, 2) - 1.0) * 0.5
    
    result.set((so3.get(2, 1) - so3.get(1, 2)) / 2.0,
               (so3.get(0, 2) - so3.get(2, 0)) / 2.0,
               (so3.get(1, 0) - so3.get(0, 1)) / 2.0)
    
    let sinAngleAbs = result.length()
    
    if cosAngle > 0.7071067811865476
    {
        if sinAngleAbs > 0.0
        {
            result.scale(asin(sinAngleAbs) / sinAngleAbs)
        }
    }
    else if cosAngle > -0.7071067811865476
    {
        let angle = acos(cosAngle)
        result.scale(angle / sinAngleAbs)
    }
    else
    {
        let angle = M_PI - asin(sinAngleAbs)
        
        let d0 = so3.get(0, 0) - cosAngle
        let d1 = so3.get(1, 1) - cosAngle
        let d2 = so3.get(2, 2) - cosAngle
        
        let r2 = Vector3d()
        
        if (d0 * d0 > d1 * d1) && (d0 * d0 > d2 * d2)
        {
            r2.set(d0, (so3.get(1, 0) + so3.get(0, 1)) / 2.0, (so3.get(0, 2) + so3.get(2, 0)) / 2.0)
        }
        else if d1 * d1 > d2 * d2
        {
            r2.set((so3.get(1, 0) + so3.get(0, 1)) / 2.0, d1, (so3.get(2, 1) + so3.get(1, 2)) / 2.0)
        }
        else
        {
            r2.set((so3.get(0, 2) + so3.get(2, 0)) / 2.0, (so3.get(2, 1) + so3.get(1, 2)) / 2.0, d2)
        }
        
        if Vector3d.dot(r2, result) < 0.0
        {
            r2.scale(-1.0)
        }
        
        r2.normalize()
        r2.scale(angle)
        
        result.set(r2)
    }

}

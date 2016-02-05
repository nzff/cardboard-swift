
import Foundation

class Matrix3x3d
{
    var m:[Double] = [Double](count: 9, repeatedValue: 0.0)
    
    init()
    {
        zero()
    }

    init(_ m00:Double, _ m01:Double, _ m02:Double,
         _ m10:Double, _ m11:Double, _ m12:Double,
         _ m20:Double, _ m21:Double, _ m22:Double)
    {
        m[0] = m00
        m[1] = m01
        m[2] = m02
        
        m[3] = m10
        m[4] = m11
        m[5] = m12
        
        m[6] = m20
        m[7] = m21
        m[8] = m22
    }
    
    func zero()
    {
        for (var i = 0; i < 9; i++)
        {
            m[i] = 0.0
        }
    }
    
    func get(row:Int, _ col:Int) -> Double
    {
        return m[(3 * row + col)]
    }
    
    func identity()
    {
        m[0] = 1
        m[1] = 0
        m[2] = 0
        m[3] = 0
        m[4] = 1
        m[5] = 0
        m[6] = 0
        m[7] = 0
        m[8] = 1
    }
    
    func setDiagonal(d:Double)
    {
        m[0] = d
        m[4] = d
        m[8] = d
    }
    
    func set(row:Int, _ col:Int, _ value:Double)
    {
        m[(3 * row + col)] = value
    }
    
    func set(m00:Double, _ m01:Double, _ m02:Double,
           _ m10:Double, _ m11:Double, _ m12:Double,
           _ m20:Double, _ m21:Double, _ m22:Double)
    {
        m[0] = m00
        m[1] = m01
        m[2] = m02
        
        m[3] = m10
        m[4] = m11
        m[5] = m12
        
        m[6] = m20
        m[7] = m21
        m[8] = m22
    }
    
    func minusEquals(input:Matrix3x3d)
    {
        for var i = 0; i < 9; i++
        {
            m[i] -= input.m[i]
        }
    }
    
    func set(input:Matrix3x3d)
    {
        for var i = 0; i < 9; i++
        {
            m[i] = input.m[i]
        }
    }
    
    func setColumn(col:Int, _ v:Vector3d)
    {
        m[col] = v.x
        m[col + 3] = v.y
        m[col + 6] = v.z
    }
    
    func scale(s:Double)
    {
        for var i = 0; i < 9; i++
        {
            m[i] *= s
        }
    }
    
    func plusEquals(input:Matrix3x3d)
    {
        for var i = 0; i < 9; i++
        {
            m[i] += input.m[i]
        }
    }
    
    func determinant() -> Double
    {
        return get(0, 0) * (get(1, 1) * get(2, 2) - get(2, 1) * get(1, 2))
             - get(0, 1) * (get(1, 0) * get(2, 2) - get(1, 2) * get(2, 0))
             + get(0, 2) * (get(1, 0) * get(2, 1) - get(1, 1) * get(2, 0))
    }
    
    func transpose()
    {
        var tmp = m[1]
        m[1] = m[3]
        m[3] = tmp
        tmp = m[2]
        m[2] = m[6]
        m[6] = tmp
        tmp = m[5]
        m[5] = m[7]
        m[7] = tmp
    }
    
    func transpose(inout result:Matrix3x3d)
    {
        result.m[0] = m[0]
        result.m[1] = m[3]
        result.m[2] = m[6]
        result.m[3] = m[1]
        result.m[4] = m[4]
        result.m[5] = m[7]
        result.m[6] = m[2]
        result.m[7] = m[5]
        result.m[8] = m[8]
    }
    
    func invert(inout result:Matrix3x3d) -> Bool
    {
        let d = determinant()
        
        if (d == 0.0)
        {
            return false;
        }
        
        let invdet = 1.0 / d
        
        result.set( (m[4] * m[8] - m[7] * m[5]) * invdet,
                   -(m[1] * m[8] - m[2] * m[7]) * invdet,
                    (m[1] * m[5] - m[2] * m[4]) * invdet,
                   -(m[3] * m[8] - m[5] * m[6]) * invdet,
                    (m[0] * m[8] - m[2] * m[6]) * invdet,
                   -(m[0] * m[5] - m[3] * m[2]) * invdet,
                    (m[3] * m[7] - m[6] * m[4]) * invdet,
                   -(m[0] * m[7] - m[6] * m[1]) * invdet,
                    (m[0] * m[4] - m[3] * m[1]) * invdet)
        
        return true
    }
    
    func toString() -> String
    {
        let matString = "{\(m[0]), \(m[1]), \(m[2]), \(m[3]), \(m[4]), \(m[5]), \(m[6]), \(m[7]), \(m[8])"
        
        return matString
    }
    
    static func mult(a:Matrix3x3d, _ b:Matrix3x3d, inout result:Matrix3x3d)
    {
        result.set(a.m[0] * b.m[0] + a.m[1] * b.m[3] + a.m[2] * b.m[6],
                   a.m[0] * b.m[1] + a.m[1] * b.m[4] + a.m[2] * b.m[7],
                   a.m[0] * b.m[2] + a.m[1] * b.m[5] + a.m[2] * b.m[8],
                   a.m[3] * b.m[0] + a.m[4] * b.m[3] + a.m[5] * b.m[6],
                   a.m[3] * b.m[1] + a.m[4] * b.m[4] + a.m[5] * b.m[7],
                   a.m[3] * b.m[2] + a.m[4] * b.m[5] + a.m[5] * b.m[8],
                   a.m[6] * b.m[0] + a.m[7] * b.m[3] + a.m[8] * b.m[6],
                   a.m[6] * b.m[1] + a.m[7] * b.m[4] + a.m[8] * b.m[7],
                   a.m[6] * b.m[2] + a.m[7] * b.m[5] + a.m[8] * b.m[8])
    }
    
    static func mult(a:Matrix3x3d, _ v:Vector3d, inout result:Vector3d)
    {
        result.set(a.m[0] * v.x + a.m[1] * v.y + a.m[2] * v.z,
                   a.m[3] * v.x + a.m[4] * v.y + a.m[5] * v.z,
                   a.m[6] * v.x + a.m[7] * v.y + a.m[8] * v.z)
    }
    
    static func add(a:Matrix3x3d, _ b:Matrix3x3d, inout result:Matrix3x3d)
    {
        for var i = 0; i < 9; i++
        {
            result.m[i] = a.m[i] + b.m[i]
        }
    }
}

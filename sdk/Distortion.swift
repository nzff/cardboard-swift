
import Foundation

class Distortion
{
    var coefficients:[Float] = [0.441, 0.156]
    
    init()
    {
        coefficients = [0.441, 0.156]
    }
    
    init(distortion:Distortion)
    {
        for (index, newCoefficient) in distortion.coefficients.enumerate()
        {
            coefficients[index] = newCoefficient
        }
    }
    
    func setCoefficients(coefficient:Float)
    {
        for (index, _) in coefficients.enumerate()
        {
            coefficients[index] = coefficient
        }
    }
    
    func distortionFactor(radius:Float) -> Float
    {
        var result:Float = 1.0
        var rFactor: Float = 1.0
        
        let squaredRadius = radius * radius
        
        for coefficient in coefficients
        {
            rFactor *= squaredRadius
            result += coefficient * rFactor
        }
        
        return result
    }
    
    func distort(radius:Float) -> Float
    {
        return radius * distortionFactor(radius)
    }
    
    func distortInverse(radius:Float) -> Float
    {
        var r:Float = radius * 0.9
        
        var r0:Float = radius / 0.9
        var dr0:Float = radius - distort(r0)
        
        while(fabsf(r-r0)>0.0001)
        {
            let dr = radius - distort(r)
            let r2 = r - dr * ((r - r0) / (dr - dr0))
            
            r0 = r
            r = r2
            dr0 = dr
        }
        
        return r
    }
}
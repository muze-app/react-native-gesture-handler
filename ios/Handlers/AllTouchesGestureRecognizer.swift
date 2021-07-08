import Foundation
import UIKit

/** A 2D vector composed of `CGFloat`s. */
public protocol CGVector2 {
    init(x: CGFloat, y: CGFloat)
    var x: CGFloat { get set }
    var y: CGFloat { get set }
}

// DL: some of these methods are not necessary for this project - I pulled some
// of this code from a personal codebase, and I'm not taking the time to look
// through what is / is not used.
extension CGVector2 {
    init<V: CGVector2>(_ otherVec2: V) {
        self.init(x: otherVec2.x, y: otherVec2.y)
    }
    
    static func unit(_ n: CGFloat = 1) -> Self {
        Self(x: n, y: n)
    }
    
    var reciprocal: Self {
        Self.unit(1) / self
    }
    
    var magnitude: CGFloat {
        return (x * x + y * y).squareRoot()
    }
    
    func zip<V: CGVector2>(_ rhs: V, with zipper: (CGFloat, CGFloat) -> CGFloat) -> Self {
        return Self(x: zipper(self.x, rhs.x), y: zipper(self.y, rhs.y))
    }
    
    func map(_ transform: (CGFloat) -> CGFloat) -> Self {
        return Self(x: transform(x), y: transform(y))
    }
    
    func map<T>(_ transform: (CGFloat) -> T) -> (x: T, y: T) {
        return (x: transform(x), y: transform(y))
    }
    
    static func -<V: CGVector2>(lhs: Self, rhs: V) -> Self {
        return lhs.zip(rhs, with: (-))
    }
    
    static prefix func -(operand: Self) -> Self {
        operand.negated
    }
    
    var negated: Self {
        map { -$0 }
    }
    
    static func +<V: CGVector2>(lhs: Self, rhs: V) -> Self {
        lhs.zip(rhs, with: (+))
    }
    
    static func +=<V: CGVector2>(lhs: inout Self, rhs: V) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
    
    static func *(scalar: CGFloat, v: Self) -> Self {
        return v.map { $0 * scalar }
    }
    
    static func *(v: Self, scalar: CGFloat) -> Self {
        return scalar * v
    }
    
    static func *<V: CGVector2>(rhs: Self, lhs: V) -> Self {
        rhs.zip(lhs, with: (*))
    }
    
    static func /<V: CGVector2>(l: Self, r: V) -> Self {
        return Self(x: l.x / r.x, y: l.y / r.y)
    }
    
    var floored: Self {
        Self(x: floor(x), y: floor(y))
    }
    
    var rounded: Self {
        Self(x: floor(x + 0.5), y: floor(y + 0.5))
    }
    
    func distance<V: CGVector2>(to other: V) -> CGFloat {
        return (other - self).magnitude
    }
    
    var direction: CGFloat {
        var out = atan2(y, x)
        if out < 0 {
            out += 2 * .pi
        }
        return out
    }
}

// Adopt `CGVector2` on CGPoint / CGSize.
extension CGPoint: CGVector2 {}
extension CGPoint: ExpressibleByArrayLiteral {}
extension CGSize: CGVector2 {
    public init(x: CGFloat, y: CGFloat) {
        self.init(width: x, height: y)
    }
    
    public var x: CGFloat {
        get { width }
        set { width = newValue }
    }
    public var y: CGFloat {
        get { height }
        set { height = newValue }
    }
}
extension CGSize: ExpressibleByArrayLiteral {}

extension CGVector2 where Self: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: CGFloat...) {
        assert(elements.count == 2, "Expected array literal with 2 elements")
        self.init(x: elements[0], y: elements[1])
    }
}

/** Gesture recognizer tracking all touch locations. */
public class TraceGestureRecognizer: UIGestureRecognizer {
    struct TouchSample {
        let location: CGPoint
        let touch: UITouch
        
        static func from(_ touch: UITouch, transform: CGAffineTransform, locationReference: UIView?) -> TouchSample {
            TouchSample(
                location: touch.location(in: locationReference).applying(transform),
                touch: touch
            )
        }
    }
    
    var samples: Set<TouchSample> = []
    var transform: CGAffineTransform = .identity
    
    func didUpdateSamples(previousSamples: Set<TouchSample>, with event: UIEvent) {}
    
    public override func reset() {
        super.reset()
        samples = []
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        let previousSamples = samples
        samples.formUnion(Set(touches.map { TouchSample.from($0, transform: transform, locationReference: self.view) }))
        if samples.count == 1 {
            state = .began
        } else {
            state = .changed
        }
        didUpdateSamples(previousSamples: previousSamples, with: event)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        let previousSamples = samples
        samples = Set(samples.map { sample -> TouchSample in
            guard touches.contains(sample.touch) else {
                return sample
            }
            return TouchSample.from(sample.touch, transform: transform, locationReference: self.view)
        })
        state = .changed
        didUpdateSamples(previousSamples: previousSamples, with: event)
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        let previousSamples = samples
        samples = samples.filter { $0.touch.phase != .cancelled }
        if samples.count == 0 {
            state = .ended
        } else {
            state = .changed
        }
        didUpdateSamples(previousSamples: previousSamples, with: event)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        let previousSamples = samples
        samples = samples.filter { $0.touch.phase != .ended }
        if samples.count == 0 {
            state = .ended
        } else {
            state = .changed
        }
        didUpdateSamples(previousSamples: previousSamples, with: event)
    }
}

extension TraceGestureRecognizer.TouchSample: Equatable {}
extension TraceGestureRecognizer.TouchSample: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(touch)
        hasher.combine(location.x)
        hasher.combine(location.y)
    }
}


/** Gesture recognizer that provides a `transformFromLastChange` which
 represents an incremental change in a transform controlled by 1-2 finger
 gestures, like Google Maps. */
@objc public class NaturalTransformGestureRecognizer: TraceGestureRecognizer {
    var previousSamples: Set<TraceGestureRecognizer.TouchSample> = []
    
    /** Transform applied to touch locations before calculating a transform from
     the touches. This is usually the current effective transform of the object
     being transformed. */
    var preTransformCalculationTransform: CGAffineTransform = .identity
    
    /** An incremental transform representing the change between the previous
     two gesture changes (precisely, the change between the last two invocations
     of `didUpdateSamples(previousSamples:, with:)`). */
    @objc public var transformFromLastChange: CGAffineTransform {
        guard previousSamples.count > 0 && samples.count > 0 else {
            return .identity
        }
        
        // `joined(with:, on:)` will quietly drop touches that were added or
        // removed in this frame - i.e. the calculated transform will ignore
        // those touches.
        let samplesByTouch = previousSamples.joined(with: samples, on: { $0.touch })
        
        switch samplesByTouch.count {
            case 1:
                // simple translation - just find the offset
                let (previousSample, sample) = samplesByTouch.values.first!
                let translation = sample.location.applying(preTransformCalculationTransform) - previousSample.location.applying(preTransformCalculationTransform)
                return CGAffineTransform(translationX: translation.x, y: translation.y)
                
            case 2:
                // two-finger gesture -> two-finger gesture: find transform
                // fitting these segments.
                let vals = Array(samplesByTouch.values)
                let (previousSampleA, sampleA) = vals[0]
                let (previousSampleB, sampleB) = vals[1]
                
                return transformFromPinch(
                    startingFrom: (
                        previousSampleA.location.applying(preTransformCalculationTransform),
                        previousSampleB.location.applying(preTransformCalculationTransform)
                    ),
                    endingAt: (
                        sampleA.location.applying(preTransformCalculationTransform),
                        sampleB.location.applying(preTransformCalculationTransform)
                    )
                )
                
            default:
                // for everything else, don't effect a change (e.g. gestures
                // with more than 2 fingers)
                return .identity
        }
    }
    
    override func didUpdateSamples(previousSamples: Set<TraceGestureRecognizer.TouchSample>, with event: UIEvent) {
        super.didUpdateSamples(previousSamples: previousSamples, with: event)
        self.previousSamples = previousSamples
    }
}


typealias LineSegment = (CGPoint, CGPoint)

/** Calculates a transform which transforms `startSegment` to `endSegment`.
 There's probably a much simpler way of doing this - pulled this from an old
 project where I stumbled through the math myself. */
fileprivate func transformFromPinch(startingFrom startSegment: LineSegment,
                                    endingAt endSegment: LineSegment) -> CGAffineTransform {
    let (a, b) = startSegment
    let (aʹ, bʹ) = endSegment
    
    let displacement = b - a
    let displacementʹ = bʹ - aʹ
    
    let rotationAngle =
        atan2(displacementʹ.y, displacementʹ.x)
        - atan2(displacement.y, displacement.x)
    let scaleFactor = displacementʹ.magnitude / displacement.magnitude
    let initialMidpoint = 0.5 * displacement + a
    let finalMidpoint = 0.5 * displacementʹ + aʹ
    
    var pivotPoint: CGPoint? {
        let u_ad = (bʹ.y - aʹ.y) * (b.x - a.x) - (bʹ.x - aʹ.x) * (b.y - a.y)
        
        guard u_ad != 0 else {
            // parallel
            return nil
        }
        
        let u_an = (bʹ.x - aʹ.x) * (a.y - aʹ.y) - (bʹ.y - aʹ.y) * (a.x - aʹ.x)
        let u_a = u_an / u_ad
        
        return CGPoint(x: a.x + u_a * (b.x - a.x),
                       y: a.y + u_a * (b.y - a.y))
    }
    
    var rotationTransform: CGAffineTransform = .identity
    
    if let pivotPoint = pivotPoint {
        rotationTransform = rotationTransform
            .concatenating(CGAffineTransform(translationX: -pivotPoint.x, y: -pivotPoint.y))
            .concatenating(CGAffineTransform(rotationAngle: rotationAngle))
            .concatenating(CGAffineTransform(translationX: pivotPoint.x, y: pivotPoint.y))
    }
    
    let rotatedMidpoint =
        initialMidpoint.applying(rotationTransform)
    
    let scaleOffset1 =
        CGAffineTransform(translationX: -rotatedMidpoint.x,
                          y: -rotatedMidpoint.y)
    let scaleXform =
        CGAffineTransform(scaleX: scaleFactor,
                          y: scaleFactor)
    let scaleOffset2 =
        CGAffineTransform(translationX: finalMidpoint.x,
                          y: finalMidpoint.y)
    
    let scaleTransform = CGAffineTransform.identity
        .concatenating(scaleOffset1)
        .concatenating(scaleXform)
        .concatenating(scaleOffset2)
    
    return CGAffineTransform.identity
        .concatenating(rotationTransform)
        .concatenating(scaleTransform)
}

extension Sequence {
    /**
     Performs a SQL-like join between two sequences. This will drop ambiguous
     rows (see example for `"NYC"` key), and will drop rows that do not have a
     "match" (see example for `"St. Louis"` key).
     
     ```swift
     let students = [
       [name: "David", hometown: "Cranston"],
       [name: "Stephen", hometown: "St. Louis"],
       [name: "Erin", hometown: "NYC"],
     ]
     let teachers = [
       [name: "Mo", hometown: "NYC"],
       [name: "Brett", hometown: "San Francisco"],
       [name: "Kathy", hometown: "Cranston"],
       [name: "Suzanne", hometown: "NYC"],
     ]
     students.joined(with: teachers, on: { $0["hometown"] }).mapValues { ($0.0["name"], $0.1["name"] }
     // => [
     //   "Cranston": ("David", "Kathy"),
     //   "NYC": ("Erin", "Suzanne"),
     // ]
     
     let a = [1, 2, 3, 4]
     let b = [4, 5]
     
     a.joined(with: b, on: { $0 % 2 })
     // => [0: (4, 4), 1: (3, 5)]
     ```
     */
    func joined<S: Sequence, JoinKey: Hashable>(with other: S, on joinAxis: (Element) -> JoinKey) -> [JoinKey: (Element, Element)] where S.Element == Element {
        var keyed: [JoinKey: Element] = [:]
        for item in self {
            keyed[joinAxis(item)] = item
        }
        
        var out: [JoinKey: (Element, Element)] = [:]
        for item in other {
            let joinKey = joinAxis(item)
            if let fromSelf = keyed[joinKey] {
                out[joinKey] = (fromSelf, item)
            }
        }
        
        return out
    }
    
}


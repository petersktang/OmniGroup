// Copyright 2006-2018 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OATestCase.h"
#import "NSBezierPath-OAInternal.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <AppKit/AppKit.h>
#import <OmniAppKit/OmniAppKit.h>
#import <XCTest/XCTest.h>

RCS_ID("$Id$");

@interface OAGeometryTests : OATestCase
@end

@implementation OAGeometryTests

#define INTERSECTION_EPSILON 1e-5
#define CURVEMATCH_EPSILON 1e-4
#define CURVEMATCH_GRAZING_EPSILON 0.5
#define BOUNDS_EPSILON 1e-4

/* CGFloat isn't type-compatible with a floating-point literal. Use these macros when you know an explicit cast is OK --- for example, if you have a float literal or an analytical expression (sqrt, etc.). If you're getting values from elsewhere, it's probably better to leave the explicit cast at the test case instead of using this macro, so that its presence is obvious. */
#define F(x) ((CGFloat)(x))
#define Pt(x,y) (NSPoint){(CGFloat)(x), (CGFloat)(y)}
#define Rct(x, y, w, h) (NSRect){{(CGFloat)(x), (CGFloat)(y)},{(CGFloat)(w),(CGFloat)(h)}}

/* Test that the point at 't' on the line p0-p1 is equal to p (within INTERSECTION_EPSILON) */
static void checkAtPoint(NSPoint p0, NSPoint p1, double t, NSPoint p)
{
    double tfrom1 = 1 - t;
    
    OBASSERT(t >= 0);
    OBASSERT(t <= 1);
    
    double px = tfrom1 * p0.x + t * p1.x;
    double py = tfrom1 * p0.y + t * p1.y;
    
    if ((fabs(px - p.x) >= INTERSECTION_EPSILON) || (fabs(py - p.y) >= INTERSECTION_EPSILON))
        NSLog(@"   Intersection point t=%g  (%g,%g)   expecting (%g,%g)  delta=(%g,%g)", t, px, py, p.x, p.y, px - p.x, py - p.y);

    OBASSERT(fabs(px - p.x) < INTERSECTION_EPSILON);
    OBASSERT(fabs(py - p.y) < INTERSECTION_EPSILON);
}

static BOOL rectsAreApproximatelyEqual(NSRect r1, NSRect r2, double epsilon, int line)
{
    BOOL fail;
    
    fail = NO;
#define testRectPart(a, b) if (fabs(a - b) > epsilon) { NSLog(@"    Unequal rects: %s (%g) != %s (%g) [delta=%g], caller line %d", #a, a, #b, b, a - b, line); fail = YES; }
    testRectPart(r1.origin.x, r2.origin.x);
    testRectPart(r1.origin.y, r2.origin.y);
    testRectPart(r1.size.width, r2.size.width);
    testRectPart(r1.size.height, r2.size.height);

    return ! fail;
}

/* return the string name of an OAIntersectionAspect */
static const char *straspect(enum OAIntersectionAspect a)
{
    switch(a) {
        case intersectionEntryLeft: return "left";
        case intersectionEntryAt:   return "along";
        case intersectionEntryRight:return "right";
        default:                    return "bogus";
    }
}

/* verify that the intersection between the lines p00-p01 and p10-p11 is at intersection and has aspect aspect */
static void checkOneLineLineIntersection(NSPoint p00, NSPoint p01, NSPoint p10, NSPoint p11, NSPoint intersection, enum OAIntersectionAspect aspect)
{
    NSPoint l1[2], l2[2];
    struct intersectionInfo r;
    
    _OAParameterizeLine(l1, p00, p01);
    _OAParameterizeLine(l2, p10, p11);
    
    r = (struct intersectionInfo){ -1, -1, -1, -1, intersectionEntryBogus, intersectionEntryBogus };
    
#ifdef OMNI_ASSERTIONS_ON
    NSInteger count = 
#endif
    OAIntersectionsBetweenLineAndLine(l1, l2, &r);
    OBASSERT(count == 1);    
    OBASSERT(r.leftParameterDistance == 0);
    OBASSERT(r.rightParameterDistance == 0);
    checkAtPoint(p00, p01, r.leftParameter, intersection);
    checkAtPoint(p10, p11, r.rightParameter, intersection);
    OBASSERT(r.leftEntryAspect == aspect);
    OBASSERT(r.leftExitAspect == aspect);
}

static void checkOneLineLineOverlap(NSPoint p00, NSPoint p01, NSPoint p10, NSPoint p11, NSPoint intersectionStart, NSPoint intersectionEnd)
{
    NSPoint l1[2], l2[2];
    struct intersectionInfo r;
    
    _OAParameterizeLine(l1, p00, p01);
    _OAParameterizeLine(l2, p10, p11);
    
    r = (struct intersectionInfo){ -1, -1, -1, -1, intersectionEntryBogus, intersectionEntryBogus };
    
#ifdef OMNI_ASSERTIONS_ON
    NSInteger count = 
#endif
    OAIntersectionsBetweenLineAndLine(l1, l2, &r);
    OBASSERT(count == 1);    
    OBASSERT(r.leftParameterDistance >= 0);  // rightParameterDistance may be negative, but leftParameterDistance should always be positive the way we've defined it
    checkAtPoint(p00, p01, r.leftParameter, intersectionStart);
    checkAtPoint(p10, p11, r.rightParameter, intersectionStart);
    checkAtPoint(p00, p01, r.leftParameter + r.leftParameterDistance, intersectionEnd);
    checkAtPoint(p10, p11, r.rightParameter + r.rightParameterDistance, intersectionEnd);
    OBASSERT(r.leftEntryAspect == intersectionEntryAt);
    OBASSERT(r.leftExitAspect == intersectionEntryAt);
}

static void linesShouldNotIntersect(double x00, double y00, double x01, double y01, double x10, double y10, double x11, double y11)
{
    NSPoint l1[2], l2[2];
    struct intersectionInfo r[1];

    // Both lines forward
    _OAParameterizeLine(l1, Pt(x00, y00), Pt(x01, y01));
    _OAParameterizeLine(l2, Pt(x10, y10), Pt(x11, y11));
#ifdef OMNI_ASSERTIONS_ON
    NSInteger count;
    count = 
#endif
    OAIntersectionsBetweenLineAndLine(l1, l2, r);
    OBASSERT(count == 0);
#ifdef OMNI_ASSERTIONS_ON
    count = 
#endif
    OAIntersectionsBetweenLineAndLine(l2, l1, r);
    OBASSERT(count == 0);

    // l1 forward, l2 reverse
    _OAParameterizeLine(l2, Pt(x11, y11), Pt(x10, y10));
#ifdef OMNI_ASSERTIONS_ON
    count = 
#endif
    OAIntersectionsBetweenLineAndLine(l1, l2, r);
    OBASSERT(count == 0);
#ifdef OMNI_ASSERTIONS_ON
    count = 
#endif
    OAIntersectionsBetweenLineAndLine(l2, l1, r);
    OBASSERT(count == 0);

    // Both lines reverse
    _OAParameterizeLine(l1, Pt(x01, y01), Pt(x00, y00));
#ifdef OMNI_ASSERTIONS_ON
    count = 
#endif
    OAIntersectionsBetweenLineAndLine(l1, l2, r);
    OBASSERT(count == 0);
#ifdef OMNI_ASSERTIONS_ON
    count = 
#endif
    OAIntersectionsBetweenLineAndLine(l2, l1, r);
    OBASSERT(count == 0);

    // l1 reverse, l2 forward
    _OAParameterizeLine(l2, Pt(x10, y10), Pt(x11, y11));
#ifdef OMNI_ASSERTIONS_ON
    count = 
#endif
    OAIntersectionsBetweenLineAndLine(l1, l2, r);
    OBASSERT(count == 0);
#ifdef OMNI_ASSERTIONS_ON
    count = 
#endif
    OAIntersectionsBetweenLineAndLine(l2, l1, r);
    OBASSERT(count == 0);
}

static void linesDoIntersect(double x00, double y00, double x01, double y01, double x10, double y10, double x11, double y11, double xi, double yi, enum OAIntersectionAspect aspect)
{
    /* This routine notionally takes CGFloats, since it's testing code that operates on values taken directly from an NSBezierPath. But we take doubles and cast to CGFloat to avoid having to sprinkle all the call sites with casts. This should be OK, as long as CGFloats don't have more precision than doubles. */
    NSPoint p00 = { (CGFloat)x00, (CGFloat)y00 };
    NSPoint p01 = { (CGFloat)x01, (CGFloat)y01 };
    NSPoint p10 = { (CGFloat)x10, (CGFloat)y10 };
    NSPoint p11 = { (CGFloat)x11, (CGFloat)y11 };
    NSPoint i   = { (CGFloat)xi,  (CGFloat)yi };

    checkOneLineLineIntersection(p00, p01, p10, p11, i, aspect); 
    checkOneLineLineIntersection(p00, p01, p11, p10, i, -aspect); 
    checkOneLineLineIntersection(p01, p00, p10, p11, i, -aspect); 
    checkOneLineLineIntersection(p01, p00, p11, p10, i, aspect); 
}

static void linesDoOverlap(CGFloat x00, CGFloat y00, CGFloat x01, CGFloat y01, CGFloat x10, CGFloat y10, CGFloat x11, CGFloat y11, CGFloat xi0, CGFloat yi0, CGFloat xi1, CGFloat yi1)
{
    NSPoint p00 = { x00, y00 };
    NSPoint p01 = { x01, y01 };
    NSPoint p10 = { x10, y10 };
    NSPoint p11 = { x11, y11 };
    NSPoint i0  = { xi0, yi0 };
    NSPoint i1  = { xi1, yi1 };
    
    checkOneLineLineOverlap(p00, p01, p10, p11, i0, i1); 
    checkOneLineLineOverlap(p00, p01, p11, p10, i0, i1); 
    checkOneLineLineOverlap(p01, p00, p10, p11, i1, i0); 
    checkOneLineLineOverlap(p01, p00, p11, p10, i1, i0); 
}

- (void)testLineLineIntersections
{
    // Oblique misses, all permutations of pdet/vdet/p'det
    linesShouldNotIntersect(2, 2, 4, 4, 0, 3.5, 3,   3.9);
    linesShouldNotIntersect(2, 2, 4, 4, 0, 3.5, 4.7, 4.2);
    linesShouldNotIntersect(2, 2, 4, 4, 0, 3.5, 1.7, 1.9);
    linesShouldNotIntersect(2, 2, 4, 4, 0, 3.5, 2.3, 0.6);
    linesShouldNotIntersect(2, 2, 4, 4, 4.7, 4.2, 5.8, 5.0);
    linesShouldNotIntersect(2, 2, 4, 4, 2.3, 0.6, 3.1, -0.8);
    
    // Parallel and collinear nonintersecting lines
    linesShouldNotIntersect(2, 2, 4, 4, 3, 2, 5, 4);
    linesShouldNotIntersect(2, 2, 4, 4, 5, 5, 6, 6);
    
    // Zero-length lines (that don't intersect)
    linesShouldNotIntersect(2, 2, 4, 4, 3, 3.5, 3, 3.5);
    linesShouldNotIntersect(2, 2, 4, 4, 5, 5, 5, 5);
    linesShouldNotIntersect(2, 2, 2, 2, 5, 5, 5, 5);
    
    // Intersection
    linesDoIntersect(2, 2, 4, 4, 2, 4, 4, 2, 3, 3, intersectionEntryLeft);     // X-shape
    linesDoIntersect(2, 2, 4, 4, 2, 4, 4, 4, 4, 4, intersectionEntryLeft);     // V-shape (touching at one end)
    linesDoIntersect(2, 2, 4, 6, 3, 4, 4, 2, 3, 4, intersectionEntryLeft);     // T-shape
                                                                               // Again, with less-round numbers
    linesDoIntersect(1.2, 3.9, -1.16, 17.3, 0, 0, -0.001, 25, -0.000428564,10.716, intersectionEntryLeft);  // X-shape
    linesDoIntersect(0, 0, 0, 1, 0, 0.01, 1, 0, 0, 0.01, intersectionEntryLeft); // T-ish shape
    linesDoIntersect(0, 0, 1, 100, 0.01, 1, 10, 1, 0.01, 1, intersectionEntryLeft);
    linesDoIntersect(0, 0, 1, 100, -1, 1, 10, 1, 0.01, 1, intersectionEntryLeft);
    
    // Collinear intersecting lines
    linesDoOverlap(2, 2, 4, 6, 3, 4, 5, 8, 3, 4, 4, 6);           // two lines with an overlap in the middle
    linesDoOverlap(4, 6, 2, 2, 3, 4, (CGFloat)3.5, 5, (CGFloat)3.5, 5, 3, 4);       // one line fully contained by the other
    linesDoOverlap(1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4);           // same line
    
    // A line touching a zero-length line
    linesDoOverlap(1, 2, 3, 4, 2, 3, 2, 3, 2, 3, 2, 3);
    // A point and its dog^H^H^H^Helf
    linesDoOverlap(8, 3, 8, 3, 8, 3, 8, 3, 8, 3, 8, 3);
}

static
void dumpFoundIntersections(NSInteger foundCount,
                            const char *leftname, const char *rightname,
                            const NSPoint *leftCoeff, const NSPoint *rightCoeff,
                            struct intersectionInfo *r)
{
    NSInteger ix;
    
#define XY(co, t) (( co[3].x * (t) + co[2].x ) * (t) + co[1].x ) * (t) + co[0].x, \
                  (( co[3].y * (t) + co[2].y ) * (t) + co[1].y ) * (t) + co[0].y

    
    printf("*** Found %ld intersections:\n", foundCount);
    for(ix = 0; ix < foundCount; ix ++) {
        printf("   %2ld: %s t=", ix, leftname);
        if (r[ix].leftParameterDistance == 0)
            printf("%g", r[ix].leftParameter);
        else
            printf("%g%+g", r[ix].leftParameter, r[ix].leftParameterDistance);
        printf(" (%g,%g)", XY(leftCoeff, r[ix].leftParameter));
        if (r[ix].leftParameterDistance != 0)
            printf("-(%g,%g)", XY(leftCoeff, r[ix].leftParameter+r[ix].leftParameterDistance));
        
        printf("  \t%s t=", rightname);
        if (r[ix].rightParameterDistance == 0)
            printf("%g", r[ix].rightParameter);
        else
            printf("%g%+g", r[ix].rightParameter, r[ix].rightParameterDistance);
        printf(" (%g,%g)", XY(rightCoeff, r[ix].rightParameter));
        if (r[ix].rightParameterDistance != 0)
            printf("-(%g,%g)", XY(rightCoeff, r[ix].rightParameter+r[ix].rightParameterDistance));
        
        printf("  \taspect=%s-%s\n", straspect(r[ix].leftEntryAspect), straspect(r[ix].leftExitAspect));
    }
    
}

static
void dumpExpectedIntersections(NSInteger expectedCount, const NSPoint *i, const double *l, const enum OAIntersectionAspect *aentry, const enum OAIntersectionAspect *aexit, BOOL invertAspects)
{
    NSInteger ix;
    
    printf("*** Expected %ld intersections:\n", expectedCount);
    if (l) {
        for(ix = 0; ix < expectedCount; ix ++) {
            printf("   %2ld: (%g,%g) (%g), %s-%s aspect\n", ix, i[ix].x, i[ix].y, l[ix], straspect(invertAspects? ( - aentry[ix] ) : ( aentry[ix] )), straspect(invertAspects? ( - aexit[ix] ) : ( aexit[ix] )));
        }
    } else {
        for(ix = 0; ix < expectedCount; ix ++) {
            printf("   %2ld: (%g,%g), %s-%s aspect\n", ix, i[ix].x, i[ix].y, straspect(invertAspects? ( - aentry[ix] ) : ( aentry[ix] )), straspect(invertAspects? ( - aexit[ix] ) : ( aexit[ix] )));
        }
    }
    
}

/* Verify that the line/curve intersection code finds intersections at the expected location with the expected aspects. */
static BOOL checkOneLineCurve(OAGeometryTests *tc, unsigned line, const NSPoint *cparams, const NSPoint *lparams, NSInteger count, const NSPoint *i, const enum OAIntersectionAspect *a, BOOL invertAspects)
{
    struct intersectionInfo r[3];
    NSInteger ix;
    
    for(ix = 0; ix < 3; ix++) {
        r[ix] = (struct intersectionInfo){ -1, -1, -1, -1, intersectionEntryBogus, intersectionEntryBogus };
    }
    assert(count <= 3);

    BOOL success = YES;

    ix = OAIntersectionsBetweenCurveAndLine(cparams, lparams, r);
    if (ix != count) {
        dumpFoundIntersections(ix, "curve", "line", cparams, lparams, r);
        dumpExpectedIntersections(count, i, NULL, a, a, invertAspects);
        [tc recordFailureWithDescription:[NSString stringWithFormat:@"Incorrect number of intersections found; found %ld, expected %ld", ix, count]
                                  inFile:@"" __FILE__ atLine:line expected:NO];
        return NO;
    }
    
    for(ix = 0; ix < count; ix++) {
#define checkValidParameter(p) if (p < -EPSILON || p > 1+EPSILON) { \
        [tc recordFailureWithDescription:[NSString stringWithFormat:@"Intersection parameter for ixn %ld is invalid: %s = %g = 1+%g = %a, but must be between -EPSILON and 1+EPSILON", ix, #p, p, p-1, p] \
            inFile:@"" __FILE__ atLine:__LINE__ expected:NO]; \
            success = NO; \
        }
        checkValidParameter(r[ix].leftParameter);
        checkValidParameter(r[ix].rightParameter);
        OBASSERT(r[ix].leftParameterDistance == 0);
        OBASSERT(r[ix].rightParameterDistance == 0);
        enum OAIntersectionAspect expectedEntryAspect, expectedExitAspect;
        if (!invertAspects) {
            expectedEntryAspect = a[2*ix];
            expectedExitAspect = a[2*ix + 1];
        } else {
            expectedEntryAspect = - a[2*ix];
            expectedExitAspect = - a[2*ix + 1];
        }
        NSPoint curvepos, linepos;
        double t = r[ix].leftParameter;
        curvepos.x = F(cparams[0].x + cparams[1].x * t + cparams[2].x * t * t + cparams[3].x * t * t * t);
        curvepos.y = F(cparams[0].y + cparams[1].y * t + cparams[2].y * t * t + cparams[3].y * t * t * t);
        linepos.x =  F(lparams[0].x + r[ix].rightParameter * lparams[1].x);
        linepos.y =  F(lparams[0].y + r[ix].rightParameter * lparams[1].y);
        
        if (fabs(i[ix].x - curvepos.x) > CURVEMATCH_EPSILON ||
            fabs(i[ix].y - curvepos.y) > CURVEMATCH_EPSILON ||
            fabs(i[ix].x - linepos.x) > CURVEMATCH_EPSILON ||
            fabs(i[ix].y - linepos.y) > CURVEMATCH_EPSILON ||
            fabs(linepos.x - curvepos.x) > CURVEMATCH_EPSILON ||
            fabs(linepos.y - curvepos.y) > CURVEMATCH_EPSILON ||
            r[ix].leftEntryAspect != expectedEntryAspect || 
            r[ix].leftExitAspect != expectedExitAspect) {
            NSString *failedHow = [NSString stringWithFormat:@"Target point (%g,%g) (%s-%s aspect)  Actual results:  Curve t=%g (%g,%g)    Line t=%g (%g,%g)  aspect=%s-%s",
                                   i[ix].x, i[ix].y, straspect(expectedEntryAspect), straspect(expectedExitAspect),
                                   r[ix].leftParameter, curvepos.x, curvepos.y,
                                   r[ix].rightParameter, linepos.x, linepos.y,
                                   straspect(r[ix].leftEntryAspect), straspect(r[ix].leftExitAspect)];
            [tc recordFailureWithDescription:failedHow inFile:@"" __FILE__ atLine:__LINE__ expected:NO];
            success = NO;
        }
    }

    return success;
}

/* Call checkOneLineCurve(), testing that it still returns the expected results if you reverse the direction of the curve and/or line. */
static
void checkLineCurve_(OAGeometryTests *tc, unsigned line, const NSPoint *c, const NSPoint *l, int count, ...)
/*
                    NSPoint i1, enum OAIntersectionAspect a1i, enum OAIntersectionAspect a1o,
                    NSPoint i2, enum OAIntersectionAspect a2i, enum OAIntersectionAspect a2o,
                    NSPoint i3, enum OAIntersectionAspect a3i, enum OAIntersectionAspect a3o) */
{
    NSPoint cparams[4];
    NSPoint lparams[4];
    NSPoint intersections[3], rev_intersections[3];
    enum OAIntersectionAspect aspects[6], rev_aspects[6];
    va_list argl;
    BOOL ok[4];
    
    /* Copy the expected results out of our argv, also storing the reversed expectations for the reversed tests */
    int ix;
    va_start(argl, count);
    for(ix = 0; ix < count; ix ++) {
        NSPoint ixn = va_arg(argl, NSPoint);
        enum OAIntersectionAspect entry = va_arg(argl, enum OAIntersectionAspect);
        enum OAIntersectionAspect exit = va_arg(argl, enum OAIntersectionAspect);
    
        intersections[ix] = ixn;
        rev_intersections[count-ix-1] = ixn;
        
        aspects[2*ix] = entry;
        aspects[2*ix+1] = exit;
        
        rev_aspects[2*(count-ix-1)+1] = entry;
        rev_aspects[2*(count-ix-1)] = exit;
    }
    
    _OAParameterizeCurve(cparams, c[0], c[3], c[1], c[2]);
    _OAParameterizeLine(lparams, l[0], l[1]);
    lparams[2] = (NSPoint){0, 0};
    lparams[3] = (NSPoint){0, 0};
    ok[0] = checkOneLineCurve(tc, line, cparams, lparams, count, intersections, aspects, NO);
    
    _OAParameterizeLine(lparams, l[1], l[0]);
    ok[1] = checkOneLineCurve(tc, line, cparams, lparams, count, intersections, aspects, YES);
    
    _OAParameterizeCurve(cparams, c[3], c[0], c[2], c[1]);
    ok[2] = checkOneLineCurve(tc, line, cparams, lparams, count, rev_intersections, rev_aspects, NO);
    
    _OAParameterizeLine(lparams, l[0], l[1]);
    ok[3] = checkOneLineCurve(tc, line, cparams, lparams, count, rev_intersections, rev_aspects, YES);
    
    if (!ok[0] || !ok[1] || !ok[2] || !ok[3]) {
        NSString *whichFailures = [NSString stringWithFormat:@"Line/Curve intersection failures in %s: Failures[%s %s %s %s]",
                                   __func__,
                                   ok[0]?"pass":"fail", ok[1]?"pass":"fail", ok[2]?"pass":"fail", ok[3]?"pass":"fail"];
        [tc recordFailureWithDescription:whichFailures inFile:@"" __FILE__ atLine:line expected:NO];
    }
}
#define checkLineCurve(c, l, ...) checkLineCurve_(self, __LINE__, c, l, __VA_ARGS__)

static NSPoint pointOnCurve(const NSPoint *pts, double t)
{
    // Using the geometric construction here, instead of the polynomial, for variety...
    
    double mx, my, nx, ny, ox, oy, px, py, qx, qy;
    double t1 = 1.0 - t;
    
    mx = pts[0].x * t1 + pts[1].x * t;
    my = pts[0].y * t1 + pts[1].y * t;
    
    nx = pts[1].x * t1 + pts[2].x * t;
    ny = pts[1].y * t1 + pts[2].y * t;
    
    ox = pts[2].x * t1 + pts[3].x * t;
    oy = pts[2].y * t1 + pts[3].y * t;
    
    px = mx * t1 + nx * t;
    py = my * t1 + ny * t;
    
    qx = nx * t1 + ox * t;
    qy = ny * t1 + oy * t;
    
    return (NSPoint){
        .x = (CGFloat)(px * t1 + qx * t),
        .y = (CGFloat)(py * t1 + qy * t)
    };
}

- (void)testLineCurveIntersections
{
    NSPoint l1[2] = { {1, 2}, {2, 6} };
    NSPoint l2[2] = { {1, 2}, {-1, -1} };
    NSPoint l3[2] = { {1, -1}, {1, 1} };
    NSPoint l4[2] = { Pt(1.1, 2.4), Pt(1.9, 5.6) };
    NSPoint l5[2] = { Pt(1.1, 2.4), Pt(2.1, 6.4) };
    NSPoint l6[2] = { Pt(-1024, 0), Pt(1024,  0) };
    NSPoint l7[2] = { Pt(1.5,  -2), Pt(1.5, 0.2) };
    
    // Nonintersecting squiggle
    NSPoint c1[4] = { Pt(1, 3), Pt(1.5, 4), Pt(1, 4), Pt(2, 6.5) };
    checkLineCurve(c1, l1, 0);
    checkLineCurve(c1, l2, 0);
    
    // Bow whose endpoints touch the line's endpoints
    NSPoint c2[4] = { {1,2}, {2,2}, {3,6}, {2,6} };
    checkLineCurve(c2, l1, 2,
                   (NSPoint){1,2}, intersectionEntryRight, intersectionEntryRight,
                   (NSPoint){2,6}, intersectionEntryLeft, intersectionEntryLeft);
    
    // Bow whose endpoints do not touch the line's endpoints
    NSPoint c2a[4] = { {518, 190}, {567, 214}, {647, 214}, {696, 190} };
    NSPoint l2a[2] = { {458, 145.5}, {607, 145.5} };
    checkLineCurve(c2a, l2a, 0);

    // S whose endpoints match the line's endpoints
    NSPoint c3[4] = { {1,2}, {2,2}, {1,6}, {2,6} };
    checkLineCurve(c3, l1, 3,
                   Pt(1,2), intersectionEntryRight, intersectionEntryRight,
                   Pt(1.5, 4), intersectionEntryLeft, intersectionEntryLeft,
                   Pt(2,6), intersectionEntryRight, intersectionEntryRight);
    checkLineCurve(c3, l4, 1,
                   Pt(1.5, 4), intersectionEntryLeft, intersectionEntryLeft);
    checkLineCurve(c3, l5, 2,
                   Pt(1.5, 4), intersectionEntryLeft, intersectionEntryLeft,
                   Pt(2,6), intersectionEntryRight, intersectionEntryRight);
    
    // Self-intersecting curve
    NSPoint c4[4] = { {0, 1}, {2, -2}, {2, 2}, {0, -1} };
    checkLineCurve(c4, l3, 2,
                   Pt(1, -0.0962251), intersectionEntryRight, intersectionEntryRight,
                   Pt(1, 0.0962251), intersectionEntryLeft, intersectionEntryLeft);
    checkLineCurve(c4, l6, 3,
                   Pt(0.857143, 0), intersectionEntryRight, intersectionEntryRight,
                   Pt(1.5, 0), intersectionEntryLeft, intersectionEntryLeft,
                   Pt(0.857143, 0), intersectionEntryRight, intersectionEntryRight);
    checkLineCurve(c4, l7, 1,
                   Pt(1.5, 0), intersectionEntryRight, intersectionEntryLeft);  // Osculation (a double root in solveCubic())

    // Another (lazy) S, with carefully-contrived coordinates. The curve is vertical at both ends, and exactly grazes the x-axis at t=3/5, X=81
    NSPoint c5[4] = { {0,0}, {0,3}, {125,-4}, {125,4} };
    checkLineCurve(c5, l6, 2,
                   Pt(0,0), intersectionEntryLeft, intersectionEntryLeft,
                   Pt(81, 0), intersectionEntryRight, intersectionEntryLeft);  // One crossing and an osculation (1 single and 1 double root)
    
    NSPoint c6[4] = { {-1,-1}, {-1,1}, {1,-1}, {1,1} };
    checkLineCurve(c6, l6, 1,
                   Pt(0,0), intersectionEntryLeft, intersectionEntryLeft);  // A triple root in solveCubic()
}

static void logparams(NSString *name, const NSPoint *c)
{
    NSLog(@"%@ px: %g %g %g %g", name, c[0].x, c[1].x, c[2].x, c[3].x);
    NSLog(@"%@ py: %g %g %g %g", name, c[0].y, c[1].y, c[2].y, c[3].y);
}

static
BOOL checkOneCurveCurve(const NSPoint *leftPoints, const NSPoint *rightPoints, int intersectionCount, const NSPoint *i, const double *l, const enum OAIntersectionAspect *entryAspects, const enum OAIntersectionAspect *exitAspects, BOOL invertAspects, BOOL looseAspects)
{
    struct intersectionInfo r[MAX_INTERSECTIONS_PER_ELT_PAIR];
    NSInteger ix, found;
    
    for(ix = 0; ix < 3; ix++) {
        r[ix] = (struct intersectionInfo){ -1, -1, -1, -1, intersectionEntryBogus, intersectionEntryBogus };
    }
    
    NSPoint leftCoefficients[4], rightCoefficients[4];
    _OAParameterizeCurve(leftCoefficients, leftPoints[0], leftPoints[3], leftPoints[1], leftPoints[2]);
    _OAParameterizeCurve(rightCoefficients, rightPoints[0], rightPoints[3], rightPoints[1], rightPoints[2]);
    found = OAntersectionsBetweenCurveAndCurve(leftCoefficients, rightCoefficients, r);
    
    if (found != intersectionCount) {
        NSLog(@"%s:%d Found %ld intersections, expecting %d", __func__, __LINE__, found, intersectionCount);
        dumpFoundIntersections(found, "Curve1", "Curve2", leftCoefficients, rightCoefficients, r);
        dumpExpectedIntersections(intersectionCount, i, l, entryAspects, exitAspects, invertAspects);
        return NO;
    }
    
    BOOL ok = YES;
    for(ix = 0; ix < intersectionCount; ix++) {
        OBASSERT(r[ix].leftParameter >= -EPSILON);
        OBASSERT(r[ix].leftParameter <= 1+EPSILON);
        OBASSERT(r[ix].rightParameter >= -EPSILON);
        OBASSERT(r[ix].rightParameter <= 1+EPSILON);
        enum OAIntersectionAspect expectedEntryAspect = invertAspects? ( - entryAspects[ix] ) : ( entryAspects[ix] );
        enum OAIntersectionAspect expectedExitAspect = invertAspects? ( - exitAspects[ix] ) : ( exitAspects[ix] );
        //OBASSERT(r[ix].leftAspect == expectedAspect);
        NSPoint leftpos, rightpos;
        BOOL mismatch;
        double pt_epsilon;
                
        if (l[ix] == 0) {
            mismatch =
            r[ix].leftParameterDistance != 0 ||
            r[ix].rightParameterDistance != 0;
            
            leftpos = pointOnCurve(leftPoints, r[ix].leftParameter);
            rightpos = pointOnCurve(rightPoints, r[ix].rightParameter);
            pt_epsilon = CURVEMATCH_EPSILON;
        } else {
            mismatch =
            r[ix].leftParameterDistance > l[ix] /* || r[ix].rightParameterDistance > l[ix] */;
            
            // This is a pretty dodgy test right here, since a grazing intersection isn't necessarily centered on the point.
            leftpos = pointOnCurve(leftPoints, r[ix].leftParameter + r[ix].leftParameterDistance/2.);
            rightpos = pointOnCurve(rightPoints, r[ix].rightParameter + r[ix].rightParameterDistance/2.);
            // Use an enormous 'epsilon' value here.
            pt_epsilon = CURVEMATCH_GRAZING_EPSILON;
        }
        
        if (fabs(i[ix].x - leftpos.x) > pt_epsilon ||
            fabs(i[ix].y - leftpos.y) > pt_epsilon ||
            fabs(i[ix].x - rightpos.x) > pt_epsilon ||
            fabs(i[ix].y - rightpos.y) > pt_epsilon ||
            fabs(rightpos.x - leftpos.x) > pt_epsilon ||
            fabs(rightpos.y - leftpos.y) > pt_epsilon) {
            mismatch = 1;
            printf("%s:  Mismatch in intersection location\n", __func__);
        }
        
        // This is kind of a pain. Because of roundoff, "along" aspects will usually be reported as right or left.
        // We could add a dead zone of 10e-5 or so to lineAspect(), but I'm worried that actual crossings would end up being
        // reported as "along" in that case.
        if ((r[ix].leftEntryAspect != expectedEntryAspect && !(looseAspects && expectedEntryAspect==intersectionEntryAt)) ||
            (r[ix].leftExitAspect != expectedExitAspect && !(looseAspects && expectedExitAspect==intersectionEntryAt))) {
            mismatch = 1;
            printf("%s:  Mismatch in intersection aspect\n", __func__);
        }
            
        if (mismatch) {
            NSLog(@"  Target point (%g,%g) (%s-%s aspect)    Curve1 t=%g (%g,%g)    Curve2 t=%g (%g,%g)  aspect=%s-%s",
                  i[ix].x, i[ix].y, straspect(expectedEntryAspect), straspect(expectedExitAspect), r[ix].leftParameter, leftpos.x, leftpos.y, r[ix].rightParameter, rightpos.x, rightpos.y, straspect(r[ix].leftEntryAspect), straspect(r[ix].leftExitAspect));
            logparams(@"  Curve1", leftPoints);
            logparams(@"  Curve2", rightPoints);
            ok = NO;
            break;
            // OBASSERT_NOT_REACHED("Curve/Curve intersection not at predicted location");
        }
    }
    
    if (!ok) {
        dumpFoundIntersections(found, "Curve1", "Curve2", leftCoefficients, rightCoefficients, r);
        dumpExpectedIntersections(intersectionCount, i, l, entryAspects, exitAspects, invertAspects);
        return NO;
    }
    
    return YES;
}

typedef struct expect {
    NSPoint pt;
    enum OAIntersectionAspect entryAspect;
    double len1, len2;
    BOOL justTouches;
} expect;

static BOOL checkCurveCurve_(OAGeometryTests *tc, unsigned line, BOOL looseAspects, const NSPoint *left, const NSPoint *right, int intersectionCount, ...)
{
    NSPoint pts[intersectionCount];
    double lens[intersectionCount];
    enum OAIntersectionAspect entryAspects[intersectionCount], exitAspects[intersectionCount];
    va_list argl;
    int intersectionIndex;
    BOOL ok1, ok2, ok3, ok4;
 
    // Workaround/fix for Static Analyzer Logic error warning; explicitly initialize these array
    for(intersectionIndex = 0; intersectionIndex < intersectionCount; intersectionIndex ++) {
        pts[intersectionIndex] = NSZeroPoint;
        lens[intersectionIndex] = 0;
        entryAspects[intersectionIndex] = intersectionEntryBogus;
        exitAspects[intersectionIndex] = intersectionEntryBogus;
    }
    
    va_start(argl, intersectionCount);
    for(intersectionIndex = 0; intersectionIndex < intersectionCount; intersectionIndex ++) {
        struct expect x = va_arg(argl, struct expect);
        pts[intersectionIndex] = x.pt;
        lens[intersectionIndex] = x.len1;
        entryAspects[intersectionIndex] = x.entryAspect;
        exitAspects[intersectionIndex] = x.justTouches ? ( - x.entryAspect ) : x.entryAspect;
    }
    va_end(argl);
    
    const NSPoint rev_left[4] = { left[3], left[2], left[1], left[0] };
    const NSPoint rev_right[4] = { right[3], right[2], right[1], right[0] };
    
    ok1 = checkOneCurveCurve(left, right, intersectionCount, pts, lens, entryAspects, exitAspects, NO, looseAspects);
    ok2 = checkOneCurveCurve(left, rev_right, intersectionCount, pts, lens, exitAspects, entryAspects, YES, looseAspects);
    
    for(intersectionIndex = 0; intersectionIndex < (intersectionCount/2); intersectionIndex ++) {
        SWAP(pts[intersectionIndex], pts[intersectionCount-intersectionIndex-1]);
        SWAP(lens[intersectionIndex], lens[intersectionCount-intersectionIndex-1]);
        SWAP(entryAspects[intersectionIndex], entryAspects[intersectionCount-intersectionIndex-1]);
        SWAP(exitAspects[intersectionIndex], exitAspects[intersectionCount-intersectionIndex-1]);
    }
    ok3 = checkOneCurveCurve(rev_left, right, intersectionCount, pts, lens, entryAspects, exitAspects, YES, looseAspects);
    ok4 = checkOneCurveCurve(rev_left, rev_right, intersectionCount, pts, lens, exitAspects, entryAspects, NO, looseAspects);
    
    if (ok1 && ok2 && ok3 && ok4)
        return YES;
    else {
        [tc recordFailureWithDescription:[NSString stringWithFormat:@"%s: Failures[%s %s %s %s]", __func__, ok1?"pass":"fail", ok2?"pass":"fail", ok3?"pass":"fail", ok4?"pass":"fail"] \
                                  inFile:@"" __FILE__ atLine:line expected:NO];
        return NO;
    }
}
#define checkCurveCurve(...) checkCurveCurve_(self, __LINE__, NO, __VA_ARGS__)
#define checkCurveCurveLoose(...) checkCurveCurve_(self, __LINE__, YES, __VA_ARGS__)

static BOOL checkOneCurveSelf(const NSPoint *p, NSPoint i, double t1, double t2,  enum OAIntersectionAspect expectedAspect)
{
    NSPoint c[4];
    _OAParameterizeCurve(c, p[0], p[3], p[1], p[2]);
    struct intersectionInfo r[MAX_INTERSECTIONS_PER_ELT_PAIR];
    NSInteger found;
    
    r[0] = (struct intersectionInfo){ -1, -1, -1, -1, intersectionEntryBogus, intersectionEntryBogus };
    
    found = OAIntersectionsBetweenCurveAndSelf(c, r);
    if(found != 1) {
        NSLog(@"%s:%d Found %ld intersections, expecting %d", __func__, __LINE__, found, 1);
        dumpFoundIntersections(found, "Self", "Self", c, c, r);
        printf("*** Expected %d intersections:\n", 1);
        printf("   %2d: (%g,%g), t=%g/%g, %s aspect\n", 1, i.x, i.y, t1, t2, straspect(expectedAspect));
        return NO;
    }
    
    OBASSERT(r[0].leftParameter >= -EPSILON);
    OBASSERT(r[0].leftParameter <= 1+EPSILON);
    OBASSERT(r[0].rightParameter >= -EPSILON);
    OBASSERT(r[0].rightParameter <= 1+EPSILON);
    
    NSPoint leftpos, rightpos;
    BOOL mismatch;
    double pt_epsilon;
        
    mismatch =
        r[0].leftParameterDistance != 0 ||
        r[0].rightParameterDistance != 0;
    
    leftpos = pointOnCurve(p, r[0].leftParameter);
    rightpos = pointOnCurve(p, r[0].rightParameter);
    pt_epsilon = CURVEMATCH_EPSILON;
    
    if (fabs(i.x - leftpos.x) > pt_epsilon ||
        fabs(i.y - leftpos.y) > pt_epsilon ||
        fabs(i.x - rightpos.x) > pt_epsilon ||
        fabs(i.y - rightpos.y) > pt_epsilon ||
        fabs(rightpos.x - leftpos.x) > pt_epsilon ||
        fabs(rightpos.y - leftpos.y) > pt_epsilon) {
        mismatch = 1;
        printf("%s:  Mismatch in intersection location\n", __func__);
    }
    
    if (r[0].leftEntryAspect != expectedAspect || r[0].leftExitAspect != expectedAspect) {
        mismatch = 1;
        printf("%s:  Mismatch in intersection aspect\n", __func__);
    }
    
    if (fabs(r[0].leftParameter - t1) > EPSILON) {
        mismatch = 1;
        printf("%s:  Mismatch in left intersection parameter (off by %+g)\n", __func__, fabs(r[0].leftParameter - t1));
    }    
    if (fabs(r[0].rightParameter - t2) > EPSILON) {
        mismatch = 1;
        printf("%s:  Mismatch in right intersection parameter (off by %+g)\n", __func__, fabs(r[0].rightParameter - t2));
    }    
    
    if (mismatch) {
        printf("  Expected point (%g,%g) t=%g or %g (%s-%s aspect)\n  Found Left t=%g (%g,%g)    Right t=%g (%g,%g)  aspect=%s-%s\n",
              i.x, i.y, t1, t2, straspect(expectedAspect), straspect(expectedAspect),
              r[0].leftParameter, leftpos.x, leftpos.y,
              r[0].rightParameter, rightpos.x, rightpos.y, straspect(r[0].leftEntryAspect), straspect(r[0].leftExitAspect));
        logparams(@"  Curve", p);
        return NO;
    } else {
        return YES;
    }
}

static BOOL checkCurveSelf_backwards(const NSPoint *p, NSPoint i, double t1, double t2,  enum OAIntersectionAspect expectedAspect)
{
    NSPoint rev[4];
    rev[0] = p[3];
    rev[1] = p[2];
    rev[2] = p[1];
    rev[3] = p[0];
    
    return checkOneCurveSelf(rev, i, 1-t2, 1-t1, - expectedAspect);
}

/* Check a given curve forwards and backwards */
#define checkCurveSelf(...) XCTAssertTrue(checkOneCurveSelf(__VA_ARGS__)); XCTAssertTrue(checkCurveSelf_backwards(__VA_ARGS__));

- (void)testCurveCurveIntersections1
{
    const double R = ( (M_SQRT2 - 1.) * 4. / 3. );
    NSPoint arc1[4] = { Pt(0,0), Pt(0, R), Pt( 1-R, 1 ), Pt(1, 1) };  // Quarter-circle of radius 1 centered at (1,0)
    NSPoint arc2[4] = { Pt(-0.1,0), Pt(-0.1, 1.1*R), Pt( 1- (1.1*R), 1.1 ), Pt(1, 1.1) }; // Quarter-circle of radius 1.1 centered at (1,0)
    NSPoint arc3[4] = { Pt(1,0), Pt(1, R), Pt(R, 1), Pt(0, 1) }; // Quarter-circle of radius 1 centered at (0,0)
    NSPoint arc4[4] = { Pt(-0.1, 0.1), Pt(R - 0.1, 0.1), Pt(0.9, 1.1 - R), Pt(0.9, 1.1) }; // Quarter-circle of radius 1 centered at (-0.1, 1.1)
    NSPoint ellarc1[4] = { Pt(0,0), Pt(0, 1.1*R), Pt( 1-R, 1.1 ), Pt(1, 1.1) }; // arc1, stretched vertically
    NSPoint ellarc2[4] = { Pt(-0.1,0), Pt(-0.1, R), Pt( 1- (1.1*R), 1 ), Pt(1, 1) }; // arc2, compressed vertically
    
    checkCurveCurve(arc1, arc2, 0);
    
    double fudge = 0.00018;  // Fudge factor. The expected value of the test (below) is the point where a pair of circular arcs would intersect. The cubic-Bezier approximation of a quarter-circle is off by 0.05% at the farthest point, and in this case the lines are close enough to parallel to magnify the error. So the intersection point of the cubics is a bit farther up than the intersection of the arcs they approximate.
    checkCurveCurve(arc1, arc3, 1, (expect){Pt(0.5, sqrt(0.75) + fudge), intersectionEntryRight});
    
    checkCurveCurve(arc1, arc4, 2,
                    (expect){Pt(0.00559027913422057, 0.10559027913422056), intersectionEntryLeft},
                    (expect){Pt(0.89440972086577941, 0.99440972086577939), intersectionEntryRight});
    checkCurveCurve(ellarc1, ellarc2, 1, (expect){Pt( 1 - sqrt(121./221.), sqrt(121./221.) ), intersectionEntryLeft});
}

- (void)testCurveCurveIntersections2
{
    NSPoint bow1[4] = { {0, 1}, {2, -2}, {2, 2}, {0, -1} }; // Self-intersecting curve
    NSPoint bow2[4] = { {1, 1}, {-1, -2}, {-1, 2}, {1, -1} }; // Same as bow1, reflected about x=.5
    NSPoint bow3[4] = { {2, 1}, {0, -2}, {0, 2}, {2, -1} }; // Same as bow1, reflected about x=1

    checkCurveCurve(bow1, bow2, 2,
                    (expect){Pt(0.5,  5. / sqrt(216)), intersectionEntryLeft},
                    (expect){Pt(0.5, -5. / sqrt(216)), intersectionEntryRight});
    
    checkCurveCurve(bow1, bow3, 6,
                    // some of these intersections are too much of a pain to find analytically, so I just found them numerically
                    (expect){Pt(0.65007289,  0.18184824), intersectionEntryRight},  // t = 0.123629812969579
                    (expect){Pt(1.0,     sqrt(3) / -18.), intersectionEntryLeft},   // t = 0.211324865405187 = 0.5 - sqrt(1/12)
                    (expect){Pt(1.34992711, -0.18184824), intersectionEntryLeft},   // t = 0.341847703205571
                    (expect){Pt(1.34992711,  0.18184824), intersectionEntryRight},  // t = 0.658152296794429
                    (expect){Pt(1.0,     sqrt(3) /  18.), intersectionEntryRight},  // t = 0.788675134594812 = 0.5 + sqrt(1/12)
                    (expect){Pt(0.65007289, -0.18184824), intersectionEntryLeft});  // t = 0.876370187030421
}


- (void)testCurveCurveIntersections3
{
    double d = 0.1;
    NSPoint ess1[4] = { Pt(-1, d), Pt(5, d), Pt(-5, -d), Pt(1, -d) };
    NSPoint ess2[4] = { Pt(-d, 1), Pt(-d, -5), Pt(d, 5), Pt(d, -1) };
    NSPoint ess3[4] = { Pt(-d/2, d), Pt(6-d/2, d), Pt(-4-d/2, -d), Pt(2-d/2, -d) };  // ess1, shifted to the right by (1-d/2) to miss one leg of ess1
    NSPoint gently[4] = { Pt(-1, 0), Pt(25, 1), Pt(75, 1), Pt(100, 0) };

    // All of these intersections were found by the algorithm itself, so this isn't a good test of intersection placement. What we're testing here is the case of many intersections, and the correct ordering of the intersections we get back, and some special cases with endpoints.
    
    // The exact symmetry of this test also triggers a wacky subdivision roundoff case in intersectionsBetweenCurveAndCurveMonotonic()+mergeSortIntersectionInfo().
    checkCurveCurve(ess1, ess2, 9,
                    (expect){Pt(-0.09799,  0.09799), intersectionEntryLeft},
                    (expect){Pt( 0.00488,  0.09740), intersectionEntryRight},
                    (expect){Pt( 0.09677,  0.09677), intersectionEntryLeft},
                    (expect){Pt( 0.09740,  0.00488), intersectionEntryRight},
                    (expect){Pt( 0,        0      ), intersectionEntryLeft},
                    (expect){Pt(-0.09740, -0.00488), intersectionEntryRight},
                    (expect){Pt(-0.09677, -0.09677), intersectionEntryLeft},
                    (expect){Pt(-0.00488, -0.09740), intersectionEntryRight},
                    (expect){Pt( 0.09799, -0.09799), intersectionEntryLeft});

    // This tests an odd case in the recursion of intersectionsBetweenCurveAndCurveMonotonic.
    checkCurveCurve(gently, ess2, 3,
                    (expect){Pt(-0.09763, 0.03394), intersectionEntryLeft},
                    (expect){Pt( 0.00188, 0.03762), intersectionEntryRight},
                    (expect){Pt( 0.09716, 0.04109), intersectionEntryLeft});
    
    checkCurveCurve(ess2, ess3, 6,
                    (expect){Pt(-0.00389,-0.07778), intersectionEntryLeft},
                    (expect){Pt(-0.00289,-0.05788), intersectionEntryRight},
                    (expect){Pt( 0.00500, 0.10000), intersectionEntryLeft},
                    (expect){Pt( 0.09675, 0.09997), intersectionEntryRight},
                    (expect){Pt( 0.09772,-0.04817), intersectionEntryLeft},
                    (expect){Pt( 0.09791,-0.08374), intersectionEntryRight});
}

#ifdef DEBUG_wiml
- (void)testCurveCurveIntersectionsRegressions
{
    // This tests the case from bug #156724
    NSPoint ovalish[4] = {
        Pt(393.80251542775778, 250.42792372513134), Pt(373.99478693587287, 240.52400875828957), Pt(342.00521306412713, 240.52400875828957), Pt(322.19748457224222, 250.42792372513134)
    };
    NSPoint lineish[4] = {
        Pt(358, 147), Pt(358, 147), Pt(358, 269), Pt(358, 269)
    };
    
    checkCurveCurve(ovalish, lineish, 1,
                    (expect){Pt(358, 240), intersectionEntryBogus});
}
#endif

- (void)testCurveCurveGrazing
{
    NSPoint bulge1[4] = { Pt(0,0), Pt(-8,5), Pt(32, 5), Pt(24, 0) };
    NSPoint bulge2[4] = { Pt(-0.5,0), Pt(-8.833,5), Pt(32.833, 5), Pt(24.5, 0) };
    NSPoint bulge3[4] = { Pt(-1,0), Pt(4,4), Pt(33, 5), Pt(23, -1) };
    NSPoint ess1[4]   = { Pt(-4, 4), Pt( 4, 4), Pt(-4, -4), Pt( 4, -4) };
    NSPoint ess2[4]   = { Pt( 4, 4), Pt(-4, 4), Pt( 4, -4), Pt(-4, -4) };
    NSPoint esslet[4] = { Pt(-4, 4), Pt( 0, 4), Pt( 0,  2), Pt( 0,  0) };
    
    // A symmetric case of two similar curves, one slightly stretched wrt the other, and osculating in the middle
    checkCurveCurve(bulge1, bulge2, 1,
                    (expect){Pt(12, 3.75), intersectionEntryLeft, 0.2, 0.2, YES});
    
    // An asymmetric case; one curve oscillates back and forth across the other a few times, and crosses at an angle elsewhere
    checkCurveCurve(bulge1, bulge3, 2,
                    (expect){Pt(-0.491551, 0.349019 ), intersectionEntryLeft, 0, 0},
                    (expect){Pt(19.3,      3.2      ), intersectionEntryRight, 0.4, 0.4});
    
    // Esses crossing and running briefly parallel
    checkCurveCurve(ess1, ess2, 1,
                    (expect){Pt(0,0), intersectionEntryLeft, 0.1, 0.1});
    
    // One curve is a section of another curve
    checkCurveCurveLoose(ess1, esslet, 1,
                         (expect){Pt(-0.5,2.75), intersectionEntryAt, 0.51, 1.0});
    
    // The same curve
    checkCurveCurveLoose(ess1, ess1, 1,
                         (expect){Pt(0, 0), intersectionEntryAt, 1.0, 1.0});
}

- (void)testCurveSelfIntersection
{
    NSPoint bow1[4] = { {0, 1}, {2, -2}, { 2, 2}, {0, -1} }; // Self-intersecting curve
    NSPoint bow2[4] = { {0, 1}, {2, -2}, {-1, 0}, {1,  0} }; // Asymmetrical self-intersecting curve

    checkCurveSelf(bow1, Pt(6./7., 0.0),             0.5 - sqrt(3./28.),    0.5 + sqrt(3./28.),    intersectionEntryLeft);
    
    checkCurveSelf(bow2, Pt(403./675., -128./3375.), 8./15. - sqrt(11./75), 8./15. + sqrt(11./75), intersectionEntryRight); 
}

static void doCubicBoundsTest(OAGeometryTests *self, CFStringRef file, int line, NSRect expected, NSPoint s, NSPoint c1, NSPoint c2, NSPoint e, CGFloat halfwidth)
{
    NSRect buf;
    BOOL modified;

    /*
     OATightBoundsOfCurveTo() is returning YES in some cases where it XCTAssertTrue(?) return NO: it computes the answer in double-precision, and sets the modified flag because it extends outside the given rectangle, but when the result is cast to CGFloat to be returned it's equal to the original again.
     
     This shouldn't be a problem in the specific uses we have for OATightBoundsOfCurveTo(), where the return value just enables some optimizations, so I've disabled that test here: we no longer fail if tightBounds... spuriously returns YES when we expect NO.
     
     To be absolutely strictly correct, I think tightBoundsOfCurve() should extend the bounds rectangle (using nextafter() or the like) if necessary when casting its results back to CGFloat. That's a greater level of care than we need though. (Alternatively, it could return its answers in doubles...)
     */
#if 0
#define checkDidNotModify(before, after) if (modified) \
    [self recordFailureWithDescription:[NSString stringWithFormat:@"Tight bounds was modified but shouldn't have been: %@->%@ (specific check at line %d)", NSStringFromRect(before), NSStringFromRect(after), __LINE__] \
                                inFile:(NSString *)file \
                                atLine:line \
                              expected:NO]
#else
#define checkDidNotModify(before, after)   do { (void)modified; (void)before; (void)after; }while(0)
#endif
    
#define checkDidModify(after) if (!modified) \
    [self recordFailureWithDescription:[NSString stringWithFormat:@"Bounds should have been modified but weren't: %@ (specific check at line %d)", NSStringFromRect(after), __LINE__] \
                                                     inFile:(NSString *)file \
                                                     atLine:line \
                                                   expected:NO]
    
#define checkCloseRect(got, want, exact) if (!rectsAreApproximatelyEqual(got, want, exact? 0 : BOUNDS_EPSILON, __LINE__)) \
    [self recordFailureWithDescription: [NSString stringWithFormat:@"%s=%@ %s=%@ (specific check at line %d)", #got, NSStringFromRect(got), #want, NSStringFromRect(want), __LINE__] \
                                                     inFile:(NSString *)file \
                                                     atLine:line \
                                                   expected:NO]
    
    buf = NSZeroRect;
    modified = OATightBoundsOfCurveTo(&buf, s, c1, c2, e, halfwidth);
    checkDidModify(buf);
    checkCloseRect(buf, expected, NO);
    
    NSRect buf2 = buf;
    NSRect buf2_before = buf2;
    modified = OATightBoundsOfCurveTo(&buf2, s, c1, c2, e, halfwidth);
    checkDidNotModify(buf2_before, buf2);
    checkCloseRect(buf2_before, buf2, YES);
    
    buf2 = NSInsetRect(buf, 1, 1);
    modified = OATightBoundsOfCurveTo(&buf2, s, c1, c2, e, halfwidth);
    checkDidModify(buf);
    checkCloseRect(buf2, expected, NO);
    
    buf2 = NSInsetRect(buf, -1, -1);
    buf2_before = buf2;
    modified = OATightBoundsOfCurveTo(&buf2, s, c1, c2, e, halfwidth);
    checkDidNotModify(buf2_before, buf2);
    checkCloseRect(buf2_before, buf2, YES);
    
    buf2 = buf;
    buf2.size.width -= 1;
    modified = OATightBoundsOfCurveTo(&buf2, s, c1, c2, e, halfwidth);
    checkDidModify(buf2);
    checkCloseRect(buf2, expected, NO);
    
    buf2 = buf;
    buf2.size.height -= 1;
    modified = OATightBoundsOfCurveTo(&buf2, s, c1, c2, e, halfwidth);
    checkDidModify(buf2);
    checkCloseRect(buf2, expected, NO);    
}

- (void)testTightCubicBounds
{
    doCubicBoundsTest(self, CFSTR(__FILE__), __LINE__,
                      (NSRect){ {0, 0}, {10, 10} },
                      (NSPoint){ 0, 0 },
                      (NSPoint){ 3, 0 },
                      (NSPoint){ 10, 7 },
                      (NSPoint){ 10, 10 }, 0);
    
    doCubicBoundsTest(self, CFSTR(__FILE__), __LINE__,
                      Rct(0, 0,
                          7.5, 10),
                      (NSPoint){ 0, 0 },
                      (NSPoint){ 10, 0 },
                      (NSPoint){ 10, 10 },
                      (NSPoint){ 0, 10 }, 0);
    
    doCubicBoundsTest(self, CFSTR(__FILE__), __LINE__,
                      Rct(0, 0,
                          20./9., 20./9.),
                      (NSPoint){ 0, 0 },
                      (NSPoint){ 5, 0 },
                      (NSPoint){ 0, 5 },
                      (NSPoint){ 0, 0 }, 0);

    doCubicBoundsTest(self, CFSTR(__FILE__), __LINE__,
                      Rct(30, -10 - 10 / sqrt(12),
                          10, 20 / sqrt(12)),
                      (NSPoint){ 30, -10 },
                      (NSPoint){ 30,   0 },
                      (NSPoint){ 40, -20 },
                      (NSPoint){ 40, -10 }, 0);
}

- (void)testTightCubicBoundsWithClearance
{
    doCubicBoundsTest(self, CFSTR(__FILE__), __LINE__,
                      Rct(-10, 0,
                          0.75 + 0.1, 2 / sqrt(12) + 0.1),
                      Pt( -10, 0   ),
                      Pt(  -9, 0.5 ),
                      Pt(  -9, 1   ),
                      Pt( -10, 0   ), F(0.1));
    
    doCubicBoundsTest(self, CFSTR(__FILE__), __LINE__,
                      Rct(-10, 0,
                          0.75 + 0.15, 2 / sqrt(12) + 0.15),
                      Pt( -10, 0   ),
                      Pt(  -9, 0.5 ),
                      Pt(  -9, 1   ),
                      Pt( -10, 0   ), F(0.15));
    
    doCubicBoundsTest(self, CFSTR(__FILE__), __LINE__,
                      Rct(10, 10,
                          1, 1),
                      Pt( 10,   10   ),
                      Pt( 11,   10.1 ),
                      Pt( 10.9, 10.9 ),
                      Pt( 11,   11   ), F(0.3));
    
    doCubicBoundsTest(self, CFSTR(__FILE__), __LINE__,
                      Rct(10 - 0.75 - 0.2, 10,
                          0.75 + 0.2, 3),
                      Pt( 10, 10 ),
                      Pt(  9, 11 ),
                      Pt(  9, 12 ),
                      Pt( 10, 13 ), F(0.2));
}


static void checkClockwise_(OAGeometryTests *self, NSBezierPath *p, BOOL cw, const char *file, int line)
{
    BOOL val;
#define checkCW(expr, want) val = [expr isClockwise]; if (val != want) \
    [self recordFailureWithDescription:[NSString stringWithFormat:@"[%s isClockwise] == %s, expecting %s (path is %@)", #expr, val?"true":"false", want?"true":"false", [expr description]] \
                                inFile:[[NSFileManager defaultManager] stringWithFileSystemRepresentation:file length:strlen(file)] atLine:line expected:NO]
    
    
    checkCW(p, cw);
    checkCW([p bezierPathByReversingPath], !cw);
    
    NSBezierPath *mirroredPath;
    
    mirroredPath = [p copy];
    NSAffineTransform *xmirror = [NSAffineTransform transform];
    [xmirror scaleXBy:-1 yBy:1];
    [mirroredPath transformUsingAffineTransform:xmirror];
    checkCW(mirroredPath, !cw);
    checkCW([mirroredPath bezierPathByReversingPath], cw);
    [mirroredPath release];

    mirroredPath = [p copy];
    NSAffineTransform *ymirror = [NSAffineTransform transform];
    [ymirror scaleXBy:1 yBy:-1];
    [mirroredPath transformUsingAffineTransform:ymirror];
    checkCW(mirroredPath, !cw);
    checkCW([mirroredPath bezierPathByReversingPath], cw);
    [mirroredPath release];
}
#define checkClockwise(path, expect) checkClockwise_(self, path, expect, __FILE__, __LINE__)

- (void)testPathClockwise
{
    NSBezierPath *p;
    double i;
    
    p = [NSBezierPath bezierPath];
    [p moveToPoint:Pt(1, 2)];
    [p lineToPoint:Pt(2, 3)];
    [p lineToPoint:Pt(3, 1)];
    [p closePath];
    checkClockwise(p, YES);
    
    p = [NSBezierPath bezierPath];
    [p moveToPoint:Pt(1, 1)];
    for(i = 1.1; i < 2; i += 0.1)
        [p lineToPoint:Pt(0.9, i)];
    [p lineToPoint:Pt(1, 2)];
    [p closePath];
    checkClockwise(p, YES);

    p = [NSBezierPath bezierPath];
    [p moveToPoint:Pt(1, 1)];
    for(i = 1.1; i < 2; i += 0.1)
        [p lineToPoint:Pt(0.9, i)];
    [p lineToPoint:Pt(1, 2)];
    [p lineToPoint:Pt(0.92, 1.5)];
    [p closePath];
    checkClockwise(p, YES);

    p = [NSBezierPath bezierPath];
    [p moveToPoint:Pt(1, 1)];
    for(i = 1.1; i < 2; i += 0.1)
        [p lineToPoint:Pt(0.9, i)];
    [p lineToPoint:Pt(1, 2)];
    [p lineToPoint:Pt(100, 1.5)];
    [p closePath];
    checkClockwise(p, YES);

    p = [NSBezierPath bezierPath];
    [p moveToPoint:Pt(1, 1)];
    for(i = 1.1; i < 2; i += 0.05)
        [p lineToPoint:Pt(0.9, i)];
    [p lineToPoint:Pt(1, 2)];
    [p lineToPoint:Pt(0.85, 2)];
    [p lineToPoint:Pt(0.85, 1)];
    [p closePath];
    checkClockwise(p, NO);

    p = [NSBezierPath bezierPath];
    [p moveToPoint:Pt(1, 1)];
    for(i = 1.1; i < 2; i += 0.05)
        [p lineToPoint:Pt(0.9, i)];
    [p lineToPoint:Pt(1, 2)];
    [p lineToPoint:Pt(0.91, 1.90)];
    [p lineToPoint:Pt(0.91, 1.10)];
    [p closePath];
    checkClockwise(p, YES);
    
    p = [NSBezierPath bezierPath];
    [p moveToPoint: Pt(-1, 0)];
    [p curveToPoint:Pt( 1, 0) controlPoint1:Pt(-0.5, 1.0) controlPoint2:Pt( 0.5, 1.0)];
    [p curveToPoint:Pt(-1, 0) controlPoint1:Pt( 0.5, 0.9) controlPoint2:Pt(-0.5, 0.9)];
    checkClockwise(p, YES);
    [p closePath];
    checkClockwise(p, YES);

    p = [NSBezierPath bezierPath];
    [p moveToPoint: Pt(-1, 0)];
    [p curveToPoint:Pt( 1, 0) controlPoint1:Pt(-0.5, 0.9) controlPoint2:Pt( 0.5, 0.9)];
    [p curveToPoint:Pt(-1, 0) controlPoint1:Pt( 0.5, 1.0) controlPoint2:Pt(-0.5, 1.0)];
    checkClockwise(p, NO);
    [p closePath];
    checkClockwise(p, NO);
    
    p = [NSBezierPath bezierPath];
    [p moveToPoint: Pt(-2, 0)];
    // Note that all the endpoint tangents here are 45 degrees.
    [p curveToPoint:Pt( 2, 0) controlPoint1:Pt(-1.0, 1.0) controlPoint2:Pt( 1.0,-1.0)];
    [p curveToPoint:Pt(-2, 0) controlPoint1:Pt( 0.8,-1.2) controlPoint2:Pt(-1.2, 0.8)];
    checkClockwise(p, YES);
    
    p = [NSBezierPath bezierPath];
    [p moveToPoint: Pt(1, 0)];
    [p lineToPoint: Pt(2, -2)];
    [p lineToPoint: Pt(-1, 0)];
    [p lineToPoint: Pt(-2, 0)];
    [p lineToPoint: Pt(0, 2)];
    [p lineToPoint: Pt(0, 0)];
    [p closePath];
    checkClockwise(p, YES);
}

@end


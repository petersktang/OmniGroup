// Copyright 2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OBTestCase.h"

#import <OmniBase/OmniBase.h>

RCS_ID("$Id$")

@implementation OBTestCase

+ (void) initialize;
{
    OBINITIALIZE;
    [OBPostLoader processClasses];
}

+ (BOOL)shouldRunSlowUnitTests;
{
    return getenv("RunSlowUnitTests") != NULL;
}

@end

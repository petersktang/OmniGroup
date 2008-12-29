// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

#import <AppKit/NSView.h>

@class OIInspectorHeaderView;

@interface OIInspectorHeaderBackground : NSView
{
    OIInspectorHeaderView *windowHeader;
}

- (void)setHeaderView:(OIInspectorHeaderView *)header;

@end

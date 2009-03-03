/*
 *  SAXMachine.h
 *  TableTest
 *
 *  Created by Nathan Herald on 3/2/09.
 *  Copyright 2009 The Myobie Corporation. All rights reserved.
 *
 */

// This is the protocol to impliment for reacting to xml events in real time as they happen. xmlib will stream the xml and parse it in chunks, so this is your gateway to interact with those chunks.
// All of this crap happens on a secondary thread, so be sure not to do any un-threadsafe stuff.

@protocol SAXMachine <NSObject>

@optional

- (void)startElementNamed:(NSString *)name withAtrributes:(NSDictionary *)attributes;
- (void)endElementNamed:(NSString *)name;

@end
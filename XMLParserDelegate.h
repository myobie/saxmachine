/*
 *  XMLParserDelegate.h
 *  TableTest
 *
 *  Created by Nathan Herald on 3/2/09.
 *  Copyright 2009 The Myobie Corporation. All rights reserved.
 *
 */

@class XMLParser;

// Protocol for the parser to communicate with its delegate (your app controller).
@protocol XMLParserDelegate <NSObject>

@optional
// Called by the parser when parsing is finished.
- (void)parserDidEndParsingData:(XMLParser *)parser;
// Called by the parser in the case of an error.
- (void)parser:(XMLParser *)parser didFailWithError:(NSError *)error;
// Called by the parser when one or more songs have been parsed. This method may be called multiple times.
- (void)parser:(XMLParser *)parser didParseObjects:(NSArray *)parsedObjects;

@end
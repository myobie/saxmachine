//
//  XMLParser.h
//  TableTest
//
//  Created by Nathan Herald on 2/26/09.
//  Copyright 2009 The Myobie Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMLParserObject.h"
#import "XMLParserDelegate.h"
#import "SAXMachine.h"
#import <libxml/tree.h>

@interface XMLParser : NSObject <SAXMachine> {
@private
	id <XMLParserDelegate> delegate;
	NSMutableArray *parsedObjects;
	
	NSArray *hierarchy;
	NSString *hierarchyString;
	
	// for XML parsing
	
    xmlParserCtxtPtr context; // Reference to the libxml parser context
    NSURLConnection *remoteConnection;
    
    BOOL done; // Overall state of the parser, used to exit the run loop.
	
    // State variable used to determine whether or not to ignore a given XML element
    BOOL parsingAnObject;
	
    // The following state variables deal with getting character data from XML elements. This is a potentially expensive 
    // operation. The character data in a given element may be delivered over the course of multiple callbacks, so that
    // data must be appended to a buffer. The optimal way of doing this is to use a C string buffer that grows exponentially.
    // When all the characters have been delivered, an NSString is constructed and the buffer is reset.
    BOOL storingCharacters;
    NSMutableData *characterBuffer;
    
    XMLParserObject *currentObject; // A reference to the current object the parser is working with.
	
    // The number of parsed objects is tracked so that the autorelease pool for the parsing thread can be periodically
    // emptied to keep the memory footprint under control. 
    NSUInteger countOfParsedObjects;
    NSAutoreleasePool *downloadAndParsePool;
}

@property (nonatomic, assign) id <XMLParserDelegate> delegate;

@property (nonatomic, retain) XMLParserObject *currentObject;
@property BOOL parsingAnObject;

@property (nonatomic, retain) NSArray *hierarchy;
@property (nonatomic, retain) NSString *hierarchyString;

- (void)parseFromRemoteUrl:(NSString *)urlString;

// This will be invoked on a secondary thread to keep the application responsive.
// Although NSURLConnection is inherently asynchronous, the parsing can be quite CPU intensive on the device, so
// the user interface can be kept responsive by moving that work off the main thread. This does create additional
// complexity, as any code which interacts with the UI must then do so in a thread-safe manner.
- (void)downloadAndParse:(NSURL *)url;

// Each of these methods must be invoked on the main thread.
- (void)downloadStarted;
- (void)downloadEnded;
- (void)parseEnded;
- (void)parsedObject:(XMLParserObject *)object;
- (void)finishedCurrentObject;
- (void)parseError:(NSError *)error;

- (NSString *)currentString;

- (void)startStoringCharacters;
- (void)stopStoringCharacters;

- (void)pushOnHierarchy:(NSString *)name;
- (void)popHierarchy;
- (void)parseHierarchyForString;

- (NSArray *)recordCharactersIfNameOrPathIsIn;

@end

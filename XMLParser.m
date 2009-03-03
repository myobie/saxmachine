//
//  XMLParser.m
//  TableTest
//
//  Created by Nathan Herald on 2/26/09.
//  Copyright 2009 The Myobie Corporation. All rights reserved.
//

#import "XMLParser.h"
#import "XMLParserObject.h"
#import <libxml/tree.h>

static NSUInteger kCountForNotification = 10;


// Function prototypes for SAX callbacks. This sample implements a minimal subset of SAX callbacks.
// Depending on your application's needs, you might want to implement more callbacks.
static void startElementSAX(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI, int nb_namespaces, const xmlChar **namespaces, int nb_attributes, int nb_defaulted, const xmlChar **attributes);
static void	endElementSAX(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI);
static void	charactersFoundSAX(void * ctx, const xmlChar * ch, int len);
static void errorEncounteredSAX(void * ctx, const char * msg, ...);

// Forward reference. The structure is defined in full at the end of the file.
static xmlSAXHandler simpleSAXHandlerStruct;


// Class extension for private properties and methods.
@interface XMLParser ()

@property (nonatomic, retain) NSMutableArray *parsedObjects;

@property BOOL storingCharacters;
@property (nonatomic, retain) NSMutableData *characterBuffer;
@property BOOL done;
@property NSUInteger countOfParsedObjects;
@property (nonatomic, retain) NSURLConnection *remoteConnection;

// The autorelease pool property is assign because autorelease pools cannot be retained.
@property (nonatomic, assign) NSAutoreleasePool *downloadAndParsePool;

@end

@implementation XMLParser

@synthesize delegate, hierarchy, hierarchyString, parsedObjects, remoteConnection, done, parsingAnObject, storingCharacters, currentObject, countOfParsedObjects, characterBuffer, downloadAndParsePool;

- (void)parseFromRemoteUrl:(NSString *)urlString {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    self.parsedObjects = [NSMutableArray array];
    NSURL *url = [NSURL URLWithString:urlString];
    [NSThread detachNewThreadSelector:@selector(downloadAndParse:) toTarget:self withObject:url];
}

- (void)dealloc {
    [parsedObjects release];
	[hierarchy release];
	[hierarchyString release];
    [super dealloc];
}

- (void)downloadAndParse:(NSURL *)url {
	self.downloadAndParsePool = [[NSAutoreleasePool alloc] init];
	done = NO;
	
	self.characterBuffer = [NSMutableData data];
	self.hierarchy = [NSArray array];
	
	[[NSURLCache sharedURLCache] removeAllCachedResponses]; // clear the caches!
	
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:url];
	[theRequest setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
	[theRequest setValue:@"application/xml" forHTTPHeaderField:@"Accept"];
	
	remoteConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	
	// This creates a context for "push" parsing in which chunks of data that are not "well balanced" can be passed
    // to the context for streaming parsing. The handler structure defined above will be used for all the parsing. 
    // The second argument, self, will be passed as user data to each of the SAX handlers. The last three arguments
    // are left blank to avoid creating a tree in memory.
    context = xmlCreatePushParserCtxt(&simpleSAXHandlerStruct, self, NULL, 0, NULL);
	
	[self performSelectorOnMainThread:@selector(downloadStarted) withObject:nil waitUntilDone:NO];
	
	if (remoteConnection != nil) {
		
		do {
			
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
			
		} while (!done);
		
	}
	
	xmlFreeParserCtxt(context);
	self.characterBuffer = nil;
	self.remoteConnection = nil;
	self.currentObject = nil;
	[downloadAndParsePool release];
	self.downloadAndParsePool = nil;
}

# pragma mark Main Thread methods

- (void)downloadStarted {
	NSAssert2([NSThread isMainThread], @"%s at line %d not called on main thread", __FUNCTION__, __LINE__);
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)downloadEnded {
	NSAssert2([NSThread isMainThread], @"%s at line %d not called on main thread", __FUNCTION__, __LINE__);
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)parseEnded {
	NSAssert2([NSThread isMainThread], @"%s at line %d not called on main thread", __FUNCTION__, __LINE__);
	
	if (self.delegate != nil && [self.delegate respondsToSelector:@selector(parser:didParseObjects:)] && [parsedObjects count] > 0) {
		[self.delegate parser:self didParseObjects:parsedObjects];
	}
	
	[self.parsedObjects removeAllObjects];
	
	if (self.delegate != nil && [self.delegate respondsToSelector:@selector(parserDidEndParsingData:)]) {
		[self.delegate parserDidEndParsingData:self];
	}
}

- (void)parsedObject:(XMLParserObject *)object {
	NSAssert2([NSThread isMainThread], @"%s at line %d not called on main thread", __FUNCTION__, __LINE__);
	
	[self.parsedObjects addObject:object];
	
	if ([parsedObjects count] > kCountForNotification) {
		if (self.delegate != nil && [self.delegate respondsToSelector:@selector(parser:didParseObjects:)]) {
			[self.delegate parser:self didParseObjects:parsedObjects];
		}
		[self.parsedObjects removeAllObjects];
	}
}

- (void)parseError:(NSError *)error {
	NSAssert2([NSThread isMainThread], @"%s at line %d not called on main thread", __FUNCTION__, __LINE__);
	
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(parser:didFailWithError:)]) {
        [self.delegate parser:self didFailWithError:error];
    }
}

#pragma mark NSURLConnection Delegate methods

// Disable caching
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

// Forward errors to the delegate.
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    done = YES;
    [self performSelectorOnMainThread:@selector(parseError:) withObject:error waitUntilDone:NO];
}

// Called when a chunk of data has been downloaded.
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	xmlParseChunk(context, (const char *)[data bytes], [data length], 0); // Parse this chunk
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self performSelectorOnMainThread:@selector(downloadEnded) withObject:nil waitUntilDone:NO];
	xmlParseChunk(context, NULL, 0, 1); // Passing 1 means your done
	[self performSelectorOnMainThread:@selector(parseEnded) withObject:nil waitUntilDone:NO];
	done = YES; // End the do/run loop
	// NSLog(@"Done...");
}

#pragma mark Parsing support methods

static const NSUInteger kAutoreleasePoolPurgeFrequency = 20;

// send the object back to be processed
- (void)finishedCurrentObject {
	[self performSelectorOnMainThread:@selector(parsedObject:) withObject:currentObject waitUntilDone:NO];
	self.currentObject = nil; // ensure our local copy is released
	countOfParsedObjects++;
	
	// Periodically purge the autorelease pool.
    if (countOfParsedObjects == kAutoreleasePoolPurgeFrequency) {
        [downloadAndParsePool release];
        self.downloadAndParsePool = [[NSAutoreleasePool alloc] init];
        countOfParsedObjects = 0;
    }
}

// Character data is appended to a buffer until the current element ends.
- (void)appendCharacters:(const char *)charactersFound length:(NSInteger)length {
    [characterBuffer appendBytes:charactersFound length:length];
}

- (NSString *)currentString {
    // Create a string with the character data using UTF-8 encoding. UTF-8 is the default XML data encoding.
    NSString *currentString = [[[NSString alloc] initWithData:characterBuffer encoding:NSUTF8StringEncoding] autorelease];
    [characterBuffer setLength:0];
    return currentString;
}

- (void)startStoringCharacters {
	self.storingCharacters = YES;
}

- (void)stopStoringCharacters {
	self.storingCharacters = NO;
}

- (void)pushOnHierarchy:(NSString *)name {
	self.hierarchy = [self.hierarchy arrayByAddingObject:name];
	[self parseHierarchyForString];
}

- (void)popHierarchy {
	NSRange theRange;
	theRange.location = 0;
	theRange.length = [self.hierarchy count] - 1;
	
	self.hierarchy = [self.hierarchy subarrayWithRange:theRange];
	[self parseHierarchyForString];
}

- (void)parseHierarchyForString {
	NSString *tempString = [NSString string];
	
	for (NSString *currentTag in self.hierarchy) {
		tempString = [tempString stringByAppendingFormat:@"/%@", currentTag];
	}
	
	self.hierarchyString = tempString;
}

/*
 Override this method to provide your own list of element names or paths to start recording characters when inside.
 */
- (NSArray *)recordCharactersIfNameOrPathIsIn {
	return [NSArray array];
}

@end

#pragma mark SAX Parsing Callbacks

static void startDocumentSAX(void *userData) {
	//NSLog(@"Started the document.");
}


static void endDocumentSAX(void *userData) {
	//NSLog(@"Finished the document.");
}

/*
 This callback is invoked when the parser finds the beginning of a node in the XML. Override this method in your subclass.
 */
static void startElementSAX(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI, int nb_namespaces, const xmlChar **namespaces, int nb_attributes, int nb_defaulted, const xmlChar **attributes) {
	
	XMLParser *parser = (XMLParser *)ctx;
	
	// grab the tag name
	NSString *name = [NSString stringWithUTF8String:(char *)localname];
	
	// build an array of where we are in the tag structure [html, head, title]
	[parser pushOnHierarchy:name];
	
	// store characters if we are in a tag that needs that sort of thing
	if ([[parser recordCharactersIfNameOrPathIsIn] indexOfObject:name] != NSNotFound || [[parser recordCharactersIfNameOrPathIsIn] indexOfObject:parser.hierarchyString] != NSNotFound) {
		[parser startStoringCharacters];
	}
	
	/* 
	 forget about namespaces and prefixes for now 
	 */
	
	//	for ( int indexNamespace = 0; indexNamespace < nb_namespaces; ++indexNamespace )
	//	{
	//		const xmlChar *prefix = namespaces[indexNamespace*2];
	//		const xmlChar *nsURI = namespaces[indexNamespace*2+1];
	//		printf( "  namespace: name='%s' uri=(%p)'%s'\n", prefix, nsURI, nsURI );
	//	}
	
	// build our attributes dictionary so it's more usable that the xmlChar trash we get
	NSMutableDictionary *attributesDict = [NSMutableDictionary dictionaryWithCapacity:nb_attributes];
	
	NSUInteger index = 0;
	
	for ( NSUInteger indexAttribute = 0; indexAttribute < nb_attributes; ++indexAttribute, index += 5 )
	{
		
		const xmlChar *localname = attributes[index];
		//		const xmlChar *prefix = attributes[index+1];
		//		const xmlChar *nsURI = attributes[index+2];
		const xmlChar *valueBegin = attributes[index+3];
		const xmlChar *valueEnd = attributes[index+4];
		
		NSInteger valueLength = xmlStrlen(valueBegin) - xmlStrlen(valueEnd);
		xmlChar *value = xmlStrsub(valueBegin, 0, valueLength);
		
		NSString *attrName = [NSString stringWithUTF8String:(char *)localname];
		NSString *attrValue = [NSString stringWithUTF8String:(char *)value];
		
		NSDictionary *this_attribute = [NSDictionary dictionaryWithObjectsAndKeys:
										attrName,
										@"name",
										attrValue,
										@"value",
										nil];
		
		[attributesDict setObject:this_attribute forKey:attrName];
	}
	
	if (parser != nil && [parser respondsToSelector:@selector(startElementNamed:withAtrributes:)]) {
		[parser startElementNamed:name withAtrributes:attributesDict];
	}
}

/*
 This callback is invoked when the parse reaches the end of a node. Override this method in your subclass.
 */
static void	endElementSAX(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI) {
	
	XMLParser *parser = (XMLParser *)ctx;
	
	// grab the tag name
	NSString *name = [NSString stringWithUTF8String:(char *)localname];
	
	if (parser != nil && [parser respondsToSelector:@selector(endElementNamed:)]) {
		[parser endElementNamed:name];
	}
	
	[parser popHierarchy];
	
	[parser stopStoringCharacters];
}

/*
 This callback is invoked when the parser encounters character data inside a node. The parser class determines how to use the character data.
 */
static void	charactersFoundSAX(void *ctx, const xmlChar *ch, int len) {
    XMLParser *parser = (XMLParser *)ctx;
    // A state variable, "storingCharacters", is set when nodes of interest begin and end. 
    // This determines whether character data is handled or ignored. 
    if (parser.storingCharacters == NO) return;
    [parser appendCharacters:(const char *)ch length:len];
}

/*
 A production application should include robust error handling as part of its parsing implementation.
 The specifics of how errors are handled depends on the application.
 */
static void errorEncounteredSAX(void *ctx, const char *msg, ...) {
    // Handle errors as appropriate for your application.
    NSCAssert(NO, @"Unhandled error encountered during SAX parse.");
}

// The handler struct has positions for a large number of callback functions. If NULL is supplied at a given position,
// that callback functionality won't be used. Refer to libxml documentation at http://www.xmlsoft.org for more information
// about the SAX callbacks.
static xmlSAXHandler simpleSAXHandlerStruct = {
NULL,                       /* internalSubset */
NULL,                       /* isStandalone   */
NULL,                       /* hasInternalSubset */
NULL,                       /* hasExternalSubset */
NULL,                       /* resolveEntity */
NULL,                       /* getEntity */
NULL,                       /* entityDecl */
NULL,                       /* notationDecl */
NULL,						/* attributeDecl */
NULL,                       /* elementDecl */
NULL,                       /* unparsedEntityDecl */
NULL,                       /* setDocumentLocator */
startDocumentSAX,           /* startDocument */
endDocumentSAX,             /* endDocument */
NULL,                       /* startElement*/
NULL,                       /* endElement */
NULL,                       /* reference */
charactersFoundSAX,         /* characters */
NULL,                       /* ignorableWhitespace */
NULL,                       /* processingInstruction */
NULL,                       /* comment */
NULL,                       /* warning */
errorEncounteredSAX,        /* error */
NULL,                       /* fatalError //: unused error() get all the errors */
NULL,                       /* getParameterEntity */
NULL,                       /* cdataBlock */
NULL,                       /* externalSubset */
XML_SAX2_MAGIC,             //
NULL,
startElementSAX,            /* startElementNs */
endElementSAX,              /* endElementNs */
NULL,                       /* serror */
};


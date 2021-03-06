//
//  Dispatcher.h
//  Jabber
//
//  Created by David Chisnall on Sun May 23 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EtoileXML/ETXMLNode.h>
#import "Message.h"
#import "Iq.h"
#import "Presence.h"

/**
 * Formal protocol for handling messages.
 */
@protocol MessageHandler <NSObject>
/**
 * Handle the given message object.
 */
- (void) handleMessage:(Message*)aMessage;
@end
/**
 * Formal protocol for handling presence stanzas.
 */
@protocol PresenceHandler <NSObject>
/**
 * Handle the given presence object.
 */
- (void) handlePresence:(Presence*)aPresence;
@end
/**
 * Formal protocol for handling info-query packets.
 */
@protocol IqHandler <NSObject>
/**
 * Handle the given info-query object.
 */
- (void) handleIq:(Iq*)anIq;
@end

/**
 * The Dispatcher class is used for routing of received stanzas.  Once each 
 * stanza has been passed, it will be encapsulated in an object.  There are 
 * three kinds of stanza specified by XMPP:
 *
 * - Messages are one-to-one and have best-effort delivery semantics.  They
 * will typically be enqueued if they can not be delivered immediately
 *
 * - Presences are one-to-many and are unreliable.
 *
 * - Info-query (iq) stanzas are one-to-one, will not be enqueued, but should
 * be acknowledged with either an error or a result reply.
 */
@interface Dispatcher : NSObject {
	NSMutableDictionary * iqHandlers;
	NSMutableDictionary * iqNamespaceHandlers;
	NSMutableDictionary * messageHandlers;
	NSMutableDictionary * presenceHandlers;
	id <IqHandler> defaultIqHandler;
	id <MessageHandler> defaultMessageHandler;
	id <PresenceHandler> defaultPresenceHandler;
}
/**
 * Create a new dispatcher with default handlers.  In the current implementation
 * all of these will be set to DefaultHander objects.
 */
+ (id) dispatcherWithDefaultIqHandler:(id <IqHandler>)iq 
					   messageHandler:(id <MessageHandler>)message 
					  presenceHandler:(id <PresenceHandler>)presence;
/** 
 * Initialise a new dispatcher with default handlers 
 */
- (id) initWithDefaultIqHandler:(id <IqHandler>)iq 
				 messageHandler:(id <MessageHandler>)message 
				presenceHandler:(id <PresenceHandler>)presence;
/**
 * Add a handler for info-query packets with the type 'result' or 'error'.  Each
 * outgoing packet should have a unique ID (which can be generated by the 
 * connection object if required).  This ID will be re-used for the reply.  This
 * method should be used to set up handlers for replies to queries sent to
 * remote clients.
 */
- (id) addIqResultHandler:(id <IqHandler>)handler forID:(NSString*)iqID;
/**
 * Add a handler for info-query packets with the type 'set' or 'get' in the 
 * specified namespace.
 */
- (id) addIqQueryHandler:(id <IqHandler>)handler forNamespace:(NSString*)aNamespace;
/**
 * Add a message handler for a specified JID.  All messages sent by this JID 
 * will be routed to the specified handler.  If a JID with no resource is 
 * specified, then it will receive messages sent by all resources for the given
 * JID.
 */
- (id) addMessageHandler:(id <MessageHandler>)handler ForJID:(NSString*)jid;
/**
 * Add a presence handler with the same delivery semantics as a message handler.
 */
- (id) addPresenceHandler:(id <PresenceHandler>)handler ForJID:(NSString*)jid;
/**
 * Dispatch the specified message object to anyone who has elected to receive 
 * it.
 */
- (void) dispatchMessage:(Message*)aMessage;
/**
 * Dispatch the specified presence object to anyone who has elected to receive 
 * it.
 */
- (void) dispatchPresence:(Presence*)aPresence;
/**
 * Dispatch the specified info-query object to anyone who has elected to 
 * receive it.
 */
- (void) dispatchIq:(Iq*)anIq;

@end

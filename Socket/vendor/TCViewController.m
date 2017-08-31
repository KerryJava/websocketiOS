//
// Copyright 2012 Square Inc.
// Portions Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE-examples file in the root directory of this source tree.
//

#import "TCViewController.h"

#import <SocketRocket/SocketRocket.h>

#import "TCChatCell.h"

@interface TCMessage : NSObject

- (instancetype)initWithMessage:(NSString *)message incoming:(BOOL)incoming;

@property (nonatomic, copy, readonly) NSString *message;
@property (nonatomic, assign, readonly, getter=isIncoming) BOOL incoming;

@end

@implementation TCMessage

- (instancetype)initWithMessage:(NSString *)message incoming:(BOOL)incoming
{
    self = [super init];
    if (!self) return self;

    _incoming = incoming;
    _message = message;

    return self;
}

@end


@interface TCViewController () <SRWebSocketDelegate, UITextViewDelegate>
{
    SRWebSocket *_webSocket;
    NSMutableArray<TCMessage *> *_messages;
}

@end

@implementation TCViewController

///--------------------------------------
#pragma mark - View
///--------------------------------------

- (void)viewDidLoad;
{
    [super viewDidLoad];

    _messages = [[NSMutableArray alloc] init];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self reconnect:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [_inputView becomeFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    [_webSocket close];
    _webSocket = nil;
}

///--------------------------------------
#pragma mark - Actions
///--------------------------------------

- (IBAction)reconnect:(id)sender
{
    _webSocket.delegate = nil;
    [_webSocket close];

//    _webSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:@"wss://echo.websocket.org"]];
    NSString *url;
    url = @"ws://192.168.1.14:8080/ws";
    _webSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:url]];
    //@"ws://192.168.1.14:8082/ws"
    _webSocket.delegate = self;
    self.title = @"Opening Connection...";
    [_webSocket open];
}

- (void)sendPing:(id)sender;
{
    [_webSocket sendPing:nil];
    //[_webSocket sendPing:nil error:NULL];
}

///--------------------------------------
#pragma mark - Messages
///--------------------------------------

- (void)_addMessage:(TCMessage *)message
{
    [_messages addObject:message];
    [self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:_messages.count - 1 inSection:0] ]
                          withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView scrollRectToVisible:self.tableView.tableFooterView.frame animated:YES];
}

///--------------------------------------
#pragma mark - UITableViewController
///--------------------------------------

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TCMessage *message = _messages[indexPath.row];

    TCChatCell *cell = [self.tableView dequeueReusableCellWithIdentifier:message.incoming ? @"ReceivedCell" : @"SentCell"
                                                            forIndexPath:indexPath];

    cell.textView.text = message.message;
    cell.nameLabel.text = message.incoming ? @"Other" : @"Me";

    return cell;
}

///--------------------------------------
#pragma mark - SRWebSocketDelegate
///--------------------------------------

- (void)webSocketDidOpen:(SRWebSocket *)webSocket;
{
    NSLog(@"Websocket Connected");
    self.title = @"Connected!";
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
{
    NSLog(@":( Websocket Failed With Error %@", error);

    self.title = @"Connection Failed! (see logs)";
    NSString *reason = [NSString stringWithFormat:@"%@", error.localizedDescription];
    [self _addMessage:[[TCMessage alloc] initWithMessage:reason incoming:YES]];
    _webSocket = nil;
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(nonnull NSString *)string
{
    NSLog(@"Received \"%@\"", string);
    [self _addMessage:[[TCMessage alloc] initWithMessage:string incoming:YES]];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessageWithString:(nonnull NSString *)string
{
    NSLog(@"Received \"%@\"", string);
    [self _addMessage:[[TCMessage alloc] initWithMessage:string incoming:YES]];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
{
    NSLog(@"WebSocket closed");
    self.title = @"Connection Closed! (see logs)";
    NSString *reasonstr = [NSString stringWithFormat:@"%@, %zd %@", reason, code, wasClean?@"clean":@"No clea"];
    [self _addMessage:[[TCMessage alloc] initWithMessage:reasonstr incoming:YES]];
    _webSocket = nil;
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload;
{
    NSLog(@"WebSocket received pong");
    NSString *reason = [NSString stringWithFormat:@"%@", @"pong"];
    [self _addMessage:[[TCMessage alloc] initWithMessage:reason incoming:YES]];
}

///--------------------------------------
#pragma mark - UITextViewDelegate
///--------------------------------------

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if ([text rangeOfString:@"\n"].location != NSNotFound) {
        NSString *message = [textView.text stringByReplacingCharactersInRange:range withString:text];
        message = [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

//        [_webSocket sendString:message error:NULL];
        [_webSocket send:message];
        [self _addMessage:[[TCMessage alloc] initWithMessage:message incoming:NO]];

        textView.text = nil;
        return NO;
    }
    return YES;
}

@end

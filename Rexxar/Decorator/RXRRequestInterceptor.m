//
//  RXRRequestInterceptor.m
//  Rexxar
//
//  Created by bigyelow on 09/03/2017.
//  Copyright © 2017 Douban.Inc. All rights reserved.
//

#import "RXRRequestInterceptor.h"
#import "RXRURLSessionDemux.h"

static NSArray<id<RXRDecorator>> *_decorators;

@implementation RXRRequestInterceptor

#pragma mark - Properties

+ (NSArray<id<RXRDecorator>> *)decorators
{
  return _decorators;
}

+ (void)setDecorators:(NSArray<id<RXRDecorator>> *)decorators
{
  _decorators = [decorators copy];
}

#pragma mark - Superclass methods

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
  // 请求被忽略（被标记为忽略或者已经请求过），不处理
  if ([self isRequestIgnored:request]) {
    return NO;
  }
  // 请求不是来自浏览器，不处理
  if (![request.allHTTPHeaderFields[@"User-Agent"] hasPrefix:@"Mozilla"]) {
    return NO;
  }

  for (id<RXRDecorator> decorator in _decorators) {
    if ([decorator shouldInterceptRequest:request]){
      return YES;
    }
  }

  return NO;
}

- (void)startLoading
{
  NSMutableURLRequest *newRequest = nil;
  if ([self.request isKindOfClass:[NSMutableURLRequest class]]) {
    newRequest = (NSMutableURLRequest *)self.request;
  } else {
    newRequest = [self.request mutableCopy];
  }

  for (id<RXRDecorator> decorator in _decorators) {
    if ([decorator shouldInterceptRequest:self.request]) {
      if ([decorator respondsToSelector:@selector(prepareWithRequest:)]) {
        [decorator prepareWithRequest:self.request];
      }
      newRequest = [[decorator decoratedRequestFromOriginalRequest:newRequest] mutableCopy];
    }
  }

  [[self class] markRequestAsIgnored:newRequest];

  NSMutableArray *modes = [NSMutableArray array];
  [modes addObject:NSDefaultRunLoopMode];

  NSString *currentMode = [[NSRunLoop currentRunLoop] currentMode];
  if (currentMode != nil && ![currentMode isEqualToString:NSDefaultRunLoopMode]) {
    [modes addObject:currentMode];
  }
  [self setModes:modes];

  NSURLSessionTask *dataTask = [[[self class] sharedDemux] dataTaskWithRequest:newRequest delegate:self modes:self.modes];
  [dataTask resume];
  [self setDataTask:dataTask];
}

@end

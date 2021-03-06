/*
 * SCMachineInfo_Darwin.m - Darwin specific backend for SCMachineInfo
 *
 * Copyright 2006, David Chisnall
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, 
 * this list of conditions and the following disclaimer.
 * 
 * Redistributions in binary form must reproduce the above copyright notice, 
 * this list of conditions and the following disclaimer in the documentation 
 * and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */
#ifdef DARWIN

#import "SCMachineInfo.h"

#define LONGLONGSYSCTLS

#import "TRSysctlByName.h"

@implementation SCMachineInfo (Darwin)

+ (unsigned long long) realMemory
{
  return (unsigned long long) performIntegerSysctlNamed ("hw.memsize");
}

+ (unsigned int) cpuMHzSpeed
{
  // hw.cpufrequency returns speed in Hz on Darwin
  return (unsigned int) (performIntegerSysctlNamed ("hw.cpufrequency") /
                         1000000);
}

+ (NSString *) cpuName
{
  return performSysctlNamed ("hw.model");
}

+ (BOOL) platformSupported
{
  return YES;
}

@end

#endif // DARWIN

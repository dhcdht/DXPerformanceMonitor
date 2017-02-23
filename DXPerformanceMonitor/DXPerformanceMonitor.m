//
//  DXPerformanceMonitor.m
//  Pods
//
//  Created by dhcdht on 2017/2/20.
//
//

#import "DXPerformanceMonitor.h"
#include "KSStackCursor_MachineContext.h"
#import <mach/mach.h>
#import <pthread.h>


#define KSMC_NEW_CONTEXT(NAME) \
char ksmc_##NAME##_storage[ksmc_contextSize()]; \
struct KSMachineContext* NAME = (struct KSMachineContext*)ksmc_##NAME##_storage

int ksmc_contextSize()
{
    return sizeof(KSMachineContext);
}


thread_t ksthread_self()
{
    thread_t thread_self = mach_thread_self();
    mach_port_deallocate(mach_task_self(), thread_self);
    return thread_self;
}

void ksmc_suspendEnvironment()
{
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = (thread_t)ksthread_self();
    thread_act_array_t threads;
    mach_msg_type_number_t numThreads;
    
    if((kr = task_threads(thisTask, &threads, &numThreads)) != KERN_SUCCESS)
    {
        NSLog(@"task_threads: %s", mach_error_string(kr));
        return;
    }
    
    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
    {
        thread_t thread = threads[i];
        if(thread != thisThread)
        {
            if((kr = thread_suspend(thread)) != KERN_SUCCESS)
            {
                // Record the error and keep going.
                NSLog(@"thread_suspend (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }
    
    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
    {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * numThreads);
}

bool kscpu_i_fillState(const thread_t thread,
                       const thread_state_t state,
                       const thread_state_flavor_t flavor,
                       const mach_msg_type_number_t stateCount)
{
    mach_msg_type_number_t stateCountBuff = stateCount;
    kern_return_t kr;
    
    kr = thread_get_state(thread, flavor, state, &stateCountBuff);
    if(kr != KERN_SUCCESS)
    {
        NSLog(@"thread_get_state: %s", mach_error_string(kr));
        return false;
    }
    return true;
}

bool ksmc_getContextForThread(thread_t thread, KSMachineContext* destinationContext)
{
    memset(destinationContext, 0, sizeof(*destinationContext));
    
    STRUCT_MCONTEXT_L* const machineContext = &destinationContext->machineContext;
    kscpu_i_fillState(thread, (thread_state_t)&machineContext->__ss, x86_THREAD_STATE64, x86_THREAD_STATE64_COUNT);
    kscpu_i_fillState(thread, (thread_state_t)&machineContext->__es, x86_EXCEPTION_STATE64, x86_EXCEPTION_STATE64_COUNT);
    
    return true;
}


@implementation DXPerformanceMonitor

+ (void)dumpThread {
    ksmc_suspendEnvironment();
    
    KSStackCursor stackCursor = {0};
    kssc_initCursor(&stackCursor, NULL, NULL);
    
    char ksmc_machineContext_storage[ksmc_contextSize()];
    struct KSMachineContext* machineContext = (struct KSMachineContext*)ksmc_machineContext_storage;
    
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t numThreads = 0;
    kern_return_t kr = KERN_FAILURE;
    if((kr = task_threads(mach_task_self(), &threads, &numThreads)) != KERN_SUCCESS)
    {
        NSLog(@"task_threads: %s", mach_error_string(kr));
        return;
    }
    
    for (int i  = 0; i < numThreads; i++) {
        thread_t t = threads[i];
        
        if (t != ksthread_self()) {
            pthread_t pt = pthread_from_mach_thread_np(t);
            char ptName[256] = {0};
            size_t ptNameSize = 256;
            pthread_getname_np(pt, ptName, 256);
            
            ksmc_getContextForThread(t, machineContext);
            
            kssc_initWithMachineContext(&stackCursor, 100, machineContext);
            
            NSLog(@"begin thread %s : %i", ptName, i);
            while (stackCursor.advanceCursor(&stackCursor)) {
                NSLog(@"%p", stackCursor.stackEntry.address);
            }
            NSLog(@"end thread %s : %i", ptName, i);
        }
    }
    
    NSLog(@"done");
}

@end

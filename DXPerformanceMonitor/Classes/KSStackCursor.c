//
//  KSStackCursor.h
//
//  Copyright (c) 2016 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//


#include "KSStackCursor.h"
//#include "KSSymbolicator.h"
#include <stdlib.h>
#include "KSDynamicLinker.h"

////#define KSLogger_LocalLevel TRACE
//#include "KSLogger.h"

/** Remove any pointer tagging from an instruction address
 * On armv7 the least significant bit of the pointer distinguishes
 * between thumb mode (2-byte instructions) and normal mode (4-byte instructions).
 * On arm64 all instructions are 4-bytes wide so the two least significant
 * bytes should always be 0.
 * On x86_64 and i386, instructions are variable length so all bits are
 * signficant.
 */
#if defined(__arm__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(1UL))
#elif defined(__arm64__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(3UL))
#else
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#endif

/** Step backwards by one instruction.
 * The backtrace of an objective-C program is expected to contain return
 * addresses not call instructions, as that is what can easily be read from
 * the stack. This is not a problem except for a few cases where the return
 * address is inside a different symbol than the call address.
 */
#define CALL_INSTRUCTION_FROM_RETURN_ADDRESS(A) (DETAG_INSTRUCTION_ADDRESS((A)) - 1)

bool kssymbolicator_symbolicate(KSStackCursor *cursor)
{
    Dl_info symbolsBuffer;
    if(ksdl_dladdr(CALL_INSTRUCTION_FROM_RETURN_ADDRESS(cursor->stackEntry.address), &symbolsBuffer))
    {
        cursor->stackEntry.imageAddress = (uintptr_t)symbolsBuffer.dli_fbase;
        cursor->stackEntry.imageName = symbolsBuffer.dli_fname;
        cursor->stackEntry.symbolAddress = (uintptr_t)symbolsBuffer.dli_saddr;
        cursor->stackEntry.symbolName = symbolsBuffer.dli_sname;
        return true;
    }
    
    cursor->stackEntry.imageAddress = 0;
    cursor->stackEntry.imageName = 0;
    cursor->stackEntry.symbolAddress = 0;
    cursor->stackEntry.symbolName = 0;
    return false;
}


static bool g_advanceCursor(__unused KSStackCursor *cursor)
{
    return false;
}

void kssc_resetCursor(KSStackCursor *cursor)
{
    cursor->state.currentDepth = 0;
    cursor->state.hasGivenUp = false;
    cursor->stackEntry.address = 0;
    cursor->stackEntry.imageAddress = 0;
    cursor->stackEntry.imageName = NULL;
    cursor->stackEntry.symbolAddress = 0;
    cursor->stackEntry.symbolName = NULL;
}

void kssc_initCursor(KSStackCursor *cursor,
                     void (*resetCursor)(KSStackCursor*),
                     bool (*advanceCursor)(KSStackCursor*))
{
    cursor->symbolicate = kssymbolicator_symbolicate;
    cursor->advanceCursor = advanceCursor != NULL ? advanceCursor : g_advanceCursor;
    cursor->resetCursor = resetCursor != NULL ? resetCursor : kssc_resetCursor;
    cursor->resetCursor(cursor);
}

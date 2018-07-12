//===-- Resumableutines.h - Resumableutine Transformations ----------------*-
//C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
// Declare accessor functions for coroutine lowering passes.
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_RESUMABLE_H
#define LLVM_TRANSFORMS_RESUMABLE_H

namespace llvm {

class Pass;
class PassManagerBuilder;

/// Add all coroutine passes to appropriate extension points.
void addResumableutinePassesToExtensionPoints(PassManagerBuilder &Builder);

/// Lower coroutine intrinsics that are not needed by later passes.
Pass *createResumableEarlyPass();

/// Lower all remaining coroutine intrinsics.
Pass *createResumableCleanupPass();

} // namespace llvm

#endif

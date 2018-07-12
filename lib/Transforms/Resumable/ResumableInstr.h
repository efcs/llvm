//===-- ResumableInstr.h - Resumableutine Intrinsics Instruction Wrappers -*-
//C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
// This file defines classes that make it really easy to deal with intrinsic
// functions with the isa/dyncast family of functions.  In particular, this
// allows you to do things like:
//
//     if (auto *SF = dyn_cast<ResumableSubFnInst>(Inst))
//        ... SF->getFrame() ...
//
// All intrinsic function calls are instances of the call instruction, so these
// are all subclasses of the CallInst class.  Note that none of these classes
// has state or virtual methods, which is an important part of this gross/neat
// hack working.
//
// The helpful comment above is borrowed from llvm/IntrinsicInst.h, we keep
// resumableutine intrinsic wrappers here since they are only used by the passes
// in the Resumableutine library.
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TRANSFORMS_RESUMABLE_RESUMABLEINSTR_H
#define LLVM_LIB_TRANSFORMS_RESUMABLE_RESUMABLEINSTR_H

#include "llvm/IR/GlobalVariable.h"
#include "llvm/IR/IntrinsicInst.h"

namespace llvm {

/// This represents the llvm.resumable.frame instruction.
class LLVM_LIBRARY_VISIBILITY ResumableFrameInst : public IntrinsicInst {
public:
  // Methods to support type inquiry through isa, cast, and dyn_cast:
  static bool classof(const IntrinsicInst *I) {
    return I->getIntrinsicID() == Intrinsic::resumable_frame;
  }
  static bool classof(const Value *V) {
    return isa<IntrinsicInst>(V) && classof(cast<IntrinsicInst>(V));
  }
};

/// This class represents the llvm.resumable.begin instruction.
class LLVM_LIBRARY_VISIBILITY ResumableBeginInst : public IntrinsicInst {
  enum { IdArg, MemArg };

public:
  Value *getMem() const { return getArgOperand(MemArg); }

  // Methods for support type inquiry through isa, cast, and dyn_cast:
  static bool classof(const IntrinsicInst *I) {
    return I->getIntrinsicID() == Intrinsic::resumable_begin;
  }
  static bool classof(const Value *V) {
    return isa<IntrinsicInst>(V) && classof(cast<IntrinsicInst>(V));
  }
};

/// This represents the llvm.resumable.promise instruction.
class LLVM_LIBRARY_VISIBILITY ResumablePromiseInst : public IntrinsicInst {
  enum { FrameArg, AlignArg, FromArg };

public:
  bool isFromPromise() const {
    return cast<Constant>(getArgOperand(FromArg))->isOneValue();
  }
  unsigned getAlignment() const {
    return cast<ConstantInt>(getArgOperand(AlignArg))->getZExtValue();
  }

  // Methods to support type inquiry through isa, cast, and dyn_cast:
  static bool classof(const IntrinsicInst *I) {
    return I->getIntrinsicID() == Intrinsic::resumable_promise;
  }
  static bool classof(const Value *V) {
    return isa<IntrinsicInst>(V) && classof(cast<IntrinsicInst>(V));
  }
};

/// This represents the llvm.resumable.suspend instruction.
class LLVM_LIBRARY_VISIBILITY ResumableSuspendInst : public IntrinsicInst {
  enum { SaveArg, FinalArg };

public:


  // Methods to support type inquiry through isa, cast, and dyn_cast:
  static bool classof(const IntrinsicInst *I) {
    return I->getIntrinsicID() == Intrinsic::resumable_suspend;
  }
  static bool classof(const Value *V) {
    return isa<IntrinsicInst>(V) && classof(cast<IntrinsicInst>(V));
  }
};

/// This represents the llvm.resumable.size instruction.
class LLVM_LIBRARY_VISIBILITY ResumableSizeInst : public IntrinsicInst {
public:
  // Methods to support type inquiry through isa, cast, and dyn_cast:
  static bool classof(const IntrinsicInst *I) {
    return I->getIntrinsicID() == Intrinsic::resumable_size;
  }
  static bool classof(const Value *V) {
    return isa<IntrinsicInst>(V) && classof(cast<IntrinsicInst>(V));
  }
};

/// This represents the llvm.resumable.end instruction.
class LLVM_LIBRARY_VISIBILITY ResumableEndInst : public IntrinsicInst {
  enum { FrameArg, UnwindArg };

public:
  bool isFallthrough() const { return !isUnwind(); }
  bool isUnwind() const {
    return cast<Constant>(getArgOperand(UnwindArg))->isOneValue();
  }

  // Methods to support type inquiry through isa, cast, and dyn_cast:
  static bool classof(const IntrinsicInst *I) {
    return I->getIntrinsicID() == Intrinsic::resumable_end;
  }
  static bool classof(const Value *V) {
    return isa<IntrinsicInst>(V) && classof(cast<IntrinsicInst>(V));
  }
};

} // End namespace llvm.

#endif

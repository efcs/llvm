//===- Resumables.cpp -----------------------------------------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file implements the common infrastructure for Resumable Passes.
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/Resumable.h"
#include "ResumableInstr.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Analysis/CallGraph.h"
#include "llvm/Analysis/CallGraphSCCPass.h"
#include "llvm/IR/Attributes.h"
#include "llvm/IR/CallSite.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Type.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Transforms/IPO.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"
#include "llvm/Transforms/Utils/Local.h"
#include <cassert>
#include <cstddef>
#include <utility>

using namespace llvm;

void llvm::initializeResumable(PassRegistry &Registry) {
  initializeResumableEarlyPass(Registry);
  initializeResumableCleanupPass(Registry);
}

static void addResumableOpt0Passes(const PassManagerBuilder &Builder,
                                   legacy::PassManagerBase &PM) {

  PM.add(createResumableCleanupPass());
}

static void addResumableEarlyPasses(const PassManagerBuilder &Builder,
                                    legacy::PassManagerBase &PM) {
  PM.add(createResumableEarlyPass());
}

static void addResumableOptimizerLastPasses(const PassManagerBuilder &Builder,
                                            legacy::PassManagerBase &PM) {
  PM.add(createResumableCleanupPass());
}

void llvm::addResumablePassesToExtensionPoints(PassManagerBuilder &Builder) {
  Builder.addExtension(PassManagerBuilder::EP_EarlyAsPossible,
                       addResumableEarlyPasses);
  Builder.addExtension(PassManagerBuilder::EP_EnabledOnOptLevel0,
                       addResumableOpt0Passes);

  Builder.addExtension(PassManagerBuilder::EP_OptimizerLast,
                       addResumableOptimizerLastPasses);
}

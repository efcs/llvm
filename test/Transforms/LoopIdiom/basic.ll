; RUN: opt -basicaa -loop-idiom < %s -S | FileCheck %s
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64"

; For @test11_pattern
; CHECK: @.memset_pattern = private unnamed_addr constant [4 x i32] [i32 1, i32 1, i32 1, i32 1]

; For @test13_pattern
; CHECK: @.memset_pattern.1 = private unnamed_addr constant [2 x i32*] [i32* @G, i32* @G]

target triple = "x86_64-apple-darwin10.0.0"

define void @test1(i8* %Base, i64 %Size) nounwind ssp {
bb.nph:                                           ; preds = %entry
  br label %for.body

for.body:                                         ; preds = %bb.nph, %for.body
  %indvar = phi i64 [ 0, %bb.nph ], [ %indvar.next, %for.body ]
  %I.0.014 = getelementptr i8, i8* %Base, i64 %indvar
  store i8 0, i8* %I.0.014, align 1
  %indvar.next = add i64 %indvar, 1
  %exitcond = icmp eq i64 %indvar.next, %Size
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @test1(
; CHECK: call void @llvm.memset.p0i8.i64(i8* align 1 %Base, i8 0, i64 %Size, i1 false)
; CHECK-NOT: store
}

; This is a loop that was rotated but where the blocks weren't merged.  This
; shouldn't perturb us.
define void @test1a(i8* %Base, i64 %Size) nounwind ssp {
bb.nph:                                           ; preds = %entry
  br label %for.body

for.body:                                         ; preds = %bb.nph, %for.body
  %indvar = phi i64 [ 0, %bb.nph ], [ %indvar.next, %for.body.cont ]
  %I.0.014 = getelementptr i8, i8* %Base, i64 %indvar
  store i8 0, i8* %I.0.014, align 1
  %indvar.next = add i64 %indvar, 1
  br label %for.body.cont
for.body.cont:
  %exitcond = icmp eq i64 %indvar.next, %Size
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @test1a(
; CHECK: call void @llvm.memset.p0i8.i64(i8* align 1 %Base, i8 0, i64 %Size, i1 false)
; CHECK-NOT: store
}


define void @test2(i32* %Base, i64 %Size) nounwind ssp {
entry:
  %cmp10 = icmp eq i64 %Size, 0
  br i1 %cmp10, label %for.end, label %for.body

for.body:                                         ; preds = %entry, %for.body
  %i.011 = phi i64 [ %inc, %for.body ], [ 0, %entry ]
  %add.ptr.i = getelementptr i32, i32* %Base, i64 %i.011
  store i32 16843009, i32* %add.ptr.i, align 4
  %inc = add nsw i64 %i.011, 1
  %exitcond = icmp eq i64 %inc, %Size
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @test2(
; CHECK: br i1 %cmp10,
; CHECK: %0 = shl i64 %Size, 2
; CHECK: call void @llvm.memset.p0i8.i64(i8* align 4 %Base1, i8 1, i64 %0, i1 false)
; CHECK-NOT: store
}

; This is a case where there is an extra may-aliased store in the loop, we can't
; promote the memset.
define void @test3(i32* %Base, i64 %Size, i8 *%MayAlias) nounwind ssp {
entry:
  br label %for.body

for.body:                                         ; preds = %entry, %for.body
  %i.011 = phi i64 [ %inc, %for.body ], [ 0, %entry ]
  %add.ptr.i = getelementptr i32, i32* %Base, i64 %i.011
  store i32 16843009, i32* %add.ptr.i, align 4
  
  store i8 42, i8* %MayAlias
  %inc = add nsw i64 %i.011, 1
  %exitcond = icmp eq i64 %inc, %Size
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %entry
  ret void
; CHECK-LABEL: @test3(
; CHECK-NOT: memset
; CHECK: ret void
}

; Make sure the first store in the loop is turned into a memset.
define void @test4(i8* %Base) nounwind ssp {
bb.nph:                                           ; preds = %entry
  %Base100 = getelementptr i8, i8* %Base, i64 1000
  br label %for.body

for.body:                                         ; preds = %bb.nph, %for.body
  %indvar = phi i64 [ 0, %bb.nph ], [ %indvar.next, %for.body ]
  %I.0.014 = getelementptr i8, i8* %Base, i64 %indvar
  store i8 0, i8* %I.0.014, align 1
  
  ;; Store beyond the range memset, should be safe to promote.
  store i8 42, i8* %Base100
  
  %indvar.next = add i64 %indvar, 1
  %exitcond = icmp eq i64 %indvar.next, 100
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @test4(
; CHECK: call void @llvm.memset.p0i8.i64(i8* align 1 %Base, i8 0, i64 100, i1 false)
}

; This can't be promoted: the memset is a store of a loop variant value.
define void @test5(i8* %Base, i64 %Size) nounwind ssp {
bb.nph:                                           ; preds = %entry
  br label %for.body

for.body:                                         ; preds = %bb.nph, %for.body
  %indvar = phi i64 [ 0, %bb.nph ], [ %indvar.next, %for.body ]
  %I.0.014 = getelementptr i8, i8* %Base, i64 %indvar
  
  %V = trunc i64 %indvar to i8
  store i8 %V, i8* %I.0.014, align 1
  %indvar.next = add i64 %indvar, 1
  %exitcond = icmp eq i64 %indvar.next, %Size
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @test5(
; CHECK-NOT: memset
; CHECK: ret void
}


;; memcpy formation
define void @test6(i64 %Size) nounwind ssp {
bb.nph:
  %Base = alloca i8, i32 10000
  %Dest = alloca i8, i32 10000
  br label %for.body

for.body:                                         ; preds = %bb.nph, %for.body
  %indvar = phi i64 [ 0, %bb.nph ], [ %indvar.next, %for.body ]
  %I.0.014 = getelementptr i8, i8* %Base, i64 %indvar
  %DestI = getelementptr i8, i8* %Dest, i64 %indvar
  %V = load i8, i8* %I.0.014, align 1
  store i8 %V, i8* %DestI, align 1
  %indvar.next = add i64 %indvar, 1
  %exitcond = icmp eq i64 %indvar.next, %Size
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @test6(
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 1 %Dest, i8* align 1 %Base, i64 %Size, i1 false)
; CHECK-NOT: store
; CHECK: ret void
}


; This is a loop that was rotated but where the blocks weren't merged.  This
; shouldn't perturb us.
define void @test7(i8* %Base, i64 %Size) nounwind ssp {
bb.nph:                                           ; preds = %entry
  br label %for.body

for.body:                                         ; preds = %bb.nph, %for.body
  %indvar = phi i64 [ 0, %bb.nph ], [ %indvar.next, %for.body.cont ]
  br label %for.body.cont
for.body.cont:
  %I.0.014 = getelementptr i8, i8* %Base, i64 %indvar
  store i8 0, i8* %I.0.014, align 1
  %indvar.next = add i64 %indvar, 1
  %exitcond = icmp eq i64 %indvar.next, %Size
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @test7(
; CHECK: call void @llvm.memset.p0i8.i64(i8* align 1 %Base, i8 0, i64 %Size, i1 false)
; CHECK-NOT: store
}

; This is a loop should not be transformed, it only executes one iteration.
define void @test8(i64* %Ptr, i64 %Size) nounwind ssp {
bb.nph:                                           ; preds = %entry
  br label %for.body

for.body:                                         ; preds = %bb.nph, %for.body
  %indvar = phi i64 [ 0, %bb.nph ], [ %indvar.next, %for.body ]
  %PI = getelementptr i64, i64* %Ptr, i64 %indvar
  store i64 0, i64 *%PI
  %indvar.next = add i64 %indvar, 1
  %exitcond = icmp eq i64 %indvar.next, 1
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @test8(
; CHECK: store i64 0, i64* %PI
}

declare i8* @external(i8*)

;; This cannot be transformed into a memcpy, because the read-from location is
;; mutated by the loop.
define void @test9(i64 %Size) nounwind ssp {
bb.nph:
  %Base = alloca i8, i32 10000
  %Dest = alloca i8, i32 10000
  
  %BaseAlias = call i8* @external(i8* %Base)
  br label %for.body

for.body:                                         ; preds = %bb.nph, %for.body
  %indvar = phi i64 [ 0, %bb.nph ], [ %indvar.next, %for.body ]
  %I.0.014 = getelementptr i8, i8* %Base, i64 %indvar
  %DestI = getelementptr i8, i8* %Dest, i64 %indvar
  %V = load i8, i8* %I.0.014, align 1
  store i8 %V, i8* %DestI, align 1

  ;; This store can clobber the input.
  store i8 4, i8* %BaseAlias
 
  %indvar.next = add i64 %indvar, 1
  %exitcond = icmp eq i64 %indvar.next, %Size
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @test9(
; CHECK-NOT: llvm.memcpy
; CHECK: ret void
}

; Two dimensional nested loop should be promoted to one big memset.
define void @test10(i8* %X) nounwind ssp {
entry:
  br label %bb.nph

bb.nph:                                           ; preds = %entry, %for.inc10
  %i.04 = phi i32 [ 0, %entry ], [ %inc12, %for.inc10 ]
  br label %for.body5

for.body5:                                        ; preds = %for.body5, %bb.nph
  %j.02 = phi i32 [ 0, %bb.nph ], [ %inc, %for.body5 ]
  %mul = mul nsw i32 %i.04, 100
  %add = add nsw i32 %j.02, %mul
  %idxprom = sext i32 %add to i64
  %arrayidx = getelementptr inbounds i8, i8* %X, i64 %idxprom
  store i8 0, i8* %arrayidx, align 1
  %inc = add nsw i32 %j.02, 1
  %cmp4 = icmp eq i32 %inc, 100
  br i1 %cmp4, label %for.inc10, label %for.body5

for.inc10:                                        ; preds = %for.body5
  %inc12 = add nsw i32 %i.04, 1
  %cmp = icmp eq i32 %inc12, 100
  br i1 %cmp, label %for.end13, label %bb.nph

for.end13:                                        ; preds = %for.inc10
  ret void
; CHECK-LABEL: @test10(
; CHECK: entry:
; CHECK-NEXT: call void @llvm.memset.p0i8.i64(i8* align 1 %X, i8 0, i64 10000, i1 false)
; CHECK-NOT: store
; CHECK: ret void
}

; On darwin10 (which is the triple in this .ll file) this loop can be turned
; into a memset_pattern call.
; rdar://9009151
define void @test11_pattern(i32* nocapture %P) nounwind ssp {
entry:
  br label %for.body

for.body:                                         ; preds = %entry, %for.body
  %indvar = phi i64 [ 0, %entry ], [ %indvar.next, %for.body ]
  %arrayidx = getelementptr i32, i32* %P, i64 %indvar
  store i32 1, i32* %arrayidx, align 4
  %indvar.next = add i64 %indvar, 1
  %exitcond = icmp eq i64 %indvar.next, 10000
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body
  ret void
; CHECK-LABEL: @test11_pattern(
; CHECK-NEXT: entry:
; CHECK-NEXT: bitcast
; CHECK-NEXT: memset_pattern
; CHECK-NOT: store
; CHECK: ret void
}

; Store of null should turn into memset of zero.
define void @test12(i32** nocapture %P) nounwind ssp {
entry:
  br label %for.body

for.body:                                         ; preds = %entry, %for.body
  %indvar = phi i64 [ 0, %entry ], [ %indvar.next, %for.body ]
  %arrayidx = getelementptr i32*, i32** %P, i64 %indvar
  store i32* null, i32** %arrayidx, align 4
  %indvar.next = add i64 %indvar, 1
  %exitcond = icmp eq i64 %indvar.next, 10000
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body
  ret void
; CHECK-LABEL: @test12(
; CHECK-NEXT: entry:
; CHECK-NEXT: bitcast
; CHECK-NEXT: call void @llvm.memset.p0i8.i64(i8* align 4 %P1, i8 0, i64 80000, i1 false)
; CHECK-NOT: store
; CHECK: ret void
}

@G = global i32 5

; This store-of-address loop can be turned into a memset_pattern call.
; rdar://9009151
define void @test13_pattern(i32** nocapture %P) nounwind ssp {
entry:
  br label %for.body

for.body:                                         ; preds = %entry, %for.body
  %indvar = phi i64 [ 0, %entry ], [ %indvar.next, %for.body ]
  %arrayidx = getelementptr i32*, i32** %P, i64 %indvar
  store i32* @G, i32** %arrayidx, align 4
  %indvar.next = add i64 %indvar, 1
  %exitcond = icmp eq i64 %indvar.next, 10000
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                          ; preds = %for.body
  ret void
; CHECK-LABEL: @test13_pattern(
; CHECK-NEXT: entry:
; CHECK-NEXT: bitcast
; CHECK-NEXT: memset_pattern
; CHECK-NOT: store
; CHECK: ret void
}



; PR9815 - This is a partial overlap case that cannot be safely transformed
; into a memcpy.
@g_50 = global [7 x i32] [i32 0, i32 0, i32 0, i32 0, i32 1, i32 0, i32 0], align 16

define i32 @test14() nounwind {
entry:
  br label %for.body

for.body:                                         ; preds = %for.inc, %for.body.lr.ph
  %tmp5 = phi i32 [ %inc, %for.body ], [ 0, %entry ]
  %add = add nsw i32 %tmp5, 4
  %idxprom = sext i32 %add to i64
  %arrayidx = getelementptr inbounds [7 x i32], [7 x i32]* @g_50, i32 0, i64 %idxprom
  %tmp2 = load i32, i32* %arrayidx, align 4
  %add4 = add nsw i32 %tmp5, 5
  %idxprom5 = sext i32 %add4 to i64
  %arrayidx6 = getelementptr inbounds [7 x i32], [7 x i32]* @g_50, i32 0, i64 %idxprom5
  store i32 %tmp2, i32* %arrayidx6, align 4
  %inc = add nsw i32 %tmp5, 1
  %cmp = icmp slt i32 %inc, 2
  br i1 %cmp, label %for.body, label %for.end

for.end:                                          ; preds = %for.inc
  %tmp8 = load i32, i32* getelementptr inbounds ([7 x i32], [7 x i32]* @g_50, i32 0, i64 6), align 4
  ret i32 %tmp8
; CHECK-LABEL: @test14(
; CHECK-NEXT: entry:
; CHECK-NEXT: call void @llvm.memmove.p0i8.p0i8.i64(i8* align 4 bitcast (i32* getelementptr inbounds ([7 x i32], [7 x i32]* @g_50, i64 0, i64 5) to i8*), i8* align 4 bitcast (i32* getelementptr inbounds ([7 x i32], [7 x i32]* @g_50, i64 0, i64 4) to i8*), i64 8, i1 false)
; CHECK: for.body:
; CHECK-NOT: store
; CHECK: br i1 %cmp

}

define void @PR14241(i32* %s, i64 %size) {
; Ensure that we don't form a memcpy for strided loops. Briefly, when we taught
; LoopIdiom about memmove and strided loops, this got miscompiled into a memcpy
; instead of a memmove. We now have the memmove transform back. Ensure this
; still doesn't generate a memcpy to catch regressions.
;
; CHECK-LABEL: @PR14241(

entry:
  %end.idx = add i64 %size, -1
  %end.ptr = getelementptr inbounds i32, i32* %s, i64 %end.idx
  br label %while.body
; CHECK-NOT: memcpy
; CHECK: call void @llvm.memmove.p0i8.p0i8.i64(i8* align 4 %s1, i8* align 4 %scevgep2, i64 %4, i1 false)
; CHECK-NEXT: br label %while.body
; CHECK-NOT: memcpy


while.body:
; CHECK: while.body:
; CHECK-NOT: store
  %phi.ptr = phi i32* [ %s, %entry ], [ %next.ptr, %while.body ]
  %src.ptr = getelementptr inbounds i32, i32* %phi.ptr, i64 1
  %val = load i32, i32* %src.ptr, align 4
; CHECK: load
  %dst.ptr = getelementptr inbounds i32, i32* %phi.ptr, i64 0
  store i32 %val, i32* %dst.ptr, align 4
; CHECK-NOT: store
  %next.ptr = getelementptr inbounds i32, i32* %phi.ptr, i64 1
  %cmp = icmp eq i32* %next.ptr, %end.ptr
  br i1 %cmp, label %exit, label %while.body

; CHECK: exit:
exit:
  ret void
; CHECK: ret void
}

; Recognize loops with a negative stride.
define void @test15(i32* nocapture %f) {
entry:
  br label %for.body

for.body:
  %indvars.iv = phi i64 [ 65536, %entry ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, i32* %f, i64 %indvars.iv
  store i32 0, i32* %arrayidx, align 4
  %indvars.iv.next = add nsw i64 %indvars.iv, -1
  %cmp = icmp sgt i64 %indvars.iv, 0
  br i1 %cmp, label %for.body, label %for.cond.cleanup

for.cond.cleanup:
  ret void
; CHECK-LABEL: @test15(
; CHECK: call void @llvm.memset.p0i8.i64(i8* align 4 %f1, i8 0, i64 262148, i1 false)
; CHECK-NOT: store
; CHECK: ret void
}

; Loop with a negative stride.  Verify an aliasing write to f[65536] prevents
; the creation of a memset.
define void @test16(i32* nocapture %f) {
entry:
  %arrayidx1 = getelementptr inbounds i32, i32* %f, i64 65536
  br label %for.body

for.body:                                         ; preds = %entry, %for.body
  %indvars.iv = phi i64 [ 65536, %entry ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, i32* %f, i64 %indvars.iv
  store i32 0, i32* %arrayidx, align 4
  store i32 1, i32* %arrayidx1, align 4
  %indvars.iv.next = add nsw i64 %indvars.iv, -1
  %cmp = icmp sgt i64 %indvars.iv, 0
  br i1 %cmp, label %for.body, label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %for.body
  ret void
; CHECK-LABEL: @test16(
; CHECK-NOT: call void @llvm.memset.p0i8.i64
; CHECK: ret void
}

; Handle memcpy-able loops with negative stride.
define noalias i32* @test17(i32* nocapture readonly %a, i32 %c) {
entry:
  %conv = sext i32 %c to i64
  %mul = shl nsw i64 %conv, 2
  %call = tail call noalias i8* @malloc(i64 %mul)
  %0 = bitcast i8* %call to i32*
  %tobool.9 = icmp eq i32 %c, 0
  br i1 %tobool.9, label %while.end, label %while.body.preheader

while.body.preheader:                             ; preds = %entry
  br label %while.body

while.body:                                       ; preds = %while.body.preheader, %while.body
  %dec10.in = phi i32 [ %dec10, %while.body ], [ %c, %while.body.preheader ]
  %dec10 = add nsw i32 %dec10.in, -1
  %idxprom = sext i32 %dec10 to i64
  %arrayidx = getelementptr inbounds i32, i32* %a, i64 %idxprom
  %1 = load i32, i32* %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds i32, i32* %0, i64 %idxprom
  store i32 %1, i32* %arrayidx2, align 4
  %tobool = icmp eq i32 %dec10, 0
  br i1 %tobool, label %while.end.loopexit, label %while.body

while.end.loopexit:                               ; preds = %while.body
  br label %while.end

while.end:                                        ; preds = %while.end.loopexit, %entry
  ret i32* %0
; CHECK-LABEL: @test17(
; CHECK: call void @llvm.memcpy
; CHECK: ret i32*
}

declare noalias i8* @malloc(i64)

; Handle memcpy-able loops with negative stride.
; void test18(unsigned *__restrict__ a, unsigned *__restrict__ b) {
;   for (int i = 2047; i >= 0; --i) {
;     a[i] = b[i];
;   }
; }
define void @test18(i32* noalias nocapture %a, i32* noalias nocapture readonly %b) #0 {
entry:
  br label %for.body

for.body:                                         ; preds = %entry, %for.body
  %indvars.iv = phi i64 [ 2047, %entry ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, i32* %b, i64 %indvars.iv
  %0 = load i32, i32* %arrayidx, align 4
  %arrayidx2 = getelementptr inbounds i32, i32* %a, i64 %indvars.iv
  store i32 %0, i32* %arrayidx2, align 4
  %indvars.iv.next = add nsw i64 %indvars.iv, -1
  %cmp = icmp sgt i64 %indvars.iv, 0
  br i1 %cmp, label %for.body, label %for.cond.cleanup

for.cond.cleanup:                                 ; preds = %for.body
  ret void
; CHECK-LABEL: @test18(
; CHECK: call void @llvm.memcpy
; CHECK: ret
}

; Two dimensional nested loop with negative stride should be promoted to one big memset.
define void @test19(i8* nocapture %X) {
entry:
  br label %for.cond1.preheader

for.cond1.preheader:                              ; preds = %entry, %for.inc4
  %i.06 = phi i32 [ 99, %entry ], [ %dec5, %for.inc4 ]
  %mul = mul nsw i32 %i.06, 100
  br label %for.body3

for.body3:                                        ; preds = %for.cond1.preheader, %for.body3
  %j.05 = phi i32 [ 99, %for.cond1.preheader ], [ %dec, %for.body3 ]
  %add = add nsw i32 %j.05, %mul
  %idxprom = sext i32 %add to i64
  %arrayidx = getelementptr inbounds i8, i8* %X, i64 %idxprom
  store i8 0, i8* %arrayidx, align 1
  %dec = add nsw i32 %j.05, -1
  %cmp2 = icmp sgt i32 %j.05, 0
  br i1 %cmp2, label %for.body3, label %for.inc4

for.inc4:                                         ; preds = %for.body3
  %dec5 = add nsw i32 %i.06, -1
  %cmp = icmp sgt i32 %i.06, 0
  br i1 %cmp, label %for.cond1.preheader, label %for.end6

for.end6:                                         ; preds = %for.inc4
  ret void
; CHECK-LABEL: @test19(
; CHECK: entry:
; CHECK-NEXT: call void @llvm.memset.p0i8.i64(i8* align 1 %X, i8 0, i64 10000, i1 false)
; CHECK: ret void
}

; Handle loops where the trip count is a narrow integer that needs to be
; extended.
define void @form_memset_narrow_size(i64* %ptr, i32 %size) {
; CHECK-LABEL: @form_memset_narrow_size(
entry:
  %cmp1 = icmp sgt i32 %size, 0
  br i1 %cmp1, label %loop.ph, label %exit
; CHECK:       entry:
; CHECK:         %[[C1:.*]] = icmp sgt i32 %size, 0
; CHECK-NEXT:    br i1 %[[C1]], label %loop.ph, label %exit

loop.ph:
  br label %loop.body
; CHECK:       loop.ph:
; CHECK-NEXT:    %[[ZEXT_SIZE:.*]] = zext i32 %size to i64
; CHECK-NEXT:    %[[SCALED_SIZE:.*]] = shl i64 %[[ZEXT_SIZE]], 3
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* align 8 %{{.*}}, i8 0, i64 %[[SCALED_SIZE]], i1 false)

loop.body:
  %storemerge4 = phi i32 [ 0, %loop.ph ], [ %inc, %loop.body ]
  %idxprom = sext i32 %storemerge4 to i64
  %arrayidx = getelementptr inbounds i64, i64* %ptr, i64 %idxprom
  store i64 0, i64* %arrayidx, align 8
  %inc = add nsw i32 %storemerge4, 1
  %cmp2 = icmp slt i32 %inc, %size
  br i1 %cmp2, label %loop.body, label %loop.exit

loop.exit:
  br label %exit

exit:
  ret void
}

define void @form_memcpy_narrow_size(i64* noalias %dst, i64* noalias %src, i32 %size) {
; CHECK-LABEL: @form_memcpy_narrow_size(
entry:
  %cmp1 = icmp sgt i32 %size, 0
  br i1 %cmp1, label %loop.ph, label %exit
; CHECK:       entry:
; CHECK:         %[[C1:.*]] = icmp sgt i32 %size, 0
; CHECK-NEXT:    br i1 %[[C1]], label %loop.ph, label %exit

loop.ph:
  br label %loop.body
; CHECK:       loop.ph:
; CHECK-NEXT:    %[[ZEXT_SIZE:.*]] = zext i32 %size to i64
; CHECK-NEXT:    %[[SCALED_SIZE:.*]] = shl i64 %[[ZEXT_SIZE]], 3
; CHECK-NEXT:    call void @llvm.memcpy.p0i8.p0i8.i64(i8* align 8 %{{.*}}, i8* align 8 %{{.*}}, i64 %[[SCALED_SIZE]], i1 false)

loop.body:
  %storemerge4 = phi i32 [ 0, %loop.ph ], [ %inc, %loop.body ]
  %idxprom1 = sext i32 %storemerge4 to i64
  %arrayidx1 = getelementptr inbounds i64, i64* %src, i64 %idxprom1
  %v = load i64, i64* %arrayidx1, align 8
  %idxprom2 = sext i32 %storemerge4 to i64
  %arrayidx2 = getelementptr inbounds i64, i64* %dst, i64 %idxprom2
  store i64 %v, i64* %arrayidx2, align 8
  %inc = add nsw i32 %storemerge4, 1
  %cmp2 = icmp slt i32 %inc, %size
  br i1 %cmp2, label %loop.body, label %loop.exit

loop.exit:
  br label %exit

exit:
  ret void
}

; Memmove formation tests

declare void @eat(i8 signext)

define void @test_memmove_formation(i8* nocapture %dest, i8* nocapture readonly %source, i64 %size) nounwind ssp {
entry:
  %cmp8 = icmp sgt i64 %size, 0
  br i1 %cmp8, label %for.body.preheader, label %for.end

for.body.preheader:                               ; preds = %entry
  br label %for.body

for.body:                                         ; preds = %for.body.preheader, %for.body
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.body ], [ 0, %for.body.preheader ]
  %arrayidx = getelementptr inbounds i8, i8* %source, i64 %indvars.iv
  %0 = load i8, i8* %arrayidx, align 1
  %arrayidx3 = getelementptr inbounds i8, i8* %dest, i64 %indvars.iv
  store i8 %0, i8* %arrayidx3, align 1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond = icmp eq i64 %indvars.iv.next, %size
  br i1 %exitcond, label %for.end, label %for.body

for.end:                                 ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @test_memmove_formation(
; CHECK: @llvm.memmove.p0i8.p0i8.i64(i8* align 1 %dest, i8* align 1 %source, i64 %size, i1 false)
; CHECK-NOT: store
; CHECK: ret void
}

define void @test_memmove_two(i8* readonly %begin, i8* readnone %end, i8* nocapture %out) nounwind ssp {
entry:
  %cmp1 = icmp eq i8* %begin, %end
  br i1 %cmp1, label %for.end, label %for.body.preheader

for.body.preheader:                               ; preds = %entry
  br label %for.body

for.body:                                         ; preds = %for.body.preheader, %for.body
  %dest.i = phi i8* [ %dest.next, %for.body ], [ %out, %for.body.preheader ]
  %begin.i = phi i8* [ %begin.next, %for.body ], [ %begin, %for.body.preheader ]
  %0 = load i8, i8* %begin.i, align 1
  store i8 %0, i8* %dest.i, align 1
  %begin.next = getelementptr inbounds i8, i8* %begin.i, i64 1
  %dest.next = getelementptr inbounds i8, i8* %dest.i, i64 1
  %cmp = icmp eq i8* %begin.next, %end
  br i1 %cmp, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @test_memmove_two(
; CHECK: call void @llvm.memmove.p0i8.p0i8.i64(i8* align 1 %out, i8* align 1 %begin
; CHECK-NOT: store
; CHECK: ret void
}


; test memmove is not performed since the source array is accessed during the loop.
define void @copy_access_source(i8* readonly %begin, i8* readonly %end, i8* nocapture %out) nounwind ssp {
entry:
  %add.ptr = getelementptr inbounds i8, i8* %end, i64 -1
  %cmp7 = icmp eq i8* %begin, %end
  br i1 %cmp7, label %for.end, label %for.body.preheader

for.body.preheader:                               ; preds = %entry
  br label %for.body

for.body:                                         ; preds = %for.body.preheader, %for.body
  %begin.i = phi i8* [ %begin.next, %for.body ], [ %begin, %for.body.preheader ]
  %dest.i = phi i8* [ %dest.next, %for.body ], [ %out, %for.body.preheader ]
  %0 = load i8, i8* %begin.i, align 1
  store i8 %0, i8* %dest.i, align 1
  %1 = load i8, i8* %add.ptr, align 1
  tail call void @eat(i8 signext %1)
  %begin.next = getelementptr inbounds i8, i8* %begin.i, i64 1
  %dest.next = getelementptr inbounds i8, i8* %dest.i, i64 1
  %cmp = icmp eq i8* %begin.next, %end
  br i1 %cmp, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @copy_access_source
; CHECK-NOT: llvm.memmove
; CHECK-NOT: llvm.memcpy
; CHECK: ret void
}

; test memmove is not performed since the destination array is accessed during the loop.
define void @copy_access_dest(i8* readonly %begin, i8* readnone %end, i8* nocapture %out) nounwind ssp {
entry:
  %add.ptr = getelementptr inbounds i8, i8* %out, i64 1
  %cmp1 = icmp eq i8* %begin, %end
  br i1 %cmp1, label %for.end, label %for.body.preheader

for.body.preheader:                               ; preds = %entry
  br label %for.body

for.body:                                         ; preds = %for.body.preheader, %for.body
  %begin.i = phi i8* [ %begin.next, %for.body ], [ %begin, %for.body.preheader ]
  %dest.i = phi i8* [ %dest.next, %for.body ], [ %out, %for.body.preheader ]
  %0 = load i8, i8* %add.ptr, align 1
  tail call void @eat(i8 signext %0) #3
  %1 = load i8, i8* %begin.i, align 1
  store i8 %1, i8* %dest.i, align 1
  %begin.next = getelementptr inbounds i8, i8* %begin.i, i64 1
  %dest.next = getelementptr inbounds i8, i8* %dest.i, i64 1
  %cmp = icmp eq i8* %begin.next, %end
  br i1 %cmp, label %for.end, label %for.body

for.end:                                          ; preds = %for.body, %entry
  ret void
; CHECK-LABEL: @copy_access_dest
; CHECK-NOT: llvm.memmove
; CHECK-NOT: llvm.memcpy
; CHECK: ret void
}


; Validate that "memset_pattern" has the proper attributes.
; CHECK: declare void @memset_pattern16(i8* nocapture, i8* nocapture readonly, i64) [[ATTRS:#[0-9]+]]
; CHECK: [[ATTRS]] = { argmemonly }

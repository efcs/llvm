; RUN: llc -mtriple x86_64-pc-linux < %s  | FileCheck %s

; Test that we don't pollute the start of the file with debug sections

; CHECK:       .text
; CHECK-NEXT: .file	"<stdin>"
; CHECK-NEXT: .globl	f
; CHECK-NEXT: .align	16, 0x90
; CHECK-NEXT: .type	f,@function
; CHECK-NEXT: f:                                      # @f

; CHECK: .section .debug_str

define void @f() {
  ret void, !dbg !9
}
!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!7, !8}

!0 = !DICompileUnit(language: DW_LANG_C99, file: !1, producer: "foo", isOptimized: true, runtimeVersion: 0, emissionKind: 1, enums: !2, retainedTypes: !2, subprograms: !3, globals: !2, imports: !2)
!1 = !DIFile(filename: "/foo/test.c", directory: "/foo")
!2 = !{}
!3 = !{!4}
!4 = !DISubprogram(name: "f", scope: !1, file: !1, line: 1, type: !5, isLocal: false, isDefinition: true, scopeLine: 1, flags: DIFlagPrototyped, isOptimized: true, function: void ()* @f, variables: !2)
!5 = !DISubroutineType(types: !6)
!6 = !{null}
!7 = !{i32 2, !"Dwarf Version", i32 4}
!8 = !{i32 2, !"Debug Info Version", i32 3}
!9 = !DILocation(line: 1, column: 15, scope: !4)

; For http://llvm.org/bugs/show_bug.cgi?id=12942
;   There are two CUs coming from /tmp/foo.c in this module. Make sure it doesn't
;   blow llc up and produces something reasonable.
;

; REQUIRES: object-emission

; RUN: %llc_dwarf %s -o %t -filetype=obj -O0
; RUN: llvm-dwarfdump -debug-dump=info %t | FileCheck %s

; ModuleID = 'test.bc'

@str = private unnamed_addr constant [4 x i8] c"FOO\00"
@str1 = private unnamed_addr constant [6 x i8] c"Main!\00"

define void @foo() nounwind {
entry:
  %puts = tail call i32 @puts(i8* getelementptr inbounds ([4 x i8]* @str, i32 0, i32 0)), !dbg !23
  ret void, !dbg !25
}

declare i32 @puts(i8* nocapture) nounwind

define i32 @main(i32 %argc, i8** nocapture %argv) nounwind {
entry:
  tail call void @llvm.dbg.value(metadata i32 %argc, i64 0, metadata !21, metadata !MDExpression()), !dbg !26
  tail call void @llvm.dbg.value(metadata i8** %argv, i64 0, metadata !22, metadata !MDExpression()), !dbg !27
  %puts = tail call i32 @puts(i8* getelementptr inbounds ([6 x i8]* @str1, i32 0, i32 0)), !dbg !28
  tail call void @foo() nounwind, !dbg !30
  ret i32 0, !dbg !31
}

declare void @llvm.dbg.value(metadata, i64, metadata, metadata) nounwind readnone

!llvm.dbg.cu = !{!0, !9}
!llvm.module.flags = !{!33}

!0 = !MDCompileUnit(language: DW_LANG_C99, producer: "clang version 3.2 (trunk 156513)", isOptimized: true, emissionKind: 1, file: !32, enums: !1, retainedTypes: !1, subprograms: !3, globals: !1, imports: !1)
!1 = !{}
!3 = !{!5}
!5 = !MDSubprogram(name: "foo", line: 5, isLocal: false, isDefinition: true, virtualIndex: 6, flags: DIFlagPrototyped, isOptimized: true, scopeLine: 5, file: !32, scope: !6, type: !7, function: void ()* @foo, variables: !1)
!6 = !MDFile(filename: "foo.c", directory: "/tmp")
!7 = !MDSubroutineType(types: !8)
!8 = !{null}
!9 = !MDCompileUnit(language: DW_LANG_C99, producer: "clang version 3.2 (trunk 156513)", isOptimized: true, emissionKind: 1, file: !32, enums: !1, retainedTypes: !1, subprograms: !10, globals: !1, imports: !1)
!10 = !{!12}
!12 = !MDSubprogram(name: "main", line: 11, isLocal: false, isDefinition: true, virtualIndex: 6, flags: DIFlagPrototyped, isOptimized: true, scopeLine: 11, file: !32, scope: !6, type: !13, function: i32 (i32, i8**)* @main, variables: !19)
!13 = !MDSubroutineType(types: !14)
!14 = !{!15, !15, !16}
!15 = !MDBasicType(tag: DW_TAG_base_type, name: "int", size: 32, align: 32, encoding: DW_ATE_signed)
!16 = !MDDerivedType(tag: DW_TAG_pointer_type, size: 32, align: 32, baseType: !17)
!17 = !MDDerivedType(tag: DW_TAG_pointer_type, size: 32, align: 32, baseType: !18)
!18 = !MDBasicType(tag: DW_TAG_base_type, name: "char", size: 8, align: 8, encoding: DW_ATE_signed_char)
!19 = !{!21, !22}
!21 = !MDLocalVariable(tag: DW_TAG_arg_variable, name: "argc", line: 11, arg: 1, scope: !12, file: !6, type: !15)
!22 = !MDLocalVariable(tag: DW_TAG_arg_variable, name: "argv", line: 11, arg: 2, scope: !12, file: !6, type: !16)
!23 = !MDLocation(line: 6, column: 3, scope: !24)
!24 = distinct !MDLexicalBlock(line: 5, column: 16, file: !32, scope: !5)
!25 = !MDLocation(line: 7, column: 1, scope: !24)
!26 = !MDLocation(line: 11, column: 14, scope: !12)
!27 = !MDLocation(line: 11, column: 26, scope: !12)
!28 = !MDLocation(line: 12, column: 3, scope: !29)
!29 = distinct !MDLexicalBlock(line: 11, column: 34, file: !32, scope: !12)
!30 = !MDLocation(line: 13, column: 3, scope: !29)
!31 = !MDLocation(line: 14, column: 3, scope: !29)
!32 = !MDFile(filename: "foo.c", directory: "/tmp")

; This test is simple to be cross platform (many targets don't yet have
; sufficiently good DWARF emission and/or dumping)
; CHECK: {{DW_TAG_compile_unit}}
; CHECK: {{foo\.c}}

!33 = !{i32 1, !"Debug Info Version", i32 3}

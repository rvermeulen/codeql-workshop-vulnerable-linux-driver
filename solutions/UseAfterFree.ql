import cpp
import Linux
import semmle.code.cpp.dataflow.DataFlow
import semmle.code.cpp.controlflow.Guards

// 1. Finding calls to kmalloc.
class KMalloc extends Function {
  KMalloc() { this.hasName("kmalloc") }
}

// predicate isKMalloc(Function f) {
//     f.hasName("kmalloc")
// }
class KMallocCall extends FunctionCall {
  KMallocCall() { exists(KMalloc f | this.getTarget() = f) }
}

// 2. Finding calls to kfree.
class KFree extends Function {
  KFree() { this.hasName("kfree") }
}

class KFreeCall extends FunctionCall {
  KFreeCall() { this.getTarget() instanceof KFree }
}

// Finding our pointer use
// from Expr e
// where e.getFile().getBaseName() = "use_after_free.h" and
// e.getLocation().getStartLine() = 84
// select e, e.getAPrimaryQlClass()
// predicate pointerUse(Expr use, Variable ptr) {
//     // p->field
//     exists(PointerFieldAccess pfa, VariableAccess va | pfa = use |
//         pfa.getQualifier() = va and
//         va.getTarget() = ptr
//         )
//     or
//     // *p
//     exists(PointerDereferenceExpr pde, VariableAccess va | pde = use |
//         pde.getOperand() = va and
//         va.getTarget() = ptr
//     )
// }
predicate pointerUse(Expr use, Variable ptr) {
  // p->field
  use.(PointerFieldAccess).getQualifier() = ptr.getAnAccess()
  or
  // *p
  use.(PointerDereferenceExpr).getOperand() = ptr.getAnAccess()
}

// from PointerFieldAccess pfa, VariableAccess va
// where pfa.getFile().getBaseName() = "use_after_free.h" and
// pfa.getQualifier() = va
// select pfa, va, va.getTarget()
// a kmalloc call and a kfree call are reachable from the entry point.
// there is path from the entrypoint to kfree, that doesn't call kmalloc.
// predicate reachable(Function caller, Function callee) {
//     // base case: caller -> callee
//     caller.calls(callee)
//     or
//     // recursion step: caller -> some other f -> callee
//     exists(Function otherFunction |
//         caller.calls(otherFunction) and reachable(otherFunction, callee)
//     )
// }
// predicate reachable2(Function caller, Function callee) {
//     // base case: caller -> callee
//     caller.calls(callee)
//     or
//     // recursion step: caller -> some other f -> callee
//     exists(Function otherFunction |
//         otherFunction.calls(callee) and reachable2(caller, otherFunction)
//     )
// }
from
  Function ep, KMallocCall kmallocCall, KFreeCall kfreeCall, GlobalVariable danglingPtr,
  Expr useOfPointer
where
  exists(Fs::FileOperationsDefinition fops | fops.getIoctlHandler() = ep) and
  ep.calls+(kmallocCall.getEnclosingFunction()) and
  ep.calls+(kfreeCall.getEnclosingFunction()) and
  // These function, calling kmalloc and kfree, do no have a common ancestor besides entry point.
  not exists(Function common |
    common.calls+(kmallocCall.getEnclosingFunction()) and
    common.calls+(kfreeCall.getEnclosingFunction()) and
    common != ep
  ) and
  not exists(Function common |
    common.calls+(kmallocCall.getEnclosingFunction()) and
    common.calls+(useOfPointer.getEnclosingFunction()) and
    common != ep
  ) and
  pointerUse(useOfPointer, danglingPtr) and
  ep.calls+(useOfPointer.getEnclosingFunction()) and
  // Make sure the danglingPtr is allocated with kmalloc and released using kfree.
  DataFlow::localExprFlow(kmallocCall, danglingPtr.getAnAssignedValue()) and
  DataFlow::localExprFlow(danglingPtr.getAnAccess(), kfreeCall.getAnArgument()) and
  not exists(GuardCondition condition |
    condition.controls(useOfPointer.getBasicBlock(), _) and
    condition.(EQExpr).getRightOperand() instanceof Literal
  )
select danglingPtr, useOfPointer

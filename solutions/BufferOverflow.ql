/**
 * @name User-controlled size argument
 * @description A user-controlled size argument can lead to a buffer overflow.
 * @kind path-problem
 */

import cpp
import semmle.code.cpp.dataflow.new.DataFlow
import Linux

module UserControlledSizeArgMemcpyDataFlow = DataFlow::Global<UserControlledSizeArgConfig>;

module StaticBufferToMemcpyDestDataFlow = DataFlow::Global<StaticBufferToMemcpyDestConfig>;

import UserControlledSizeArgMemcpyDataFlow::PathGraph

class MemcpyCall extends FunctionCall {
  MemcpyCall() { this.getTarget().getName() = "memcpy" }

  Expr getDest() { result = this.getArgument(0) }

  Expr getSize() { result = this.getArgument(2) }
}

class StrlenCall extends FunctionCall {
  StrlenCall() { this.getTarget().getName() = "strlen" }

  Expr getArgument() { result = this.getArgument(0) }
}

module StaticBufferToMemcpyDestConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node node) {
    // Local static buffers
    node.asUninitialized().getType() instanceof ArrayType
    or
    // Global static buffers
    node.asVariable().getType() instanceof ArrayType
  }

  predicate isSink(DataFlow::Node node) { exists(MemcpyCall call | node.asExpr() = call.getDest()) }
}

module UserControlledSizeArgConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node node) {
    exists(Fs::FileOperationsDefinition fops, Function ioctHandler |
      fops.getIoctlHandler() = ioctHandler
    |
      node.asParameter() = ioctHandler.getParameter(2)
    )
  }

  predicate isSink(DataFlow::Node node) {
    exists(MemcpyCall call |
      node.asExpr() = call.getSize() and
      StaticBufferToMemcpyDestDataFlow::flowToExpr(call.getDest())
    )
  }

  predicate isAdditionalFlowStep(DataFlow::Node pred, DataFlow::Node succ) {
    exists(StrlenCall call |
      pred.asExpr() = call.getArgument() and
      succ.asExpr() = call
    )
  }
}

from
  UserControlledSizeArgMemcpyDataFlow::PathNode sizeSource,
  UserControlledSizeArgMemcpyDataFlow::PathNode sizeSink, DataFlow::Node stackBufferSource,
  MemcpyCall memcpyCall
where
  UserControlledSizeArgMemcpyDataFlow::flowPath(sizeSource, sizeSink) and
  memcpyCall.getSize() = sizeSink.getNode().asExpr() and
  StaticBufferToMemcpyDestDataFlow::flow(stackBufferSource, DataFlow::exprNode(memcpyCall.getDest()))
select sizeSink, sizeSource, sizeSink,
  "User-controlled size argument in call to $@ copying to a $@", memcpyCall, "memcpy",
  stackBufferSource, "stack buffer"

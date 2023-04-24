import cpp

module Fs {
  class FileOperationsStruct extends Struct {
    FileOperationsStruct() {
      this.hasName("file_operations") and
      this.getFile().getAbsolutePath().matches("%/linux-headers-%/include/linux/fs.h")
    }
  }

  class FileOperationsDefinition extends Expr {
    FileOperationsDefinition() {
      exists(Variable v | v.getType() instanceof FileOperationsStruct |
        this = v.getInitializer().getExpr()
      )
    }

    Function getIoctlHandler() {
      exists(Field f | f.getName().matches("%ioctl") |
        result.getAnAccess() = this.(ClassAggregateLiteral).getAFieldExpr(f)
      )
    }
  }
}

module MiscDevice {
  class MiscDeviceStruct extends Struct {
    MiscDeviceStruct() {
      this.hasName("miscdevice") and
      this.getFile().getAbsolutePath().matches("%/linux-headers-%/include/linux/miscdevice.h")
    }
  }

  class FileOperationsStruct extends Struct {
    FileOperationsStruct() {
      this.hasName("file_operations") and
      this.getFile().getAbsolutePath().matches("%/linux-headers-%/include/linux/fs.h")
    }
  }

  class MiscDeviceDefinition extends Expr {
    MiscDeviceDefinition() {
      exists(Variable v | v.getType() instanceof MiscDeviceStruct |
        this = v.getInitializer().getExpr()
      )
    }

    Fs::FileOperationsDefinition getFileOperationsDefinition() {
      this.(ClassAggregateLiteral)
          .getAFieldExpr(_)
          .(AddressOfExpr)
          .getOperand()
          .(VariableAccess)
          .getTarget()
          .getInitializer()
          .getExpr() = result
    }
  }

  class MiscRegisterFunction extends Function {
    MiscRegisterFunction() {
      this.getName() = "misc_register" and
      this.getType() instanceof IntType and
      this.getNumberOfParameters() = 1 and
      this.getParameter(0).getType().(PointerType).getBaseType() instanceof MiscDeviceStruct
    }
  }
}

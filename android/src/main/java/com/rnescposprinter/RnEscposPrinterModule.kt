package com.rnescposprinter

import com.facebook.react.bridge.ReactApplicationContext

class RnEscposPrinterModule(reactContext: ReactApplicationContext) :
  NativeRnEscposPrinterSpec(reactContext) {

  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }

  companion object {
    const val NAME = NativeRnEscposPrinterSpec.NAME
  }
}

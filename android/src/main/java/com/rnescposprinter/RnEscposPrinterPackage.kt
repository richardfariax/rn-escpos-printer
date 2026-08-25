package com.rnescposprinter

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider

class RnEscposPrinterPackage : BaseReactPackage() {
  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return if (name == RnEscposPrinterModule.NAME) {
      RnEscposPrinterModule(reactContext)
    } else {
      null
    }
  }

  override fun getReactModuleInfoProvider() = ReactModuleInfoProvider {
    mapOf(
      RnEscposPrinterModule.NAME to ReactModuleInfo(
        RnEscposPrinterModule.NAME,
        RnEscposPrinterModule.NAME,
        false,
        false,
        false,
        true
      )
    )
  }
}

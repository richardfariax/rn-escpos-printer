import { TurboModuleRegistry, type TurboModule } from 'react-native';

export type NativePrinterDevice = {
  id: string;
  name: string;
  address: string;
  transport: string;
  connected: boolean;
};

export interface Spec extends TurboModule {
  initialize(): Promise<void>;
  getPrinters(scanDurationMs: number): Promise<NativePrinterDevice[]>;
  connect(identifier: string, timeoutMs: number): Promise<void>;
  disconnect(): Promise<void>;
  isConnected(): Promise<boolean>;
  printText(
    text: string,
    codePage: string,
    feedLines: number,
    cut: boolean
  ): Promise<void>;
  printImageBase64(
    base64: string,
    paperWidth: number,
    threshold: number,
    feedLines: number,
    cut: boolean
  ): Promise<void>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('RnEscposPrinter');

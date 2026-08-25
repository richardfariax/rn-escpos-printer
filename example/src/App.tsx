import { useState } from 'react';
import {
  ActivityIndicator,
  PermissionsAndroid,
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { EscPosPrinter, type PrinterDevice } from 'rn-escpos-printer';

const errorMessage = (error: unknown): string =>
  error instanceof Error ? error.message : String(error);

const BLUETOOTH_CONNECT_PERMISSION = 'android.permission.BLUETOOTH_CONNECT';

const requestAndroidPermission = async (): Promise<void> => {
  if (Platform.OS !== 'android' || Platform.Version < 31) {
    return;
  }

  const result = await PermissionsAndroid.request(BLUETOOTH_CONNECT_PERMISSION);
  if (result !== PermissionsAndroid.RESULTS.GRANTED) {
    throw new Error('Bluetooth permission was not granted');
  }
};

export default function App() {
  const [printers, setPrinters] = useState<PrinterDevice[]>([]);
  const [selected, setSelected] = useState<PrinterDevice | null>(null);
  const [status, setStatus] = useState('Ready');
  const [busy, setBusy] = useState(false);

  const run = async (operation: () => Promise<void>): Promise<void> => {
    setBusy(true);
    try {
      await operation();
    } catch (error) {
      setStatus(errorMessage(error));
    } finally {
      setBusy(false);
    }
  };

  const findPrinters = () =>
    run(async () => {
      await requestAndroidPermission();
      await EscPosPrinter.initialize();
      setStatus(
        Platform.OS === 'ios' ? 'Scanning…' : 'Reading paired devices…'
      );
      const result = await EscPosPrinter.getPrinters();
      setPrinters(result);
      setStatus(`${result.length} printer(s) found`);
    });

  const connect = (printer: PrinterDevice) =>
    run(async () => {
      setStatus(`Connecting to ${printer.name}…`);
      await EscPosPrinter.connect(printer);
      setSelected(printer);
      setStatus(`Connected to ${printer.name}`);
    });

  const printTest = () =>
    run(async () => {
      await EscPosPrinter.printText(
        'rn-escpos-printer\nPedido: 123\nAcentos: ação, café, preço\nTotal: R$ 42,90',
        { codePage: 'cp850' }
      );
      setStatus('Test receipt sent');
    });

  const disconnect = () =>
    run(async () => {
      await EscPosPrinter.disconnect();
      setSelected(null);
      setStatus('Disconnected');
    });

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.title}>rn-escpos-printer</Text>
        <Text style={styles.subtitle}>ESC/POS Bluetooth test application</Text>

        <Pressable
          disabled={busy}
          onPress={findPrinters}
          style={styles.primaryButton}
        >
          <Text style={styles.primaryButtonText}>Find printers</Text>
        </Pressable>

        <View style={styles.list}>
          {printers.map((printer) => (
            <Pressable
              disabled={busy}
              key={printer.id}
              onPress={() => connect(printer)}
              style={styles.printer}
            >
              <Text style={styles.printerName}>{printer.name}</Text>
              <Text style={styles.printerDetail}>
                {printer.transport} · {printer.address}
              </Text>
            </Pressable>
          ))}
        </View>

        {selected ? (
          <View style={styles.actions}>
            <Pressable
              disabled={busy}
              onPress={printTest}
              style={styles.primaryButton}
            >
              <Text style={styles.primaryButtonText}>Print text test</Text>
            </Pressable>
            <Pressable
              disabled={busy}
              onPress={disconnect}
              style={styles.secondaryButton}
            >
              <Text style={styles.secondaryButtonText}>Disconnect</Text>
            </Pressable>
          </View>
        ) : null}

        <View style={styles.status}>
          {busy ? <ActivityIndicator /> : null}
          <Text style={styles.statusText}>{status}</Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: '#f7f8fa' },
  container: { padding: 24, gap: 16 },
  title: { color: '#111827', fontSize: 28, fontWeight: '700' },
  subtitle: { color: '#6b7280', fontSize: 16, marginBottom: 8 },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: '#2563eb',
    borderRadius: 10,
    padding: 14,
  },
  primaryButtonText: { color: '#ffffff', fontSize: 16, fontWeight: '600' },
  secondaryButton: {
    alignItems: 'center',
    borderColor: '#cbd5e1',
    borderRadius: 10,
    borderWidth: 1,
    padding: 14,
  },
  secondaryButtonText: { color: '#334155', fontSize: 16, fontWeight: '600' },
  list: { gap: 10 },
  printer: { backgroundColor: '#ffffff', borderRadius: 10, padding: 14 },
  printerName: { color: '#111827', fontSize: 16, fontWeight: '600' },
  printerDetail: { color: '#6b7280', fontSize: 12, marginTop: 4 },
  actions: { gap: 10 },
  status: { alignItems: 'center', flexDirection: 'row', gap: 8, marginTop: 8 },
  statusText: { color: '#475569', flex: 1 },
});
